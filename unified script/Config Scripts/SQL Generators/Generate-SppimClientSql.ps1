# ─────────────────────────────────────────────
#  Client SQL Generator — SPPIM (not yet implemented)
#
#  Placeholder registered in cloudConfigLib.ps1's $script:ClientSqlGenerators so
#  every market is generator-driven; fill in the real spreadsheet-reading logic
#  the same way Generate-ClientSql.ps1 (New-CaisoClientSql) does for CAISO.
# ─────────────────────────────────────────────

function New-SppimClientSql {
    param(
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$Client
    )
    throw "SPPIM client SQL generator not implemented yet"
}
