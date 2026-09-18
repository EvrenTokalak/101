param(
  [string]$WebSocketUrl = 'ws://127.0.0.1:52988/devtools/page/1D1E434597F989F45783F1F7A1384600',
  [string]$Action = 'screenshot',
  [double]$X = 0,
  [double]$Y = 0,
  [double]$X2 = 0,
  [double]$Y2 = 0,
  [string]$Output = 'build/cdp-screen.png'
)

$socket = [System.Net.WebSockets.ClientWebSocket]::new()
$socket.ConnectAsync([Uri]$WebSocketUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
$script:messageId = 0

function Invoke-Cdp([string]$method, [hashtable]$params = @{}) {
  $script:messageId++
  $id = $script:messageId
  $payload = @{ id = $id; method = $method; params = $params } | ConvertTo-Json -Compress -Depth 8
  $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
  $segment = [ArraySegment[byte]]::new($bytes)
  $socket.SendAsync($segment, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
  while ($true) {
    $stream = [IO.MemoryStream]::new()
    do {
      $buffer = New-Object byte[] 65536
      $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
      $stream.Write($buffer, 0, $received.Count)
    } while (-not $received.EndOfMessage)
    $json = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
    $stream.Dispose()
    if ($json.id -eq $id) { return $json }
  }
}

function Send-Mouse([string]$type, [double]$mouseX, [double]$mouseY, [string]$button = 'none', [int]$buttons = 0) {
  $script:messageId++
  $payload = @{
    id = $script:messageId
    method = 'Input.dispatchMouseEvent'
    params = @{ type = $type; x = $mouseX; y = $mouseY; button = $button; buttons = $buttons; clickCount = 1 }
  } | ConvertTo-Json -Compress -Depth 5
  $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
  $socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

Invoke-Cdp 'Page.enable' | Out-Null
Invoke-Cdp 'Performance.enable' | Out-Null

switch ($Action) {
  'screenshot' {
    $shot = Invoke-Cdp 'Page.captureScreenshot' @{ format = 'png'; fromSurface = $true }
    $dir = Split-Path -Parent $Output
    if ($dir) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllBytes($Output, [Convert]::FromBase64String($shot.result.data))
    Write-Output (Resolve-Path $Output)
  }
  'click' {
    Send-Mouse 'mousePressed' $X $Y 'left' 1
    Start-Sleep -Milliseconds 60
    Send-Mouse 'mouseReleased' $X $Y 'left' 0
    Start-Sleep -Milliseconds 100
  }
  'drag' {
    Send-Mouse 'mouseMoved' $X $Y
    Send-Mouse 'mousePressed' $X $Y 'left' 1
    for ($i = 1; $i -le 24; $i++) {
      $px = $X + ($X2 - $X) * $i / 24
      $py = $Y + ($Y2 - $Y) * $i / 24
      Send-Mouse 'mouseMoved' $px $py 'left' 1
      Start-Sleep -Milliseconds 20
    }
    Send-Mouse 'mouseReleased' $X2 $Y2 'left' 0
    Start-Sleep -Milliseconds 100
  }
  'metrics' {
    (Invoke-Cdp 'Performance.getMetrics').result.metrics | ConvertTo-Json -Compress
  }
}

$socket.Abort()
$socket.Dispose()
