param(
    [int]$Port = 7357,
    [string]$Root = (Join-Path $PSScriptRoot '..\build\web')
)

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

$mimeTypes = @{
    '.css'   = 'text/css'
    '.html'  = 'text/html; charset=utf-8'
    '.ico'   = 'image/x-icon'
    '.js'    = 'application/javascript'
    '.json'  = 'application/json'
    '.png'   = 'image/png'
    '.svg'   = 'image/svg+xml'
    '.wasm'  = 'application/wasm'
    '.webp'  = 'image/webp'
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            $relativePath = 'index.html'
        }

        $candidate = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))
        if (-not $candidate.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $candidate = Join-Path $resolvedRoot 'index.html'
        }

        $bytes = [System.IO.File]::ReadAllBytes($candidate)
        $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
        $context.Response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.OutputStream.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
