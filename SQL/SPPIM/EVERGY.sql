-- Asset Owners with Market Participant Name = WRGS
UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\PCI\certificates\Client_Certificates\Evergy\006943781$API_WRGSQSE2.pfx',
    PASSWORD = '3QiCq$VsysuLQ',
-- Prod Screen Name
    USER1 = 'EX000004355',
-- Prod API Key
    USER2 = 'aGG/JiVaQ/uhK51+NKCcsebusL7JmyUwlpfuD8teZQLeMg6DMqSiDpFFye9dZGmrxTANvAwxFnZope97FtpDKg==',
-- MTE Screen Name
    USER3 = 'EX000000450',
-- MTE API Key
    USER4 = 'UzfstyYyHYm6nuI+owEcKVXlHyJfMmpm3j+PFy2mQzBaW2JPU9YCAnJJzV2u5LrgwCWgyKLjakhyoxfWfZWPLA=='
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        '1073',
        'BUCK_X',
        'CLW1',
        'COWP',
        'DEC',
        'FR3',
        'FSEC',
        'HCPP_X',
        'KEPC',
        'KN01',
        'KVEC',
        'NIXA',
        'NMEC',
        'PARL',
        'PBEL',
        'PEOP_X',
        'PLWC',
        'WR1_X',
        'WR2_X',
        'WR3_X',
        'WRGS',
        'WRKM_X'
    )
);

-- Asset Owners with a Market Participant Name other than WRGS
UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\PCI\certificates\Client_Certificates\Evergy\006943781$API_WRGSQSE2.pfx',
    PASSWORD = '3QiCq$VsysuLQ',
-- Prod Screen Name
    USER1 = 'EX000004355',
-- Prod API Key
    USER2 = 'aGG/JiVaQ/uhK51+NKCcsebusL7JmyUwlpfuD8teZQLeMg6DMqSiDpFFye9dZGmrxTANvAwxFnZope97FtpDKg==',
-- MTE Screen Name
    USER3 = 'EX000000450',
-- MTE API Key
    USER4 = 'UzfstyYyHYm6nuI+owEcKVXlHyJfMmpm3j+PFy2mQzBaW2JPU9YCAnJJzV2u5LrgwCWgyKLjakhyoxfWfZWPLA=='
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'CFSP',
        'CHAN',
        'DGPM',
        'EDEP',
        'ETEC',
        'GDWL',
        'JFY_X',
        'KCPS',
        'KFOS_X',
        'MIDW',
        'MJST',
        'MNCO',
        'OLSP',
        'PARL_X',
        'PEC',
        'SIKE',
        'SLNG',
        'UCU'
    )
);