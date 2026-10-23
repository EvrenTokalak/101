$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $projectRoot 'build/web'
$destination = Join-Path $projectRoot 'sites/okey-cloud/dist'
if (-not (Test-Path -LiteralPath (Join-Path $source 'main.dart.js'))) {
  throw 'Build the current Flutter web release first.'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Get-ChildItem -LiteralPath $source -Force |
  Where-Object { $_.Name -ne '.last_build_id' } |
  ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force }

# Flutter deliberately double-encodes requests for these once-encoded names.
# Preserve every asset key and optimize only the independent hosting copies.
$encodedImages = 'assets/g%C3%B6rseller'
& (Join-Path $projectRoot 'tool/optimize_profile_assets.ps1') `
  -Destination ('sites/okey-cloud/dist/' + $encodedImages + '/pp') -MaxSize 224 | Out-Null
$encoder = Join-Path $projectRoot '.tool-home/libwebp-1.6.0-windows-x64/bin/cwebp.exe'
foreach ($relative in @('assets/images/ui', $encodedImages)) {
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $destination $relative) -Recurse -File) {
    if (($file.Extension -ne '.png' -and $file.Extension) -or $file.Length -lt 150000) { continue }
    $encoded = $file.FullName + '.hosting.webp'
    & $encoder -quiet -q 92 -alpha_q 100 -m 4 -sharp_yuv -mt $file.FullName -o $encoded
    if ($LASTEXITCODE -ne 0) { throw ('Hosting image compression failed: ' + $file.Name) }
    if ((Get-Item -LiteralPath $encoded).Length -lt $file.Length) {
      Copy-Item -LiteralPath $encoded -Destination $file.FullName -Force
    }
    Remove-Item -LiteralPath $encoded
  }
}
$htmlPath = Join-Path $destination 'index.html'
$html = [IO.File]::ReadAllText($htmlPath)
$html = $html.Replace('<html>', '<html lang="tr">')
$html = $html.Replace('<title>flutter_application_1</title>', '<title>101 Okey</title>')
$description = '101 Okey oyununu taray' + [char]0x0131 + 'c' + [char]0x0131 + 'nda oyna.'
$html = $html.Replace('content="A new Flutter project."', ('content="' + $description + '"'))
$html = $html.Replace('content="flutter_application_1"', 'content="101 Okey"')
[IO.File]::WriteAllText($htmlPath, $html, [Text.UTF8Encoding]::new($false))
$manifestPath = Join-Path $destination 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest.name = '101 Okey'
$manifest.short_name = '101 Okey'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
$bootstrapPath = Join-Path $destination 'flutter_bootstrap.js'
$bootstrap = [IO.File]::ReadAllText($bootstrapPath)
$bootstrap = $bootstrap.Replace('_flutter.loader.load({', '_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"},')
if (-not $bootstrap.Contains('canvasKitBaseUrl:"canvaskit/"')) { throw 'The bundled CanvasKit loader was not configured.' }
[IO.File]::WriteAllText($bootstrapPath, $bootstrap, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $destination '_headers'), "/*`n  Cache-Control: public, max-age=0, must-revalidate`n", [Text.UTF8Encoding]::new($false))
$files = @(Get-ChildItem -LiteralPath $destination -Recurse -File)
$tooLarge = @($files | Where-Object Length -gt 26214400)
if ($tooLarge.Count) { throw 'A hosting asset exceeds 25 MiB.' }
[PSCustomObject]@{ Directory = $destination; Files = $files.Count; Bytes = ($files | Measure-Object Length -Sum).Sum }
