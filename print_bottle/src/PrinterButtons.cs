// Adds two extra print buttons to the bottle printer and remembers its output grid.
//
// Verified layout (game 1.0.0.x, Assembly-CSharp):
//   MachineBottlePrinter.BottlePrinter()
//     -> MachineBottlePrinter.CreateMachineInventoryWindow(bool, bool, int)
//          battery = new GameSlotInventory()
//          output  = new GameGridInventory(4, 4)
//          buttons = small / normal / large MachineryButton
//          panels  = PowerPanel(battery), Panel(output), Panel(Vertical(3 buttons), "control")
//          window  = MachineHelper.CreateMachineryWindow(...)   childElement = MachineryPanelRow
//          returns ValueTuple6(window, battery, output, small, normal, large)
//     -> sets the three vanilla callbacks, wraps everything into the machine GameItem,
//        SetContentWindow(window), then ApplyUpgradeState() sets the output grid shape.
//
// The Harmony postfix below runs right after CreateMachineInventoryWindow returns and before
// BottlePrinter() creates the machine GameItem. It appends two buttons to the control column
// and re-validates the panel row so the window grows by the extra button rows. The three
// vanilla buttons are left untouched; the 750 mL product is vanilla again.
//
// Printing re-implements the same four checks as the vanilla TryPrint local function:
//   battery slot not empty -> CanDrawPowerSource(battery, cost) -> DirectoryMaster.Item(id, true)
//   -> GraphUtils.CanAccept(outputGrid, product) -> TryAcceptAll(...) -> DrawPowerSource(...)
// Doing it here (instead of patching the compiler-generated TryPrint) keeps this file free of
// private nested types and harmless when the game's method names change.
//
// Nothing here touches save data: it only adds widgets to a UI window that the game rebuilds
// from the item id every time a save is loaded.

using System;
using System.Collections.Generic;

namespace PrintBottle
{
    internal static class PrinterButtons
    {
        internal const string WineBottleId = "wine_bottle";
        internal const string WaterJugId = "water_jug";

        // Power per print. Vanilla: small 450 mL = 4, normal 750 mL = 6, large 2 L = 11.
        // A wine bottle is a 1 L container worth ~12 credits, the jug is a 6 L container.
        // Tune these two numbers if the mod should feel cheaper / more expensive.
        internal const int WinePrintCost = 8;
        internal const int JugPrintCost = 16;

        private const string WineLabelKey = "btn_print_wine";
        private const string WineLabelFallback = "Print Wine Bottle";
        private const string JugLabelKey = "btn_print_jug";
        private const string JugLabelFallback = "Print 6L Jug";

        /// <summary>
        /// Output grids created for a bottle printer, used by PrinterCapacity. A List (not a
        /// HashSet) keeps the compiled DLL free of a System.Core reference: only mscorlib,
        /// Assembly-CSharp and 0Harmony are referenced, like before.
        /// </summary>
        private static readonly List<GameGridInventory> outputGrids = new List<GameGridInventory>();

        internal static bool IsOutputGrid(GameGridInventory grid)
        {
            if (grid == null) return false;
            for (int i = 0; i < outputGrids.Count; i++)
            {
                if (ReferenceEquals(outputGrids[i], grid)) return true;
            }
            return false;
        }

        internal static void ClearTracked()
        {
            outputGrids.Clear();
        }

        /// <summary>Harmony postfix for MachineBottlePrinter.CreateMachineInventoryWindow.</summary>
        private static void WindowPostfix(
            ref ValueTuple<PixelWindow, GameSlotInventory, GameGridInventory, MachineryButton, MachineryButton, MachineryButton> __result)
        {
            if (!PrintBottleMod.Enabled) return;

            try
            {
                PixelWindow window = __result.Item1;
                GameSlotInventory batterySlot = __result.Item2;
                GameGridInventory outputGrid = __result.Item3;

                if (window == null || batterySlot == null || outputGrid == null)
                {
                    PrintBottleMod.Log.Warning("printer window postfix: unexpected null result, extra buttons skipped");
                    return;
                }

                // Register before anything else: even if the widget search below fails, the
                // capacity patch should still see the grid.
                outputGrids.Add(outputGrid);

                MachineryPanelRow row = window.childElement as MachineryPanelRow;
                MachineryPanel controlPanel = row == null ? null : row.GetPanel("control");
                MachineryStack stack = FindStack(controlPanel == null ? null : controlPanel.content);

                if (stack == null)
                {
                    PrintBottleMod.Log.Warning("printer window postfix: control stack not found, extra buttons skipped");
                    return;
                }

                MachineryButton wineButton = CreateButton(WineLabelKey, WineLabelFallback,
                    delegate { TryPrint(batterySlot, outputGrid, WineBottleId, WinePrintCost); });
                MachineryButton jugButton = CreateButton(JugLabelKey, JugLabelFallback,
                    delegate { TryPrint(batterySlot, outputGrid, WaterJugId, JugPrintCost); });

                stack.Add(wineButton);
                stack.Add(jugButton);

                // Re-layout: panel row -> panel -> window. MachineryStack.Add already validates
                // the stack itself; the row validation below pushes the new height up the chain.
                if (controlPanel != null) controlPanel.Validate();
                if (row != null) row.Validate();
                window.Validate();

                PrintBottleMod.Log.Log("added print buttons: wine bottle (" + WinePrintCost + " power), 6L jug (" + JugPrintCost + " power)");
            }
            catch (Exception e)
            {
                // Never let a UI failure take down the vanilla printer.
                PrintBottleMod.Log.Error("printer window postfix failed (extra buttons skipped): " + e);
            }
        }

        /// <summary>
        /// Same checks and order as the vanilla printer's TryPrint local function. Runs on the
        /// main thread from a button callback; every failure path just returns (no power drawn).
        /// </summary>
        private static void TryPrint(GameSlotInventory batterySlot, GameGridInventory outputGrid, string itemId, int cost)
        {
            if (!PrintBottleMod.Enabled || batterySlot == null || outputGrid == null) return;

            try
            {
                if (batterySlot.childItems.Count == 0) return;

                GameItem battery = batterySlot.childItem;
                if (battery == null) return;
                if (!PowerHelper.CanDrawPowerSource(battery, cost)) return;

                GameItem product = DirectoryMaster.Item(itemId, true);
                if (product == null)
                {
                    PrintBottleMod.Log.Error("could not create item: " + itemId);
                    return;
                }

                if (!GraphUtils.CanAccept(outputGrid, product)) return;

                GraphUtils.TryAcceptAll(outputGrid, product, -1);
                PowerHelper.DrawPowerSource(battery, cost);
                PrintBottleMod.Log.Log("printed " + itemId + " for " + cost + " power");
            }
            catch (Exception e)
            {
                PrintBottleMod.Log.Error("print failed (" + itemId + "): " + e);
            }
        }

        private static MachineryButton CreateButton(string locKey, string fallback, Action callback)
        {
            // -1/-1 = let the machinery layout pick the button size (same as the vanilla buttons).
            return new MachineryButton(Label(locKey, fallback), callback, -1, -1);
        }

        private static MachineryStack FindStack(PixelElement element)
        {
            if (element == null) return null;

            MachineryStack stack = element as MachineryStack;
            if (stack != null) return stack;

            // MachineHelper.Panel wraps inventories in a MachineryIntake; the control panel
            // content is a plain MachineryStack today, but follow the wrapper if that changes.
            MachineryIntake intake = element as MachineryIntake;
            if (intake != null) return FindStack(intake.content);

            return null;
        }

        private static string Label(string locKey, string fallback)
        {
            try
            {
                string text = ModHelper.GetLocalized(PrintBottleMod.ModId, locKey);
                if (!string.IsNullOrEmpty(text) && text != locKey) return text;
            }
            catch (Exception e)
            {
                PrintBottleMod.Log.Warning("localization failed for " + locKey + ": " + e.Message);
            }
            return fallback;
        }
    }
}
