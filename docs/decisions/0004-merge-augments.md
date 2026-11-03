# 0004: Merge augments, your own kit made stronger, and a drained Boki after the ultimate

- **Status:** accepted (owner design of Nov 2 2026; supersedes the "kit swap" part of [0003](0003-merge-forms.md))
- **Date:** 2026-11-02
- **Area:** combat / networking / UI (the Merge, hunter inputs, Kin, Net)

## Problem
0003 replaced your LMB, RMB and E with the form's own kit. It is a second moveset to learn per Boki, it hides the hero you picked, and it needs hold mechanics (boulder, hover, prism) that only the form kits used.

## Options
1. Keep the kit swap and add forms 4-9: rejected, nine movesets on top of nine heroes.
2. An augment per hero x Boki pair: rejected, 6 x 9 sets (as in 0001).
3. One augment set per Boki TYPE (decided), the same for every hero. You keep LMB, RMB, E, Shift and Q, and the form makes each stronger.

## Decision
- **Flow** (`KinMerge`): unchanged up to the transformation (0.7s, `MergeXform`, `MergeLook`, the colour wash, the shell bar, no tiers). Live for the form's duration (~10s). R again fires that Boki's ultimate, unlocked 1.5s in (Collapse, Thunderhead, Shatter; the other six a basic burst).
- **Augments** (`MergeAugment`, data in `content/merge_forms/<id>.json` under `aug`, fallback forms get one from their type in `content/rules/merge_forms.json`):
  - LMB: a rider on every attack through the existing shot/swing rider path (`Hunter._kin_riders`: chain, pierce, slow, burn, an extra effect list on every Nth attack).
  - RMB and E: when the hero casts one (`CombatBus.ability_used` "secondary" / "kin"), the form adds an effect list in the effect grammar at the same spot and recharges that slot faster. It works on any kit, because it hangs off the cast signal and not off a kit's own code.
  - Shift: a form dash on top of the hero's own dash (`dash_kind`: sweep = damage along the path, charge = armoured shove, reflect = a short mirror window, trail = the type rider on what you pass, then haste; no dash makes an area burst).
  - Stats: a modest passive through `KinMerge.passives` (damage reduction, speed, cooldown rate).
- **Clarity:** augmented slots get a tint and a Boki-type badge on the HUD, and every add-on has its own ring and word colour. The last 3s of the window warn loudly: the R slot flashes, a rising tick each second, the parts flicker, a screen-edge pulse in the form colour.
- **Ending:**
  - released (the merge key again, the ultimate fired): you separate on a high. For `afterglow.secs` (3s) you move `afterglow.move_speed` (+15%) faster with a shield of `afterglow.shield_frac` (8%) of max health, with a gold ring, sparkles and a sound (`MergeRelease`). The Boki lands beside you pumped, following, and rests `release_rest_s` (6s): no C, no Sic or orders (G reads "resting"), carried bonuses still apply, the meter restarts at 0, the HUD shows the rest timer on the Boki card.
  - timeout: the Boki pops out in Follow, no burst, no afterglow, no rest beyond the plain spent window (`KinParts.MERGE_SPENT_TIME`, 3s). Shell broken: as before.
- **Damage cap:** while merged, the stat-based damage bonus totals at most `damage_cap` (+20%, `merge_forms.json`; `KinMerge.cap_damage`). A merge's own damage passive tops out at +20% (`KinParts.OWNER_STATS`, so the Vespyx and Hivara merges went from +30% to +20%), and buffs plus the merge together are held to the cap, so an ultimate into a merge cannot one-shot. Gear and perks you already had are never cut. Form shields, the ultimates' own damage and the bless/weak multipliers are not stats and stay as they are.
- **Keys:** T is Merge (T again releases), R reloads (build mode keeps R for rotate), X is the hunter ultimate (`ArchKit.cast_ult`, no hero has one yet). Old saves move once (`KeyMigrate`).
- **Bond:** `KinBond.add(hunter, share, reason)` is the one way to put a share into the bond bar (fighting uses it too); `KinBond.from_ult(hunter, "hit"|"knock"|"kill")` pays a hero ultimate's share (`bond_from_ult` in `boki_system.json`: 0.6, 0.7, 0.8), best event of a cast, not per target.
- **Removed:** `MergeKit` routing of LMB/RMB/E, `MergeHolds` (boulder, hover, prism, blink; the ultimate's climb moves to `MergeKit`), the `lmb`/`rmb`/`e` blocks of the form files, the poses only they used. `ArchKit._drop_holds` runs at merge start only (the transformation), so hero holds stay usable afterwards.
- **Net:** `Net.VERSION` 0.14.0 to 0.15.0. The kin snapshot carries the rest seconds; casts that need a tell in another game use the existing `mcast` event.

## Consequences
- New: `scripts/kin/merge_augment.gd`, `docs/decisions/0004-merge-augments.md`. Rewritten: `tools/merge_form_check.gd`, `merge_kit.gd` (ultimate only). Deleted: `merge_holds.gd`. Wiring only in hunter.gd, kin.gd, kin_follow.gd, kin_command.gd, arch kits' `KinMerge.active` guards (now `transforming`), hud.gd, boki_hud.gd, bot.gd.
- Debt: the six other Boki have fallback augments (the type rider on LMB, the type dash trail, no RMB/E add-ons) and a basic burst ultimate until their form files land.
