param([string]$Arg='')
$ErrorActionPreference='Stop'
$managed='E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm=[DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod=$asm.MainModule
function Walk($t){ $t; foreach($n in $t.NestedTypes){ Walk $n } }
$all=@(foreach($x in $mod.Types){ Walk $x })
foreach($spec in ($Arg -split ';')){
  $parts=$spec.Trim() -split '::'
  $tn=$parts[0]; $mn=$parts[1]
  $t=$all | Where-Object { $_.FullName -eq $tn } | Select-Object -First 1
  if($t -eq $null){ "### TYPE NOT FOUND: $tn"; continue }
  foreach($m in ($t.Methods | Where-Object { $_.Name -eq $mn })){
    "=== $($m.FullName)"
    if(-not $m.HasBody){ '  <no body>'; continue }
    foreach($i in $m.Body.Instructions){
      $op=$i.Operand; $s=''
      if($op -ne $null){
        if($op -is [string]){ $s="'"+$op+"'" }
        elseif($op -is [DseCecil.MethodReference]){ $s=$op.DeclaringType.Name+'::'+$op.Name }
        elseif($op -is [DseCecil.FieldReference]){ $s=$op.DeclaringType.Name+'::'+$op.Name }
        elseif($op -is [DseCecil.Cil.Instruction]){ $s='-> dec_off='+$op.Offset+' ['+$op.OpCode.Name+']' }
        else { $s=$op.ToString() }
      }
      "  {0,5} {1,-12} {2}" -f $i.Offset, $i.OpCode.Name, $s
    }
  }
}
