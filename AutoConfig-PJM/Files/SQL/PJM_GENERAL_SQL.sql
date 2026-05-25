------------------------------------------------------------------------------
-- 1) CombinedSQL_PCIKEY_keystore.sql (\\nas3\shared\Market Systems\PJM\1. Setting up a Cloud Domain\2. SQL\1. CombinedSQL_PCIKEY_keystore.txt)
------------------------------------------------------------------------------
update SASSET_OWNER_CONFIG set ACTIVE='N';
commit;
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='DR_HUB_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='EX_SCHEDULE_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='FTR_CENTER_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='IN_SCHEDULE_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='MARKETS_GATEWAY_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='MSRS_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
UPDATE SPARAMETER SET VALUE ='https://ssotrain.pjm.com/access/authenticate/pjmauthcert' WHERE NAME='POWER_METER_SANDBOX_AUTH_HOST' and SYSTEM='ISOCOMM' and TYPE='_PJM_';
update sparameter set value='C:\FileFolders\PJM\download' where name='DOWNLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='_SYSTEM_';
update sparameter set value='C:\FileFolders\PJM\Settlements\statements' where name='SETTLEMENT_STATEMENTS' AND SYSTEM='GenManager' AND TYPE='_SYSTEM_';
update sparameter set value='C:\FileFolders\PJM\upload' where name='UPLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='_SYSTEM_';
update sparameter set value='C:\FileFolders\PJM\download2' where name='DOWNLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='_PJM_';
update sparameter set value='C:\FileFolders\PJM\archive' where name='ARCHIVE_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\auto' where name='AUTO_UPLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\Settlements\download' where name='DOWNLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\invoices\invoiceDownload' where name='INVOICE_LOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\Settlements\archive' where name='SETTLEMENT_ARCHIVE_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\Settlements\download2' where name='SETTLEMENT_DOWNLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\invoices\pdfDisplay' where name='SETTLEMENT_INVOICE_PDF_DISPLAY_DIR' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\invoices\pdfDownload' where name='SETTLEMENT_INVOICE_PDF_DOWNLOAD_DIR' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\Settlements\statementLoad' where name='STATEMENT_LOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\PJM\PCIKEY.Keystore' where name='TRUST_STORE' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='C:\FileFolders\PJM\uploadAuto' where name='UPLOAD_DIRECTORY' AND SYSTEM='GenManager' AND TYPE='PJM';
update sparameter set value='Y' where name='EDART_SANDBOX' AND SYSTEM='GenManager' AND TYPE='_SYSTEM_';
update sparameter set value='-' where name='EDART_URL_S' AND SYSTEM='AssetOperations' AND TYPE='OutageManagementPJM';
update sparameter set value='-' where name='USE_MODE' AND SYSTEM='AssetOperations' AND TYPE='OutageManagementPJM';
commit;
update suser set U_PASSWORD='gtwp$pci1';
update suser set SOURCE='S';
update sparameter set value='gtwp$pci1' where name='BACKGROUND_PASSWORD';
update sparameter set value='tQJPeerA' where name='TRUST_STORE_PASSWORD';
commit;

------------------------------------------------------------------------------
-- 2) SPARAMETER: Driver Options PJM
------------------------------------------------------------------------------
UPDATE SPARAMETER
SET VALUE = 'C:\FileFolders\PJM\archive',
    DESCRIPTION = 'File archive location'
WHERE NAME = 'ARCHIVE_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\FileFolders\PJM\uploadAuto',
    DESCRIPTION = 'Auto-upload directory'
WHERE NAME = 'AUTO_UPLOAD_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\FileFolders\PJM\download',
    DESCRIPTION = 'Download directory'
WHERE NAME = 'DOWNLOAD_DIRECTORY';

UPDATE SPARAMETER
SET VALUE = 'C:\PJM\PCIKEY.keystore',
    DESCRIPTION = 'SSL keystore'
WHERE NAME = 'TRUST_STORE';

UPDATE SPARAMETER
SET VALUE = 'tQJPeerA',
    DESCRIPTION = 'Keystore password'
WHERE NAME = 'TRUST_STORE_PASSWORD';

UPDATE SPARAMETER
SET VALUE = 'C:\FileFolders\PJM\upload',
    DESCRIPTION = 'Manual upload folder'
WHERE NAME = 'UPLOAD_DIRECTORY';

------------------------------------------------------------------------------
-- 3) SPARAMETER: Set PJM Sandbox Mode
------------------------------------------------------------------------------
UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'DATA_MINER_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'DR_HUB_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'EX_SCHEDULE_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'FTR_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'MARKETS_GATEWAY_REST_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'MSRS_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'POWER_METER_MODE'
  AND SYSTEM = 'ISOCOMM'
  AND TYPE = '_PJM_';

UPDATE SPARAMETER
SET VALUE = 'S'
WHERE NAME = 'IN_SCHEDULE_MODE'
  AND SYSTEM = 'GenManager'
  AND TYPE = '_SYSTEM_';
  
commit;