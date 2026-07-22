UPDATE SASSET_OWNER_CONFIG
SET CERTIFICATE = 'C:\PCI\certificates\PCI_Prod_and_MTE.pfx',
PASSWORD = 'M@k31tR@1n!'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'CMLP',
        'GRDX',
        'OGRB_X'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET
-- Prod API Key and Screen Name need to be updated!
-- Prod Screen Name
    USER1 = 'EX000010102',
-- Prod API Key
    USER2 = 'EhsN9z+6/LnjT6Gtmola3v4LquqwIeci8kCIiiBcoF5fYnQNAO+yfwzHXl3mm2wcFYNm3k6C7L6g8bbyw4J0Uw==',
-- MTE Screen Name
    USER3 = 'EX000004641',
-- MTE API Key
    USER4 = 'wQeFLQqku+ujEojw9B/2Vxo1L0pjFJrIPSoX7rK9qLSgbbW7R7p5t+RAABYDGuZj+Q/yLQ0tw6qyRxjyV/BPWA==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCI_Prod_and_MTE.pfx',
-- MTE Password
    USER6 = 'M@k31tR@1n!';