UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'C:\PCI\certificates\PCI OGE Hosted TEST.pfx',
    PASSWORD = 'oge1234$',
-- Prod Screen Name
    USER1 = 'EX000003997',
-- Prod API Key
    USER2 = '8aB+KsUQW3s6jrvlscMXoB6qN22XE6b/w+6t4md6nEgvl2W7i1WHKNVeAPaA2sLkTVnaMTPux3qT35vdmch1GA==',
-- MTE Screen Name
    USER3 = 'EX000001937',
-- MTE API Key
    USER4 = 'EeHzxh/m4URlMcr/iPCjsyExJgbRDqR3sARS0Z47EzOw9I0JzehbPcktn6opX+cYBBCM0wyJ/3KsNm71plNIKw==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCI OGE Hosted TEST.pfx',
-- MTE Password
    USER6 = 'oge1234$'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'OGE',
        'OGMC_X',
        'OGRB_X'
    )
);

UPDATE SLOV_VALUE
SET
    PROPERTY1 = 'C:\PCI\certificates\PCI OGE Hosted TEST.pfx',
    PROPERTY2 = 'oge1234$'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'SPPIM CROW Market Participant Info');