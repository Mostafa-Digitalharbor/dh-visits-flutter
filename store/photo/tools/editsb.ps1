. "C:\Users\NINJAZ~1\AppData\Local\Temp\claude\e--mostafa-Companies-Digital-Harbor-Visits-location-gps\91b2d9bf-4d8e-4f62-9bc4-3b9f86930cbd\scratchpad\edit\imglib.ps1"
$ed="e:\mostafa\Companies\Digital_Harbor\Visits\location_gps\store\photo\edited"
$out="C:\Users\NINJAZ~1\AppData\Local\Temp\claude\e--mostafa-Companies-Digital-Harbor-Visits-location-gps\91b2d9bf-4d8e-4f62-9bc4-3b9f86930cbd\scratchpad\edit"
$files="01_visit_detail.png","02_visits_list.png","03_dashboard.png","04_analytics.png"

foreach($f in $files){
  $S=Open-Img (Join-Path $ed $f)
  $g=New-Graphics $S
  $bg=$S.GetPixel(32,70)                       # status-bar bg for this shot
  # clock -> 10:10
  Fill-Rect $g 44 46 96 46 $bg
  Draw-Text $g "10:10" "roboto" 34 (RGB 255 255 255) 50 51
  # signal triangle -> full (solid white right-triangle)
  $wb=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
  $pts=@((New-Object System.Drawing.PointF 918,84),(New-Object System.Drawing.PointF 967,84),(New-Object System.Drawing.PointF 967,51))
  $g.FillPolygon($wb,$pts); $wb.Dispose()
  $g.Dispose()
  Save-Png $S (Join-Path $ed $f)              # overwrite edited source
  $S.Dispose()
}
# verification crop of shot 1
$V=Open-Img (Join-Path $ed "01_visit_detail.png")
$c=$V.Clone((New-Object System.Drawing.Rectangle 0,25,1080,80),$V.PixelFormat)
$z=New-Object System.Drawing.Bitmap 1080,160
$gg=[System.Drawing.Graphics]::FromImage($z); $gg.InterpolationMode='NearestNeighbor'; $gg.DrawImage($c,0,0,1080,160); $gg.Dispose()
$z.Save((Join-Path $out "sb_check.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$V.Dispose();$c.Dispose();$z.Dispose()
Write-Host "status bars updated (10:10 + full signal) on all 4"
