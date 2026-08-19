UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'C:\PCI\certificates\PCIXCELMISOSPPIMRO.pfx',
    PASSWORD = 'Spiupo23!',
-- Prod Screen Name
    USER1 = 'EX000001282',
-- Prod API Key
    USER2 = '08D2AhZkZuh2749F9RqrwSNkkgmtIvfF3iH0+UZjj0PG4wA9ogzpFRUnLYOYCpdVJ7oF1XOirQ1Vpm1fySLL8g==',
-- MTE Screen Name
    USER3 = 'EX000000556',
-- MTE API Key
    USER4 = '5vu1AQrlcneIvjw8Ef05M1xXhtgxySmuBHAEYSI6xAn31yMUofRDNaEF5azcmLVx+dclfndCr72tz1RwpFS+ug==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCIXCELMISOSPPIMRO.pfx',
-- MTE Password
    USER6 = 'Spiupo23!'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'COFC',
        'EXGW_X',
        'NSPP',
        'NSPT',
        'NSPT_X',
        'PSC2',
        'PSCM',
        'PSCP',
        'SPSM',
        'SPSP'
    )
);

UPDATE SLOV_VALUE
SET
    PROPERTY1 = 'C:\PCI\certificates\PCIXCELMISOSPPIMRO.pfx',
    PROPERTY2 = 'Spiupo23!'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'SPPIM CROW Market Participant Info');