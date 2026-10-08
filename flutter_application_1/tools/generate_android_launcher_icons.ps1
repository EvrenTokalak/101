param(
    [Parameter(Mandatory = $true)]
    [string]$LogoPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$resourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\android\app\src\main\res'))
$sourceImage = [System.Drawing.Image]::FromFile([System.IO.Path]::GetFullPath($LogoPath))

function Export-LauncherIcon([string]$Destination, [int]$Size, [double]$ContentFraction, [bool]$Transparent) {
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        if ($Transparent) {
            $graphics.Clear([System.Drawing.Color]::Transparent)
        } else {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#07382C'))
        }
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = $Size * $ContentFraction / [Math]::Max($sourceImage.Width, $sourceImage.Height)
        $width = [single]($sourceImage.Width * $scale)
        $height = [single]($sourceImage.Height * $scale)
        $graphics.DrawImage($sourceImage, [single](($Size - $width) / 2), [single](($Size - $height) / 2), $width, $height)
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($Destination)) | Out-Null
        $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($density in $densities.GetEnumerator()) {
        Export-LauncherIcon (Join-Path $resourceRoot "mipmap-$($density.Key)\ic_launcher.png") $density.Value 0.92 $false
    }
    # Android adaptive masks reserve the central 66 dp of the 108 dp layer.
    # Keep the complete existing logo inside that area rather than cropping it.
    Export-LauncherIcon (Join-Path $resourceRoot 'drawable-xxxhdpi\ic_launcher_foreground.png') 432 (64.0 / 108.0) $true
} finally {
    $sourceImage.Dispose()
}
