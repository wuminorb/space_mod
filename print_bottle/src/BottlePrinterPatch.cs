// Replaces the product of the "standard water bottle" button with a wine bottle.
//
// Verified call chain (game 1.0.0.x, Assembly-CSharp):
//   MachineBottlePrinter.CreateMachineInventoryWindow(...)
//     + button callbacks live in the private nested class MachineBottlePrinter/<>c__DisplayClass8_0:
//        <BottlePrinter>b__3 -> TryPrint("small_bottled_water", 4)
//        <BottlePrinter>b__4 -> IsNormalUnlocked ? TryPrint("bottled_water", 6) : return      <- 750 mL
//        <BottlePrinter>b__5 -> IsLargeUnlocked  ? TryPrint("large_bottled_water", 11) : return
//     + TryPrint(string bottleId, int cost):
//        output empty? -> enough power for cost? -> DirectoryMaster.Item(bottleId, true)
//        -> output grid accepts it? -> place -> draw power
//
// Swapping only the incoming id keeps power cost (6), output-grid checks and the
// "unlocked after 3 upgrades" gate exactly as vanilla.
//
// The target is a compiler-generated method, so it is resolved through the game's own
// ModReflect helper instead of System.Reflection: ModReflect is free of capabilities,
// while hand-rolled reflection on a dataflow-derived Type could be flagged as
// "reflection-external" (refused from 2026-12-10).

using System;
using System.Reflection;
using HarmonyLib;

namespace PrintBottle
{
    internal static class BottlePrinterPatch
    {
        /// <summary>Vanilla 750 mL bottled water product id.</summary>
        public const string StandardWaterBottleId = "bottled_water";

        /// <summary>Reflection full name of the compiler-generated display class.</summary>
        private const string DisplayTypeName = "MachineBottlePrinter+<>c__DisplayClass8_0";

        /// <summary>Name without the declaring type, used by the fallback scan.</summary>
        private const string DisplayTypeShortName = "<>c__DisplayClass8_0";

        /// <summary>Compiler-generated local function that performs one print.</summary>
        private const string TryPrintMethodName = "<BottlePrinter>g__TryPrint|1";

        /// <summary>
        /// Returns the printer's TryPrint(string, int) method, or null when the game
        /// version no longer has it (the mod then keeps running without the patch).
        /// </summary>
        internal static MethodBase ResolveTarget()
        {
            try
            {
                Type display = FindDisplayType();
                if (display == null) return null;

                return ModReflect.Target(
                    display,
                    TryPrintMethodName,
                    new Type[] { typeof(string), typeof(int) });
            }
            catch (Exception)
            {
                return null;
            }
        }

        private static Type FindDisplayType()
        {
            Type direct = ModReflect.FindType(DisplayTypeName);
            if (direct != null) return direct;

            // Fallback: the compiler may renumber the display class, so scan the game's
            // types for a nested one with the expected name inside MachineBottlePrinter.
            foreach (Type candidate in ModReflect.Types())
            {
                if (candidate.Name != DisplayTypeShortName) continue;
                if (candidate.FullName == null) continue;
                if (candidate.FullName.StartsWith("MachineBottlePrinter+", StringComparison.Ordinal)) return candidate;
            }

            return null;
        }

        /// <summary>__0 is TryPrint's first argument: the product item id.</summary>
        private static void Prefix(ref string __0)
        {
            if (__0 != StandardWaterBottleId) return;

            __0 = PrintBottleMod.WineBottleId;

            if (PrintBottleMod.Log != null)
            {
                PrintBottleMod.Log.Log("bottled_water -> wine_bottle");
            }
        }
    }
}
