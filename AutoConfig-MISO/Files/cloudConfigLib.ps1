# Common Init Functions
function initFunc_Common {
    New-Item -Path C:\PCI\trust\$domainName -ItemType Directory -Force | Out-Null
    New-Item -Path C:\PCI-Updates\GM\custom\$domainName\applications\GenPortal.ear\APP-INF\classes -ItemType Directory -Force | Out-Null
	
    Copy-Item (Join-Path $scriptDir "Files\GSMS_GM_truststore.jks") C:\PCI\trust\$domainName\${domainName}_GM_truststore.jks

    # Pre-configure SQL Developer connection with domain-s JDBC URL
    $jdbcConfigFile = "C:\PCI\domain\$domainName\config\jdbc\GTDW-8080-jdbc.xml"	
    $jdbcXML = [xml](Get-Content $jdbcConfigFile)
    $jdbcUrl = $jdbcXML.'jdbc-data-source'.'jdbc-driver-params'.'url'

    $connectionsJsonPath = Join-Path $scriptDir "Files\connections.json"
    ((Get-Content -path $connectionsJsonPath -Raw) -replace 'jdbc:oracle:thin:@yourdomainname-db.cloud.pci:1521/gsms.powercosts.com', $($jdbcUrl)) | Set-Content -Path $connectionsJsonPath
    
    $cnct = get-childitem 'C:\Users\Administrator\AppData\Roaming\SQL Developer' -Filter 'system*' | Select-Object -Property name
    Copy-Item $connectionsJsonPath "C:\Users\Administrator\AppData\Roaming\SQL Developer\$($cnct.Name)\o.jdeveloper.db.connection\connections.json"
}

# Market Load Function
function initFunc_MISO([string]$clientName, [string]$CertDir) {
    Set-TimeZone -Name 'Central Standard Time'
    Write-Host "Server timezone set to CST"

    $folders = @(
        "archive",
        "archiveInvoice",
        "archivePDFInvoice",
        "archiveStatements",
        "archiveXMLInvoice",
        "certs",
        "disputes",
        "download",
        "invoicePDFDisplay",
        "loadStatements",
        "upload"
    )

    foreach ($folder in $folders) {
        New-Item -Path "C:\MISO\$folder" -ItemType Directory -Force | Out-Null
    }

    Copy-Item (Join-Path $scriptDir "Files\miso.jks") C:\MISO\certs\miso.jks
    Copy-Item (Join-Path $scriptDir "Files\Client_CERTS\$clientName\*") C:\MISO\certs -Recurse -Force
}

# Weblogic Functions 
function loadOracle {
    # Load Function Library & Assembly files: 										   
    Param([Parameter(Mandatory = $false)][switch]$wlpwd)

    $odpZip = Join-Path $scriptDir "Files\ODP.NET_Managed_ODAC122cR1.zip"
    $odpTarget = "C:\Oracle_ODP_Install\"

    $odpInstall = "C:\Oracle_ODP_Install\"
    $odpInstallbat = "install_odpm.bat"
    $odpInstallParam1 = "C:\oracle"
    $odpInstallParam2 = "both"
    $odpInstallParam3 = "true"

    $ora12local = 'C:\oracle\odp.net\managed\common\Oracle.ManagedDataAccess.dll'
		
    if (!(test-path -type leaf 'C:\Oracle_ODP_Install\install_odpm.bat')) {
        #if missing, extract files: 
        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($odpZip, $odpTarget)
        #verify extraction: 
        if (!(test-path -type leaf 'C:\Oracle_ODP_Install\install_odpm.bat')) {
            Write-Host "[ERR] Extract failed! Check drive space and permissions" -Foregroundcolor Red
            exit 1 
        }
    }
	
    #verify previous run of install.bat
    if (!(test-path 'C:\oracle\odp.net\')) {
        if (!(test-path -type leaf $ora12local)) {
            Write-Host "[WRN] ODP assembly not found. Attempting to install ODP managed drivers" -Foregroundcolor Yellow
            &cmd /c "cd $odpInstall && $odpInstallbat $odpInstallParam1 $odpInstallParam2 $odpInstallParam3"
        }
    }
	
    if (test-path -type leaf $ora12local) {
        Add-Type -Path $ora12local
        $assemblyFile = $ora12local
        return $assemblyFile			
    }
    else {
        Write-Host "[ERR] Cannot find $ora12local to load. Exiting."  -Foregroundcolor Red
        exit 1
    }
}

function getEnv {
    #Get domain path, get WL path. Start setting variables like what the wlsetENV.bat file does... 
    $imagePath = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\services\PCI_GM_$domainName | Select-Object -ExpandProperty ImagePath)
    $serverBinPath = Split-Path $imagePath
    $serverPath = $imagePath -replace "\\server\\bin\\wlsvcX64.exe", ""
    $jdkBinPath = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\services\PCI_GM_$domainName\Parameters | Select-Object -ExpandProperty JavaHome) -replace [regex]::Escape("/"), "\" 
    $jdkBinPath = Join-Path $jdkBinPath "bin"
    $domainDir = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\services\PCI_GM_$domainName\Parameters | Select-Object -ExpandProperty ExecDir)
    
    $env:MW_HOME = $serverPath | split-path 
    $env:WL_HOME = $serverPath
    $env:JAVA_HOME = $jdkBinPath
    $env:APPHOME = $domainDir

    $date = (get-date).ToString("yyyy-MM-dd")
    $dateMin1 = (get-date).AddDays(-1).ToString("yyyy-MM-dd")
    $frmDate = (get-date).AddDays(-1).ToString("yyyy-MM-dd 05:00:00")
    $toDate = (get-date).ToString("yyyy-MM-dd 04:59:59")
	
    return @{
        ServerBinPath = $serverBinPath
        ServerPath    = $serverPath
        JdkBinPath    = $jdkBinPath
        DomainDir     = $domainDir
        Date          = $date
        DateMin1      = $dateMin1
        FromDate      = $frmDate
        ToDate        = $toDate
    }
}

function setWLEnv([string]$wlServerBinPath) {
    Write-Host "[NFO] Setting WL environment..." -Foregroundcolor Yellow
    & "$wlServerBinPath\setWLSEnv.cmd" | Out-Null
}

function wl_encrypt_pw ([string]$javaPath, [string]$encryptme) {
    $startPath = Get-Location
    Set-Location $env:APPHOME
    $java = Join-Path $javaPath "java.exe"
    $jar = Join-Path $env:WL_HOME "server\lib\weblogic.jar"
    $wlst = 'weblogic.security.Encrypt'
    $encryptedPW = & $java -cp $jar $wlst $encryptme
    Set-Location $startPath
    return $encryptedPW
}

function wl_config_modify($file, $jksFile, $enc_pw) {
    if (!(($file) -or ($jksFile) -or ($enc_pw))) {
        Write-Host "[ERR] Missing a SSL input. Exiting." -Foregroundcolor Red
        exit
    }

    Write-Host "[NFO] Modifying Weblogic config.xml" -Foregroundcolor Yellow
    Write-Host 
    $saveit = 0
    $xml = [xml](Get-Content $file)
    $encrypter_value = $enc_pw 
	
    if (!(($xml.domain.server.ssl.enabled.ToString()) -eq 'true')) {	
        Write-Host "[NFO] Attempting to add SSL block" -Foregroundcolor Yellow
        $xml.domain.server.ssl.enabled = 'true'
	
        $newNode1 = $xml.CreateElement("listen-port", "http://xmlns.oracle.com/weblogic/domain")
        $newNode1.InnerText = '8001'
        $deploy = $xml.domain.server.ssl.InsertAfter($newNode1, $xml.domain.server.ssl['hostname-verification-ignored'])
		
        $newNode2 = $xml.CreateElement("server-private-key-alias", "http://xmlns.oracle.com/weblogic/domain")
        $newNode2.InnerText = "*.pci-int.pci"
        $deploy = $xml.domain.server.ssl.InsertAfter($newNode2, $xml.domain.server.ssl['listen-port'])
		
        $newNode3 = $xml.CreateElement("server-private-key-pass-phrase-encrypted", "http://xmlns.oracle.com/weblogic/domain")
        $newNode3.InnerText = $encrypter_value
        $deploy = $xml.domain.server.ssl.InsertAfter($newNode3, $xml.domain.server.ssl['server-private-key-alias'])
		
        $newNode4 = $xml.CreateElement("custom-identity-key-store-file-name", "http://xmlns.oracle.com/weblogic/domain")
        $newNode4.InnerText = $jksFile
        $deploy = $xml.domain.server.InsertAfter($newNode4, $xml.domain.server['key-stores'])
		
        $newNode5 = $xml.CreateElement("custom-identity-key-store-type", "http://xmlns.oracle.com/weblogic/domain")
        $newNode5.InnerText = "JKS"
        $deploy = $xml.domain.server.InsertAfter($newNode5, $xml.domain.server['custom-identity-key-store-file-name'])
		
        $newNode6 = $xml.CreateElement("custom-identity-key-store-pass-phrase-encrypted", "http://xmlns.oracle.com/weblogic/domain")
        $newNode6.InnerText = $encrypter_value
        $deploy = $xml.domain.server.InsertAfter($newNode6, $xml.domain.server['custom-identity-key-store-type'])
		
        $newNode7 = $xml.CreateElement("custom-trust-key-store-file-name", "http://xmlns.oracle.com/weblogic/domain")
        $newNode7.InnerText = $jksFile
        $deploy = $xml.domain.server.InsertAfter($newNode7, $xml.domain.server['custom-identity-key-store-pass-phrase-encrypted'])
		
        $newNode8 = $xml.CreateElement("custom-trust-key-store-type", "http://xmlns.oracle.com/weblogic/domain")
        $newNode8.InnerText = "JKS"
        $deploy = $xml.domain.server.InsertAfter($newNode8, $xml.domain.server['custom-trust-key-store-file-name'])
		
        $newNode9 = $xml.CreateElement("custom-trust-key-store-pass-phrase-encrypted", "http://xmlns.oracle.com/weblogic/domain")
        $newNode9.InnerText = $encrypter_value
        $deploy = $xml.domain.server.InsertAfter($newNode9, $xml.domain.server['custom-trust-key-store-type'])

        $saveit = 1
        Write-Host "[SUC] Modified SSL block in Weblogic config.xml" -Foregroundcolor Green
        Write-Host 
    }
    else {
        Write-Host "[NFO] SSL already in Weblogic config.xml" -Foregroundcolor Yellow
        Write-Host 
    }
	
    if (!($xml.domain['mail-session'])) {	
        Write-Host "[NFO] Attempting to add mail block" -Foregroundcolor Yellow
        $xmlMail = $xml.CreateElement("mail-session", "http://xmlns.oracle.com/weblogic/domain");
        $deploy = $xml.domain.InsertAfter($xmlMail, $xml.domain.jmx)
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("name", "http://xmlns.oracle.com/weblogic/domain"));
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("target", "http://xmlns.oracle.com/weblogic/domain"));
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("jndi-name", "http://xmlns.oracle.com/weblogic/domain"));
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("properties", "http://xmlns.oracle.com/weblogic/domain"));
        $xml.domain.'mail-session'.name = 'GPMailSession'
        $xml.domain.'mail-session'.target = $(hostname).toString().toLower() 
        $xml.domain.'mail-session'.'jndi-name' = 'GPMailSession'
        $xml.domain.'mail-session'.properties = "debug=true;mail.transport.protocol=SMTP;mail.user=PCI_Support;mail.host=365mail.powercosts.com;mail.store.protocol=POP3";
        $saveit = 1
        Write-Host "[SUC] Modified mail block in Weblogic config.xml" -Foregroundcolor Green	
        Write-Host 
    }
    else {
        Write-Host "[NFO] Mail block already in Weblogic config.xml" -Foregroundcolor Yellow
        Write-Host 
    }
	
    if ($saveit -ne 0) { 
        Write-Host "[NFO] Backing up existing weblogic config.xml" -Foregroundcolor Yellow
        $dateTime = (get-date).ToString("yyyy-MM-dd_HHmm")
        $fileBackup = Join-Path (Split-Path $file) "config.xml.bakup_$dateTime"
        Copy-Item $file $fileBackup
		
        $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
        $sw = New-Object System.IO.StreamWriter($file, $false, $utf8WithoutBom)
        $xml.Save($sw)
        $sw.Close(); 

        $v = get-content $file -raw
        (($v -replace "\s{4}[<]listen-address[>][\r][\n]\s{4}[<][/]listen-address[>]", '    <listen-address></listen-address>')) | set-content -Path $file 
        $v = get-content $file -raw
        (($v -replace '\s{4}[<]plan-staging-mode xsi:nil="true"[>\r\n]\s+[<][/]plan-staging-mode[>]', '    <plan-staging-mode xsi:nil="true"></plan-staging-mode>')) | set-content -Path $file
	
        Write-Host "[SUC] Weblogic config.xml modified" -Foregroundcolor Green
        Write-Host 		
    }
}

#SQL Functions 
function buildjdbc {
    #Build JDBC Connect String: 
    $jdbc = (get-content $env:APPHOME\config\jdbc\GTDW-8080-jdbc.xml | 
        select-string ':1521/' -SimpleMatch).ToString().Trim() 
    $jdbc = $jdbc -replace "<url>jdbc:oracle:thin:@", ""
    $jdbc = $jdbc -replace "</url>", ""
    $user = 'pci'

    return @{
        JDBC = $jdbc
        User = $user
    }
}

function genericSQL($market) {
    $genericSQLPath = Join-Path $scriptDir "Files\genericSQL_$market.sql"
    if (!(Test-Path $genericSQLPath)) {
        Write-Host "[ERR] Missing generic SQL file: $genericSQLPath" -ForegroundColor Red
        exit 1
    }
    return (Get-Content -Path $genericSQLPath -Raw)
}

function clientSQL([string]$Market, [string]$SqlFilePath) {
    if (-not (Test-Path $SqlFilePath)) {
        Write-Host "[ERR] Client SQL file not found: $SqlFilePath" -Foregroundcolor Red
        exit 1
    }

    Write-Host "[NFO] Using client SQL: $(Split-Path $SqlFilePath -Leaf)" -ForegroundColor Yellow
    $sql = Get-Content -Path $SqlFilePath -Raw
    return @"
BEGIN	
$sql
COMMIT; 
END;
"@
}