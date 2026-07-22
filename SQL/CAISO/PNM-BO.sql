UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'pci sysbackofficetestx16023 (caiso_certificate_authority_issuing)',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = 'CN=PCI SYSBACKOFFICETESTx16023,OU=people,O=CAISO,C=US'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AZPR',        
        'NEWMEXICO',        
        'NMEE',        
        'NMJU',        
        'NMPR',        
        'TSPR'        
    )
);

UPDATE SCUSTOM_FIELD
SET VALUE = 'C:\CAISO\Settlements\SFTP\NMEE_Private_Key.ppk'
WHERE NAME = 'NMEE_CERT';

UPDATE SCUSTOM_FIELD
SET VALUE = 'Nmee_Pci3!'
WHERE NAME = 'NMEE_CERT_PASSWORD';

UPDATE SCUSTOM_FIELD
SET VALUE = 'pcipnmsettlements3'
WHERE NAME = 'NMEE_SFTP_USER';