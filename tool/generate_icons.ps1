# generate_icons.ps1 — derives every icon variant from the master brand logo.
#
# Master source: assets/icon/visit-logo-master.png (full-bleed art as delivered,
# navy rounded-square plate on a white page margin).
#
# Outputs
#   assets/images/visit-logo.png            in-app logo: plate cropped square,
#                                           page margin knocked out to alpha.
#   assets/images/visit-logo-mark.png       in-app glyph WITHOUT the navy plate,
#                                           for placing on light/branded
#                                           surfaces (and for tinting flat via
#                                           Image.asset's `color:`).
#   assets/icon/visit-logo-foreground.png   adaptive-icon foreground: glyph only
#                                           on transparent, inset to the 66/108
#                                           safe zone.
#   assets/icon/visit-logo-ios.png          iOS icon: full-bleed navy, no alpha
#                                           (iOS applies its own squircle mask).
#   android/app/src/main/res/drawable-*/ic_notification.png
#                                           status-bar icon: WHITE SILHOUETTE on
#                                           transparent. Android discards colour
#                                           and keeps only the alpha channel, so
#                                           anything else renders as a blob.
#
# Run after replacing the master, then regenerate the launcher icons:
#   pwsh tool/generate_icons.ps1
#   dart run flutter_launcher_icons
#   dart run flutter_native_splash:create

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$master = Join-Path $root 'assets\icon\visit-logo-master.png'
if (-not (Test-Path $master)) { throw "Master logo not found: $master" }

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class IconGen
{
    // The plate colour the artwork sits on. Antialiased art pixels are mixed
    // with this, so it doubles as the "is this background?" reference.
    public const int NavyR = 9, NavyG = 23, NavyB = 49;

    static byte[] Read(Bitmap bmp, out int stride)
    {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = data.Stride;
        var buf = new byte[stride * bmp.Height];
        Marshal.Copy(data.Scan0, buf, 0, buf.Length);
        bmp.UnlockBits(data);
        return buf;
    }

    static Bitmap Write(byte[] buf, int w, int h, int stride)
    {
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(buf, 0, data.Scan0, buf.Length);
        bmp.UnlockBits(data);
        return bmp;
    }

    /// <summary>Tight bounding box of everything darker than the page margin.</summary>
    public static Rectangle PlateBounds(Bitmap src)
    {
        int stride; var buf = Read(src, out stride);
        int minX = src.Width, maxX = -1, minY = src.Height, maxY = -1;
        for (int y = 0; y < src.Height; y++)
            for (int x = 0; x < src.Width; x++)
            {
                int i = y * stride + x * 4;
                double lum = 0.299 * buf[i + 2] + 0.587 * buf[i + 1] + 0.114 * buf[i];
                if (lum < 110)
                {
                    if (x < minX) minX = x; if (x > maxX) maxX = x;
                    if (y < minY) minY = y; if (y > maxY) maxY = y;
                }
            }
        return Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
    }

    public static Bitmap Crop(Bitmap src, Rectangle r)
    {
        var outBmp = new Bitmap(r.Width, r.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(outBmp))
        {
            g.CompositingMode = CompositingMode.SourceCopy;
            g.DrawImage(src, new Rectangle(0, 0, r.Width, r.Height), r, GraphicsUnit.Pixel);
        }
        return outBmp;
    }

    /// <summary>
    /// Knocks the white page margin out to alpha by flooding inward from the
    /// four corners, so only the rounded plate survives. A flood (rather than a
    /// global "white is transparent" test) protects the white person glyph in
    /// the middle of the artwork, which is the same colour as the margin.
    /// </summary>
    public static Bitmap KnockOutMargin(Bitmap src)
    {
        int w = src.Width, h = src.Height, stride;
        var buf = Read(src, out stride);
        var seen = new bool[w * h];
        var stack = new System.Collections.Generic.Stack<int>();
        Action<int, int> push = (x, y) =>
        {
            if (x < 0 || y < 0 || x >= w || y >= h) return;
            if (seen[y * w + x]) return;
            int i = y * stride + x * 4;
            double lum = 0.299 * buf[i + 2] + 0.587 * buf[i + 1] + 0.114 * buf[i];
            if (lum < 150) return;              // hit the plate — stop flooding
            seen[y * w + x] = true;
            stack.Push(y * w + x);
        };
        push(0, 0); push(w - 1, 0); push(0, h - 1); push(w - 1, h - 1);
        while (stack.Count > 0)
        {
            int p = stack.Pop(); int x = p % w, y = p / w;
            push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1);
            // Feather the plate edge: the brighter the margin pixel, the more
            // transparent, so the antialiased rim does not leave a white halo.
            int i = y * stride + x * 4;
            double lum = 0.299 * buf[i + 2] + 0.587 * buf[i + 1] + 0.114 * buf[i];
            double a = (250.0 - lum) / 100.0;   // lum 250+ -> 0, lum 150 -> 1
            buf[i + 3] = (byte)Math.Max(0, Math.Min(255, a * 255));
        }
        return Write(buf, w, h, stride);
    }

    /// <summary>
    /// Alpha := how far the pixel is from the navy plate. RGB is left alone, so
    /// the result still composites seamlessly onto navy while being cut out
    /// everywhere the plate showed through.
    /// </summary>
    public static Bitmap PlateToAlpha(Bitmap src)
    {
        int w = src.Width, h = src.Height, stride;
        var buf = Read(src, out stride);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                double dr = buf[i + 2] - NavyR, dg = buf[i + 1] - NavyG, db = buf[i] - NavyB;
                double dist = Math.Sqrt(dr * dr + dg * dg + db * db);
                double a = (dist - 18.0) / 42.0;       // <18 plate, >60 solid art
                buf[i + 3] = (byte)Math.Max(0, Math.Min(255, a * 255));
            }
        return Write(buf, w, h, stride);
    }

    /// <summary>
    /// Flattens to a white silhouette: every pixel becomes pure white and only
    /// the alpha carries the shape. This is the only form Android accepts for a
    /// notification small icon.
    /// </summary>
    public static Bitmap Silhouette(Bitmap src)
    {
        int w = src.Width, h = src.Height, stride;
        var buf = Read(src, out stride);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int i = y * stride + x * 4;
                double lum = 0.299 * buf[i + 2] + 0.587 * buf[i + 1] + 0.114 * buf[i];
                double a = (lum - 28.0) / 82.0;        // navy(~22) -> 0, art -> 1
                a = Math.Max(0, Math.Min(1, a));
                // Keep RGB white everywhere, including in transparent regions,
                // so downscaling interpolates white-to-white and never smears a
                // dark fringe into the glyph edge.
                buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255;
                buf[i + 3] = (byte)(a * 255);
            }
        return Write(buf, w, h, stride);
    }

    /// <summary>Resizes onto a transparent canvas of <paramref name="size"/>, inset by <paramref name="scale"/>.</summary>
    public static Bitmap Fit(Bitmap src, int size, double scale, Color background)
    {
        var outBmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(outBmp))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.CompositingQuality = CompositingQuality.HighQuality;
            if (background.A > 0) g.Clear(background);
            int inner = (int)Math.Round(size * scale);
            int off = (size - inner) / 2;
            // Clamp the source edges so bicubic sampling cannot pull the
            // surrounding transparent pixels into the outermost ring.
            using (var attr = new ImageAttributes())
            {
                attr.SetWrapMode(WrapMode.TileFlipXY);
                g.DrawImage(src, new Rectangle(off, off, inner, inner),
                    0, 0, src.Width, src.Height, GraphicsUnit.Pixel, attr);
            }
        }
        return outBmp;
    }

    /// <summary>Drops the alpha channel by compositing onto a solid colour (iOS forbids alpha).</summary>
    public static Bitmap Flatten(Bitmap src, Color background)
    {
        var outBmp = new Bitmap(src.Width, src.Height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(outBmp))
        {
            g.Clear(background);
            g.DrawImage(src, 0, 0, src.Width, src.Height);
        }
        return outBmp;
    }
}
'@ -ReferencedAssemblies System.Drawing, System.Drawing.Primitives

function Save([System.Drawing.Bitmap]$bmp, [string]$path) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "  wrote $($path.Substring($root.Length + 1))  ($($bmp.Width)x$($bmp.Height))"
}

$navy = [System.Drawing.Color]::FromArgb(255, [IconGen]::NavyR, [IconGen]::NavyG, [IconGen]::NavyB)
$src = New-Object System.Drawing.Bitmap($master)

# ── 1. Square-crop the plate out of the page ──────────────────────────────────
$b = [IconGen]::PlateBounds($src)
$side = [Math]::Max($b.Width, $b.Height)
$cx = $b.X + $b.Width / 2; $cy = $b.Y + $b.Height / 2
$x = [int][Math]::Max(0, [Math]::Min($src.Width - $side, $cx - $side / 2))
$y = [int][Math]::Max(0, [Math]::Min($src.Height - $side, $cy - $side / 2))
$square = [IconGen]::Crop($src, (New-Object System.Drawing.Rectangle($x, $y, $side, $side)))
Write-Host "Plate cropped to ${side}x${side} at ($x,$y)"

# ── 2. In-app logo — plate with the page margin knocked out ───────────────────
$plate = [IconGen]::KnockOutMargin($square)
$appLogo = [IconGen]::Fit($plate, 512, 1.0, [System.Drawing.Color]::Transparent)
Save $appLogo (Join-Path $root 'assets\images\visit-logo.png')

# ── 3. Adaptive foreground — glyph only, inset to the 66/108 safe zone ────────
# The plate is dropped here because the launcher supplies its own masked
# background; keeping it would show a rounded square inside a circle.
$glyph = [IconGen]::PlateToAlpha([IconGen]::Crop($square, (New-Object System.Drawing.Rectangle(
    [int]($side * 0.10), [int]($side * 0.10), [int]($side * 0.80), [int]($side * 0.80)))))
# 0.84, not 1.0: the generated mipmap-anydpi-v26/ic_launcher.xml draws this
# drawable with a further 16% inset, so the glyph lands at 0.84 x 0.68 = 0.57 of
# the 108dp canvas — filling the 66/108 (0.61) safe zone without touching its
# edge, whatever mask the launcher applies.
Save ([IconGen]::Fit($glyph, 1024, 0.84, [System.Drawing.Color]::Transparent)) `
     (Join-Path $root 'assets\icon\visit-logo-foreground.png')

# ── 3b. In-app glyph — same cut-out, bundled at UI resolution ─────────────────
Save ([IconGen]::Fit($glyph, 512, 1.0, [System.Drawing.Color]::Transparent)) `
     (Join-Path $root 'assets\images\visit-logo-mark.png')

# ── 4. iOS icon — full-bleed navy, alpha flattened away ───────────────────────
Save ([IconGen]::Flatten([IconGen]::Fit($glyph, 1024, 0.78, $navy), $navy)) `
     (Join-Path $root 'assets\icon\visit-logo-ios.png')

# ── 5. Android notification small icons — white silhouette, 24dp per density ──
$sil = [IconGen]::Silhouette([IconGen]::Crop($square, (New-Object System.Drawing.Rectangle(
    [int]($side * 0.10), [int]($side * 0.10), [int]($side * 0.80), [int]($side * 0.80)))))
$densities = @{ 'mdpi' = 24; 'hdpi' = 36; 'xhdpi' = 48; 'xxhdpi' = 72; 'xxxhdpi' = 96 }
foreach ($d in $densities.GetEnumerator()) {
    # 0.85 keeps the glyph inside the 24dp box's optical padding, matching the
    # inset the system icons next to it use.
    Save ([IconGen]::Fit($sil, $d.Value, 0.85, [System.Drawing.Color]::Transparent)) `
         (Join-Path $root "android\app\src\main\res\drawable-$($d.Key)\ic_notification.png")
}

$src.Dispose()
Write-Host "`nDone. Next: dart run flutter_launcher_icons && dart run flutter_native_splash:create"
