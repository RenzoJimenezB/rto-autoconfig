UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'pci office - shell test automatedx20924 (caiso_certificate_authority_issuing)',
    PASSWORD    = 'caisoteam',
    CERT_DETAILS = 'CN=PCI OFFICE - SHELL TEST AUTOMATEDx20924,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AVCE',
        'CEMA',
        'CLPH',
        'CLTN',
        'CRL1',
        'CRLC',
        'CRLL',
        'CRLP',
        'CRLT',
        'CRLU',
        'CRN1',
        'CSFT',
        'CTID',
        'CVOY',
        'EBMD',
        'IGLR',
        'IVLY',
        'KMPD',
        'LWRD',
        'PSTN',
        'PTUA',
        'RETQ',
        'SCPA',
        'SCRI',
        'TMCO',
        'YCWA'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET ACTIVE = 'N'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER 
    WHERE NAME IN (
        'CRL1',
        'PTUA'
    )
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'C:\CAISO\Settlements\SFTP\shelluser.openssh.id'
WHERE NAME IN (
    'CEMA_CERT',
    'CLPH_CERT',
    'CLTN_CERT',
    'CRLC_CERT',
    'CRLL_CERT',
    'CRLP_CERT',
    'CRLT_CERT',
    'CRN1_CERT',
    'CSFT_CERT',
    'CTID_CERT',
    'IVLY_CERT',
    'KMPD_CERT',
    'PSTN_CERT',
    'TMCO_CERT'
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'IbYM9ati'
WHERE NAME IN (
    'CEMA_CERT_PASSWORD',
    'CLPH_CERT_PASSWORD',
    'CLTN_CERT_PASSWORD',
    'CRLC_CERT_PASSWORD',
    'CRLL_CERT_PASSWORD',
    'CRLP_CERT_PASSWORD',
    'CRLT_CERT_PASSWORD',
    'CRN1_CERT_PASSWORD',
    'CSFT_CERT_PASSWORD',
    'CTID_CERT_PASSWORD',
    'IVLY_CERT_PASSWORD',
    'KMPD_CERT_PASSWORD',
    'PSTN_CERT_PASSWORD',
    'TMCO_CERT_PASSWORD'
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'xcrlpaccessserver'
WHERE NAME IN (
    'CEMA_SFTP_USER',
    'CLPH_CERT_USER',
    'CLTN_SFTP_USER',
    'CRLC_SFTP_USER',
    'CRLL_SFTP_USER',
    'CRLP_SFTP_USER',
    'CRLT_SFTP_USER',
    'CRN1_SFTP_USER',
    'CSFT_SFTP_USER',
    'CTID_SFTP_USER',
    'IVLY_SFTP_USER',
    'KMPD_CERT_USER',
    'PSTN_SFTP_USER',
    'TMCO_CERT_USER'
);