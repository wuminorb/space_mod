# Launch Probably Stolen, wait for the mod loader to finish, then stop the game.
# Saves are snapshotted before the run and restored afterwards if anything changed.
$ErrorActionPreference = 'Stop'
$gameExe = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen.exe'
$logDir  = Join-Path $env:USERPROFILE 'AppData\LocalLow\Questing Goose Studio\Probably Stolen'
$playerLog = Join-Path $logDir 'Player.log'
$backupDir = 'D:\space_mod\.tmp\save-backup'

# --- snapshot saves ---
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Get-ChildItem $backupDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
$saves = Get-ChildItem $logDir -Filter '*.es3' -File
$before = @{}
foreach ($f in $saves) {
    Copy-Item $f.FullName (Join-Path $backupDir $f.Name) -Force
    $before[$f.Name] = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
}
Write-Output ("saves snapshotted: " + $saves.Count)

# --- launch ---
if (Test-Path $playerLog) { Remove-Item $playerLog -Force -ErrorAction SilentlyContinue }
$gameDir = Split-Path $gameExe
$proc = Start-Process -FilePath $gameExe -WorkingDirectory $gameDir -PassThru
Write-Output ("launched pid " + $proc.Id)

$deadline = (Get-Date).AddSeconds(200)
$loaded = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if (Test-Path $playerLog) {
        $content = Get-Content $playerLog -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Contains('mod(s) registered')) { $loaded = $true; break }
    }
    if ($proc.HasExited) { Write-Output 'game exited on its own'; break }
}
Write-Output ("loader finished: " + $loaded)
Start-Sleep -Seconds 8

# --- collect log lines ---
if (Test-Path $playerLog) {
    $lines = Get-Content $playerLog
    $interesting = $lines | Select-String -Pattern 'ModLoader|PrintBottle|print_bottle|patch applied|Harmony|Exception|Error|error' -SimpleMatch:$false
    $interesting | Select-Object -First 200 | ForEach-Object { $_.Line }
}

# --- stop game ---
if (-not $proc.HasExited) {
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
}
Get-Process -Name 'Probably Stolen' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# --- verify saves unchanged ---
$changed = @()
foreach ($f in (Get-ChildItem $logDir -Filter '*.es3' -File)) {
    $nowHash = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
    if (-not $before.ContainsKey($f.Name) -or $before[$f.Name] -ne $nowHash) { $changed += $f.Name }
}
Write-Output ('changed save files: ' + ($changed -join ', '))
foreach ($name in $changed) {
    $src = Join-Path $backupDir $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $logDir $name) -Force
        Write-Output ('restored ' + $name)
    }
}
Write-Output 'DONE'
