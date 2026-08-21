# ─────────────────────────────────────────────
#  Client SQL Generator — CAISO
#
#  Reads the market spreadsheet (Certificates / SFTP Certificates / Asset
#  Owners sheets) and generates the per-client asset-owner SQL block that
#  today lives as a hand-maintained file under SQL\CAISO\<Client>.sql.
#
#  Sheet relationship (star schema):
#    Asset Owners.Cert ID      -> Certificates.Cert ID
#    Asset Owners.SFTP Cert ID -> SFTP Certificates.SFTP Cert ID
# ─────────────────────────────────────────────

Import-Module ImportExcel -ErrorAction Stop

function Import-FilledSheet {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$WorksheetName
    )

    $rows = Import-Excel -Path $Path -WorksheetName $WorksheetName

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

# Every asset-owner lookup is disambiguated by market, because the same AO
# NAME can exist under more than one ISO's portfolio mapping in a shared,
# multi-market domain (e.g. DTEET/P66-MT). Applying this join everywhere
# (not just to known multi-market clients) also closes a latent gap in the
# old hand-written multi-owner IN(...) queries, which matched on NAME alone.
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

function New-CaisoClientSql {
    param(
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$Client
    )

    $certs = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'Certificates'
    $sftpCerts = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'SFTP Certificates'
    $assetOwners = Import-FilledSheet -Path $WorkbookPath -WorksheetName 'Asset Owners' |
        Where-Object { $_.Client -eq $Client }

    if (-not $assetOwners) {
        throw "No Asset Owners rows found for client '$Client' in $WorkbookPath"
    }

    $blocks = [System.Collections.Generic.List[string]]::new()

    # ── SASSET_OWNER_CONFIG: one block per distinct Cert ID ──
    $certGroups = $assetOwners | Where-Object { $_.'Cert ID' } | Group-Object 'Cert ID'
    foreach ($group in $certGroups) {
        $certRow = $certs | Where-Object { $_.'Cert ID' -eq $group.Name }
        if (-not $certRow) {
            throw "Cert ID '$($group.Name)' referenced by client '$Client' but not found in Certificates sheet"
        }

        $names = @($group.Group.'Asset Owner')
        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Names $names -Market 'CAISO')"

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    CERTIFICATE = '$($certRow.'Cert Alias')',
    PASSWORD = 'caisoteam',
    CERT_DETAILS = '$($certRow.'Cert Details')',
    ACTIVE = 'Y'
$whereClause;
"@)
    }

    # ── SASSET_OWNER_CONFIG: Active/Settle overrides ──
    # These AOs still get a certificate above (kept as a record even when the
    # cert is known not to work for them, e.g. permission issues) but must not
    # end up live: this block runs after the activation above and wins.
    $overrideGroups = $assetOwners | Group-Object {
        "$($_.'Active')|$($_.'Settle')"
    }
    foreach ($group in $overrideGroups) {
        $parts = $group.Name -split '\|'
        $active = if ($parts[0]) { $parts[0] } else { 'Y' }
        $settle = if ($parts[1]) { $parts[1] } else { 'Y' }

        if ($active -eq 'Y' -and $settle -eq 'Y') {
            continue
        }

        $setParts = [System.Collections.Generic.List[string]]::new()
        if ($active -ne 'Y') { $setParts.Add("ACTIVE = '$active'") }
        if ($settle -ne 'Y') { $setParts.Add("SETTLE = '$settle'") }

        $names = @($group.Group.'Asset Owner')
        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET $($setParts -join ', ')
WHERE $(Get-AssetOwnerKeyClause -Names $names -Market 'CAISO');
"@)
    }

    # ── SCUSTOM_FIELD: three blocks per distinct SFTP Cert ID ──
    $sftpGroups = $assetOwners | Where-Object { $_.'SFTP Cert ID' } | Group-Object 'SFTP Cert ID'
    foreach ($group in $sftpGroups) {
        $sftpRow = $sftpCerts | Where-Object { $_.'SFTP Cert ID' -eq $group.Name }
        if (-not $sftpRow) {
            throw "SFTP Cert ID '$($group.Name)' referenced by client '$Client' but not found in SFTP Certificates sheet"
        }

        $names = @($group.Group.'Asset Owner')
        $keyPath = "C:\CAISO\Settlements\SFTP\$($sftpRow.'Cert Name')"

        $fields = @(
            @{ Suffix = 'CERT'; Value = $keyPath }
            @{ Suffix = 'CERT_PASSWORD'; Value = $sftpRow.'Cert Password' }
            @{ Suffix = 'SFTP_USER'; Value = $sftpRow.'SFTP User' }
        )

        foreach ($field in $fields) {
            if ($names.Count -eq 1) {
                $blocks.Add("UPDATE SCUSTOM_FIELD SET VALUE = '$($field.Value)' WHERE NAME = '$($names[0])_$($field.Suffix)';")
            }
            else {
                $fieldNames = $names | Sort-Object | ForEach-Object { "        '${_}_$($field.Suffix)'" }
                $blocks.Add(@"
UPDATE SCUSTOM_FIELD
SET VALUE = '$($field.Value)'
WHERE NAME IN (
$($fieldNames -join ",`r`n")
);
"@)
            }
        }
    }

    return ($blocks -join "`r`n`r`n")
}
