param(
    [int]$X = 0,
    [int]$Y = 0,
    [string]$Shot = '',
    [int]$WaitMs = 2500
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ClickWin32 {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$proc = Get-Process -Name 'Probably Stolen' -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1
if ($proc) {
    [ClickWin32]::ShowWindow($proc.MainWindowHandle, 3) | Out-Null
    [ClickWin32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 500
}

if ($X -gt 0 -or $Y -gt 0) {
    [ClickWin32]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 200
    [ClickWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)   # left down
    Start-Sleep -Milliseconds 80
    [ClickWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)   # left up
    Write-Output "clicked at $X,$Y"
}

Start-Sleep -Milliseconds $WaitMs

if ($Shot -ne '') {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save($Shot, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "screenshot: $Shot"
}
