# Builds the mod with the .NET Framework C# compiler shipped with Windows.
# Use this when no .NET SDK is installed; `dotnet build -c Release` works too.
param(
    [string]$GameDir = 'E:\SteamLibrary\steamapps\common\Probably Stolen'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$managed = Join-Path $GameDir 'Probably Stolen_Data\Managed'
$outDir = Join-Path $root 'bin\Release'
$dll = Join-Path $outDir 'StockpilerBudget.dll'

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found: $csc" }
if (-not (Test-Path $managed)) { throw "game Managed folder not found: $managed" }

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$sources = @(Get-ChildItem (Join-Path $root 'src') -Filter *.cs | ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) { throw "no .cs files under src" }

$refs = @(
    'Assembly-CSharp.dll',
    'UnityEngine.dll',
    'UnityEngine.CoreModule.dll',
    '0Harmony.dll',
    'netstandard.dll'
) | ForEach-Object { '/r:' + (Join-Path $managed $_) }

$cscArgs = @('/nologo', '/target:library', '/langversion:5', '/optimize+', '/debug-', ('/out:' + $dll)) + $refs + $sources

& $csc $cscArgs
if ($LASTEXITCODE -ne 0) { throw "compile failed (exit $LASTEXITCODE)" }

Write-Host "built: $dll"
