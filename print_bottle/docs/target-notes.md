# 第二阶段：反编译结论（已完成）

上一版这里是「待查」。现在已用 Cecil 读 `Assembly-CSharp.dll` 确认了调用链，结论如下，后续游戏更新时按同样方法复查即可。

## 1. 机器组件

- 机器物品 id：`bottle_printer`（由 `MachineBottlePrinter.BottlePrinter()` 工厂创建，`Items/items_tool` 精灵图）
- **没有** `BottlePrinter` 组件类；`MachineBottlePrinter` 是一个普通静态工具类（`base=System.Object`），提供：
  - `BottlePrinter()` / `GetUpgradeCount` / `IsNormalUnlocked` / `IsLargeUnlocked` / `CanUpgradePrinter` / `UpgradePrinter`
  - `CreateTooltip(RichTextBuilder, GameItem)`
  - `CreateMachineInventoryWindow(bool, bool, int)` → `ValueTuple`6`（机器窗口本身）
  - 常量：`SMALL_PRINT_COST=4`、`NORMAL_PRINT_COST=6`、`LARGE_PRINT_COST=11`、`OUTPUT_BASE_WIDTH`、`OUTPUT_HEIGHT`

## 2. 按钮与打印逻辑

机器窗口在 `CreateMachineInventoryWindow` 里构建，按钮点击回调是编译器生成的私有嵌套类 `MachineBottlePrinter/<>c__DisplayClass8_0` 上的三个方法：

| 方法 | 行为 |
| --- | --- |
| `<BottlePrinter>b__3` | `TryPrint("small_bottled_water", 4)` |
| `<BottlePrinter>b__4` | `if (IsNormalUnlocked(machine)) TryPrint("bottled_water", 6)` ← **750 mL 标准瓶** |
| `<BottlePrinter>b__5` | `if (IsLargeUnlocked(machine)) TryPrint("large_bottled_water", 11)` |

`TryPrint(string bottleId, int cost)` 是同一嵌套类里的局部函数（名字 `<BottlePrinter>g__TryPrint|1`），顺序是：

1. 输入格（电池槽）里没有物品 → 直接返回；
2. `PowerHelper.CanDrawPowerSource(battery, cost)` 为假 → 返回；
3. `DirectoryMaster.Item(bottleId, true)` 创建产物；
4. `GraphUtils.CanAccept(outputGrid, item)` 为假 → 返回（不扣电）；
5. `GraphUtils.TryAcceptAll(outputGrid, item, -1)` 放入；
6. `PowerHelper.DrawPowerSource(battery, cost)` 扣电。

所以**唯一需要改的就是第 3 步拿到的那个 id**。

## 3. 酒瓶本身

- `wine_bottle` 由 `WineDirectory.WineBottle()` 工厂创建：`Directory.Empty()` → 精灵图/名称/描述/价值 12 → `WineHelper.InitWineBottle`（初始化空瓶、气塞、发酵相关标签）→ `AudioHelper.InitGlass`。
- 因此通过 `DirectoryMaster.Item("wine_bottle", true)` 拿到的是**合法的空酒瓶**，可以直接灌水/发酵，不需要自己拼装物品。
- 占 1×4 格，4×4 输出区最多并排 4 个。

## 4. 最终采用的补丁

`src/BottlePrinterPatch.cs`：

- `FindDisplayType()`：先 `ModReflect.FindType("MachineBottlePrinter+<>c__DisplayClass8_0")`，失败再用 `ModReflect.Types()` 按名字扫一遍（编译器重新编号时兜底）；
- `ModReflect.Target(display, "<BottlePrinter>g__TryPrint|1", new[]{typeof(string), typeof(int)})` 拿到方法；
- `Prefix(ref string __0)`：`__0 == "bottled_water"` 时改成 `"wine_bottle"`；
- 只换 id，电量 6、解锁门槛（3 次升级）、输出区判定全部沿用原版。

为什么不用 `System.Reflection`：扫描器把「在数据流推导出来的 `Type` 上按名字找成员」判为 `reflection-external`（2026-12-10 起拒绝启动），而 `ModReflect` 是官方提供的免能力入口，并且它的 `InScope` 会校验目标类型属于游戏程序集 —— 编译器生成的嵌套类正好在范围内。

已验证：编译产物只引用 `mscorlib 4.0` / `Assembly-CSharp 0.0.0.0` / `0Harmony 2.4.2.0`，运行时都是 `v4.0.30319`，与游戏自带的 DLL 版本一致。

## 5. 复查方法（游戏更新后）

本机没有 .NET SDK，所以用游戏自带的 `DseCecil.dll` 直接读元数据：

```powershell
Add-Type -Path 'E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\Managed\DseCecil.dll'
$asm = [DseCecil.AssemblyDefinition]::ReadAssembly('E:\...\Managed\Assembly-CSharp.dll')
$t = $asm.MainModule.GetType('MachineBottlePrinter')
$t.NestedTypes | ForEach-Object { $_.Methods | Where-Object { $_.Name -match 'TryPrint' } }
```

有 SDK 的机器上也可以 `dotnet tool install -g ilspycmd` 后 `ilspycmd -t MachineBottlePrinter Assembly-CSharp.dll`。

## 6. 还可以做的（可选）

- **改解锁门槛**：`b__4` 在调用 `TryPrint` 前先判 `IsNormalUnlocked`，想要「开局就能打酒瓶」需要再补一个小补丁跳过这个判断。
- **改按钮/提示文案**：`CreateTooltip` 用的是 `mech_bottle_printer_tooltip_print_normal` 等本地化键，按钮文案来自 `mech_bottle_printer_btn_print_normal`。想显示「打印酒瓶」要么改本地化表（模组不能直接改游戏资源），要么给 `CreateTooltip` 加 Postfix 自己拼一行。
- **加第四个按钮而不是替换**：需要重建 `CreateMachineInventoryWindow` 的按钮布局，参考社区「更好的瓶子打印机」的做法，工作量大得多。
