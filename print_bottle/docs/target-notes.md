# 反编译结论（v0.3.0，游戏 VERSION 100-REV13 / 1.0.0.x 实测）

本机用游戏自带的 `DseCecil.dll` 读 `Assembly-CSharp.dll` 得到。游戏更新后按第 8 节复查。

## 1. 机器组件

- 机器物品 id：`bottle_printer`，由 `FurnitureItemDirectory::InitDirectory` 里的工厂委托调用 `MachineBottlePrinter.BottlePrinter()` 创建（`Items/items_tool` 精灵图）。
- **没有** `BottlePrinter` 组件类；`MachineBottlePrinter` 是普通静态工具类（`base=System.Object`），提供：
  - `BottlePrinter()` / `GetUpgradeCount` / `IsNormalUnlocked` / `IsLargeUnlocked` / `CanUpgradePrinter` / `UpgradePrinter`
  - `CreateTooltip(RichTextBuilder, GameItem)`
  - `CreateMachineInventoryWindow(bool isDraggable, bool isCentered, int minWidth)` → `ValueTuple`6<...>
  - 常量：`SMALL_PRINT_COST=4`、`NORMAL_PRINT_COST=6`、`LARGE_PRINT_COST=11`、`OUTPUT_BASE_WIDTH=4`、`OUTPUT_HEIGHT=4`、`NORMAL_UNLOCK_COST=3`、`LARGE_UNLOCK_COST=9`
  - 注：`CreateMachineInventoryWindow` 的 `isCentered` / `minWidth` 两个参数在当前版本里**没有被使用**（方法体里只把 `isDraggable` 传给 `MachineHelper.CreateMachineryWindow`）。

## 2. 机器窗口结构（v0.3.0 新补丁的关键）

`CreateMachineInventoryWindow` 依次做：

```
battery = new GameSlotInventory()                       // 电池槽
output  = new GameGridInventory(4, 4)                   // 输出格 4x4
buttonSmall  = new MachineryButton(LocHelper.GetLocalizedMechanicOrDefault("mech_bottle_printer_btn_print_small", "Print Small Bottle", ...), null, -1, -1)
buttonNormal = new MachineryButton(LocHelper.GetLocalizedMechanic("mech_bottle_printer_btn_print_normal", ...), null, -1, -1)
buttonLarge  = new MachineryButton(LocHelper.GetLocalizedMechanic("mech_bottle_printer_btn_print_large", ...), null, -1, -1)
panels = {
    MachineHelper.PowerPanel(battery),                                        // role "power"
    MachineHelper.Panel(label, output, "output", true),                       // role "output"
    MachineHelper.Panel(label, MachineryStack.Vertical(3 buttons), "control", true) // role "control"
}
window = MachineHelper.CreateMachineryWindow(isDraggable, panels)
return (window, battery, output, buttonSmall, buttonNormal, buttonLarge)
```

窗口树：

```
PixelWindow (style = 1 / machinery)
└─ childElement: MachineryPanelRow
   ├─ GetPanel("power")   -> MachineryPanel.content = MachineryIntake(battery)
   ├─ GetPanel("output")  -> MachineryPanel.content = MachineryIntake(output grid)
   └─ GetPanel("control") -> MachineryPanel.content = MachineryStack (vertical, gap 4)
                              children: buttonSmall, buttonNormal, buttonLarge
```

要点（都已在本机运行时验证）：

- `MachineryStack.Add(PixelElement)` = `Attach`：加入 `children`、`SetRenderingParent`、`MachineryContainerUtils.SetOwner`、最后自己 `Validate()`。
- 追加按钮后依次 `panel.Validate()` → `row.Validate()` → `window.Validate()` 就能让面板/窗口按新高度重排；`MachineryPanelRow.Validate` 末尾本来就会通过 `FindParentElement<GraphNodeStorage>()` 调 `window.Validate()`，`validateLock` 会挡住重复递归。
- `GameGridInventory.ResizePixels` 是空方法；`GameGridInventory.Validate()` 里才用 `widthPixels = inventoryShape.width * UISettings.current.gridSize`、`heightPixels = inventoryShape.height * UISettings.current.gridSize` 重算像素尺寸。所以改完 `SetShape` 要 `Validate()`（原版升级代码就是这么做的）。

`BottlePrinter()` 在 `CreateMachineInventoryWindow` 返回后：给 `outputGrid` 设 `mayInventoryAddItemFunc`（只允许玩家拥有且带 `LIQUID_CONTAINER_TAG` 的物品）、创建机器 `GameItem`、`SetContentWindow(window)`、`MachineHelper.SetupBatterySlot(...)`，最后调用局部函数 `ApplyUpgradeState()`。

## 3. 打印逻辑（原版）

`<>c__DisplayClass8_0` 上的三个按钮回调：

| 方法 | 行为 |
| --- | --- |
| `<BottlePrinter>b__3` | `TryPrint("small_bottled_water", 4)` |
| `<BottlePrinter>b__4` | `if (IsNormalUnlocked(machine)) TryPrint("bottled_water", 6)` ← 750 mL 标准瓶 |
| `<BottlePrinter>b__5` | `if (IsLargeUnlocked(machine)) TryPrint("large_bottled_water", 11)` |

局部函数 `<BottlePrinter>g__TryPrint|1(string bottleId, int cost)`：

1. 电池槽 `childItems.Count == 0` → 返回；
2. `PowerHelper.CanDrawPowerSource(battery, cost)` 为假 → 返回；
3. `GameItem product = DirectoryMaster.Item(bottleId, true)`；
4. `GraphUtils.CanAccept(outputGrid, product)` 为假 → 返回（不扣电）；
5. `GraphUtils.TryAcceptAll(outputGrid, product, -1)`；
6. `PowerHelper.DrawPowerSource(battery, cost)`。

v0.3.0 **不再补丁这个方法**（原版三个按钮保持原样）；两个新按钮的回调在 `PrinterButtons.TryPrint` 里按上面同样的顺序调用同样的公共 API，所以扣电、输出区判定、`mayInventoryAddItemFunc` 行为与原版按钮一致。

## 4. 输出格容量与升级

局部函数 `ApplyUpgradeState()`：

```
int width = 4;
if (IsNormalUnlocked(machine)) width++;
if (IsLargeUnlocked(machine)) width++;
outputGrid.SetShape(width, 4);
outputGrid.Validate();
machine.contentWindow.Validate();
machine.Validate();
buttonNormal.Enable()/Disable(); buttonLarge.Enable()/Disable();
```

`ApplyUpgradeState` 在机器创建（`BottlePrinter()` 末尾）和升级事件（`onItemTargetThisFunc` -> `<BottlePrinter>b__7`）以及 `onLoaded`（`b__6`）时都会跑一次。

v0.3.0 的容量补丁：`GameGridInventory.SetShape(int width, int height)` 加 Prefix；`PrinterButtons.WindowPostfix` 先把该机器的输出格登记进 `List<GameGridInventory>`，Prefix 只对登记过的实例把参数宽度 ×2（并限制在 4–6 的合法原版宽度范围）。这样：

- 4×4 → 8×4，5×4 → 10×4，6×4 → 12×4；原版 SetShape 之后的 Validate 链会自己完成重排；
- 其它机器（`MachineFridge.ApplyStorageSize`、`MachineRAS.ApplyTankSize`、`VendingMachineHelper.UpgradeCapacity`、`EmporiumEntry.*` 等 20 多处同样调用 `SetShape(int,int)`）完全不受影响。

**输出格尺寸不进存档**：读档时机器物品按 id + `BOTTLE_PRINTER_UPGRADE_COUNT_TAG` 重建，`ApplyUpgradeState` 重新推导尺寸。本机实测：读档后控制台依次出现 `output grid widened: 4 -> 8 columns`、`output grid widened: 6 -> 12 columns`（同一台机器创建 + onLoaded 两次调用），存档目录里除 `SaveFile.es3`（设置/信任记录，测试后已还原）外没有任何 `.es3` 被改动。

## 5. 两个新产物物品

| id | 工厂 | 容量 | 价值 | 形状 | 备注 |
| --- | --- | --- | --- | --- | --- |
| `wine_bottle` | `WineDirectory::WineBottle()` | 1 L 容器 | 12 | 1×4 | `WineHelper.InitWineBottle`（气塞/发酵标签）+ `AudioHelper.InitGlass` |
| `water_jug` | `FoodItemDirectory::WaterJug()`（原版「桶装水」） | **6000 mL = 6 L** | 15 | 1×4 | `Items/water_container4` / `xl`；`WaterHelper.InitLiquidContainerItem(6000, 15, 0,0,0,1,4)` + `AudioHelper.InitPlasticBottle` |

两者都已注册在各自的 `InitDirectory` 里，`DirectoryMaster.Item(id, true)` 就能拿到合法的空液体容器；都带 `LIQUID_CONTAINER_TAG`，能通过打印机输出格的 `mayInventoryAddItemFunc`。

## 6. v0.3.0 最终采用的两个补丁

`src/PrintBottleMod.cs` 里手动 Harmony patch（不写 `[HarmonyPatch]` 特性，加载器的自动扫描只报 0）：

1. **Postfix** `MachineBottlePrinter.CreateMachineInventoryWindow(bool, bool, int)`（`src/PrinterButtons.cs`）
   - `__result: ref ValueTuple6<PixelWindow, GameSlotInventory, GameGridInventory, MachineryButton, MachineryButton, MachineryButton>`；
   - 登记 `__result.Item3` 输出格；
   - `window.childElement as MachineryPanelRow` → `GetPanel("control")` → `content as MachineryStack`（若是 `MachineryIntake` 包一层则取 `intake.content`）；
   - 追加两个 `new MachineryButton(文本, 回调, -1, -1)`，文本来自模组自己的 `Localization/*.csv`（`ModHelper.GetLocalized`，缺 key 回退英文）；
   - `panel.Validate(); row.Validate(); window.Validate();`
   - 任何异常只记日志，原版窗口照常返回。
2. **Prefix** `GameGridInventory.SetShape(int, int)`（`src/PrinterCapacity.cs`）
   - 只对登记的打印机输出格生效，宽度 ×2；其余实例原样放行。

补丁目标全部通过 `typeof(游戏类型)` + `ModReflect.Target` 解析（静态已知类型，扫描器不算 `reflection-external`）；没有使用 `System.Reflection` 在运行时类型上按名找成员。

## 7. 存档与卸载行为

本机实测 + 存档代码反编译结论：**输出格尺寸不进存档**。存档只记录物品 id、标签（升级次数）、格子坐标（`GridShapeBuilder` 的 minX/minY 等）；机器窗口和输出格尺寸每次读档时由工厂 + `ApplyUpgradeState` 重新构建，`SetShape(4/5/6, 4)` 被 Prefix 改成 8/10/12。实测读档后存档目录里除 `SaveFile.es3`（设置/信任记录，测试后已还原）外没有任何 `.es3` 被改动。

停用模组/删掉文件夹后：机器窗口回到 3 个按钮、输出格回到 4/5/6 列。落在额外列里的物品**不会消失、不会掉地**：物品的格子坐标存在存档里，读档时 `UncheckedAccept` 不校验容量，只是它们位于窄网格之外、拿不出来；重新启用模组就能再看到。卸载前把输出区腾空可以避免这种尴尬。


## 8. 复查方法（游戏更新后）

```powershell
$managed = '<game>\Probably Stolen_Data\Managed'
Add-Type -Path "$managed\DseCecil.dll"
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly("$managed\Assembly-CSharp.dll")
$mod = $asm.MainModule

# 1) 目标方法/返回类型还在不在
$t = $mod.GetType('MachineBottlePrinter')
$t.Methods | ForEach-Object { "$($_.ReturnType.Name) $($_.Name)(" + (($_.Parameters | ForEach-Object { $_.ParameterType.Name }) -join ',') + ")" }

# 2) 窗口树是否仍是 row.GetPanel("control") -> MachineryStack
$m = $t.Methods | Where-Object { $_.Name -eq 'CreateMachineInventoryWindow' }
foreach ($i in $m.Body.Instructions) { if ($i.OpCode.Name -match 'call|newobj|ldstr') { $i.ToString() } }

# 3) 升级时 SetShape 的宽度还是不是 4/5/6
$d = $t.NestedTypes | Where-Object { $_.Name -like '<>c__DisplayClass*' } | Select-Object -First 1
$d.Methods | Where-Object { $_.Name -match 'ApplyUpgradeState' } | ForEach-Object { $_.Body.Instructions | ForEach-Object { $_.ToString() } }

# 4) 物品 id / 容量
$mod.GetType('FoodItemDirectory').Methods | Where-Object { $_.Name -eq 'WaterJug' } | ForEach-Object { $_.Body.Instructions | ForEach-Object { $_.ToString() } }
```

进游戏后用 F8 验证的日志（本机实测输出）：

```
[打印酒瓶 / 6L 大桶]: patch applied: MachineBottlePrinter.CreateMachineInventoryWindow (printer window: additive buttons)
[打印酒瓶 / 6L 大桶]: patch applied: GameGridInventory.SetShape (printer output capacity x2)
[打印酒瓶 / 6L 大桶]: added print buttons: wine bottle (8 power), 6L jug (16 power)
[打印酒瓶 / 6L 大桶]: output grid widened: 4 -> 8 columns
[打印酒瓶 / 6L 大桶]: output grid widened: 6 -> 12 columns
[打印酒瓶 / 6L 大桶]: printed wine_bottle for 8 power
[打印酒瓶 / 6L 大桶]: printed water_jug for 16 power
```

## 9. 还可以做的（可选）

- **改耗时/耗电**：`src/PrinterButtons.cs` 的 `WinePrintCost` / `JugPrintCost`，重新编译即可。
- **给新按钮加解锁门槛**：目前两个新按钮不检查 `IsNormalUnlocked` / `IsLargeUnlocked`。想要跟原版档位绑定，可以在 `WindowPostfix` 里把 `__result.Item5`/`Item6`（原版标准/大号按钮）存下来，在回调里判断 `isDisabled`，并在 `ApplyUpgradeState` 之后同步 `Enable()`/`Disable()`（需要再监听升级事件）。
- **改按钮/提示文案**：改 `Localization/en.csv`、`zh.csv`（键 `btn_print_wine` / `btn_print_jug`），不用重新编译。
- **机器 tooltip 补两行**：`CreateTooltip` 的 `RichTextBuilder.AddLine` 需要 `ColorPalette` 枚举，而它是 `Assembly-CSharp` 内部类型（C# 里无法直接引用），要用 `ModReflect.Call` 绕；本轮没做，因为收益小于风险。
- **加更多档位**：`MiscItemDirectory` 的 `EnergyCredit`（100 能量）、`EnergyCreditExtended`（250）、`DisposableBattery`（1000）等电池都支持更大单次耗电，`CanDrawPowerSource` 只比较剩余能量，不限制单次上限。
