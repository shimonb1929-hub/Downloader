# One-click update for Video Downloader itself (the app and the Chrome button).
# Gets the newest files from the GitHub page and copies the changed ones over this copy.
# The tools (yt-dlp, ffmpeg...), your settings and your downloads are not touched.
# Loaded by downloader.ps1. Downloads go through your own connection, so NetFree still applies.

$UpdateZipUrl = 'https://github.com/shimonb1929-hub/Downloader/archive/refs/heads/main.zip'
$AppRoot = Split-Path -Parent $AppDir
$script:updTemp    = Join-Path ([System.IO.Path]::GetTempPath()) 'VideoDownloaderUpdate'
$script:updRunning = $false
$script:updAuto    = $false
$script:updAsked   = $false   # the automatic check asks only once each time the app opens

$btnAppUpdate = New-Object System.Windows.Forms.Button
$btnAppUpdate.Text = 'Update this app'
$btnAppUpdate.Location = New-Object System.Drawing.Point(365, 420)
$btnAppUpdate.Size = New-Object System.Drawing.Size(245, 30)
$btnAppUpdate.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.Controls.Add($btnAppUpdate)

# Files in the downloaded zip that are new or different from this copy
function Get-ChangedFiles([string]$zipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $dir = Join-Path $script:updTemp 'files'
    if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $dir)
    # GitHub puts everything in one top folder, like "Downloader-main"
    $top = Get-ChildItem -Path $dir -Directory | Select-Object -First 1
    if (-not $top -or -not (Test-Path (Join-Path $top.FullName 'app\downloader.ps1'))) {
        throw 'The downloaded update does not look right.'
    }
    $list = @()
    foreach ($f in (Get-ChildItem -Path $top.FullName -Recurse -File)) {
        $rel = $f.FullName.Substring($top.FullName.Length + 1)
        if ($rel -match '(^|\\)\.' -or $rel -match '\.\.') { continue }   # skip .gitignore and the like
        $dest = Join-Path $AppRoot $rel
        if ((Test-Path $dest) -and ((Get-FileHash -Path $dest).Hash -eq (Get-FileHash -Path $f.FullName).Hash)) { continue }
        $list += @{ Rel = $rel; Src = $f.FullName; Dest = $dest }
    }
    return ,$list
}

function Start-AppUpdateCheck([bool]$auto) {
    if ($script:updRunning) { return }
    $script:updRunning = $true
    $script:updAuto = $auto
    if (-not $auto) { $lblStatus.Text = 'Checking for a new version of the app...' }
    try {
        if (-not (Test-Path $script:updTemp)) { New-Item -ItemType Directory -Path $script:updTemp -Force | Out-Null }
        $zip = Join-Path $script:updTemp 'update.zip'
        $wc = New-Object System.Net.WebClient
        $wc.Add_DownloadFileCompleted({
            param($s, $e)
            $s.Dispose()
            Complete-AppUpdateCheck $e
        })
        $wc.DownloadFileAsync([Uri]$UpdateZipUrl, $zip)
    } catch {
        $script:updRunning = $false
        if (-not $auto) { $lblStatus.Text = 'Could not check for a new version.'; $txtLog.AppendText($_.Exception.Message + "`r`n") }
    }
}

function Complete-AppUpdateCheck($e) {
    $script:updRunning = $false
    $auto = $script:updAuto
    if ($e.Error) {
        $err = $e.Error.ToString()
        if (-not $script:relaxedCerts -and ($err -match 'SSL|TLS|trust|certificate')) {
            Enable-RelaxedCerts
            Start-AppUpdateCheck $auto
            return
        }
        if (-not $auto) {
            $lblStatus.Text = 'Could not check for a new version.'
            $txtLog.AppendText($e.Error.Message + "`r`n")
            [System.Windows.Forms.MessageBox]::Show(
                "Could not reach the update page on GitHub.`n`nCheck your internet and try again later. If NetFree blocks it, ask NetFree to open:`n$UpdateZipUrl`n`nDetails: $($e.Error.Message)",
                'Video Downloader') | Out-Null
        }
        return
    }

    $changed = $null
    try { $changed = Get-ChangedFiles (Join-Path $script:updTemp 'update.zip') } catch {
        if (-not $auto) {
            $lblStatus.Text = 'Could not check for a new version.'
            $txtLog.AppendText($_.Exception.Message + "`r`n")
        }
        return
    }
    if ($changed.Count -eq 0) {
        if (-not $auto) { $lblStatus.Text = 'You already have the newest version of the app.' }
        return
    }

    if ($auto) {
        # Never interrupt a download - look again a bit later
        if ($script:busy) { $updTimer.Interval = 30000; $updTimer.Start(); return }
        if ($script:updAsked) { return }
        $script:updAsked = $true
    }
    $ans = [System.Windows.Forms.MessageBox]::Show(
        "A new version of Video Downloader is ready.`n`nUpdate now? It takes a few seconds, then the app opens again by itself.",
        'Video Downloader', 'YesNo')
    if ($ans -ne 'Yes') {
        $lblStatus.Text = 'A new version is ready. Click "Update this app" when you want it.'
        return
    }
    if ($script:busy) {
        [System.Windows.Forms.MessageBox]::Show('A download is running. When it finishes, click "Update this app".', 'Video Downloader') | Out-Null
        return
    }
    Install-AppUpdate $changed
}

function Install-AppUpdate($changed) {
    $chromeChanged = $false
    # Counts as busy so no download from the Chrome button starts while files are replaced
    $script:busy = $true
    $lblStatus.Text = 'Updating the app...'
    [System.Windows.Forms.Application]::DoEvents()
    try {
        foreach ($c in $changed) {
            $d = Split-Path -Parent $c.Dest
            if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force -ErrorAction Stop | Out-Null }
            Copy-Item -LiteralPath $c.Src -Destination $c.Dest -Force -ErrorAction Stop
            Unblock-File -LiteralPath $c.Dest -ErrorAction SilentlyContinue
            $txtLog.AppendText("Updated: $($c.Rel)`r`n")
            if ($c.Rel -like 'extension\*') { $chromeChanged = $true }
        }
    } catch {
        $script:busy = $false
        $lblStatus.Text = 'The update did not finish.'
        [System.Windows.Forms.MessageBox]::Show(
            "The update did not finish. Close the app, open it again, and click `"Update this app`".`n`nDetails: $($_.Exception.Message)",
            'Video Downloader') | Out-Null
        return
    }

    $msg = 'Updated! Video Downloader opens again now.'
    if ($chromeChanged) {
        $msg += "`n`nThe Download button in Chrome was updated too. To start using it:`n" +
                "close Chrome completely and open it again.`n" +
                "(Or on Chrome's Extensions page, click the round arrow on 'Video Downloader Button'.)"
    }
    [System.Windows.Forms.MessageBox]::Show($msg, 'Video Downloader') | Out-Null

    # Open the new version, then close this one
    $ps = 'powershell.exe'
    if ($env:SystemRoot) { $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
    try {
        Start-Process -FilePath $ps -WorkingDirectory $AppDir -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "' + (Join-Path $AppDir 'downloader.ps1') + '"')
    } catch {}
    $form.Close()
}

$btnAppUpdate.Add_Click({
    if ($script:busy) {
        [System.Windows.Forms.MessageBox]::Show('Please wait until the download (or setup) finishes.', 'Video Downloader') | Out-Null
        return
    }
    Start-AppUpdateCheck $false
})

# Look for a new version by itself a few seconds after the app opens (quietly, no message if none)
$updTimer = New-Object System.Windows.Forms.Timer
$updTimer.Interval = 4000
$updTimer.Add_Tick({
    if ($script:busy -or -not (Test-ToolsReady)) { $updTimer.Interval = 30000; return }
    $updTimer.Stop()
    Start-AppUpdateCheck $true
})
$form.Add_Shown({ $updTimer.Start() })
