param([string]$Needle='IsFullEnabled')
$ErrorActionPreference='Stop'
$managed = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod = $asm.MainModule
function Walk($t) { $t; foreach ($n in $t.NestedTypes) { Walk $n } }
$all = @(foreach ($x in $mod.Types) { Walk $x })
foreach ($t in $all) {
  foreach ($m in $t.Methods) {
    if (-not $m.HasBody) { continue }
    foreach ($i in $m.Body.Instructions) {
      $op = $i.Operand
      if ($op -is [DseCecil.MethodReference] -and ($op.Name -eq 'get_IsFullEnabled' -or $op.Name -eq 'get_IsEnabled' -or $op.Name -eq 'SetDeveloperMode')) {
        "$($t.FullName)::$($m.Name)  ->  $($op.DeclaringType.FullName)::$($op.Name)"
      }
    }
  }
}
