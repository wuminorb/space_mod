// print_bottle / v0.2.0
// Makes the Bottle Printer's "standard water bottle" button output a wine bottle
// (wine_bottle) instead of a 750 mL bottled water.
//
// Layout:
//   PrintBottleMod     - IMod entry: logging, F9 spawn button, install/uninstall of the patch
//   BottlePrinterPatch - resolves the printer's TryPrint method and swaps the product id
//
// NOTE: keep this file ASCII-only. The build uses csc.exe 4.x, which reads non-BOM
// sources with the system code page and would mangle non-ASCII string literals.

using System;
using System.Reflection;
using HarmonyLib;

namespace PrintBottle
{
    public class PrintBottleMod : IMod
    {
        public const string ModId = "print_bottle";
        public const string WineBottleId = "wine_bottle";

        internal static ModLog Log;

        private Harmony harmony;
        private MethodBase patchedTarget;

        public void Init(ModManifest manifest)
        {
            // Init/OnEnable run on the main menu: game systems do not exist yet.
            Log = new ModLog(manifest);
        }

        public void OnEnable()
        {
            ModHelper.AddDebugFunction(ModId, ModHelper.DEBUG_CATEGORY_SPAWN, "Spawn Wine Bottle", SpawnWineBottle);
            ApplyPatch();
        }

        public void OnDisable()
        {
            ModHelper.RemoveDebugFunctions(ModId);
            RemovePatch();
        }

        private void ApplyPatch()
        {
            try
            {
                patchedTarget = BottlePrinterPatch.ResolveTarget();
                if (patchedTarget == null)
                {
                    Log.Error("TryPrint(string,int) not found on MachineBottlePrinter - patch skipped (game version changed?)");
                    return;
                }

                harmony = new Harmony("mod." + ModId);
                harmony.Patch(
                    patchedTarget,
                    new HarmonyMethod(typeof(BottlePrinterPatch).GetMethod("Prefix", BindingFlags.Static | BindingFlags.NonPublic)),
                    null,
                    null);

                Log.Log("patch applied: " + patchedTarget.DeclaringType.Name + "." + patchedTarget.Name);
            }
            catch (Exception e)
            {
                Log.Error("failed to apply patch: " + e);
            }
        }

        private void RemovePatch()
        {
            if (harmony == null || patchedTarget == null) return;
            try
            {
                harmony.Unpatch(patchedTarget, HarmonyPatchType.All, harmony.Id);
            }
            catch (Exception e)
            {
                Log.Warning("failed to remove patch: " + e.Message);
            }
            finally
            {
                harmony = null;
                patchedTarget = null;
            }
        }

        /// <summary>F9 debug button: spawn one wine bottle on the front counter.</summary>
        private void SpawnWineBottle()
        {
            try
            {
                GameItem item = ModHelper.SpawnItem(WineBottleId);
                ModHelper.MoveItemToFrontCounter(item);
                Log.Log("spawned a wine bottle (" + WineBottleId + ")");
            }
            catch (Exception e)
            {
                Log.Error("spawn failed: " + e);
            }
        }
    }
}
