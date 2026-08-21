# ─────────────────────────────────────────────
#  Minimal .xlsx Sheet Reader
#
#  Reads plain cell values out of a single worksheet using only built-in .NET
#  (System.IO.Compression + System.Xml) -- no third-party module required.
#
#  Loaded by ClientSqlGeneratorDispatcher.ps1 so every SQL Generators\ worker can call
#  Import-XlsxSheet the same way they'd call Import-Excel. Chosen over ImportExcel because
#  our need is narrow (plain data cells, no formulas/charts/formatting) and ImportExcel's
#  ~200-file module load took ~85s over NAS3, dwarfing everything else in the generation
#  step; this reader's load + full 27-client CAISO generation together run in ~5s.
#
#  Known limitation: date cells are returned as their raw Excel serial number, not a
#  [datetime] -- no generator currently reads a date column. Add numFmt-aware conversion
#  (via xl/styles.xml) if one ever needs to.
# ─────────────────────────────────────────────

function Get-XlsxColumnLetter([string]$CellRef) {
    ($CellRef -replace '\d+$', '')
}

function Get-XlsxColumnIndex([string]$ColumnLetter) {
    $index = 0
    foreach ($c in $ColumnLetter.ToCharArray()) {
        $index = $index * 26 + ([int][char]$c - [int][char]'A' + 1)
    }
    return $index
}

# Returns an array of PSCustomObjects, one per data row, with properties named after the
# header row (row 1) -- the same shape Import-Excel returns.
function Import-XlsxSheet {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$WorksheetName
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $nsMain = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
        $nsRel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
        $nsPkgRel = 'http://schemas.openxmlformats.org/package/2006/relationships'

        function Read-ZipEntryXml([string]$EntryName) {
            $entry = $zip.GetEntry($EntryName)
            if (-not $entry) { return $null }
            $stream = $entry.Open()
            try {
                $reader = New-Object System.IO.StreamReader($stream)
                $text = $reader.ReadToEnd()
                $xml = New-Object System.Xml.XmlDocument
                $xml.LoadXml($text)
                return $xml
            }
            finally { $stream.Dispose() }
        }

        # --- workbook.xml: map sheet name -> r:id ---
        $wbXml = Read-ZipEntryXml 'xl/workbook.xml'
        $wbNsMgr = New-Object System.Xml.XmlNamespaceManager($wbXml.NameTable)
        $wbNsMgr.AddNamespace('s', $nsMain)
        $wbNsMgr.AddNamespace('r', $nsRel)
        $sheetNode = $wbXml.SelectSingleNode("//s:sheets/s:sheet[@name='$WorksheetName']", $wbNsMgr)
        if (-not $sheetNode) { throw "Worksheet '$WorksheetName' not found in $Path" }
        $rId = $sheetNode.GetAttribute('id', $nsRel)

        # --- workbook.xml.rels: map r:id -> target sheetN.xml ---
        $relsXml = Read-ZipEntryXml 'xl/_rels/workbook.xml.rels'
        $relsNsMgr = New-Object System.Xml.XmlNamespaceManager($relsXml.NameTable)
        $relsNsMgr.AddNamespace('pr', $nsPkgRel)
        $relNode = $relsXml.SelectSingleNode("//pr:Relationship[@Id='$rId']", $relsNsMgr)
        $sheetPath = "xl/$($relNode.GetAttribute('Target'))"

        # --- sharedStrings.xml (optional -- absent when Excel writes inline strings instead) ---
        $sharedStrings = @()
        $ssXml = Read-ZipEntryXml 'xl/sharedStrings.xml'
        if ($ssXml) {
            $ssNsMgr = New-Object System.Xml.XmlNamespaceManager($ssXml.NameTable)
            $ssNsMgr.AddNamespace('s', $nsMain)
            foreach ($si in $ssXml.SelectNodes('//s:sst/s:si', $ssNsMgr)) {
                $tNodes = $si.SelectNodes('.//s:t', $ssNsMgr)
                $sharedStrings += (@($tNodes) | ForEach-Object { $_.InnerText }) -join ''
            }
        }

        # --- the actual sheet ---
        $sheetXml = Read-ZipEntryXml $sheetPath
        $sheetNsMgr = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
        $sheetNsMgr.AddNamespace('s', $nsMain)

        function Get-XlsxCellValue($cellNode) {
            if (-not $cellNode) { return $null }
            $type = $cellNode.GetAttribute('t')
            $vNode = $cellNode.SelectSingleNode('s:v', $sheetNsMgr)
            $isNode = $cellNode.SelectSingleNode('s:is', $sheetNsMgr)

            if ($type -eq 's') {
                if (-not $vNode) { return $null }
                return $sharedStrings[[int]$vNode.InnerText]
            }
            elseif ($type -eq 'inlineStr') {
                if (-not $isNode) { return $null }
                $tNodes = $isNode.SelectNodes('.//s:t', $sheetNsMgr)
                return (@($tNodes) | ForEach-Object { $_.InnerText }) -join ''
            }
            else {
                if (-not $vNode) { return $null }
                return $vNode.InnerText
            }
        }

        $rowNodes = $sheetXml.SelectNodes('//s:sheetData/s:row', $sheetNsMgr)
        if ($rowNodes.Count -eq 0) { return @() }

        # Header row (row 1) -> column index -> header name
        $headerRow = $rowNodes[0]
        $headers = @{}
        foreach ($c in $headerRow.SelectNodes('s:c', $sheetNsMgr)) {
            $colIdx = Get-XlsxColumnIndex (Get-XlsxColumnLetter $c.GetAttribute('r'))
            $val = Get-XlsxCellValue $c
            if ($val) { $headers[$colIdx] = $val }
        }
        $orderedColIdx = $headers.Keys | Sort-Object

        $results = [System.Collections.Generic.List[object]]::new()
        for ($i = 1; $i -lt $rowNodes.Count; $i++) {
            $row = $rowNodes[$i]
            $rowData = [ordered]@{}
            foreach ($colIdx in $orderedColIdx) { $rowData[$headers[$colIdx]] = $null }

            $hasValue = $false
            foreach ($c in $row.SelectNodes('s:c', $sheetNsMgr)) {
                $colIdx = Get-XlsxColumnIndex (Get-XlsxColumnLetter $c.GetAttribute('r'))
                if ($headers.ContainsKey($colIdx)) {
                    $val = Get-XlsxCellValue $c
                    $rowData[$headers[$colIdx]] = $val
                    if ($null -ne $val -and $val -ne '') { $hasValue = $true }
                }
            }

            # Skip fully blank rows (including self-closing <row/> tags with no cells at
            # all) -- these are leftover structural artifacts, not real data.
            if ($hasValue) {
                $results.Add([PSCustomObject]$rowData)
            }
        }

        return $results.ToArray()
    }
    finally {
        $zip.Dispose()
    }
}
