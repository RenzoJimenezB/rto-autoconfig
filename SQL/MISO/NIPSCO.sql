UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\PCI NAI TEST.pfx',
    PASSWORD = 'Pnt@123@tnp',
    CERT_DETAILS = 'C:\MISO\certs\PCI NAI TEST.pfx'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AM',
        'BP',
        'CARGILL',
        'NIP',
        'NLMK_IN',
        'PRATT PAPER',
        'PRAXAIR',
        'USS'
    )
);