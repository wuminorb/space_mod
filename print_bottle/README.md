# print_bottle —— 水瓶打印机扩展（酒瓶 / 6L 大桶 / 双倍输出区）

《深空当铺：可能是偷的》（Probably Stolen）原生模组。三项改动：

1. **还原 750 mL 标准水瓶**：原版「标准水瓶」按钮照常打印 `bottled_water`（0.2.x 的「替换成酒瓶」行为已移除）；
2. **新增两个打印机按钮**：打印酒瓶（`wine_bottle`，8 点电）、打印 6L 大桶（桶装水 `water_jug`，16 点电）；
3. **输出区容量翻倍**：4×4 → 8×4，随原版升级变成 10×4 / 12×4（瓶子占 1×4 格，即一次能放 8 / 10 / 12 个）。

- Mod ID：`print_bottle`
- 程序集：`PrintBottle.dll`
- 版本：**v0.3.0**
- 目标游戏：1.0.0.x（清单里写 `1.0.0` 覆盖整个 1.0.0 的所有修订）

## 它改了什么

| 按钮（从上到下） | 原版 | 装了本模组 |
| --- | --- | --- |
| 小号（4 电） | 小号瓶装水 `small_bottled_water` | 不变 |
| **标准（6 电）** | 750 mL 瓶装水 `bottled_water` | **还原为原版 750 mL 瓶装水** |
| 大号（11 电） | 大号瓶装水 `large_bottled_water` | 不变 |
| **打印酒瓶（新，8 电）** | — | **酒瓶 `wine_bottle`** |
| **打印 6L 大桶（新，16 电）** | — | **桶装水 / 6L 水桶 `water_jug`** |

| | 原版 | 装了本模组 |
| --- | --- | --- |
| 输出区 | 4×4（升级后 5×4 / 6×4） | **8×4（升级后 10×4 / 12×4）** |
| 解锁条件 | 累计升级 3 次解锁标准、9 次解锁大号 | 不变（只控制前三个按钮；两个新按钮不受升级限制，只要电池有电就能点） |
| 耗电 / 输出区判定 | 电不够或放不下就不打印也不扣电 | 不变（新按钮走同一套判断） |

- **酒瓶** 是合法的空瓶（`WineDirectory.WineBottle()` 工厂会跑 `WineHelper.InitWineBottle`，带气塞与发酵标签），打印出来直接灌水/发酵即可；占 1×4 格，价值 12。
- **6L 大桶** 就是原版物品「桶装水」`water_jug`（`FoodItemDirectory.WaterJug()`：容量 6000 mL，价值 15，占 1×4 格），打印出来是合法的空液体容器，可直接装水。
- 单次耗电写在 `src/PrinterButtons.cs` 的 `WinePrintCost` / `JugPrintCost`，想调价格改这两个常量重新编译即可。

## 实现方式

- **新按钮**：Harmony **Postfix** 打在 `MachineBottlePrinter.CreateMachineInventoryWindow(bool,bool,int)` 上。该方法是原版创建机器窗口的地方，返回 `ValueTuple6(window, 电池槽, 输出格, 小号按钮, 标准按钮, 大号按钮)`；Postfix 从窗口树里找到 `MachineryPanelRow.GetPanel("control")` 的控制列 `MachineryStack`，把两个新 `MachineryButton` 追加进去并重新 `Validate()`，窗口自然长高。原版三个按钮、回调、解锁状态完全不动。
- **打印逻辑**：新按钮的回调复刻原版 `TryPrint` 局部函数的四步判定（电池槽非空 → `PowerHelper.CanDrawPowerSource` → `DirectoryMaster.Item(id, true)` → `GraphUtils.CanAccept` → `TryAcceptAll` → `DrawPowerSource`），不扣电不产物，和原版按钮手感一致。
- **输出区翻倍**：Harmony **Prefix** 打在 `GameGridInventory.SetShape(int,int)` 上。原版升级函数会调用 `SetShape(4/5/6, 4)`，窗口初始化时登记过的那一个输出格宽度会被乘 2；其它机器的储物格通过登记表过滤，完全不受影响。输出格尺寸是每次读档/升级时按升级次数重新推导的，不写进存档。
- 旧版（0.2.x）那个「把 `bottled_water` 换成 `wine_bottle`」的前缀补丁已经删除。

## 存档与稳定性

- 不写存档、不改存档结构、不加自定义物品、不联网。新增产物全是原版物品，走原版物品工厂。
- 机器窗口和输出格尺寸在**每次载入存档时由物品 ID + 升级标签重新构建**，所以老存档、新存档都能直接用；本模组不往存档里塞任何字段。
- **卸载前**先把打印机输出区多出来的列（第 5 列以后）腾空。停用模组后输出区变回 4/5/6 列：留在外面的物品**不会消失、也不会被挤掉**（物品位置是存档里记的格子坐标，读档时照原样放回，网格不做容量校验），只是会落在网格遮罩外、拿不出来；重新启用模组就又能看到。也就是说最坏情况是可恢复的，但仍建议先腾空。
- 所有补丁都带 try/catch 降级：目标方法找不到或窗口结构变了，只在 F8 控制台报错，机器保持原版行为，不会崩游戏。

## 构建与安装

本机没装 .NET SDK，用 Windows 自带的 `csc.exe` 就能编（`build.ps1`）：

```powershell
cd D:\space_mod\print_bottle
.\build.ps1          # 产物 bin\Release\PrintBottle.dll
.\deploy.ps1         # 构建 + DLL/manifest/Localization 复制到 %GameDir%\Mods\print_bottle
```

装了 SDK 也可以用 `dotnet build -c Release`（`PrintBottle.csproj` 里 `GameDir` 属性指向游戏目录，换机器只改这一处）。

游戏目录默认 `E:\SteamLibrary\steamapps\common\Probably Stolen`，可用 `-GameDir` 覆盖。

首次安装 / 换了 DLL 后：主菜单 **Mods** → 选中本模组 → **Activate / 审核并启用** → **重启游戏**。本地模组改哈希后会被扫描器重新扫描一次，扫描通过通常会自动加载；如果详情面板提示需要审核，点一下启用即可。

## 怎么验证生效

1. 游戏根目录放一个空的 `dev.txt`（开发工具开关，只在启动时读一次；注意别变成 `dev.txt.txt`）。
2. 进游戏读档，按 **F8** 看控制台，应有：

```
[打印酒瓶 / 6L 大桶]: patch applied: MachineBottlePrinter.CreateMachineInventoryWindow (printer window: additive buttons)
[打印酒瓶 / 6L 大桶]: patch applied: GameGridInventory.SetShape (printer output capacity x2)
```

3. 打开（或放置）一台水瓶打印机，控制台会多一行，表示两个按钮已加进窗口：

```
[打印酒瓶 / 6L 大桶]: added print buttons: wine bottle (8 power), 6L jug (16 power)
```

   窗口控制列应从上到下是：小号 / 标准 / 大号 / **打印酒瓶** / **打印 6L 大桶**；输出区比原版宽一倍。
4. 点「打印酒瓶」「打印 6L 大桶」，产物进输出区，控制台每次打印都会打一行：

```
[打印酒瓶 / 6L 大桶]: printed wine_bottle for 8 power
[打印酒瓶 / 6L 大桶]: printed water_jug for 16 power
```

5. 顺带的自检：**F9 → Spawn → Spawn Wine Bottle / Spawn 6L Water Jug** 会在柜台上直接放一个对应物品（不需要打印机，用来单独确认物品可用）。

按钮文字来自 `Localization/en.csv` 与 `Localization/zh.csv`；想换文案直接改 CSV（键 `btn_print_wine` / `btn_print_jug`），不用重编译。

## 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 模组菜单里没有它 | `manifest.xml` 与 `PrintBottle.dll` 必须在 `Mods\print_bottle\` 同级目录下；F8 控制台启动日志会指出具体问题 |
| 激活后没生效 | 启用只在**重启后**生效；重编译过 DLL 还要在详情面板点「审核并启用」，或打开**开发者模式** |
| F8 只有 `patch applied`，没有 `added print buttons` | 打印机还没被创建。读档后已有打印机、或新放一台就会触发；只到主菜单不会创建机器 |
| 日志出现 `control stack not found` | 游戏更新改了机器窗口结构。两个新按钮不出现，但原版打印机和 750 mL 打印仍正常 |
| 日志出现 `patch skipped` | 游戏更新改了目标方法。整台打印机保持原版行为，不会崩 |
| 想恢复原版 | 在模组菜单停用并重启，或直接删掉 `Mods\print_bottle` 文件夹；**删之前先把打印机输出区腾空** |

改了打印机行为属于「核心循环」改动，官方明确不保证兼容；游戏大版本更新后可能失效，失效时控制台会给出上面的 not found / not applied 日志而不是崩溃。

## 目录结构

```
print_bottle/
├─ build.ps1                    # csc 构建（不需要 SDK）
├─ deploy.ps1                   # 构建 + 部署到 Mods（含 Localization）
├─ PrintBottle.csproj           # 有 .NET SDK 时的等价工程
├─ manifest.xml                 # ID / 版本 / Assemblies / Capabilities
├─ Localization/
│  ├─ en.csv                    # 新按钮英文文案
│  └─ zh.csv                    # 新按钮中文文案
├─ src/
│  ├─ PrintBottleMod.cs         # IMod 入口：日志、F9 按钮、补丁装卸
│  ├─ PrinterButtons.cs         # 机器窗口 Postfix：追加两个按钮 + 打印回调
│  └─ PrinterCapacity.cs        # SetShape Prefix：输出区宽度 ×2
└─ docs/target-notes.md         # 反编译结论、复查方法、可选的后续改动
```

## 合规自检（发布前）

- `<Assemblies>` 只列了 `PrintBottle.dll`；构建产物只引用 `mscorlib` / `Assembly-CSharp` / `0Harmony`（没有把 0Harmony / Unity / netstandard 拷进来）。
- 没有 `files` / `network` / `process` 等能力，`<Capabilities />` 为空；反射只用游戏自带的 `ModReflect.Target`（对静态已知的游戏类型），不碰 `reflection-external`。
- 发布前在游戏内 F8 运行 `mod-scan print_bottle`，确认没有 `DEPRECATED` 行、`detected` 为空。
- 不含任何数据文件、不写存档、不联网。

## 参考资料

- [社区指南仓库：README / ModdingGuide / APIChanges](https://github.com/dragonpan2/probably-stolen-modding)
- [模组制作指南中文版（钩子、能力声明、创意工坊）](https://github.com/dragonpan2/probably-stolen-modding/blob/main/ModdingGuide.zh-CN.md)
- [水瓶打印机（BWIKI）：三档产物、耗电、解锁](https://wiki.biligame.com/probablystolen/%e6%b0%b4%e7%93%b6%e6%89%93%e5%8d%b0%e6%9c%ba)
- [酒瓶（BWIKI）：物品 ID `wine_bottle`](https://wiki.biligame.com/probablystolen/%e9%85%92%e7%93%b6)
- [桶装水（BWIKI）：物品 ID `water_jug`，6L](https://wiki.biligame.com/probablystolen/%e6%a1%b6%e8%a3%85%e6%b0%b4)
- [瓶子与容器机制说明](https://probablystolenguide.com/zh-hans/wiki/bottles-and-containers/)
