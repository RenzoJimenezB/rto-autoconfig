UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\PCI AMUE View-1.pfx',
    PASSWORD = 'pciAMUEView24',
    CERT_DETAILS = 'C:\MISO\certs\PCI AMUE View-1.pfx'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AET',
        'AEXP',
        'AMDV',
        'AMUE',
        'GIBSON CITY',
        'GRAND TOWER',
        'HUTSONVILLE',
        'MEREDOSIA',
        'UEBT',
        'UECC',
        'UEGEN',
        'UEHF',
        'UEHP',
        'UELSE'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = 'C:\MISO\certs\PCI AMCP View.pfx',
    PASSWORD = 'pciAMCP20',
    CERT_DETAILS = 'C:\MISO\certs\PCI AMCP View.pfx'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'AMCP',
        'AMCP1',
        'AMCP2',
        'AMCP3',
        'AMCP_DR_CI',
        'AMCP_DR_TSTAT',
        'AMCP_GEN_SOLAR'
    )
);

UPDATE SASSET_OWNER_CONFIG
SET 
    ACTIVE = 'N',
    SETTLE = 'N'
WHERE ASSET_OWNER_KEY IN (
    SELECT ASSET_OWNER_KEY FROM SASSET_OWNER
    WHERE NAME IN (
        'UEBT',
        'UECC',
        'UEHF',
        'UEHP'
    )
);