# ─────────────────────────────────────────────
#  Client SQL Generator — SPPIM
#
#  Reads the market spreadsheet (Certificates / Env Details / Asset Owners sheets) and
#  generates the per-client asset-owner SQL block that today lives as a hand-maintained file
#  under SQL\SPPIM\<Client>.sql.
#
#  Sheet relationship:
#    Asset Owners.Prod Cert ID -> Certificates.Cert ID, Env Details.Prod Cert ID
#    Asset Owners.MTE Cert ID  -> Certificates.Cert ID
#
#  Every AO carries a Prod cert AND an MTE cert -- usually the same physical file (Prod Cert
#  ID == MTE Cert ID), but not always: e.g. BEPC's AOs use BEPC-01 for Prod and a distinct
#  BEPC-02 for MTE. Env Details is keyed by Prod Cert ID and holds BOTH environments' screen
#  name/API key in that one row (the MTE screen name/API key there is *not* looked up by MTE
#  Cert ID -- it's just the other half of that same Env Details row).
#
#  Certificates.CROW ('Y'/blank) marks whichever cert is the current SPPIM CROW Market
#  Participant -- not AO-linked at all (unlike MISO's CROW, which flags an *Asset Owner* row
#  and reuses that AO's own cert). SPPIM's SLOV_VALUE update has no DISPLAY filter in the
#  hand-maintained SQL -- it's one global row, so whichever client's SQL last ran "wins" the
#  designation. Usually the flagged cert is just that client's own main Prod cert (BEPC/OGE/
#  XCEL), but it can be a dedicated cert no AO ever references at all (CSU's CSU-02, a
#  separate file from its main CSU-01 Prod cert). At most one CROW-flagged row is expected per
#  client; if a client has none (EVERGY/AECC/GRDA-MKT today), no SLOV_VALUE block is emitted.
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

function Format-NameList {
    param([string[]]$Names, [string]$Prefix = '')
    return ($Names | Sort-Object | ForEach-Object { "        $Prefix'$_'" }) -join ",`r`n"
}

# Every asset-owner lookup is disambiguated by market, same reasoning as CAISO/ERCOT/MISO/PJM.
function Get-AssetOwnerKeyClause {
    param([string[]]$Names, [string]$Market)
    $Names = @($Names)

    $nameFilter = if ($Names.Count -eq 1) {
        "so.NAME = '$($Names[0])'"
    }
    else {
        "so.NAME IN (`r`n$(Format-NameList $Names)`r`n        )"
    }

    $subquery = @"
SELECT so.ASSET_OWNER_KEY
    FROM SASSET_OWNER so
    INNER JOIN SISO_PORTFOLIO_MAPPING spm
        ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
    WHERE $nameFilter
    AND spm.NAME = '$Market'
"@

    if ($Names.Count -eq 1) {
        return "ASSET_OWNER_KEY = (`r`n    $subquery`r`n)"
    }
    return "ASSET_OWNER_KEY IN (`r`n    $subquery`r`n)"
}

function New-SppimClientSql {
    param(
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$Client
    )

    $certs = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'Certificates'
    $envDetails = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'Env Details'
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

    function Get-CertPath {
        param($CertRow)
        return "C:\PCI\certificates\$($CertRow.'Cert Name')"
    }

    $blocks = [System.Collections.Generic.List[string]]::new()

    # One block per distinct (Prod Cert ID, MTE Cert ID) pair -- an AO's Prod and MTE
    # certs aren't always the same file (e.g. BEPC: BEPC-01 Prod, BEPC-02 MTE), so
    # grouping by Prod Cert ID alone isn't safe. SETTLE is not asserted here.
    $certGroups = $assetOwners | Group-Object { "$($_.'Prod Cert ID')|$($_.'MTE Cert ID')" }
    foreach ($group in $certGroups) {
        $prodCertId, $mteCertId = $group.Name -split '\|'
        $prodCert = Get-CertRow -CertId $prodCertId
        $mteCert = Get-CertRow -CertId $mteCertId

        $envRow = $envDetails | Where-Object { $_.'Prod Cert ID' -eq $prodCertId }
        if (-not $envRow) {
            throw "Prod Cert ID '$prodCertId' referenced by client '$Client' but not found in Env Details sheet"
        }

        $names = @($group.Group.'Asset Owner')
        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Names $names -Market 'SPPIM')"

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    CERTIFICATE = '$(Get-CertPath $prodCert)',
    PASSWORD = '$($prodCert.'Cert Password')',
-- Prod Screen Name
    USER1 = '$($envRow.'Prod Screen Name')',
-- Prod API Key
    USER2 = '$($envRow.'Prod API Key')',
-- MTE Screen Name
    USER3 = '$($envRow.'MTE Screen Name')',
-- MTE API Key
    USER4 = '$($envRow.'MTE API Key')',
-- MTE Certificate
    USER5 = '$(Get-CertPath $mteCert)',
-- MTE Password
    USER6 = '$($mteCert.'Cert Password')'
$whereClause;
"@)
    }

    # CROW block -- not tied to any AO, so it's keyed off the client's own Certificates rows,
    # not the Asset Owners sheet at all.
    $crowCert = $certs | Where-Object { $_.Client -eq $Client -and $_.CROW -eq 'Y' }
    if ($crowCert) {
        $blocks.Add(@"
UPDATE SLOV_VALUE
SET
    PROPERTY1 = '$(Get-CertPath $crowCert)',
    PROPERTY2 = '$($crowCert.'Cert Password')'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'SPPIM CROW Market Participant Info');
"@)
    }

    # Corrects stale SETTLE = 'Y' on AOs left deactivated. Reads live DB state, runs
    # after activation -- not part of genericSQL_SPPIM.sql.
    $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET SETTLE = 'N'
WHERE ACTIVE = 'N' AND SETTLE = 'Y'
AND ASSET_OWNER_KEY IN (
    SELECT so.ASSET_OWNER_KEY
    FROM SASSET_OWNER so
    INNER JOIN SISO_PORTFOLIO_MAPPING spm
        ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
    WHERE spm.NAME = 'SPPIM'
);
"@)

    return ($blocks -join "`r`n`r`n")
}
