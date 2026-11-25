$ErrorActionPreference='Stop'
$managed = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$mine = [DseCecil.AssemblyDefinition]::ReadAssembly('D:\space_mod\print_bottle\bin\Release\PrintBottle.dll')
"--- assembly references ---"
$mine.MainModule.AssemblyReferences | ForEach-Object { "  $($_.Name) $($_.Version)" }
"--- types ---"
function Walk($t) { $t; foreach ($n in $t.NestedTypes) { Walk $n } }
foreach ($x in $mine.MainModule.Types) { foreach ($t in (Walk $x)) { "  $($t.FullName)" } }
"--- methods ---"
$mine.MainModule.Types | ForEach-Object { $_.Methods } | ForEach-Object { "  $($_.Name)" }
"--- method references outside our assembly ---"
$seen = @{}
function WalkRefs($t) {
  foreach ($m in $t.Methods) {
    if (-not $m.HasBody) { continue }
    foreach ($i in $m.Body.Instructions) {
      $op = $i.Operand
      if ($op -is [DseCecil.MethodReference] -and $op.DeclaringType.Scope -isnot [DseCecil.ModuleDefinition]) {
        $k = "$($op.DeclaringType.FullName)::$($op.Name)"
        if (-not $seen.ContainsKey($k)) { $seen[$k] = 1 }
      }
      if ($op -is [DseCecil.FieldReference] -and $op.DeclaringType.Scope -isnot [DseCecil.ModuleDefinition]) {
        $k = "FIELD $($op.DeclaringType.FullName)::$($op.Name)"
        if (-not $seen.ContainsKey($k)) { $seen[$k] = 1 }
      }
    }
  }
  foreach ($n in $t.NestedTypes) { WalkRefs $n }
}
foreach ($x in $mine.MainModule.Types) { WalkRefs $x }
$seen.Keys | Sort-Object
