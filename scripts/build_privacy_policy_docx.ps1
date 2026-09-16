# Builds docs\PRIVACY_POLICY.docx WITHOUT requiring Microsoft Word.
#
# A .docx file is a ZIP archive containing OOXML (Office Open XML) files.
# We generate the minimum-viable structure: [Content_Types].xml, _rels/.rels,
# word/document.xml, word/styles.xml, and word/_rels/document.xml.rels.
#
# The text comes from docs\PRIVACY_POLICY.md: edit that file, then re-run this
# script (and scripts/build_privacy_policy_html.mjs). Word, LibreOffice and
# Google Docs will all open the result.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\build_privacy_policy_docx.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$outPath  = Join-Path $repoRoot 'docs\PRIVACY_POLICY.docx'
$tmpRoot  = Join-Path ([System.IO.Path]::GetTempPath()) ("policy_docx_" + [System.Guid]::NewGuid().ToString('N'))

# --- Content model -----------------------------------------------------------
# Read from docs\PRIVACY_POLICY.md (the single source of the policy text) by
# scripts\privacy_policy_sections.mjs, which needs Node.js. Each entry is one of:
#   @{ kind='h1'|'h2'|'h3'|'p'; text='...' }   # bold via **...**, italic via _..._
#   @{ kind='bullet'; items=@('...', '...') }
#   @{ kind='table'; header=@('A','B','C'); rows=@(@('x','y','z'), ...) }
#   @{ kind='hr' }

New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
$sectionsJson = Join-Path $tmpRoot 'sections.json'
& node (Join-Path $PSScriptRoot 'privacy_policy_sections.mjs') $sectionsJson
if ($LASTEXITCODE -ne 0) { throw 'privacy_policy_sections.mjs failed' }
$sections = Get-Content -Raw -Encoding UTF8 -LiteralPath $sectionsJson | ConvertFrom-Json

# --- OOXML builders ----------------------------------------------------------

function Escape-Xml([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

# Convert a paragraph string into a list of OOXML runs (<w:r>) honoring
# **bold** and _italic_ markers.
function Get-RunsXml([string]$line) {
    $out = New-Object System.Text.StringBuilder
    $buf = ''
    $bold = $false
    $italic = $false
    $emit = {
        param($t, $b, $i)
        if ([string]::IsNullOrEmpty($t)) { return }
        $props = ''
        if ($b -or $i) {
            $props = '<w:rPr>'
            if ($b) { $props += '<w:b/>' }
            if ($i) { $props += '<w:i/>' }
            $props += '</w:rPr>'
        }
        $escaped = (Escape-Xml $t).Replace([string][char]0xE000, '_')
        $null = $out.Append("<w:r>${props}<w:t xml:space=`"preserve`">${escaped}</w:t></w:r>")
    }
    $i = 0
    while ($i -lt $line.Length) {
        if ($i + 1 -lt $line.Length -and $line.Substring($i, 2) -eq '**') {
            & $emit $buf $bold $italic
            $buf = ''
            $bold = -not $bold
            $i += 2
            continue
        }
        $ch = $line[$i]
        if ($ch -eq '_') {
            & $emit $buf $bold $italic
            $buf = ''
            $italic = -not $italic
            $i += 1
            continue
        }
        $buf += $ch
        $i += 1
    }
    & $emit $buf $bold $italic
    return $out.ToString()
}

function New-Paragraph([string]$style, [string]$text) {
    $pPr = ''
    if ($style) { $pPr = "<w:pPr><w:pStyle w:val=`"$style`"/></w:pPr>" }
    $runs = Get-RunsXml $text
    return "<w:p>${pPr}${runs}</w:p>"
}

function New-Heading([int]$level, [string]$text) {
    $style = "Heading$level"
    return New-Paragraph $style $text
}

function New-Bullet([string]$text) {
    $runs = Get-RunsXml $text
    return "<w:p><w:pPr><w:pStyle w:val=`"ListParagraph`"/><w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"1`"/></w:numPr></w:pPr>${runs}</w:p>"
}

function New-HorizontalRule() {
    return '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="999999"/></w:pBdr></w:pPr></w:p>'
}

function New-Table($header, $rows) {
    $colCount = $header.Count
    # Equal column widths within a ~16cm content area: 9000 twentieths of a point per col fits 3 cols.
    $colWidth = [int](9000 / $colCount)
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append('<w:tbl>')
    $null = $sb.Append('<w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/><w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/><w:insideH w:val="single" w:sz="4" w:color="999999"/><w:insideV w:val="single" w:sz="4" w:color="999999"/></w:tblBorders></w:tblPr>')
    # Column widths
    $null = $sb.Append('<w:tblGrid>')
    for ($c = 0; $c -lt $colCount; $c++) {
        $null = $sb.Append("<w:gridCol w:w=`"$colWidth`"/>")
    }
    $null = $sb.Append('</w:tblGrid>')
    # Header row
    $null = $sb.Append('<w:tr><w:trPr><w:tblHeader/></w:trPr>')
    foreach ($h in $header) {
        $runs = Get-RunsXml "**$h**"
        $null = $sb.Append("<w:tc><w:tcPr><w:tcW w:w=`"$colWidth`" w:type=`"dxa`"/><w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"EEEEEE`"/></w:tcPr><w:p>${runs}</w:p></w:tc>")
    }
    $null = $sb.Append('</w:tr>')
    # Body rows
    foreach ($row in $rows) {
        $null = $sb.Append('<w:tr>')
        foreach ($cell in $row) {
            $runs = Get-RunsXml $cell
            $null = $sb.Append("<w:tc><w:tcPr><w:tcW w:w=`"$colWidth`" w:type=`"dxa`"/></w:tcPr><w:p>${runs}</w:p></w:tc>")
        }
        $null = $sb.Append('</w:tr>')
    }
    $null = $sb.Append('</w:tbl>')
    # Word needs an empty paragraph after a table.
    $null = $sb.Append('<w:p/>')
    return $sb.ToString()
}

# --- Build document.xml body -------------------------------------------------

$bodyXml = New-Object System.Text.StringBuilder
foreach ($s in $sections) {
    switch ($s.kind) {
        'h1' { $null = $bodyXml.Append((New-Heading 1 $s.text)) }
        'h2' { $null = $bodyXml.Append((New-Heading 2 $s.text)) }
        'h3' { $null = $bodyXml.Append((New-Heading 3 $s.text)) }
        'p'  { $null = $bodyXml.Append((New-Paragraph '' $s.text)) }
        'bullet' {
            foreach ($it in $s.items) { $null = $bodyXml.Append((New-Bullet $it)) }
        }
        'table' { $null = $bodyXml.Append((New-Table $s.header $s.rows)) }
        'hr'    { $null = $bodyXml.Append((New-HorizontalRule)) }
    }
}
# Section properties (page size / margins) at end of body.
$sectPr = '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/><w:cols w:space="708"/><w:docGrid w:linePitch="360"/></w:sectPr>'

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$($bodyXml.ToString())
$sectPr
  </w:body>
</w:document>
"@

# --- styles.xml -------------------------------------------------------------
$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="160" w:line="280" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="480" w:after="200"/>
      <w:outlineLvl w:val="0"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/>
      <w:b/>
      <w:color w:val="1F3864"/>
      <w:sz w:val="40"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="360" w:after="120"/>
      <w:outlineLvl w:val="1"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/>
      <w:b/>
      <w:color w:val="2E74B5"/>
      <w:sz w:val="28"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="200" w:after="80"/>
      <w:outlineLvl w:val="2"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/>
      <w:b/>
      <w:color w:val="1F4E79"/>
      <w:sz w:val="24"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph">
    <w:name w:val="List Paragraph"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:ind w:left="720"/>
      <w:contextualSpacing/>
    </w:pPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:basedOn w:val="TableNormal"/>
    <w:tblPr>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:color="999999"/>
        <w:left w:val="single" w:sz="4" w:color="999999"/>
        <w:bottom w:val="single" w:sz="4" w:color="999999"/>
        <w:right w:val="single" w:sz="4" w:color="999999"/>
        <w:insideH w:val="single" w:sz="4" w:color="999999"/>
        <w:insideV w:val="single" w:sz="4" w:color="999999"/>
      </w:tblBorders>
    </w:tblPr>
  </w:style>
  <w:style w:type="table" w:default="1" w:styleId="TableNormal">
    <w:name w:val="Normal Table"/>
  </w:style>
</w:styles>
'@

# --- numbering.xml (for bullets) --------------------------------------------
$numberingXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="&#8226;"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
      <w:rPr>
        <w:rFonts w:ascii="Symbol" w:hAnsi="Symbol"/>
      </w:rPr>
    </w:lvl>
  </w:abstractNum>
  <w:num w:numId="1">
    <w:abstractNumId w:val="0"/>
  </w:num>
</w:numbering>
'@

# --- Container files --------------------------------------------------------
$contentTypesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>
'@

$rootRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@

$docRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>
'@

# --- Write parts to a temp tree then ZIP into .docx --------------------------
Write-Host "Staging OOXML parts under: $tmpRoot"
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpRoot '_rels') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpRoot 'word') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpRoot 'word\_rels') -Force | Out-Null

# Write all parts as UTF-8 without BOM (OOXML requires it)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $tmpRoot '[Content_Types].xml'), $contentTypesXml, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $tmpRoot '_rels\.rels'), $rootRelsXml, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $tmpRoot 'word\document.xml'), $documentXml, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $tmpRoot 'word\styles.xml'), $stylesXml, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $tmpRoot 'word\numbering.xml'), $numberingXml, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $tmpRoot 'word\_rels\document.xml.rels'), $docRelsXml, $utf8NoBom)

# Build the .docx ZIP. We use [ZipArchive] directly so that the entries are
# stored with forward-slash paths (required by the OOXML/ZIP spec) and so
# that we can control compression on a per-entry basis.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path $outPath) { Remove-Item $outPath -Force }
$fs = [System.IO.File]::Open($outPath, [System.IO.FileMode]::Create)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $entries = @(
        @{ src = (Join-Path $tmpRoot '[Content_Types].xml');         entry = '[Content_Types].xml' }
        @{ src = (Join-Path $tmpRoot '_rels\.rels');                  entry = '_rels/.rels' }
        @{ src = (Join-Path $tmpRoot 'word\document.xml');            entry = 'word/document.xml' }
        @{ src = (Join-Path $tmpRoot 'word\styles.xml');              entry = 'word/styles.xml' }
        @{ src = (Join-Path $tmpRoot 'word\numbering.xml');           entry = 'word/numbering.xml' }
        @{ src = (Join-Path $tmpRoot 'word\_rels\document.xml.rels'); entry = 'word/_rels/document.xml.rels' }
    )
    foreach ($e in $entries) {
        $z = $zip.CreateEntry($e.entry, [System.IO.Compression.CompressionLevel]::Optimal)
        $writer = New-Object System.IO.StreamWriter($z.Open(), $utf8NoBom)
        $content = [System.IO.File]::ReadAllText($e.src, $utf8NoBom)
        $writer.Write($content)
        $writer.Flush()
        $writer.Dispose()
    }
} finally {
    $zip.Dispose()
    $fs.Dispose()
}

# Clean up temp dir
Remove-Item $tmpRoot -Recurse -Force

if (Test-Path $outPath) {
    $size = (Get-Item $outPath).Length
    Write-Host "OK - wrote $outPath ($size bytes)"
} else {
    throw "Did not produce $outPath"
}
