<##
==============================================================================================
 Microsoft PowerShell Source File
 NAME:				Configure_Domain.ps1

 AUTHOR:			Renzo Jimenez

 COMMENT: 
    Market-specific auto configuration script for PCI Cloud domains.
    This script configures the server environment, including folders, SSL/mailbox configuration, 
	SQL deployment, certificates, and supporting application files.

 Requirements: 
    - AutoConfig_<MARKET>.zip package extracted locally
    - Execute from an elevated (Administrator) PowerShell prompt
==============================================================================================
##>

param(
    [Parameter(Mandatory = $true)][string]$Market,
    [Parameter(Mandatory = $true)][string]$Client,
    [Parameter(Mandatory = $true)][string]$CertDir,
    [Parameter(Mandatory = $true)][string]$SqlFilePath
)

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

# Get working path
$scriptDir = $PSScriptRoot
$configLib = Join-Path $scriptDir "cloudConfigLib.ps1"

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
$clientSqlBlock = clientSQL $SqlFilePath
$clientName = $Client
$genericSqlBlock = genericSQL $Market

# Run initialization 
initFunc_Common
initFunc_MISO $clientName $CertDir

# Build environment details for WebLogic scripting
Write-Step 'Configuring server environment'
$envConfig = getEnv
$domainDir = $envConfig.DomainDir
$jdkBinPath = $envConfig.JdkBinPath
$wlServerBinPath = $envConfig.ServerBinPath

loadOracle
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

    Restart-ServiceSafely -ServiceName $gsmsSvc
}
catch {
    throw $_.Exception.Message
}
finally {
    if ($conn -and $conn.State -eq 'Open') { $conn.Close() }
}

exit 0