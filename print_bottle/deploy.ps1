# Builds and copies the mod into the game's Mods folder.
param(
    [string]$GameDir = 'E:\SteamLibrary\steamapps\common\Probably Stolen',
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $NoBuild) {
    & (Join-Path $root 'build.ps1') -GameDir $GameDir
    if ($LASTEXITCODE -ne 0) { throw "build failed, nothing deployed" }
}

$dll = Join-Path $root 'bin\Release\PrintBottle.dll'
if (-not (Test-Path $dll)) { throw "missing build output: $dll" }

$dest = Join-Path $GameDir 'Mods\print_bottle'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item $dll -Destination $dest -Force
Copy-Item (Join-Path $root 'manifest.xml') -Destination $dest -Force

# Optional mod resources: Localization/*.csv (button labels), plus any future asset folders.
foreach ($dir in @('Localization', 'Textures', 'Sounds', 'Books', 'LootTables')) {
    $src = Join-Path $root $dir
    if (Test-Path $src) {
        Copy-Item $src -Destination $dest -Recurse -Force
    }
}

Write-Host "deployed to: $dest"
Write-Host "First install / changed DLL: start game -> Mods -> select the mod -> Activate -> restart game."
