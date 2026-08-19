UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'C:\PCI\certificates\PCI_ReadOnly1 (2025-2027).pfx',
    PASSWORD = 'ATKm@ncw975n',
-- Prod Screen Name
    USER1 = 'EX000002420',
-- Prod API Key
    USER2 = 'Y9xJTNcjxXcCpSX5fyv9tnKF4yrckF/XflqjbuK7pTETS23QwH6cifAkoVHJR3WhNEPTWtAmlQ7Py6NaRq0TqA==',
-- MTE Screen Name
    USER3 = 'EX000001043',
-- MTE API Key
    USER4 = '2yMW/Qzu171EYzy4tY+9UdeYSWrvs+WhZUMwtDXr0jDFQp69dCD8CDynodg/KkIAKFZGzPxLSzUnAkRCspnAzg==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCI_TEST_MTECCE_READWRITE (2026-2028).pfx',
-- MTE Password
    USER6 = 'nH15TPxTZr!w'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'BEPM',
        'BEPW_X',
        'CP01_X',
        'CRBC_X',
        'ER01_X',
        'LRS1_X',
        'N01_X',
        'NMCA_X',
        'PNLK_X',
        'SXLD_X',
        'UM01_X'
    )
);

UPDATE SLOV_VALUE
SET
    PROPERTY1 = 'C:\PCI\certificates\PCI_ReadOnly1 (2025-2027).pfx',
    PROPERTY2 = 'ATKm@ncw975n'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'SPPIM CROW Market Participant Info');