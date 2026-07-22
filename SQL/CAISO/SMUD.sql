UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'smud pci_rox2315 (caiso_certificate_authority_issuing)',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = 'CN=SMUD PCI_ROx2315,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'BANC',
        'BANCSMUD',
        'EXC_SMD3_1637',
        'EXC_SMD3_1973',
        'GPCC',
        'SEIM',
        'SMD3',
        'SMUD',
        'VCEA'
    )
);