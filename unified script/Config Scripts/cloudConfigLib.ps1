# ─────────────────────────────────────────────
#  Truststore — normalize installer-generated GM truststore
# ─────────────────────────────────────────────
function Set-GmTruststore([string]$DomainName) {
    # The WebLogic install already generates C:\PCI\trust\DOMAIN_NAME\DOMAIN_NAME_GM_truststore.jks
    # (literal placeholder folder/file names). Rename both to use the real domain name instead of
    # copying a bundled jks from Config Files\
    $placeholderDir = 'C:\PCI\trust\DOMAIN_NAME'
    $targetDir = "C:\PCI\trust\$DomainName"
    $placeholderFileName = 'DOMAIN_NAME_GM_truststore.jks'
    $targetFileName = "${DomainName}_GM_truststore.jks"

    if (Test-Path $placeholderDir) {
        if (Test-Path $targetDir) {
            Remove-Item -Path $targetDir -Recurse -Force
        }
        Rename-Item -Path $placeholderDir -NewName $DomainName -Force
    }
    elseif (-not (Test-Path $targetDir)) {
        throw "Installer-generated truststore folder not found: $placeholderDir (and $targetDir does not exist either)"
    }

    $placeholderFilePath = Join-Path $targetDir $placeholderFileName
    $targetFilePath = Join-Path $targetDir $targetFileName
    if (Test-Path $placeholderFilePath) {
        if (Test-Path $targetFilePath) {
            Remove-Item -Path $targetFilePath -Force
        }
        Rename-Item -Path $placeholderFilePath -NewName $targetFileName -Force
    }
    elseif (-not (Test-Path $targetFilePath)) {
        throw "Installer-generated truststore file not found: $placeholderFilePath"
    }

    return $targetFilePath
}

# ─────────────────────────────────────────────
#  Common Init
# ─────────────────────────────────────────────
function initFunc_Common([string]$ConfigFilesDir) {
    New-Item -Path C:\PCI-Updates\GM\custom\$domainName\applications\GenPortal.ear\APP-INF\classes -ItemType Directory -Force | Out-Null

    Set-GmTruststore -DomainName $domainName | Out-Null

    # Pre-configure SQL Developer connection with domain-s JDBC URL
    $jdbcConfigFile = "C:\PCI\domain\$domainName\config\jdbc\GTDW-8080-jdbc.xml"
    $jdbcXML = [xml](Get-Content $jdbcConfigFile)
    $jdbcUrl = $jdbcXML.'jdbc-data-source'.'jdbc-driver-params'.'url'

    $connectionsJsonPath = Join-Path $ConfigFilesDir "connections.json"
    ((Get-Content -path $connectionsJsonPath -Raw) -replace 'jdbc:oracle:thin:@yourdomainname-db.cloud.pci:1521/gsms.powercosts.com', $($jdbcUrl)) | Set-Content -Path $connectionsJsonPath

    $cnct = get-childitem 'C:\Users\Administrator\AppData\Roaming\SQL Developer' -Filter 'system*' | Select-Object -Property name
    Copy-Item $connectionsJsonPath "C:\Users\Administrator\AppData\Roaming\SQL Developer\$($cnct.Name)\o.jdeveloper.db.connection\connections.json" -Force -ErrorAction Stop
}

# ─────────────────────────────────────────────
#  Market Init — CAISO
# ─────────────────────────────────────────────
function initFunc_CAISO([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    $clientTimezones = @{
        'APU'       = 'PST'
        'APS-MT'    = 'MST'
        'APS-TO'    = 'MST'
        'AVISTA-MT' = 'PST'
        'AVISTA-TO' = 'PST'
        'BEPC'      = 'PST'
        'BHEM-BA'   = 'MST'
        'BPA'       = 'PST'
        'CDWR'      = 'PST'
        'DTEET'     = 'PST'
        'GUZMN-MT'  = 'MST'
        'IID-MT'    = 'PST'
        'LADWP-MT'  = 'PST'
        'MERCURIA'  = 'PST'
        'NVE-MT'    = 'PST'
        'P66-MT'    = 'PST'
        'PAC'       = 'PST'
        'PAC-GAS'   = 'PST'
        'PGE-GOS'   = 'PST'
        'PGE-TOS'   = 'PST'
        'PNM-BO'    = 'MST'
        'PNM-EESC'  = 'MST'
        'PNM-PRSC'  = 'MST'
        'PSE-MT'    = 'PST'
        'PSE-TO'    = 'PST'
        'RWE'       = 'CST'
        'SDCP'      = 'PST'
        'SDGE-MT'   = 'PST'
        'SHELL'     = 'CST'
        'SMUD'      = 'PST'
        'SRP-STF'   = 'MST'
        'SRP-TGO'   = 'MST'
        'TID'       = 'PST'
        'TPU-BO'    = 'PST'
        'TPU-MT'    = 'PST'
        'TRISTATE'  = 'MST'
        'UMPA-MT'   = 'MST'
        'XCEL'      = 'PST'
    }

    $timezoneMap = @{
        'CST' = 'Central Standard Time'
        'MST' = 'US Mountain Standard Time'
        'PST' = 'Pacific Standard Time'
    }

    $timezoneabbv = $clientTimezones[$clientName]

    if (-not $timezoneabbv) {
        throw "Unknown client '$clientName'. Please add them to the client timezone lookup table"
    }

    $timezone = $timezoneMap[$timezoneabbv]
    Set-TimeZone -Name $timezone
    Write-Info "Server timezone set to $timezoneabbv"

    $folders = @(
        "C:\CAISO\Archive",
        "C:\CAISO\Auto_Upload",
        "C:\CAISO\Bid_Status",
        "C:\CAISO\Download",
        "C:\CAISO\Exports",
        "C:\CAISO\Upload",

        "C:\CAISO\Settlements\Archive",
        "C:\CAISO\Settlements\Download",
        "C:\CAISO\Settlements\Historic",
        "C:\CAISO\Settlements\Upload",
        "C:\CAISO\Settlements\SFTP",

        "C:\CAISO\Import_Datafeed\ETL_Export_Latest",
        "C:\CAISO\Import_Datafeed\Import_Files\Load_Forecast\Archive",
        "C:\CAISO\Import_Datafeed\IT_Datafeed_Files\WACOG",

        "C:\ISO\STORE_BID_SUBMIT_DATA",
        "C:\ISO\STORE_BID_RESULT_DATA"
    )

    foreach ($folder in $folders) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    Copy-Item (Join-Path $ConfigFilesDir "CAISOEIM.keystore") C:\CAISO\CAISOEIM.keystore -Force -ErrorAction Stop
    Copy-Item (Join-Path $ConfigFilesDir "CAISOEIM.txt") C:\CAISO\CAISOEIM.txt -Force -ErrorAction Stop

    Copy-Item (Join-Path $ConfigFilesDir "crypto.properties") "C:\PCI-Updates\GM\custom\$domainName\applications\GenPortal.ear\APP-INF\classes\crypto.properties" -Force -ErrorAction Stop
    Copy-Item (Join-Path $ConfigFilesDir "crypto.properties") "C:\PCI\domain\$domainName\applications\GenPortal.ear\APP-INF\classes\crypto.properties" -Force -ErrorAction Stop

    Copy-Item "$CertDir\*" C:\CAISO\Settlements\SFTP -Recurse -Force
}

# ─────────────────────────────────────────────
#  Market Init — ERCOT
# ─────────────────────────────────────────────
function initFunc_ERCOT([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    Set-TimeZone -Name 'Central Standard Time'
    Write-Info "Server timezone set to CST"

    $boFolders = @(
        "Archive",
        "Calendar",
        "Certificates\PROD",
        "Disputes",
        "Download",
        "ercot_notifications",
        "invoice_reports",
        "Invoices",
        "Manual\DAM",
        "Manual\RTM",
        "Statements"
    )

    foreach ($folder in $boFolders) {
        New-Item -Path "C:\ERCOT\BO\$folder" -ItemType Directory -Force | Out-Null
    }

    $foFolders = @(
        "Archive",
        "Certificates\MOTE",
        "Download",
        "Import",
        "Submit_Cache",
        "Upload\Auto"
    )

    foreach ($folder in $foFolders) {
        New-Item -Path "C:\ERCOT\FO\$folder" -ItemType Directory -Force | Out-Null
    }

    Copy-Item (Join-Path $ConfigFilesDir "clientTruststore.jks") C:\ERCOT\clientTruststore.jks -Force -ErrorAction Stop

    Copy-Item (Join-Path $ConfigFilesDir "crypto.properties") "C:\PCI-Updates\GM\custom\$domainName\applications\GenPortal.ear\APP-INF\classes\crypto.properties" -Force -ErrorAction Stop
    Copy-Item (Join-Path $ConfigFilesDir "crypto.properties") "C:\PCI\domain\$domainName\applications\GenPortal.ear\APP-INF\classes\crypto.properties" -Force -ErrorAction Stop
    Copy-Item (Join-Path $ConfigFilesDir "crypto.properties") "C:\PCI\domain\$domainName\crypto.properties" -Force -ErrorAction Stop
}

# ─────────────────────────────────────────────
#  ERCOT — cert/wsdd staging (MOTE or PROD)
# ─────────────────────────────────────────────
function stageErcotFiles([string]$Environment, [string]$SourceDir, [string]$Label) {
    if (-not $SourceDir -or -not (Test-Path $SourceDir)) {
        Write-Warn "No $Label files staged for this client; skipping"
        return
    }

    $destination = if ($Environment -eq 'PROD') {
        "C:\ERCOT\BO\Certificates\PROD"
    }
    else {
        "C:\ERCOT\FO\Certificates\MOTE"
    }

    # Certs and wsdd files land in the same folder so pairs are easy to spot for
    # troubleshooting; they accumulate here across environment switches by design.
    Copy-Item -Path "$SourceDir\*" -Destination $destination -Force -ErrorAction Stop
    Write-Success "$Label files copied to $destination"
}

# ─────────────────────────────────────────────
#  Market Init — ISONE
# ─────────────────────────────────────────────
function initFunc_ISONE([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    Set-TimeZone -Name 'Eastern Standard Time'
    Write-Info "Server timezone set to EST"

    $folders = @(
        "Archive",
        "Certificates",
        "Download",
        "EQR_DATA",
        "Invoice",
        "Settlements",
        "Upload",

        "Settlements\Archive",
        "Settlements\Download\SFTP",
        "Settlements\Statements",

        "Upload\Auto"
    )

    foreach ($folder in $folders) {
        New-Item -Path "C:\ISONE\$folder" -ItemType Directory -Force | Out-Null
    }

    Copy-Item (Join-Path $ConfigFilesDir "PCIKEY.keystore") C:\ISONE\Certificates\PCIKEY.keystore -Force -ErrorAction Stop
    Copy-Item "$CertDir\*" C:\ISONE\Certificates -Recurse -Force
}

# ─────────────────────────────────────────────
#  Market Init — MISO
# ─────────────────────────────────────────────
function initFunc_MISO([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    Set-TimeZone -Name 'Central Standard Time'
    Write-Info "Server timezone set to CST"

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
        "upload",

        "crow\archive",
        "crow\download"
    )

    foreach ($folder in $folders) {
        New-Item -Path "C:\MISO\$folder" -ItemType Directory -Force | Out-Null
    }

    New-Item -Path "C:\PCI\settlement" -ItemType Directory -Force | Out-Null
    New-Item -Path "C:\PCI\archive\settlement" -ItemType Directory -Force | Out-Null

    Copy-Item (Join-Path $ConfigFilesDir "miso.jks") C:\MISO\certs\miso.jks -Force -ErrorAction Stop
    Copy-Item "$CertDir\*" C:\MISO\certs -Recurse -Force
}

# ─────────────────────────────────────────────
#  Market Init — NYISO
# ─────────────────────────────────────────────
function initFunc_NYISO([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    Set-TimeZone -Name 'Eastern Standard Time'
    Write-Info "Server timezone set to EST"

    $folders = @(
        "Adders",
        "Archive",
        "Certificates",
        "Download",
        "Imports",
        "LoadFromDirectory",
        "Production",
        "Settlements",
        "Statements",
        "Upload",
        "Weather",

        "Archive\Transactions",

        "Imports\LoadForecast",
        "Imports\Transactions",

        "Production\Imports\Banding",
        "Production\Imports\FuelPrices",
        "Production\Imports\LoadForecast",
        "Production\Imports\Temperatures",
        "Production\Imports\UnitOffers",

        "Settlements\Archive",
        "Settlements\Statements",

        "Upload\Auto"
    )

    foreach ($folder in $folders) {
        New-Item -Path "C:\NYISO\$folder" -ItemType Directory -Force | Out-Null
    }

    Copy-Item (Join-Path $ConfigFilesDir "ISONE_NYISO_Keystore.jks") C:\NYISO\Certificates\PCIKEY.keystore -Force -ErrorAction Stop
    Copy-Item "$CertDir\*" C:\NYISO\Certificates -Recurse -Force
}

# ─────────────────────────────────────────────
#  Market Init — PJM
# ─────────────────────────────────────────────
function initFunc_PJM([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    Set-TimeZone -Name 'Eastern Standard Time'
    Write-Info "Server timezone set to EST"

    $pciFolders = @(
        "archive",
        "certificates",

        "certificates\pki"
    )

    foreach ($folder in $pciFolders) {
        New-Item -Path "C:\PCI\$folder" -ItemType Directory -Force | Out-Null
    }

    $pjmFolders = @(
        "archive",
        "auto",
        "download",
        "download2",
        "invoices",
        "settlements",
        "upload",
        "uploadAuto",

        "invoices\invoiceDownload",
        "invoices\pdfDisplay",
        "invoices\pdfDownload",

        "settlements\archive",
        "settlements\download",
        "settlements\download2",
        "settlements\statementLoad",
        "settlements\statements"
    )

    foreach ($folder in $pjmFolders) {
        New-Item -Path "C:\PJM\$folder" -ItemType Directory -Force | Out-Null
    }

    Copy-Item (Join-Path $ConfigFilesDir "PCIKEY.keystore") C:\PJM\PCIKEY.keystore -Force -ErrorAction Stop
    Copy-Item "$CertDir\*" C:\PCI\certificates\pki -Recurse -Force
}

# ─────────────────────────────────────────────
#  Market Init — SPPIM
# ─────────────────────────────────────────────
function initFunc_SPPIM([string]$clientName, [string]$CertDir, [string]$ConfigFilesDir) {
    Set-TimeZone -Name 'Central Standard Time'
    Write-Info "Server timezone set to CST"

    $folders = @(
        "archive",
        "certificates",
        "download",
        "sppts",
        "statements",
        "test",
        "upload",

        "archive\settlement",
        "settlement\archiveInvoices",
        "settlement\archiveStatements",
        "settlement\invoices",
        "settlement\misc_Statements",
        "settlement\statements",
        "upload\auto"
    )

    foreach ($folder in $folders) {
        New-Item -Path "C:\PCI\$folder" -ItemType Directory -Force | Out-Null
    }

    New-Item -Path "C:\iso_messages\archive" -ItemType Directory -Force | Out-Null

    Copy-Item (Join-Path $ConfigFilesDir "sppim_2017.JKS") C:\PCI\certificates\sppim_2017.JKS -Force -ErrorAction Stop
    Copy-Item "$CertDir\*" C:\PCI\certificates -Recurse -Force
}

# ─────────────────────────────────────────────
#  WebLogic — Load Oracle ODP
# ─────────────────────────────────────────────
function loadOracle {
    # Load Function Library & Assembly files:
    Param(
        [Parameter(Mandatory = $false)][switch]$wlpwd,
        [Parameter(Mandatory = $true)][string]$SharedFilesDir
    )

    $odpZip = Join-Path $SharedFilesDir "ODP.NET_Managed_ODAC122cR1.zip"
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
            throw 'ODP extraction failed. Check drive space and permissions'
        }
    }

    # Verify previous run of install.bat
    if (!(test-path 'C:\oracle\odp.net\')) {
        if (!(test-path -type leaf $ora12local)) {
            Write-Warn "ODP assembly not found"
            Write-Info "Installing ODP managed drivers..."
            &cmd /c "cd $odpInstall && $odpInstallbat $odpInstallParam1 $odpInstallParam2 $odpInstallParam3" | Out-Null
        }
    }

    if (test-path -type leaf $ora12local) {
        Add-Type -Path $ora12local
        Write-Success "ODP assembly loaded"
    }
    else {
        throw "Cannot find $ora12local to load"
    }
}

# ─────────────────────────────────────────────
#  WebLogic — Environment
# ─────────────────────────────────────────────
function getEnv {
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

# ─────────────────────────────────────────────
#  WebLogic — config.xml SSL + Mail
# ─────────────────────────────────────────────
function wl_config_modify($file, $jksFile, $enc_pw) {
    if (!(($file) -or ($jksFile) -or ($enc_pw))) {
        throw 'Missing a SSL input'
    }

    $saveit = 0
    $xml = [xml](Get-Content $file)
    $encrypter_value = $enc_pw

    if (!(($xml.domain.server.ssl.enabled.ToString()) -eq 'true')) {
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
        Write-Success "SSL block added"
    }
    else {
        Write-Info "SSL already in WebLogic config.xml"
    }

    if (!($xml.domain['mail-session'])) {
        $xmlMail = $xml.CreateElement("mail-session", "http://xmlns.oracle.com/weblogic/domain");
        $deploy = $xml.domain.InsertAfter($xmlMail, $xml.domain.jmx)
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("name", "http://xmlns.oracle.com/weblogic/domain"));
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("target", "http://xmlns.oracle.com/weblogic/domain"));
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("jndi-name", "http://xmlns.oracle.com/weblogic/domain"));
        $newXmlNameElement = $xmlMail.AppendChild($xml.CreateElement("properties", "http://xmlns.oracle.com/weblogic/domain"));
        $xml.domain.'mail-session'.name = 'GPMailSession'
        $xml.domain.'mail-session'.target = $(hostname).toString().toLower()
        $xml.domain.'mail-session'.'jndi-name' = 'GPMailSession'
        $xml.domain.'mail-session'.properties = "debug=true;mail.transport.protocol=SMTP;mail.user=PCI_Support;mail.host=365mail.powercosts.com_bk;mail.store.protocol=POP3";
        $saveit = 1
        Write-Success "Mail block added"
    }
    else {
        Write-Info "Mail block already in Weblogic config.xml"
    }

    if ($saveit -ne 0) {
        Write-Info "Backing up existing weblogic config.xml..."
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

        Write-Success "Weblogic config.xml modified"
    }
}

# ─────────────────────────────────────────────
#  SQL Helpers
# ─────────────────────────────────────────────
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

function genericSQL([string]$Market, [string]$Environment, [string]$ConfigFilesDir) {
    $genericSQLPath = Join-Path $ConfigFilesDir "genericSQL_$Market.sql"
    if (!(Test-Path $genericSQLPath)) {
        throw "Missing generic SQL file: $genericSQLPath"
    }
    $sql = Get-Content -Path $genericSQLPath -Raw

    if ($Market -eq 'ERCOT') {
        if (-not $Environment) { throw "genericSQL: ERCOT requires an Environment value (MOTE or PROD)" }
        # USE_MODE: 'S' = MOTE/Sandbox, 'M' = Production/MIS
        $useModeValue = if ($Environment -eq 'PROD') { 'M' } else { 'S' }
        $sql = $sql -replace '("USE_MODE",\s*\r?\n\s*)"S"', "`$1`"$useModeValue`""
    }
    elseif ($Market -eq 'CAISO') {
        if (-not $Environment) { throw "genericSQL: CAISO requires an Environment value (N or P)" }
        # USE_MODE: 'N' = Map Stage, 'P' = Production
        $pattern = "(VALUE = ')[^']*(' WHERE SYSTEM = 'GenManager' and TYPE = 'CAISO' and NAME = 'USE_MODE')"
        $sql = $sql -replace $pattern, "`${1}$Environment`${2}"
    }

    return $sql
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

# The client SQL text itself is generated ahead of time, locally, by Start-CloudDomainConfig.ps1
# (see ClientSqlGeneratorDispatcher.ps1) so the target VM never needs ImportExcel or the raw spreadsheet --
# only the resulting .sql file is staged/transferred, same as every other market. Configure_Domain.ps1
# just reads that file and wraps it, exactly like it always has.
function clientSQL([string]$SqlFilePath) {
    if (-not (Test-Path $SqlFilePath)) {
        throw "Client SQL file not found: $SqlFilePath"
    }
    $sql = Get-Content -Path $SqlFilePath -Raw
    return @"
BEGIN
$sql
COMMIT;
END;
"@
}

# ─────────────────────────────────────────────
#  Service Helpers
# ─────────────────────────────────────────────
function Restart-ServiceSafely {
    param(
        [string]$ServiceName,
        [int]$StopTimeoutSec = 30,
        [int]$StartTimeoutSec = 30
    )

    $currentStatus = (Get-Service $ServiceName).Status

    # STOP
    Write-Step "Stopping $ServiceName..."

    if ($currentStatus -ne 'Stopped') {
        Stop-Service $ServiceName -ErrorAction Stop

        $elapsed = 0
        while ((Get-Service $ServiceName).Status -ne 'Stopped') {
            if ($elapsed -ge $StopTimeoutSec) {
                throw "$ServiceName failed to stop after ${StopTimeoutSec}s"
            }
            Start-Sleep -Seconds 2
            $elapsed += 2
        }
        Write-Success "Service stopped (after ${elapsed}s)"
    }
    else {
        Write-Warn "$ServiceName already stopped"
    }

    # START
    Write-Step "Starting $ServiceName..."

    $startTime = Get-Date
    Start-Service $ServiceName -ErrorAction Stop -WarningAction SilentlyContinue

    $elapsed = [int](New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
    Write-Success "Service running (after ${elapsed}s)"
}
