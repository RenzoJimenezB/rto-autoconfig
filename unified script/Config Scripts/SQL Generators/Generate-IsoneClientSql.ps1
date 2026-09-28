# ─────────────────────────────────────────────
#  Client SQL Generator — ISONE
#
#  Reads the market spreadsheet (Certificates / Asset Owners sheets) and generates the
#  per-client asset-owner SQL block that today lives as a hand-maintained file under
#  SQL\ISONE\<Client>.sql.
#
#  Sheet relationship:
#    Asset Owners.Cert ID -> Certificates.Cert ID
#
#  SFTP_USER/SFTP_PASSWORD live on the Asset Owners row, not the Certificates row: RWE's
#  Cassadaga and RWECE AOs share the exact same cert, but each has its own distinct SFTP
#  login -- so unlike every other market, the same Cert ID can carry different USER1/USER2
#  values per AO. Grouping is still attempted (by Cert ID + SFTP User + SFTP Password
#  together), so AOs that DO share identical everything still collapse into one IN(...)
#  block; USER1/USER2 are only emitted at all when the AO has an SFTP login (IGS's AO has
#  none, matching genericSQL_ISONE.sql's default with no SFTP lines).
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

# Every asset-owner lookup is disambiguated by market, same reasoning as CAISO/ERCOT/MISO/PJM/SPPIM.
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

function New-IsoneClientSql {
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

    $groups = $assetOwners | Group-Object { "$($_.'Cert ID')|$($_.'SFTP User')|$($_.'SFTP Password')" }
    foreach ($group in $groups) {
        $sample = $group.Group[0]
        $certRow = Get-CertRow -CertId $sample.'Cert ID'
        $names = @($group.Group.'Asset Owner')
        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Names $names -Market 'ISONE')"

        $sftpLines = ''
        if ($sample.'SFTP User') {
            $sftpLines = @"
,
-- SFTP_USER
    USER1 = '$($sample.'SFTP User')',
-- SFTP_PASSWORD
    USER2 = '$($sample.'SFTP Password')'
"@
        }

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    CERTIFICATE = 'C:\ISONE\Certificates\$($certRow.'Cert Name')',
    PASSWORD = '$($certRow.'Cert Password')'$sftpLines
$whereClause;
"@)
    }

    return ($blocks -join "`r`n`r`n")
}
