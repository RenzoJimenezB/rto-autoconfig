------------------------------------------------------------------------------
-- 4) SASSET_OWNER_CONFIG: Set EKPC Asset Owners
------------------------------------------------------------------------------

-- Primary Asset Owner credentials
UPDATE SASSET_OWNER_CONFIG
SET ACTIVE      = 'Y',
	CERTIFICATE = 'PCIsand',
    PASSWORD    = 'M0C?2018$Gen'
WHERE ASSET_OWNER_KEY = (
    SELECT ASSET_OWNER_KEY
    FROM SASSET_OWNER
    WHERE NAME = 'EKPC' --Asset Owner name
);

-- Custom Properties
UPDATE SASSET_OWNER_CONFIG
SET
    -- Production PKI
    USER15 = 'C:\PCI\certificates\pki\PCI-EKPC-PJM-PROD-RO.p12',
    USER16 = 'EKPC_pjm_PK1!',

    -- Sandbox PKI
    USER17 = 'C:\PCI\certificates\pki\PCI-EKPC-PJM-SAND-RW.p12',
    USER18 = 'EKPC_pjm_PK1!',

    -- Sandbox credentials
    USER19 = 'PCIsand',
    USER20 = 'M0C?2018$Gen'
WHERE ASSET_OWNER_KEY = (
    SELECT ASSET_OWNER_KEY
    FROM SASSET_OWNER
    WHERE NAME = 'EKPC' --Asset Owner name
);