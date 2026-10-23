param(
    [int]$Port = 7358,
    [string]$Root = (Join-Path $PSScriptRoot '..\build\web')
)
$ErrorActionPreference = 'Stop'
$dart = Join-Path $PSScriptRoot '..\.flutter-sdk\bin\cache\dart-sdk\bin\dart.exe'
$server = Join-Path $PSScriptRoot 'serve_web.dart'
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
& $dart $server $Port $resolvedRoot
if ($LASTEXITCODE -ne 0) { throw 'Local web server stopped.' }
