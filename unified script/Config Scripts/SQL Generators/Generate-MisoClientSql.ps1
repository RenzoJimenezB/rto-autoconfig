# ─────────────────────────────────────────────
#  Client SQL Generator — MISO
#
#  Reads the market spreadsheet (Certificates / Asset Owners sheets) and generates the
#  per-client asset-owner SQL block that today lives as a hand-maintained file under
#  SQL\MISO\<Client>.sql.
#
#  Sheet relationship:
#    Asset Owners.Cert ID -> Certificates.Cert ID
#
#  ACTIVE is derived from Cert ID presence, same as ERCOT/CAISO/SPPIM -- an AO with no
#  Cert ID gets no activation block at all. CROW and Prod Access remain explicit per-row
#  flags. SETTLE is not asserted here; see the corrective block at the end.
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

# Every asset-owner lookup is disambiguated by market, because the same AO NAME can exist
# under more than one ISO's portfolio mapping in a shared, multi-market domain (e.g. MISO's
# P66-MT is also an ERCOT client). Applied to every market's generator for this reason.
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

# Blank/anything-but-'Y' collapses to 'N' -- the explicit override convention agreed for
# CROW and Prod Access.
function Get-YesNo {
    param($Value)
    if ($Value -eq 'Y') { return 'Y' }
    return 'N'
}

function New-MisoClientSql {
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

    function Get-CertPath {
        param($CertRow)
        return "C:\MISO\certs\$($CertRow.'Cert Name')"
    }

    $blocks = [System.Collections.Generic.List[string]]::new()

    # ── Kind A: SASSET_OWNER_CONFIG cert fields + ACTIVE, one block per distinct Cert ID.
    # AOs with no Cert ID get no block -- genericSQL_MISO.sql blanket-deactivates first.
    $certGroups = $assetOwners | Where-Object { $_.'Cert ID' } | Group-Object 'Cert ID'
    foreach ($group in $certGroups) {
        $certRow = Get-CertRow -CertId $group.Name
        $certPath = Get-CertPath -CertRow $certRow
        $names = @($group.Group.'Asset Owner')
        $whereClause = "WHERE $(Get-AssetOwnerKeyClause -Names $names -Market 'MISO')"

        $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET
    ACTIVE = 'Y',
    CERTIFICATE = '$certPath',
    PASSWORD = '$($certRow.'Cert Password')',
    CERT_DETAILS = '$certPath'
$whereClause;
"@)
    }

    # ── Kind C: SLOV_VALUE, one block per AO with CROW = 'Y', reusing that AO's own Cert ID
    # for the path/password (the CROW cert IS the AO's cert). DISPLAY only gets added when a
    # client has MORE THAN ONE CROW AO (e.g. RWE's PTWF/STWF) -- that's the only case where a
    # DISPLAY filter is needed to tell them apart. A client with a single CROW AO (e.g.
    # ALLIANT's ALTM, DTE) gets a bare global update instead, matching production exactly:
    # adding an unconditional "AND DISPLAY = '<name>'" there would silently match zero rows if
    # that SLOV_VALUE row's DISPLAY isn't literally that AO's name, and the CROW cert would
    # never actually get set.
    $crowAos = @($assetOwners | Where-Object { (Get-YesNo $_.CROW) -eq 'Y' })
    $needsDisplay = $crowAos.Count -gt 1
    foreach ($ao in $crowAos) {
        $certRow = Get-CertRow -CertId $ao.'Cert ID'
        $certPath = Get-CertPath -CertRow $certRow
        $displayClause = if ($needsDisplay) { "`r`nAND DISPLAY = '$($ao.'Asset Owner')'" } else { '' }

        $blocks.Add(@"
UPDATE SLOV_VALUE
SET
    PROPERTY1 = '$certPath',
    PROPERTY2 = '$($certRow.'Cert Password')'
WHERE LOV_KEY = (SELECT LOV_KEY FROM SLOV WHERE NAME = 'MISO CROW Market Participant Info')$displayClause;
"@)
    }

    # ── Kind D: SPARAMETER override for MISO_DART2_HOST_TARGET_DOWNLOADS -- genericSQL_MISO
    # defaults downloads to Prod ('P'); if any ACTIVE AO's cert lacks Prod Access, downloads
    # can't come from Prod for this domain, so point them at Test/CCE ('T') instead.
    $activeCertIds = @($assetOwners | Where-Object { $_.'Cert ID' } |
        ForEach-Object { $_.'Cert ID' } | Sort-Object -Unique)
    $lacksProdAccess = $false
    foreach ($certId in $activeCertIds) {
        $certRow = Get-CertRow -CertId $certId
        if ((Get-YesNo $certRow.'Prod Access') -ne 'Y') { $lacksProdAccess = $true }
    }
    if ($lacksProdAccess) {
        $blocks.Add("UPDATE SPARAMETER SET VALUE = 'T' WHERE SYSTEM = 'ISOCOMM' and TYPE = '_MISO_' and NAME = 'MISO_DART2_HOST_TARGET_DOWNLOADS';")
    }

    # Corrects stale SETTLE = 'Y' on AOs left deactivated. Reads live DB state, runs
    # after activation -- not part of genericSQL_MISO.sql.
    $blocks.Add(@"
UPDATE SASSET_OWNER_CONFIG
SET SETTLE = 'N'
WHERE ACTIVE = 'N' AND SETTLE = 'Y'
AND ASSET_OWNER_KEY IN (
    SELECT so.ASSET_OWNER_KEY
    FROM SASSET_OWNER so
    INNER JOIN SISO_PORTFOLIO_MAPPING spm
        ON so.ISO_PORTFOLIO_MAPPING_KEY = spm.ISO_PORTFOLIO_MAPPING_KEY
    WHERE spm.NAME = 'MISO'
);
"@)

    return ($blocks -join "`r`n`r`n")
}
