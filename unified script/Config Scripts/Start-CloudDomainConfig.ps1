#Requires -Version 5.1
<#
.SYNOPSIS
    Cloud Domain AutoConfig Launcher
    Pulls certs from NAS3, transfers them to the target VM via PSRemoting,
    and executes the AutoConfig script elevated on the VM.

.DESCRIPTION
    Run this from any local Windows 11 machine that has access to NAS3.
    Launch using Start-CloudDomainConfig.bat (located one level up, at the
    root of the AutoConfig folder), not by invoking the script directly.

    Interactive use accepts one or more VM names at once (comma-separated). Market/Client
    are collected for every queued VM up front, then one shared admin password, then each
    VM runs in turn; a failed VM prints full troubleshooting detail and the run moves on
    to the next one instead of stopping, so the user can just re-run the VM(s) that failed.

    When invoked by the app that drives this script ($runningFromApp = $true, with
    $vmHost/$market/$client/$environment/$adminPass pre-set), no prompts run and a
    failure calls `exit 1` immediately instead of continuing to a next VM.

.NOTES
    Location : \\nas3\Client-Certificates\AutoConfig\Config Scripts\Start-CloudDomainConfig.ps1
    Launcher : \\nas3\Client-Certificates\AutoConfig\Start-CloudDomainConfig.bat
    Author   : Renzo Jimenez
    Created  : 2026-05-25
#>

# ── Console ───────────────────────────────────────────────────────────────────
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'White'
Clear-Host

# QuickEdit Mode pauses all console I/O the moment the window is clicked/dragged,
# until Enter is pressed -- looks exactly like a hang at any point in a long-running
# script. Disabling it here.
try {
    Add-Type -Name Console -Namespace Win32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop

    $stdIn = [Win32.Console]::GetStdHandle(-10)  # STD_INPUT_HANDLE
    [uint32]$consoleMode = 0
    if ([Win32.Console]::GetConsoleMode($stdIn, [ref]$consoleMode)) {
        # ENABLE_EXTENDED_FLAGS (0x0080) must be set for the QuickEdit bit (0x0040)
        # to actually take effect -- a documented quirk of this API.
        $consoleMode = ($consoleMode -band (-bnot 0x0040)) -bor 0x0080
        [Win32.Console]::SetConsoleMode($stdIn, $consoleMode) | Out-Null
    }
}
catch { }

# ── Preflight ─────────────────────────────────────────────────────────────────

# ExecutionPolicy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# WinRM
$winrm = Get-Service -Name WinRM
if ($winrm.Status -ne 'Running') {
    winrm quickconfig -quiet
}

# TrustedHosts
$current = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
if ($current -notlike "*cloud.pci*") {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*.cloud.pci" -Force
}

# ── Runtime context flag ──────────────────────────────────────────────────────

if (-not (Get-Variable -Name 'runningFromApp' -ErrorAction SilentlyContinue)) {
    $runningFromApp = $false
}

$InformationPreference = 'Continue'

# ─────────────────────────────────────────────
#  STRICT MODE + ERROR HANDLING
# ─────────────────────────────────────────────

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────
#  CONFIGURATION — adjust these paths if needed
# ─────────────────────────────────────────────

$NAS3_CERTS_ROOT = '\\nas3\Client-Certificates'
$NAS3_AUTOCONFIG = '\\nas3\Client-Certificates\AutoConfig'

# Unified layout under AutoConfig\: shared Config Scripts\ (generators + this launcher),
# Config Files\<Market>\ per market, shared Dependencies\, and Client Info Spreadsheets\
# (<Market>.xlsx) -- the client/AO-to-credential source of truth. Every market is
# generator-driven; there's no legacy per-client SQL file path here anymore.
$NAS3_CONFIG_SCRIPTS = Join-Path $NAS3_AUTOCONFIG 'Config Scripts'
$NAS3_CONFIG_FILES = Join-Path $NAS3_AUTOCONFIG 'Config Files'
$NAS3_DEPENDENCIES = Join-Path $NAS3_AUTOCONFIG 'Dependencies'
$NAS3_SPREADSHEETS = Join-Path $NAS3_AUTOCONFIG 'Client Info Spreadsheets'

$VM_DOMAIN_SUFFIX = '.cloud.pci'
$VM_TEMP_DIR = 'C:\Temp\CloudDomainConfig'   # temp dir created on the VM

# Extensions to copy from the client cert folder. .txt deliberately excluded -- those are
# password/expiration notes never read by Configure_Domain.ps1 (the spreadsheet's
# Certificates sheet is the source of truth now). Not consulted for CAISO, which instead
# matches files by basename against the SFTP Certificates sheet's Cert Name column.
$CERT_EXTENSIONS = @('.pfx', '.p12', '.ppk', '.cer', '.crt', '.id')

$validMarkets = @('CAISO', 'ERCOT', 'ISONE', 'MISO', 'NYISO', 'PJM', 'SPPIM')
$ercotEnvironments = @('MOTE', 'PROD')
$caisoEnvironments = @('N', 'P')

# ─────────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n[ $(Get-Date -Format 'HH:mm:ss') ] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  OK  $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  !!  $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$m)
    Write-Host "  $m" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string]$m)
    Write-Host "  $m" -ForegroundColor Yellow
}

# CAISO's N/P aren't self-explanatory like ERCOT's MOTE/PROD, so display messages
# append this label; MOTE/PROD print unlabeled.
function Get-EnvironmentDisplay([string]$Environment) {
    switch ($Environment) {
        'N' { "$Environment (Map Stage)" }
        'P' { "$Environment (Production)" }
        'MOTE' { $Environment }
        'PROD' { $Environment }
    }
}

function Prompt-NotEmpty {
    param([string]$Label)
    do {
        $value = Read-Host $Label
        $value = $value.Trim()
        if (-not $value) { Write-Warn "Value cannot be empty. Please try again." }
    } while (-not $value)
    return $value
}

function Find-ClientMatches {
    param([string]$RawEntry, [string[]]$ClientList)

    $normalized = $RawEntry.ToUpper().Replace('-', '').Replace(' ', '').Replace('_', '')

    return $ClientList | Where-Object {
        $canonical = $_.ToUpper().Replace('-', '').Replace(' ', '').Replace('_', '')
        $canonical -like "*$normalized*" -or $normalized -like "*$canonical*"
    }
}

# Resolves a market's spreadsheet and copies it to a local temp file (3 attempts, 2s
# backoff) -- Excel can hold a share-violation lock on the NAS3 copy, so every downstream
# read uses this local copy instead. Shared by Read-VmInputs and the app-driven path;
# pass -ExitOnFailure (app path only) to exit 1 on failure instead of returning $null.
function Resolve-MarketWorkbook {
    param(
        [string]$Market,
        [switch]$ExitOnFailure
    )

    $workbookSourcePath = Join-Path $NAS3_SPREADSHEETS "$Market.xlsx"
    if (-not (Test-Path $workbookSourcePath)) {
        Write-Fail "Market spreadsheet not found: $workbookSourcePath"
        Write-Warn "$Market isn't wired into this launcher yet -- it needs a Client Info Spreadsheets\$Market.xlsx first"
        if ($ExitOnFailure) { exit 1 }
        return $null
    }

    $xlsxTempDir = Join-Path $env:TEMP "CloudDomainConfig_xlsx_$(Get-Random)"
    New-Item -ItemType Directory -Path $xlsxTempDir -Force | Out-Null
    $workbookLocalPath = Join-Path $xlsxTempDir "$Market.xlsx"

    $copyAttempts = 3
    for ($i = 1; $i -le $copyAttempts; $i++) {
        try {
            Copy-Item -Path $workbookSourcePath -Destination $workbookLocalPath -Force -ErrorAction Stop
            return [PSCustomObject]@{ LocalPath = $workbookLocalPath; TempDir = $xlsxTempDir }
        }
        catch {
            if ($i -eq $copyAttempts) {
                Write-Fail "Could not read $Market.xlsx after $copyAttempts attempts -- it may be open for editing on another machine right now."
                Write-Warn "Error: $_"
                if ($ExitOnFailure) { exit 1 }
                return $null
            }
            Start-Sleep -Seconds 2
        }
    }
}

# ─────────────────────────────────────────────
#  Collect inputs for one VM (Market, Client, Environment) interactively and derive its
#  paths. Returns a config object to run later via Invoke-CloudDomainConfigForVm, or $null
#  if this VM couldn't even be configured (e.g. its market spreadsheet is missing) -- the
#  caller records that as a failure for this VM and moves on to collecting the next one.
#  Only used interactively; the $runningFromApp path builds its one Config directly from
#  pre-set variables instead (see the bottom of this file), since it never prompts.
# ─────────────────────────────────────────────

function Read-VmInputs {
    param(
        [string]$VmRaw,
        [int]$Index,
        [int]$Total
    )

    try {
        Write-Host ''
        Write-Host '=============================================' -ForegroundColor DarkCyan
        Write-Host "   ${Index}/${Total}: $VmRaw" -ForegroundColor White
        Write-Host '=============================================' -ForegroundColor DarkCyan

        $vmHost = ($VmRaw.Trim().ToLower()) + $VM_DOMAIN_SUFFIX
        Write-Info "Target VM FQDN: $vmHost"

        do {
            $market = (Prompt-NotEmpty "  Enter Market name for $VmRaw").Trim().ToUpper()
            if ($market -notin $validMarkets) {
                Write-Warn "Invalid market '$market'. Please enter one of: $($validMarkets -join ', ')"
            }
        } while ($market -notin $validMarkets)

        $isCaiso = $market -eq 'CAISO'
        $isErcot = $market -eq 'ERCOT'
        $isPjm = $market -eq 'PJM'
        $isMiso = $market -eq 'MISO'
        $certFolder = if ($isCaiso) { 'CAISO-Settlements' } else { $market }

        # Market spreadsheet -- resolved early because client-name validation below reads its
        # Asset Owners sheet directly: the sheet's Client column IS the canonical client list.
        $workbook = Resolve-MarketWorkbook -Market $market
        if (-not $workbook) { return $null }
        $workbookSourcePath = $workbook.LocalPath

        # Load canonical client list from the spreadsheet
        . (Join-Path $NAS3_CONFIG_SCRIPTS "XlsxReader.ps1")
        $assetOwnerRows = Import-XlsxSheet -Path $workbookSourcePath -WorksheetName 'Asset Owners'

        # "Client" is only populated on the first row of each group (merged-cell style in the
        # sheet); forward-fill it, same as every SQL generator does, before taking distinct values.
        $lastClient = $null
        $validClients = [System.Collections.Generic.List[string]]::new()
        foreach ($row in $assetOwnerRows) {
            if ($row.Client) { $lastClient = $row.Client }
            if ($lastClient -and -not $validClients.Contains($lastClient)) {
                $validClients.Add($lastClient)
            }
        }
        $validClients = @($validClients | Sort-Object)

        # Valid clients and input validation
        $client = $null
        do {
            $raw = (Prompt-NotEmpty "  Enter Client name for $VmRaw").Trim()
            $upper = $raw.ToUpper()

            $exactMatch = $validClients | Where-Object { $_.ToUpper() -eq $upper }
            if ($exactMatch) {
                $client = $exactMatch
                break
            }

            $clientMatches = @(Find-ClientMatches -RawEntry $raw -ClientList $validClients)

            if ($clientMatches.Count -eq 1) {
                $confirm = Prompt-NotEmpty "  Did you mean '$($clientMatches[0])'? (Y/N)"
                if ($confirm.Trim().ToUpper() -eq 'Y') {
                    $client = $clientMatches[0]
                }
                else {
                    Write-Warn "No client selected. Please try again."
                }
            }
            elseif ($clientMatches.Count -gt 1) {
                Write-Host "  Did you mean one of these?" -ForegroundColor Cyan
                $i = 1
                foreach ($m in $clientMatches) { Write-Host "  [$i] $m"; $i++ }
                Write-Host "  [0] None of these"
                $choice = Prompt-NotEmpty "Enter number"
                $idx = [int]$choice - 1
                if ($idx -ge 0 -and $idx -lt $clientMatches.Count) {
                    $client = $clientMatches[$idx]
                }
                else {
                    Write-Warn "No client selected. Please try again."
                }
            }
            else {
                Write-Warn "No matches found for '$raw'. Please check the name and try again."
            }

        } while (-not $client)
        Write-Info "Client set to: $client for $VmRaw"

        # ERCOT: domain points to either MOTE (sandbox) or PROD (MIS) at a time.
        # CAISO: USE_MODE is N (Map Stage) or P (Production).
        $environment = $null
        if ($isErcot) {
            do {
                $environment = (Prompt-NotEmpty "  Enter Environment for $VmRaw (MOTE or PROD)").Trim().ToUpper()
                if ($environment -notin $ercotEnvironments) {
                    Write-Warn "Invalid environment '$environment'. Please enter MOTE or PROD"
                }
            } while ($environment -notin $ercotEnvironments)
            Write-Info "Environment set to: $(Get-EnvironmentDisplay $environment)"
        }
        elseif ($isCaiso) {
            do {
                $environment = (Prompt-NotEmpty "  Enter Environment for $VmRaw (N = Map Stage, P = Production)").Trim().ToUpper()
                if ($environment -notin $caisoEnvironments) {
                    Write-Warn "Invalid environment '$environment'. Please enter N or P"
                }
            } while ($environment -notin $caisoEnvironments)
            Write-Info "Environment set to: $(Get-EnvironmentDisplay $environment)"
        }

        # Derive paths
        $certSourcePath = if ($isErcot) { Join-Path $NAS3_CERTS_ROOT "$certFolder\$client\$environment" }
        else { Join-Path $NAS3_CERTS_ROOT "$certFolder\$client" }

        $marketConfigFilesFolder = Join-Path $NAS3_CONFIG_FILES $market

        $wsddSourcePath = if ($isErcot) { Join-Path $NAS3_CERTS_ROOT "$market\$client\wsdd\$environment" }
        else { $null }

        Write-Host ''
        Write-Info 'Summary:'
        Write-Info "  VM FQDN      : $vmHost"
        Write-Info "  Cert source  : $certSourcePath"
        Write-Info "  Config Files : $marketConfigFilesFolder"
        Write-Info "  Spreadsheet  : $workbookSourcePath"
        Write-Host ''

        return [PSCustomObject]@{
            Index                   = $Index
            Total                   = $Total
            VmRaw                   = $VmRaw
            VmHost                  = $vmHost
            Market                  = $market
            Client                  = $client
            Environment             = $environment
            IsCaiso                 = $isCaiso
            IsErcot                 = $isErcot
            IsPjm                   = $isPjm
            IsMiso                  = $isMiso
            CertSourcePath          = $certSourcePath
            MarketConfigFilesFolder = $marketConfigFilesFolder
            WsddSourcePath          = $wsddSourcePath
            WorkbookLocalPath       = $workbookSourcePath
            XlsxTempDir             = $workbook.TempDir
        }
    }
    catch {
        # Safety net -- an unexpected error here shouldn't stop input collection for the
        # remaining VMs still waiting in the queue.
        Write-Fail "Unexpected error while collecting inputs for $VmRaw"
        Write-Warn "Error: $_"
        return $null
    }
}

# ─────────────────────────────────────────────
#  Run the actual config work for one VM (validate, generate SQL, WinRM test, stage,
#  transfer, execute, cleanup) -- shared by both the interactive and app-driven paths.
#  -ExitOnFailure (app path only) exits 1 on failure and suppresses the per-VM banner
#  below; without it, a failure prints and `return`s to the caller's loop instead.
# ─────────────────────────────────────────────

function Invoke-CloudDomainConfigForVm {
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] [System.Security.SecureString]$AdminPass,
        [switch]$ExitOnFailure
    )

    $vmRaw = $Config.VmRaw
    $vmHost = $Config.VmHost
    $market = $Config.Market
    $client = $Config.Client
    $environment = $Config.Environment
    $isCaiso = $Config.IsCaiso
    $isErcot = $Config.IsErcot
    $isPjm = $Config.IsPjm
    $isMiso = $Config.IsMiso
    $certSourcePath = $Config.CertSourcePath
    $marketConfigFilesFolder = $Config.MarketConfigFilesFolder
    $wsddSourcePath = $Config.WsddSourcePath
    $workbookSourcePath = $Config.WorkbookLocalPath
    $sharedOdpZipPath = Join-Path $NAS3_DEPENDENCIES 'ODP.NET_Managed_ODAC122cR1.zip'

    $localTemp = $null
    $session = $null

    if (-not $ExitOnFailure) {
        Write-Host ''
        Write-Host '=============================================' -ForegroundColor DarkCyan
        Write-Host "   Configuring $($Config.Index)/$($Config.Total): $vmRaw" -ForegroundColor White
        Write-Host '=============================================' -ForegroundColor DarkCyan
    }

    try {
        # ─────────────────────────────────────────────
        #  Validate NAS3 paths
        # ─────────────────────────────────────────────

        Write-Step 'Validating NAS3 paths'

        # Cert files
        $skipCertTransfer = $false
        $certLabel = if ($isCaiso) { 'SFTP cert' } else { 'cert' }
        $certFiles = @()

        if ($isPjm) {
            # PJM: Certificates sheet, Path in nas3 = folder, Cert Name = filename.
            # Both blank = AO has no cert (expected); one without the other, or a
            # missing file on disk, gets its own warning.
            . (Join-Path $NAS3_CONFIG_SCRIPTS "XlsxReader.ps1")
            $allCertRows = Import-XlsxSheet -Path $workbookSourcePath -WorksheetName 'Certificates'

            # "Client" is only populated on the first row of each group (merged-cell style,
            # same convention as the Asset Owners sheet) -- forward-fill before filtering.
            $lastCertClient = $null
            foreach ($row in $allCertRows) {
                if ($row.Client) { $lastCertClient = $row.Client } else { $row.Client = $lastCertClient }
            }

            $certRows = @($allCertRows | Where-Object { $_.Client -eq $client })
            $expectedCount = 0

            foreach ($row in $certRows) {
                $hasCertName = [bool]$row.'Cert Name'
                $hasPath = [bool]$row.'Path in nas3'

                if (-not $hasCertName -and -not $hasPath) {
                    continue
                }
                $expectedCount++

                if ($hasCertName -and -not $hasPath) {
                    Write-Warn "Cert '$($row.'Cert Name')' ($($row.'Cert ID')) has no Path in nas3 registered -- skipping"
                    continue
                }
                if ($hasPath -and -not $hasCertName) {
                    Write-Warn "Path in nas3 registered for $($row.'Cert ID') but no Cert Name -- skipping"
                    continue
                }

                $certFilePath = Join-Path $row.'Path in nas3' $row.'Cert Name'
                if (Test-Path $certFilePath -PathType Leaf) {
                    $certFiles += Get-Item -Path $certFilePath
                }
                else {
                    Write-Warn "Cert file not found for $($row.'Cert ID'): $certFilePath"
                }
            }

            if ($expectedCount -eq 0) {
                Write-Info "${client}: no certs registered in the spreadsheet -- cert transfer skipped"
                # Reuse $skipCertTransfer to skip the staging/transfer steps below too -- there's
                # nothing to copy, same as CAISO's no-settlement-certs clients.
                $skipCertTransfer = $true
            }
            elseif ($certFiles.Count -eq 0) {
                Write-Fail "None of the $expectedCount registered cert file(s) could be found on NAS3 for $client"
                if ($ExitOnFailure) { exit 1 }
                return
            }
            else {
                Write-Success "$($certFiles.Count) of $expectedCount registered cert file(s) resolved:"
                foreach ($f in $certFiles) {
                    Write-Info "  - $($f.FullName)"
                }
            }
        }
        elseif ($isMiso) {
            # MISO: same as PJM -- Certificates sheet, Path in nas3 = folder, Cert Name =
            # filename. Both blank = no cert (expected); one without the other, or a
            # missing file, gets its own warning.
            . (Join-Path $NAS3_CONFIG_SCRIPTS "XlsxReader.ps1")
            $allCertRows = Import-XlsxSheet -Path $workbookSourcePath -WorksheetName 'Certificates'

            # "Client" is only populated on the first row of each group (merged-cell style,
            # same convention as the Asset Owners sheet) -- forward-fill before filtering.
            $lastCertClient = $null
            foreach ($row in $allCertRows) {
                if ($row.Client) { $lastCertClient = $row.Client } else { $row.Client = $lastCertClient }
            }

            $certRows = @($allCertRows | Where-Object { $_.Client -eq $client })
            $expectedCount = 0

            foreach ($row in $certRows) {
                $hasCertName = [bool]$row.'Cert Name'
                $hasPath = [bool]$row.'Path in nas3'

                if (-not $hasCertName -and -not $hasPath) {
                    continue
                }
                $expectedCount++

                if ($hasCertName -and -not $hasPath) {
                    Write-Warn "Cert '$($row.'Cert Name')' ($($row.'Cert ID')) has no Path in nas3 registered -- skipping"
                    continue
                }
                if ($hasPath -and -not $hasCertName) {
                    Write-Warn "Path in nas3 registered for $($row.'Cert ID') but no Cert Name -- skipping"
                    continue
                }

                $certFilePath = Join-Path $row.'Path in nas3' $row.'Cert Name'
                if (Test-Path $certFilePath -PathType Leaf) {
                    $certFiles += Get-Item -Path $certFilePath
                }
                else {
                    Write-Warn "Cert file not found for $($row.'Cert ID'): $certFilePath"
                }
            }

            if ($expectedCount -eq 0) {
                Write-Info "${client}: no certs registered in the spreadsheet -- cert transfer skipped"
                # Reuse $skipCertTransfer to skip the staging/transfer steps below too -- there's
                # nothing to copy, same as CAISO's no-settlement-certs clients.
                $skipCertTransfer = $true
            }
            elseif ($certFiles.Count -eq 0) {
                Write-Fail "None of the $expectedCount registered cert file(s) could be found on NAS3 for $client"
                if ($ExitOnFailure) { exit 1 }
                return
            }
            else {
                Write-Success "$($certFiles.Count) of $expectedCount registered cert file(s) resolved:"
                foreach ($f in $certFiles) {
                    Write-Info "  - $($f.FullName)"
                }
            }
        }
        elseif ($isErcot) {
            # ERCOT certs aren't transferred -- clientTruststore.jks already covers
            # cert usage at runtime. Still need to confirm this environment has at
            # least one AO cert registered, or nothing downstream (SQL, wsdd) exists.
            . (Join-Path $NAS3_CONFIG_SCRIPTS "XlsxReader.ps1")
            $allAoRows = Import-XlsxSheet -Path $workbookSourcePath -WorksheetName 'Asset Owners'
            $lastAoClient = $null
            foreach ($row in $allAoRows) {
                if ($row.Client) { $lastAoClient = $row.Client } else { $row.Client = $lastAoClient }
            }
            $aoRows = @($allAoRows | Where-Object { $_.Client -eq $client })
            $certIdColumn = "$environment Cert ID"
            $hasAnyCert = [bool]($aoRows | Where-Object { $_.$certIdColumn } | Select-Object -First 1)

            if (-not $hasAnyCert) {
                Write-Fail "No $environment certs registered for $client in the spreadsheet -- nothing to configure for this environment"
                if ($ExitOnFailure) { exit 1 }
                return
            }

            Write-Info "${client}: ERCOT certs not transferred -- clientTruststore.jks covers this"
            $skipCertTransfer = $true
        }
        elseif ($isCaiso) {
            # CAISO EIM certs (Certificates sheet) aren't transferred -- CAISOEIM.keystore
            # covers usage at runtime. Only SFTP certs (below) get transferred.
            Write-Info "${client}: CAISO EIM certs not transferred -- CAISOEIM.keystore covers this"

            # SFTP certs live directly under CAISO-Settlements\<Client> (no CERT-XXXX
            # subfolder), so $certSourcePath alone locates them -- no Path in nas3 column
            # needed. SFTP Certificates sheet's Cert Name is the allow-list.
            . (Join-Path $NAS3_CONFIG_SCRIPTS "XlsxReader.ps1")
            $allSftpRows = Import-XlsxSheet -Path $workbookSourcePath -WorksheetName 'SFTP Certificates'

            # "Client" is only populated on the first row of each group (merged-cell style,
            # same convention as every other sheet) -- forward-fill before filtering.
            $lastSftpClient = $null
            foreach ($row in $allSftpRows) {
                if ($row.Client) { $lastSftpClient = $row.Client } else { $row.Client = $lastSftpClient }
            }

            $sftpRows = @($allSftpRows | Where-Object { $_.Client -eq $client })
            $expectedCertNames = @($sftpRows | ForEach-Object { $_.'Cert Name' } | Where-Object { $_ } | Sort-Object -Unique)

            if ($expectedCertNames.Count -eq 0) {
                Write-Info "${client}: no SFTP certs registered in the spreadsheet -- cert transfer skipped"
                $skipCertTransfer = $true
            }
            else {
                if (-not (Test-Path $certSourcePath)) {
                    Write-Fail "$certLabel folder not found: $certSourcePath"
                    Write-Warn "Check that Market and Client names are correct"
                    if ($ExitOnFailure) { exit 1 }
                    return
                }
                Write-Success "$certLabel folder found: $certSourcePath"

                # An extensionless cert and its .ppk/.txt companion share the same BaseName,
                # so matching on BaseName alone pulls both halves of a pair without needing
                # separate extension-based pairing logic.
                $allFiles = Get-ChildItem -Path $certSourcePath -File -ErrorAction SilentlyContinue
                $expectedBasenames = @($expectedCertNames | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) })
                $certFiles = @($allFiles | Where-Object { $_.BaseName -in $expectedBasenames })

                $foundBasenames = @($certFiles | ForEach-Object { $_.BaseName } | Sort-Object -Unique)
                foreach ($expected in $expectedCertNames) {
                    if ([System.IO.Path]::GetFileNameWithoutExtension($expected) -notin $foundBasenames) {
                        Write-Warn "Cert '$expected' registered in the spreadsheet but not found in: $certSourcePath"
                    }
                }

                if ($certFiles.Count -eq 0) {
                    Write-Fail "None of the $($expectedCertNames.Count) registered $certLabel file(s) could be found in: $certSourcePath"
                    if ($ExitOnFailure) { exit 1 }
                    return
                }
                Write-Success "$($certFiles.Count) of $($expectedCertNames.Count) registered $certLabel file(s) resolved:"
                foreach ($f in $certFiles) {
                    Write-Info "  - $($f.Name)"
                }
            }
        }
        else {
            # ISONE/NYISO/SPPIM: same exact-lookup pattern as PJM/MISO -- Certificates
            # sheet, Path in nas3 = folder, Cert Name = filename. Replaces a folder-wide
            # scan that ignored Path in nas3 and could grab a stale cert or miss one
            # stored in its own CERT-XXXX subfolder.
            . (Join-Path $NAS3_CONFIG_SCRIPTS "XlsxReader.ps1")
            $allCertRows = Import-XlsxSheet -Path $workbookSourcePath -WorksheetName 'Certificates'

            # "Client" is only populated on the first row of each group (merged-cell style,
            # same convention as the Asset Owners sheet) -- forward-fill before filtering.
            $lastCertClient = $null
            foreach ($row in $allCertRows) {
                if ($row.Client) { $lastCertClient = $row.Client } else { $row.Client = $lastCertClient }
            }

            $certRows = @($allCertRows | Where-Object { $_.Client -eq $client })
            $expectedCount = 0

            foreach ($row in $certRows) {
                $hasCertName = [bool]$row.'Cert Name'
                $hasPath = [bool]$row.'Path in nas3'

                if (-not $hasCertName -and -not $hasPath) {
                    continue
                }
                $expectedCount++

                if ($hasCertName -and -not $hasPath) {
                    Write-Warn "Cert '$($row.'Cert Name')' ($($row.'Cert ID')) has no Path in nas3 registered -- skipping"
                    continue
                }
                if ($hasPath -and -not $hasCertName) {
                    Write-Warn "Path in nas3 registered for $($row.'Cert ID') but no Cert Name -- skipping"
                    continue
                }

                $certFilePath = Join-Path $row.'Path in nas3' $row.'Cert Name'
                if (Test-Path $certFilePath -PathType Leaf) {
                    $certFiles += Get-Item -Path $certFilePath
                }
                else {
                    Write-Warn "Cert file not found for $($row.'Cert ID'): $certFilePath"
                }
            }

            if ($expectedCount -eq 0) {
                Write-Info "${client}: no certs registered in the spreadsheet -- cert transfer skipped"
                $skipCertTransfer = $true
            }
            elseif ($certFiles.Count -eq 0) {
                Write-Fail "None of the $expectedCount registered cert file(s) could be found on NAS3 for $client"
                if ($ExitOnFailure) { exit 1 }
                return
            }
            else {
                Write-Success "$($certFiles.Count) of $expectedCount registered cert file(s) resolved:"
                foreach ($f in $certFiles) {
                    Write-Info "  - $($f.FullName)"
                }
            }
        }

        # ERCOT: wsdd files for the selected environment
        $wsddFiles = @()
        if ($isErcot) {
            if (-not (Test-Path $wsddSourcePath)) {
                Write-Fail "wsdd folder not found: $wsddSourcePath"
                Write-Warn "Expected: Client-Certificates\ERCOT\$client\wsdd\$environment\"
                if ($ExitOnFailure) { exit 1 }
                return
            }
            Write-Success "wsdd folder found: $wsddSourcePath"

            $wsddFiles = @(Get-ChildItem -Path $wsddSourcePath -File -Filter '*.wsdd' -ErrorAction SilentlyContinue)
            if ($wsddFiles.Count -eq 0) {
                Write-Fail "No .wsdd files found in: $wsddSourcePath"
                if ($ExitOnFailure) { exit 1 }
                return
            }
            Write-Success "$($wsddFiles.Count) wsdd file(s) found:"
            foreach ($f in $wsddFiles) {
                Write-Info "  - $($f.Name)"
            }
        }

        # Config Scripts folder (shared — Configure_Domain.ps1 + cloudConfigLib.ps1)
        if (-not (Test-Path $NAS3_CONFIG_SCRIPTS)) {
            Write-Fail "Config Scripts folder not found: $NAS3_CONFIG_SCRIPTS"
            if ($ExitOnFailure) { exit 1 }
            return
        }
        Write-Success "Config Scripts folder found: $NAS3_CONFIG_SCRIPTS"

        # Config Files\<Market>\ folder
        if (-not (Test-Path $marketConfigFilesFolder)) {
            Write-Fail "Config Files folder not found: $marketConfigFilesFolder"
            Write-Warn "Expected: Config Files\$market\ under $NAS3_AUTOCONFIG"
            if ($ExitOnFailure) { exit 1 }
            return
        }
        Write-Success "Config Files folder found: $marketConfigFilesFolder"

        # Dependencies folder (contains the ODP.NET zip staged below; not checked file-by-file,
        # same as Config Files\<Market>\ above -- a missing file inside would fail loudly at copy time)
        if (-not (Test-Path $NAS3_DEPENDENCIES)) {
            Write-Fail "Dependencies folder not found: $NAS3_DEPENDENCIES"
            if ($ExitOnFailure) { exit 1 }
            return
        }
        Write-Success "Dependencies folder found: $NAS3_DEPENDENCIES"

        # Market spreadsheet was already validated (Test-Path) up front, before client-name
        # validation -- nothing further to check here.

        # ─────────────────────────────────────────────
        #  Generate client SQL locally
        # ─────────────────────────────────────────────

        Write-Step 'Generating client SQL from spreadsheet'

        try {
            . (Join-Path $NAS3_CONFIG_SCRIPTS "ClientSqlGeneratorDispatcher.ps1")
            $clientSqlText = if ($isErcot) {
                New-ClientSqlText -Market $market -Client $client -WorkbookPath $workbookSourcePath -Environment $environment
            }
            else {
                New-ClientSqlText -Market $market -Client $client -WorkbookPath $workbookSourcePath
            }
            Write-Success "Client SQL generated for $market\$client"
        }
        catch {
            Write-Fail "Client SQL generation failed"
            Write-Warn "Error: $_"
            if ($ExitOnFailure) { exit 1 }
            return
        }

        # Show exactly what will be staged and executed
        Write-Host ''
        Write-Host "----- Generated SQL: $client.sql -----" -ForegroundColor DarkCyan
        Write-Host $clientSqlText -ForegroundColor Gray
        Write-Host "----- End of generated SQL -----" -ForegroundColor DarkCyan
        Write-Host ''

        # ─────────────────────────────────────────────
        #  Test WinRM / WSMan connectivity
        # ─────────────────────────────────────────────

        Write-Step "Testing WinRM connectivity to $vmHost"

        try {
            $wsmanResult = Test-WSMan -ComputerName $vmHost -ErrorAction Stop
            Write-Success "WinRM responded on $vmHost"
            Write-Info "  Vendor  : $($wsmanResult.ProductVendor)"
            Write-Info "  Version : $($wsmanResult.ProductVersion)"
        }
        catch {
            Write-Fail "Cannot reach $vmHost via WinRM."
            Write-Warn "Error: $_"
            Write-Warn "Verify the VM name is correct and that you are on the PCI network."
            if ($ExitOnFailure) { exit 1 }
            return
        }

        # ─────────────────────────────────────────────
        #  Prepare admin credentials
        # ─────────────────────────────────────────────

        Write-Step 'Preparing VM admin credentials'
        $adminCred = New-Object System.Management.Automation.PSCredential("$vmHost\Administrator", $AdminPass)

        # ─────────────────────────────────────────────
        #  Stage files in a local temp folder
        # ─────────────────────────────────────────────

        Write-Step 'Staging files in local temp folder'

        $localTemp = Join-Path $env:TEMP "CloudDomainConfig_$(Get-Random)"
        New-Item -ItemType Directory -Path $localTemp -Force | Out-Null
        Write-Success "Local staging folder: $localTemp"

        # Cert files
        if (-not $skipCertTransfer) {
            $localCertsDir = Join-Path $localTemp 'Certs'
            New-Item -ItemType Directory -Path $localCertsDir -Force | Out-Null
            foreach ($f in $certFiles) {
                Copy-Item -Path $f.FullName -Destination $localCertsDir
            }
            Write-Success "Copied $($certFiles.Count) ${certLabel} file(s) to staging"
        }

        # wsdd files
        if ($isErcot) {
            $localWsddDir = Join-Path $localTemp 'Wsdd'
            New-Item -ItemType Directory -Path $localWsddDir -Force | Out-Null
            foreach ($f in $wsddFiles) {
                Copy-Item -Path $f.FullName -Destination $localWsddDir
            }
            Write-Success "Copied $($wsddFiles.Count) wsdd file(s) to staging"
        }

        # Config Scripts (shared)
        $localConfigScripts = Join-Path $localTemp 'Config Scripts'
        Copy-Item -Path $NAS3_CONFIG_SCRIPTS -Destination $localConfigScripts -Recurse
        Write-Success "Copied Config Scripts to staging"

        # Dependencies (shared — just the ODP.NET zip)
        $localDependencies = Join-Path $localTemp 'Dependencies'
        New-Item -ItemType Directory -Path $localDependencies -Force | Out-Null
        Copy-Item -Path $sharedOdpZipPath -Destination $localDependencies
        Write-Success "Copied Dependencies (ODP.NET zip) to staging"

        # Config Files (this market's subfolder)
        $localConfigFiles = Join-Path $localTemp 'Config Files'
        $localConfigFilesMarket = Join-Path $localConfigFiles $market
        New-Item -ItemType Directory -Path $localConfigFilesMarket -Force | Out-Null
        Copy-Item -Path "$marketConfigFilesFolder\*" -Destination $localConfigFilesMarket -Recurse
        Write-Success "Copied Config Files ($market) to staging"

        # Generated client SQL (already generated above)
        $localSql = Join-Path $localTemp "$client.sql"
        Set-Content -Path $localSql -Value $clientSqlText -Encoding utf8 -NoNewline
        Write-Success "Wrote generated SQL to staging: $client.sql"

        # ─────────────────────────────────────────────
        #  Establish PSSession and transfer files
        # ─────────────────────────────────────────────

        Write-Step "Establishing PSSession to $vmHost"

        try {
            $session = New-PSSession -ComputerName $vmHost -Credential $adminCred -Authentication Negotiate -ErrorAction Stop
            Write-Success "PSSession established (ID: $($session.Id))"
        }
        catch {
            Write-Fail "Failed to create PSSession to $vmHost"
            Write-Warn "Error: $_"
            Write-Warn "Check credentials and that PSRemoting is enabled on the VM"
            Remove-Item -Path $localTemp -Recurse -Force -ErrorAction SilentlyContinue
            if ($ExitOnFailure) { exit 1 }
            return
        }

        try {
            # Create temp directory on the VM
            Write-Step "Creating temp directory on VM: $VM_TEMP_DIR"
            Invoke-Command -Session $session -ScriptBlock {
                param($dir)
                if (Test-Path $dir) {
                    Remove-Item -Path $dir -Recurse -Force
                }
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                New-Item -ItemType Directory -Path "$dir\Certs" -Force | Out-Null
                New-Item -ItemType Directory -Path "$dir\Wsdd" -Force | Out-Null
            } -ArgumentList $VM_TEMP_DIR
            Write-Success "Temp directory ready on VM"

            if (-not $skipCertTransfer) {
                Write-Step "Transferring $certLabel files to VM"
                Copy-Item -Path "$localCertsDir\*" `
                    -Destination "$VM_TEMP_DIR\Certs" `
                    -ToSession $session `
                    -Force
                Write-Success "$certLabel files transferred"
            }

            if ($isErcot) {
                Write-Step "Transferring wsdd files to VM"
                Copy-Item -Path "$localWsddDir\*" `
                    -Destination "$VM_TEMP_DIR\Wsdd" `
                    -ToSession $session `
                    -Force
                Write-Success "wsdd files transferred"
            }

            # Transfer Config Scripts (shared)
            Write-Step "Transferring Config Scripts to VM"
            Copy-Item -Path $localConfigScripts `
                -Destination $VM_TEMP_DIR `
                -ToSession $session `
                -Recurse -Force
            Write-Success "Config Scripts transferred"

            # Transfer Dependencies (shared — just the ODP.NET zip)
            Write-Step "Transferring Dependencies to VM"
            Copy-Item -Path $localDependencies `
                -Destination $VM_TEMP_DIR `
                -ToSession $session `
                -Recurse -Force
            Write-Success "Dependencies transferred"

            # Transfer Config Files (this market's subfolder)
            Write-Step "Transferring Config Files to VM"
            Copy-Item -Path $localConfigFiles `
                -Destination $VM_TEMP_DIR `
                -ToSession $session `
                -Recurse -Force
            Write-Success "Config Files transferred"

            # Transfer generated SQL file
            Write-Step "Transferring SQL file to VM"
            Copy-Item -Path $localSql `
                -Destination $VM_TEMP_DIR `
                -ToSession $session `
                -Force
            Write-Success "SQL file transferred: $client.sql"
        }
        catch {
            Write-Fail "VM preparation failed"
            Write-Warn "Error: $_"
            Write-Warn "Could not complete directory setup or file transfers"
            Remove-Item -Path $localTemp -Recurse -Force -ErrorAction SilentlyContinue
            if ($ExitOnFailure) { exit 1 }
            return
        }

        # ─────────────────────────────────────────────
        #  Execute main script elevated on VM
        # ─────────────────────────────────────────────

        $mainScript = "$VM_TEMP_DIR\Config Scripts\Configure_Domain.ps1"
        $vmConfigFilesDir = "$VM_TEMP_DIR\Config Files\$market"

        Write-Step "Executing AutoConfig script on VM (elevated)"
        Write-Info "Script       : $mainScript"
        Write-Info "Market       : $market"
        Write-Info "Client       : $client"
        Write-Info "CertDir      : $VM_TEMP_DIR\Certs"
        Write-Info "ConfigFiles  : $vmConfigFilesDir"
        Write-Info "SQL file     : $VM_TEMP_DIR\$client.sql"
        if ($isErcot -or $isCaiso) {
            Write-Info "Environment  : $(Get-EnvironmentDisplay $environment)"
        }
        if ($isErcot) {
            Write-Info "WsddDir      : $VM_TEMP_DIR\Wsdd"
        }
        Write-Host ''

        Write-Host '=============================================' -ForegroundColor DarkCyan

        $vmSqlFilePath = "$VM_TEMP_DIR\$client.sql"

        try {
            Invoke-Command -Session $session -ScriptBlock {
                param($scriptPath, $market, $client, $certDir, $sqlFilePath, $configFilesDir, $isErcot, $isCaiso, $environment, $wsddDir)

                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

                $params = @{
                    Market         = $market
                    Client         = $client
                    CertDir        = $certDir
                    ConfigFilesDir = $configFilesDir
                    SqlFilePath    = $sqlFilePath
                }
                if ($isErcot -or $isCaiso) {
                    $params.Environment = $environment
                }
                if ($isErcot) {
                    $params.WsddDir = $wsddDir
                }

                & $scriptPath @params

                if (-not $?) { throw }

            } -ArgumentList $mainScript, $market, $client, "$VM_TEMP_DIR\Certs", $vmSqlFilePath, $vmConfigFilesDir, $isErcot, $isCaiso, $environment, "$VM_TEMP_DIR\Wsdd" -ErrorAction Stop

            Write-Host ''
            Write-Host '=============================================' -ForegroundColor DarkCyan
            Write-Success "Configure_Domain.ps1 completed successfully"
            $script:lastVmSucceeded = $true
        }
        catch {
            Write-Host ''
            Write-Host '=============================================' -ForegroundColor DarkCyan
            Write-Fail "An error occurred during remote execution"
            Write-Warn "Error              : $_"
            # $_ alone only shows the summarized message -- these carry the actual origin (which
            # command, which line, which computer) needed to pinpoint a remote failure without
            # another round-trip.
            if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
                Write-Warn "Position           : $($_.InvocationInfo.PositionMessage.Trim())"
            }
            if ($_.CategoryInfo) {
                Write-Warn "Category           : $($_.CategoryInfo.ToString())"
            }
            if ($_.FullyQualifiedErrorId) {
                Write-Warn "FullyQualifiedId   : $($_.FullyQualifiedErrorId)"
            }
            if ($_.PSObject.Properties.Match('OriginInfo').Count -gt 0 -and $_.OriginInfo -and $_.OriginInfo.PSComputerName) {
                Write-Warn "Origin computer    : $($_.OriginInfo.PSComputerName)"
            }
            if ($_.Exception.InnerException) {
                Write-Warn "Inner exception    : $($_.Exception.InnerException.Message)"
            }
        }
        finally {

            # ─────────────────────────────────────────────
            #  Cleanup
            # ─────────────────────────────────────────────

            Write-Step "Cleaning up"

            # Remove temp files from VM
            try {
                Invoke-Command -Session $session -ScriptBlock {
                    param($dir)
                    if (Test-Path $dir) {
                        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                } -ArgumentList $VM_TEMP_DIR
                Write-Success "Temp files removed from VM"
            }
            catch {
                Write-Warn "Warning: Could not remove temp files from VM. Manual cleanup may be needed at: $VM_TEMP_DIR"
            }

            # Close the PSSession
            if ($session) {
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                Write-Success "PSSession closed"
            }

            # Remove local staging folder
            if (Test-Path $localTemp) {
                Remove-Item -Path $localTemp -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Local staging folder removed"
            }
        }
    }
    catch {
        # Safety net for anything not already caught above (e.g. a failure while staging
        # files, which has no inner try/catch of its own) -- without this, an unhandled
        # terminating error here (StrictMode + $ErrorActionPreference = 'Stop' make most
        # errors terminating) would propagate out of the function and end the entire run,
        # not just this VM's.
        Write-Fail "Unexpected error while configuring $vmRaw"
        Write-Warn "Error: $_"
        if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
            Write-Warn "Position: $($_.InvocationInfo.PositionMessage.Trim())"
        }
        if ($session) {
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }
        if ($ExitOnFailure) { exit 1 }
    }
    finally {
        # Remove local xlsx temp copy created back when this VM's Config was built -- it's
        # only needed up through SQL generation above, so it's safe to clean up
        # unconditionally here regardless of where this VM's run ended.
        if ($Config.XlsxTempDir -and (Test-Path $Config.XlsxTempDir)) {
            Remove-Item -Path $Config.XlsxTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────

if (-not $runningFromApp) { Clear-Host }
Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host '   Cloud Domain AutoConfig Launcher'          -ForegroundColor White
Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host ''

if ($runningFromApp) {

    # ═════════════════════════════════════════════════════════════════════════
    #  App-driven single-VM run — $vmHost/$market/$client/$environment/$adminPass
    #  arrive pre-set by the caller. No prompts; builds one Config and runs it via
    #  Invoke-CloudDomainConfigForVm -ExitOnFailure.
    # ═════════════════════════════════════════════════════════════════════════

    Write-Step 'Collecting configuration inputs'

    # $vmHost, $market, $client, and (for ERCOT) $environment all arrive pre-set by the
    # calling app -- nothing here prompts for them.
    Write-Info "Target VM FQDN: $vmHost"

    $isCaiso = $market -eq 'CAISO'
    $isErcot = $market -eq 'ERCOT'
    $isPjm = $market -eq 'PJM'
    $isMiso = $market -eq 'MISO'
    $certFolder = if ($isCaiso) { 'CAISO-Settlements' } else { $market }

    # Market spreadsheet -- exits on failure (matching this script's behavior before
    # multi-VM support existed), so $workbook is always non-null past this point.
    $workbook = Resolve-MarketWorkbook -Market $market -ExitOnFailure

    # Client-name validation against the spreadsheet's Asset Owners sheet is skipped here --
    # the app is expected to pass an already-valid $client, and this branch never prompts.
    Write-Info "Client set to: $client"

    # ERCOT: domain points to either MOTE (sandbox) or PROD (MIS) at a time. CAISO:
    # USE_MODE is N (Map Stage) or P (Production). $environment arrives pre-set by the
    # calling app for these two markets (same convention as $vmHost/$market/$client/
    # $adminPass) -- only default it to $null here if the app never set it at all
    # (every other market, or a non-ERCOT/non-CAISO app run).
    if (-not (Get-Variable -Name 'environment' -ErrorAction SilentlyContinue)) {
        $environment = $null
    }

    # No silent default -- an app run for either market with a missing or wrong-for-market
    # value fails here instead of falling through to whatever's already in the generic SQL.
    if ($isErcot -and $environment -notin $ercotEnvironments) {
        Write-Fail "ERCOT requires Environment to be MOTE or PROD (got '$environment')"
        exit 1
    }
    if ($isCaiso -and $environment -notin $caisoEnvironments) {
        Write-Fail "CAISO requires Environment to be N or P (got '$environment')"
        exit 1
    }

    if ($isErcot -or $isCaiso) {
        Write-Info "Environment set to: $(Get-EnvironmentDisplay $environment)"
    }

    # Derive paths
    $certSourcePath = if ($isErcot) { Join-Path $NAS3_CERTS_ROOT "$certFolder\$client\$environment" }
    else { Join-Path $NAS3_CERTS_ROOT "$certFolder\$client" }

    $marketConfigFilesFolder = Join-Path $NAS3_CONFIG_FILES $market

    $wsddSourcePath = if ($isErcot) { Join-Path $NAS3_CERTS_ROOT "$market\$client\wsdd\$environment" }
    else { $null }

    Write-Host ''
    Write-Info 'Summary:'
    Write-Info "  VM FQDN      : $vmHost"
    Write-Info "  Cert source  : $certSourcePath"
    Write-Info "  Config Files : $marketConfigFilesFolder"
    Write-Info "  Spreadsheet  : $($workbook.LocalPath)"
    Write-Host ''

    $vmConfig = [PSCustomObject]@{
        Index                   = 1
        Total                   = 1
        VmRaw                   = $vmHost
        VmHost                  = $vmHost
        Market                  = $market
        Client                  = $client
        Environment             = $environment
        IsCaiso                 = $isCaiso
        IsErcot                 = $isErcot
        IsPjm                   = $isPjm
        IsMiso                  = $isMiso
        CertSourcePath          = $certSourcePath
        MarketConfigFilesFolder = $marketConfigFilesFolder
        WsddSourcePath          = $wsddSourcePath
        WorkbookLocalPath       = $workbook.LocalPath
        XlsxTempDir             = $workbook.TempDir
    }

    Invoke-CloudDomainConfigForVm -Config $vmConfig -AdminPass $adminPass -ExitOnFailure

    # No trailing "Done" banner here -- the app owns its own window/UI lifecycle.

}
else {

    # ═════════════════════════════════════════════════════════════════════════
    #  Interactive multi-VM run — collects Market/Client for every queued VM up
    #  front (Read-VmInputs), then one shared admin password, then runs each VM
    #  through Invoke-CloudDomainConfigForVm; a failed VM doesn't stop the rest.
    # ═════════════════════════════════════════════════════════════════════════

    $vmListRaw = Prompt-NotEmpty '  Enter VM name(s) (e.g. RTO-QA-RWE-TEST, RTO-QA-OGE-TEST)'
    $vmList = @($vmListRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    if ($vmList.Count -eq 0) {
        Write-Fail 'No VM names were entered.'
        exit 1
    }

    Write-Info "Queued $($vmList.Count) VM(s):"
    foreach ($v in $vmList) { Write-Info "  - $v" }

    # Pre-populate results so a VM that fails during input collection (before it ever reaches
    # actual execution) still shows up as a failure in the final summary below.
    $results = [ordered]@{}
    foreach ($v in $vmList) { $results[$v] = $false }

    $vmConfigs = @()
    for ($i = 0; $i -lt $vmList.Count; $i++) {
        $cfg = Read-VmInputs -VmRaw $vmList[$i] -Index ($i + 1) -Total $vmList.Count
        if ($cfg) { $vmConfigs += $cfg }
    }

    if ($vmConfigs.Count -eq 0) {
        Write-Host ''
        Write-Fail 'No VMs made it through input collection -- nothing to configure.'
    }
    else {
        Write-Step 'Preparing VM admin credentials'
        Write-Host "  Enter the admin password to use for all queued VMs (username will be .\Administrator on each)" -ForegroundColor Gray
        $adminPass = Read-Host -Prompt '  Password' -AsSecureString

        foreach ($cfg in $vmConfigs) {
            $script:lastVmSucceeded = $false
            Invoke-CloudDomainConfigForVm -Config $cfg -AdminPass $adminPass
            $results[$cfg.VmRaw] = $script:lastVmSucceeded
        }
    }

    # ─────────────────────────────────────────────
    #  Final summary — so failed VMs are easy to spot and retry
    # ─────────────────────────────────────────────

    Write-Host ''
    Write-Host '=============================================' -ForegroundColor DarkCyan
    Write-Host '   Summary'                                     -ForegroundColor White
    Write-Host '=============================================' -ForegroundColor DarkCyan
    foreach ($vmRaw in $results.Keys) {
        if ($results[$vmRaw]) {
            Write-Success "$vmRaw"
        }
        else {
            Write-Fail "$vmRaw"
        }
    }

    Write-Host ''
    Write-Host '=============================================' -ForegroundColor DarkCyan
    Write-Host '   Done. Type exit to close this window.'      -ForegroundColor White
    Write-Host '=============================================' -ForegroundColor DarkCyan
}
