# 0048: Camps own the early game; XP is a kill reward

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** match flow / combat

## Problem
Levels came from standing still (1.2 XP/s) and from stray damage (0.35 per damage to monsters, 0.6 to Hunters), and a camp paid nothing on its own. The early game felt random (spec `EARLY_CAMPS_DROP.md` sections 1, 2 and 6).

## Options
1. Pay the whole camp's XP once, on its last kill. Simple, but a rival who steals the last kill takes everything the other squad earned.
2. Pay each monster's XP on its kill, to the last hit's squad within 30 m. A camp's XP is the sum of its monsters. This is the owner's rule of 11-10 ~1:20 PM. Chosen.

## Decision
- `content/rules/xp.json` + `XpRules`: no trickle, no XP for damage. Hunter damage still builds `armor_xp`. A knock pays 32 + 12 x the victim's level, plus 30 per level the victim is above the knocker, half when the victim is 2 or more below (spec 6.5). A monster kill pays its kind's XP (camp monsters: 36 small, 60 Sentinel, 90 Brute, 150 Chief; the spec's 30 / 50 / 100 / 170 and knock 40 + 15 tuned within 20% by `--camp-pace-check`) or 8 for a monster outside a camp. Lair bosses keep their own pay (`lairs.gd`). `XpRules.pay_squad` is the only code that knows the 30 m squad rule.
- `Camps` (`scripts/match/camps.gd`, `content/rules/camps.json`) takes over `Match._spawn_mobs` and the comeback that `Rolling` used to own. Each camp has an explicit state (LIVE, CLEARED, RETURNING, SPENT). On the last kill the killer's squad gets one bundle (armor, an orb, gear) and one toast. Camp monsters no longer roll their own drops (Brute orb, treasure, seeds, and also the gear table and stagger armor: the camp pays one bundle). The Rift Key chance stays.
- `Camps.safe_for` wraps the Blight's closing. This base has no ring yet, so today it asks whether the islands will still be up (`Match.length`). The zone redesign replaces only this function.
- `BotCamps` (`scripts/match/bot_camps.gd`, the `bots` block of `camps.json`): a bot squad leader with no human ping pings a camp (the hot zone first at `HotZone.BOT_PICK`, else a rim or mid region no bot squad has; the Crown, the region round the Heart, at most once a match). After landing the squad clears its region together (within 25 m of its leader) smallest first until 2:30; with it cleared, a squad no more than 2 over the pace level (`XpRules.pace_level`, `pace_at_s` in `xp.json`) takes the nearest live camp within 200 m in a region no other bot squad holds; a leader that cannot walk to its camp in 10 s strikes it off and takes the region it stands in. A camp is left when it is unsafe, a Blight Warden is within 40 m, or a squad with a higher total level is at it. In the opening bots and their Boki start no fight with rival bots (only a rival going for them on purpose provokes them: stray hits from Boki thrown at monsters started most early brawls), and a squad leaves camp monsters whose kill would bring it within 60 XP of level 6 (spec 2.5: no ultimate before 2:30). Later a squad under level 5 detours to a camp that came back within 60 m, and a bot starts no fight with a squad 2+ levels above (spec 6.8). Alternative not taken: lower the hot-zone and Crown camps instead of the hold (they would still out-level everyone with the old curve's 650 for level 6). `--camp-pace-check` runs ten bot trios over five seeds and asserts the level pace.

## Consequences
- Net: each peer pays its own Hunters. The "mobdead" event now carries the host's XP for the kill, peers pay knock XP from the "knock" event, and a new "campclr" event carries the clear toast. Noted in the unreleased 0.24.4 entry of Net.VERSION (no number change; the alternative is 0.24.5).
- Rolling loses CAMP_RESPAWN, `camps`, `note_camp` and `_camp_respawns`. Its "picked over" start calls `Camps.picked_over`.
- New check `--camps-check`. `--rolling-check` drops its camp-respawn rows (the comeback is asserted in `--camps-check`).
- Left to the levels task: the new XP curve, the pace and gap bonuses, rarity multipliers, the XP bar, and the 300 last-hit boss pay.

## Camps on the maps (ext/early-camps-map-ui)
- The 28 camps are one `SpawnPlan` category, "camp": announced, no roll, one candidate per `Camps.list()` entry, live from 0:00. The marker is a campfire with 1, 2 or 3 flames (Small Camp, Camp, Great Camp) and a crown over the fire for a Camp Chief (`scripts/ui/camp_map.gd`); a Camp's size follows its camp, so a hot-zone camp and a returned camp show one size up.
- Cleared and returning states are per squad. A squad sees a camp as cleared (dim) or returning (dim, with a ring that fills until `back_t`) only if one of its hunters has been within 60 m (`SpawnPlan.NEAR_R`) since the clear; every other squad still sees it live. The note resets whenever the camp is live again.
- The drop map labels each region "N camps: to level L" (`CampMap.region_line`, from `Camps.region_xp`'s sizes and `Hunter.XP_TO`), the hot zone "HOT: bigger camps, better loot", and the legend has "Camps: clear them to level up". The minimap draws the same markers inside its range (`MapDetail.GROUND_R` = 34 m on the ground, the whole map while riding or dropping).
- `CampSmoke` (`scripts/match/camp_smoke.gd`) puts one unshaded billboard quad per camp in the sky (1/2/3 strands, orange in the hot zone; no particles, no lights), visible within 160 m during the local player's drop and freed 5 s after landing.
- First-match guide: "Pick a camp and ping it" while planning (a Small Camp in a middle region pulses on the drop map), "Clear the camp to level up" after landing (a waypoint to the nearest live camp) until the squad's first clear. These two lines run for the first three Extractions (`camp_matches` 3); the other lines keep their two (`matches` 2).
- Check: `--camp-map-check`. Not done here: net clients have no camp list (`Camps.spawn_all` returns early for non-hosts), so they see no camp markers or smoke (docs/DEBT.md).
