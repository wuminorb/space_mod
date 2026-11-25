// Doubles the bottle printer's output grid capacity.
//
// Vanilla: MachineBottlePrinter/<>c__DisplayClass8_0.<BottlePrinter>g__ApplyUpgradeState|2
// calls outputGrid.SetShape(OUTPUT_BASE_WIDTH + normalUnlocked + largeUnlocked, OUTPUT_HEIGHT)
// i.e. 4x4 -> 5x4 -> 6x4 and then validates the grid / window / machine.
//
// The prefix below sees that same SetShape(int width, int height) call and doubles the width
// for the grids registered by PrinterButtons.WindowPostfix: 4x4 -> 8x4, 5x4 -> 10x4,
// 6x4 -> 12x4. The vanilla code right after SetShape (SetShape validates the grid itself, then
// ApplyUpgradeState validates window and machine) re-lays the machinery window, so no extra
// validation is needed here.
//
// Every other machine in the game calls the very same GameGridInventory.SetShape method when it
// upgrades its storage. The registry check keeps them untouched; if the set ever gets out of
// sync the "only shapes that look like the printer's" range check below still avoids runaway
// growth. This method is not part of the save format - the shape is re-derived on every load.

namespace PrintBottle
{
    internal static class PrinterCapacity
    {
        /// <summary>Vanilla base output width and the widest vanilla shape after both unlocks.</summary>
        private const int MinPrinterWidth = 4;
        private const int MaxPrinterWidth = 6;

        /// <summary>Harmony prefix for GameGridInventory.SetShape(int width, int height).</summary>
        private static void SetShapePrefix(GameGridInventory __instance, ref int __0)
        {
            if (!PrintBottleMod.Enabled || __instance == null) return;
            if (!PrinterButtons.IsOutputGrid(__instance)) return;

            // Only touch the shapes the vanilla printer code asks for (4/5/6). Anything else
            // means the game changed or some other code touched the grid: leave it alone.
            if (__0 < MinPrinterWidth || __0 > MaxPrinterWidth) return;

            int doubled = __0 * 2;
            PrintBottleMod.Log.Log("output grid widened: " + __0 + " -> " + doubled + " columns");
            __0 = doubled;
        }
    }
}
