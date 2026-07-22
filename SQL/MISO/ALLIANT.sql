UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\Settlements Read Only AERM 2027_08_28.pfx',
    PASSWORD = 'Alliantets!',
    CERT_DETAILS = 'C:\MISO\certs\Settlements Read Only AERM 2027_08_28.pfx'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AERM',
        'FCW',
        'FORWARD',
        'RVRS'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\Settlements Read Only ALTM 2027_08_28.pfx',
    PASSWORD = 'Alliantets!',
    CERT_DETAILS = 'C:\MISO\certs\Settlements Read Only ALTM 2027_08_28.pfx'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AIPL',
        'AIPL_2',
        'AIPL_ESR',
        'AIPL_ESR_2',
        'ALTM',
        'AWPL',
        'AWPL_2',
        'AWPL_ESR',
        'BEARCRK',
        'CIPCO',
        'CRAWFISH',
        'NROCK',
        'WOODCTY',
        'WRIV'
    )
);

UPDATE SLOV_VALUE
SET
    PROPERTY1 = 'C:\MISO\certs\Settlements Read Only ALTM 2027_08_28.pfx',
    PROPERTY2 = 'Alliantets!'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'MISO CROW Market Participant Info');