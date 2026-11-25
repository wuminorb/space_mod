param(
    [string]$Types = '',
    [string]$Methods = '',   # "Type::Method;Type::Method"
    [string]$Search = ''     # substring to look for in ldstr
)
$ErrorActionPreference = 'Stop'
$managed = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod = $asm.MainModule

function Walk($t) { $t; foreach ($n in $t.NestedTypes) { Walk $n } }
$all = @(foreach ($x in $mod.Types) { Walk $x })

function Fmt-Op($i) {
  $op = $i.Operand; $s = ''
  if ($op -ne $null) {
    if ($op -is [string]) { $s = "'" + $op + "'" }
    elseif ($op -is [DseCecil.MethodReference]) { $s = $op.DeclaringType.Name + '::' + $op.Name }
    elseif ($op -is [DseCecil.FieldReference]) { $s = $op.DeclaringType.Name + '::' + $op.Name }
    else { $s = $op.ToString() }
  }
  "  {0,-6} {1,-12} {2}" -f ('IL_' + $i.Offset), $i.OpCode.Name, $s
}

function DumpType($name) {
  $t = $all | Where-Object { $_.FullName -eq $name } | Select-Object -First 1
  if ($t -eq $null) { "### TYPE NOT FOUND: $name"; return }
  "### TYPE $($t.FullName)  base=$($t.BaseType.FullName)  public=$($t.IsPublic)  attrs=$($t.Attributes)"
  $t.Fields | ForEach-Object { "  FIELD $($_.FieldType.FullName) $($_.Name) static=$($_.IsStatic) const=$($_.HasConstant) val=$(if($_.HasConstant){$_.Constant})" }
  $t.Properties | ForEach-Object { "  PROP $($_.PropertyType.FullName) $($_.Name)" }
  $t.Methods | ForEach-Object { "  METHOD $($_.ReturnType.Name) $($_.Name)(" + (($_.Parameters | ForEach-Object { $_.ParameterType.Name + ' ' + $_.Name }) -join ', ') + ") public=$($_.IsPublic) static=$($_.IsStatic)" }
  $t.NestedTypes | ForEach-Object { "  NESTED $($_.FullName)" }
}

if ($Types -ne '') {
  foreach ($n in ($Types -split ';')) { DumpType $n.Trim() }
}

if ($Methods -ne '') {
  foreach ($spec in ($Methods -split ';')) {
    $parts = $spec.Trim() -split '::'
    $tn = $parts[0]; $mn = $parts[1]
    $t = $all | Where-Object { $_.FullName -eq $tn } | Select-Object -First 1
    if ($t -eq $null) { "### TYPE NOT FOUND: $tn"; continue }
    foreach ($m in ($t.Methods | Where-Object { $_.Name -eq $mn })) {
      "=== $($m.FullName)  static=$($m.IsStatic)"
      if (-not $m.HasBody) { '  <no body>'; continue }
      foreach ($v in $m.Body.Variables) { "  local $($v.VariableType.Name) V_$($v.Index)" }
      foreach ($i in $m.Body.Instructions) { Fmt-Op $i }
    }
  }
}

if ($Search -ne '') {
  "### STRINGS containing '$Search'"
  $seen = @{}
  foreach ($t in $all) {
    foreach ($m in $t.Methods) {
      if (-not $m.HasBody) { continue }
      foreach ($i in $m.Body.Instructions) {
        if ($i.OpCode.Name -eq 'ldstr' -and $i.Operand -is [string] -and $i.Operand.Contains($Search)) {
          $k = $i.Operand
          if (-not $seen.ContainsKey($k)) { $seen[$k] = New-Object System.Collections.ArrayList }
          $loc = "$($t.FullName)::$($m.Name)"
          if (-not $seen[$k].Contains($loc)) { [void]$seen[$k].Add($loc) }
        }
      }
    }
  }
  foreach ($k in ($seen.Keys | Sort-Object)) {
    "  '$k'"
    foreach ($loc in $seen[$k]) { "      @ $loc" }
  }
}
