# Receives a video link from the Chrome button and hands it to the Video Downloader app.
# Chrome talks to this file through "native messaging" (only on this computer).
$ErrorActionPreference = 'Stop'
$AppDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$JobsDir = Join-Path $AppDir 'jobs'
$ExtCookies = Join-Path $AppDir 'ext-cookies.txt'
$StatusFile = Join-Path $AppDir 'status.json'

function Read-Exact($stream, [int]$count) {
    $buf = New-Object byte[] $count
    $got = 0
    while ($got -lt $count) {
        $n = $stream.Read($buf, $got, $count - $got)
        if ($n -le 0) { break }
        $got += $n
    }
    if ($got -lt $count) { return $null }
    return ,$buf
}

function Send-Reply($obj) {
    $json  = $obj | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $out   = [Console]::OpenStandardOutput()
    $len   = [BitConverter]::GetBytes([int]$bytes.Length)
    $out.Write($len, 0, 4)
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
}

function Test-AppRunning {
    # Close the handle right away, or it would keep the app's sign alive after the app closes
    $m = $null
    $ok = $false
    try { $ok = [System.Threading.Mutex]::TryOpenExisting('Local\VideoDownloaderApp', [ref]$m) } catch {}
    if ($m) { try { $m.Dispose() } catch {} }
    return $ok
}

# Keeps telling the Chrome box how one download is going, until it is done or failed.
# The app writes status.json; this only reads it.
function Watch-Job([string]$job) {
    $start = Get-Date
    $last = ''
    while ($true) {
        $st = $null
        try { if (Test-Path $StatusFile) { $st = [System.IO.File]::ReadAllText($StatusFile) | ConvertFrom-Json } } catch {}
        $running = Test-AppRunning
        $waiting = Test-Path (Join-Path $JobsDir "$job.json")
        $secs = [int]((Get-Date) - $start).TotalSeconds
        $final = ($st -and [string]$st.job -eq $job -and ([string]$st.state -in @('done', 'failed')))

        if ($final) {
            $reply = @{ state = [string]$st.state; text = [string]$st.text; percent = [int]$st.percent }
        } elseif (-not $running) {
            if ($secs -lt 45) {
                $reply = @{ state = 'waiting'; text = 'Opening Video Downloader...'; percent = -1 }
            } elseif ($st -and [string]$st.job -eq $job) {
                $reply = @{ state = 'failed'; text = 'Video Downloader was closed before the download finished. Open it and try again.'; percent = -1 }
            } else {
                $reply = @{ state = 'failed'; text = 'Video Downloader did not open. Open it from its folder or Desktop icon, then try again.'; percent = -1 }
            }
        } elseif ($st -and [string]$st.job -eq $job) {
            $reply = @{ state = [string]$st.state; text = [string]$st.text; percent = [int]$st.percent }
        } elseif ($st -and [string]$st.state -eq 'setup') {
            $reply = @{ state = 'waiting'; text = [string]$st.text; percent = -1 }
        } elseif ($waiting) {
            $reply = @{ state = 'waiting'; text = 'Waiting for the download before it to finish...'; percent = -1 }
        } else {
            $reply = @{ state = 'waiting'; text = 'Starting...'; percent = -1 }
        }

        $json = $reply | ConvertTo-Json -Compress
        if ($json -ne $last) { Send-Reply $reply; $last = $json }
        if ($reply.state -in @('done', 'failed')) { return }
        if ($secs -gt 4 * 3600) { return }
        Start-Sleep -Milliseconds 700
    }
}

try {
    $in = [Console]::OpenStandardInput()
    $lenBytes = Read-Exact $in 4
    if ($lenBytes -eq $null) { exit 0 }
    $len = [BitConverter]::ToInt32($lenBytes, 0)
    if ($len -le 0 -or $len -gt 8MB) { Send-Reply @{ ok = $false; error = 'bad message' }; exit 0 }
    $body = Read-Exact $in $len
    $msg = [System.Text.Encoding]::UTF8.GetString($body) | ConvertFrom-Json

    # The Chrome box asks how a download is going
    if ([string]$msg.type -eq 'watch') {
        $job = [string]$msg.job
        if ($job -notmatch '^\d{17}$') { Send-Reply @{ ok = $false; error = 'bad job' }; exit 0 }
        Watch-Job $job
        exit 0
    }

    # Only YouTube video pages
    $url = [string]$msg.url
    if ($url -notmatch '^https://(www\.|m\.)?youtube\.com/(watch\?|shorts/)') {
        Send-Reply @{ ok = $false; error = 'Not a YouTube video page' }; exit 0
    }
    $mode = [string]$msg.mode
    if ($mode -notin @('video', 'mp3', 'wav')) { $mode = 'video' }

    # Save YouTube's pass from Chrome (YouTube entries only)
    if ($msg.cookies) {
        $keep = New-Object System.Collections.Generic.List[string]
        $keep.Add('# Netscape HTTP Cookie File')
        foreach ($line in ([string]$msg.cookies -split "`n")) {
            if ($line -match '^(#HttpOnly_)?([^\t#][^\t]*)\t' -and $Matches[2] -match '(^|\.)youtube\.com$') { $keep.Add($line.TrimEnd("`r")) }
        }
        [System.IO.File]::WriteAllLines($ExtCookies, $keep)
    }

    # Leave a job for the app
    if (-not (Test-Path $JobsDir)) { New-Item -ItemType Directory -Path $JobsDir -Force | Out-Null }
    $job = @{ url = $url; mode = $mode; ua = [string]$msg.ua } | ConvertTo-Json -Compress
    $jobId = (Get-Date).ToString('yyyyMMddHHmmssfff')
    $jobFile = Join-Path $JobsDir ($jobId + '.json')
    [System.IO.File]::WriteAllText($jobFile, $job)

    # Open the app if it is not open yet (started separately so it stays open)
    $running = Test-AppRunning
    if (-not $running) {
        $ps = 'powershell.exe'
        if ($env:SystemRoot) { $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
        $cmd = '"' + $ps + '" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "' + (Join-Path $AppDir 'downloader.ps1') + '"'
        $started = $false
        try {
            $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; CurrentDirectory = $AppDir }
            if ($r.ReturnValue -eq 0) { $started = $true }
        } catch {}
        if (-not $started) { try { Start-Process -FilePath $ps -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "' + (Join-Path $AppDir 'downloader.ps1') + '"') } catch {} }
    }

    Send-Reply @{ ok = $true; job = $jobId }
} catch {
    try { Send-Reply @{ ok = $false; error = $_.Exception.Message } } catch {}
}
