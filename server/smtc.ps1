$ErrorActionPreference = "Stop"

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and
        $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]

    function Await($WinRtTask, [System.Type]$ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        return $netTask.Result
    }

    [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.Streams.DataReader,Windows.Storage,ContentType=WindowsRuntime] | Out-Null

    $manager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) `
        ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])

    $session = $manager.GetCurrentSession()

    if ($null -eq $session) {
        '{"playing":false}' | Write-Output
        exit 0
    }

    $props    = Await ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsMediaProperties])
    $timeline = $session.GetTimelineProperties()
    $playback = $session.GetPlaybackInfo()

    $artPath = "$env:TEMP\mw-art.dat"
    $artMime  = "image/jpeg"
    $hasArt   = $false

    try {
        if ($null -ne $props.Thumbnail) {
            [Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
            $stream = Await ($props.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
            $artMime = if ($stream.ContentType) { $stream.ContentType } else { "image/jpeg" }
            $sz = [uint32]$stream.Size
            if ($sz -gt 0) {
                $reader = [Windows.Storage.Streams.DataReader]::new($stream)
                Await ($reader.LoadAsync($sz)) ([System.UInt32]) | Out-Null
                $bytes = [byte[]]::new($sz)
                $reader.ReadBytes($bytes)
                [System.IO.File]::WriteAllBytes($artPath, $bytes)
                $hasArt = $true
                $reader.DetachStream()
            }
            $stream.Dispose()
        }
    } catch { }

    $statusStr = $playback.PlaybackStatus.ToString()
    $isPlaying = ($statusStr -eq "Playing")

    $pos = 0.0
    $dur = 0.0
    try { $pos = [math]::Round($timeline.Position.TotalSeconds, 1) } catch { }
    try { $dur = [math]::Round($timeline.EndTime.TotalSeconds,  1) } catch { }

    [PSCustomObject]@{
        playing  = $isPlaying
        title    = $props.Title
        artist   = $props.Artist
        album    = $props.AlbumTitle
        position = $pos
        duration = $dur
        source   = $session.SourceAppUserModelId
        hasArt   = $hasArt
        artMime  = $artMime
    } | ConvertTo-Json -Compress

} catch {
    [PSCustomObject]@{ playing = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress
}
