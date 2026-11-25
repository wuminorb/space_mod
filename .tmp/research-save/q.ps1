param(
    [string]$Cmd = '',
    [string]$Arg = '',
    [string]$Arg2 = ''
)
$ErrorActionPreference = 'Stop'
$managed = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod = $asm.MainModule

function Walk($t) { $t; foreach ($n in $t.NestedTypes) { Walk $n } }
$script:all = @(foreach ($x in $mod.Types) { Walk $x })

function Fmt-Op($i) {
    $op = $i.Operand; $s = ''
    if ($op -ne $null) {
        if ($op -is [string]) { $s = "'" + $op + "'" }
        elseif ($op -is [DseCecil.MethodReference]) { $s = $op.DeclaringType.FullName + '::' + $op.Name }
        elseif ($op -is [DseCecil.FieldReference]) { $s = $op.DeclaringType.FullName + '::' + $op.Name }
        elseif ($op -is [DseCecil.TypeReference]) { $s = $op.FullName }
        else { $s = $op.ToString() }
    }
    "  {0,-6} {1,-12} {2}" -f ('IL_' + $i.Offset), $i.OpCode.Name, $s
}

function Get-T($name) {
    $script:all | Where-Object { $_.FullName -eq $name } | Select-Object -First 1
}

function Dump-Type($name) {
    $t = Get-T $name
    if ($t -eq $null) { "### TYPE NOT FOUND: $name"; return }
    "### TYPE $($t.FullName)  base=$($t.BaseType.FullName)  public=$($t.IsPublic)  attrs=$($t.Attributes)"
    $t.Fields | ForEach-Object {
        $cv = ''
        if ($_.HasConstant) { $cv = " const=$($_.Constant)" }
        "  FIELD $($_.FieldType.FullName) $($_.Name) static=$($_.IsStatic)$cv"
    }
    $t.Properties | ForEach-Object { "  PROP $($_.PropertyType.FullName) $($_.Name) get=$($_.GetMethod.IsPublic) set=$($_.SetMethod.IsPublic)" }
    $t.Methods | ForEach-Object {
        $ps = ($_.Parameters | ForEach-Object { $_.ParameterType.Name + ' ' + $_.Name }) -join ', '
        "  METHOD $($_.ReturnType.Name) $($_.Name)($ps) public=$($_.IsPublic) static=$($_.IsStatic)"
    }
    $t.NestedTypes | ForEach-Object { "  NESTED $($_.FullName)" }
}

function Dump-IL($spec) {
    $parts = $spec.Trim() -split '::'
    $tn = $parts[0]; $mn = $parts[1]
    $filter = ''
    if ($parts.Count -ge 3) { $filter = $parts[2] }
    $t = Get-T $tn
    if ($t -eq $null) { "### TYPE NOT FOUND: $tn"; return }
    $ms = @($t.Methods | Where-Object { $_.Name -eq $mn })
    if ($filter -ne '') { $ms = @($t.Methods | Where-Object { $_.Name -like $mn -and (&{ $p = $_.Parameters; ($p | ForEach-Object { $_.ParameterType.Name }) -join ',' }) -like $filter }) }
    if ($ms.Count -eq 0) { "### METHOD NOT FOUND: $spec"; return }
    foreach ($m in $ms) {
        "=== $($m.FullName)  static=$($m.IsStatic)"
        if (-not $m.HasBody) { '  <no body>'; continue }
        foreach ($v in $m.Body.Variables) { "  local $($v.VariableType.Name) V_$($v.Index)" }
        foreach ($i in $m.Body.Instructions) { Fmt-Op $i }
    }
}

function Dump-Callers($pattern, $opFilter) {
    $rx = [regex]$pattern
    $ops = @('call','callvirt','newobj','ldftn','ldvirtftn')
    if ($opFilter -ne '') { $ops = @($opFilter -split ',') }
    foreach ($t in $script:all) {
        foreach ($m in $t.Methods) {
            if (-not $m.HasBody) { continue }
            foreach ($i in $m.Body.Instructions) {
                if ($ops -notcontains $i.OpCode.Name) { continue }
                $op = $i.Operand
                if ($op -eq $null) { continue }
                if (-not ($op -is [DseCecil.MethodReference])) { continue }
                $s = $op.DeclaringType.FullName + '::' + $op.Name
                if ($rx.IsMatch($s)) {
                    "CALLER $($t.FullName)::$($m.Name)  [IL_$('{0:x4}' -f $i.Offset)] $($i.OpCode.Name) $s"
                }
            }
        }
    }
}

function Dump-Strings($sub) {
    $seen = @{}
    foreach ($t in $script:all) {
        foreach ($m in $t.Methods) {
            if (-not $m.HasBody) { continue }
            foreach ($i in $m.Body.Instructions) {
                if ($i.OpCode.Name -eq 'ldstr' -and $i.Operand -is [string] -and $i.Operand.Contains($sub)) {
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

function Dump-FieldRefs($pattern) {
    $rx = [regex]$pattern
    foreach ($t in $script:all) {
        foreach ($m in $t.Methods) {
            if (-not $m.HasBody) { continue }
            foreach ($i in $m.Body.Instructions) {
                $op = $i.Operand
                if ($op -eq $null) { continue }
                if (-not ($op -is [DseCecil.FieldReference])) { continue }
                $s = $op.DeclaringType.FullName + '::' + $op.Name
                if ($rx.IsMatch($s)) { "FIELDREF $($t.FullName)::$($m.Name)  [IL_$('{0:x4}' -f $i.Offset)] $($i.OpCode.Name) $s" }
            }
        }
    }
}

function Dump-TypeRefs($typeName) {
    $rx = [regex]('(^|[^A-Za-z0-9_])' + [regex]::Escape($typeName) + '($|[^A-Za-z0-9_])')
    foreach ($t in $script:all) {
        foreach ($m in $t.Methods) {
            if (-not $m.HasBody) { continue }
            foreach ($i in $m.Body.Instructions) {
                $op = $i.Operand
                if ($op -eq $null) { continue }
                $s = ''
                if ($op -is [DseCecil.TypeReference]) { $s = $op.FullName }
                elseif ($op -is [DseCecil.MethodReference]) { $s = $op.DeclaringType.FullName + '::' + $op.Name }
                else { continue }
                if ($rx.IsMatch($s)) { "REF $($t.FullName)::$($m.Name)  [IL_$('{0:x4}' -f $i.Offset)] $($i.OpCode.Name) $s" }
            }
        }
    }
}

switch ($Cmd) {
    'findtypes' {
        $rx = [regex]$Arg
        foreach ($t in $script:all) { if ($rx.IsMatch($t.FullName)) { $t.FullName } }
    }
    'findmethods' {
        $rx = [regex]$Arg
        foreach ($t in $script:all) {
            foreach ($m in $t.Methods) { if ($rx.IsMatch($m.Name)) { "$($t.FullName)::$($m.Name)" } }
        }
    }
    'types' { foreach ($n in ($Arg -split ';')) { Dump-Type $n.Trim() } }
    'il' { foreach ($n in ($Arg -split ';')) { Dump-IL $n.Trim() } }
    'callers' { Dump-Callers $Arg $Arg2 }
    'fieldrefs' { Dump-FieldRefs $Arg }
    'subclasses' {
        foreach ($t in $script:all) { if ($t.BaseType -ne $null -and $t.BaseType.FullName -eq $Arg) { "$($t.FullName)  base=$($t.BaseType.FullName)" } }
    }
    'strings' { Dump-Strings $Arg }
    'typerefs' { Dump-TypeRefs $Arg }
    'fields' {
        foreach ($n in ($Arg -split ';')) {
            $t = Get-T $n.Trim()
            if ($t -eq $null) { "### TYPE NOT FOUND: $n"; continue }
            "### $($t.FullName)"
            $t.Fields | ForEach-Object { "  $($_.FieldType.FullName) $($_.Name) static=$($_.IsStatic)" }
        }
    }
    default { "unknown cmd" }
}
