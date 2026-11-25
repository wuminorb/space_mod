# Step 1: launch the game, wait for the mod loader, screenshot the main menu.
$ErrorActionPreference = 'Stop'
$gameExe = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen.exe'
$logDir  = Join-Path $env:USERPROFILE 'AppData\LocalLow\Questing Goose Studio\Probably Stolen'
$playerLog = Join-Path $logDir 'Player.log'
$backupDir = 'D:\space_mod\.tmp\save-backup2'

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Get-ChildItem $backupDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
$saves = Get-ChildItem $logDir -Filter '*.es3' -File
foreach ($f in $saves) { Copy-Item $f.FullName (Join-Path $backupDir $f.Name) -Force }
$saveHashes = @{}
foreach ($f in $saves) { $saveHashes[$f.Name] = (Get-FileHash $f.FullName -Algorithm SHA256).Hash }
$saveHashes.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Set-Content 'D:\space_mod\.tmp\save-before.txt'
Write-Output ("saves snapshotted: " + $saves.Count)

if (Test-Path $playerLog) { Remove-Item $playerLog -Force -ErrorAction SilentlyContinue }
Start-Process -FilePath $gameExe -WorkingDirectory (Split-Path $gameExe) | Out-Null
Write-Output 'launched'

$deadline = (Get-Date).AddSeconds(180)
$loaded = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if (Test-Path $playerLog) {
        $content = Get-Content $playerLog -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Contains('mod(s) registered')) { $loaded = $true; break }
    }
}
Write-Output ("loader finished: " + $loaded)
Start-Sleep -Seconds 12

Add-Type -AssemblyName System.Drawing, System.Windows.Forms
$proc = Get-Process -Name 'Probably Stolen' -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1
if ($proc) {
    Write-Output ("game process: id=" + $proc.Id + " handle=" + $proc.MainWindowHandle + " title=" + $proc.MainWindowTitle)
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Fg {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    [Win32Fg]::ShowWindow($proc.MainWindowHandle, 3) | Out-Null
    [Win32Fg]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    Start-Sleep -Seconds 2
} else {
    Write-Output 'game process NOT found'
}
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save('D:\space_mod\.tmp\shot-menu.png', [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output 'screenshot saved'
