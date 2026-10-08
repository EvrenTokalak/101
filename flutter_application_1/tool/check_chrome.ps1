param([int]$Port = 59124, [switch]$Reload)
$pages = Invoke-RestMethod "http://localhost:$Port/json/list"
$page = $pages | Where-Object { $_.type -eq 'page' -and $_.url -like 'http://localhost:*' } | Select-Object -First 1
if (-not $page) { throw 'Development page not found' }
$socket = [Net.WebSockets.ClientWebSocket]::new()
$timeout = [Threading.CancellationTokenSource]::new(15000)
try {
  $null = $socket.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $timeout.Token).GetAwaiter().GetResult()
  $commands = @(@{id=1;method='Log.enable'}, @{id=2;method='Runtime.enable'})
  $started = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if ($Reload) { $commands += @{id=3;method='Runtime.discardConsoleEntries'}, @{id=4;method='Log.clear'}, @{id=5;method='Page.reload';params=@{ignoreCache=$true}} }
  foreach ($command in $commands) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($command | ConvertTo-Json -Compress -Depth 8))
    $null = $socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $timeout.Token).GetAwaiter().GetResult()
  }
  $until = [DateTime]::UtcNow.AddSeconds(10)
  $errors = 0
  while ([DateTime]::UtcNow -lt $until) {
    $buffer = [byte[]]::new(262144)
    $stream = [IO.MemoryStream]::new()
    do {
      $result = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $timeout.Token).GetAwaiter().GetResult()
      $stream.Write($buffer, 0, $result.Count)
    } while (-not $result.EndOfMessage)
    $raw = [Text.Encoding]::UTF8.GetString($stream.ToArray())
    $stream.Dispose()
    $message = $raw | ConvertFrom-Json
    if ($message.method -eq 'Runtime.exceptionThrown' -or ($message.method -eq 'Log.entryAdded' -and $message.params.entry.level -eq 'error') -or ($message.method -eq 'Runtime.consoleAPICalled' -and $message.params.type -eq 'error')) {
      if ($Reload -and $message.params.timestamp -and $message.params.timestamp -lt $started) { continue }
      $errors++
      $detail = if ($message.method -eq 'Runtime.consoleAPICalled') { ($message.params.args | ForEach-Object { $_.value }) -join ' ' } else { $raw }
      $detail.Substring(0, [Math]::Min($detail.Length, 2200))
    }
  }
} catch {
  if (-not $timeout.IsCancellationRequested) { throw }
} finally {
  "Observed errors: $errors; page: $($page.url)"
  $socket.Dispose()
  $timeout.Dispose()
}
