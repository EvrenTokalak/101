param(
  [int]$BuildNumber = 0,
  [string]$OutputFile = 'releases/okey20.apk',
  [string]$GradleCacheRoot = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputFile))
if (-not $outputPath.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'APK output must stay inside the project.'
}
if ($BuildNumber -le 0) {
  $BuildNumber = 2021
  if (Test-Path -LiteralPath $outputPath) {
    $badging = & (Join-Path $projectRoot '.android-sdk/build-tools/36.0.0/aapt.exe') dump badging $outputPath
    if ($LASTEXITCODE -ne 0) { throw 'Existing APK metadata could not be read.' }
    $versionMatch = [regex]::Match(($badging -join "`n"), "versionCode='(\d+)'")
    if (-not $versionMatch.Success) { throw 'Existing APK version code is missing.' }
    $BuildNumber = [Math]::Max($BuildNumber, [int]$versionMatch.Groups[1].Value + 1)
  }
}
$tempRoot = (Resolve-Path -LiteralPath $env:TEMP).Path
$buildId = [Guid]::NewGuid().ToString('N')
$apkWork = Join-Path $tempRoot ('okey_small_apk_' + $buildId)
$profileStageRelative = '.codex-build\apk-profiles-' + $buildId
$profileStage = [IO.Path]::GetFullPath((Join-Path $projectRoot $profileStageRelative))
$avatarSubpath = 'g' + [char]0x00F6 + 'rseller/pp'
$imageRoot = 'g' + [char]0x00F6 + 'rseller'
$flutter = Join-Path $projectRoot '.flutter-sdk/bin/flutter.bat'
$oldLocation = (Get-Location).Path
$oldJavaHome = $env:JAVA_HOME
$oldAndroidHome = $env:ANDROID_HOME
$oldAndroidSdkRoot = $env:ANDROID_SDK_ROOT
$oldGradleHome = $env:GRADLE_USER_HOME
$oldPubCache = $env:PUB_CACHE

function Optimize-BuildUi([string]$buildRoot) {
  $encoder = Join-Path $projectRoot '.tool-home/libwebp-1.6.0-windows-x64/bin/cwebp.exe'
  if (-not (Test-Path -LiteralPath $encoder)) { throw 'Install the official libwebp 1.6.0 Windows tools in .tool-home before packaging.' }
  $before = 0L
  $after = 0L
  foreach ($relative in @('images/ui', $imageRoot)) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $buildRoot $relative) -Recurse -File |
      Where-Object { $_.Extension -eq '.png' -or -not $_.Extension }) {
      if ($file.Length -lt 150000) { continue }
      if (-not $file.FullName.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Image is outside the temporary APK build.' }
      $encoded = $file.FullName + '.webp'
      & $encoder -quiet -q 92 -alpha_q 100 -m 4 -sharp_yuv -mt $file.FullName -o $encoded
      if ($LASTEXITCODE -ne 0) { throw "UI image compression failed: $($file.Name)" }
      $before += $file.Length
      if ((Get-Item -LiteralPath $encoded).Length -lt $file.Length) {
        # Flutter detects the encoded format from its header. Preserve asset keys
        # and dimensions, including alpha; only temporary package copies change.
        Copy-Item -LiteralPath $encoded -Destination $file.FullName -Force
      }
      $after += (Get-Item -LiteralPath $file.FullName).Length
      Remove-Item -LiteralPath $encoded
    }
  }
  Write-Output "Build-only UI compression: $before -> $after bytes."
}

function Remove-OwnedBuildFolder([string]$path, [string]$parent) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  $resolved = (Resolve-Path -LiteralPath $path).Path
  if ($resolved -ne $path -or -not $resolved.StartsWith($parent + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Temporary build folder is outside its expected parent.'
  }
  $longPath = '\\?\' + $resolved
  $links = @(Get-ChildItem -LiteralPath $longPath -Recurse -Force |
    Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 })
  if ($links.Count -gt 0) { throw 'Unexpected link in temporary build folder.' }
  Remove-Item -LiteralPath $longPath -Recurse -Force
}

try {
  New-Item -ItemType Directory -Path $apkWork | Out-Null
  foreach ($name in @('lib', 'assets', 'images', 'fonts')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $apkWork -Recurse -Force
  }
  New-Item -ItemType Directory -Path (Join-Path $apkWork $imageRoot) | Out-Null
  Copy-Item -LiteralPath (Join-Path $projectRoot ($imageRoot + '/icon')) -Destination (Join-Path $apkWork $imageRoot) -Recurse -Force
  # Include explicitly declared artwork stored directly under the source image folder.
  foreach ($line in Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Encoding UTF8) {
    if ($line -notmatch '^\s+-\s+(.+?)\s*$') { continue }
    $asset = $Matches[1]
    if (-not $asset.StartsWith($imageRoot + '/', [StringComparison]::Ordinal)) { continue }
    $leaf = $asset.Substring($imageRoot.Length + 1)
    if (-not $leaf -or $leaf.Contains('/') -or $leaf.Contains('\') -or $leaf -in @('.', '..')) { continue }
    $sourceAsset = Join-Path $projectRoot $asset
    if (Test-Path -LiteralPath $sourceAsset -PathType Leaf) {
      Copy-Item -LiteralPath $sourceAsset -Destination (Join-Path $apkWork $asset) -Force
    }
  }
  # Resize only build copies; full resolution source photos remain intact.
  & (Join-Path $projectRoot 'tool/optimize_profile_assets.ps1') -Destination $profileStageRelative -MaxSize 160 | Out-Null
  Copy-Item -LiteralPath $profileStage -Destination (Join-Path $apkWork $avatarSubpath) -Recurse -Force
  foreach ($name in @('pubspec.yaml', 'pubspec.lock', '.metadata')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $apkWork -Force
  }
  Optimize-BuildUi $apkWork
  New-Item -ItemType Directory -Path (Join-Path $apkWork 'android') | Out-Null
  Get-ChildItem -LiteralPath (Join-Path $projectRoot 'android') -Force |
    Where-Object { $_.Name -notin @('.gradle', 'build', 'local.properties') } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $apkWork 'android') -Recurse -Force }
  # Flutter is ARM64-only here; also strip other ABIs from plugin libraries.
  $gradleFile = Join-Path $apkWork 'android/app/build.gradle.kts'
  $gradleText = [IO.File]::ReadAllText($gradleFile)
  if (-not $gradleText.Contains('    defaultConfig {')) { throw 'Android defaultConfig was not found.' }
  $gradleText = $gradleText.Replace('    defaultConfig {', "    defaultConfig {`n        ndk { abiFilters.clear(); abiFilters += listOf(`"arm64-v8a`") }")
  [IO.File]::WriteAllText($gradleFile, $gradleText)
  $flutterLocation = (Join-Path $projectRoot '.flutter-sdk').Replace('\', '\\')
  $androidLocation = (Join-Path $projectRoot '.android-sdk').Replace('\', '\\')
  [IO.File]::WriteAllLines((Join-Path $apkWork 'android/local.properties'),
    @("flutter.sdk=$flutterLocation", "sdk.dir=$androidLocation"), [Text.UTF8Encoding]::new($false))
  $env:JAVA_HOME = Join-Path $projectRoot '.jdk/jdk-17.0.20.1+1'
  $env:ANDROID_HOME = Join-Path $projectRoot '.android-sdk'
  $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
  $env:GRADLE_USER_HOME = if ($GradleCacheRoot) {
    [IO.Path]::GetFullPath($GradleCacheRoot)
  } else {
    Join-Path $projectRoot '.tool-home/gradle'
  }
  if (-not $env:PUB_CACHE) {
    $config = Get-Content -LiteralPath (Join-Path $projectRoot '.dart_tool/package_config.json') -Raw | ConvertFrom-Json
    $cachedPackage = $config.packages | Where-Object { $_.rootUri -match '^file:.*[\/]hosted[\/]' } | Select-Object -First 1
    if ($cachedPackage) {
      $packageFolder = [IO.DirectoryInfo]::new(([Uri]$cachedPackage.rootUri).LocalPath.TrimEnd('\', '/'))
      $env:PUB_CACHE = $packageFolder.Parent.Parent.Parent.FullName
    }
  }
  Set-Location -LiteralPath $apkWork
  & $flutter pub get --offline
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
  & $flutter build apk --release --no-pub --target-platform android-arm64 --build-number $BuildNumber
  if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
  $apkSource = Join-Path $apkWork 'build/app/outputs/flutter-apk/app-release.apk'
  $apk = Get-Item -LiteralPath $apkSource
  # Strict decimal MB limit, also below 20 MiB.
  if ($apk.Length -ge 20000000) { throw "APK exceeds the 20 MB limit: $($apk.Length) bytes." }
  & (Join-Path $projectRoot '.android-sdk/build-tools/36.0.0/apksigner.bat') verify $apkSource
  if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
  New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
  Copy-Item -LiteralPath $apkSource -Destination $outputPath -Force
  if ((Get-FileHash -LiteralPath $apkSource).Hash -ne (Get-FileHash -LiteralPath $outputPath).Hash) {
    throw 'APK copy verification failed.'
  }
  [pscustomobject]@{ APK = $outputPath; Bytes = $apk.Length; DecimalMB = [Math]::Round($apk.Length / 1000000, 2); Architecture = 'arm64-v8a' }
} finally {
  Set-Location -LiteralPath $oldLocation
  $env:JAVA_HOME = $oldJavaHome
  $env:ANDROID_HOME = $oldAndroidHome
  $env:ANDROID_SDK_ROOT = $oldAndroidSdkRoot
  $env:GRADLE_USER_HOME = $oldGradleHome
  $env:PUB_CACHE = $oldPubCache
  Remove-OwnedBuildFolder $apkWork $tempRoot
  # OneDrive can mark ordinary staging files as reparse points; they are build copies.
  if (Test-Path -LiteralPath $profileStage) {
    $resolvedStage = (Resolve-Path -LiteralPath $profileStage).Path
    $expectedParent = Join-Path $projectRoot '.codex-build'
    if ($resolvedStage -ne $profileStage -or -not $resolvedStage.StartsWith($expectedParent + '\', [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Unexpected profile staging folder.'
    }
    Get-ChildItem -LiteralPath $resolvedStage -File -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Remove-Item -LiteralPath $resolvedStage -Force
  }
}
