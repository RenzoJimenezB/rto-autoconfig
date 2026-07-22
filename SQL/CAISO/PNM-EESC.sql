UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'pci sysusermapx15897 (caiso_certificate_authority_issuing)',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = 'CN=PCI SYSUSERMAPx15897,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AZPR',
        'GUZC',
        'NEWMEXICO',
        'NMEE',
        'NMPR',
        'TSPR'
    )
);