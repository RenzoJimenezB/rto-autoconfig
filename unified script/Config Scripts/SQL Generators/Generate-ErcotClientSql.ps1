# ─────────────────────────────────────────────
#  Client SQL Generator — ERCOT
#
#  Reads the market spreadsheet (Certificates / Asset Owners sheets) and generates the
#  per-client, per-environment asset-owner SQL block that today lives as a hand-maintained
#  file under SQL\ERCOT\<Environment>\<Client>.sql.
#
#  Unlike every other market, ERCOT SQL is generated per environment (MOTE or PROD), not
#  once per client -- the launcher prompts for environment and threads it through here.
#
#  Sheet relationship:
#    Asset Owners.<Environment> Cert ID -> Certificates.Cert ID
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

# Every asset-owner lookup is disambiguated by market, because the same AO NAME can exist
# under more than one ISO's portfolio mapping in a shared, multi-market domain -- ERCOT's
# P66-MT is already known to also operate under MISO (SQL\MISO\P66-MT.sql). Applied to every
# market's generator (CAISO, MISO, ERCOT, and future ones) for the same reason.
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

function New-ErcotClientSql {
    param(
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$Client,
        [Parameter(Mandatory = $true)][ValidateSet('MOTE', 'PROD')][string]$Environment
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

    $certIdColumn = "$Environment Cert ID"
    # Matches the wsdd files under Client-Certificates\ERCOT\<Client>\wsdd\<Environment>\ --
    # deploy_<ao-lowercase>.wsdd -- staged onto the VM under these fixed paths.
    $vmWsddBase = if ($Environment -eq 'MOTE') { 'C:\ERCOT\FO\Certificates\MOTE' } else { 'C:\ERCOT\BO\Certificates\PROD' }

    $blocks = [System.Collections.Generic.List[string]]::new()

    # No-cert-for-this-environment AOs get no block -- genericSQL_ERCOT.sql already
    # deactivates every AO (ACTIVE = 'N', no WHERE). SETTLE is not asserted here.
    foreach ($ao in ($assetOwners | Where-Object { $_.$certIdColumn })) {
        $certId = $ao.$certIdColumn
        $certRow = $certs | Where-Object { $_.'Cert ID' -eq $certId }
        if (-not $certRow) {
            throw "Cert ID '$certId' referenced by client '$Client' AO '$($ao.'Asset Owner')' but not found in Certificates sheet"
        }

        $aoName = $ao.'Asset Owner'
        $wsddPath = "$vmWsddBase\deploy_$($aoName.ToLower()).wsdd"
        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Name $aoName -Market 'ERCOT')"

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    CERTIFICATE = '$($certRow.'Cert Alias')',
    PASSWORD = 'changeit',
    CERT_DETAILS = '$wsddPath'
$whereClause;
"@)
    }

    # Corrects stale SETTLE = 'Y' on AOs left deactivated. Reads live DB state, runs
    # after activation -- not part of genericSQL_ERCOT.sql.
    $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET SETTLE = 'N'
WHERE ACTIVE = 'N' AND SETTLE = 'Y'
AND ASSET_OWNER_KEY IN (
    SELECT so.ASSET_OWNER_KEY
    FROM SASSET_OWNER so
    INNER JOIN SISO_PORTFOLIO_MAPPING spm
        ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
    WHERE spm.NAME = 'ERCOT'
);
"@)

    return ($blocks -join "`r`n`r`n")
}
