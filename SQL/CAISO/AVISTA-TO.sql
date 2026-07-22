UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'pci eesc test user1x18157 (caiso_certificate_authority_issuing)',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = 'CN=PCI EESC TEST USER1x18157,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AVAM',        
        'AVAT',        
        'AVISTA'        
    )
);