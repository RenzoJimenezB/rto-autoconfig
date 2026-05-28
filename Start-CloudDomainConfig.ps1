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
    Location : \\nas3\shared\Cloud Domain AutoConfig\Start-CloudDomainConfig.ps1
    Launcher : \\nas3\shared\Cloud Domain AutoConfig\Start-CloudDomainConfig.bat
    Author   : R. Jimenez
    Updated  : 2026-05-27
#>

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
$NAS3_AUTOCONFIG = '\\nas3\shared\Cloud Domain AutoConfig'
$NAS3_SQL_ROOT = '\\nas3\shared\Cloud Domain AutoConfig\SQL'

$VM_DOMAIN_SUFFIX = '.cloud.pci'
$VM_TEMP_DIR = 'C:\Temp\CloudDomainConfig'   # temp dir created on the VM

# Extensions to copy from the client cert folder
$CERT_EXTENSIONS = @('*.pfx', '*.p12', '*.ppk', '*.cer', '*.crt', '*.txt')

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

function Prompt-NotEmpty {
    param([string]$Label)
    do {
        $value = Read-Host $Label
        $value = $value.Trim()
        if (-not $value) { Write-Host "  Value cannot be empty. Please try again." -ForegroundColor Yellow }
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
    $vmRaw = Prompt-NotEmpty 'Enter VM name (e.g. RTO-QA-RWE-TEST)'
    $vmHost = ($vmRaw.Trim().ToLower()) + $VM_DOMAIN_SUFFIX
}
Write-Host "  Target VM FQDN: $vmHost" -ForegroundColor Gray

# Valid markets and input validation
$validMarkets = @('CAISO', 'ERCOT', 'ISONE', 'MISO', 'NYISO', 'PJM', 'SPPIM')

if (-not $runningFromApp) {
    do {
        $market = (Prompt-NotEmpty 'Enter Market name (CAISO, ERCOT, ISONE, MISO, NYISO, PJM, SPPIM)').Trim().ToUpper()
        if ($market -notin $validMarkets) {
            Write-Warning "Invalid market '$market'. Please enter one of: $($validMarkets -join ', ')"
        }
    } while ($market -notin $validMarkets)
}

$certFolder = if ($market -eq 'CAISO') { 'CAISO-Settlements' } else { $market }

# Load canonical client list from file
if (-not $runningFromApp) {
    $validClients = Get-Content "$PSScriptRoot\clients.txt" | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
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
        $raw = (Prompt-NotEmpty 'Enter Client name (e.g. PAC, PSE-MT, NVE-MT)').Trim()
        $upper = $raw.ToUpper()

        $exactMatch = $validClients | Where-Object { $_.ToUpper() -eq $upper }
        if ($exactMatch) {
            $client = $exactMatch
            break
        }

        $clientMatches = @(Find-ClientMatches -RawEntry $raw -ClientList $validClients)

        if ($clientMatches.Count -eq 1) {
            $confirm = Prompt-NotEmpty "Did you mean '$($clientMatches[0])'? (Y/N)"
            if ($confirm.Trim().ToUpper() -eq 'Y') {
                $client = $clientMatches[0]
            }
            else {
                Write-Warning "No client selected. Please try again."
            }
        }
        elseif ($clientMatches.Count -gt 1) {
            Write-Host "Did you mean one of these?" -ForegroundColor Cyan
            $i = 1
            foreach ($m in $clientMatches) { Write-Host "  [$i] $m"; $i++ }
            Write-Host "  [0] None of these"
            $choice = Prompt-NotEmpty "Enter number"
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $clientMatches.Count) {
                $client = $clientMatches[$idx]
            }
            else {
                Write-Warning "No client selected. Please try again."
            }
        }
        else {
            Write-Warning "No matches found for '$raw'. Please check the name and try again."
        }

    } while (-not $client)
}
Write-Host "Client set to: $client" -ForegroundColor Green

# Derive paths
$certSourcePath = Join-Path $NAS3_CERTS_ROOT "$certFolder\$client"
$autoConfigZip = Join-Path $NAS3_AUTOCONFIG  "AutoConfig-$market.zip"
$sqlSourcePath = Join-Path $NAS3_SQL_ROOT "$market\$client.sql"

Write-Host ''
Write-Host '  Summary:' -ForegroundColor DarkGray
Write-Host "    VM FQDN    : $vmHost"          -ForegroundColor DarkGray
Write-Host "    Cert source: $certSourcePath"   -ForegroundColor DarkGray
Write-Host "    AutoConfig : $autoConfigZip"    -ForegroundColor DarkGray
Write-Host "    SQL file   : $sqlSourcePath"    -ForegroundColor DarkGray
Write-Host ''

# ─────────────────────────────────────────────
#  STEP 2 — Validate NAS3 paths
# ─────────────────────────────────────────────

Write-Step 'Validating NAS3 paths'

if (-not (Test-Path $certSourcePath)) {
    Write-Fail "Cert folder not found: $certSourcePath"
    Write-Host "  Check that Market and Client names are correct." -ForegroundColor Yellow
    exit 1
}
Write-Success "Cert folder found: $certSourcePath"

if (-not (Test-Path $autoConfigZip)) {
    Write-Fail "AutoConfig zip not found: $autoConfigZip"
    Write-Host "  Expected: AutoConfig-$market.zip in $NAS3_AUTOCONFIG" -ForegroundColor Yellow
    exit 1
}
Write-Success "AutoConfig zip found: $autoConfigZip"

if (-not (Test-Path $sqlSourcePath)) {
    Write-Fail "SQL file not found: $sqlSourcePath"
    Write-Host "  Expected: $client.sql under $NAS3_SQL_ROOT\$market\" -ForegroundColor Yellow
    exit 1
}
Write-Success "SQL file found: $sqlSourcePath"

# Collect cert files
$certFiles = @()
foreach ($ext in $CERT_EXTENSIONS) {
    $certFiles += Get-ChildItem -Path $certSourcePath -Filter $ext -File -ErrorAction SilentlyContinue
}

if ($certFiles.Count -eq 0) {
    Write-Fail "No cert/credential files found in $certSourcePath"
    Write-Host "  Expected extensions: pfx, p12, ppk, cer, crt, txt" -ForegroundColor Yellow
    exit 1
}
Write-Success "$($certFiles.Count) file(s) found in cert folder:"
foreach ($f in $certFiles) {
    Write-Host "    - $($f.Name)" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────
#  STEP 3 — Test WinRM / WSMan connectivity
# ─────────────────────────────────────────────

Write-Step "Testing WinRM connectivity to $vmHost"

try {
    $wsmanResult = Test-WSMan -ComputerName $vmHost -ErrorAction Stop
    Write-Success "WinRM responded on $vmHost"
    Write-Host "    Vendor  : $($wsmanResult.ProductVendor)"  -ForegroundColor DarkGray
    Write-Host "    Version : $($wsmanResult.ProductVersion)" -ForegroundColor DarkGray
}
catch {
    Write-Fail "Cannot reach $vmHost via WinRM."
    Write-Host "  Error: $_" -ForegroundColor Yellow
    Write-Host "  Verify the VM name is correct and that you are on the PCI network." -ForegroundColor Yellow
    exit 1
}

# ─────────────────────────────────────────────
#  STEP 4 — Prompt for admin credentials
# ─────────────────────────────────────────────

# Write-Step 'Prompting for VM admin credentials'
# Write-Host '  Enter the privileged admin account for the VM (e.g. DOMAIN\Administrator)' -ForegroundColor Gray
# $adminCred = Get-Credential -Message "Admin credentials for $vmHost"

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

# Copy cert files
$localCertsDir = Join-Path $localTemp 'Certs'
New-Item -ItemType Directory -Path $localCertsDir -Force | Out-Null
foreach ($f in $certFiles) {
    Copy-Item -Path $f.FullName -Destination $localCertsDir
}
Write-Success "Copied $($certFiles.Count) cert file(s) to staging"

# Copy AutoConfig zip
$localZip = Join-Path $localTemp (Split-Path $autoConfigZip -Leaf)
Copy-Item -Path $autoConfigZip -Destination $localZip
Write-Success "Copied AutoConfig zip to staging"

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
    Write-Host "  Error: $_" -ForegroundColor Yellow
    Write-Host "  Check credentials and that PSRemoting is enabled on the VM." -ForegroundColor Yellow
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
    } -ArgumentList $VM_TEMP_DIR
    Write-Success "Temp directory ready on VM"

    # Transfer cert files
    Write-Step "Transferring cert files to VM"
    Copy-Item -Path "$localCertsDir\*" `
        -Destination "$VM_TEMP_DIR\Certs" `
        -ToSession $session `
        -Force
    Write-Success "Cert files transferred"

    # Transfer AutoConfig zip
    Write-Step "Transferring AutoConfig zip to VM"
    Copy-Item -Path $localZip `
        -Destination $VM_TEMP_DIR `
        -ToSession $session `
        -Force
    Write-Success "AutoConfig zip transferred"

    # Transfer SQL file
    Write-Step "Transferring SQL file to VM"
    Copy-Item -Path $localSql `
        -Destination $VM_TEMP_DIR `
        -ToSession $session `
        -Force
    Write-Success "SQL file transferred: $client.sql"

    # ─────────────────────────────────────────────
    #  STEP 7 — Extract zip and find main script
    # ─────────────────────────────────────────────

    Write-Step "Extracting AutoConfig zip on VM"
    $mainScript = Invoke-Command -Session $session -ScriptBlock {
        param($dir, $zipName)

        $zipPath = Join-Path $dir $zipName
        $extractDir = Join-Path $dir 'AutoConfig'

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

        $ps1 = Get-ChildItem -Path $extractDir -Filter 'Configure_Domain.ps1' -File -Recurse |
        Select-Object -First 1

        if (-not $ps1) {
            throw "Configure_Domain.ps1 not found inside the AutoConfig zip."
        }
        return $ps1.FullName
    } -ArgumentList $VM_TEMP_DIR, (Split-Path $localZip -Leaf)

    Write-Success "Extracted. Main script: $mainScript"

    # ─────────────────────────────────────────────
    #  STEP 8 — Execute main script elevated on VM
    # ─────────────────────────────────────────────

    Write-Step "Executing AutoConfig script on VM (elevated)"
    Write-Host "  Script    : $mainScript"              -ForegroundColor DarkGray
    Write-Host "  Market    : $market"                  -ForegroundColor DarkGray
    Write-Host "  Client    : $client"                  -ForegroundColor DarkGray
    Write-Host "  CertDir   : $VM_TEMP_DIR\Certs"       -ForegroundColor DarkGray
    Write-Host "  SQL file  : $VM_TEMP_DIR\$client.sql" -ForegroundColor DarkGray
    Write-Host ''

    $result = Invoke-Command -Session $session -ScriptBlock {
        param($scriptPath, $market, $client, $certDir, $sqlFilePath)

        & $scriptPath -Market      $market `
            -Client      $client `
            -CertDir     $certDir `
            -SqlFilePath $sqlFilePath | Out-Null

        return $LASTEXITCODE
    } -ArgumentList $mainScript, $market, $client, "$VM_TEMP_DIR\Certs", "$VM_TEMP_DIR\$client.sql"


    if ($result -eq 0 -or $null -eq $result) {
        Write-Success "Configure_Domain.ps1 completed successfully"
    }
    else {
        Write-Fail "Configure_Domain.ps1 finished with exit code: $result"
        Write-Host "  Review logs on the VM for details." -ForegroundColor Yellow
    }
}
catch {
    Write-Fail "An error occurred during remote execution."
    Write-Host "  Error: $_" -ForegroundColor Yellow
    
    Write-Host "Type: $($_.Exception.GetType().FullName)"
    Write-Host "Message: $($_.Exception.Message)"
    Write-Host "Stack:"
    Write-Host $_.ScriptStackTrace
}
finally {

    # ─────────────────────────────────────────────
    #  STEP 9 — Cleanup
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
        Write-Host "  Warning: Could not remove temp files from VM. Manual cleanup may be needed at: $VM_TEMP_DIR" -ForegroundColor Yellow
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
    Write-Host '   Done. Press any key to close.'             -ForegroundColor White
    Write-Host '=============================================' -ForegroundColor DarkCyan
}