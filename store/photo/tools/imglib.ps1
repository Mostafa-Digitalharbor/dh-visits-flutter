# imglib.ps1 — GDI+ helpers for precise screenshot compositing (Cairo font).
Add-Type -AssemblyName System.Drawing

$Global:FontDir = "C:\Users\NINJAZ~1\AppData\Local\Temp\claude\e--mostafa-Companies-Digital-Harbor-Visits-location-gps\91b2d9bf-4d8e-4f62-9bc4-3b9f86930cbd\scratchpad\fonts"
$Global:PFCs = @{}

function Get-CairoFamily([string]$weight) {
  # weight: 400,500,600,700,900
  $map = @{ '400'='Cairo_400Regular'; '500'='Cairo_500Medium'; '600'='Cairo_600SemiBold'; '700'='Cairo_700Bold'; '800'='Cairo_800ExtraBold'; '900'='Cairo_900Black'; 'roboto'='Roboto_500Medium' }
  $file = Join-Path $Global:FontDir ($map[$weight] + '.ttf')
  if (-not $Global:PFCs.ContainsKey($weight)) {
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    $pfc.AddFontFile($file)
    $Global:PFCs[$weight] = $pfc
  }
  return $Global:PFCs[$weight].Families[0]
}

function New-CairoFont([string]$weight, [double]$px) {
  $fam = Get-CairoFamily $weight
  return New-Object System.Drawing.Font($fam, [single]$px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
}

function Open-Img([string]$path) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $ms = New-Object System.IO.MemoryStream (,$bytes)
  $img = [System.Drawing.Image]::FromStream($ms)
  $bmp = New-Object System.Drawing.Bitmap $img
  $img.Dispose(); $ms.Dispose()
  return $bmp
}

function New-Graphics($bmp) {
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  return $g
}

function RGB([int]$r,[int]$g,[int]$b,[int]$a=255){ return [System.Drawing.Color]::FromArgb($a,$r,$g,$b) }

function Sample($bmp, [int]$x, [int]$y) {
  $c = $bmp.GetPixel($x,$y)
  return ("({0},{1}) = #{2:X2}{3:X2}{4:X2}" -f $x,$y,$c.R,$c.G,$c.B)
}

function Fill-Rect($g, [int]$x,[int]$y,[int]$w,[int]$h, $color) {
  $br = New-Object System.Drawing.SolidBrush $color
  $g.FillRectangle($br, $x, $y, $w, $h)
  $br.Dispose()
}

# Copy a source rectangle onto a destination position (for cloning gradient/background patches)
function Copy-Patch($bmp, $g, [int]$sx,[int]$sy,[int]$w,[int]$h,[int]$dx,[int]$dy) {
  $sub = $bmp.Clone((New-Object System.Drawing.Rectangle $sx,$sy,$w,$h), $bmp.PixelFormat)
  $g.DrawImage($sub, $dx, $dy, $w, $h)
  $sub.Dispose()
}

# Draw left-aligned text at baseline-free top-left (x,y = top-left of text box)
function Draw-Text($g, [string]$text, [string]$weight, [double]$px, $color, [int]$x, [int]$y) {
  $font = New-CairoFont $weight $px
  $br = New-Object System.Drawing.SolidBrush $color
  $sf = New-Object System.Drawing.StringFormat
  $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
  # GDI+ adds internal padding; use GenericTypographic to reduce it
  $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
  $g.DrawString($text, $font, $br, [single]$x, [single]$y, $sf)
  $br.Dispose(); $font.Dispose()
}

# Measure text width/height in px for a weight/size
function Measure-Text($g, [string]$text, [string]$weight, [double]$px) {
  $font = New-CairoFont $weight $px
  $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
  $sz = $g.MeasureString($text, $font, [int]0, $sf)
  $font.Dispose()
  return $sz
}

function Fill-RoundRect($g,[int]$x,[int]$y,[int]$w,[int]$h,[int]$r,$color){
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2*$r
  $path.AddArc($x,$y,$d,$d,180,90)
  $path.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $path.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90)
  $path.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $path.CloseFigure()
  $br = New-Object System.Drawing.SolidBrush $color
  $g.FillPath($br,$path); $br.Dispose(); $path.Dispose()
}

function Fill-RoundRectGrad($g,[int]$x,[int]$y,[int]$w,[int]$h,[int]$r,$c1,$c2){
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2*$r
  $path.AddArc($x,$y,$d,$d,180,90)
  $path.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $path.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90)
  $path.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $path.CloseFigure()
  $rect = New-Object System.Drawing.Rectangle ($x-1),$y,($w+2),$h
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect,$c1,$c2,([System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
  $g.FillPath($br,$path); $br.Dispose(); $path.Dispose()
}

function Text-Width($g,[string]$text,[string]$weight,[double]$px){
  $font = New-CairoFont $weight $px
  $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
  $sz = $g.MeasureString($text,$font,(New-Object System.Drawing.PointF 0,0),$sf)
  $font.Dispose(); return $sz.Width
}

function Draw-TextCentered($g,[string]$text,[string]$weight,[double]$px,$color,[int]$cx,[int]$topY){
  $w = Text-Width $g $text $weight $px
  Draw-Text $g $text $weight $px $color ([int]($cx - $w/2)) $topY
}

function Peak-Color($bmp,[int]$x0,[int]$y0,[int]$x1,[int]$y1,[string]$mode){
  $best=-99999;$bc=$null
  for($y=$y0;$y -lt $y1;$y++){for($x=$x0;$x -lt $x1;$x++){
    $c=$bmp.GetPixel($x,$y);$r=$c.R;$g2=$c.G;$b=$c.B
    switch($mode){ 'green'{$s=$g2-($r+$b)/2} 'red'{$s=$r-($g2+$b)/2} default{$s=[Math]::Max($r,[Math]::Max($g2,$b))} }
    if($s -gt $best){$best=$s;$bc=$c}
  }}
  return $bc
}

function Save-Png($bmp, [string]$path) {
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}
