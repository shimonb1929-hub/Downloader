# Receives a video link from the Chrome button and hands it to the Video Downloader app.
# Chrome talks to this file through "native messaging" (only on this computer).
$ErrorActionPreference = 'Stop'
$AppDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$JobsDir = Join-Path $AppDir 'jobs'
$ExtCookies = Join-Path $AppDir 'ext-cookies.txt'

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

try {
    $in = [Console]::OpenStandardInput()
    $lenBytes = Read-Exact $in 4
    if ($lenBytes -eq $null) { exit 0 }
    $len = [BitConverter]::ToInt32($lenBytes, 0)
    if ($len -le 0 -or $len -gt 8MB) { Send-Reply @{ ok = $false; error = 'bad message' }; exit 0 }
    $body = Read-Exact $in $len
    $msg = [System.Text.Encoding]::UTF8.GetString($body) | ConvertFrom-Json

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
    $jobFile = Join-Path $JobsDir ((Get-Date).ToString('yyyyMMddHHmmssfff') + '.json')
    [System.IO.File]::WriteAllText($jobFile, $job)

    # Open the app if it is not open yet (started separately so it stays open)
    $running = $false
    try { $m = $null; $running = [System.Threading.Mutex]::TryOpenExisting('Local\VideoDownloaderApp', [ref]$m) } catch {}
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

    Send-Reply @{ ok = $true }
} catch {
    try { Send-Reply @{ ok = $false; error = $_.Exception.Message } } catch {}
}
