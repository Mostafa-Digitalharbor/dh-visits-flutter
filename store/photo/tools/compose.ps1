. "C:\Users\NINJAZ~1\AppData\Local\Temp\claude\e--mostafa-Companies-Digital-Harbor-Visits-location-gps\91b2d9bf-4d8e-4f62-9bc4-3b9f86930cbd\scratchpad\edit\imglib.ps1"
$edited="e:\mostafa\Companies\Digital_Harbor\Visits\location_gps\store\photo\edited"
$outRoot=Join-Path $edited "framed"

function RoundPath([int]$x,[int]$y,[int]$w,[int]$h,[int]$r){
  $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=2*$r
  $p.AddArc($x,$y,$d,$d,180,90); $p.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90); $p.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $p.CloseFigure(); return $p
}
function FitSize($g,$text,$weight,$startPx,$maxW){
  $px=$startPx; while($px -gt 12){ if((Text-Width $g $text $weight $px) -le $maxW){break}; $px-=2 }; return $px
}

function Compose($srcPath,$headline,$subtitle,$TW,$TH,$dstPath){
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
  Draw-TextCentered $g $headline "800" $hpx (RGB 245 248 252) ([int]($TW/2)) $hy
  $spx=[int]($TW*0.026)
  $sy=$hy+[int]($hpx*1.35)
  Draw-TextCentered $g $subtitle "400" $spx (RGB 150 170 200) ([int]($TW/2)) $sy
  $ay=$sy+[int]($spx*1.9)
  Fill-RoundRect $g ([int]($TW/2-46)) $ay 92 6 3 (RGB 63 191 217)

  # --- phone frame (fit into zone below the accent) ---
  $zoneTop=$ay+[int]($TH*0.035)
  $zoneBot=[int]($TH*0.965)
  $zoneH=$zoneBot-$zoneTop
  $bezel=[int]($TW*0.016)
  $maxPW=[int]($TW*0.80)
  $aspect=$shot.Width/$shot.Height
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

# shots in narrative order, with marketing captions
$shots=@(
  @{n='1-visits-list';  f='02_visits_list.png'; h='Your field day, planned';     s='Every assigned visit, start to finish.'}
  @{n='2-visit-detail'; f='01_visit_detail.png';h='Check in with verified GPS';  s='Tamper-resistant location at every site.'}
  @{n='3-dashboard';    f='03_dashboard.png';   h='See your team in real time';  s='Live progress, attendance, and field map.'}
  @{n='4-analytics';    f='04_analytics.png';   h='Performance at a glance';     s='On-time rates, coverage, and trends.'}
)
$targets=[ordered]@{
  'play-phone'=@(1350,2400); 'play-tablet-7'=@(1350,2400); 'play-tablet-10'=@(1600,2560)
  'ios-6.9'=@(1290,2796); 'ios-6.5'=@(1242,2688); 'ipad-13'=@(2064,2752)
}
foreach($t in $targets.Keys){
  $dir=Join-Path $outRoot $t
  if(-not(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $TW,$TH=$targets[$t]
  foreach($s in $shots){ Compose (Join-Path $edited $s.f) $s.h $s.s $TW $TH (Join-Path $dir ($s.n+'.png')) }
  Write-Host ("{0,-15} {1}x{2}" -f $t,$TW,$TH)
}
Write-Host "`nframed -> $outRoot"
