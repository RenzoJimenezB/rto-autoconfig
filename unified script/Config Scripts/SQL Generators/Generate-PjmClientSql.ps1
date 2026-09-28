# ─────────────────────────────────────────────
#  Client SQL Generator — PJM
#
#  Reads the market spreadsheet (Certificates / Asset Owners sheets) and generates the
#  per-client asset-owner SQL block that today lives as a hand-maintained file under
#  SQL\PJM\<Client>.sql.
#
#  Sheet relationship:
#    Asset Owners.Sandbox Cert ID -> Certificates.Cert ID
#    Asset Owners.Prod Cert ID    -> Certificates.Cert ID
#
#  ACTIVE is derived from Prod/Sandbox Cert ID presence, same as ERCOT/CAISO/MISO -- an AO
#  with neither gets no block at all. SETTLE is not asserted here; see the corrective block
#  at the end.
#
#  Unlike every other market, CERTIFICATE/PASSWORD here hold the Prod *login* credentials
#  (Certificates.'User (Certificate)'/'User Password'), not a cert file -- the actual PKI
#  cert files (Prod and Sandbox) go in USER15-18, and the Sandbox login goes in USER19/20.
#  A client can have a Sandbox identity with no physical cert at all (e.g. PJM\RWE\CEDSOL):
#  Cert Name/Cert Password/Path in nas3 are blank on that Certificates row, but User
#  (Certificate)/User Password are still real and still feed USER19/20 -- so every AO with a
#  Sandbox Cert ID always resolves through the Certificates sheet, never inlined from the AO
#  row itself. An AO with no Sandbox Cert ID at all (e.g. URSF) gets empty strings for
#  USER17-20, matching genericSQL_PJM.sql's expectations exactly. Prod Cert ID is handled the
#  same way: blank means no prod cert row exists yet, and CERTIFICATE/PASSWORD/USER15/USER16
#  come out blank rather than failing the whole client's generation.
#
#  Import-XlsxSheet (XlsxReader.ps1) is loaded by ClientSqlGeneratorDispatcher.ps1 before
#  this file is dot-sourced.
# ─────────────────────────────────────────────

function Import-FilledSheet {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$WorksheetName
    )

    $rows = Import-XlsxSheet -Path $Path -WorksheetName $WorksheetName

    # The "Client" column is only populated on the first row of each group
    # in the spreadsheet (merged-cell style); forward-fill it so every row
    # can be filtered/grouped by client independently.
    $lastClient = $null
    foreach ($row in $rows) {
        if ($row.Client) {
            $lastClient = $row.Client
        }
        else {
            $row.Client = $lastClient
        }
    }

    return $rows
}

# Every asset-owner lookup is disambiguated by market, same reasoning as CAISO/ERCOT/MISO:
# the same AO NAME can exist under more than one ISO's portfolio mapping in a shared,
# multi-market domain.
function Get-AssetOwnerKeyClause {
    param([string]$Name, [string]$Market)

    return @"
ASSET_OWNER_KEY = (
    SELECT so.ASSET_OWNER_KEY
    FROM SASSET_OWNER so
    INNER JOIN SISO_PORTFOLIO_MAPPING spm
        ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
    WHERE so.NAME = '$Name'
    AND spm.NAME = '$Market'
)
"@
}

function New-PjmClientSql {
    param(
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$Client
    )

    $certs = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'Certificates'
    $assetOwners = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'Asset Owners' |
        Where-Object { $_.Client -eq $Client }

    if (-not $assetOwners) {
        throw "No Asset Owners rows found for client '$Client' in $WorkbookPath"
    }

    $blankAoRows = @($assetOwners | Where-Object { -not $_.'Asset Owner' })
    if ($blankAoRows) {
        throw "Client '$Client' has $($blankAoRows.Count) Asset Owners row(s) with no Asset Owner name set"
    }

    function Get-CertRow {
        param([string]$CertId)
        $certRow = $certs | Where-Object { $_.'Cert ID' -eq $CertId }
        if (-not $certRow) {
            throw "Cert ID '$CertId' referenced by client '$Client' but not found in Certificates sheet"
        }
        return $certRow
    }

    $blocks = [System.Collections.Generic.List[string]]::new()

    # AOs with neither a Prod nor a Sandbox cert get no block -- genericSQL_PJM.sql
    # blanket-deactivates first.
    foreach ($ao in ($assetOwners | Where-Object { $_.'Prod Cert ID' -or $_.'Sandbox Cert ID' })) {
        $aoName = $ao.'Asset Owner'
        $prodCert = if ($ao.'Prod Cert ID') { Get-CertRow -CertId $ao.'Prod Cert ID' } else { $null }
        $sandboxCert = if ($ao.'Sandbox Cert ID') { Get-CertRow -CertId $ao.'Sandbox Cert ID' } else { $null }

        $prodCertificate = if ($prodCert) { $prodCert.'User (Certificate)' } else { '' }
        $prodPassword = if ($prodCert) { $prodCert.'User Password' } else { '' }
        $pkiPathProd = "C:\PCI\certificates\pki\$(if ($prodCert) { $prodCert.'Cert Name' })"
        $pkiPasswordProd = if ($prodCert) { $prodCert.'Cert Password' } else { '' }

        $pkiPathSandbox = "C:\PCI\certificates\pki\$(if ($sandboxCert) { $sandboxCert.'Cert Name' })"
        $pkiPasswordSandbox = if ($sandboxCert) { $sandboxCert.'Cert Password' } else { '' }
        $sandboxUsername = if ($sandboxCert) { $sandboxCert.'User (Certificate)' } else { '' }
        $sandboxPassword = if ($sandboxCert) { $sandboxCert.'User Password' } else { '' }

        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Name $aoName -Market 'PJM')"

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    CERTIFICATE = '$prodCertificate',
    PASSWORD = '$prodPassword',
-- PKI_CERTIFICATE_PATH
    USER15 = '$pkiPathProd',
-- PKI_CERTIFICATE_PASSWORD
    USER16 = '$pkiPasswordProd',
-- PKI_CERTIFICATE_PATH_SANDBOX
    USER17 = '$pkiPathSandbox',
-- PKI_CERTIFICATE_PASSWORD_SANDBOX
    USER18 = '$pkiPasswordSandbox',
-- SANDBOX_USERNAME
    USER19 = '$sandboxUsername',
-- SANDBOX_PASSWORD
    USER20 = '$sandboxPassword'
$whereClause;
"@)
    }

    # Corrects stale SETTLE = 'Y' on AOs left deactivated. Reads live DB state, runs
    # after activation -- not part of genericSQL_PJM.sql.
    $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET SETTLE = 'N'
WHERE ACTIVE = 'N' AND SETTLE = 'Y'
AND ASSET_OWNER_KEY IN (
    SELECT so.ASSET_OWNER_KEY
    FROM SASSET_OWNER so
    INNER JOIN SISO_PORTFOLIO_MAPPING spm
        ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
    WHERE spm.NAME = 'PJM'
);
"@)

    return ($blocks -join "`r`n`r`n")
}
