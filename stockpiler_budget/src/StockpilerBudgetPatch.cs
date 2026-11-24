// stockpiler_budget_x10 / v1.0.0
// Gives the upper-level "water stockpiler" client (identifier: waterStockpiler)
// ten times its vanilla budget.
//
// Verified call chain (game 1.0.0.x, Assembly-CSharp):
//   StoreClientListTier.CreateWaterStockPiler()
//     identifier = "waterStockpiler"
//     displayName = LocHelper.GetLocalizedClientName("name_water_stockpiler")
//     clientFaction = "FACTION_UPPER_LEVEL"
//     SetBudget(500 + RNG.GetRandomInt(0, 100) + StoreStation.GetDayCounter())
//   StoreClient.SetBudget(int)
//     clientBudget = value; useClientBudget = true; ApplyBudgetModifier()
//   StoreClient.ApplyBudgetModifier()
//     applies reputation perks / starting perk / endorsement / attractiveness
//   StoreClient.GetBudget() is used afterwards to build the "I have {0} credits"
//   dialogue, so the multiplier must be applied before that line is built.
//
// StoreClient.SellItem() pays by calling ModBudget(-price) on the stored budget,
// so the budget must be scaled exactly once at creation. Patching GetBudget()
// instead would multiply the quote on every read and break that counter.
//
// The patched multiplier is applied in a Postfix on ApplyBudgetModifier: that
// runs at the end of every SetBudget(int) overload, after the perks, and before
// the factory reads GetBudget() for dialogue. Stored value stays a plain int in
// the save schema - the mod adds no fields and writes no save data.
//
// Target is a normal public game method, so it is resolved through the game's
// ModReflect helper (free of capabilities, supported from 2026-12-10) and the
// mod degrades to "patch skipped" if a game update removes it.

using System;
using System.Reflection;
using HarmonyLib;

namespace StockpilerBudget
{
    internal static class StockpilerBudgetPatch
    {
        /// <summary>Vanilla identifier of the upper-level water stockpiler client.</summary>
        public const string WaterStockpilerId = "waterStockpiler";

        /// <summary>Budget multiplier requested by the mod (10x).</summary>
        public const int Multiplier = 10;

        /// <summary>Only the first few scalings are logged to keep F8 readable.</summary>
        private static int loggedScalings;

        /// <summary>
        /// Harmony Postfix for StoreClient.ApplyBudgetModifier().
        /// Runs once per StoreClient.SetBudget(int) call, after perks were applied.
        /// </summary>
        private static void Postfix(StoreClient __instance)
        {
            if (__instance == null) return;
            if (__instance.identifier != WaterStockpilerId) return;

            int current = __instance.GetBudget();
            if (current <= 0) return;

            long scaled = (long)current * Multiplier;
            if (scaled > int.MaxValue) scaled = int.MaxValue;

            __instance.OverrideBudget((int)scaled);

            if (StockpilerBudgetMod.Log != null && loggedScalings < 20)
            {
                loggedScalings++;
                StockpilerBudgetMod.Log.Log(
                    "waterStockpiler budget " + current + " -> " + scaled);
            }
        }
    }
}
