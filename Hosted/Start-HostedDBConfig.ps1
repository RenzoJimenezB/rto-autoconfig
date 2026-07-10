#Requires -Version 5.1
<#
.SYNOPSIS
    Hosted DB AutoConfig

.DESCRIPTION
    Runs entirely on the local machine. Connects directly to a client's hosted
    database using a user-supplied Data Source and credentials, then executes
    the generic market SQL and client-specific SQL pulled from NAS3.

    Unlike Start-CloudDomainConfig.ps1, this script does NOT connect to a VM:
    there is no PSRemoting, no cert staging/transfer, and no service restart.
    Because cloud domain access may not be granted to every user, the operator
    is instructed to manually perform a rolling restart once the script completes.

    LOWER ENVIRONMENTS ONLY. Do not run this against PRODUCTION.

.NOTES
    Location : \\nas3\Client-Certificates\AutoConfig\Hosted\Start-HostedDBConfig.ps1
    Launcher : \\nas3\Client-Certificates\AutoConfig\Hosted\Start-HostedDBConfig.bat
    Author   : Renzo Jimenez
    Created  : 2026-07-07
#>

# ── Console ───────────────────────────────────────────────────────────────────
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'White'
Clear-Host

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────
#  CONFIGURATION — adjust these paths if needed
# ─────────────────────────────────────────────

$NAS3_AUTOCONFIG_ROOT = '\\nas3\Client-Certificates\AutoConfig'
$NAS3_CLIENTS_ROOT = Join-Path $NAS3_AUTOCONFIG_ROOT 'Clients'
$NAS3_HOSTED_ROOT = Join-Path $NAS3_AUTOCONFIG_ROOT 'Hosted'
$NAS3_SQL_ROOT = Join-Path $NAS3_HOSTED_ROOT 'SQL'
$ORACLE_DLL_PATH = 'C:\oracle\odp.net\managed\common\Oracle.ManagedDataAccess.dll'

$validMarkets = @('CAISO', 'ERCOT', 'ISONE', 'MISO', 'NYISO', 'PJM', 'SPPIM')

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

function ConvertTo-PlainText {
    param([System.Security.SecureString]$SecureString)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Find-ClientMatches {
    param([string]$RawEntry, [string[]]$ClientList)

    $normalized = $RawEntry.ToUpper().Replace('-', '').Replace(' ', '').Replace('_', '')

    return $ClientList | Where-Object {
        $canonical = $_.ToUpper().Replace('-', '').Replace(' ', '').Replace('_', '')
        $canonical -like "*$normalized*" -or $normalized -like "*$canonical*"
    }
}

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────

Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host '   Hosted DB AutoConfig'                        -ForegroundColor White
Write-Host '=============================================' -ForegroundColor DarkCyan

# ─────────────────────────────────────────────
#  STEP 0 — Lower environment warning
# ─────────────────────────────────────────────

Write-Host ''
Write-Host '*** LOWER ENVIRONMENTS ONLY ***' -ForegroundColor Black -BackgroundColor Yellow
Write-Warn 'This script connects directly to a hosted DB using the credentials you provide.'
Write-Warn 'It must ONLY be run against DEV/TEST/QA. Do NOT run this against PRODUCTION.'
Write-Host ''

$proceed = Prompt-NotEmpty '  Type Y to confirm this is a LOWER environment and continue (anything else aborts)'
if ($proceed.Trim().ToUpper() -ne 'Y') {
    Write-Fail 'Aborted by user.'
    exit 1
}

# ─────────────────────────────────────────────
#  STEP 1 — Collect inputs
# ─────────────────────────────────────────────

Write-Step 'Collecting configuration inputs'

do {
    $market = (Prompt-NotEmpty '  Enter Market name (CAISO, ERCOT, ISONE, MISO, NYISO, PJM, SPPIM)').Trim().ToUpper()
    if ($market -notin $validMarkets) {
        Write-Warn "Invalid market '$market'. Please enter one of: $($validMarkets -join ', ')"
    }
} while ($market -notin $validMarkets)

$clientListPath = Join-Path $NAS3_CLIENTS_ROOT "${market}.txt"
if (-not (Test-Path $clientListPath)) {
    Write-Fail "Client list not found: $clientListPath"
    exit 1
}
$validClients = Get-Content $clientListPath | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }

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
Write-Info "Client set to: $client"

$dataSource = Prompt-NotEmpty '  Enter DB Data Source (e.g. host:port/service)'
$dbUser = Prompt-NotEmpty '  Enter DB User'
Write-Host '  Enter DB Password' -ForegroundColor Gray
$dbPasswordSecure = Read-Host -Prompt '  Password' -AsSecureString

# Derive paths
$genericSqlPath = Join-Path $NAS3_SQL_ROOT "Generic\generic_${market}_HOSTED.sql"
$clientSqlPath = Join-Path $NAS3_SQL_ROOT "$market\$client.sql"

Write-Host ''
Write-Info 'Summary:'
Write-Info "  Market       : $market"
Write-Info "  Client       : $client"
Write-Info "  Data Source  : $dataSource"
Write-Info "  DB User      : $dbUser"
Write-Info "  Generic SQL  : $genericSqlPath"
Write-Info "  Client SQL   : $clientSqlPath"
Write-Host ''

# ─────────────────────────────────────────────
#  STEP 2 — Validate NAS3 SQL paths
# ─────────────────────────────────────────────

Write-Step 'Validating NAS3 SQL paths'

if (-not (Test-Path $genericSqlPath)) {
    Write-Fail "Generic SQL file not found: $genericSqlPath"
    Write-Warn "Expected: generic_${market}_HOSTED.sql under $NAS3_SQL_ROOT\Generic\"
    exit 1
}
Write-Success "Generic SQL file found: $genericSqlPath"

if (-not (Test-Path $clientSqlPath)) {
    Write-Fail "Client SQL file not found: $clientSqlPath"
    Write-Warn "Expected: $client.sql under $NAS3_SQL_ROOT\$market\$client\"
    exit 1
}
Write-Success "Client SQL file found: $clientSqlPath"

# ─────────────────────────────────────────────
#  STEP 3 — Load Oracle ODP.NET
# ─────────────────────────────────────────────

Write-Step 'Loading Oracle ODP.NET managed driver'

if (-not (Test-Path -PathType Leaf $ORACLE_DLL_PATH)) {
    Write-Fail "Oracle.ManagedDataAccess.dll not found at: $ORACLE_DLL_PATH"
    Write-Warn "Install the Oracle ODP.NET managed driver on this machine, or update `$ORACLE_DLL_PATH in this script."
    exit 1
}

Add-Type -Path $ORACLE_DLL_PATH
Write-Success "ODP.NET assembly loaded"

# ─────────────────────────────────────────────
#  STEP 4 — Connect and execute SQL
# ─────────────────────────────────────────────

Write-Step 'Connecting to database'

$dbPasswordPlain = ConvertTo-PlainText $dbPasswordSecure
$conn = $null

try {
    $constr = "User Id=$dbUser;Password=$dbPasswordPlain;Data Source=$dataSource;"

    $conn = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($constr)
    $conn.Open()
    Write-Success 'Connected to DB successfully'

    Write-Step 'Executing SQL scripts'

    $genericSqlBlock = Get-Content -Path $genericSqlPath -Raw
    $clientSqlRaw = Get-Content -Path $clientSqlPath -Raw
    $clientSqlBlock = @"
BEGIN
$clientSqlRaw
COMMIT;
END;
"@

    try {
        (New-Object Oracle.ManagedDataAccess.Client.OracleCommand($genericSqlBlock, $conn)).ExecuteNonQuery() | Out-Null
        Write-Success 'Generic Market SQL executed successfully'
    }
    catch { throw "Generic Market SQL failed: $($_.Exception.Message)" }

    try {
        (New-Object Oracle.ManagedDataAccess.Client.OracleCommand($clientSqlBlock, $conn)).ExecuteNonQuery() | Out-Null
        Write-Success 'Client SQL executed successfully'
    }
    catch { throw "Client SQL failed: $($_.Exception.Message)" }
}
catch {
    Write-Fail 'An error occurred during database configuration'
    Write-Warn "Error: $_"
    exit 1
}
finally {
    $dbPasswordPlain = $null
    if ($conn -and $conn.State -eq 'Open') { $conn.Close() }
}

# ─────────────────────────────────────────────
#  STEP 5 — Manual rolling restart reminder
# ─────────────────────────────────────────────

Write-Host ''
Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host '*** MANUAL ACTION REQUIRED ***' -ForegroundColor Black -BackgroundColor Yellow
Write-Warn 'You must manually perform a ROLLING RESTART of the hosted environment servers'
Write-Warn 'for the parameters to take effect. Restart the servers sequentially.'
Write-Host '=============================================' -ForegroundColor DarkCyan

Write-Host ''
Write-Host '=============================================' -ForegroundColor DarkCyan
Write-Host '   Done. Type exit to close this window.'      -ForegroundColor White
Write-Host '=============================================' -ForegroundColor DarkCyan