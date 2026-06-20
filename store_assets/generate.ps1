# Generates Google Play store graphics from the app logo.
# Re-run after replacing assets/images/logo.jpg with a higher-res version.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $root 'store_assets'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$logoPath = Join-Path $root 'assets\images\logo.jpg'

$navy = [System.Drawing.Color]::FromArgb(30, 42, 110)   # #1E2A6E brand navy
$cyan = [System.Drawing.Color]::FromArgb(63, 191, 217)  # #3FBFD9 brand cyan

function New-HQGraphics([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint  = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return $g
}

$logo = [System.Drawing.Image]::FromFile($logoPath)

# ---------- App icon: 512 x 512 (white background, centered logo) ----------
$icon = New-Object System.Drawing.Bitmap 512, 512
$gi = New-HQGraphics $icon
$gi.Clear([System.Drawing.Color]::White)
$isz = 410
$ip  = [int](((512 - $isz) / 2))
$gi.DrawImage($logo, $ip, $ip, $isz, $isz)
$gi.Dispose()
$icon.Save((Join-Path $out 'app_icon_512.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$icon.Dispose()

# ---------- Feature graphic: 1024 x 500 (brand gradient + logo + title) ----------
$fg = New-Object System.Drawing.Bitmap 1024, 500
$gf = New-HQGraphics $fg
$rect = New-Object System.Drawing.Rectangle 0, 0, 1024, 500
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $navy, $cyan, 35.0)
$gf.FillRectangle($grad, $rect)

# White circle holding the logo on the left third
$circD = 300
$circX = 110
$circY = [int]((500 - $circD) / 2)
$gf.FillEllipse([System.Drawing.Brushes]::White, $circX, $circY, $circD, $circD)
$pad = 46
$gf.DrawImage($logo, $circX + $pad, $circY + $pad, $circD - 2 * $pad, $circD - 2 * $pad)

# Title + tagline
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$soft  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, 255, 255, 255))
$titleFont = New-Object System.Drawing.Font('Segoe UI', 78, [System.Drawing.FontStyle]::Bold)
$subFont   = New-Object System.Drawing.Font('Segoe UI', 27, [System.Drawing.FontStyle]::Regular)
$tx = $circX + $circD + 70
$gf.DrawString('Visits', $titleFont, $white, $tx, 168)
$gf.DrawString('Field visits & live team tracking', $subFont, $soft, ($tx + 6), 296)
$gf.Dispose()
$fg.Save((Join-Path $out 'feature_graphic_1024x500.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$fg.Dispose()

$logo.Dispose()
Write-Output "Done. Files in: $out"
Get-ChildItem $out -Filter *.png | ForEach-Object {
    $im = [System.Drawing.Image]::FromFile($_.FullName)
    Write-Output ("{0}  ->  {1}x{2}" -f $_.Name, $im.Width, $im.Height)
    $im.Dispose()
}
