# Video Downloader - simple window for yt-dlp
# Runs on your own internet connection, so it goes through NetFree.
# Only videos NetFree has approved will download.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppVersion = '15'
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

# How many downloads run at the same time (3 unless changed in the window)
$MaxSetting = Join-Path $AppDir 'at-once-setting.txt'
$MaxAtOnce = 3
try {
    if (Test-Path $MaxSetting) {
        $n = [int]((Get-Content -Path $MaxSetting -Raw).Trim())
        if ($n -ge 1 -and $n -le 6) { $MaxAtOnce = $n }
    }
} catch {}
function Save-MaxAtOnce {
    try { Set-Content -Path $MaxSetting -Value ([string]$script:MaxAtOnce) } catch {}
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
$form.Size = New-Object System.Drawing.Size(640, 660)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = $font

$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = 'Paste video links (one or more, one on each line):'
$lblUrl.Location = New-Object System.Drawing.Point(15, 12)
$lblUrl.AutoSize = $true
$form.Controls.Add($lblUrl)

# Several lines, so many links can go in at once
$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(15, 36)
$txtUrl.Size = New-Object System.Drawing.Size(500, 52)
$txtUrl.Multiline = $true
$txtUrl.WordWrap = $false
$txtUrl.ScrollBars = 'Vertical'
$form.Controls.Add($txtUrl)

$btnPaste = New-Object System.Windows.Forms.Button
$btnPaste.Text = 'Paste'
$btnPaste.Location = New-Object System.Drawing.Point(525, 36)
$btnPaste.Size = New-Object System.Drawing.Size(85, 30)
$form.Controls.Add($btnPaste)

$grpType = New-Object System.Windows.Forms.GroupBox
$grpType.Text = 'Download as'
$grpType.Location = New-Object System.Drawing.Point(15, 95)
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
$lblFolder.Location = New-Object System.Drawing.Point(15, 195)
$lblFolder.Size = New-Object System.Drawing.Size(400, 40)
$lblFolder.Text = "Saves to: $SaveFolder"
$form.Controls.Add($lblFolder)

$btnChange = New-Object System.Windows.Forms.Button
$btnChange.Text = 'Change folder'
$btnChange.Location = New-Object System.Drawing.Point(420, 192)
$btnChange.Size = New-Object System.Drawing.Size(110, 30)
$form.Controls.Add($btnChange)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = 'Open folder'
$btnOpen.Location = New-Object System.Drawing.Point(535, 192)
$btnOpen.Size = New-Object System.Drawing.Size(75, 30)
$btnOpen.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$form.Controls.Add($btnOpen)

$btnDownload = New-Object System.Windows.Forms.Button
$btnDownload.Text = 'Download'
$btnDownload.Font = $fontBig
$btnDownload.Location = New-Object System.Drawing.Point(15, 238)
$btnDownload.Size = New-Object System.Drawing.Size(595, 42)
$btnDownload.BackColor = [System.Drawing.Color]::FromArgb(30, 110, 200)
$btnDownload.ForeColor = [System.Drawing.Color]::White
$btnDownload.FlatStyle = 'Flat'
$form.Controls.Add($btnDownload)

# One line for each download, so several can run at the same time
$lstJobs = New-Object System.Windows.Forms.ListView
$lstJobs.Location = New-Object System.Drawing.Point(15, 288)
$lstJobs.Size = New-Object System.Drawing.Size(595, 140)
$lstJobs.View = 'Details'
$lstJobs.FullRowSelect = $true
$lstJobs.HideSelection = $false
$lstJobs.MultiSelect = $true
$lstJobs.HeaderStyle = 'Nonclickable'
[void]$lstJobs.Columns.Add('Video', 235)
[void]$lstJobs.Columns.Add('Type', 70)
[void]$lstJobs.Columns.Add('Status', 230)
[void]$lstJobs.Columns.Add('%', 40)
$form.Controls.Add($lstJobs)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = 'Stop'
$btnStop.Location = New-Object System.Drawing.Point(15, 433)
$btnStop.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($btnStop)

$btnDetails = New-Object System.Windows.Forms.Button
$btnDetails.Text = 'Details'
$btnDetails.Location = New-Object System.Drawing.Point(100, 433)
$btnDetails.Size = New-Object System.Drawing.Size(80, 28)
$form.Controls.Add($btnDetails)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = 'Clear finished'
$btnClear.Location = New-Object System.Drawing.Point(185, 433)
$btnClear.Size = New-Object System.Drawing.Size(110, 28)
$form.Controls.Add($btnClear)

# How many downloads run at the same time
$lblMax = New-Object System.Windows.Forms.Label
$lblMax.Text = 'Downloads at the same time:'
$lblMax.Location = New-Object System.Drawing.Point(355, 438)
$lblMax.AutoSize = $true
$form.Controls.Add($lblMax)

$numMax = New-Object System.Windows.Forms.NumericUpDown
$numMax.Location = New-Object System.Drawing.Point(555, 435)
$numMax.Size = New-Object System.Drawing.Size(55, 28)
$numMax.Minimum = 1
$numMax.Maximum = 6
$numMax.Value = $MaxAtOnce
$form.Controls.Add($numMax)

$tips = New-Object System.Windows.Forms.ToolTip
$tips.SetToolTip($numMax, 'More at once is faster, but NetFree or YouTube may block more often. 3 is a good number.')
$tips.SetToolTip($btnStop, 'Stops the downloads you picked in the list (or all of them).')
$tips.SetToolTip($btnDetails, 'Opens the details file of the download you picked in the list.')

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(15, 470)
$progress.Size = New-Object System.Drawing.Size(595, 16)
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 490)
$lblStatus.Size = New-Object System.Drawing.Size(595, 22)
$lblStatus.Text = 'Ready.'
$form.Controls.Add($lblStatus)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(15, 514)
$txtLog.Size = New-Object System.Drawing.Size(595, 60)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 8)
$form.Controls.Add($txtLog)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = 'Update downloader (if downloads stop working)'
$btnUpdate.Location = New-Object System.Drawing.Point(15, 582)
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
# Each download is its own little record (a hashtable), so several can run at the same time.
# Each one has its own yt-dlp, its own output queue, its own details file and its own line in the list.
$script:downloads = New-Object System.Collections.ArrayList
$script:nextId    = 0
$script:hold      = $false    # true while the tools are being set up
$script:installing = $false   # true while "Update this app" replaces files
$script:busy      = $false    # anything running (downloads, setup, update) - updater.ps1 reads this
$script:popups    = New-Object System.Collections.ArrayList
$script:popupOpen = $false

$LogsDir = Join-Path $AppDir 'logs'
$RunDir  = Join-Path $AppDir 'run'      # a private copy of the YouTube pass for each running download

# Clean up what an earlier run left behind
try { if (Test-Path $RunDir) { Get-ChildItem -Path $RunDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue } } catch {}
try {
    if (Test-Path $LogsDir) {
        Get-ChildItem -Path $LogsDir -Filter '*.txt' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
} catch {}

# ---------- Status for the Chrome button ----------
# Each Download box in Chrome reads its own small file, results\<job>.json (through host.ps1),
# to show progress and a clear message if something goes wrong. Only on this computer.
# status.json is only for messages about the whole app (like the one-time setup).
$StatusFile = Join-Path $AppDir 'status.json'
$ResultsDir = Join-Path $AppDir 'results'
$script:lastGlobal = ''
$script:jobStatus  = @{}

function Write-JobStatus([string]$jobId, [string]$state, [string]$text, [int]$percent = -1) {
    if (-not $jobId) { return }
    $obj = [ordered]@{ job = $jobId; state = $state; text = $text; percent = $percent }
    $json = $obj | ConvertTo-Json -Compress
    if ($script:jobStatus[$jobId] -eq $json) { return }
    $script:jobStatus[$jobId] = $json
    try {
        if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }
        [System.IO.File]::WriteAllText((Join-Path $ResultsDir ($jobId + '.json')), $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
}

function Write-GlobalStatus([string]$state, [string]$text) {
    $obj = [ordered]@{ job = ''; state = $state; text = $text; percent = -1 }
    $json = $obj | ConvertTo-Json -Compress
    if ($json -eq $script:lastGlobal) { return }
    $script:lastGlobal = $json
    try { [System.IO.File]::WriteAllText($StatusFile, $json, (New-Object System.Text.UTF8Encoding($false))) } catch {}
}

# Old results nobody picked up (the Chrome box was closed)
try {
    if (Test-Path $ResultsDir) {
        Get-ChildItem -Path $ResultsDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
} catch {}
Write-GlobalStatus 'ready' ''

# Status of one download: its line in the list, and its Chrome box
function Write-Status($d, [string]$state, [string]$text, [int]$percent = -1) {
    if ($percent -ge 0) { $d.Percent = $percent }
    if ($text -ne $d.Step -or $d.Percent -ne $d.ShownPct) {
        $d.Step = $text
        $d.ShownPct = $d.Percent
        try {
            $d.Row.SubItems[2].Text = $text
            if ($d.Percent -ge 0) { $d.Row.SubItems[3].Text = [string]$d.Percent } else { $d.Row.SubItems[3].Text = '' }
        } catch {}
    }
    if ($d.Mode -eq 'download') { Write-JobStatus $d.JobId $state $text $percent }
}

# Short reason for the Chrome box, from yt-dlp's last ERROR line
function Get-ShortError($d) {
    $e = ([string]$d.LastErr) -replace '^ERROR:\s*', '' -replace '^\[[^\]]+\]\s*[^:]*:\s*', ''
    if ($e.Length -gt 140) { $e = $e.Substring(0, 140) + '...' }
    return $e
}

function Quote-Arg([string]$a) {
    return '"' + $a.Replace('"', '\"') + '"'
}

function Start-Reader($stream, $queue) {
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
        param($reader, $queue)
        while ($true) {
            $line = $reader.ReadLine()
            if ($line -eq $null) { break }
            $queue.Enqueue($line)
        }
    }).AddArgument($stream).AddArgument($queue)
    $handle = $ps.BeginInvoke()
    return @{ PS = $ps; Handle = $handle }
}

# A message box waits its turn, so it never stops the other downloads from moving
function Add-Popup([string]$text, [string]$buttons = 'OK', [string]$action = '', $d = $null) {
    [void]$script:popups.Add(@{ Text = $text; Buttons = $buttons; Action = $action; D = $d })
}

function Show-NextPopup {
    if ($script:popupOpen -or $script:popups.Count -eq 0) { return }
    $p = $script:popups[0]
    $script:popups.RemoveAt(0)
    $script:popupOpen = $true
    try {
        $ans = [System.Windows.Forms.MessageBox]::Show($p.Text, 'Video Downloader', $p.Buttons)
        if ($ans -eq 'Yes') {
            switch ($p.Action) {
                'log'    { Open-Log $p.D }
                'signin' { Start-SignInRetry $p.D }
            }
        }
    } finally { $script:popupOpen = $false }
}

function Get-Active {
    return @($script:downloads | Where-Object { $_.State -eq 'running' -or $_.State -eq 'waiting' })
}

function Get-Running {
    return @($script:downloads | Where-Object { $_.State -eq 'running' })
}

function Update-Busy {
    $script:busy = $script:hold -or $script:installing -or (@(Get-Running).Count -gt 0)
    $running = @(Get-Running).Count -gt 0
    $btnUpdate.Enabled = -not $script:busy
    $btnChange.Enabled = -not $running
}

# Setup holds new downloads until the tools are ready
function Set-Busy([bool]$busy) {
    $script:hold = $busy
    if (-not $busy) {
        $btnDownload.Text = 'Download'
        $btnDownload.Enabled = $true
    }
    Update-Busy
}

$KindNames = @{ video = 'Video'; mp3 = 'MP3'; best = 'Best sound'; update = 'Update' }

# Adds a download to the list. It starts as soon as there is a free spot.
function New-Download([string]$url, [string]$kind, [string]$jobId = '', [string]$ua = '') {
    $script:nextId++
    $d = @{
        Id = $script:nextId; JobId = $jobId; Url = $url; Kind = $kind; Ua = $ua
        Mode = 'download'; FromButton = [bool]$jobId
        State = 'waiting'; Step = ''; Percent = -1; ShownPct = -2; Title = ''
        Proc = $null; Queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new(); Readers = @()
        Log = $null; LogPath = ''; LastErr = ''; Stopped = $false
        NetfreeBlocked = $false; PageStep = $false; Part = 0; LastPct = -1
        StartTime = (Get-Date); LastOutput = (Get-Date)
        Attempt = 0; BaseArgs = @(); BaseArgsPlain = @(); TriedPlain = $false; Refreshed = $false
        CookieCopy = ''
    }
    if ($kind -eq 'update') { $d.Mode = 'update' }
    $name = $url
    if ($kind -eq 'update') { $name = 'yt-dlp' }
    $item = New-Object System.Windows.Forms.ListViewItem($name)
    [void]$item.SubItems.Add($KindNames[$kind])
    [void]$item.SubItems.Add('')
    [void]$item.SubItems.Add('')
    $item.Tag = $d.Id
    $d.Row = $item
    [void]$lstJobs.Items.Add($item)
    try { $item.EnsureVisible() } catch {}
    [void]$script:downloads.Add($d)
    Write-Status $d 'waiting' 'Waiting for a free spot...'
    return $d
}

# The YouTube pass for one download. yt-dlp writes the pass file back when it ends,
# so each download gets its own copy - two at once could spoil a shared file.
function Get-RunCookieArgs($d, [string[]]$passArgs) {
    if ($passArgs.Count -ge 2 -and $passArgs[0] -eq '--cookies') {
        try {
            if (-not (Test-Path $RunDir)) { New-Item -ItemType Directory -Path $RunDir -Force | Out-Null }
            $copy = Join-Path $RunDir ("pass-$($d.Id).txt")
            Copy-Item -LiteralPath $passArgs[1] -Destination $copy -Force
            $d.CookieCopy = $copy
            return @('--cookies', $copy)
        } catch {}
    }
    return $passArgs
}

# Everything yt-dlp needs for one download (type, folder, pass...)
function Initialize-Download($d) {
    $outTemplate = Join-Path $script:SaveFolder '%(title)s.%(ext)s'
    $argList = @(
        '--ignore-config',                   # ignore any outside settings files
        '--no-write-thumbnail',              # never save the video's picture
        '--no-embed-thumbnail',              # never put a picture inside the file
        '--no-check-certificate',            # needed on NetFree (NetFree certificate)
        '--socket-timeout', '20',            # do not hang forever on a stuck connection
        '--retries', '3',
        '--fragment-retries', '3',
        '-v',                                # full details go to the download's details file
        '--no-playlist',
        '--newline',
        '--progress-template', 'download:[PROG] %(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
        '--ffmpeg-location', $ToolsDir,
        '--js-runtimes', ('deno:' + $Deno),
        '--windows-filenames',
        '--no-mtime',
        '-o', $outTemplate
    )

    if ($d.Kind -eq 'best') {
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
    } elseif ($d.Kind -eq 'mp3') {
        # Same best source as "Best sound" (no DRC, original language, highest bitrate),
        # then the top MP3 setting: 320 kbps. Lower the level by 1.5 dB while converting:
        # loud songs otherwise go over the top after MP3 and crackle on playback.
        $argList += @(
            '-f', 'ba[format_id!*=drc]/ba/b',
            '-S', 'lang,abr,acodec:opus',
            '-x', '--audio-format', 'mp3', '--audio-quality', '320K',
            '--postprocessor-args', 'ExtractAudio:-af volume=-1.5dB'
        )
    } else {
        # Prefer regular MP4 (H.264) up to 1080p, so it plays on any Windows computer.
        # Sound: YouTube's own AAC track, copied in with no re-encode. Skip the squashed-volume
        # "DRC" copy; the highest AAC bitrate wins (256k when the account has it).
        $argList += @(
            '-f', 'bv*[height<=1080][ext=mp4][vcodec^=avc]+ba[ext=m4a][format_id!*=drc]/bv*[height<=1080][ext=mp4][vcodec^=avc]+ba[ext=m4a]/bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b',
            '--merge-output-format', 'mp4'
        )
    }
    $passArgs = @(Get-CookieArgs)
    if ($d.FromButton -and (Test-Path $ExtCookies)) { $passArgs = @('--cookies', $ExtCookies) }
    $ua = [string]$d.Ua
    if (-not $ua -and $script:cookieMode -eq 'Chrome button' -and (Test-Path $ExtUA)) {
        try { $ua = ([System.IO.File]::ReadAllText($ExtUA)).Trim() } catch {}
    }
    if ($ua) { $argList += @('--user-agent', $ua) }
    $d.BaseArgsPlain = @($argList)
    $d.BaseArgs = @($argList) + @(Get-RunCookieArgs $d $passArgs)
    $d.Attempt = 0
}

function Start-YtDlp($d, [string[]]$argList, [bool]$append = $false) {
    if (-not (Test-Path $YtDlp)) {
        Write-Status $d 'failed' 'The downloader tool is missing. Close and reopen Video Downloader to set it up again.'
        Complete-Download $d 'failed'
        Add-Popup "yt-dlp.exe is missing from:`n$ToolsDir"
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

    $d.LastErr = ''
    $d.NetfreeBlocked = $false
    $d.PageStep = $false
    $d.Part = 0
    $d.LastPct = -1
    $d.StartTime = Get-Date
    $d.LastOutput = Get-Date
    $d.State = 'running'
    try {
        if ($d.Log) { $d.Log.Dispose() }
        if (-not $d.LogPath) {
            if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }
            $d.LogPath = Join-Path $LogsDir ((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss') + "_$($d.Id).txt")
        }
        $d.Log = New-Object System.IO.StreamWriter($d.LogPath, $append, [System.Text.Encoding]::UTF8)
        if ($append) { $d.Log.WriteLine(''); $d.Log.WriteLine('========== Next try ==========') }
        $d.Log.AutoFlush = $true
        $d.Log.WriteLine("Started: " + (Get-Date).ToString('MM/dd/yyyy hh:mm:ss tt'))
        $d.Log.WriteLine("App version: $AppVersion   YouTube pass: $($script:cookieMode)   From Chrome button: $($d.FromButton)")
        $d.Log.WriteLine("Command: yt-dlp " + $psi.Arguments)
    } catch { $d.Log = $null }

    try {
        $d.Proc = [System.Diagnostics.Process]::Start($psi)
    } catch {
        $txtLog.AppendText($_.Exception.Message + "`r`n")
        Write-Status $d 'failed' ('Could not start the downloader. Details: ' + $_.Exception.Message)
        Complete-Download $d 'failed'
        return
    }
    $d.Readers = @(
        (Start-Reader $d.Proc.StandardOutput $d.Queue),
        (Start-Reader $d.Proc.StandardError $d.Queue)
    )
    Update-Busy
}

function Start-Attempt($d) {
    $a = @($d.BaseArgs) + @($script:clientTries[$d.Attempt]) + @($d.Url)
    Start-YtDlp $d $a ($d.Attempt -gt 0)
}

# A download ended (done, failed or stopped): tidy up and color its line
function Complete-Download($d, [string]$state) {
    $d.State = $state
    $d.Proc = $null
    foreach ($r in $d.Readers) { try { $r.PS.Dispose() } catch {} }
    $d.Readers = @()
    if ($d.Log) { try { $d.Log.Dispose() } catch {}; $d.Log = $null }
    if ($d.CookieCopy) { Remove-Item -LiteralPath $d.CookieCopy -Force -ErrorAction SilentlyContinue; $d.CookieCopy = '' }
    # Keep a copy of the newest details where it always was
    if ($d.LogPath -and (Test-Path $d.LogPath)) { try { Copy-Item -LiteralPath $d.LogPath -Destination $LogFile -Force } catch {} }
    try {
        switch ($state) {
            'done'    { $d.Row.ForeColor = [System.Drawing.Color]::FromArgb(26, 127, 55) }
            'failed'  { $d.Row.ForeColor = [System.Drawing.Color]::FromArgb(180, 35, 24) }
            default   { $d.Row.ForeColor = [System.Drawing.Color]::Gray }
        }
    } catch {}
    Update-Busy
}

function Handle-Line($d, [string]$line) {
    $d.LastOutput = Get-Date
    if ($d.Log) { try { $d.Log.WriteLine($line) } catch {} }
    if ($line -match '^\[debug\]') { return }
    if ($line -match '^\[PROG\]\s*([\d\.]+)%') {
        $p = [int][math]::Floor([double]$Matches[1])
        if ($p -lt 0 -or $p -gt 100) { return }
        # Which part: a video download gets the picture first, then the sound
        $what = 'sound'
        if ($d.Kind -eq 'video') {
            $what = 'video'
            if ($d.Part -ge 2) { $what = 'sound (part 2 of 2)' }
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
            if ($more.Count) { $extra = '  (' + ($more -join ', ') + ')' }
        }
        $d.Percent = $p
        $d.Step = "Downloading $what$extra"
        $d.ShownPct = $p
        try { $d.Row.SubItems[2].Text = "Downloading $what$extra"; $d.Row.SubItems[3].Text = [string]$p } catch {}
        if ($p -ne $d.LastPct) {
            $d.LastPct = $p
            if ($d.Mode -eq 'download') { Write-JobStatus $d.JobId 'downloading' "Downloading $what... $p%" $p }
        }
        return
    }
    if ($d.Mode -eq 'update') { $txtLog.AppendText($line + "`r`n") }

    # Show the video's name in the list as soon as yt-dlp knows it
    if ($line -match '^\[download\] Destination: (.+)$' -or $line -match '^\[Merger\] Merging formats into "(.+)"$') {
        $t = [System.IO.Path]::GetFileNameWithoutExtension($Matches[1].Trim())
        if ($t -and -not $d.Title) { $d.Title = $t; try { $d.Row.Text = $t } catch {} }
    }

    # Is NetFree blocking THIS video? (the video page itself, or the video data)
    if ($line -match '^\[youtube\] [^:]+: Downloading webpage$') { $d.PageStep = $true }
    elseif ($line -match '^\[(youtube|info|download)\]') { $d.PageStep = $false }
    $blockedNow = $false
    if ($d.PageStep -and $line -match 'HTTP Error 418') { $blockedNow = $true }
    if ($line -match '^ERROR:.*(HTTP Error 418|Blocked by NetFree)') { $blockedNow = $true }
    if ($line -match 'unable to download video data.*418') { $blockedNow = $true }
    if ($blockedNow -and -not $d.NetfreeBlocked) {
        $d.NetfreeBlocked = $true
        Write-Status $d 'failed' "Blocked by NetFree. This video is not approved yet. Open it and click 'send the video for review'."
        # Stop right away - no point retrying
        if ($d.Proc -ne $null -and -not $d.Proc.HasExited) {
            try { Start-Process taskkill.exe -ArgumentList ('/F /T /PID ' + $d.Proc.Id) -WindowStyle Hidden } catch {}
        }
        return
    }

    $step = ''
    if ($line -match '^ERROR:') { $d.LastErr = $line }
    elseif ($line -match '^\[download\] Destination:') { $d.Part++ }
    elseif ($line -match '^\[Merger\]')        { $step = 'Joining video and sound...' }
    elseif ($line -match '^\[ExtractAudio\]')  { $step = $(if ($d.Kind -eq 'best') { 'Saving the sound...' } else { 'Making the MP3...' }) }
    elseif ($line -match '^\[youtube\].*Downloading') { $step = 'Getting video info...' }
    if ($step -and -not $d.NetfreeBlocked) { Write-Status $d 'working' $step $d.Percent }
}

# What happens when one yt-dlp run ends: done, try another way, or a clear failure
function Complete-Run($d) {
    $code = $d.Proc.ExitCode
    foreach ($r in $d.Readers) { try { $r.PS.Dispose() } catch {} }
    $d.Readers = @()
    $d.Proc = $null
    if ($d.Log) { try { $d.Log.WriteLine("Exit code: $code") } catch {} }
    $fromApp = -not $d.FromButton

    if ($d.Stopped) {
        Write-Status $d 'failed' 'Stopped in the Video Downloader window.'
        try { $d.Row.SubItems[2].Text = 'Stopped.' } catch {}
        Complete-Download $d 'stopped'
        return
    }

    if ($d.Mode -eq 'update') {
        if ($code -eq 0) { Write-Status $d 'done' 'Update finished.' 100; $lblStatus.Text = 'Update finished.'; Complete-Download $d 'done' }
        else { Write-Status $d 'failed' 'Update did not work. See the details below.'; $lblStatus.Text = 'Update did not work. See the details below.'; Complete-Download $d 'failed' }
        return
    }

    if ($d.NetfreeBlocked) {
        Write-Status $d 'failed' "Blocked by NetFree. This video is not approved yet. Open it and click 'send the video for review'."
        Complete-Download $d 'failed'
        if ($fromApp) {
            Add-Popup ("BLOCKED BY NETFREE`n`nNetFree has not approved this video, so it cannot be downloaded:`n$($d.Url)`n`n" +
                       "To ask for it: open the video in your browser and click 'send the video for review'.")
        }
        return
    }

    $cookieProblem = ($d.LastErr -match 'cookie database|decrypt|cookies from|cookies file|Netscape')
    if ($code -ne 0 -and $cookieProblem -and -not $d.TriedPlain) {
        $d.TriedPlain = $true
        $d.BaseArgs = @($d.BaseArgsPlain)
        $d.Attempt = 0
        Write-Status $d 'working' 'Trying without the YouTube pass...'
        Start-Attempt $d
        return
    }
    if ($code -ne 0 -and $cookieProblem) {
        Write-Status $d 'failed' 'Could not read the YouTube pass. Reload this page and try again.'
        Complete-Download $d 'failed'
        if ($fromApp) { Add-Popup "The app could not read the YouTube pass from $($script:cookieMode).`n`nOpen the details file?" 'YesNo' 'log' $d }
        return
    }
    if ($code -ne 0 -and ($d.Attempt + 1) -lt $script:clientTries.Count) {
        $d.Attempt++
        Write-Status $d 'working' "Trying another way ($($d.Attempt + 1) of $($script:clientTries.Count))..."
        Start-Attempt $d
        return
    }

    if ($code -eq 0) {
        $d.Percent = 100
        Write-Status $d 'done' "Done! Saved in $($script:SaveFolder)" 100
        try { $d.Row.SubItems[2].Text = 'Done!' } catch {}
        Complete-Download $d 'done'
        return
    }

    if ($d.LastErr -match 'not a bot|Sign in to confirm') {
        Write-Status $d 'failed' 'YouTube asked to confirm you are not a robot. Reload this page, then click the button again.'
        Complete-Download $d 'failed'
        if ($script:cookieMode -eq 'In-app browser' -and -not $d.Refreshed) {
            $extra = ''
            if (-not (Test-Path $SignInCookies)) { $extra = "First, let's set up YouTube access.`n`n" }
            Add-Popup ($extra + "Open the app's YouTube browser now to refresh access? (Pictures are blocked. If YouTube asks, sign in once.) Then it will try again.") 'YesNo' 'signin' $d
            return
        }
        if ($fromApp) {
            Add-Popup ("YouTube is asking to confirm you are not a robot.`n`n" +
                       "Fix: open the video in Chrome and press the Download button on the page (bottom right). That gives the app a fresh YouTube pass.`n`n" +
                       "Open the details file (to send for help)?") 'YesNo' 'log' $d
        }
        return
    }
    $why = Get-ShortError $d
    if ($why) { Write-Status $d 'failed' "Download failed: $why" }
    else { Write-Status $d 'failed' 'Download failed. See the Video Downloader window for the reason.' }
    Complete-Download $d 'failed'
    if ($fromApp) {
        $msg = "The download did not work:`n$($d.Url)`n`n" +
               "Most common reasons:`n" +
               "1. NetFree has not approved this video yet. Open it in your browser and click 'send the video for review'.`n" +
               "2. The link is wrong. Copy it again from the video page.`n" +
               "3. YouTube changed something. Click 'Update downloader' and try again."
        if ($d.LastErr) { $msg += "`n`nDetails: " + $d.LastErr }
        $msg += "`n`nOpen the details file (to send for help)?"
        Add-Popup $msg 'YesNo' 'log' $d
    }
}

# After the in-app sign-in, try the same download again
function Start-SignInRetry($d) {
    $d.Refreshed = $true
    $ok = Show-SignIn
    if (-not $ok) { return }
    $d.BaseArgs = @($d.BaseArgsPlain) + @(Get-RunCookieArgs $d @(Get-CookieArgs))
    $d.Attempt = 0
    $d.Stopped = $false
    try { $d.Row.ForeColor = [System.Drawing.SystemColors]::WindowText } catch {}
    Write-Status $d 'working' 'Trying again with fresh access...'
    Start-Attempt $d
}

# Starts waiting downloads while there are free spots
function Start-Waiting {
    if ($script:hold -or $script:installing) { return }
    $waiting = @($script:downloads | Where-Object { $_.State -eq 'waiting' })
    if ($waiting.Count -eq 0) { return }
    if (-not (Test-ToolsReady)) { return }
    $updating = @(Get-Running | Where-Object { $_.Mode -eq 'update' }).Count -gt 0
    if ($updating) { return }
    $free = [int]$numMax.Value - @(Get-Running).Count
    foreach ($d in $waiting) {
        if ($free -le 0) {
            Write-Status $d 'waiting' "Waiting for a free spot ($(@(Get-Running).Count) downloads running)..."
            continue
        }
        $free--
        Write-Status $d 'working' 'Starting...' 0
        Initialize-Download $d
        Start-Attempt $d
    }
}

# One sum-up line for all downloads
function Update-Summary {
    $running = @(Get-Running)
    $waiting = @($script:downloads | Where-Object { $_.State -eq 'waiting' }).Count
    if ($script:hold) { return }   # setup shows its own steps
    if ($running.Count -eq 0 -and $waiting -eq 0) { return }
    $sum = 0
    foreach ($d in $running) { if ($d.Percent -gt 0) { $sum += $d.Percent } }
    if ($running.Count -gt 0) { $progress.Value = [int][math]::Min(100, [math]::Floor($sum / $running.Count)) }
    $t = "$($running.Count) downloading"
    if ($waiting -gt 0) { $t += ", $waiting waiting" }
    $lblStatus.Text = $t + '.'
}

$script:wasActive = $false
$script:inTick = $false
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    if (-not $script:inTick) {
        $script:inTick = $true
        try {
            foreach ($d in @(Get-Running)) {
                $line = $null
                while ($d.Queue.TryDequeue([ref]$line)) { Handle-Line $d $line }
                if ($d.Proc -eq $null) { continue }

                # Show that it is still alive, and warn if nothing is happening
                if (-not $d.Proc.HasExited) {
                    $total = [int]((Get-Date) - $d.StartTime).TotalSeconds
                    $idle  = [int]((Get-Date) - $d.LastOutput).TotalSeconds
                    if ($idle -ge 15 -and $d.LastPct -lt 0 -and -not $d.NetfreeBlocked) {
                        Write-Status $d 'working' "Still waiting for YouTube ($total sec)..."
                    }
                    continue
                }
                $allDone = $true
                foreach ($r in $d.Readers) { if (-not $r.Handle.IsCompleted) { $allDone = $false } }
                if (-not $allDone) { continue }
                while ($d.Queue.TryDequeue([ref]$line)) { Handle-Line $d $line }
                Complete-Run $d
            }
            Start-Waiting
            Update-Summary
            $active = @(Get-Active).Count -gt 0
            if ($script:wasActive -and -not $active -and -not $script:hold) {
                $progress.Value = 0
                $done = @($script:downloads | Where-Object { $_.State -eq 'done' -and $_.Mode -eq 'download' }).Count
                if ($done -gt 0) { $lblStatus.Text = 'All finished. Click "Open folder" to see the files.' }
                else { $lblStatus.Text = 'Ready.' }
            }
            $script:wasActive = $active
        } finally { $script:inTick = $false }
    }
    # Message boxes come last, one at a time. While one is open, the timer keeps the downloads moving.
    Show-NextPopup
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
            Write-GlobalStatus 'setup' 'Video Downloader could not finish its setup. Close and reopen it to try again.'
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
            Write-GlobalStatus 'setup' 'Video Downloader could not finish its setup. Close and reopen it to try again.'
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

function Open-Log($d = $null) {
    $path = $LogFile
    if ($d -and $d.LogPath) { $path = $d.LogPath }
    if (Test-Path $path) { Start-Process notepad.exe -ArgumentList (Quote-Arg $path) }
}

function Stop-Download($d) {
    if ($d.State -eq 'waiting') {
        $d.Stopped = $true
        Write-Status $d 'failed' 'Stopped in the Video Downloader window.'
        try { $d.Row.SubItems[2].Text = 'Stopped.' } catch {}
        Complete-Download $d 'stopped'
        return
    }
    if ($d.State -eq 'running' -and $d.Proc -ne $null -and -not $d.Proc.HasExited) {
        $d.Stopped = $true
        if ($d.Log) { try { $d.Log.WriteLine("STOPPED by user. Last step: " + $d.Step) } catch {} }
        try { Start-Process taskkill.exe -ArgumentList ('/F /T /PID ' + $d.Proc.Id) -WindowStyle Hidden -Wait } catch {}
        try { if (-not $d.Proc.HasExited) { $d.Proc.Kill() } } catch {}
        try { $d.Row.SubItems[2].Text = 'Stopping...' } catch {}
    }
}

# The downloads picked in the list
function Get-Selected {
    $ids = @($lstJobs.SelectedItems | ForEach-Object { $_.Tag })
    return @($script:downloads | Where-Object { $ids -contains $_.Id })
}

# ---------- Buttons ----------
# Adds what is on the clipboard. Pasting again adds more links on new lines.
$btnPaste.Add_Click({
    try {
        $clip = [System.Windows.Forms.Clipboard]::GetText()
        if ($clip) {
            $clip = $clip.Trim()
            if ($txtUrl.Text.Trim()) { $txtUrl.AppendText("`r`n" + $clip) } else { $txtUrl.Text = $clip }
        }
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

# Every link in the box becomes its own download. They all start (up to the number
# set in "Downloads at the same time"); the rest wait for a free spot.
$btnDownload.Add_Click({
    if (@(Get-Running | Where-Object { $_.Mode -eq 'update' }).Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show('Please wait until the update finishes.', 'Video Downloader') | Out-Null
        return
    }
    $links = @(($txtUrl.Text -split '\s+') | Where-Object { $_ -match '^https?://' } | Select-Object -Unique)
    if ($links.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Please paste a full video link (starting with https://).', 'Video Downloader') | Out-Null
        return
    }
    try {
        if (-not (Test-Path $script:SaveFolder)) { New-Item -ItemType Directory -Path $script:SaveFolder -Force | Out-Null }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Cannot use this folder:`n$($script:SaveFolder)", 'Video Downloader') | Out-Null
        return
    }
    $kind = 'video'
    if ($rbBest.Checked) { $kind = 'best' } elseif ($rbAudio.Checked) { $kind = 'mp3' }
    foreach ($u in $links) { [void](New-Download $u $kind) }
    $txtUrl.Clear()
    Start-Waiting
})

$btnStop.Add_Click({
    $pick = @(Get-Selected | Where-Object { $_.State -eq 'running' -or $_.State -eq 'waiting' })
    if ($pick.Count -eq 0) {
        $pick = @(Get-Active)
        if ($pick.Count -eq 0) { return }
        if ($pick.Count -gt 1) {
            $ans = [System.Windows.Forms.MessageBox]::Show("Stop all $($pick.Count) downloads?`n`n(To stop just one, click it in the list first.)", 'Video Downloader', 'YesNo')
            if ($ans -ne 'Yes') { return }
        }
    }
    # Waiting ones first, so a freed spot does not start them
    foreach ($d in @($pick | Where-Object { $_.State -eq 'waiting' })) { Stop-Download $d }
    foreach ($d in $pick) { Stop-Download $d }
})

$btnDetails.Add_Click({
    $pick = @(Get-Selected)
    if ($pick.Count -gt 0) { Open-Log $pick[0] }
    elseif ($script:downloads.Count -gt 0) { Open-Log $script:downloads[$script:downloads.Count - 1] }
    else { Open-Log }
})

$btnClear.Add_Click({
    foreach ($d in @($script:downloads | Where-Object { $_.State -in @('done', 'failed', 'stopped') })) {
        try { $lstJobs.Items.Remove($d.Row) } catch {}
        $script:downloads.Remove($d)
    }
})

# Double-click a line: finished = open the folder, otherwise show its details
$lstJobs.Add_DoubleClick({
    $pick = @(Get-Selected)
    if ($pick.Count -eq 0) { return }
    if ($pick[0].State -eq 'done') { $btnOpen.PerformClick() } else { Open-Log $pick[0] }
})

$numMax.Add_ValueChanged({
    $script:MaxAtOnce = [int]$numMax.Value
    Save-MaxAtOnce
})

$btnUpdate.Add_Click({
    if ($script:busy) {
        [System.Windows.Forms.MessageBox]::Show('Please wait until the downloads finish.', 'Video Downloader') | Out-Null
        return
    }
    $lblStatus.Text = 'Updating...'
    $txtLog.Clear()
    $d = New-Download '' 'update'
    Start-YtDlp $d @('-U', '--no-check-certificate')
})

$form.Add_FormClosing({
    $active = @(Get-Active)
    if ($active.Count -gt 0) {
        $ans = [System.Windows.Forms.MessageBox]::Show("$($active.Count) download(s) still running or waiting. Stop them and close?", 'Video Downloader', 'YesNo')
        if ($ans -ne 'Yes') { $_.Cancel = $true; return }
        foreach ($d in @($active | Where-Object { $_.State -eq 'waiting' })) { Stop-Download $d }
        foreach ($d in $active) { Stop-Download $d }
    }
})

# ---------- Chrome button (extension) ----------
$ExtensionId = 'bagidnomlmojifgdgmgicinhabkhbahb'
$JobsDir     = Join-Path $AppDir 'jobs'
$ExtCookies  = Join-Path $AppDir 'ext-cookies.txt'
$ExtUA       = Join-Path $AppDir 'ext-useragent.txt'

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

# Pick up videos sent from the Chrome button. Every click starts right away
# (up to the number set in "Downloads at the same time"); no waiting in line for the one before.
$jobTimer = New-Object System.Windows.Forms.Timer
$jobTimer.Interval = 300
$jobTimer.Add_Tick({
    if (-not (Test-Path $JobsDir)) { return }
    $files = @(Get-ChildItem -Path $JobsDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($files.Count -eq 0) { return }
    if (-not (Test-ToolsReady)) {
        # Tell the Chrome box why nothing is happening yet
        if ($script:hold) { Write-GlobalStatus 'setup' 'Video Downloader is setting up its tools (one time only). Your download starts when it finishes.' }
        else { Write-GlobalStatus 'setup' 'Video Downloader needs its one-time setup. Close and reopen it, then click Yes.' }
        return
    }
    if ($script:installing) { return }
    Write-GlobalStatus 'ready' ''
    $wasIdle = @(Get-Active).Count -eq 0
    foreach ($f in $files) {
        $job = $null
        try { $job = [System.IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json } catch {}
        Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
        if (-not $job -or -not $job.url) { continue }
        if ($job.ua) { try { [System.IO.File]::WriteAllText($ExtUA, [string]$job.ua) } catch {} }
        $kind = 'video'
        switch ([string]$job.mode) {
            'mp3' { $kind = 'mp3' }
            'wav' { $kind = 'best' }
        }
        [void](New-Download ([string]$job.url) $kind $f.BaseName ([string]$job.ua))
    }
    Start-Waiting
    # Show the window for the first download; later ones do not jump in front of Chrome
    try {
        if ($form.WindowState -eq 'Minimized') { $form.WindowState = 'Normal' }
        if ($wasIdle) { $form.TopMost = $true; $form.Activate(); $form.TopMost = $false }
    } catch {}
})
$jobTimer.Start()
$timer.Start()

[void]$form.ShowDialog()
