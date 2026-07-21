# Re-frames the raw 1080x2400 (20:9) captures into the canvas sizes Google Play
# and App Store Connect accept. Nothing is cropped or stretched: the shot is
# scaled to fit, centred, and the leftover bars are filled by smearing the
# image's own edge pixels — so the login screen's gradient continues into the
# bar instead of hitting a black wall.
#
#   powershell -ExecutionPolicy Bypass -File store/photo/resize.ps1
Add-Type -AssemblyName System.Drawing

$src = $PSScriptRoot
$out = Join-Path $src 'out'

# Narrative order for the listing. Login goes last — see AUDIT.md on why it
# probably shouldn't ship at all.
$shots = [ordered]@{
    '1-visits-list'   = 'Screenshot_1784471051.png'
    '2-visit-detail'  = 'Screenshot_1784471044.png'
    '3-dashboard'     = 'Screenshot_1784471657.png'
    '4-analytics'     = 'Screenshot_1784471664.png'
    '5-sign-in'       = 'Screenshot_1784471876.png'
}

# Play accepts a 9:16 canvas for every slot; the 10" tablet slot additionally
# requires >=1080px on BOTH sides, which 1350x2400 already satisfies, but a
# roomier canvas reads better there. Apple demands these exact pixel sizes.
$targets = [ordered]@{
    'play-phone'    = @(1350, 2400)
    'play-tablet-7' = @(1350, 2400)
    'play-tablet-10'= @(1600, 2560)
    'ios-6.9'       = @(1290, 2796)   # iPhone 16/15 Pro Max — required
    'ios-6.5'       = @(1242, 2688)   # older Max — optional fallback
    'ipad-13'       = @(2064, 2752)   # required while TARGETED_DEVICE_FAMILY includes 2
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

    # TileFlipXY stops GDI+ from sampling transparent pixels past the edge,
    # which otherwise leaves a hairline seam where the bar meets the shot.
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
