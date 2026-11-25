param([string]$Needle = 'CreateMachineInventoryWindow')
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
      if ($op -is [DseCecil.MethodReference] -and $op.Name -eq $Needle) { "$($t.FullName)::$($m.Name)  ->  $($op.DeclaringType.FullName)::$($op.Name)" }
      if ($op -is [DseCecil.MethodReference] -and $op.Name -eq 'BottlePrinter') { "$($t.FullName)::$($m.Name)  ->  $($op.DeclaringType.FullName)::BottlePrinter" }
    }
  }
}
