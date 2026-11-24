# 补丁目标笔记（游戏 1.0.0.x）

## 事实清单（Assembly-CSharp 反编译所得）

| 项目 | 值 |
| --- | --- |
| 顾客工厂 | `StoreClientListTier.CreateWaterStockPiler()` |
| 顾客内部 id | `waterStockpiler` |
| 显示名 | `LocHelper.GetLocalizedClientName("name_water_stockpiler")` → 中文「囤水者」 |
| 阵营 | `FACTION_UPPER_LEVEL`（上层区），`StoreClientFactionSetup.InitUpperLevelCitizen` |
| 预算公式 | `500 + RNG.GetRandomInt(0, 100) + StoreStation.GetDayCounter()`，经 `StoreClient.SetBudget(int)` |
| 预算字段 | `StoreClient.clientBudget`（private），`useClientBudget`（public） |
| 预算读取 | `StoreClient.GetBudget()`（public） |
| 预算直接覆盖 | `StoreClient.OverrideBudget(int)`（public） |
| 预算增减 | `StoreClient.ModBudget(int)`（public，`PlayerStore.SellItem` 成交后扣款） |
| 加成结算 | `StoreClient.ApplyBudgetModifier()`（public，由 `SetBudget` 结尾调用） |
| 对话 4 | `dialog_water_stockpiler_4`，参数是 `GetBudget()` —— 所以放大必须发生在对话构建之前 |

工厂的 IL 顺序（关键部分）：

```
newobj  StoreClient
ldstr   'waterStockpiler'        → identifier
ldstr   'name_water_stockpiler'  → displayName
ldstr   'FACTION_UPPER_LEVEL'    → clientFaction
call    StoreClientFactionSetup::InitUpperLevelCitizen
callvirt StoreClient::AddBasicCheck
ldc.i4  500
ldc.i4.0 / ldc.i4.s 100 → RNG::GetRandomInt
add
StoreStation::GetDayCounter
add
callvirt StoreClient::SetBudget(int)
...
callvirt StoreClient::GetBudget   → dialog_water_stockpiler_4 的 {0}
```

## 为什么补丁打在 ApplyBudgetModifier 上

- `SetBudget(int)` 内部顺序：`clientBudget = 参数` → `ApplyBudgetModifier()`。Postfix 时预算已含所有原版加成，直接 `OverrideBudget(GetBudget() * 10)` 即可，且返回后工厂才构建对话。
- 不能打 `GetBudget()`：`PlayerStore.SellItem` 每次成交都用 `GetBudget()` 判定、再用 `ModBudget(-实付)` 扣款，读一次乘一次会让扣款永远追不上读取。
- 不能只打 `CreateWaterStockPiler` 的 Postfix：那时 `dialog_water_stockpiler_4` 的文本已经用旧预算生成，玩家看到的数字和实际预算对不上。
- `ShowcaseHelper.CreateClientByStockType` 里也出现 `waterStockpiler`，但它只是返回顾客 id 字符串做陈列预测，不创建顾客、不设预算，无需处理。

## 复查命令（游戏更新后）

PowerShell 5.1 直接跑，`$managed` 换成实际游戏目录：

```powershell
$managed = 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod = $asm.MainModule

$t = $mod.GetType('StoreClient')
$t.Methods | Where-Object { $_.Name -match 'Budget' } |
  ForEach-Object { "$($_.ReturnType.Name) $($_.Name)(" + (($_.Parameters | ForEach-Object { $_.ParameterType.Name }) -join ',') + ") public=$($_.IsPublic)" }
$t.Fields | Where-Object { $_.Name -match 'clientBudget|identifier' } |
  ForEach-Object { "$($_.FieldType.Name) $($_.Name) public=$($_.IsPublic)" }

$f = $mod.GetType('StoreClientListTier').Methods | Where-Object { $_.Name -eq 'CreateWaterStockPiler' }
foreach ($i in $f.Body.Instructions) {
  if ($i.OpCode.Name -eq 'ldstr') { "ldstr $($i.Operand)" }
  elseif ($i.Operand -is [DseCecil.MethodReference] -and $i.Operand.DeclaringType.Name -eq 'StoreClient') { "call $($i.Operand.Name)" }
}
```

确认：`ApplyBudgetModifier()` 仍是无参 public 实例方法；`OverrideBudget(int)`、`GetBudget()` 仍在；`CreateWaterStockPiler` 里仍先 `SetBudget`、后 `GetBudget` 构对话；`identifier` 仍是 `waterStockpiler`。

## 更新后的最小改动

- 方法名/签名不变：只改 `manifest.xml` 的 `<ModVersion>` 与 `<GameVersions>`。
- `ApplyBudgetModifier` 被改名或内联：在 `StoreClient.SetBudget(int)` 上改打 Prefix（把 `__1` 乘 10），或退回到 `CreateWaterStockPiler` 的 Postfix 并在生成后同步改写对话（更麻烦）。
- 工厂预算公式被改：不影响本模组（乘的是最终值），无需调整。
