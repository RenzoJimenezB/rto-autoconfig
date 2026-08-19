-- Asset Owners with Market Participant Name = WRGS
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'C:\PCI\certificates\PCI_API_SPP_WRGS_NORMAN.pfx',
    PASSWORD = 'Evergy123!',
-- Prod Screen Name
    USER1 = 'EX000004343',
-- Prod API Key
    USER2 = 'fw0FxuMbAoI3/u+rFVHUheJXY3DEMxs9vhoyR6jjXBMenmQaLpjtqc2ptplMsMkB1hAq0u+993rx0GeLr2ZlIQ==',
-- MTE Screen Name
    USER3 = 'EX000001979',
-- MTE API Key
    USER4 = 'rp0P2OoMcZC2/PLEHQ1Ev4x9dGsWl7awECFx+DhPtebkS7VYFuCcBI/8oLWKG4Bk4ahblGfEKZZB1l1r9B0Gpw==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCI_API_SPP_WRGS_NORMAN.pfx',
-- MTE Password
    USER6 = 'Evergy123!'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        '1073',
        'BUCK_X',
        'CHAN',
        'CLW1',
        'COWP',
        'FSEC',
        'HCPP_X',
        'KEPC',
        'KN01',
        'KVEC',
        'NMEC',
        'PBEL',
        'PEC',
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
    ACTIVE = 'Y',
    SETTLE = 'Y',
    CERTIFICATE = 'C:\PCI\certificates\PCI_API_SPPIM_NORMAN_27.pfx',
    PASSWORD = '50ftRoman!',
-- Prod Screen Name
    USER1 = 'EX000000617',
-- Prod API Key
    USER2 = 'tQkbOClbOCnsjF6UIERSI7gwsJdg/M5TV024do+yPI/WIaQ8u9mfSNo5+nPo7XPx1/mNBN45s/kq2mS8wk/GZA==',
-- MTE Screen Name
    USER3 = 'EX000000372',
-- MTE API Key
    USER4 = 'mHJKQPatzWNzUvTNGA4gLmuWtXlnCVkMsLtb/UzxvuNfeIPEyG8z/ppc07xTwes0xPhwynuqDQdWlfrHN7Dg/w==',
-- MTE Certificate
    USER5 = 'C:\PCI\certificates\PCI_API_SPPIM_NORMAN_27.pfx',
-- MTE Password
    USER6 = '50ftRoman!'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'CFSP',
        'EDEP',
        'GDWL',
        'JFY_X',
        'KCPS',
        'KFOS_X',
        'MJST',
        'MNCO',
        'PARL_X',
        'SIKE',
        'SLNG',
        'UCU'
    )
);
