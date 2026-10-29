# Puts a "Video Downloader" shortcut on the Desktop
$AppDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script  = Join-Path $AppDir 'downloader.ps1'
$Desktop = [Environment]::GetFolderPath('Desktop')
$Link    = Join-Path $Desktop 'Video Downloader.lnk'

$shell = New-Object -ComObject WScript.Shell
$s = $shell.CreateShortcut($Link)
$s.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$s.Arguments        = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "' + $Script + '"'
$s.WorkingDirectory = $AppDir
$s.WindowStyle      = 7
$s.Description      = 'Video Downloader'
$s.Save()

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("Done! 'Video Downloader' is now on your Desktop.", 'Video Downloader') | Out-Null
