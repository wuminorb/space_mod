# stockpiler_budget_x10 —— 上层区囤水者预算 ×10

《深空当铺：可能是偷的》（Probably Stolen）原生模组。已实现：**把上层区「囤水者」顾客的预算提高到原来的 10 倍**。

- Mod ID：`stockpiler_budget_x10`
- 程序集：`StockpilerBudget.dll`
- 版本：**v1.0.0**
- 目标游戏：1.0.0.x（清单里写 `1.0.0` 覆盖整个 1.0.0 的所有修订）

## 它改了什么

| | 原版 | 装了本模组 |
| --- | --- | --- |
| 顾客 | 上层区「囤水者」（内部 id `waterStockpiler`） | 同一个顾客，不新增、不替换 |
| 初始预算 | `500 + 随机 0~100 + 游戏天数` | 同一套数值算完再 **×10** |
| 声望 / 人脉 / 魅力加成 | 原版结算 | 先按原版结算，再整体 ×10 |
| 对话里的信用点数字 | 原版预算 | 同步显示 ×10 后的数字 |
| 其他水商（waterSeller / waterCompany / waterSellerScav / honestBadWaterSeller） | — | **不受影响** |
| 存档 | — | 不加字段、不改结构、不写模组数据 |

预算的用途：顾客用它判断买不买得起（`HasBudgetLeftToBuy`、议价界面），真正成交时按成交价从预算里扣（`PlayerStore.SellItem` → `StoreClient.ModBudget`）。因此放大必须**只在顾客生成时做一次**，否则每卖一件都会重新乘 10。

## 实现方式

补丁点选在 `StoreClient.ApplyBudgetModifier()` 的 **Postfix**：

```
StoreClientListTier.CreateWaterStockPiler()
  identifier = "waterStockpiler"
  clientFaction = "FACTION_UPPER_LEVEL"
  SetBudget(500 + RNG.GetRandomInt(0,100) + StoreStation.GetDayCounter())
    → clientBudget = value; useClientBudget = true; ApplyBudgetModifier()
        → 声望/起始特质/人脉/魅力加成
        → [本模组 Postfix] identifier == "waterStockpiler" ? clientBudget *= 10
  之后才用 GetBudget() 生成「我有 {0} 信用点」的对话
```

- 放在 `ApplyBudgetModifier` 而不是 `GetBudget`：后者每次读取都乘 10，会和 `ModBudget` 的扣款逻辑打架（预算永远花不完）；放在 `SetBudget` 返回后则赶不上工厂里紧接着生成的对话数字。
- `identifier == "waterStockpiler"` 才算，所以同一天刷出的其他顾客完全不受影响。
- 乘法用 `long` 计算并截断到 `int.MaxValue`，不会溢出；实际数值（几百 ×10）离上限很远。
- 目标方法通过 `ModReflect.Target(typeof(StoreClient), ...)` 解析（免能力、2026-12-10 后仍受支持）；游戏更新删掉这个方法时只记录 `not found` 并跳过补丁，不会把主菜单搞崩。
- 不改写 `clientBudget` 字段以外的任何状态，也不调用 `ModHelper.SetModData` / 存档接口。

## 构建与安装

本机没装 .NET SDK，用 Windows 自带的 `csc.exe` 就能编（`build.ps1`）：

```powershell
cd D:\space_mod\stockpiler_budget
.\build.ps1          # 产物 bin\Release\StockpilerBudget.dll
.\deploy.ps1         # 构建 + 复制到 <GameDir>\Mods\stockpiler_budget_x10
```

> 如果 PowerShell 提示「禁止运行脚本」，用
> `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1` 运行。

装了 SDK 也可以用 `dotnet build -c Release`（`StockpilerBudget.csproj` 里 `GameDir` 指向游戏目录，换机器只改这一处）。

游戏目录默认 `E:\SteamLibrary\steamapps\common\Probably Stolen`，可用 `-GameDir` 覆盖。

首次安装后：主菜单 **Mods** → 选中「囤水者预算 ×10」→ **Activate** → **重启游戏**。

## 怎么验证生效

1. 游戏根目录放一个空的 `dev.txt`（开发工具开关，只在启动时读一次；注意别变成 `dev.txt.txt`）。
2. 进游戏按 **F8**，启动日志应有：

```
[囤水者预算 ×10]: patch applied: StoreClient.ApplyBudgetModifier (waterStockpiler budget x10)
```

3. 等上层区刷出囤水者（或读一个上层区客流高的档），F8 里每次生成都会打一行（最多记录 20 条）：

```
[囤水者预算 ×10]: waterStockpiler budget 537 -> 5370
```

4. 和囤水者对话，对方说的信用点数字应是四位数；拿高价水/纯水试卖，能成交的单价明显变高，且预算会正常递减到 0 后离开。

## 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 模组菜单里没有它 | `manifest.xml` 与 `StockpilerBudget.dll` 必须在 `Mods\stockpiler_budget_x10\` 同一层；启动日志 `[ModLoader]` 会写具体原因 |
| 激活后没生效 | 启用只在**重启后**生效；重编译过 DLL 还要在详情面板点「审核并启用」，或打开**开发者模式** |
| F8 里只有 `patch applied`，从不出现 `budget ... -> ...` | 你遇到的不是囤水者：同区的 waterSeller / waterCompany / 小贩都不在补丁范围内；也可能是旧版本存档里已经生成的顾客 |
| 日志出现 `ApplyBudgetModifier not found` | 游戏更新改了 `StoreClient`，按 `docs/target-notes.md` 复查后改补丁点 |
| 想恢复原版 | 模组菜单停用并重启，或直接删掉 `Mods\stockpiler_budget_x10` 文件夹；本模组不写存档、不改存档结构 |

停用后，**已经在队列里的那个囤水者**本次仍然带着 10× 预算，离开后就恢复原版；新刷出的顾客一律按原版走。这是运行时补丁的正常表现，不会在存档里留下任何标记。

## 目录结构

```
stockpiler_budget/
├─ build.ps1                    # csc 构建（不需要 SDK）
├─ deploy.ps1                   # 构建 + 部署到 Mods
├─ StockpilerBudget.csproj      # 有 .NET SDK 时的等价工程
├─ manifest.xml                 # ID / 版本 / Assemblies / Capabilities
├─ README.md
├─ docs/target-notes.md         # 反编译得到的补丁目标与复查方法
└─ src/
   ├─ StockpilerBudgetMod.cs    # IMod 入口：日志、补丁安装/卸载
   └─ StockpilerBudgetPatch.cs  # ApplyBudgetModifier Postfix：×10
```
