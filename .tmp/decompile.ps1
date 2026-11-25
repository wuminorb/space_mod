param([string]$TypeName = 'MachineBottlePrinter')
$ErrorActionPreference = 'Stop'
$managed = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod = $asm.MainModule

function Walk($t) { $t; foreach ($n in $t.NestedTypes) { Walk $n } }

function Fmt-Op($i) {
  $op = $i.Operand; $s = ''
  if ($op -ne $null) {
    if ($op -is [string]) { $s = "'" + $op + "'" }
    elseif ($op -is [DseCecil.MethodReference]) { $s = $op.DeclaringType.Name + '::' + $op.Name }
    elseif ($op -is [DseCecil.FieldReference]) { $s = $op.DeclaringType.Name + '::' + $op.Name }
    else { $s = $op.ToString() }
  }
  "  {0,-8} {1,-12} {2}" -f ('IL_' + $i.Offset), $i.OpCode.Name, $s
}

function DumpIL($m) {
  "=== $($m.FullName)  (public=$($m.IsPublic) static=$($m.IsStatic))"
  if ($m.HasBody -eq $false) { '  <no body>'; return }
  foreach ($v in $m.Body.Variables) { "  local $($v.VariableType.Name) V_$($v.Index)" }
  foreach ($i in $m.Body.Instructions) { Fmt-Op $i }
}

$t = $mod.GetType($TypeName)
if ($t -eq $null) { "type not found: $TypeName"; exit 1 }
"TYPE: $($t.FullName)  base=$($t.BaseType.FullName)  attrs=$($t.Attributes)"
"--- fields ---"
$t.Fields | ForEach-Object { "  $($_.FieldType.FullName) $($_.Name) (static=$($_.IsStatic) const=$($_.HasConstant) val=$(if($_.HasConstant){$_.Constant}))" }
"--- methods ---"
$t.Methods | ForEach-Object { "  $($_.ReturnType.Name) $($_.Name)(" + (($_.Parameters | ForEach-Object { $_.ParameterType.Name + ' ' + $_.Name }) -join ', ') + ")  public=$($_.IsPublic) static=$($_.IsStatic)" }
"--- nested ---"
$t.NestedTypes | ForEach-Object {
  "NESTED: $($_.FullName)  base=$($_.BaseType.FullName)"
  $_.Fields | ForEach-Object { "    field $($_.FieldType.Name) $($_.Name)" }
  $_.Methods | ForEach-Object { "    method $($_.ReturnType.Name) $($_.Name)(" + (($_.Parameters | ForEach-Object { $_.ParameterType.Name }) -join ', ') + ")" }
}
"================ FULL IL ================"
$targets = @($t)
foreach ($n in $t.NestedTypes) { $targets += $n }
foreach ($tt in $targets) {
  "################ $($tt.FullName)"
  foreach ($m in $tt.Methods) { DumpIL $m }
}
