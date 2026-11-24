# print_bottle —— 让水瓶打印机打印酒瓶

《深空当铺：可能是偷的》（Probably Stolen）原生模组。已实现：**把水瓶打印机「标准水瓶」那一档的产物换成酒瓶**。

- Mod ID：`print_bottle`
- 程序集：`PrintBottle.dll`
- 版本：**v0.2.0**
- 目标游戏：1.0.0.x（清单里写 `1.0.0` 覆盖整个 1.0.0 的所有修订）

## 它改了什么

| | 原版 | 装了本模组 |
| --- | --- | --- |
| 小号按钮（4 电） | 小号瓶装水 `small_bottled_water` | 不变 |
| **标准按钮（6 电）** | 750 mL 瓶装水 `bottled_water` | **酒瓶 `wine_bottle`** |
| 大号按钮（11 电） | 大号瓶装水 `large_bottled_water` | 不变 |
| 解锁条件 | 累计升级 3 次 | 不变 |
| 耗电 / 输出区判定 | 电不够或放不下就不打印也不扣电 | 不变 |

酒瓶是合法的**空瓶**（`WineDirectory.WineBottle()` 工厂会跑 `WineHelper.InitWineBottle`，带气塞与发酵标签），打印出来直接灌水/发酵即可。

实现方式：只给打印机内部那一个 `TryPrint(string bottleId, int cost)` 加 `Prefix`，把 `bottled_water` 换成 `wine_bottle`。扣电、输出区、解锁判断全部走原版代码，所以行为差异只有产物本身。

目标方法是编译器生成的私有嵌套类成员，因此用游戏自带的 `ModReflect.FindType` / `ModReflect.Target` 解析，而不是自己写 `System.Reflection` —— 后者在数据流推导出来的 `Type` 上做成员查找会被扫描器算成 `reflection-external`（2026-12-10 起直接拒绝启动），而 `ModReflect` 是免能力的官方入口。

## 构建与安装

本机没装 .NET SDK，用 Windows 自带的 `csc.exe` 就能编（`build.ps1`）：

```powershell
cd D:\space_mod\print_bottle
.\build.ps1          # 产物 bin\Release\PrintBottle.dll
.\deploy.ps1         # 构建 + 复制到 %GameDir%\Mods\print_bottle
```

装了 SDK 也可以用 `dotnet build -c Release`（`PrintBottle.csproj` 里 `GameDir` 属性指向游戏目录，换机器只改这一处）。

游戏目录默认 `E:\SteamLibrary\steamapps\common\Probably Stolen`，可用 `-GameDir` 覆盖。

首次安装后：主菜单 **Mods** → 选中「打印酒瓶」→ **Activate** → **重启游戏**。

## 怎么验证生效

1. 游戏根目录放一个空的 `dev.txt`（开发工具开关，只在启动时读一次；注意别变成 `dev.txt.txt`）。
2. 进游戏读档，按 **F8** 看控制台，应有：

```
[打印酒瓶]: patch applied: <>c__DisplayClass8_0.<BottlePrinter>g__TryPrint|1
```

3. 把水瓶打印机升到 3 级解锁标准档，点标准按钮，控制台每次打印都会打一行：

```
[打印酒瓶]: bottled_water -> wine_bottle
```

输出区出来的应该是酒瓶而不是瓶装水。

4. 顺带的自检：**F9 → Spawn → Spawn Wine Bottle** 会在柜台上直接放一个酒瓶（不需要打印机，用来单独确认物品可用）。

## 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 模组菜单里没有它 | `manifest.xml` 与 `PrintBottle.dll` 必须在 `Mods\print_bottle\` 同级目录下；F8 控制台启动日志会指出具体问题 |
| 激活后没生效 | 启用只在**重启后**生效；重编译过 DLL 还要在详情面板点「审核并启用」，或打开**开发者模式** |
| F8 只有 `patch applied` 没有 `bottled_water ->` | 打印机没解锁标准档（需累计升级 3 次），或你点的是小号/大号按钮 |
| 日志出现「TryPrint(string,int) not found」 | 游戏更新改了打印机代码，见 `docs/target-notes.md` 的复查方法 |
| 想恢复原版 | 在模组菜单停用并重启，或直接删掉 `Mods\print_bottle` 文件夹；本模组不写存档、不动存档结构 |

改了打印机行为属于「核心循环」改动，官方明确不保证兼容；游戏大版本更新后可能失效，失效时控制台会给出上面的 not found 日志而不是崩溃。

## 目录结构

```
print_bottle/
├─ build.ps1                    # csc 构建（不需要 SDK）
├─ deploy.ps1                   # 构建 + 部署到 Mods
├─ PrintBottle.csproj           # 有 .NET SDK 时的等价工程
├─ manifest.xml                 # ID / 版本 / Assemblies / Capabilities
├─ src/
│  ├─ PrintBottleMod.cs         # IMod 入口：日志、F9 按钮、补丁装卸
│  └─ BottlePrinterPatch.cs     # 定位 TryPrint + 替换产物 id
└─ docs/target-notes.md         # 反编译结论、复查方法、可选的后续改动
```

## 合规自检（发布前）

- `<Assemblies>` 只列了 `PrintBottle.dll`；构建产物没有把 `0Harmony` / Unity / `netstandard` 拷进来（引用都指向游戏自带的副本）。
- 没有 `files` / `network` / `process` 等能力，`<Capabilities />` 为空；不需要声明 `reflection-external`（反射目标都是 `typeof(MachineBottlePrinter)` 这种静态已知的游戏类型）。
- 发布前在游戏内 F8 运行 `mod-scan print_bottle`，确认没有 `DEPRECATED` 行、`detected` 为空。
- 不含任何数据文件、不写存档、不联网。

## 参考资料

- [社区指南仓库：README / ModdingGuide / APIChanges](https://github.com/dragonpan2/probably-stolen-modding)
- [模组制作指南中文版（钩子、能力声明、创意工坊）](https://github.com/dragonpan2/probably-stolen-modding/blob/main/ModdingGuide.zh-CN.md)
- [水瓶打印机（BWIKI）：三档产物、耗电、解锁](https://wiki.biligame.com/probablystolen/%e6%b0%b4%e7%93%b6%e6%89%93%e5%8d%b0%e6%9c%ba)
- [酒瓶（BWIKI）：物品 ID `wine_bottle`](https://wiki.biligame.com/probablystolen/%e9%85%92%e7%93%b6)
- [瓶子与容器机制说明](https://probablystolenguide.com/zh-hans/wiki/bottles-and-containers/)
