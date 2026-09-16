# Generates the two required Play Store graphics from the existing brand assets:
#   icon_512.png            512x512   — store icon (Play re-masks it itself, so ship it square)
#   feature_1024x500.png   1024x500   — feature graphic shown at the top of the listing
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File store/play/make_graphics.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out  = $PSScriptRoot

function Save-Png($bmp, $path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "wrote $path"
}

# ---------------------------------------------------------------- store icon
# The iOS 1024 icon is already square, opaque and full-bleed — exactly Play's
# spec — so it only needs downscaling.
$src = [System.Drawing.Image]::FromFile("$root\assets\icon\visit-logo-ios.png")
$icon = New-Object System.Drawing.Bitmap 512, 512
$g = [System.Drawing.Graphics]::FromImage($icon)
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode   = 'HighQuality'
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, 512, 512))
$g.Dispose(); $src.Dispose()
Save-Png $icon "$out\icon_512.png"
$icon.Dispose()

# ----------------------------------------------------------- feature graphic
$W = 1024; $H = 500
$fg = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($fg)
$g.SmoothingMode     = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode   = 'HighQuality'
$g.TextRenderingHint = 'ClearTypeGridFit'

# navy900 -> navy700 diagonal wash, matching the app's own background
$rect  = New-Object System.Drawing.Rectangle 0, 0, $W, $H
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.ColorTranslator]::FromHtml('#0B1240'),
    [System.Drawing.ColorTranslator]::FromHtml('#24327C'),
    25.0)
$g.FillRectangle($brush, $rect)
$brush.Dispose()

# soft cyan glow behind the mark so it doesn't sit flat on the navy
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(560, 30, 440, 440)
$pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$pgb.CenterColor    = [System.Drawing.Color]::FromArgb(70, 63, 191, 217)
$pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 63, 191, 217))
$g.FillPath($pgb, $glow)
$pgb.Dispose(); $glow.Dispose()

# brand mark on the right (RTL listing: artwork leads from the right)
$mark = [System.Drawing.Image]::FromFile("$root\assets\images\visit-logo-mark.png")
$g.DrawImage($mark, (New-Object System.Drawing.Rectangle 655, 90, 320, 320))
$mark.Dispose()

# Arabic copy on the left, right-aligned toward the mark
$rtl = New-Object System.Drawing.StringFormat
$rtl.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
$rtl.Alignment   = [System.Drawing.StringAlignment]::Near   # Near == right under RTL

$titleFont = New-Object System.Drawing.Font 'Segoe UI', 58, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$subFont   = New-Object System.Drawing.Font 'Segoe UI', 30, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)

$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$cyan  = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#5FD0E6'))

$textBox = New-Object System.Drawing.RectangleF 70, 178, 560, 90
$g.DrawString('الزيارات الميدانية', $titleFont, $white, $textBox, $rtl)
$subBox = New-Object System.Drawing.RectangleF 70, 268, 560, 60
$g.DrawString('زيارات العملاء موثّقة بالموقع الجغرافي', $subFont, $cyan, $subBox, $rtl)

$white.Dispose(); $cyan.Dispose(); $titleFont.Dispose(); $subFont.Dispose()
$g.Dispose()
Save-Png $fg "$out\feature_1024x500.png"
$fg.Dispose()
