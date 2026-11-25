using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using HarmonyLib;

internal static class Probe
{
    private static void Test(
        ValueTuple<PixelWindow, GameSlotInventory, GameGridInventory, MachineryButton, MachineryButton, MachineryButton> t)
    {
        GameGridInventory g = t.Item3;
        g.SetShape(8, 4);
        MachineryStack s = null;
        s.Add(t.Item4);
        IReadOnlyList<PixelElement> els = s.elements;
        MachineryPanelRow row = null;
        MachineryPanel p = row.GetPanel("control");
        PixelElement content = p.content;
        p.Validate();
        row.Validate();
        MachineryButton bt = new MachineryButton("x", null, -1, -1);
        bool dis = bt.isDisabled;
        bt.Enable();
        GameItem machine = null;
        PixelWindow win = machine.contentWindow;
        win.Validate();
        bool hasItems = t.Item2.childItems.Count > 0;
        GameItem battery = t.Item2.childItem;
        GameSlotInventory battery2 = MachineHelper.GetBatterySlot(machine);
        GameInventory slot = MachineHelper.GetSlot(machine, 1);
        bool can = PowerHelper.CanDrawPowerSource(battery, 6);
        GameItem product = DirectoryMaster.Item("wine_bottle", true);
        bool ok = GraphUtils.CanAccept(g, product);
        GraphUtils.TryAcceptAll(g, product, -1);
        PowerHelper.DrawPowerSource(battery, 6);
        int n = MachineBottlePrinter.GetUpgradeCount(machine);
        bool lvl = MachineBottlePrinter.IsNormalUnlocked(machine);
        string s2 = ModHelper.GetLocalized("print_bottle", "btn_wine", new object[0]);
        string s3 = ModHelper.GetLocalized("print_bottle", "btn_wine");
        MethodBase mb = ModReflect.Target(typeof(GameGridInventory), "SetShape", new Type[] { typeof(int), typeof(int) });
        Console.WriteLine(content + " " + n + s2 + s3 + can + ok + hasItems + dis + els.Count + slot + battery2 + lvl + mb);
    }

    // Harmony patch prototype signatures
    private static void SetShapePrefix(GameGridInventory __instance, ref int __0)
    {
        __0 = __0 * 2;
    }

    private static void WindowPostfix(
        ref ValueTuple<PixelWindow, GameSlotInventory, GameGridInventory, MachineryButton, MachineryButton, MachineryButton> __result)
    {
        __result.Item1.Validate();
    }
}
