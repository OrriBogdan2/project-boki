# 0022: Ultimate ranks

- **Status:** proposed (spec only, no code)
- **Date:** 2026-11-09
- **Area:** combat, progression

## Problem
`docs/heroes/thief.md` says the ult's numbers grow with rank, but the twelve X ultimates (`HeroUlt`) do not.
Hunter.slot_lv["ult"] (max 2, gates `ULT_AT = [6, 9]`) already exists and the HUD shows it as the R slot,
but all it does is open the hero ult and the Merge (the Merge lasts +30% at rank 2). A hero's own ult
reads no rank. Owner decisions: on level-up the player chooses which ability to rank; maxing one unlocks
its bonus; the ult is R.

## Source: R ranks (briefs/supervive-data/supervive_kits.md, on ext/agent-briefs)
Tiers: "R has II/III only" (line 4), so an R has three ranks: I (base) and two upgrades. `A / B` = tier
II / tier III; `x2` = the same step at each tier. Cooldown is in seconds.

| Source hero (line) | Ours | Base | Upg: II / III | Ours already? |
|---|---|---|---|---|
| Elluna, channel heal (13) | tender Hearth Call | 60s | none listed | no ranks; base only |
| Brall, Volcanic Rebuke (28) | juggernaut Gilded Riposte | 45s | +30 dmg, +5% AP, -5s CD at each tier | cd 36s; the generic rank only |
| Celeste, Chilling Finale (36) | rimewright Rimelock | 80s | +40% dmg and -10s / -10s | cd 80s; none |
| Felix, Flight of the Firefox (44) | ashwick Flue Flight | 45s | -15s / +25% dmg | cd 36s; none |
| Ghost, Summon Napalm (52) | gunslinger Cinderfall | 55s | +20% dmg, -5s at each tier | cd 42s; none |
| Kingpin, Slugwave (61) | dredge Brass Broadside | 36s | +20% dmg, -5s at each tier | cd 21s; none |
| Joule, Thunderstorm (69) | mage Kitefall | 60s | +50% impact dmg and -7.5s / -7.5s | cd 42s; none |
| Myth, Virideth's Fury (77) | archer Starpiercer | 60s | +10% dmg, -5s at each tier | cd 60s; none |
| Oath, Abyssalbreaker (93) | bulwark Faultline | 50s | +20% dmg, -5s at each tier | cd 40s; none |
| Shiv, Fusillade (101) | thief Encore | 50s | +10% dmg, -5s at each tier | cd 24s; none |
| Tetra, Tetraform (109) | dolm Basalt Spine | 45s | -5s, +2.5s wall life at each tier | cd 45s; none |
| Void, Singularity (117) | ostra Nightwell | 70s | -5s at each tier | cd 70s; none |

"Approximate" today means only the base: every kit has a cooldown near the source's (a few were cut for our
shorter matches) and the shared rank rules (below). No kit reads an X rank. Elluna's line lists no Upg, so
tender gets the generic step only.

## Options
1. A new slot `x` beside `ult`. Ranks and Merge ranks would split cleanly, but a fifth slot means a new
   HUD tile, key hint and save field, and ten skill points already cover only 3 x 3 + 2 + Q.
2. Reuse `slot_lv["ult"]` as the R rank (the HUD's R tile already draws it), raise `SLOT_MAX["ult"]` to 3
   and let `HeroUlt` read it. The Merge keeps its rank-2 bonus. **Chosen.**
3. Ult ranks only at fixed levels (no choice). Rejected: breaks the owner decision.

## Decision
Option 2. Ranks stay a spend of the same skill point, chosen by the player (Alt + R or the gold + on the R
slot, as for every slot); maxing a slot unlocks its bonus (the existing `rank3` text on each kit).

**When a rank is offered.** `Hunter.ULT_AT` becomes `[6, 9, 10]`: rank 1 at level 6 (unchanged), rank 2 at 9
(unchanged), rank 3 at 10 (the cap). `can_level("ult")` already indexes it. A level-10 hunter has had 10
points, so a full R costs 3 of them: it competes with the other slots, which is the point.

**What a rank does** (all in `HeroUlt`, no per-kit code):
- Generic step per rank past 1, like every slot: damage +15% (`Effects.level_k`) and cooldown -10% (`rank_cd_k`).
  `HeroUlt.cooldown(k)` multiplies by `rank_cd_k("ult")`; kits that use `x_def().dmg` multiply by `level_k`.
- Hero step: `x` in the archetype JSON may carry `"per_rank": {"cooldown": [-5, -5], "dmg": [0.2, 0.2], "time": [..]}`
  (one entry per rank past 1), taken from the table. An entry replaces the generic step for that key.
  Rank 3 text lives in `rank3.x` / `rank2.x` (same keys the other slots use, shown by `rank_text`).
- Numbers are ours: the table gives the direction and size, not a promise to match; each hero's doc
  records its chosen values.

**Bots.** `_bot_spend` already spends on `ult` first whenever `can_level("ult")` is true. Keep that for
ranks 1 and 2 and put rank 3 in the archetype `order` (`"ult"` last) so a bot at 10 takes it only if no
slot is still below its rank-2 line. `order` filters `"ult"` today (hunter.gd `_bot_spend`); change the
filter to keep it after rank 2.

**HUD.** No new widget. `rank_text("r")` shows "Rank n / 3, next rank: <rank2/3 text>" from the JSON; the
R tile's tier pips go to three; `r_lock_text` is unchanged for rank 1. The gold + shows while
`can_level("ult")`. Toast on rank 3: the kit's `rank3.x` line.

**Data shape.** Per `content/archetypes/<id>.json`: add `x.per_rank` (above), `rank2.x` and `rank3.x`
strings. No new files. `tools/gen_wiki.py` and `docs/ABILITIES.md` pick the strings up.

**Net / save.** Rank is already `slot_lv`, which the snapshot and saves carry (`ult` is 0-2 today, 3 is the
same int). Net.VERSION: bump once when `SLOT_MAX` and `ULT_AT` change, because a v-old client would clamp
a 3. No save field changes, so no migration; a run in progress is not saved. Practice `unlock_all` stays at
rank 1.

## Consequences
- One shared edit (hunter.gd constants, a few lines; `hero_ult.gd` cooldown and `level_k`) plus data per hero.
- `docs/ABILITIES.md` line 9 ("rank 2 at 9") and the Ranks section (R: ranks 1-2) change to 1-3.
- Check: extend the rank check so rank 3 needs level 10, `HeroUlt.cooldown` shrinks with rank, and a bot at
  10 takes rank 3.
- Alternative kept open: option 1 if the owner wants Merge and ult ranks spent separately.

## Per-hero build items (for the planner)
1. Shared: `ULT_AT`, `SLOT_MAX`, `_bot_spend`, `HeroUlt.cooldown`, `rank_text`, pips to 3, Net.VERSION, check.
2. juggernaut: `x.per_rank` dmg +30 flat each rank, cd -5; `rank3.x` text.
3. rimewright: dmg +40% and cd -10 at rank 2, cd -10 at 3.
4. ashwick: cd -12 at rank 2 (the source -15 scaled 36/45), dmg +25% at 3.
5. gunslinger: dmg +20%, cd -5 each rank (napalm blast and fire zone both).
6. dredge: dmg +20%, cd -5 each rank (both waves).
7. mage: impact dmg +50% and cd -7.5 at 2, cd -7.5 at 3.
8. archer: dmg +10%, cd -5 each rank (the three shots).
9. bulwark: dmg +20%, cd -5 each rank (first strike and eruptions).
10. thief: dmg +10%, cd -5 each rank; her wiki note "Not built" line in `docs/heroes/thief.md` goes.
11. dolm: cd -5 and wall lifetime +2.5s each rank (`time`).
12. ostra: cd -5 each rank (Nightwell `time` stays).
13. tender: generic step only (no source tiers); optional heal +15% by `level_k`.
Cooldowns above are source deltas; where our base is already shorter, scale the delta by ours/source.
