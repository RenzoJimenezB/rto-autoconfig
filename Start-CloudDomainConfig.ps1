#Requires -Version 5.1
<#
.SYNOPSIS
    Cloud Domain AutoConfig Launcher
    Pulls certs from NAS3, transfers them to the target VM via PSRemoting,
    and executes the AutoConfig script elevated on the VM.

.DESCRIPTION
    Run this from any local Windows 11 machine that has access to NAS3.
    Launch using Start-CloudDomainConfig.bat (located in the same folder),
    not by invoking the script directly.

.NOTES
    Location : \\nas3\Client-Certificates\AutoConfig\Start-CloudDomainConfig.ps1
    Launcher : \\nas3\Client-Certificates\AutoConfig\Start-CloudDomainConfig.bat
    Author   : Renzo Jimenez
    Created  : 2026-05-25
#>

# ── Console ───────────────────────────────────────────────────────────────────
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'White'
Clear-Host

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
$NAS3_SQL_ROOT = '\\nas3\Client-Certificates\AutoConfig\SQL'

$VM_DOMAIN_SUFFIX = '.cloud.pci'
$VM_TEMP_DIR = 'C:\Temp\CloudDomainConfig'   # temp dir created on the VM

# Extensions to copy from the client cert folder
$CERT_EXTENSIONS = @('.pfx', '.p12', '.ppk', '.cer', '.crt', '.id', '.txt')

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

function Prompt-NotEmpty {
    param([string]$Label)
    do {
        $value = Read-Host $Label
        $value = $value.Trim()
        if (-not $value) { Write-Warn "Value cannot be empty. Please try again." }
    } while (-not $value)
    return $value
}

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────

if (-not $runningFromApp) { Clear-Host }
Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host '   Cloud Domain AutoConfig Launcher'          -ForegroundColor White
Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host ''

# ─────────────────────────────────────────────
#  STEP 1 — Collect inputs
# ─────────────────────────────────────────────

Write-Step 'Collecting configuration inputs'

# VM name — injected from app or prompted if running standalone
if (-not $runningFromApp) {
    $vmRaw = Prompt-NotEmpty '  Enter VM name (e.g. RTO-QA-RWE-TEST)'
    $vmHost = ($vmRaw.Trim().ToLower()) + $VM_DOMAIN_SUFFIX
}
Write-Info "Target VM FQDN: $vmHost"

# Valid markets and input validation
$validMarkets = @('CAISO', 'ERCOT', 'ISONE', 'MISO', 'NYISO', 'PJM', 'SPPIM')

if (-not $runningFromApp) {
    do {
        $market = (Prompt-NotEmpty '  Enter Market name (CAISO, ERCOT, ISONE, MISO, NYISO, PJM, SPPIM)').Trim().ToUpper()
        if ($market -notin $validMarkets) {
            Write-Warn "Invalid market '$market'. Please enter one of: $($validMarkets -join ', ')"
        }
    } while ($market -notin $validMarkets)
}

$isCaiso = $market -eq 'CAISO'
$isErcot = $market -eq 'ERCOT'

# CAISO only:
$noSettlementsClients = @(
    'AVISTA-TO',
    'SMUD',
    'PAC',
    'PNM-EESC'
)

$certFolder = if ($isCaiso) { 'CAISO-Settlements' } else { $market }

# Load canonical client list from file
if (-not $runningFromApp) {
    $validClients = Get-Content "$PSScriptRoot\Clients\${market}.txt" | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
}

# Valid clients and input validation
function Find-ClientMatches {
    param([string]$RawEntry, [string[]]$ClientList)

    $normalized = $RawEntry.ToUpper().Replace('-', '').Replace(' ', '').Replace('_', '')

    return $ClientList | Where-Object {
        $canonical = $_.ToUpper().Replace('-', '').Replace(' ', '').Replace('_', '')
        $canonical -like "*$normalized*" -or $normalized -like "*$canonical*"
    }
}

if (-not $runningFromApp) {
    $client = $null
    do {
        $raw = (Prompt-NotEmpty '  Enter Client name (e.g. OGE, PSE, RWE)').Trim()
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
}
Write-Info "Client set to: $client"

# ERCOT: domain points to either MOTE (sandbox) or PROD (MIS) at a time
$ercotEnvironments = @('MOTE', 'PROD')
$environment = $null

if ($isErcot -and -not $runningFromApp) {
    do {
        $environment = (Prompt-NotEmpty '  Enter Environment (MOTE or PROD)').Trim().ToUpper()
        if ($environment -notin $ercotEnvironments) {
            Write-Warn "Invalid environment '$environment'. Please enter MOTE or PROD"
        }
    } while ($environment -notin $ercotEnvironments)
}
if ($isErcot) {
    Write-Info "Environment set to: $environment"
}

# Derive paths
$certSourcePath = if ($isErcot) { Join-Path $NAS3_CERTS_ROOT "$certFolder\$client\$environment" }
else { Join-Path $NAS3_CERTS_ROOT "$certFolder\$client" }

$autoConfigFolder = Join-Path $NAS3_AUTOCONFIG  "AutoConfig-$market"

$sqlSourcePath = if ($isErcot) { Join-Path $NAS3_SQL_ROOT "$market\$environment\$client.sql" }
else { Join-Path $NAS3_SQL_ROOT "$market\$client.sql" }

$wsddSourcePath = if ($isErcot) { Join-Path $NAS3_CERTS_ROOT "$market\$client\wsdd\$environment" }
else { $null }

Write-Host ''
Write-Info 'Summary:'
Write-Info "  VM FQDN    : $vmHost"
Write-Info "  Cert source: $certSourcePath"
Write-Info "  AutoConfig : $autoConfigFolder"
Write-Info "  SQL file   : $sqlSourcePath"
Write-Host ''

# ─────────────────────────────────────────────
#  STEP 2 — Validate NAS3 paths
# ─────────────────────────────────────────────

Write-Step 'Validating NAS3 paths'

# CAISO and ERCOT both transfer real cert files despite being "keystore markets" —
# CAISO's SFTP settlement certs and ERCOT's per-AO certs (already in clientTruststore.jks,
# staged again here purely so cert/wsdd pairs sit together for manual troubleshooting).
# They share the same folder/extension-filter validation; only two things differ:
# ERCOT's certs live nested under CERT-XXXX subfolders (needs -Recurse), and CAISO
# sometimes ships extensionless files paired with a .ppk/.txt companion.
$skipSftpCerts = $isCaiso -and ($noSettlementsClients -contains $client)
$certLabel = if ($isCaiso) { 'SFTP cert' } else { 'cert' }
$certFiles = @()

if ($skipSftpCerts) {
    Write-Info "${client}: CAISO Settlements not applicable. SFTP certs not required"
}
else {
    if (-not (Test-Path $certSourcePath)) {
        Write-Fail "$certLabel folder not found: $certSourcePath"
        if ($isErcot) { Write-Warn "Check that Market, Client, and Environment names are correct" }
        else { Write-Warn "Check that Market and Client names are correct" }
        exit 1
    }
    Write-Success "$certLabel folder found: $certSourcePath"

    $allFiles = Get-ChildItem -Path $certSourcePath -File -Recurse:$isErcot -ErrorAction SilentlyContinue
    $certFiles = @($allFiles | Where-Object { $_.Extension -in $CERT_EXTENSIONS })

    if ($isCaiso) {
        # Extensionless files paired with a .ppk/.txt companion of the same basename are certs too
        $ppkBasenames = @($allFiles | Where-Object { $_.Extension -eq '.ppk' } | ForEach-Object { $_.BaseName })
        $txtBasenames = @($allFiles | Where-Object { $_.Extension -eq '.txt' } | ForEach-Object { $_.BaseName })
        $basenamesToCheck = @($ppkBasenames) + @($txtBasenames) | Sort-Object -Unique
        $extensionlessFiles = $allFiles | Where-Object { $_.Extension -eq '' -and $_.BaseName -in $basenamesToCheck }
        $certFiles = @(@($certFiles) + @($extensionlessFiles) | Sort-Object Name -Unique)
    }

    if ($certFiles.Count -eq 0) {
        Write-Fail "No $certLabel files found in: $certSourcePath"
        if ($isErcot) { Write-Warn "Check that CERT subfolders under $certSourcePath contain cert files" }
        elseif ($isCaiso) { Write-Warn "Expected extensions: pfx, p12, ppk, cer, crt, txt" }
        else { Write-Warn "Check that the cert directory is populated for $market\$client" }
        exit 1
    }
    Write-Success "$($certFiles.Count) $certLabel file(s) found:"
    foreach ($f in $certFiles) {
        Write-Info "  - $($f.Name)"
    }
}

# ERCOT: wsdd files for the selected environment
$wsddFiles = @()
if ($isErcot) {
    if (-not (Test-Path $wsddSourcePath)) {
        Write-Fail "wsdd folder not found: $wsddSourcePath"
        Write-Warn "Expected: Client-Certificates\ERCOT\$client\wsdd\$environment\"
        exit 1
    }
    $wsddFiles = @(Get-ChildItem -Path $wsddSourcePath -File -Filter '*.wsdd' -ErrorAction SilentlyContinue)
    if ($wsddFiles.Count -eq 0) {
        Write-Fail "No .wsdd files found in: $wsddSourcePath"
        exit 1
    }
    Write-Success "$($wsddFiles.Count) wsdd file(s) found:"
    foreach ($f in $wsddFiles) {
        Write-Info "  - $($f.Name)"
    }
}

if (-not (Test-Path $autoConfigFolder)) {
    Write-Fail "AutoConfig folder not found: $autoConfigFolder"
    Write-Warn "Expected: AutoConfig-$market folder in $NAS3_AUTOCONFIG"
    exit 1
}
Write-Success "AutoConfig folder found: $autoConfigFolder"

if (-not (Test-Path $sqlSourcePath)) {
    Write-Fail "SQL file not found: $sqlSourcePath"
    Write-Warn "Expected: $client.sql under $NAS3_SQL_ROOT\$market\$environment\"
    exit 1
}
Write-Success "SQL file found: $sqlSourcePath"

# ─────────────────────────────────────────────
#  STEP 3 — Test WinRM / WSMan connectivity
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
    exit 1
}

# ─────────────────────────────────────────────
#  STEP 4 — Prompt for admin credentials
# ─────────────────────────────────────────────

Write-Step 'Preparing VM admin credentials'
if (-not $runningFromApp) {
    Write-Host "  Enter the admin password for $vmHost (username will be .\Administrator)" -ForegroundColor Gray
    $adminPass = Read-Host -Prompt '  Password' -AsSecureString
}
$adminCred = New-Object System.Management.Automation.PSCredential("$vmHost\Administrator", $adminPass)

# ─────────────────────────────────────────────
#  STEP 5 — Stage files in a local temp folder
# ─────────────────────────────────────────────

Write-Step 'Staging files in local temp folder'

$localTemp = Join-Path $env:TEMP "CloudDomainConfig_$(Get-Random)"
New-Item -ItemType Directory -Path $localTemp -Force | Out-Null
Write-Success "Local staging folder: $localTemp"

# Copy cert files (every market stages certs except CAISO clients with no settlements)
if (-not $skipSftpCerts) {
    $localCertsDir = Join-Path $localTemp 'Certs'
    New-Item -ItemType Directory -Path $localCertsDir -Force | Out-Null
    foreach ($f in $certFiles) {
        Copy-Item -Path $f.FullName -Destination $localCertsDir
    }
    Write-Success "Copied $($certFiles.Count) ${certLabel} file(s) to staging"
}

# ERCOT: copy this client's env-specific wsdd files
if ($isErcot) {
    $localWsddDir = Join-Path $localTemp 'Wsdd'
    New-Item -ItemType Directory -Path $localWsddDir -Force | Out-Null
    foreach ($f in $wsddFiles) {
        Copy-Item -Path $f.FullName -Destination $localWsddDir
    }
    Write-Success "Copied $($wsddFiles.Count) wsdd file(s) to staging"
}

# Copy AutoConfig folder
$localAutoConfig = Join-Path $localTemp "AutoConfig-$market"
Copy-Item -Path $autoConfigFolder -Destination $localAutoConfig -Recurse
Write-Success "Copied AutoConfig folder to staging"

# Copy SQL file
$localSql = Join-Path $localTemp "$client.sql"
Copy-Item -Path $sqlSourcePath -Destination $localSql
Write-Success "Copied SQL file to staging: $client.sql"

# ─────────────────────────────────────────────
#  STEP 6 — Establish PSSession and transfer files
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
    # Cleanup local temp
    Remove-Item -Path $localTemp -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
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

    if (-not $skipSftpCerts) {
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

    # Transfer AutoConfig folder
    Write-Step "Transferring AutoConfig folder to VM"
    Copy-Item -Path $localAutoConfig `
        -Destination $VM_TEMP_DIR `
        -ToSession $session `
        -Recurse -Force
    Write-Success "AutoConfig folder transferred"

    # Transfer SQL file
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
    exit 1
}

# ─────────────────────────────────────────────
#  STEP 7 — Execute main script elevated on VM
# ─────────────────────────────────────────────

$mainScript = "$VM_TEMP_DIR\AutoConfig-$market\Configure_Domain.ps1"

Write-Step "Executing AutoConfig script on VM (elevated)"
Write-Info "Script    : $mainScript"
Write-Info "Market    : $market"
Write-Info "Client    : $client"
Write-Info "CertDir   : $VM_TEMP_DIR\Certs"
Write-Info "SQL file  : $VM_TEMP_DIR\$client.sql"
if ($isErcot) {
    Write-Info "Environment: $environment"
    Write-Info "WsddDir   : $VM_TEMP_DIR\Wsdd"
}
Write-Host ''

Write-Host '=============================================' -ForegroundColor DarkCyan

try {
    Invoke-Command -Session $session -ScriptBlock {
        param($scriptPath, $market, $client, $certDir, $sqlFilePath, $isErcot, $environment, $wsddDir)

        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

        $params = @{
            Market      = $market
            Client      = $client
            CertDir     = $certDir
            SqlFilePath = $sqlFilePath
        }
        if ($isErcot) {
            $params.Environment = $environment
            $params.WsddDir = $wsddDir
        }

        & $scriptPath @params

        if (-not $?) { throw }

    } -ArgumentList $mainScript, $market, $client, "$VM_TEMP_DIR\Certs", "$VM_TEMP_DIR\$client.sql", $isErcot, $environment, "$VM_TEMP_DIR\Wsdd" -ErrorAction Stop

    Write-Host ''
    Write-Host '=============================================' -ForegroundColor DarkCyan
    Write-Success "Configure_Domain.ps1 completed successfully"
}
catch {
    Write-Host ''
    Write-Host '=============================================' -ForegroundColor DarkCyan
    Write-Fail "An error occurred during remote execution"
    Write-Warn "Error: $_"
} 
finally {

    # ─────────────────────────────────────────────
    #  STEP 8 — Cleanup
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

if (-not $runningFromApp) {
    Write-Host ''
    Write-Host '=============================================' -ForegroundColor DarkCyan
    Write-Host '   Done. Type exit to close this window.'             -ForegroundColor White
    Write-Host '=============================================' -ForegroundColor DarkCyan
}