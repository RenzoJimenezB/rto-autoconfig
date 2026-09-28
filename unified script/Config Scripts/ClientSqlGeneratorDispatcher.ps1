# ─────────────────────────────────────────────
#  Client SQL Generator Dispatch
#
#  Loaded ONLY by Start-CloudDomainConfig.ps1 (the local launcher) -- generates the final
#  client SQL text from a market's spreadsheet BEFORE staging/transfer, so the target VM
#  never needs the raw spreadsheet at all; only the resulting .sql text is shipped to the
#  VM, through the same fast path used for every other staged file. Configure_Domain.ps1
#  (VM-side) stays generator-agnostic -- it just reads that .sql file via cloudConfigLib.ps1's
#  clientSQL(), exactly like it always has.
# ─────────────────────────────────────────────

# Spreadsheet reading: XlsxReader.ps1's Import-XlsxSheet (built-in .NET only, no ImportExcel
# module). Swapped in after ImportExcel's ~200-file module load measured ~85s over NAS3 --
# our need is narrow (plain data cells only), so a small purpose-built reader eliminates
# that cost entirely along with the third-party dependency.
. (Join-Path $PSScriptRoot "XlsxReader.ps1")

# Spreadsheet-driven client SQL generators live one per market under SQL Generators\
# (Generate-<Market>ClientSql.ps1); load every one so New-ClientSqlText below can dispatch
# to them. Every market is generator-driven -- markets without a real implementation yet
# use a throwing placeholder until their file is filled in. New markets just need a new
# file dropped in SQL Generators\; nothing here needs to change to pick it up.
$script:GeneratorsDir = Join-Path $PSScriptRoot "SQL Generators"
Get-ChildItem -Path $script:GeneratorsDir -Filter "Generate-*ClientSql.ps1" | ForEach-Object {
    . $_.FullName
}

$script:ClientSqlGenerators = @{
    'CAISO' = { param($WorkbookPath, $Client, $Environment) New-CaisoClientSql -WorkbookPath $WorkbookPath -Client $Client }
    'ERCOT' = { param($WorkbookPath, $Client, $Environment) New-ErcotClientSql -WorkbookPath $WorkbookPath -Client $Client -Environment $Environment }
    'ISONE' = { param($WorkbookPath, $Client, $Environment) New-IsoneClientSql -WorkbookPath $WorkbookPath -Client $Client }
    'MISO'  = { param($WorkbookPath, $Client, $Environment) New-MisoClientSql -WorkbookPath $WorkbookPath -Client $Client }
    'NYISO' = { param($WorkbookPath, $Client, $Environment) New-NyisoClientSql -WorkbookPath $WorkbookPath -Client $Client }
    'PJM'   = { param($WorkbookPath, $Client, $Environment) New-PjmClientSql -WorkbookPath $WorkbookPath -Client $Client }
    'SPPIM' = { param($WorkbookPath, $Client, $Environment) New-SppimClientSql -WorkbookPath $WorkbookPath -Client $Client }
}

# Returns the raw generated SQL body (no BEGIN/COMMIT/END wrapper) -- callers write this
# straight to a .sql file in the same format as the historical hand-maintained files.
function New-ClientSqlText {
    param(
        [Parameter(Mandatory = $true)][string]$Market,
        [Parameter(Mandatory = $true)][string]$Client,
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        # Only ERCOT's generator uses this today (SQL is generated per MOTE/PROD
        # environment); every other market's scriptblock ignores it.
        [string]$Environment
    )

    if (-not $script:ClientSqlGenerators.ContainsKey($Market)) {
        throw "No client SQL generator registered for market '$Market'"
    }
    if (-not (Test-Path $WorkbookPath)) {
        throw "Market spreadsheet not found: $WorkbookPath"
    }

    return & $script:ClientSqlGenerators[$Market] $WorkbookPath $Client $Environment
}
