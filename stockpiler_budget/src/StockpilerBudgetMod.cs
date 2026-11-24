// stockpiler_budget_x10 / v1.0.0
// IMod entry point: owns the ModLog and installs/removes the Harmony patch.
//
// Keep this file ASCII-only: the build uses csc.exe 4.x, which reads non-BOM
// sources using the system code page and would mangle non-ASCII literals.

using System;
using System.Reflection;
using HarmonyLib;

namespace StockpilerBudget
{
    public class StockpilerBudgetMod : IMod
    {
        public const string ModId = "stockpiler_budget_x10";

        /// <summary>Name of the patched method on the game's StoreClient type.</summary>
        private const string TargetMethodName = "ApplyBudgetModifier";

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
            ApplyPatch();
        }

        public void OnDisable()
        {
            RemovePatch();
        }

        private void ApplyPatch()
        {
            try
            {
                // typeof(game type) plus ModReflect is free of capabilities; do not
                // hand-roll reflection on a Type derived from game data.
                patchedTarget = ModReflect.Target(
                    typeof(StoreClient),
                    TargetMethodName,
                    Type.EmptyTypes);

                if (patchedTarget == null)
                {
                    Log.Error(TargetMethodName + " not found on StoreClient - patch skipped (game version changed?)");
                    return;
                }

                MethodInfo postfix = typeof(StockpilerBudgetPatch).GetMethod(
                    "Postfix",
                    BindingFlags.Static | BindingFlags.NonPublic);

                harmony = new Harmony("mod." + ModId);
                harmony.Patch(patchedTarget, null, new HarmonyMethod(postfix), null);

                Log.Log("patch applied: StoreClient." + TargetMethodName +
                        " (waterStockpiler budget x" + StockpilerBudgetPatch.Multiplier + ")");
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
    }
}
