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
    @{ kind='p';  text='**Effective date:** 14 September 2026' }
    @{ kind='p';  text='**Last updated:** 14 September 2026' }
    @{ kind='p';  text='This Privacy Policy describes how **Digital Harbor** ("we", "us", "our") collects, uses, and protects information when you use the **Customer Visits** mobile application ("the App"). The App is a field workforce tool: employees of our customer organisations use it to plan and record customer site visits, to record their route during a work day, and to share their work location with their manager during working hours.' }
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
        'Authentication credentials (password). The password is kept only in the device''s secure storage (Android Keystore / iOS Keychain) so the App can renew your session, and is never written to logs or crash reports.'
    )}

    @{ kind='h3'; text='2.2 Location information' }
    @{ kind='p';  text='The App collects your device''s location -- latitude, longitude, accuracy, and, for route recording, altitude, speed, heading and the time of each position -- in the following cases:' }
    @{ kind='table';
        header=@('When', 'Why', 'Stored where');
        rows=@(
            @('When you start or end a customer visit', 'To prove you were at the customer site and record arrival/departure times', 'Visit record on your employer''s backend'),
            @('While a visit you started is in progress', 'To record the visit''s route', 'Visit route on your employer''s backend'),
            @('About every 30 seconds while the App is open on your screen', 'To share your current position with your manager', 'Your "live location" record on your employer''s backend (the previous value is overwritten)'),
            @('**During an active work day** -- from Start work day until End work day or sign-out, including while the App is in the background, closed from the screen, or the screen is locked', 'To record your work-day route: the whole day, including the movement between visits', 'Work-day route on your employer''s backend')
        )
    }
    @{ kind='p';  text='**Work-day route recording.** While your work day is active, the App records a position about every 5 seconds while you are moving (at least 5 metres apart, and nothing while you stand still), also when you switch to another app or lock your screen. On Android a notification ("Workday tracking active") is shown for as long as recording runs; on iOS the system shows its location indicator. Before the first work day, the App explains this on screen and asks for your agreement before any permission prompt.' }
    @{ kind='p';  text='**When the App does not collect location:**' }
    @{ kind='bullet'; items=@(
        'when no work day is active and the App is not open on your screen;',
        'after you tap End work day -- recording stops immediately;',
        'after you sign out;',
        'when you have not granted location permission, or have revoked it.'
    )}
    @{ kind='p';  text='**Offline storage.** Without a network, recorded positions are kept in the App''s private storage on your device until they can be uploaded to your employer''s backend, and are removed from the device once uploaded.' }
    @{ kind='p';  text='**Road matching (map display).** To draw your recorded routes along roads, the App may send recorded positions (coordinates, their accuracy, heading, and time offsets relative to the first position -- not the actual date and time) to a road-matching service. It only returns a line to draw; your recorded positions are not changed. No name, employee ID, device ID, credential or session is sent. In the production App this service is operated by Digital Harbor on infrastructure it controls (directly or through a hosting provider acting on its behalf), never by a public routing service; if none is configured, routes are drawn as recorded and nothing is sent. Map lines are cached on the device for up to 30 days and deleted when you sign out.' }

    @{ kind='h3'; text='2.3 Visit content' }
    @{ kind='p';  text='You create visit records that include: the customer being visited, visit type, free-text notes you choose to write, the outcome, and the visit state. You may optionally capture a photo with the camera or attach a file as proof of the visit; only what you choose at that moment is uploaded. This content is stored on your employer''s backend.' }

    @{ kind='h3'; text='2.4 Device & technical data' }
    @{ kind='bullet'; items=@(
        'The requests needed to call your employer''s backend, over HTTPS only.',
        'A device-specific push notification token (Firebase Cloud Messaging), stored on your employer''s backend against your account.',
        'Crash reports and performance measurements sent to Sentry, configured to exclude personal information (no name, email, location or IP address).',
        'Generic device locale (so the App displays in Arabic or English).'
    )}
    @{ kind='p';  text='The App does **not** collect: contact lists, microphone audio, your photo library, files outside what you choose to attach, the IMEI, advertising identifiers, or any analytics fingerprint.' }

    @{ kind='h2'; text='3. How we use the information' }
    @{ kind='p';  text='We use the information described above strictly to provide the App''s features:' }
    @{ kind='bullet'; items=@(
        '**Authenticate you** against your employer''s backend.',
        '**Record visits** and prove you were physically at the customer''s location.',
        '**Record your work-day route** between Start work day and End work day, including travel between visits.',
        '**Share your live location with your manager** while the App is open.',
        '**Show maps** of customers, routes and positions, with routes drawn along roads where road matching is available.',
        '**Keep working offline** -- actions and recorded positions are stored on the device and sent automatically when connectivity returns.'
    )}
    @{ kind='p';  text='We do **not** use your data for advertising, profiling, behavioural analytics, or sale to third parties.' }

    @{ kind='h2'; text='4. Background location during an active work day' }
    @{ kind='p';  text='The App uses your location in the background **only while a work day you started is active**.' }
    @{ kind='bullet'; items=@(
        '**Android:** recording runs in a foreground service of type "location", started when you tap Start work day, with a notification visible for as long as it runs. The App requests location access "while using the app" and does not request the Android background location permission.',
        '**iOS:** the App declares the iOS "location" background mode. With "While Using the App" access, recording continues in the background once you started the work day in the App. The App may also ask you to allow "Always"; this is optional and only lets recording resume if iOS closes the App during your work day.',
        '**Stopping:** tap End work day, or sign out. You can also revoke location access at any time in your device Settings; visit check-in/out, live sharing and work-day recording then stop until access is granted again.'
    )}

    @{ kind='h2'; text='5. Permissions the App requests' }
    @{ kind='table';
        header=@('Permission', 'Reason');
        rows=@(
            @('Precise and approximate location (while using the app)', 'Visit coordinates, visit routes, live sharing while the App is open, and the work-day route'),
            @('Android: foreground service (location)', 'Keep recording the work-day route in the background or with the screen locked, with a visible notification'),
            @('iOS: location background mode; optional "Always" access', 'Keep recording the work-day route in the background; "Always" lets recording resume if iOS closes the App'),
            @('iOS: temporary precise location', 'Asked only if Precise Location is off, because a route cannot be recorded accurately without it'),
            @('Notifications', 'Visit workflow notifications; on Android also the work-day recording notification'),
            @('Camera', 'Optional proof-of-visit photos'),
            @('Internet / network state', 'Talk to the backend; detect offline state to queue actions')
        )
    }
    @{ kind='p';  text='The App does **not** request: the Android background location permission, microphone, contacts, calendar, SMS or phone.' }

    @{ kind='h2'; text='6. Data sharing' }
    @{ kind='p';  text='We share your data only with the following parties:' }
    @{ kind='bullet'; items=@(
        '**Your employer**, who is the controller of the data. Anyone your employer grants manager rights can see the live location, work-day routes and visit history of the employees they manage.',
        '**Our hosting providers**, strictly to operate the backend and, where configured, the road-matching service.',
        '**Sentry** (crash and performance reports without personal information) and **Firebase Cloud Messaging** (push notification delivery).',
        '**Authorities**, only if we are legally compelled by a valid court order.'
    )}
    @{ kind='p';  text='We do **not** sell or share your data with advertisers, analytics platforms, or data brokers.' }

    @{ kind='h2'; text='7. Data retention' }
    @{ kind='bullet'; items=@(
        '**Session and credentials** stored on the device: deleted on sign-out.',
        '**Positions waiting to upload** on the device: removed once uploaded; at most about 8,000 waiting work-day positions are kept, the oldest discarded beyond that.',
        '**Road-matched map lines** cached on the device: up to 30 days, deleted on sign-out.',
        '**Live location** on the backend: only your most recent position is kept.',
        '**Visit records, visit routes and work-day routes** on the backend: retained according to your employer''s retention schedule. Work-day positions cannot be edited or deleted from the App. Contact your employer to request deletion.'
    )}

    @{ kind='h2'; text='8. Security' }
    @{ kind='bullet'; items=@(
        'All traffic between the App and the backend and road-matching service is over HTTPS (TLS). Cleartext HTTP is blocked on both Android and iOS.',
        'Credentials are stored in the device''s secure storage (Android Keystore / iOS Keychain).',
        'Positions waiting to upload are stored in the App''s private storage (on iOS protected until the device is first unlocked after a restart), and the App is excluded from Android cloud backups.',
        'On the backend, employees can only add positions to their own active work day, managers can only see the employees they manage, and recorded positions cannot be changed.'
    )}
    @{ kind='p';  text='No system is 100% secure. If you suspect your account is compromised, change your password from your employer''s Odoo portal immediately.' }

    @{ kind='h2'; text='9. Children' }
    @{ kind='p';  text='The App is a workplace tool intended for adult employees of our customer organisations. It is **not** directed at children under 16, and we do not knowingly collect data from anyone under 16.' }

    @{ kind='h2'; text='10. Your rights' }
    @{ kind='p';  text='Because your employer is the controller of the data:' }
    @{ kind='bullet'; items=@(
        'To request **access, correction, or deletion** of your visit history, work-day routes or live-location record, contact your employer''s HR or IT.',
        'For complaints about how Digital Harbor (the processor) handles your data, contact us at **ai-tools@digital-harbor.net**.',
        'Depending on your country, you may also have the right to lodge a complaint with your local data protection authority.'
    )}

    @{ kind='h2'; text='11. Changes to this policy' }
    @{ kind='p';  text='We may update this policy when we add features, change subprocessors, or comply with new regulations. We will publish the updated policy at the same URL where you found this document and update the "Last updated" date at the top. Material changes will additionally be communicated via the App on next launch.' }

    @{ kind='h2'; text='12. Contact' }
    @{ kind='p';  text='**Digital Harbor**' }
    @{ kind='p';  text='Email: **ai-tools@digital-harbor.net**' }
    @{ kind='p';  text='Website: **https://digitalharbor.com.sa**' }
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
