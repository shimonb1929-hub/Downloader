# Video Downloader - simple window for yt-dlp
# Runs on your own internet connection, so it goes through NetFree.
# Only videos NetFree has approved will download.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppVersion = '13'
$AppDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path $AppDir 'tools'
$YtDlp    = Join-Path $ToolsDir 'yt-dlp.exe'
$Deno     = Join-Path $ToolsDir 'deno.exe'
$Settings = Join-Path $AppDir 'settings.txt'
$LogFile  = Join-Path $AppDir 'last-run-log.txt'

# Remove the "downloaded from internet" mark so Windows does not block the tools
try { Get-ChildItem -Path $ToolsDir -File | Unblock-File -ErrorAction SilentlyContinue } catch {}

# ---------- Save folder ----------
$DefaultFolder = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\Video Downloads'
$SaveFolder = $DefaultFolder
try {
    if (Test-Path $Settings) {
        $saved = (Get-Content -Path $Settings -Raw -Encoding UTF8).Trim()
        if ($saved) { $SaveFolder = $saved }
    }
} catch {}

function Save-Settings {
    try { Set-Content -Path $Settings -Value $script:SaveFolder -Encoding UTF8 } catch {}
}

# ---------- Browser cookies (for YouTube "not a bot" check) ----------
# Cookies stay on this computer. yt-dlp uses them only to talk to YouTube,
# the same way your browser does.
$CookieSettings = Join-Path $AppDir 'cookie-setting.txt'
$script:cookieMode = 'No'
$script:cookieFile = ''
$script:settingsVer = ''
try {
    if (Test-Path $CookieSettings) {
        $lines = @(Get-Content -Path $CookieSettings -Encoding UTF8)
        if ($lines.Count -ge 1 -and $lines[0]) { $script:cookieMode = $lines[0].Trim() }
        if ($lines.Count -ge 2 -and $lines[1]) { $script:cookieFile = $lines[1].Trim() }
        if ($lines.Count -ge 3 -and $lines[2]) { $script:settingsVer = $lines[2].Trim() }
    }
} catch {}
function Save-CookieSettings {
    try { Set-Content -Path $CookieSettings -Value @($script:cookieMode, $script:cookieFile, $script:settingsVer) -Encoding UTF8 } catch {}
}
# On NetFree, YouTube refuses downloads without a pass, so version 9 turns the Chrome pass on (once)
if ($script:settingsVer -ne '11') {
    $script:cookieMode = 'Chrome button'
    $script:settingsVer = '11'
    Save-CookieSettings
}

# ---------- Keep the Desktop shortcut pointing to this copy ----------
try {
    $lnkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Video Downloader.lnk'
    if (Test-Path $lnkPath) {
        $me = Join-Path $AppDir 'downloader.ps1'
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnkPath)
        if (-not ([string]$sc.Arguments).Contains($me)) {
            $sc.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $sc.Arguments        = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "' + $me + '"'
            $sc.WorkingDirectory = $AppDir
            $sc.WindowStyle      = 7
            $sc.Save()
        }
    }
} catch {}

# ---------- Window ----------
$font     = New-Object System.Drawing.Font('Segoe UI', 10)
$fontBig  = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Video Downloader (version $AppVersion)"
$form.Size = New-Object System.Drawing.Size(640, 500)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = $font

$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = 'Paste the video link:'
$lblUrl.Location = New-Object System.Drawing.Point(15, 15)
$lblUrl.AutoSize = $true
$form.Controls.Add($lblUrl)

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(15, 40)
$txtUrl.Size = New-Object System.Drawing.Size(500, 28)
$form.Controls.Add($txtUrl)

$btnPaste = New-Object System.Windows.Forms.Button
$btnPaste.Text = 'Paste'
$btnPaste.Location = New-Object System.Drawing.Point(525, 38)
$btnPaste.Size = New-Object System.Drawing.Size(85, 30)
$form.Controls.Add($btnPaste)

$grpType = New-Object System.Windows.Forms.GroupBox
$grpType.Text = 'Download as'
$grpType.Location = New-Object System.Drawing.Point(15, 80)
$grpType.Size = New-Object System.Drawing.Size(595, 90)
$form.Controls.Add($grpType)

$rbVideo = New-Object System.Windows.Forms.RadioButton
$rbVideo.Text = 'Video (MP4)'
$rbVideo.Location = New-Object System.Drawing.Point(15, 25)
$rbVideo.AutoSize = $true
$rbVideo.Checked = $true
$grpType.Controls.Add($rbVideo)

$rbAudio = New-Object System.Windows.Forms.RadioButton
$rbAudio.Text = 'Sound only (MP3)'
$rbAudio.Location = New-Object System.Drawing.Point(200, 25)
$rbAudio.AutoSize = $true
$grpType.Controls.Add($rbAudio)

$rbBest = New-Object System.Windows.Forms.RadioButton
$rbBest.Text = 'Sound - best quality (original, no loss)'
$rbBest.Location = New-Object System.Drawing.Point(15, 55)
$rbBest.AutoSize = $true
$grpType.Controls.Add($rbBest)

$lblCookie = New-Object System.Windows.Forms.Label
$lblCookie.Text = 'YouTube pass:'
$lblCookie.Location = New-Object System.Drawing.Point(360, 27)
$lblCookie.AutoSize = $true
$grpType.Controls.Add($lblCookie)

$cmbCookie = New-Object System.Windows.Forms.ComboBox
$cmbCookie.DropDownStyle = 'DropDownList'
$cmbCookie.Location = New-Object System.Drawing.Point(450, 23)
$cmbCookie.Size = New-Object System.Drawing.Size(150, 28)
[void]$cmbCookie.Items.AddRange(@('Chrome button', 'Firefox', 'cookies.txt file', 'No'))
$grpType.Controls.Add($cmbCookie)

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Location = New-Object System.Drawing.Point(15, 185)
$lblFolder.Size = New-Object System.Drawing.Size(400, 40)
$lblFolder.Text = "Saves to: $SaveFolder"
$form.Controls.Add($lblFolder)

$btnChange = New-Object System.Windows.Forms.Button
$btnChange.Text = 'Change folder'
$btnChange.Location = New-Object System.Drawing.Point(420, 182)
$btnChange.Size = New-Object System.Drawing.Size(110, 30)
$form.Controls.Add($btnChange)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = 'Open folder'
$btnOpen.Location = New-Object System.Drawing.Point(535, 182)
$btnOpen.Size = New-Object System.Drawing.Size(75, 30)
$btnOpen.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$form.Controls.Add($btnOpen)

$btnDownload = New-Object System.Windows.Forms.Button
$btnDownload.Text = 'Download'
$btnDownload.Font = $fontBig
$btnDownload.Location = New-Object System.Drawing.Point(15, 230)
$btnDownload.Size = New-Object System.Drawing.Size(595, 45)
$btnDownload.BackColor = [System.Drawing.Color]::FromArgb(30, 110, 200)
$btnDownload.ForeColor = [System.Drawing.Color]::White
$btnDownload.FlatStyle = 'Flat'
$form.Controls.Add($btnDownload)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(15, 285)
$progress.Size = New-Object System.Drawing.Size(595, 22)
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 312)
$lblStatus.Size = New-Object System.Drawing.Size(595, 22)
$lblStatus.Text = 'Ready.'
$form.Controls.Add($lblStatus)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(15, 337)
$txtLog.Size = New-Object System.Drawing.Size(595, 75)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 8)
$form.Controls.Add($txtLog)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = 'Update downloader (if downloads stop working)'
$btnUpdate.Location = New-Object System.Drawing.Point(15, 420)
$btnUpdate.Size = New-Object System.Drawing.Size(340, 30)
$btnUpdate.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.Controls.Add($btnUpdate)

# "Update this app" button and the automatic new-version check (in updater.ps1)
$UpdaterFile = Join-Path $AppDir 'updater.ps1'
if (Test-Path $UpdaterFile) { . $UpdaterFile }

$idx = $cmbCookie.Items.IndexOf($script:cookieMode)
if ($idx -lt 0) { $idx = 0; $script:cookieMode = 'No'; Save-CookieSettings }
$cmbCookie.SelectedIndex = $idx
$script:cookieReady = $true

# ---------- Built-in YouTube sign-in window ----------
# Its own small window, separate from Chrome (no need to close anything).
# All pictures and videos are blocked inside it. Goes through NetFree like everything else.
$WebViewDir    = Join-Path $AppDir 'webview'
$SignInData    = Join-Path $AppDir 'signin-data'
$SignInCookies = Join-Path $AppDir 'youtube-cookies.txt'
$SignInUrl     = 'https://www.youtube.com/'
$script:webviewLoaded = $false

function Show-SignIn {
    if (-not $script:webviewLoaded) {
        try {
            Get-ChildItem -Path $WebViewDir -File | Unblock-File -ErrorAction SilentlyContinue
            Add-Type -Path (Join-Path $WebViewDir 'Microsoft.Web.WebView2.Core.dll')
            Add-Type -Path (Join-Path $WebViewDir 'Microsoft.Web.WebView2.WinForms.dll')
            [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::SetLoaderDllFolderPath($WebViewDir)
            $script:webviewLoaded = $true
        } catch {
            [System.Windows.Forms.MessageBox]::Show("The sign-in window could not start.`n`nDetails: " + $_.Exception.Message, 'Video Downloader') | Out-Null
            return $false
        }
    }

    $script:signedIn = $false
    $script:wvCore = $null

    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = 'YouTube access - pictures blocked'
    $sf.Size = New-Object System.Drawing.Size(520, 700)
    $sf.StartPosition = 'CenterParent'
    $sf.Font = $font

    $info = New-Object System.Windows.Forms.Label
    $info.Dock = 'Top'
    $info.Height = 60
    $info.Padding = New-Object System.Windows.Forms.Padding(8)
    $info.Text = "This is the app's own small browser. It is opening YouTube to get access.`nPictures and videos are blocked here. Wait until the page finishes, then click 'Save and close'. (You can sign in if YouTube asks you to.)"
    $script:sfInfo = $info

    $save = New-Object System.Windows.Forms.Button
    $save.Dock = 'Bottom'
    $save.Height = 42
    $save.Text = 'Save and close'
    $save.Font = $fontBig

    $wv = New-Object Microsoft.Web.WebView2.WinForms.WebView2
    $cp = New-Object Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties
    $cp.UserDataFolder = $SignInData
    $wv.CreationProperties = $cp
    $wv.Dock = 'Fill'

    $sf.Controls.Add($wv)
    $sf.Controls.Add($info)
    $sf.Controls.Add($save)
    $wv.BringToFront()

    $wv.Add_CoreWebView2InitializationCompleted({
        param($sender, $e)
        if (-not $e.IsSuccess) {
            $msg = 'unknown'
            if ($e.InitializationException) { $msg = $e.InitializationException.Message }
            [System.Windows.Forms.MessageBox]::Show("The sign-in window could not start.`n`nDetails: $msg", 'Video Downloader') | Out-Null
            return
        }
        $script:wvCore = $sender.CoreWebView2
        $script:wvCore.AddWebResourceRequestedFilter('*', [Microsoft.Web.WebView2.Core.CoreWebView2WebResourceContext]::Image)
        $script:wvCore.AddWebResourceRequestedFilter('*', [Microsoft.Web.WebView2.Core.CoreWebView2WebResourceContext]::Media)
        $script:wvCore.add_WebResourceRequested({
            param($s2, $e2)
            try { $e2.Response = $script:wvCore.Environment.CreateWebResourceResponse($null, 403, 'Blocked', '') } catch {}
        })
        $script:wvCore.add_NewWindowRequested({
            param($s3, $e3)
            $e3.Handled = $true
            try { $script:wvCore.Navigate($e3.Uri) } catch {}
        })
        $script:wvCore.Navigate($SignInUrl)
    })

    $sf.Add_Shown({ [void]$wv.EnsureCoreWebView2Async($null) })

    $script:cookieTask = $null
    $ctimer = New-Object System.Windows.Forms.Timer
    $ctimer.Interval = 200
    $script:sfForm = $sf
    $script:sfTimer = $ctimer
    $ctimer.Add_Tick({
        if ($script:cookieTask -eq $null -or -not $script:cookieTask.IsCompleted) { return }
        $script:sfTimer.Stop()
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add('# Netscape HTTP Cookie File')
        $count = 0
        try {
            foreach ($c in $script:cookieTask.Result) {
                $d = [string]$c.Domain
                if ($d -notmatch 'youtube\.com$') { continue }
                $inc = 'FALSE'; if ($d.StartsWith('.')) { $inc = 'TRUE' }
                $sec = 'FALSE'; if ($c.IsSecure) { $sec = 'TRUE' }
                $exp = 0; if (-not $c.IsSession) { $exp = [long][math]::Floor($c.Expires) }
                $pre = ''; if ($c.IsHttpOnly) { $pre = '#HttpOnly_' }
                $lines.Add("$pre$d`t$inc`t$($c.Path)`t$sec`t$exp`t$($c.Name)`t$($c.Value)")
                $count++
            }
        } catch {
            if (-not $script:sfClosing) { [System.Windows.Forms.MessageBox]::Show("Could not read the YouTube access.`n`nDetails: " + $_.Exception.Message, 'Video Downloader') | Out-Null }
            return
        }
        if ($count -lt 1) {
            if (-not $script:sfClosing) { [System.Windows.Forms.MessageBox]::Show("YouTube has not finished loading yet.`n`nWait a few seconds for the page, then click 'Save and close' again.", 'Video Downloader') | Out-Null }
            return
        }
        try { [System.IO.File]::WriteAllLines($SignInCookies, $lines) } catch {
            if (-not $script:sfClosing) { [System.Windows.Forms.MessageBox]::Show("Could not save the access file.`n`nDetails: " + $_.Exception.Message, 'Video Downloader') | Out-Null }
            return
        }
        $script:signedIn = $true
        if (-not $script:sfClosing) { $script:sfForm.Close() }
    })

    $save.Add_Click({
        if ($script:wvCore -eq $null) { return }
        $script:cookieTask = $script:wvCore.CookieManager.GetCookiesAsync('')
        $script:sfTimer.Start()
    })

    $script:sfClosing = $false
    $sf.Add_FormClosing({
        # If they just close the window, still try to grab the access quietly
        if (-not $script:signedIn -and $script:wvCore -ne $null) {
            $script:sfClosing = $true
            try {
                $t = $script:wvCore.CookieManager.GetCookiesAsync('')
                while (-not $t.IsCompleted) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }
                $script:cookieTask = $t
                $lines2 = New-Object System.Collections.Generic.List[string]
                $lines2.Add('# Netscape HTTP Cookie File')
                $c2 = 0
                foreach ($c in $t.Result) {
                    $d = [string]$c.Domain
                    if ($d -notmatch 'youtube\.com$') { continue }
                    $inc = 'FALSE'; if ($d.StartsWith('.')) { $inc = 'TRUE' }
                    $sec = 'FALSE'; if ($c.IsSecure) { $sec = 'TRUE' }
                    $exp = 0; if (-not $c.IsSession) { $exp = [long][math]::Floor($c.Expires) }
                    $pre = ''; if ($c.IsHttpOnly) { $pre = '#HttpOnly_' }
                    $lines2.Add("$pre$d`t$inc`t$($c.Path)`t$sec`t$exp`t$($c.Name)`t$($c.Value)")
                    $c2++
                }
                if ($c2 -ge 1) { [System.IO.File]::WriteAllLines($SignInCookies, $lines2); $script:signedIn = $true }
            } catch {}
        }
    })

    [void]$sf.ShowDialog($form)
    try { $ctimer.Dispose(); $wv.Dispose(); $sf.Dispose() } catch {}
    return $script:signedIn
}

$cmbCookie.Add_SelectedIndexChanged({
    if (-not $script:cookieReady) { return }
    $choice = [string]$cmbCookie.SelectedItem
    if ($choice -eq 'cookies.txt file') {
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = 'Choose your cookies.txt file'
        $dlg.Filter = 'Cookies file (*.txt)|*.txt|All files (*.*)|*.*'
        if ($dlg.ShowDialog() -eq 'OK') {
            $script:cookieFile = $dlg.FileName
        } else {
            $script:cookieReady = $false
            $cmbCookie.SelectedItem = $script:cookieMode
            $script:cookieReady = $true
            return
        }
    } elseif ($choice -eq 'In-app browser') {
        $doIt = $true
        if (Test-Path $SignInCookies) {
            $ans = [System.Windows.Forms.MessageBox]::Show('YouTube access is already set up. Set it up again?', 'Video Downloader', 'YesNo')
            if ($ans -ne 'Yes') { $doIt = $false }
        }
        if ($doIt) {
            $ok = Show-SignIn
            if (-not $ok -and -not (Test-Path $SignInCookies)) {
                $script:cookieReady = $false
                $cmbCookie.SelectedItem = $script:cookieMode
                if ($cmbCookie.SelectedIndex -lt 0) { $cmbCookie.SelectedIndex = 0 }
                $script:cookieReady = $true
                return
            }
            if ($ok) { $lblStatus.Text = 'YouTube access set up. Ready to download.' }
        }
    }
    $script:cookieMode = $choice
    Save-CookieSettings
})

function Get-CookieArgs {
    switch ($script:cookieMode) {
        'Chrome button' {
            if (Test-Path $ExtCookies) { return @('--cookies', $ExtCookies) }
            return @()
        }
        'In-app browser' {
            if (Test-Path $SignInCookies) { return @('--cookies', $SignInCookies) }
            return @()
        }
        'Firefox' { return @('--cookies-from-browser', 'firefox') }
        'cookies.txt file' {
            if ($script:cookieFile -and (Test-Path $script:cookieFile)) { return @('--cookies', $script:cookieFile) }
            return @()
        }
        default { return @() }
    }
}

# ---------- Running yt-dlp in the background ----------
$script:proc     = $null
$script:queue    = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:readers  = @()
$script:mode     = ''
$script:stopped  = $false
$script:log      = $null
$script:lastErr  = ''

# ---------- Status for the Chrome button ----------
# The Download box in Chrome reads this small file (through host.ps1) to show
# progress and a clear message if something goes wrong. Only on this computer.
$StatusFile = Join-Path $AppDir 'status.json'
$ResultsDir = Join-Path $AppDir 'results'
$script:jobId = ''
$script:lastStatus = ''
function Write-Status([string]$state, [string]$text, [int]$percent = -1) {
    $obj = [ordered]@{ job = $script:jobId; state = $state; text = $text; percent = $percent }
    $json = $obj | ConvertTo-Json -Compress
    if ($json -eq $script:lastStatus) { return }
    $script:lastStatus = $json
    try { [System.IO.File]::WriteAllText($StatusFile, $json, (New-Object System.Text.UTF8Encoding($false))) } catch {}
    # Keep the end result per job too, so the next download cannot hide it from its Chrome box
    if ($script:jobId -and $state -in @('done', 'failed')) {
        try {
            if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }
            Get-ChildItem -Path $ResultsDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
            [System.IO.File]::WriteAllText((Join-Path $ResultsDir ($script:jobId + '.json')), $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch {}
    }
}

# Short reason for the Chrome box, from yt-dlp's last ERROR line
function Get-ShortError {
    $e = ([string]$script:lastErr) -replace '^ERROR:\s*', '' -replace '^\[[^\]]+\]\s*[^:]*:\s*', ''
    if ($e.Length -gt 140) { $e = $e.Substring(0, 140) + '...' }
    return $e
}

function Quote-Arg([string]$a) {
    return '"' + $a.Replace('"', '\"') + '"'
}

function Start-Reader($stream) {
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
        param($reader, $queue)
        while ($true) {
            $line = $reader.ReadLine()
            if ($line -eq $null) { break }
            $queue.Enqueue($line)
        }
    }).AddArgument($stream).AddArgument($script:queue)
    $handle = $ps.BeginInvoke()
    return @{ PS = $ps; Handle = $handle }
}

function Start-YtDlp([string[]]$argList, [string]$mode, [bool]$append = $false) {
    if (-not (Test-Path $YtDlp)) {
        Write-Status 'failed' 'The downloader tool is missing. Close and reopen Video Downloader to set it up again.'
        [System.Windows.Forms.MessageBox]::Show("yt-dlp.exe is missing from:`n$ToolsDir", 'Video Downloader') | Out-Null
        return
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $YtDlp
    $psi.Arguments = ($argList | ForEach-Object { Quote-Arg $_ }) -join ' '
    $psi.WorkingDirectory = $ToolsDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $psi.EnvironmentVariables['PYTHONUNBUFFERED'] = '1'
    $psi.EnvironmentVariables['DENO_NO_UPDATE_CHECK'] = '1'
    $psi.EnvironmentVariables['DENO_NO_PROMPT'] = '1'
    $psi.EnvironmentVariables['PATH'] = $ToolsDir + ';' + $psi.EnvironmentVariables['PATH']

    $script:mode = $mode
    $script:lastErr = ''
    $script:netfreeBlocked = $false
    $script:pageStep = $false
    $script:lastStep = 'Starting'
    $script:part = 0
    $script:lastPct = -1
    $script:startTime = Get-Date
    $script:lastOutput = Get-Date
    if (-not $append) { $txtLog.Clear() }
    $progress.Value = 0
    try {
        if ($script:log) { $script:log.Dispose() }
        $script:log = New-Object System.IO.StreamWriter($LogFile, $append, [System.Text.Encoding]::UTF8)
        if ($append) { $script:log.WriteLine(''); $script:log.WriteLine('========== Next try ==========') }
        $script:log.AutoFlush = $true
        $script:log.WriteLine("Started: " + (Get-Date).ToString('MM/dd/yyyy hh:mm:ss tt'))
        $script:log.WriteLine("App version: $AppVersion   YouTube pass: $($script:cookieMode)   Saved Chrome pass: " + (Test-Path $ChromePass))
        if ($script:cookieMode -eq 'Chrome' -and (Test-Path $ChromePassLog)) {
            try { $script:log.WriteLine("Chrome pass log: " + ([System.IO.File]::ReadAllText($ChromePassLog) -replace "`r?`n", ' | ')) } catch {}
        }
        $script:log.WriteLine("Command: yt-dlp " + $psi.Arguments)
    } catch { $script:log = $null }

    try {
        $script:proc = [System.Diagnostics.Process]::Start($psi)
    } catch {
        $lblStatus.Text = 'Could not start the downloader.'
        $txtLog.AppendText($_.Exception.Message)
        Write-Status 'failed' ('Could not start the downloader. Details: ' + $_.Exception.Message)
        return
    }
    $script:readers = @(
        (Start-Reader $script:proc.StandardOutput),
        (Start-Reader $script:proc.StandardError)
    )
    Set-Busy $true
    $timer.Start()
}

$script:busy = $false
function Set-Busy([bool]$busy) {
    $script:busy = $busy
    $btnUpdate.Enabled   = -not $busy
    $btnChange.Enabled   = -not $busy
    if ($busy) {
        $btnDownload.Text = 'Stop'
        $btnDownload.BackColor = [System.Drawing.Color]::FromArgb(190, 60, 50)
    } else {
        $btnDownload.Text = 'Download'
        $btnDownload.BackColor = [System.Drawing.Color]::FromArgb(30, 110, 200)
        $btnDownload.Enabled = $true
    }
}

function Handle-Line([string]$line) {
    $script:lastOutput = Get-Date
    if ($script:log) { try { $script:log.WriteLine($line) } catch {} }
    if ($line -match '^\[debug\]') { return }
    if ($line -match '^\[PROG\]\s*([\d\.]+)%') {
        $p = [int][math]::Floor([double]$Matches[1])
        if ($p -ge 0 -and $p -le 100) { $progress.Value = $p }
        # Which part: a video download gets the picture first, then the sound
        $what = 'sound'
        if ($script:kind -eq 'video') {
            $what = 'video'
            if ($script:part -ge 2) { $what = 'sound (part 2 of 2)' }
        }
        # Speed and time left, e.g. "2.3MB/s, 00:12 left"
        $extra = ''
        $bits = $line -split '\|'
        if ($bits.Count -ge 3) {
            $speed = ($bits[1].Trim() -replace 'iB', 'B')
            $eta   = $bits[2].Trim()
            $more = @()
            if ($speed -match '\d') { $more += $speed }
            if ($eta -match '\d')   { $more += "$eta left" }
            if ($more.Count) { $extra = '   (' + ($more -join ', ') + ')' }
        }
        $lblStatus.Text = "Downloading $what... $p%$extra"
        if ($p -ne $script:lastPct) {
            $script:lastPct = $p
            Write-Status 'downloading' "Downloading $what... $p%" $p
        }
        return
    }
    $txtLog.AppendText($line + "`r`n")

    # Is NetFree blocking THIS video? (the video page itself, or the video data)
    if ($line -match '^\[youtube\] [^:]+: Downloading webpage$') { $script:pageStep = $true }
    elseif ($line -match '^\[(youtube|info|download)\]') { $script:pageStep = $false }
    $blockedNow = $false
    if ($script:pageStep -and $line -match 'HTTP Error 418') { $blockedNow = $true }
    if ($line -match '^ERROR:.*(HTTP Error 418|Blocked by NetFree)') { $blockedNow = $true }
    if ($line -match 'unable to download video data.*418') { $blockedNow = $true }
    if ($blockedNow -and -not $script:netfreeBlocked) {
        $script:netfreeBlocked = $true
        $lblStatus.Text = 'Blocked by NetFree.'
        if ($script:mode -eq 'download') { Write-Status 'failed' "Blocked by NetFree. This video is not approved yet. Open it and click 'send the video for review'." }
        # Stop right away - no point retrying
        if ($script:proc -ne $null -and -not $script:proc.HasExited) {
            try { Start-Process taskkill.exe -ArgumentList ('/F /T /PID ' + $script:proc.Id) -WindowStyle Hidden } catch {}
        }
    }

    if ($line -match '^ERROR:') { $script:lastErr = $line }
    elseif ($line -match '^\[download\] Destination:') { $script:part++ }
    elseif ($line -match '^\[Merger\]')        { $lblStatus.Text = 'Joining video and sound...' }
    elseif ($line -match '^\[ExtractAudio\]')  { $lblStatus.Text = $(if ($rbBest.Checked) { 'Saving the sound...' } else { 'Making the MP3...' }) }
    elseif ($line -match '^\[youtube\].*Downloading') { $lblStatus.Text = 'Getting video info...' }
    $script:lastStep = $lblStatus.Text
    if ($script:mode -eq 'download' -and -not $script:netfreeBlocked -and $lblStatus.Text -notmatch '^Downloading') {
        Write-Status 'working' $lblStatus.Text $progress.Value
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    $line = $null
    while ($script:queue.TryDequeue([ref]$line)) { Handle-Line $line }

    # Show that it is still alive, and warn if nothing is happening
    if ($script:proc -ne $null -and -not $script:proc.HasExited) {
        $total = [int]((Get-Date) - $script:startTime).TotalSeconds
        $idle  = [int]((Get-Date) - $script:lastOutput).TotalSeconds
        if ($idle -ge 15 -and $lblStatus.Text -notmatch '^Downloading') {
            $lblStatus.Text = "Still waiting ($total sec)... If nothing happens in 2 minutes, click Stop."
            if ($script:mode -eq 'download') { Write-Status 'working' "Still waiting for YouTube ($total sec)..." }
        }
    }

    if ($script:proc -ne $null -and $script:proc.HasExited) {
        $allDone = $true
        foreach ($r in $script:readers) { if (-not $r.Handle.IsCompleted) { $allDone = $false } }
        if (-not $allDone) { return }
        while ($script:queue.TryDequeue([ref]$line)) { Handle-Line $line }
        $timer.Stop()
        foreach ($r in $script:readers) { try { $r.PS.Dispose() } catch {} }
        $code = $script:proc.ExitCode
        $script:proc = $null
        if ($script:log) { try { $script:log.WriteLine("Exit code: $code"); $script:log.Dispose() } catch {}; $script:log = $null }
        Set-Busy $false
        if ($script:stopped) {
            $script:stopped = $false; $progress.Value = 0; $lblStatus.Text = 'Stopped.'
            if ($script:mode -eq 'download') { Write-Status 'failed' 'Stopped in the Video Downloader window.' }
            return
        }

        if ($script:mode -eq 'update') {
            if ($code -eq 0) { $lblStatus.Text = 'Update finished.' }
            else { $lblStatus.Text = 'Update did not work. See the details below.' }
            return
        }

        if ($script:netfreeBlocked -and $script:mode -eq 'download') {
            $progress.Value = 0
            $lblStatus.Text = 'Blocked by NetFree - this video is not approved.'
            Write-Status 'failed' "Blocked by NetFree. This video is not approved yet. Open it and click 'send the video for review'."
            [System.Windows.Forms.MessageBox]::Show(
                "BLOCKED BY NETFREE`n`nNetFree has not approved this video, so it cannot be downloaded.`n`n" +
                "To ask for it: open the video in your browser and click 'send the video for review'.",
                'Video Downloader', 'OK', 'Warning') | Out-Null
            return
        }

        $cookieProblem = ($script:lastErr -match 'cookie database|decrypt|cookies from|cookies file|Netscape')
        if ($code -ne 0 -and $script:mode -eq 'download' -and $cookieProblem -and -not $script:triedPlain) {
            $script:triedPlain = $true
            $script:baseArgs = @($script:baseArgsPlain)
            $script:attempt = 0
            $lblStatus.Text = 'Trying without the YouTube pass...'
            Write-Status 'working' 'Trying without the YouTube pass...'
            $txtLog.AppendText("--- Could not read the YouTube pass, trying without it ---`r`n")
            Start-Attempt
            return
        }
        if ($code -ne 0 -and $script:mode -eq 'download' -and $cookieProblem) {
            $lblStatus.Text = 'Could not read the browser pass.'
            Write-Status 'failed' 'Could not read the YouTube pass. Reload this page and try again.'
            $b = $script:cookieMode
            $msg = "The app could not read the YouTube pass from $b.`n`nOpen the details file?"
            $ans = [System.Windows.Forms.MessageBox]::Show($msg, 'Video Downloader', 'YesNo')
            if ($ans -eq 'Yes') { Open-Log }
            return
        }
        if ($code -ne 0 -and $script:mode -eq 'download' -and ($script:attempt + 1) -lt $script:clientTries.Count) {
            $script:attempt++
            $lblStatus.Text = "Trying another way ($($script:attempt + 1) of $($script:clientTries.Count))..."
            Write-Status 'working' $lblStatus.Text
            $txtLog.AppendText("--- Trying another way ---`r`n")
            Start-Attempt
            return
        }

        if ($code -eq 0) {
            $progress.Value = 100
            $lblStatus.Text = 'Done! Click "Open folder" to see the file.'
            Write-Status 'done' "Done! Saved in $($script:SaveFolder)" 100
        } else {
            $progress.Value = 0
            $lblStatus.Text = 'Download failed.'
            if ($script:lastErr -match 'not a bot|Sign in to confirm') {
                Write-Status 'failed' 'YouTube asked to confirm you are not a robot. Reload this page, then click the button again.'
                if ($script:cookieMode -eq 'In-app browser' -and -not $script:refreshed) {
                    $extra = ''
                    if (-not (Test-Path $SignInCookies)) { $extra = "First, let's set up YouTube access.`n`n" }
                    $ans = [System.Windows.Forms.MessageBox]::Show(
                        $extra + "Open the app's YouTube browser now to refresh access? (Pictures are blocked. If YouTube asks, sign in once.) Then it will try again.",
                        'Video Downloader', 'YesNo')
                    if ($ans -eq 'Yes') {
                        $script:refreshed = $true
                        $ok = Show-SignIn
                        if ($ok) {
                            $script:baseArgs = @($script:baseArgsPlain) + @(Get-CookieArgs)
                            $script:attempt = 0
                            $lblStatus.Text = 'Trying again with fresh access...'
                            Write-Status 'working' 'Trying again with fresh access...'
                            Start-Attempt
                            return
                        }
                    }
                    return
                }
                $msg = "YouTube is asking to confirm you are not a robot.`n`n" +
                       "Fix: open the video in Chrome and press the Download button on the page (bottom right). That gives the app a fresh YouTube pass.`n`n" +
                       "Open the details file (to send for help)?"
                $ans = [System.Windows.Forms.MessageBox]::Show($msg, 'Video Downloader', 'YesNo')
                if ($ans -eq 'Yes') { Open-Log }
                return
            }
            $why = Get-ShortError
            if ($why) { Write-Status 'failed' "Download failed: $why" }
            else { Write-Status 'failed' 'Download failed. See the Video Downloader window for the reason.' }
            $msg = "The download did not work.`n`n" +
                   "Most common reasons:`n" +
                   "1. NetFree has not approved this video yet. Open it in your browser and click 'send the video for review'.`n" +
                   "2. The link is wrong. Copy it again from the video page.`n" +
                   "3. YouTube changed something. Click 'Update downloader' and try again."
            if ($script:lastErr) { $msg += "`n`nDetails: " + $script:lastErr }
            $msg += "`n`nOpen the details file (to send for help)?"
            $ans = [System.Windows.Forms.MessageBox]::Show($msg, 'Video Downloader', 'YesNo')
            if ($ans -eq 'Yes') { Open-Log }
        }
    }
})

# ---------- First-time setup: download the tools ----------
# Downloads go through your own connection, so NetFree still applies.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$script:setupSteps = @(
    @{ Name = 'yt-dlp (downloader)'; File = 'yt-dlp.exe'; Zip = $false
       Url  = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' },
    @{ Name = 'Deno (reads YouTube pages)'; File = 'deno.zip'; Zip = $true
       Url  = 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' },
    @{ Name = 'FFmpeg (video + MP3 tool)'; File = 'ffmpeg.zip'; Zip = $true
       Url  = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip' }
)
$script:stepIndex = 0
$script:relaxedCerts = $false

function Test-ToolsReady {
    foreach ($f in @('yt-dlp.exe', 'deno.exe', 'ffmpeg.exe', 'ffprobe.exe')) {
        if (-not (Test-Path (Join-Path $ToolsDir $f))) { return $false }
    }
    return $true
}

function Enable-RelaxedCerts {
    # Same idea as NetFree's advice to turn off certificate checking in download programs
    if (-not ('NetFreeCertHelper' -as [type])) {
        Add-Type -TypeDefinition @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class NetFreeCertHelper {
    public static void Enable() {
        ServicePointManager.ServerCertificateValidationCallback =
            delegate (object s, X509Certificate c, X509Chain ch, SslPolicyErrors e) { return true; };
    }
}
"@
    }
    [NetFreeCertHelper]::Enable()
    $script:relaxedCerts = $true
}

function Expand-Tools([string]$zipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.Name
            if (-not $name) { continue }
            if ($name -like '*.dll' -or $name -eq 'deno.exe' -or $name -eq 'ffmpeg.exe' -or $name -eq 'ffprobe.exe') {
                $dest = Join-Path $ToolsDir $name
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
                [System.Windows.Forms.Application]::DoEvents()
            }
        }
    } finally { $zip.Dispose() }
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}

function Start-SetupStep {
    if ($script:stepIndex -ge $script:setupSteps.Count) {
        Set-Busy $false
        $progress.Value = 100
        $lblStatus.Text = 'Setup finished. Ready to download.'
        return
    }
    $step = $script:setupSteps[$script:stepIndex]
    $target = Join-Path $ToolsDir $step.File
    $lblStatus.Text = "Setup $($script:stepIndex + 1) of $($script:setupSteps.Count): downloading $($step.Name)..."
    $progress.Value = 0

    $wc = New-Object System.Net.WebClient
    $wc.Add_DownloadProgressChanged({
        param($s, $e)
        $progress.Value = [math]::Min(100, [math]::Max(0, $e.ProgressPercentage))
        $mb = [math]::Round($e.BytesReceived / 1MB)
        $lblStatus.Text = "Setup $($script:stepIndex + 1) of $($script:setupSteps.Count): $($script:setupSteps[$script:stepIndex].Name) - $mb MB"
    })
    $wc.Add_DownloadFileCompleted({
        param($s, $e)
        $s.Dispose()
        $step = $script:setupSteps[$script:stepIndex]
        $target = Join-Path $ToolsDir $step.File
        if ($e.Error) {
            Remove-Item -Path $target -Force -ErrorAction SilentlyContinue
            $err = $e.Error.ToString()
            if (-not $script:relaxedCerts -and ($err -match 'SSL|TLS|trust|certificate')) {
                $txtLog.AppendText("Certificate problem, retrying with NetFree setting...`r`n")
                Enable-RelaxedCerts
                Start-SetupStep
                return
            }
            Set-Busy $false
            $lblStatus.Text = 'Setup did not finish.'
            $txtLog.AppendText($e.Error.Message + "`r`n")
            Write-Status 'setup' 'Video Downloader could not finish its setup. Close and reopen it to try again.'
            [System.Windows.Forms.MessageBox]::Show("Could not download $($step.Name).`n`nCheck your internet, then close and reopen the app to try again.`n`nDetails: $($e.Error.Message)", 'Video Downloader') | Out-Null
            return
        }
        try {
            if ($step.Zip) {
                $lblStatus.Text = "Unpacking $($step.Name)..."
                [System.Windows.Forms.Application]::DoEvents()
                Expand-Tools $target
            }
            Get-ChildItem -Path $ToolsDir -File | Unblock-File -ErrorAction SilentlyContinue
        } catch {
            Set-Busy $false
            $lblStatus.Text = 'Setup did not finish.'
            $txtLog.AppendText($_.Exception.Message + "`r`n")
            Write-Status 'setup' 'Video Downloader could not finish its setup. Close and reopen it to try again.'
            [System.Windows.Forms.MessageBox]::Show("Could not unpack $($step.Name).`n`nClose and reopen the app to try again.`n`nDetails: $($_.Exception.Message)", 'Video Downloader') | Out-Null
            return
        }
        $txtLog.AppendText("Done: $($step.Name)`r`n")
        $script:stepIndex++
        Start-SetupStep
    })
    $wc.DownloadFileAsync([Uri]$step.Url, $target)
}

function Start-Setup {
    if (-not (Test-Path $ToolsDir)) { New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null }
    $script:stepIndex = 0
    $txtLog.Clear()
    Set-Busy $true
    $btnDownload.Text = 'Setting up...'
    $btnDownload.Enabled = $false
    Start-SetupStep
}

$form.Add_Shown({
    if (-not (Test-ToolsReady)) {
        $ans = [System.Windows.Forms.MessageBox]::Show(
            "First time setup: the app needs to download its tools (about 150 MB, one time only).`n`nDownload now?",
            'Video Downloader', 'YesNo')
        if ($ans -eq 'Yes') { Start-Setup }
        else { $lblStatus.Text = 'Setup needed. Close and reopen the app to set up.'; $btnDownload.Enabled = $false }
    }
})

# YouTube can be read in several ways ("clients"). NetFree may allow some and block others,
# so if one way fails, the app automatically tries the next.
$script:clientTries = @(
    @('--extractor-args', 'youtube:player_client=web'),
    @(),
    @('--extractor-args', 'youtube:player_client=web_safari'),
    @('--extractor-args', 'youtube:player_client=tv'),
    @('--extractor-args', 'youtube:player_client=web_embedded'),
    @('--extractor-args', 'youtube:player_client=android_vr')
)
$script:attempt  = 0
$script:baseArgs = @()
$script:url      = ''

function Start-Attempt {
    $a = @($script:baseArgs) + @($script:clientTries[$script:attempt]) + @($script:url)
    Start-YtDlp $a 'download' ($script:attempt -gt 0)
}

# ---------- Chrome pass (the app keeps its own copy) ----------
# Chrome locks its pass file while it is open. So the app saves its own copy
# whenever Chrome is closed, and uses that copy while Chrome is open.
# Only YouTube's entries are kept - nothing else from Chrome is saved.
$ChromePass    = Join-Path $AppDir 'chrome-pass.txt'
$ChromePassLog = Join-Path $AppDir 'chrome-pass-log.txt'

function Test-ChromeRunning {
    return (@(Get-Process -Name 'chrome' -ErrorAction SilentlyContinue).Count -gt 0)
}

# Returns '' when saved, otherwise a short reason: locked / decrypt / none / save
function Export-ChromePass {
    $tmp = Join-Path $AppDir 'chrome-pass-temp.txt'
    Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
    $out = ''
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $YtDlp
        $psi.Arguments = (@('--ignore-config', '--cookies-from-browser', 'chrome', '--cookies', $tmp) | ForEach-Object { Quote-Arg $_ }) -join ' '
        $psi.WorkingDirectory = $ToolsDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
        $p = [System.Diagnostics.Process]::Start($psi)
        $errTask = $p.StandardError.ReadToEndAsync()
        $out = $p.StandardOutput.ReadToEnd()
        [void]$p.WaitForExit(60000)
        $out = $out + "`r`n" + $errTask.Result
    } catch { $out = $out + "`r`n" + $_.Exception.Message }

    $kept = New-Object System.Collections.Generic.List[string]
    $kept.Add('# Netscape HTTP Cookie File')
    $n = 0
    try {
        if (Test-Path $tmp) {
            foreach ($line in [System.IO.File]::ReadAllLines($tmp)) {
                if ($line -match '^(#HttpOnly_)?([^\t#][^\t]*)\t') {
                    if ($Matches[2] -match '(^|\.)youtube\.com$') { $kept.Add($line); $n++ }
                }
            }
        }
    } catch {}
    Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
    try { [System.IO.File]::WriteAllText($ChromePassLog, ((Get-Date).ToString('MM/dd/yyyy hh:mm:ss tt') + "`r`nYouTube entries saved: $n`r`n" + $out)) } catch {}

    if ($n -gt 0) {
        try { [System.IO.File]::WriteAllLines($ChromePass, $kept); return '' } catch { return 'save' }
    }
    if ($out -match 'Could not copy') { return 'locked' }
    if ($out -match 'could not be decrypted|decrypt') { return 'decrypt' }
    return 'none'
}

# Close Chrome for a few seconds, save its pass, then open Chrome again with all the tabs
function Invoke-ChromeBlink {
    $chromePath = $null
    try { $chromePath = (Get-Process -Name 'chrome' -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1).Path } catch {}
    if (-not $chromePath) {
        foreach ($c in @((Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
                         (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
                         (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'))) {
            if ($c -and (Test-Path $c)) { $chromePath = $c; break }
        }
    }
    $lblStatus.Text = 'Closing Chrome for a few seconds...'
    [System.Windows.Forms.Application]::DoEvents()
    # A quick full stop keeps every window and tab in Chrome's memory of the last session
    try { Start-Process taskkill.exe -ArgumentList '/F /T /IM chrome.exe' -WindowStyle Hidden -Wait } catch {}
    for ($i = 0; $i -lt 10 -and (Test-ChromeRunning); $i++) { Start-Sleep -Milliseconds 300 }
    Start-Sleep -Milliseconds 500

    $lblStatus.Text = 'Saving the Chrome pass...'
    [System.Windows.Forms.Application]::DoEvents()
    $r = Export-ChromePass

    # Open Chrome again with all the tabs
    if ($chromePath) {
        try { Start-Process -FilePath $chromePath -ArgumentList '--restore-last-session' } catch {}
    }
    if ($r -eq '') { $lblStatus.Text = 'Chrome pass saved.' } else { $lblStatus.Text = 'Could not save the Chrome pass.' }
    return $r
}

function Show-ChromePassProblem([string]$why) {
    if ($why -eq 'decrypt') {
        $m = "Chrome on this computer locks its YouTube pass so no program can read it.`n`nTry 'Firefox' in 'YouTube pass' instead."
    } elseif ($why -eq 'locked') {
        $m = "Chrome was still open, so its pass could not be read.`n`nTry again in a moment."
    } else {
        $m = "No YouTube pass was found in Chrome.`n`nOpen any YouTube video in Chrome once, then try again."
    }
    [System.Windows.Forms.MessageBox]::Show($m, 'Video Downloader') | Out-Null
}

function Open-Log {
    if (Test-Path $LogFile) { Start-Process notepad.exe -ArgumentList (Quote-Arg $LogFile) }
}

function Stop-Download {
    if ($script:proc -ne $null -and -not $script:proc.HasExited) {
        $script:stopped = $true
        if ($script:log) { try { $script:log.WriteLine("STOPPED by user. Last step: " + $script:lastStep) } catch {} }
        try { Start-Process taskkill.exe -ArgumentList ('/F /T /PID ' + $script:proc.Id) -WindowStyle Hidden -Wait } catch {}
        try { if (-not $script:proc.HasExited) { $script:proc.Kill() } } catch {}
        $lblStatus.Text = 'Stopping...'
    }
}

# ---------- Buttons ----------
$btnPaste.Add_Click({
    try {
        $clip = [System.Windows.Forms.Clipboard]::GetText()
        if ($clip) { $txtUrl.Text = $clip.Trim() }
    } catch {}
})

$btnChange.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Where should downloads be saved?'
    if (Test-Path $script:SaveFolder) { $dlg.SelectedPath = $script:SaveFolder }
    if ($dlg.ShowDialog() -eq 'OK') {
        $script:SaveFolder = $dlg.SelectedPath
        $lblFolder.Text = "Saves to: $($script:SaveFolder)"
        Save-Settings
    }
})

$btnOpen.Add_Click({
    try {
        if (-not (Test-Path $script:SaveFolder)) { New-Item -ItemType Directory -Path $script:SaveFolder -Force | Out-Null }
        Start-Process explorer.exe -ArgumentList (Quote-Arg $script:SaveFolder)
    } catch {}
})

$btnDownload.Add_Click({
    if ($script:busy) {
        if ($script:proc -ne $null) { Stop-Download }
        return
    }
    if (-not $script:jobFromButton) { $script:jobId = '' }
    $url = $txtUrl.Text.Trim()
    if (-not ($url -match '^https?://')) {
        [System.Windows.Forms.MessageBox]::Show('Please paste a full video link (starting with https://).', 'Video Downloader') | Out-Null
        return
    }
    try {
        if (-not (Test-Path $script:SaveFolder)) { New-Item -ItemType Directory -Path $script:SaveFolder -Force | Out-Null }
    } catch {
        Write-Status 'failed' "Cannot save to this folder: $($script:SaveFolder). Choose another folder in Video Downloader."
        [System.Windows.Forms.MessageBox]::Show("Cannot use this folder:`n$($script:SaveFolder)", 'Video Downloader') | Out-Null
        return
    }

    $outTemplate = Join-Path $script:SaveFolder '%(title)s.%(ext)s'

    $argList = @(
        '--ignore-config',                   # ignore any outside settings files
        '--no-write-thumbnail',              # never save the video's picture
        '--no-embed-thumbnail',              # never put a picture inside the file
        '--no-check-certificate',            # needed on NetFree (NetFree certificate)
        '--socket-timeout', '20',            # do not hang forever on a stuck connection
        '--retries', '3',
        '--fragment-retries', '3',
        '-v',                                # full details go to last-run-log.txt
        '--no-playlist',
        '--newline',
        '--progress-template', 'download:[PROG] %(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
        '--ffmpeg-location', $ToolsDir,
        '--js-runtimes', ('deno:' + $Deno),
        '--windows-filenames',
        '--no-mtime',
        '-o', $outTemplate
    )

    $script:kind = 'video'
    if ($rbBest.Checked) { $script:kind = 'best' } elseif ($rbAudio.Checked) { $script:kind = 'mp3' }
    if ($rbBest.Checked) {
        # Keep YouTube's own best sound stream exactly as it is - no converting.
        # The old WAV conversion clipped loud parts into crackle (Opus -> 16-bit WAV),
        # which is why it sounded noisy in earbuds.
        # Pick: skip the squashed-volume "DRC" copies, keep the original language track,
        # then the highest bitrate (so 256k streams win when the account has them),
        # and Opus over AAC when the bitrate is the same.
        $argList += @(
            '-f', 'ba[format_id!*=drc]/ba/b',
            '-S', 'lang,abr,acodec:opus',
            '-x', '--audio-format', 'best'     # 'best' = keep the stream as-is (copy, no re-encode)
        )
    } elseif ($rbAudio.Checked) {
        $argList += @('-f', 'ba/b', '-x', '--audio-format', 'mp3', '--audio-quality', '0')
    } else {
        # Prefer regular MP4 (H.264) up to 1080p, so it plays on any Windows computer
        $argList += @(
            '-f', 'bv*[height<=1080][ext=mp4][vcodec^=avc]+ba[ext=m4a]/bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b',
            '--merge-output-format', 'mp4'
        )
    }
    $script:refreshed = $false
    $passArgs = @(Get-CookieArgs)
    if ($script:jobFromButton -and (Test-Path $ExtCookies)) { $passArgs = @('--cookies', $ExtCookies) }
    if (($script:cookieMode -eq 'Chrome button' -or $script:jobFromButton) -and (Test-Path $ExtUA)) {
        try {
            $ua = ([System.IO.File]::ReadAllText($ExtUA)).Trim()
            if ($ua) { $argList += @('--user-agent', $ua) }
        } catch {}
    }
    $script:triedPlain = $false
    $script:baseArgsPlain = @($argList)
    $script:baseArgs = @($argList) + $passArgs
    $script:url = $url
    $script:attempt = 0

    $lblStatus.Text = 'Starting...'
    Write-Status 'working' 'Starting...' 0
    Start-Attempt
})

$btnUpdate.Add_Click({
    $lblStatus.Text = 'Updating...'
    Start-YtDlp @('-U', '--no-check-certificate') 'update'
})

$form.Add_FormClosing({
    if ($script:proc -ne $null -and -not $script:proc.HasExited) {
        $ans = [System.Windows.Forms.MessageBox]::Show('A download is still running. Stop it and close?', 'Video Downloader', 'YesNo')
        if ($ans -ne 'Yes') { $_.Cancel = $true; return }
        Stop-Download
    }
})

# ---------- Chrome button (extension) ----------
$ExtensionId = 'bagidnomlmojifgdgmgicinhabkhbahb'
$JobsDir     = Join-Path $AppDir 'jobs'
$ExtCookies  = Join-Path $AppDir 'ext-cookies.txt'
$ExtUA       = Join-Path $AppDir 'ext-useragent.txt'
$script:jobFromButton = $false

# Tell Chrome where the helper is (only on this computer, no admin needed)
function Register-ChromeHelper {
    try {
        $hostJson = Join-Path $AppDir 'native-host.json'
        $obj = [ordered]@{
            name            = 'com.videodownloader.host'
            description     = 'Video Downloader'
            path            = (Join-Path $AppDir 'host.bat')
            type            = 'stdio'
            allowed_origins = @("chrome-extension://$ExtensionId/")
        }
        [System.IO.File]::WriteAllText($hostJson, ($obj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
        foreach ($k in @('HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.videodownloader.host',
                         'HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.videodownloader.host')) {
            New-Item -Path $k -Force | Out-Null
            Set-Item -Path $k -Value $hostJson
        }
    } catch {}
}
Register-ChromeHelper

# Lets the helper know the app is already open
try { $script:appMutex = New-Object System.Threading.Mutex($false, 'Local\VideoDownloaderApp') } catch {}

# Pick up videos sent from the Chrome button
$jobTimer = New-Object System.Windows.Forms.Timer
$jobTimer.Interval = 1000
$jobTimer.Add_Tick({
    if (-not (Test-Path $JobsDir)) { return }
    $f = Get-ChildItem -Path $JobsDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
    if (-not $f) { return }
    if (-not (Test-ToolsReady)) {
        # Tell the Chrome box why nothing is happening yet
        $script:jobId = ''
        if ($script:busy) { Write-Status 'setup' 'Video Downloader is setting up its tools (one time only). Your download starts when it finishes.' }
        else { Write-Status 'setup' 'Video Downloader needs its one-time setup. Close and reopen it, then click Yes.' }
        return
    }
    if ($script:busy) { return }
    $job = $null
    try { $job = [System.IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json } catch {}
    Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
    if (-not $job -or -not $job.url) { return }
    if ($job.ua) { try { [System.IO.File]::WriteAllText($ExtUA, [string]$job.ua) } catch {} }
    $txtUrl.Text = [string]$job.url
    switch ([string]$job.mode) {
        'mp3'   { $rbAudio.Checked = $true }
        'wav'   { $rbBest.Checked = $true }
        default { $rbVideo.Checked = $true }
    }
    try { $form.WindowState = 'Normal'; $form.TopMost = $true; $form.Activate(); $form.TopMost = $false } catch {}
    $script:jobFromButton = $true
    $script:jobId = $f.BaseName
    $btnDownload.PerformClick()
    $script:jobFromButton = $false
})
$jobTimer.Start()

[void]$form.ShowDialog()
