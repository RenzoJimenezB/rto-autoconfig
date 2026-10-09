<##
==============================================================================================
 Microsoft PowerShell Source File
 NAME:				Configure_Domain.ps1 & cloudConfigLib.ps1

 AUTHORS:			Renzo Jimenez

 COMMENT:
    Unified auto configuration script for PCI Cloud domains, covering every market
    (CAISO, ERCOT, ISONE, MISO, NYISO, PJM, SPPIM).
    This script configures the server environment, including folders, SSL/mailbox configuration,
	SQL deployment, certificates, and supporting application files.

 Requirements:
    - Execute from an elevated (Administrator) PowerShell prompt
    - cloudConfigLib.ps1 present alongside this script
    - Per-market files available at -ConfigFilesDir (see Config Files\<Market>\)
==============================================================================================
##>

param(
    [Parameter(Mandatory = $true)][string]$Market,
    [Parameter(Mandatory = $true)][string]$Client,
    [Parameter(Mandatory = $true)][string]$CertDir,
    [Parameter(Mandatory = $true)][string]$SqlFilePath,
    [Parameter(Mandatory = $true)][string]$ConfigFilesDir,
    [Parameter(Mandatory = $false)][ValidateSet('MOTE', 'PROD', 'N', 'P')][string]$Environment,
    [Parameter(Mandatory = $false)][string]$WsddDir
)

# Without this, a cmdlet error (e.g. Copy-Item/New-Item hitting an unexpected pre-existing
# file) is non-terminating by default: the script keeps running past it silently, and the
# only sign of trouble is a generic "remote execution failed" message the launcher reports
# at the very end, disconnected from whatever step actually failed. Setting this makes every
# such failure stop immediately, right where it happens, under the Write-Step banner for that
# stage -- matching what Start-CloudDomainConfig.ps1 (the local launcher) already does.
$ErrorActionPreference = 'Stop'

# ValidateSet above only checks Environment is in the combined MOTE/PROD/N/P set -- it
# can't tell MOTE apart from N by market, so ERCOT+N or CAISO+MOTE would pass it. This
# catches that, and also catches CAISO with no Environment at all ($null -notin @('N','P')).
if ($Market -eq 'ERCOT' -and $Environment -notin @('MOTE', 'PROD')) {
    throw "ERCOT requires Environment to be MOTE or PROD (got '$Environment')"
}
if ($Market -eq 'CAISO' -and $Environment -notin @('N', 'P')) {
    throw "CAISO requires Environment to be N or P (got '$Environment')"
}

function Write-Step {
    param([string]$Message)
    Write-Output "`n[ $(Get-Date -Format 'HH:mm:ss') ] $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Output "  OK  $Message"
}

function Write-Fail {
    param([string]$Message)
    Write-Output "  !!  $Message"
}

function Write-Warn {
    param([string]$m)
    Write-Output "  $m"
}

function Write-Info {
    param([string]$m)
    Write-Output "  $m"
}

# Get working paths
$scriptDir = $PSScriptRoot
$configLib = Join-Path $scriptDir "cloudConfigLib.ps1"

# Dependencies\ (shared third-party files our scripts need -- ODP.NET driver, ImportExcel)
# is a sibling of Config Scripts\, same level as Config Files\.
$SharedFilesDir = Join-Path (Split-Path $scriptDir -Parent) "Dependencies"

# Load cloudConfigLib.ps1
if (-not (Test-Path $configLib)) {
    throw 'Cannot find cloudConfigLib.ps1'
}
. $configLib

# Get domain name
$domains = @(Get-ChildItem -Path C:\PCI\domain -Directory | Select-Object -ExpandProperty Name)

if ($domains.Count -gt 1) {
    Write-Warn "Multiple domains found. $($domains[0]) selected"
}
$domainName = $domains[0]

# Set service name
$gsmsSvc = "PCI_GM_" + $domainName

Write-Step 'Script initializing, please wait...'

# Load SQL payloads
Write-Info "Using client SQL: $Client.sql"
if ($Market -eq 'ERCOT' -or $Market -eq 'CAISO') {
    Write-Info "Environment: $Environment"
}
$clientSqlBlock = clientSQL $SqlFilePath
$clientName = $Client
$genericSqlBlock = genericSQL $Market $Environment $ConfigFilesDir

# Run initialization — per-market plug-in point (initFunc_CAISO, initFunc_ERCOT, ...)
initFunc_Common $ConfigFilesDir

$marketInitFn = "initFunc_$Market"
if (-not (Get-Command $marketInitFn -ErrorAction SilentlyContinue)) {
    throw "No market init function found for market '$Market' (expected function '$marketInitFn' in cloudConfigLib.ps1)"
}
& $marketInitFn $clientName $CertDir $ConfigFilesDir

# ERCOT-only: stage per-environment wsdd files after the market folders exist. Certs
# aren't transferred -- clientTruststore.jks covers cert usage at runtime.
if ($Market -eq 'ERCOT') {
    stageErcotFiles $Environment $WsddDir 'wsdd'
}

# Build environment details for WebLogic scripting
Write-Step 'Configuring server environment'
$envConfig = getEnv
$domainDir = $envConfig.DomainDir
$jdkBinPath = $envConfig.JdkBinPath
$wlServerBinPath = $envConfig.ServerBinPath

loadOracle -SharedFilesDir $SharedFilesDir
setWLEnv $wlServerBinPath

Write-Step 'Setting WL environment'

$jdbcConfig = buildJDBC
$jdbc = $jdbcConfig.JDBC
$user = $jdbcConfig.User
$dbPW = 'pci'

# WebLogic config file
$file = Join-Path $domainDir "config\config.xml"
$jksFile = "C:\PCI\trust\$domainName\${domainName}_GM_truststore.jks"

Write-Step 'Modifying WebLogic config.xml'
$encrypted_password = wl_encrypt_pw $jdkBinPath "#code4quality"
wl_config_modify $file $jksFile $encrypted_password

Write-Step 'Setting PCI_GM service memory'
Set-WlHeapSize $domainName

# Connect to DB and execute SQL
Write-Step 'Connecting to database'
try {
    $constr = "User Id=$user;Password=$dbPW;Data Source=$jdbc"

    $conn = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($constr)
    $conn.Open()
    Write-Success 'Connected to DB successfully'

    Write-Step 'Executing SQL scripts'

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

    # Every market's generic SQL deactivates all asset owners before the client SQL reactivates
    # only the ones with a cert entry. If the AO flagged DEFAULT_ASSET_OWNER is inactive at this point,
    # it's because this configuration had no cert for it and ISO Comm tasks that rely on the default AO
    # will fail until someone sets a different, active AO as default via the AO screen.
    try {
        $defaultAoQuery = @"
SELECT so.NAME
FROM SASSET_OWNER_CONFIG soc
INNER JOIN SASSET_OWNER so ON so.ASSET_OWNER_KEY = soc.ASSET_OWNER_KEY
INNER JOIN SISO_PORTFOLIO_MAPPING spm ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
WHERE spm.NAME = '$Market'
AND soc.DEFAULT_ASSET_OWNER = 'Y'
AND soc.ACTIVE = 'N'
"@
        $reader = (New-Object Oracle.ManagedDataAccess.Client.OracleCommand($defaultAoQuery, $conn)).ExecuteReader()
        $inactiveDefaultAo = $null
        if ($reader.Read()) { $inactiveDefaultAo = $reader.GetString(0) }
        $reader.Close()

        if ($inactiveDefaultAo) {
            $envNote = if ($Environment) { " for $(Get-EnvironmentDisplay $Environment)" } else { '' }
            Write-Info ""
            Write-Warn "WARNING: Default asset owner '$inactiveDefaultAo' is inactive$envNote!"
            Write-Warn "No certificate was registered for it, so this configuration left it inactive"
            Write-Warn "ISO Communication tasks may fail until a different, active AO is set as default"
        }
    }
    catch { Write-Warn "Could not verify default asset owner status: $($_.Exception.Message)" }

    Restart-ServiceSafely -ServiceName $gsmsSvc
}
catch {
    throw $_.Exception.Message
}
finally {
    if ($conn -and $conn.State -eq 'Open') { $conn.Close() }
}

exit 0
