<##
==============================================================================================
 Microsoft PowerShell Source File
 NAME:				Configure_Domain.ps1
 LAST UPDATED:		05/19/2026

 AUTHORS:			Renzo Jimenez & Rodrigo Mujica

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

# Get working path
$scriptDir = $PSScriptRoot
$configLib = Join-Path $scriptDir "Files\cloudConfigLib.ps1"

# Load cloudConfigLib.ps1
if (-not (Test-Path $configLib)) {
    Write-Host "[ERR] Cannot find cloudConfigLib.ps1" -ForegroundColor Red
    exit 1
}
. $configLib

# Get domain name
$domains = Get-ChildItem -Path C:\PCI\domain -Directory | Select-Object -ExpandProperty Name

if ($domains.Count -gt 1) {
    Write-Host "[WRN] Multiple domains found. $($domains[0]) selected" -ForegroundColor Yellow
}
$domainName = $domains[0]

# Set service name
$gsmsSvc = "PCI_GM_" + $domainName

Write-Host "======================================" 
Write-Host "[NFO] Script initializing, please wait..." -Foregroundcolor Yellow

# Load SQL payloads
$clientSqlBlock = clientSQL -Market $Market -SqlFilePath $SqlFilePath
$clientName = $Client
$genericSqlBlock = genericSQL($Market)

# Run initialization 
initFunc_Common
initFunc_SPPIM -clientName $clientName -CertDir $CertDir

# Build environment details for WebLogic scripting
$envConfig = getEnv

$domainDir = $envConfig.DomainDir
$jdkBinPath = $envConfig.JdkBinPath
$wlServerBinPath = $envConfig.ServerBinPath

# Set up Oracle, WebLogic environment, SLL and mail block
loadOracle
setWLEnv $wlServerBinPath

$jdbcConfig = buildJDBC
$jdbc = $jdbcConfig.JDBC
$user = $jdbcConfig.User
$dbPW = 'pci'

# WebLogic config file
$file = Join-Path $domainDir "config\config.xml"

# Set the precanned JKS file 
$jksFile = "C:\PCI\trust\$domainName\${domainName}_GM_truststore.jks"

$encrypted_password = wl_encrypt_pw $jdkBinPath "#code4quality"
wl_config_modify $file $jksFile $encrypted_password

# Connect to DB and execute SQL
try {
    $constr = "User Id=$user;Password=$dbPW;Data Source=$jdbc"
    Write-Host "[NFO] Attempting to connect to DB... " -Foregroundcolor Yellow

    $conn = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($constr)
    $conn.Open()
    Write-Host "[SUC] Connected to DB successfully!" -Foregroundcolor Green
    Write-Host "[NFO] Executing SQL scripts..." -Foregroundcolor Yellow

    try {
        (New-Object Oracle.ManagedDataAccess.Client.OracleCommand($genericSqlBlock, $conn)).ExecuteNonQuery() | Out-Null
        Write-Host "[SUC] Generic Market SQL executed successfully" -ForegroundColor Green
    }
    catch { throw "Generic Market SQL failed: $($_.Exception.Message)" }

    try {
        (New-Object Oracle.ManagedDataAccess.Client.OracleCommand($clientSqlBlock, $conn)).ExecuteNonQuery() | Out-Null
        Write-Host "[SUC] Client SQL executed successfully" -ForegroundColor Green
    }
    catch { throw "Client SQL failed: $($_.Exception.Message)" }

    Write-Host "[NFO] Restarting GSMS service..." -Foregroundcolor Yellow
    Stop-Service $gsmsSvc
    Start-Service $gsmsSvc
    Write-Host "[SUC] Script completed" -Foregroundcolor Green
}
catch {
    Write-Host "[ERR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($conn -and $conn.State -eq 'Open') { $conn.Close() }
}
Write-Host "======================================" 