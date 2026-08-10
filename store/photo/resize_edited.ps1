# Re-frames the EDITED 1080x2400 screenshots into the canvas sizes Google Play
# and App Store Connect accept. Nothing is cropped or stretched: the shot is
# scaled to fit, centred, and the leftover bars are filled by smearing the
# image's own edge pixels.
#   powershell -ExecutionPolicy Bypass -File store/photo/resize_edited.ps1
Add-Type -AssemblyName System.Drawing

$src = Join-Path $PSScriptRoot 'edited'
$out = Join-Path $src 'out'

# Narrative order for the listing (login excluded — layout bug + low value).
$shots = [ordered]@{
    '1-visits-list'  = '02_visits_list.png'
    '2-visit-detail' = '01_visit_detail.png'
    '3-dashboard'    = '03_dashboard.png'
    '4-analytics'    = '04_analytics.png'
}

# Play only. The App Store sizes used to be generated here from the same Android
# captures — that is what got build 1.0 (4) rejected under guideline 2.3.10
# (Android status bar + gesture pill on App Store screenshots). iOS shots are now
# captured on a simulator: store/photo/tools/ios_shots.sh, then compose.ps1 -Platform ios.
# iPad sizes are gone too: TARGETED_DEVICE_FAMILY is "1" (iPhone only) as of 1.0.1 (5).
$targets = [ordered]@{
    'play-phone'     = @(1350, 2400)
    'play-tablet-7'  = @(1350, 2400)
    'play-tablet-10' = @(1600, 2560)
}

function New-Framed($srcPath, $dstPath, $TW, $TH) {
    $img = [System.Drawing.Image]::FromFile($srcPath)
    $SW = $img.Width; $SH = $img.Height
    $bmp = New-Object System.Drawing.Bitmap $TW, $TH
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode   = 'HighQuality'
    $g.SmoothingMode     = 'AntiAlias'
    $scale = [Math]::Min($TW / $SW, $TH / $SH)
    $dw = [int][Math]::Round($SW * $scale)
    $dh = [int][Math]::Round($SH * $scale)
    $dx = [int][Math]::Floor(($TW - $dw) / 2)
    $dy = [int][Math]::Floor(($TH - $dh) / 2)
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    if ($dx -gt 0) {
        $left  = New-Object System.Drawing.Rectangle 0, 0, ($dx + 1), $TH
        $right = New-Object System.Drawing.Rectangle ($dx + $dw - 1), 0, ($TW - $dx - $dw + 1), $TH
        $g.DrawImage($img, $left,  0, 0, 1, $SH, [System.Drawing.GraphicsUnit]::Pixel, $attr)
        $g.DrawImage($img, $right, ($SW - 1), 0, 1, $SH, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    }
    if ($dy -gt 0) {
        $top = New-Object System.Drawing.Rectangle 0, 0, $TW, ($dy + 1)
        $bot = New-Object System.Drawing.Rectangle 0, ($dy + $dh - 1), $TW, ($TH - $dy - $dh + 1)
        $g.DrawImage($img, $top, 0, 0, $SW, 1, [System.Drawing.GraphicsUnit]::Pixel, $attr)
        $g.DrawImage($img, $bot, 0, ($SH - 1), $SW, 1, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    }
    $dest = New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh
    $g.DrawImage($img, $dest, 0, 0, $SW, $SH, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    $attr.Dispose(); $g.Dispose(); $img.Dispose()
    $bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

foreach ($t in $targets.Keys) {
    $dir = Join-Path $out $t
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $TW, $TH = $targets[$t]
    foreach ($name in $shots.Keys) {
        $srcFile = Join-Path $src $shots[$name]
        if (-not (Test-Path $srcFile)) { Write-Warning "missing $($shots[$name])"; continue }
        New-Framed $srcFile (Join-Path $dir "$name.png") $TW $TH
    }
    Write-Host ("{0,-16} {1}x{2}  ({3} shots)" -f $t, $TW, $TH, $shots.Count)
}
Write-Host "`nout -> $out"
