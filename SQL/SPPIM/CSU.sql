UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'C:\PCI\certificates\PCI_CSU_Oasis_SPPIM.pfx',
    PASSWORD = 'Oati$2022',
-- Prod Screen Name
    USER1 = 'EX000006210',
-- Prod API Key
    USER2 = 'xz7wSiqjUbVgb6fdQtEBHC7/Jl1MFiI7Z15D6PpiO3LQxiGrmniJl2W4TD+is8ok6CgqI3E5qfcZ9BJBNEUx+g==',
-- MTE Screen Name
    USER3 = 'EX000003008',
-- MTE API Key
    USER4 = 'oFfqQrZeii9dP9NQkYPa7TFW2iicq8nA5/26lcJJRddHAgceMoJLKj5QnLi3xb2F4w/0DSZvzWQ33za8Dv+AfQ==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCI_CSU_Oasis_SPPIM.pfx',
-- MTE Password
    USER6 = 'Oati$2022'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'CSU',
        'CSUM',
        'OTER'
    )
);

UPDATE SLOV_VALUE
SET
    PROPERTY1 = 'C:\PCI\certificates\PCI SPPIM Crow Test.pfx',
    PROPERTY2 = 'Oati$2022'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'SPPIM CROW Market Participant Info');