# One-time setup for the Download button in Chrome
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExtensionId = 'bagidnomlmojifgdgmgicinhabkhbahb'
$ExtDir = Join-Path (Split-Path -Parent $AppDir) 'extension'
Add-Type -AssemblyName System.Windows.Forms

# 1. Tell Chrome where the helper is (this computer only, no admin needed)
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
} catch {
    [System.Windows.Forms.MessageBox]::Show("Setup problem: " + $_.Exception.Message, 'Video Downloader') | Out-Null
}

# 2. Show the steps, open the extension folder and Chrome's extensions page
[System.Windows.Forms.MessageBox]::Show(
    "Add the Download button to Chrome (one time):`n`n" +
    "1. Chrome opens its Extensions page. Turn ON 'Developer mode' (top right).`n" +
    "2. Click 'Load unpacked' (top left).`n" +
    "3. Choose the folder 'extension' (a window with it opens now), then 'Select Folder'.`n`n" +
    "Done. Open any YouTube video in Chrome - a Download box appears at the bottom right.",
    'Video Downloader') | Out-Null
try { Start-Process explorer.exe -ArgumentList ('"' + $ExtDir + '"') } catch {}
$chrome = $null
foreach ($c in @((Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
                 (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
                 (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'))) {
    if ($c -and (Test-Path $c)) { $chrome = $c; break }
}
if ($chrome) { try { Start-Process -FilePath $chrome -ArgumentList 'chrome://extensions/' } catch {} }
