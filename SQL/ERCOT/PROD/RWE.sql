UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'pci mis ro qecnr6',
    PASSWORD = 'changeit',
    CERT_DETAILS = 'C:\ERCOT\BO\Certificates\PROD\deploy_qecnr6.wsdd'
WHERE ASSET_OWNER_KEY = (SELECT ASSET_OWNER_KEY FROM SASSET_OWNER WHERE NAME = 'QECNR6');

UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'pci mis ro xecnr1',
    PASSWORD = 'changeit',
    CERT_DETAILS = 'C:\ERCOT\BO\Certificates\PROD\deploy_xecnr1.wsdd'
WHERE ASSET_OWNER_KEY = (SELECT ASSET_OWNER_KEY FROM SASSET_OWNER WHERE NAME = 'XECNR1');

UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'pci mis ro xecnr2',
    PASSWORD = 'changeit',
    CERT_DETAILS = 'C:\ERCOT\BO\Certificates\PROD\deploy_xecnr2.wsdd'
WHERE ASSET_OWNER_KEY = (SELECT ASSET_OWNER_KEY FROM SASSET_OWNER WHERE NAME = 'XECNR2');

-- No PROD cert available: QECNR, QECNR2, QECNR3, QECNR4, QECNR5 stay deactivated (generic SQL default)
