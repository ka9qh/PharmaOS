Add-Type -AssemblyName System.Drawing

$srcPath = "C:\pharmasy\PharmaOS\mobile\pharmaos_owner_app\assets\images\owner_avatar.png"
$src = [System.Drawing.Image]::FromFile($srcPath)

$sizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($entry in $sizes.GetEnumerator()) {
    $folder = $entry.Key
    $dim = $entry.Value
    $destDir = "C:\pharmasy\PharmaOS\mobile\pharmaos_owner_app\android\app\src\main\res\$folder"
    if (-not (Test-Path $destDir)) { 
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $destPath = Join-Path $destDir "ic_launcher.png"
    
    $bmp = New-Object System.Drawing.Bitmap($dim, $dim)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $dim, $dim)
    $g.Dispose()
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Generated launcher icon: $destPath (Size: ${dim}x${dim})"
}

$src.Dispose()
Write-Host "All launcher icons generated successfully!"
