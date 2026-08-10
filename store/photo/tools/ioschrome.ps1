# ioschrome.ps1 — draws iOS system chrome (status bar + home indicator) over a
# capture taken on another platform, and small text/patch helpers used by the
# content clean-up in clean_shots.ps1.
#
# Why: App Store guideline 2.3.10 rejected build 1.0 (4) because the uploaded
# screenshots carried an Android status bar ("3G", Android signal triangle and
# battery, punch-hole camera) and the Android gesture pill. Everything drawn here
# replaces that chrome with the iOS equivalent: 9:41 clock, cellular bars, wifi,
# battery, home indicator.

. (Join-Path $PSScriptRoot 'imglib.ps1')

# Solid-fill a rect with the colour sampled at ($sx,$sy) — the usual way to erase
# a label before drawing its replacement.
function Erase-Rect($bmp, $g, [int]$x, [int]$y, [int]$w, [int]$h, [int]$sx, [int]$sy) {
  Fill-Rect $g $x $y $w $h ($bmp.GetPixel($sx, $sy))
}

# Erase a rect sitting on a horizontal gradient (the greeting card) by refilling
# it with a gradient between the pixels just outside its left and right edges.
function Erase-Grad($bmp, $g, [int]$x, [int]$y, [int]$w, [int]$h, [int]$sampleY = -1) {
  # Sample on a row with no glyphs on it, otherwise the "gradient" picks up text
  # pixels and leaves a bright block where the label used to be.
  $sy = if ($sampleY -ge 0) { $sampleY } else { $y + [int]($h / 2) }
  $c1 = $bmp.GetPixel([Math]::Max(0, $x - 2), $sy)
  $c2 = $bmp.GetPixel([Math]::Min($bmp.Width - 1, $x + $w + 2), $sy)
  $rect = New-Object System.Drawing.Rectangle ($x - 1), $y, ($w + 2), $h
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, ([System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
  $g.FillRectangle($br, $x, $y, $w, $h)
  $br.Dispose()
}

# Right-aligned text: ($rx,$y) is the top-RIGHT corner. Arabic/RTL strings are
# laid out right-to-left so they read correctly.
function Draw-TextRight($g, [string]$text, [string]$weight, [double]$px, $color, [int]$rx, [int]$y, [bool]$rtl = $true) {
  $font = New-CairoFont $weight $px
  $br = New-Object System.Drawing.SolidBrush $color
  $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  if ($rtl) { $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft }
  # Lay the text out in a box just big enough for it, anchored so its right edge
  # lands on $rx. A huge box with Far alignment drops stray glyphs at the far
  # side under some GDI+ versions, so the box is measured, not oversized.
  $sz = $g.MeasureString($text, $font, [int]0, $sf)
  $w = [single]($sz.Width + $px * 0.6)
  $rect = New-Object System.Drawing.RectangleF ([single]($rx - $w)), ([single]$y), $w, ([single]($px * 2.4))
  $g.DrawString($text, $font, $br, $rect, $sf)
  $br.Dispose(); $font.Dispose()
}

# Centred text with optional RTL layout.
function Draw-TextMid($g, [string]$text, [string]$weight, [double]$px, $color, [int]$cx, [int]$y, [bool]$rtl = $false) {
  $font = New-CairoFont $weight $px
  $br = New-Object System.Drawing.SolidBrush $color
  $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  if ($rtl) { $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft }
  $rect = New-Object System.Drawing.RectangleF ([single]($cx - 1500)), ([single]$y), 3000, ([single]($px * 2.2))
  $g.DrawString($text, $font, $br, $rect, $sf)
  $br.Dispose(); $font.Dispose()
}

# ── iOS status bar ────────────────────────────────────────────────────────────
# Clock left, then (right to left) battery, wifi, cellular — the layout iOS uses
# when the device language is LTR, which is our case: the device runs English and
# the app itself is switched to Arabic in-app.
function Draw-IOSStatusBar($bmp, $g, [int]$W, [int]$barH, $bg, [string]$time = '9:41', [int]$clockCx = -1) {
  Fill-Rect $g 0 0 $W $barH $bg
  $white = RGB 255 255 255

  # Clock: centred in the left "ear" on a notched phone, but hard against the
  # left margin on iPad, which has no ear to centre in.
  $clockPx = [int]($barH * 0.36)
  $cx = if ($clockCx -ge 0) { $clockCx } else { [int]($W * 0.135) }
  Draw-TextMid $g $time '700' $clockPx $white $cx ([int]($barH * 0.30))

  $unit = $barH * 0.30                    # nominal glyph height
  $right = [int]($W - $barH * 0.44)       # right margin
  $cy = [int]($barH * 0.50)               # vertical centre of the cluster

  # battery: rounded outline + tip + full fill
  $bH = [int]($unit * 0.94)
  $bW = [int]($bH * 2.08)
  $bx = $right - $bW
  $by = $cy - [int]($bH / 2)
  $pen = New-Object System.Drawing.Pen ((RGB 255 255 255 150)), ([single]([Math]::Max(2, $bH * 0.10)))
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $r = [int]($bH * 0.32); $d = 2 * $r
  $path.AddArc($bx, $by, $d, $d, 180, 90)
  $path.AddArc($bx + $bW - $d, $by, $d, $d, 270, 90)
  $path.AddArc($bx + $bW - $d, $by + $bH - $d, $d, $d, 0, 90)
  $path.AddArc($bx, $by + $bH - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
  $tipH = [int]($bH * 0.38)
  Fill-RoundRect $g ($bx + $bW + [int]($bH * 0.12)) ($cy - [int]($tipH / 2)) ([int]($bH * 0.16)) $tipH ([int]($bH * 0.08)) (RGB 255 255 255 150)
  $pad = [Math]::Max(3, [int]($bH * 0.20))
  Fill-RoundRect $g ($bx + $pad) ($by + $pad) ($bW - 2 * $pad) ($bH - 2 * $pad) ([int]($bH * 0.16)) $white

  # wifi: three arcs + dot
  $wR = [int]($unit * 0.82)
  $wx = $bx - [int]($unit * 0.62) - $wR
  $wy = $cy + [int]($unit * 0.42)
  $wpen = New-Object System.Drawing.Pen $white, ([single]([Math]::Max(2, $unit * 0.15)))
  $wpen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $wpen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  foreach ($f in @(1.0, 0.62)) {
    $rr = [int]($wR * $f)
    $g.DrawArc($wpen, ($wx - $rr), ($wy - $rr), (2 * $rr), (2 * $rr), 210, 120)
  }
  $wpen.Dispose()
  $dot = [int]($unit * 0.22)
  $br = New-Object System.Drawing.SolidBrush $white
  $g.FillEllipse($br, ($wx - [int]($dot / 2)), ($wy - [int]($dot * 0.9)), $dot, $dot)
  $br.Dispose()

  # cellular: four ascending rounded bars, all lit
  $barW = [int]($unit * 0.24)
  $gap = [int]($unit * 0.15)
  $sxRight = $wx - $wR - [int]($unit * 0.70)
  for ($i = 3; $i -ge 0; $i--) {
    $h = [int]($unit * (0.34 + 0.22 * $i))
    $x = $sxRight - (3 - $i) * ($barW + $gap) - $barW
    Fill-RoundRect $g $x ($cy + [int]($unit * 0.50) - $h) $barW $h ([int]($barW * 0.35)) $white
  }
}

# ── iOS home indicator ────────────────────────────────────────────────────────
# Erases whatever the source platform drew in the gesture area and draws the iOS
# bar at its real proportions (34.5% of the screen width, ~5pt tall).
function Draw-IOSHomeIndicator($bmp, $g, [int]$W, [int]$H, $bg, [int]$stripH) {
  Fill-Rect $g 0 ($H - $stripH) $W $stripH $bg
  $iw = [int]($W * 0.345)
  $ih = [Math]::Max(4, [int]($W * 0.0055))
  $iy = $H - [int]($W * 0.0075) - $ih - [int]($stripH * 0.18)
  Fill-RoundRect $g ([int](($W - $iw) / 2)) $iy $iw $ih ([int]($ih / 2)) (RGB 255 255 255 235)
}
