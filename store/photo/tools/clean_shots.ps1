<#
  Turns the raw Android captures in live-assets/ into App-Store-ready screen
  images: iOS system chrome instead of Android chrome, no test-data markers, and
  demo figures that show the product working rather than an empty trial account.

      powershell -ExecutionPolicy Bypass -File store/photo/tools/clean_shots.ps1

  Output (the "screen" images that compose.ps1 then frames):
      store/photo/ios/        1080x2400  -> iPhone canvases
      store/photo/ios-tablet/ 2560x1600  -> iPad canvas

  Every number changed here is demo data, not a claim about a real deployment.
  What gets fixed and why:
    - Android status bar (3G, Android signal/battery, punch-hole) and gesture
      pill -> iOS clock/cellular/wifi/battery + home indicator. This is the
      guideline 2.3.10 rejection from 2026-08-06.
    - "[DH Demo]" markers on every visit purpose -> removed (test-data markers
      read as an unfinished app; Play's metadata policy and Apple 2.3.3).
    - Empty-account figures (0% on time, 00:00 avg visit, 0 km, 0/1 today) and
      the red "4 overdue" / escalated flags -> a healthy week.
#>

. (Join-Path $PSScriptRoot 'ioschrome.ps1')

$root = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent   # tools -> photo -> store -> repo
$src = Join-Path $root 'live-assets'
$outPhone = Join-Path $root 'store\photo\ios'
$outTablet = Join-Path $root 'store\photo\ios-tablet'
foreach ($d in @($outPhone, $outTablet)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

# app palette (sampled from the captures)
$cScreen = RGB 10 11 16      # phone status-bar / screen background
$cSurface = RGB 14 15 21     # app surface
$cWhite = RGB 255 255 255
$cLabel = RGB 150 155 168    # KPI caption grey
$cGreen = RGB 74 222 128
$cGreenDim = RGB 34 197 94

function Open-Shot([string]$name) {
  $b = Open-Img (Join-Path $src $name)
  return $b
}

# ── 1. phone: visit detail (map + in-progress badge) ──────────────────────────
function Build-PhoneVisitDetail {
  $b = Open-Shot 'Screenshot_1786260349.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 1080 136 $cScreen
  Draw-IOSHomeIndicator $b $g 1080 2400 (RGB 0 0 0) 74
  $g.Dispose()
  Save-Png $b (Join-Path $outPhone '01_visit_detail.png'); $b.Dispose()
}

# ── 2. phone: visits list awaiting approval ───────────────────────────────────
function Build-PhoneVisitsList {
  $b = Open-Shot 'Screenshot_1786260334.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 1080 136 $cScreen
  Draw-IOSHomeIndicator $b $g 1080 2400 (RGB 0 0 0) 74

  # "[DH Demo]" tail on each purpose line. The line is right-aligned, so the tail
  # cannot just be wiped (it would leave a gap at the edge) — the whole line is
  # redrawn without it.
  $purposes = @(
    @{ y = 936; text = 'Contract renewal site check' },
    @{ y = 1354; text = 'Security and QA joint inspection' },
    @{ y = 1774; text = 'Quarterly service review' }
  )
  foreach ($p in $purposes) {
    Erase-Rect $b $g 300 $p.y 720 52 150 ($p.y + 20)
    Draw-TextRight $g $p.text '400' 29 (RGB 185 191 204) 1012 ($p.y + 2) $false
  }
  # red "escalated !" flag on each row
  foreach ($y in @(870, 1290, 1710)) { Erase-Rect $b $g 583 $y 210 48 150 ($y + 20) }

  $g.Dispose()
  Save-Png $b (Join-Path $outPhone '02_visits_list.png'); $b.Dispose()
}

# ── 3. phone: manager dashboard ───────────────────────────────────────────────
function Build-PhoneDashboard {
  $b = Open-Shot 'Screenshot_1786260328.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 1080 136 $cScreen
  Draw-IOSHomeIndicator $b $g 1080 2400 (RGB 0 0 0) 74

  # greeting card sits on a horizontal gradient -> refill with a matching one
  # "Administrator" -> a field-manager persona
  Erase-Grad $b $g 495 445 350 60
  Draw-TextRight $g 'Rana Khalil' '700' 42 $cWhite 845 448 $false
  # avatar letter A -> R
  Erase-Grad $b $g 900 420 62 62
  Draw-TextMid $g 'R' '700' 42 $cWhite 931 434

  # "today 0/1 · 0%" -> a day that is nearly done
  Erase-Grad $b $g 690 554 320 58 528
  Draw-TextRight $g 'إنجاز اليوم  5/6 · 83٪' '600' 30 (RGB 226 232 240) 1000 558
  # progress bar: fill 83% from the right (RTL)
  $barX = 94; $barY = 634; $barW = 892; $barH = 15
  Fill-RoundRect $g $barX $barY $barW $barH 7 (RGB 255 255 255 60)
  $fill = [int]($barW * 0.83)
  Fill-RoundRect $g ($barX + $barW - $fill) $barY $fill $barH 7 (RGB 255 255 255 235)

  # bottom row: visits today 1 -> 6, field time 0h -> 5h
  Erase-Grad $b $g 924 690 30 52 672
  Draw-TextRight $g '6' '700' 32 $cWhite 948 694 $false
  Erase-Grad $b $g 574 690 70 52 672
  Draw-TextRight $g '5 س' '700' 32 $cWhite 640 694

  # KPI: red "4 overdue" -> neutral card, zero overdue
  $cx = 558; $cy = 834; $cw = 480; $ch = 336
  $cardBg = $b.GetPixel(700, 1300)          # the neutral "visits today" card
  $cardBd = $b.GetPixel(560, 1300)
  # wipe the red card whole (its tinted border sits a few px outside the fill)
  Fill-Rect $g ($cx - 10) ($cy - 10) ($cw + 20) ($ch + 20) ($b.GetPixel(540, 1000))
  Fill-RoundRect $g $cx $cy $cw $ch 34 $cardBg
  $pen = New-Object System.Drawing.Pen $cardBd, 2
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 68
  $path.AddArc($cx, $cy, $d, $d, 180, 90); $path.AddArc($cx + $cw - $d, $cy, $d, $d, 270, 90)
  $path.AddArc($cx + $cw - $d, $cy + $ch - $d, $d, $d, 0, 90); $path.AddArc($cx, $cy + $ch - $d, $d, $d, 90, 90)
  $path.CloseFigure(); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
  # icon tile + check mark, sized to match the other cards' icon badges
  Fill-RoundRect $g ($cx + 66) ($cy + 40) 60 60 20 (RGB 20 66 44)
  $cpen = New-Object System.Drawing.Pen $cGreen, 6
  $cpen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $cpen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $cpen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawLines($cpen, @(
      (New-Object System.Drawing.Point (($cx + 82), ($cy + 70))),
      (New-Object System.Drawing.Point (($cx + 93), ($cy + 82))),
      (New-Object System.Drawing.Point (($cx + 112), ($cy + 56)))))
  $cpen.Dispose()
  # chevron, number, label
  Copy-Patch $b $g 940 1248 40 44 ($cx + $cw - 100) ($cy + 36)
  Draw-TextRight $g '0' '700' 84 $cGreen ($cx + $cw - 46) ($cy + 126) $false
  Draw-TextRight $g 'متأخرة' '600' 30 $cLabel ($cx + $cw - 46) ($cy + 246)

  # keep the "visits today" KPI consistent with the greeting card (1 -> 6)
  Erase-Rect $b $g 930 1345 72 92 700 1300
  Draw-TextRight $g '6' '700' 84 (RGB 199 205 240) 986 1352 $false

  $g.Dispose()
  Save-Png $b (Join-Path $outPhone '03_dashboard.png'); $b.Dispose()
}

# ── 4. phone: analytics ───────────────────────────────────────────────────────
function Build-PhoneAnalytics {
  $b = Open-Shot 'Screenshot_1786260340.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 1080 136 $cScreen
  Draw-IOSHomeIndicator $b $g 1080 2400 (RGB 0 0 0) 74

  # Blank pixels inside each KPI tile, used as the erase colour. Sampling
  # outside the tile picks up the darker page background and leaves a visible box.
  $tl = 70, 560; $tr = 586, 560; $bl = 70, 926; $br2 = 586, 926

  # KPI values. Left column is right-aligned at x=480, right column at x=996;
  # row 1 numbers sit at y=466, row 2 at y=832 (draw origin, not glyph top).
  Erase-Rect $b $g 350 495 145 96 $tl[0] $tl[1]
  Draw-TextRight $g '23' '700' 76 $cWhite 480 466 $false
  Erase-Rect $b $g 790 495 215 96 $tr[0] $tr[1]
  Draw-TextRight $g '96%' '700' 76 $cWhite 996 466 $false
  Erase-Rect $b $g 290 860 205 96 $bl[0] $bl[1]
  Draw-TextRight $g '00:42' '700' 68 $cWhite 480 838 $false
  Erase-Rect $b $g 860 860 145 96 $br2[0] $br2[1]
  Draw-TextRight $g '38' '700' 76 $cWhite 996 832 $false

  # deltas — text ends at x=190 (left column) / x=702 (right); the trend arrow
  # occupies the ~36px to the right of that and is left in place.
  Erase-Rect $b $g 94 398 100 40 $tl[0] $tl[1]
  Draw-TextRight $g '+15٪' '600' 26 $cGreen 190 404 $false
  Erase-Rect $b $g 606 398 100 40 $tr[0] $tr[1]
  Draw-TextRight $g '+6٪' '600' 26 $cGreen 702 404 $false
  Erase-Rect $b $g 94 768 100 40 $bl[0] $bl[1]
  Draw-TextRight $g '+8د' '600' 26 $cGreen 190 774 $false
  # km delta was red with a down arrow: wipe both, borrow the green up arrow
  Erase-Rect $b $g 606 764 148 46 $br2[0] $br2[1]
  Copy-Patch $b $g 703 398 44 38 703 768
  Draw-TextRight $g '+18٪' '600' 26 $cGreen 702 774 $false

  # weekly chart: an empty trial week (1,1,0,1,1,1,0) -> a worked week summing
  # to the 23 visits claimed by the KPI above
  $chartBg = $b.GetPixel(500, 1150)
  Fill-Rect $g 100 1215 900 345 $chartBg
  $days = @(6, 4, 0, 5, 3, 5, 0)
  $cxs = @(148, 278, 409, 540, 671, 802, 932)
  $barW = 34; $baseY = 1542; $maxH = 264; $maxV = 6
  for ($i = 0; $i -lt 7; $i++) {
    $v = $days[$i]
    $h = if ($v -eq 0) { 14 } else { [int]($maxH * $v / $maxV) }
    $x = $cxs[$i] - [int]($barW / 2)
    $y = $baseY - $h
    if ($i -eq 0) {
      $rect = New-Object System.Drawing.Rectangle $x, ($y - 1), $barW, ($h + 2)
      $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (RGB 63 145 217), (RGB 94 216 240), ([System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
      $path = New-Object System.Drawing.Drawing2D.GraphicsPath
      $d = $barW
      $path.AddArc($x, $y, $d, $d, 180, 90); $path.AddArc($x + $barW - $d, $y, $d, $d, 270, 90)
      $path.AddArc($x + $barW - $d, $baseY - $d, $d, $d, 0, 90); $path.AddArc($x, $baseY - $d, $d, $d, 90, 90)
      $path.CloseFigure(); $g.FillPath($br, $path); $br.Dispose(); $path.Dispose()
    } else {
      Fill-RoundRect $g $x $y $barW $h ([int]($barW / 2)) (RGB 27 32 48)
    }
    $col = if ($i -eq 0) { RGB 125 211 252 } else { if ($v -eq 0) { RGB 110 116 130 } else { RGB 226 232 240 } }
    Draw-TextMid $g "$v" '600' 30 $col $cxs[$i] 1224
  }

  # employee row: 0% · 1 -> 96% · 12, and fill the empty bar
  Erase-Rect $b $g 78 1840 200 46 300 1820
  Draw-TextRight $g '96٪ · 12' '600' 28 $cGreen 250 1844 $false
  $ebX = 84; $ebY = 1896; $ebW = 770; $ebH = 12
  Fill-RoundRect $g $ebX $ebY $ebW $ebH 6 (RGB 30 34 44)
  Fill-RoundRect $g ($ebX + $ebW - [int]($ebW * 0.96)) $ebY ([int]($ebW * 0.96)) $ebH 6 $cGreenDim

  $g.Dispose()
  Save-Png $b (Join-Path $outPhone '04_analytics.png'); $b.Dispose()
}

# ── tablet (landscape 2560x1600) -> iPad canvas ───────────────────────────────
$tabBg = RGB 14 15 21
$tabBarH = 56
$tabStrip = 64

function Build-TabletVisitDetail {
  $b = Open-Shot 'Screenshot_1786258845.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 2560 $tabBarH $tabBg '9:41' 92
  Draw-IOSHomeIndicator $b $g 2560 1600 $tabBg $tabStrip
  $g.Dispose()
  Save-Png $b (Join-Path $outTablet '01_visit_detail.png'); $b.Dispose()
}

function Build-TabletVisitsList {
  $b = Open-Shot 'Screenshot_1786258659.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 2560 $tabBarH $tabBg '9:41' 92
  Draw-IOSHomeIndicator $b $g 2560 1600 $tabBg $tabStrip

  $purposes = @(
    @{ y = 618; text = 'Contract renewal site check' },
    @{ y = 894; text = 'Security and QA joint inspection' },
    @{ y = 1168; text = 'Quarterly service review' }
  )
  foreach ($p in $purposes) {
    Erase-Rect $b $g 1700 $p.y 820 46 300 ($p.y + 18)
    Draw-TextRight $g $p.text '400' 26 (RGB 185 191 204) 2506 ($p.y + 2) $false
  }
  foreach ($y in @(556, 832, 1108)) { Erase-Rect $b $g 1498 $y 180 42 300 ($y + 16) }

  $g.Dispose()
  Save-Png $b (Join-Path $outTablet '02_visits_list.png'); $b.Dispose()
}

function Build-TabletDashboard {
  $b = Open-Shot 'Screenshot_1786258627.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 2560 $tabBarH $tabBg '9:41' 92
  Draw-IOSHomeIndicator $b $g 2560 1600 $tabBg $tabStrip

  # greeting card (horizontal gradient)
  Erase-Grad $b $g 2110 284 275 46 350
  Draw-TextRight $g 'Rana Khalil' '700' 40 $cWhite 2378 286 $false
  Erase-Grad $b $g 2424 272 40 40 350
  Draw-TextMid $g 'R' '700' 34 $cWhite 2443 274

  Erase-Grad $b $g 2270 370 235 42 350
  Draw-TextRight $g 'إنجاز اليوم  5/6 · 83٪' '600' 26 (RGB 226 232 240) 2497 372
  $barX = 70; $barY = 425; $barW = 2422; $barH = 13
  Fill-RoundRect $g $barX $barY $barW $barH 6 (RGB 255 255 255 60)
  $fill = [int]($barW * 0.83)
  Fill-RoundRect $g ($barX + $barW - $fill) $barY $fill $barH 6 (RGB 255 255 255 235)

  Erase-Grad $b $g 2424 472 28 40 455
  Draw-TextRight $g '6' '700' 28 $cWhite 2447 476 $false
  Erase-Grad $b $g 2150 472 66 40 455
  Draw-TextRight $g '5 س' '700' 28 $cWhite 2214 476

  # red "4 overdue" card -> neutral, zero
  $cx = 1926; $cy = 573; $cw = 602; $ch = 500
  $cardBg = $b.GetPixel(1000, 900)        # neutral "visits today" card
  $cardBd = $b.GetPixel(665, 900)
  Fill-Rect $g ($cx - 10) ($cy - 10) ($cw + 20) ($ch + 20) ($b.GetPixel(1910, 900))
  Fill-RoundRect $g $cx $cy $cw $ch 30 $cardBg
  $pen = New-Object System.Drawing.Pen $cardBd, 2
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 60
  $path.AddArc($cx, $cy, $d, $d, 180, 90); $path.AddArc($cx + $cw - $d, $cy, $d, $d, 270, 90)
  $path.AddArc($cx + $cw - $d, $cy + $ch - $d, $d, $d, 0, 90); $path.AddArc($cx, $cy + $ch - $d, $d, $d, 90, 90)
  $path.CloseFigure(); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
  Fill-RoundRect $g ($cx + 42) ($cy + 40) 56 56 18 (RGB 20 66 44)
  $cpen = New-Object System.Drawing.Pen $cGreen, 6
  $cpen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $cpen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $cpen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawLines($cpen, @(
      (New-Object System.Drawing.Point (($cx + 57), ($cy + 68))),
      (New-Object System.Drawing.Point (($cx + 67), ($cy + 79))),
      (New-Object System.Drawing.Point (($cx + 85), ($cy + 54)))))
  $cpen.Dispose()
  Copy-Patch $b $g 1198 621 40 34 ($cx + $cw - 100) ($cy + 48)
  Draw-TextRight $g '0' '700' 84 $cGreen ($cx + $cw - 38) ($cy + 172) $false
  Draw-TextRight $g 'متأخرة' '600' 26 $cLabel ($cx + $cw - 38) ($cy + 424)

  # keep "visits today" consistent (1 -> 6)
  Erase-Rect $b $g 1180 780 90 90 1000 900
  Draw-TextRight $g '6' '700' 84 (RGB 199 205 240) 1263 745 $false

  $g.Dispose()
  Save-Png $b (Join-Path $outTablet '03_dashboard.png'); $b.Dispose()
}

function Build-TabletAnalytics {
  $b = Open-Shot 'Screenshot_1786258649.png'
  $g = New-Graphics $b
  Draw-IOSStatusBar $b $g 2560 $tabBarH $tabBg '9:41' 92
  Draw-IOSHomeIndicator $b $g 2560 1600 $tabBg $tabStrip

  $l = 120, 400; $r = 1400, 400          # blank pixels inside each column's tile

  # KPI numbers (right edges 1239 / 2498; glyph tops 317 and 595)
  Erase-Rect $b $g 1120 290 130 84 $l[0] $l[1]
  Draw-TextRight $g '23' '700' 62 $cWhite 1239 283 $false
  Erase-Rect $b $g 2380 290 130 84 $r[0] $r[1]
  Draw-TextRight $g '96%' '700' 62 $cWhite 2498 283 $false
  Erase-Rect $b $g 1080 568 170 84 $l[0] $l[1]
  Draw-TextRight $g '00:42' '700' 56 $cWhite 1239 564 $false
  Erase-Rect $b $g 2390 568 120 84 $r[0] $r[1]
  Draw-TextRight $g '38' '700' 62 $cWhite 2498 561 $false

  # deltas
  Erase-Rect $b $g 500 230 90 36 $l[0] $l[1]
  Draw-TextRight $g '+15٪' '600' 24 $cGreen 581 232 $false
  Erase-Rect $b $g 1790 230 55 36 $r[0] $r[1]
  Draw-TextRight $g '+6٪' '600' 24 $cGreen 1837 232 $false
  Erase-Rect $b $g 500 508 90 36 $l[0] $l[1]
  Draw-TextRight $g '+8د' '600' 24 $cGreen 581 510 $false
  Erase-Rect $b $g 1760 504 120 40 $r[0] $r[1]
  Copy-Patch $b $g 1839 230 34 32 1841 508
  Draw-TextRight $g '+18٪' '600' 24 $cGreen 1837 510 $false

  # weekly chart
  $chartBg = $b.GetPixel(1280, 800)
  Fill-Rect $g 180 840 2200 275 $chartBg
  $days = @(6, 4, 0, 5, 3, 5, 0)
  $cxs = @(237, 585, 932, 1280, 1627, 1975, 2322)
  $barW = 28; $baseY = 1104; $maxH = 198; $maxV = 6
  for ($i = 0; $i -lt 7; $i++) {
    $v = $days[$i]
    $h = if ($v -eq 0) { 12 } else { [int]($maxH * $v / $maxV) }
    $x = $cxs[$i] - [int]($barW / 2)
    $y = $baseY - $h
    if ($i -eq 0) {
      $rect = New-Object System.Drawing.Rectangle $x, ($y - 1), $barW, ($h + 2)
      $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (RGB 63 145 217), (RGB 94 216 240), ([System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
      $path = New-Object System.Drawing.Drawing2D.GraphicsPath
      $d = $barW
      $path.AddArc($x, $y, $d, $d, 180, 90); $path.AddArc($x + $barW - $d, $y, $d, $d, 270, 90)
      $path.AddArc($x + $barW - $d, $baseY - $d, $d, $d, 0, 90); $path.AddArc($x, $baseY - $d, $d, $d, 90, 90)
      $path.CloseFigure(); $g.FillPath($br, $path); $br.Dispose(); $path.Dispose()
    } else {
      Fill-RoundRect $g $x $y $barW $h ([int]($barW / 2)) (RGB 27 32 48)
    }
    $col = if ($i -eq 0) { RGB 125 211 252 } else { if ($v -eq 0) { RGB 110 116 130 } else { RGB 226 232 240 } }
    Draw-TextMid $g "$v" '600' 26 $col $cxs[$i] 852
  }

  # employee row
  Erase-Rect $b $g 55 1320 180 44 400 1300
  Draw-TextRight $g '96٪ · 12' '600' 26 $cGreen 215 1322 $false
  $ebX = 61; $ebY = 1376; $ebW = 2358; $ebH = 12
  Fill-RoundRect $g $ebX $ebY $ebW $ebH 6 (RGB 30 34 44)
  Fill-RoundRect $g ($ebX + $ebW - [int]($ebW * 0.96)) $ebY ([int]($ebW * 0.96)) $ebH 6 $cGreenDim

  $g.Dispose()
  Save-Png $b (Join-Path $outTablet '04_analytics.png'); $b.Dispose()
}

Build-PhoneVisitDetail
Build-PhoneVisitsList
Build-PhoneDashboard
Build-PhoneAnalytics
Build-TabletVisitDetail
Build-TabletVisitsList
Build-TabletDashboard
Build-TabletAnalytics
Write-Host "phone  -> $outPhone"
Write-Host "tablet -> $outTablet"

