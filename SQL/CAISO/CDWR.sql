UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'cdwr pci-cdwr (caiso_certificate_authority_issuing)',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = 'CN=CDWR PCI-CDWR,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'APXD',        
        'CDWR',        
        'CMWD',        
        'CWRT',
        'MET1',
        'AIE2',
        'EXC_TGEM_2258',
        'EXC_TGEM_2905',
        'SLVD'
    )
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'C:\CAISO\Settlements\SFTP\cdwruser.openssh.id'
WHERE NAME IN (
    'APXD_CERT',
    'CDWR_CERT',
    'CMWD_CERT',
    'CWRT_CERT',
    'MET1_CERT'
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'cdwruser'
WHERE NAME IN (
    'APXD_CERT_PASSWORD',
    'CDWR_CERT_PASSWORD',
    'CMWD_CERT_PASSWORD',
    'CWRT_CERT_PASSWORD',
    'MET1_CERT_PASSWORD'
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'cdwruser'
WHERE NAME IN (
    'APXD_SFTP_USER',
    'CDWR_SFTP_USER',
    'CMWD_SFTP_USER',
    'CWRT_SFTP_USER',
    'MET1_SFTP_USER'
);