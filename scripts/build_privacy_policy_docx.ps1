# Builds docs\PRIVACY_POLICY.docx WITHOUT requiring Microsoft Word.
#
# A .docx file is a ZIP archive containing OOXML (Office Open XML) files.
# We generate the minimum-viable structure: [Content_Types].xml, _rels/.rels,
# word/document.xml, word/styles.xml, and word/_rels/document.xml.rels.
#
# Re-run any time by editing $sections below. Word, LibreOffice, and Google
# Docs will all open the result.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\build_privacy_policy_docx.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$outPath  = Join-Path $repoRoot 'docs\PRIVACY_POLICY.docx'
$tmpRoot  = Join-Path ([System.IO.Path]::GetTempPath()) ("policy_docx_" + [System.Guid]::NewGuid().ToString('N'))

# --- Content model -----------------------------------------------------------
# Each entry is one of:
#   @{ kind='h1'; text='...' }
#   @{ kind='h2'; text='...' }
#   @{ kind='h3'; text='...' }
#   @{ kind='p';  text='...' }   # bold via **...**, italic via _..._
#   @{ kind='bullet'; items=@('...', '...') }
#   @{ kind='table'; header=@('A','B','C'); rows=@(@('x','y','z'), ...) }
#   @{ kind='hr' }

$sections = @(
    @{ kind='h1'; text='Privacy Policy -- Customer Visits' }
    @{ kind='p';  text='**Effective date:** _Replace with the date you publish this policy_' }
    @{ kind='p';  text='**Last updated:** _Same as effective date for the first version_' }
    @{ kind='p';  text='This Privacy Policy describes how **Digital Harbor** ("we", "us", "our") collects, uses, and protects information when you use the **Customer Visits** mobile application ("the App"). The App is a field workforce tool: employees of our customer organisations use it to check in and out of customer site visits, and to share their live work location with their direct manager during working hours.' }
    @{ kind='p';  text='If you have any question about this policy, contact us at: **ai-tools@digital-harbor.net**' }
    @{ kind='hr' }

    @{ kind='h2'; text='1. Who controls your data' }
    @{ kind='p';  text='The App is provided by Digital Harbor as a tool for our customer organisations (your employer). When you use the App as part of your job:' }
    @{ kind='bullet'; items=@(
        '**Your employer is the data controller** for the visit records and live-location data you generate. Your employer decides who in their organisation can see your location and visit history.',
        '**Digital Harbor is a data processor** -- we build, host and maintain the App and its backend on behalf of your employer. We process your data only on their instructions.'
    )}
    @{ kind='p';  text='If you have questions about how your employer uses this data (retention, access, deletion), contact your employer''s HR or IT department directly.' }

    @{ kind='h2'; text='2. Information we collect' }

    @{ kind='h3'; text='2.1 Account information' }
    @{ kind='p';  text='When your employer creates your account on the backend (Odoo) you provide:' }
    @{ kind='bullet'; items=@(
        'Your name, email or username, and an internal employee ID.',
        'Authentication credentials (password). Passwords are never stored on the device in plain text; only an authenticated session token is kept in the device''s secure storage.'
    )}

    @{ kind='h3'; text='2.2 Location information' }
    @{ kind='p';  text='The App collects your device''s GPS coordinates (latitude, longitude, accuracy radius and timestamp) in the following cases:' }
    @{ kind='table';
        header=@('When', 'Why', 'Stored where');
        rows=@(
            @('When you tap "Check-in" or "Check-out" of a visit', 'To prove you were at the customer site and to record arrival/departure times', 'Visit record on your employer''s Odoo backend'),
            @('Approximately every 30 seconds while the App is open on your screen', 'To share your live position with your manager so they know where the field team is during the work day', '"Live employee location" record on your employer''s Odoo backend, overwriting the previous value')
        )
    }
    @{ kind='p';  text='**The App does not collect or transmit your location when it is in the background, closed, or when you are not logged in.** Live sharing pauses automatically the moment you leave the App and resumes when you return to it. There is no persistent background tracking.' }

    @{ kind='h3'; text='2.3 Visit content' }
    @{ kind='p';  text='You create visit records that include: the customer being visited, visit type, free-text notes you choose to write, and the visit state (draft / submitted / under review / done / cancelled). This content is stored on your employer''s Odoo backend.' }

    @{ kind='h3'; text='2.4 Device & technical data' }
    @{ kind='p';  text='For diagnostics, the App may transmit:' }
    @{ kind='bullet'; items=@(
        'The HTTP request needed to call the backend API (URL, headers, JSON body), over HTTPS only.',
        'Generic device locale (so the App displays in Arabic or English).'
    )}
    @{ kind='p';  text='The App does **not** collect: contact lists, photos, microphone audio, files outside its own sandbox, the IMEI, ad identifiers, or any analytics fingerprint.' }

    @{ kind='h2'; text='3. How we use the information' }
    @{ kind='p';  text='We use the information described above strictly to provide the App''s features:' }
    @{ kind='bullet'; items=@(
        '**Authenticate you** against your employer''s Odoo instance.',
        '**Record visits** and prove you were physically at the customer''s location.',
        '**Share your live location with your manager** during the work day.',
        '**Show maps** of customers, nearby employees and your own position.',
        '**Queue offline actions** (a check-in performed while offline is stored locally and re-sent automatically when connectivity returns).'
    )}
    @{ kind='p';  text='We do **not** use your data for advertising, profiling, behavioural analytics, or sale to third parties.' }

    @{ kind='h2'; text='4. No background tracking' }
    @{ kind='p';  text='The App **does not** track your location in the background.' }
    @{ kind='bullet'; items=@(
        'The App requests only "While Using the App" location access -- both on iOS (When In Use) and on Android (Precise location, only while using the app).',
        'The App does not declare the Android ACCESS_BACKGROUND_LOCATION permission, and does not declare the iOS "location" background mode.',
        'The instant you switch to another app, lock your screen, or close the App, the live-location ticker stops. It restarts automatically when you bring the App back to the foreground.',
        'You can revoke location access at any time from Settings -> Apps -> Customer Visits -> Permissions (Android) or Settings -> Privacy -> Location -> Visits (iOS). If you do, check-in/out and live sharing will both stop working until you re-grant it.'
    )}

    @{ kind='h2'; text='5. Permissions the App requests' }
    @{ kind='table';
        header=@('Permission', 'Reason');
        rows=@(
            @('Precise location (foreground / "while using")', 'Record visit check-in/out coordinates; share live position with manager while App is open'),
            @('Internet / network state', 'Talk to the backend; detect offline state to queue actions')
        )
    }
    @{ kind='p';  text='The App does **not** request: background location, foreground service, camera, microphone, contacts, calendar, SMS, phone, or files/photos.' }

    @{ kind='h2'; text='6. Data sharing' }
    @{ kind='p';  text='We share your data only with the following parties:' }
    @{ kind='bullet'; items=@(
        '**Your employer**, who is the controller of the data. Anyone in your employer''s organisation that your employer has granted manager privileges to can see your live location and visit history.',
        '**Our cloud hosting provider** (Odoo SH / equivalent), strictly to operate the backend. No marketing or third-party processing.',
        '**Authorities**, only if we are legally compelled by a valid court order.'
    )}
    @{ kind='p';  text='We do **not** sell or share your data with advertisers, analytics platforms, or data brokers.' }

    @{ kind='h2'; text='7. Data retention' }
    @{ kind='bullet'; items=@(
        '**Session token** stored on the device: cleared automatically on logout, or when the OS evicts the secure storage.',
        '**Live location** on the backend: overwrites the previous value, so we keep only your most recent live position, not a track history. Older values are not retained.',
        '**Visit records**: retained according to your employer''s retention schedule. Contact your employer to request deletion.'
    )}

    @{ kind='h2'; text='8. Security' }
    @{ kind='bullet'; items=@(
        'All traffic between the App and the backend is over HTTPS (TLS). Cleartext HTTP is blocked at the OS level on both Android (usesCleartextTraffic=false) and iOS (App Transport Security).',
        'The session token is stored using the device''s secure storage (Android KeyStore / iOS Keychain).',
        'The App is excluded from automatic Android cloud backups so the session secret is never copied to a different device.'
    )}
    @{ kind='p';  text='No system is 100% secure. If you suspect your account is compromised, change your password from your employer''s Odoo portal immediately.' }

    @{ kind='h2'; text='9. Children' }
    @{ kind='p';  text='The App is a workplace tool intended for adult employees of our customer organisations. It is **not** directed at children under 16, and we do not knowingly collect data from anyone under 16.' }

    @{ kind='h2'; text='10. Your rights' }
    @{ kind='p';  text='Because your employer is the controller of the data:' }
    @{ kind='bullet'; items=@(
        'To request **access, correction, or deletion** of your visit history or live-location record, contact your employer''s HR or IT.',
        'For complaints about how Digital Harbor (the processor) handles your data, contact us at **ai-tools@digital-harbor.net**.',
        'Depending on your country, you may also have the right to lodge a complaint with your local data protection authority.'
    )}

    @{ kind='h2'; text='11. Changes to this policy' }
    @{ kind='p';  text='We may update this policy when we add features, change subprocessors, or comply with new regulations. We will publish the updated policy at the same URL where you found this document and update the "Last updated" date at the top. Material changes will additionally be communicated via the App on next launch.' }

    @{ kind='h2'; text='12. Contact' }
    @{ kind='p';  text='**Digital Harbor**' }
    @{ kind='p';  text='Email: **ai-tools@digital-harbor.net**' }
    @{ kind='p';  text='Website: **https://digital-harbor.net**' }
    @{ kind='hr' }
    @{ kind='p';  text='_This policy is provided as a template tailored to the Customer Visits App''s actual data flows. Please review it with your legal counsel before publishing publicly. Replace all italic placeholder text (effective date, etc.) before going live._' }
)

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
        $escaped = Escape-Xml $t
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
