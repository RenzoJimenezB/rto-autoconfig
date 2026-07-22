UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\Khai Le (MECB).pfx',
    PASSWORD = 'Tkhaile.mec.25',
    CERT_DETAILS = 'C:\MISO\certs\Khai Le (MECB).pfx'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'EME',
        'MECB_G',
        'MECB_LGS',
        'MECB_N4',
        'MECB_WS3',
        'MECB_WS4'
    )
);