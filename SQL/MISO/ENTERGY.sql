UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\pci_test_eamp.p12',
    PASSWORD = 'entergyOT!', 
    CERT_DETAILS = 'C:\MISO\certs\pci_test_eamp.p12'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'EAMP',
        'EAMP_ANO1',
        'EAMP_ANO2',
        'EAMP_BIGRST',
        'EAMP_DRVRSOL',
        'EAMP_GG',
        'EAMP_IN1',
        'EAMP_IN2',
        'EAMP_OIS',
        'EAMP_RLA',
        'EAMP_SEARCY',
        'EAMP_STGRT',
        'EAMP_SWPA',
        'EAMP_UPP1',
        'EAMP_WB1',
        'EAMP_WB2',
        'EAMP_WBSOL',
        'EAMP_WMPSOL'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\pci_test_elmp.p12',
    PASSWORD = 'entergyOT!',
    CERT_DETAILS = 'C:\MISO\certs\pci_test_elmp.p12'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'EGMP',
        'EGMP_AGRI',
        'EGMP_BELHEL',
        'EGMP_DOW',
        'EGMP_DOWMTR',
        'EGMP_FORMOS',
        'EGMP_LST',
        'EGMP_NEL6',
        'EGMP_RAIN',
        'EGMP_REP',
        'EGMP_SOWOOD',
        'EGMP_SRMPAIP',
        'EGMP_WODSTK',
        'ELMP',
        'ELMP_ACADIA',
        'ELMP_AGRI',
        'ELMP_ALG',
        'ELMP_BELHEL',
        'ELMP_CALPINE',
        'ELMP_DOW',
        'ELMP_DOWMTR',
        'ELMP_EVRGRN',
        'ELMP_FORMOS',
        'ELMP_GG',
        'ELMP_KAISR4',
        'ELMP_LST',
        'ELMP_MVDR',
        'ELMP_NEL6',
        'ELMP_NM6',
        'ELMP_PERRY',
        'ELMP_PT_ELLPT1',
        'ELMP_RAIN',
        'ELMP_REP',
        'ELMP_RLA',
        'ELMP_RVB',
        'ELMP_SCY',
        'ELMP_SOWOOD',
        'ELMP_SRMPAIP',
        'ELMP_STRSOL',
        'ELMP_TB',
        'ELMP_UNCARB',
        'ELMP_VIDALIA',
        'ELMP_WODSTK',
        'ELMP_WPEC',
        'ELMPCS'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\pci_test_emmp.p12',
    PASSWORD = 'entergyOT!',
    CERT_DETAILS = 'C:\MISO\certs\pci_test_emmp.p12'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'EMMP',
        'EMMP_GG',
        'EMMP_MEAM',
        'EMMP_MSCHEM',
        'EMMP_PT_EML20',
        'EMMP_RLA',
        'EMMP_SUNFLOWER'
    )
);


UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\pci_test_enmp.p12',
    PASSWORD = 'entergyOT!',
    CERT_DETAILS = 'C:\MISO\certs\pci_test_enmp.p12'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'ENMP',
        'ENMP_GG'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\pci_test_etmp.p12',
    PASSWORD = 'entergyOT!',
    CERT_DETAILS = 'C:\MISO\certs\pci_test_etmp.p12'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'ETMP',
        'ETMP_CALPINE',
        'ETMP_DUPSB',
        'ETMP_GLFWAY',
        'ETMP_HARDIN',
        'ETMP_HUNTS1',
        'ETMP_MAGNOL',
        'ETMP_MCPS',
        'ETMP_NISCO',
        'ETMP_OSG',
        'ETMP_SALTGR',
        'ETMP_SANJAC',
        'ETMP_STHSID',
        'ETMP_TB',
        'ETMP_VFWPRK'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET ACTIVE = 'N'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER 
    WHERE NAME IN (
        'ELMP_STRSOL',
        'IRIS',
        'PELI_BC2_3',
        'STJS',
        'SUNLIGHT ROAD',
        'TNSK_14',
        'TNSK_26',
        'TNSK_28'
    )
);