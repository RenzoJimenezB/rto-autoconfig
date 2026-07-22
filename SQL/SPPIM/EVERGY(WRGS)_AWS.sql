UPDATE suser
SET u_password = 'gtwp$pci1'
WHERE u_name IN ('Admin','background');

UPDATE SPARAMETER
SET "VALUE" = 'gtwp$pci1'
WHERE "NAME" = 'BACKGROUND_PASSWORD';

UPDATE SPARAMETER
SET VALUE = 'C:\sppim\Archive'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'ARCHIVE_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\sppim\AutoUpload'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'AUTO_UPLOAD_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\certs'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'CERTS_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\sppim\Download'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'DOWNLOAD_DIRECTORY';

UPDATE SPARAMETER
-- domain specific
SET VALUE = 'C:\sppim\Archive'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'SETTLEMENT_ARCHIVE_DIRECTORY';

UPDATE SPARAMETER
--domain specific
SET VALUE = 'C:\sppim\Statements'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'STATEMENT_LOAD_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\sppim\Upload'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'UPLOAD_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'M'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'USE_MODE';

UPDATE SPARAMETER
SET VALUE = 'C:\PCI\certificates\sppim_2017.jks'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'TRUST_STORE';

UPDATE SPARAMETER
SET VALUE = 'changeit'
WHERE SYSTEM = 'GenManager'
and TYPE = 'SPPIM'
and NAME = 'TRUST_STORE_PASSWORD';

UPDATE SPARAMETER
SET VALUE = 'C:\iso_messages\archive'
WHERE SYSTEM = 'GenManager'
and TYPE = 'ISO'
and NAME = 'CACHER_ARCHIVE_ROOT_DIR';

UPDATE SPARAMETER
SET VALUE = 'C:\iso_messages'
WHERE SYSTEM = 'GenManager'
and TYPE = 'ISO'
and NAME = 'CACHER_ROOT_PATH';

UPDATE SPARAMETER
SET VALUE = 'sppim'
WHERE SYSTEM = 'GenManager'
and TYPE = 'ISO'
and NAME = 'CACHER_ISO_PATH';

UPDATE SPARAMETER
SET VALUE = 'Prod'
WHERE SYSTEM = 'GenManager'
and TYPE = 'ISO'
and NAME = 'CACHER_SERVER_PATH';

UPDATE SPARAMETER
SET VALUE = 'Admin'
WHERE SYSTEM = 'GenManager'
and TYPE = 'ISO'
and NAME = 'USER_NAME';

UPDATE SPARAMETER
SET VALUE = 'gtwp'
WHERE SYSTEM = 'GenManager'
and TYPE = 'ISO'
and NAME = 'USER_PASSWORD';

UPDATE SPARAMETER
SET VALUE = 'PCI'
WHERE SYSTEM = 'GenPortal'
and TYPE = '_SYSTEM_'
and NAME = 'PORTAL_LOGO';

UPDATE SPARAMETER
SET VALUE = 'PCI'
WHERE SYSTEM = 'GenPortal'
and TYPE = '_SYSTEM_'
and NAME = 'PORTAL_LOGO_DARK';

-- This needs to be updated per client

UPDATE SASSET_OWNER_CONFIG
SET CERTIFICATE = 'C:\PCI\certificates\Client_Certificates\Evergy\006943781$API_WRGSQSE2.pfx',
PASSWORD = '3QiCq$VsysuLQ';

-- User1 is Prod's screen name, User2 is Prod's API KEY, User3 is MTE's screen name, User4 is MTE's API KEY

UPDATE SASSET_OWNER_CONFIG
-- Prod screen name and API key
SET USER1 = 'EX000004355',
USER2 = 'aGG/JiVaQ/uhK51+NKCcsebusL7JmyUwlpfuD8teZQLeMg6DMqSiDpFFye9dZGmrxTANvAwxFnZope97FtpDKg==',
-- MTE screen name and API key
USER3 = 'EX000000450',
USER4 = 'UzfstyYyHYm6nuI+owEcKVXlHyJfMmpm3j+PFy2mQzBaW2JPU9YCAnJJzV2u5LrgwCWgyKLjakhyoxfWfZWPLA==';