param(
  [string]$Destination = '',
  [int]$MaxSize = 224
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$avatarSubpath = 'g' + [char]0x00F6 + 'rseller/pp'
$sourceFolder = Join-Path $workspace $avatarSubpath
if (-not $Destination) { $Destination = '.codex-build/android-league/' + $avatarSubpath }
$destinationFolder = [IO.Path]::GetFullPath((Join-Path $workspace $Destination))
if (-not $destinationFolder.StartsWith($workspace + [IO.Path]::DirectorySeparatorChar,
  [StringComparison]::OrdinalIgnoreCase) -or $destinationFolder -eq $sourceFolder) {
  throw 'Use a build folder within the workspace; original images are preserved.'
}
if ($MaxSize -lt 144) { throw 'Profile images must retain at least 144 pixels.' }
[IO.Directory]::CreateDirectory($destinationFolder) | Out-Null
$before = 0L
$after = 0L
foreach ($file in Get-ChildItem -LiteralPath $sourceFolder -File -Filter '*.png') {
  $image = [Drawing.Image]::FromFile($file.FullName)
  try {
    $scale = [Math]::Min(1.0, $MaxSize / [double][Math]::Max($image.Width, $image.Height))
    $width = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
    $height = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    try {
      $graphics = [Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes = [Drawing.Imaging.ImageAttributes]::new()
        try {
          $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
          $graphics.DrawImage($image, [Drawing.Rectangle]::new(0, 0, $width, $height),
            0, 0, $image.Width, $image.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
        } finally { $attributes.Dispose() }
      } finally { $graphics.Dispose() }
      $target = Join-Path $destinationFolder $file.Name
      $bitmap.Save($target, [Drawing.Imaging.ImageFormat]::Png)
      $before += $file.Length
      $after += (Get-Item -LiteralPath $target).Length
    } finally { $bitmap.Dispose() }
  } finally { $image.Dispose() }
}
[pscustomobject]@{ OriginalBytes = $before; OptimizedBytes = $after; MaxSize = $MaxSize }
