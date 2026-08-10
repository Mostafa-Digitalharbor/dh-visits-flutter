<#
  Composes store screenshots: headline + subtitle + device frame on the brand navy
  background, at each store's required canvas size.

      powershell -ExecutionPolicy Bypass -File store/photo/tools/compose.ps1 -Platform play
      powershell -ExecutionPolicy Bypass -File store/photo/tools/compose.ps1 -Platform ios

  Source sets — they are NOT interchangeable:
      play -> store/photo/edited/   Android captures (1080x2400)
      ios  -> store/photo/ios/      iOS Simulator captures (1290x2796)

  App Store shots must come from the ios set. Build 1.0 (4) was rejected under
  guideline 2.3.10 because the App Store screenshots were framed Android captures
  (Android status bar + gesture pill). Capture the iOS set on a Mac with
  store/photo/tools/ios_shots.sh. Details: store/appstore/apple-review-2026-08-06.md.

  iPad sizes are gone: TARGETED_DEVICE_FAMILY is "1" (iPhone only) as of 1.0.1 (5).
#>
param([ValidateSet('play', 'ios', 'ipad')][string]$Platform = 'play')

. (Join-Path $PSScriptRoot 'imglib.ps1')

$photo   = Split-Path $PSScriptRoot -Parent
$srcRoot = switch ($Platform) {
  'ios'  { Join-Path $photo 'ios' }
  'ipad' { Join-Path $photo 'ios-tablet' }
  default { Join-Path $photo 'edited' }
}
$outRoot = Join-Path $photo "framed-$Platform"

function RoundPath([int]$x,[int]$y,[int]$w,[int]$h,[int]$r){
  $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=2*$r
  $p.AddArc($x,$y,$d,$d,180,90); $p.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90); $p.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $p.CloseFigure(); return $p
}
function FitSize($g,$text,$weight,$startPx,$maxW){
  $px=$startPx; while($px -gt 12){ if((Text-Width $g $text $weight $px) -le $maxW){break}; $px-=2 }; return $px
}

function Draw-TextCenteredRTL($g,[string]$text,[string]$weight,[double]$px,$color,[int]$cx,[int]$topY){
  $font = New-CairoFont $weight $px
  $br = New-Object System.Drawing.SolidBrush $color
  $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft
  $sz = $g.MeasureString($text,$font,[int]0,$sf)
  $w = [single]($sz.Width + $px)
  $rect = New-Object System.Drawing.RectangleF ([single]($cx - $w/2)),([single]$topY),$w,([single]($px*2.4))
  $g.DrawString($text,$font,$br,$rect,$sf)
  $br.Dispose(); $font.Dispose()
}

function Compose($srcPath,$headline,$subtitle,$TW,$TH,$dstPath,[bool]$rtl=$false){
  $shot=Open-Img $srcPath
  $canvas=New-Object System.Drawing.Bitmap $TW,$TH
  $g=New-Graphics $canvas

  # --- background: brand navy gradient (app colors) ---
  $rect=New-Object System.Drawing.Rectangle 0,0,$TW,$TH
  $bg=New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect,(RGB 28 40 100),(RGB 6 9 30),115.0
  $g.FillRectangle($bg,$rect); $bg.Dispose()
  # --- brand cyan glow behind phone top ---
  $gx=[int]($TW*0.5); $gy=[int]($TH*0.32); $gr=[int]([Math]::Max($TW,$TH)*0.42)
  $gp=New-Object System.Drawing.Drawing2D.GraphicsPath
  $gp.AddEllipse(($gx-$gr),($gy-$gr),(2*$gr),(2*$gr))
  $pgb=New-Object System.Drawing.Drawing2D.PathGradientBrush $gp
  $pgb.CenterColor=[System.Drawing.Color]::FromArgb(65,63,191,217)   # cyan500
  $pgb.SurroundColors=@([System.Drawing.Color]::FromArgb(0,63,191,217))
  $g.FillPath($pgb,$gp); $pgb.Dispose(); $gp.Dispose()

  # --- headline + subtitle + accent ---
  $maxTextW=[int]($TW*0.90)
  $hpx=FitSize $g $headline "800" ([int]($TW*0.050)) $maxTextW
  $hy=[int]($TH*0.042)
  $spx=[int]($TW*0.026)
  # Arabic sits lower in the line box and has deep descenders, so the headline
  # and subtitle need more room than the Latin set did.
  $sy=$hy+[int]($hpx*$(if($rtl){1.75}else{1.35}))
  if($rtl){
    Draw-TextCenteredRTL $g $headline "800" $hpx (RGB 245 248 252) ([int]($TW/2)) $hy
    Draw-TextCenteredRTL $g $subtitle "400" $spx (RGB 150 170 200) ([int]($TW/2)) $sy
  } else {
    Draw-TextCentered $g $headline "800" $hpx (RGB 245 248 252) ([int]($TW/2)) $hy
    Draw-TextCentered $g $subtitle "400" $spx (RGB 150 170 200) ([int]($TW/2)) $sy
  }
  $ay=$sy+[int]($spx*$(if($rtl){2.6}else{1.9}))
  Fill-RoundRect $g ([int]($TW/2-46)) $ay 92 6 3 (RGB 63 191 217)

  # --- phone frame (fit into zone below the accent) ---
  $zoneTop=$ay+[int]($TH*0.035)
  $zoneBot=[int]($TH*0.965)
  $zoneH=$zoneBot-$zoneTop
  $bezel=[int]($TW*0.016)
  $aspect=$shot.Width/$shot.Height
  # A landscape tablet frame is short for its width, so it can take more of the
  # canvas before it starts to crowd the headline.
  $maxPW=[int]($TW*$(if($aspect -gt 1){0.88}else{0.80}))
  $screenW=$maxPW-2*$bezel
  $screenH=[int]($screenW/$aspect)
  $phoneH=$screenH+2*$bezel
  if($phoneH -gt $zoneH){ $phoneH=$zoneH; $screenH=$phoneH-2*$bezel; $screenW=[int]($screenH*$aspect) }
  $phoneW=$screenW+2*$bezel
  $px=[int](($TW-$phoneW)/2)
  $py=[int]($zoneTop+($zoneH-$phoneH)/2)
  $rPhone=[int]($TW*0.055); $rScreen=$rPhone-$bezel

  $sh=RoundPath ($px+6) ($py+16) $phoneW $phoneH $rPhone
  $shb=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(95,0,0,0))
  $g.FillPath($shb,$sh); $shb.Dispose(); $sh.Dispose()
  $body=RoundPath $px $py $phoneW $phoneH $rPhone
  $bb=New-Object System.Drawing.SolidBrush (RGB 9 15 26)
  $g.FillPath($bb,$body); $bb.Dispose()
  $pen=New-Object System.Drawing.Pen ((RGB 48 62 92)),2
  $g.DrawPath($pen,$body); $pen.Dispose(); $body.Dispose()
  $sx=$px+$bezel; $sy2=$py+$bezel
  $screen=RoundPath $sx $sy2 $screenW $screenH $rScreen
  $g.SetClip($screen)
  $g.DrawImage($shot,$sx,$sy2,$screenW,$screenH)
  $g.ResetClip(); $screen.Dispose()

  $g.Dispose(); Save-Png $canvas $dstPath
  $shot.Dispose(); $canvas.Dispose()
}

# shots in narrative order, with marketing captions. The iOS/iPad captures show
# the app in Arabic, so those canvases get Arabic headlines; the Play set is the
# older English capture run.
$rtl = $Platform -in @('ios','ipad')
$shots = if ($rtl) {
  @(
    @{n='1-visits-list';  f='02_visits_list.png'; h='زياراتك اليوم في مكان واحد'; s='من التخطيط حتى الاعتماد.'}
    @{n='2-visit-detail'; f='01_visit_detail.png';h='حضور موثّق بالموقع';          s='إحداثيات دقيقة عند كل عميل.'}
    @{n='3-dashboard';    f='03_dashboard.png';   h='فريقك أمامك لحظة بلحظة';      s='التقدّم والحضور وخريطة الميدان.'}
    @{n='4-analytics';    f='04_analytics.png';   h='الأداء في نظرة واحدة';        s='الالتزام بالمواعيد والتغطية والاتجاهات.'}
  )
} else {
  @(
    @{n='1-visits-list';  f='02_visits_list.png'; h='Your field day, planned';     s='Every assigned visit, start to finish.'}
    @{n='2-visit-detail'; f='01_visit_detail.png';h='Check in with verified GPS';  s='Tamper-resistant location at every site.'}
    @{n='3-dashboard';    f='03_dashboard.png';   h='See your team in real time';  s='Live progress, attendance, and field map.'}
    @{n='4-analytics';    f='04_analytics.png';   h='Performance at a glance';     s='On-time rates, coverage, and trends.'}
  )
}

$targets = switch ($Platform) {
  # 6.9" is the size Apple requires for new submissions; 6.5" is the legacy slot
  # the listing was originally built for, kept because it is still accepted.
  'ios'  { [ordered]@{ 'ios-6.9'=@(1290,2796); 'ios-6.5'=@(1242,2688) } }
  # iPad 13" accepts either orientation; the captures are landscape.
  'ipad' { [ordered]@{ 'ipad-13'=@(2752,2064) } }
  default { [ordered]@{ 'play-phone'=@(1350,2400); 'play-tablet-7'=@(1350,2400); 'play-tablet-10'=@(1600,2560) } }
}

$missing=@($shots | Where-Object { -not (Test-Path (Join-Path $srcRoot $_.f)) })
if ($missing.Count -eq $shots.Count) {
  throw "no source screenshots in $srcRoot. For -Platform ios, capture them first on a Mac: bash store/photo/tools/ios_shots.sh"
}

foreach($t in $targets.Keys){
  $dir=Join-Path $outRoot $t
  if(-not(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $TW,$TH=$targets[$t]
  foreach($s in $shots){
    $srcFile=Join-Path $srcRoot $s.f
    if(-not(Test-Path $srcFile)){ Write-Warning "missing $($s.f) in $srcRoot"; continue }
    Compose $srcFile $s.h $s.s $TW $TH (Join-Path $dir ($s.n+'.png')) $rtl
  }
  Write-Host ("{0,-15} {1}x{2}" -f $t,$TW,$TH)
}
Write-Host "`nframed -> $outRoot  (source: $srcRoot)"
