// print_bottle / v0.3.0
// Bottle Printer mod:
//   * restores the vanilla 750 mL bottled-water button (that product is no longer replaced)
//   * adds two extra print buttons: wine bottle (wine_bottle) and 6 L water jug (water_jug)
//   * doubles the printer's output grid capacity (4x4 -> 8x4; every upgrade tier is doubled too)
//
// Layout:
//   PrintBottleMod  - IMod entry: logging, F9 spawn buttons, patch install/uninstall
//   PrinterButtons  - postfix on MachineBottlePrinter.CreateMachineInventoryWindow: appends the
//                     two buttons to the control column and remembers the output grid
//   PrinterCapacity - prefix on GameGridInventory.SetShape(int,int): doubles the width of the
//                     remembered bottle-printer output grid
//
// NOTE: keep every source file ASCII-only. csc.exe 4.x reads non-BOM sources with the system
// code page and would mangle non-ASCII string literals. Chinese/English labels live in
// Localization/*.csv (UTF-8) and are read through ModHelper.GetLocalized.

using System;
using System.Collections.Generic;
using System.Reflection;
using HarmonyLib;

namespace PrintBottle
{
    public class PrintBottleMod : IMod
    {
        public const string ModId = "print_bottle";

        internal static ModLog Log;
        internal static bool Enabled;

        private Harmony harmony;
        private readonly List<MethodBase> patchedMethods = new List<MethodBase>();

        public void Init(ModManifest manifest)
        {
            // Init/OnEnable run on the main menu: game systems do not exist yet.
            Log = new ModLog(manifest);
        }

        public void OnEnable()
        {
            Enabled = true;
            ModHelper.AddDebugFunction(ModId, ModHelper.DEBUG_CATEGORY_SPAWN, "Spawn Wine Bottle", SpawnWineBottle);
            ModHelper.AddDebugFunction(ModId, ModHelper.DEBUG_CATEGORY_SPAWN, "Spawn 6L Water Jug", SpawnWaterJug);
            ApplyPatches();
        }

        public void OnDisable()
        {
            Enabled = false;
            ModHelper.RemoveDebugFunctions(ModId);
            RemovePatches();
            PrinterButtons.ClearTracked();
        }

        private void ApplyPatches()
        {
            harmony = new Harmony("mod." + ModId);

            // 1) Append two print buttons to the printer's control column and remember its
            //    output grid so the capacity patch below can identify it.
            Patch(typeof(MachineBottlePrinter), "CreateMachineInventoryWindow",
                new Type[] { typeof(bool), typeof(bool), typeof(int) },
                null,
                typeof(PrinterButtons).GetMethod("WindowPostfix", BindingFlags.Static | BindingFlags.NonPublic),
                "printer window: additive buttons");

            // 2) Widen the bottle-printer output grid to twice the vanilla width.
            //    A prefix on the target method is harmless for every other machine: only grids
            //    registered by PrinterButtons.WindowPostfix are touched.
            Patch(typeof(GameGridInventory), "SetShape",
                new Type[] { typeof(int), typeof(int) },
                typeof(PrinterCapacity).GetMethod("SetShapePrefix", BindingFlags.Static | BindingFlags.NonPublic),
                null,
                "printer output capacity x2");
        }

        private void Patch(Type declaring, string name, Type[] signature, MethodInfo prefix, MethodInfo postfix, string what)
        {
            try
            {
                MethodBase target = ModReflect.Target(declaring, name, signature);
                harmony.Patch(
                    target,
                    prefix == null ? null : new HarmonyMethod(prefix),
                    postfix == null ? null : new HarmonyMethod(postfix));

                patchedMethods.Add(target);
                Log.Log("patch applied: " + declaring.Name + "." + name + " (" + what + ")");
            }
            catch (Exception e)
            {
                // Version drift: keep running with vanilla behaviour instead of breaking the game.
                Log.Error("patch skipped: " + declaring.Name + "." + name + " (" + what + "): " + e);
            }
        }

        private void RemovePatches()
        {
            if (harmony == null) return;

            for (int i = 0; i < patchedMethods.Count; i++)
            {
                try
                {
                    harmony.Unpatch(patchedMethods[i], HarmonyPatchType.All, harmony.Id);
                }
                catch (Exception e)
                {
                    Log.Warning("failed to remove patch " + patchedMethods[i].Name + ": " + e.Message);
                }
            }

            patchedMethods.Clear();
            harmony = null;
        }

        /// <summary>F9 debug button: spawn one wine bottle on the front counter.</summary>
        private static void SpawnWineBottle()
        {
            SpawnItem(PrinterButtons.WineBottleId, "wine bottle");
        }

        /// <summary>F9 debug button: spawn one 6 L water jug on the front counter.</summary>
        private static void SpawnWaterJug()
        {
            SpawnItem(PrinterButtons.WaterJugId, "6L water jug");
        }

        private static void SpawnItem(string itemId, string label)
        {
            try
            {
                GameItem item = ModHelper.SpawnItem(itemId);
                ModHelper.MoveItemToFrontCounter(item);
                Log.Log("spawned " + label + " (" + itemId + ")");
            }
            catch (Exception e)
            {
                Log.Error("spawn failed (" + itemId + "): " + e);
            }
        }
    }
}
