# ─────────────────────────────────────────────
#  Client SQL Generator — NYISO
#
#  Reads the market spreadsheet (Certificates / Asset Owners sheets) and generates the
#  per-client asset-owner SQL block that today lives as a hand-maintained file under
#  SQL\NYISO\<Client>.sql.
#
#  Sheet relationship:
#    Asset Owners.Cert ID -> Certificates.Cert ID
#
#  Every cert carries its own MIS and DSS login (MIS_USER/MIS_PASSWORD, DSS_USER/
#  DSS_PASSWORD), unlike ISONE where the SFTP login is per-AO -- here everything lives on
#  the Certificates row, so this generator groups by Cert ID exactly like CAISO/MISO do.
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

# Every asset-owner lookup is disambiguated by market, same reasoning as CAISO/ERCOT/MISO/PJM/SPPIM/ISONE.
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

function New-NyisoClientSql {
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

    $blocks = [System.Collections.Generic.List[string]]::new()

    $certGroups = $assetOwners | Group-Object 'Cert ID'
    foreach ($group in $certGroups) {
        $certRow = $certs | Where-Object { $_.'Cert ID' -eq $group.Name }
        if (-not $certRow) {
            throw "Cert ID '$($group.Name)' referenced by client '$Client' but not found in Certificates sheet"
        }

        $names = @($group.Group.'Asset Owner')
        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Names $names -Market 'NYISO')"

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    CERTIFICATE = 'C:\NYISO\Certificates\$($certRow.'Cert Name')',
    PASSWORD = '$($certRow.'Cert Password')',
-- MIS_USER
    USER1 = '$($certRow.'MIS User')',
-- MIS_PASSWORD
    USER2 = '$($certRow.'MIS Password')',
-- DSS_USER
    USER3 = '$($certRow.'DSS User')',
-- DSS_PASSWORD
    USER4 = '$($certRow.'DSS Password')'
$whereClause;
"@)
    }

    return ($blocks -join "`r`n`r`n")
}
