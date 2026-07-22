UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'srp pci-srp-test-stfx13513 (caiso_certificate_authority_issuing)',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = 'CN=SRP PCI-SRP-TEST-STFx13513,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'SRP1',
        'SRP_BA',
        'SRPE',
        'SRPM'
    )
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'C:\CAISO\Settlements\SFTP\pcisrp1serveraccess'
WHERE NAME IN (
    'SRP1_CERT',
    'SRPM_CERT'
) ;

UPDATE SCUSTOM_FIELD
SET VALUE = 'tQJPeerA'
WHERE NAME IN (
    'SRP1_CERT_PASSWORD',
    'SRPM_CERT_PASSWORD'
) ;

UPDATE SCUSTOM_FIELD
SET VALUE = 'pcisrp1serveraccess'
WHERE NAME IN (
    'SRP1_SFTP_USER',
    'SRPM_SFTP_USER'
) ;