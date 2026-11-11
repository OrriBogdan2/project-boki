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
- `content/rules/xp.json` + `XpRules`: no trickle, no XP for damage. Hunter damage still builds `armor_xp`. A knock pays 40 + 15 x the victim's level. A monster kill pays its kind's XP (camp monsters: 30 small, 50 Sentinel, 100 Brute, 170 Chief) or 8 for a monster outside a camp. Lair bosses keep their own pay (`lairs.gd`). `XpRules.pay_squad` is the only code that knows the 30 m squad rule.
- `Camps` (`scripts/match/camps.gd`, `content/rules/camps.json`) takes over `Match._spawn_mobs` and the comeback that `Rolling` used to own. Each camp has an explicit state (LIVE, CLEARED, RETURNING, SPENT). On the last kill the killer's squad gets one bundle (armor, an orb, gear) and one toast. Camp monsters no longer roll their own drops (Brute orb, treasure, seeds, and also the gear table and stagger armor: the camp pays one bundle). The Rift Key chance stays.
- `Camps.safe_for` wraps the Blight's closing. This base has no ring yet, so today it asks whether the islands will still be up (`Match.length`). The zone redesign replaces only this function.
- `BotCamps` (`scripts/match/bot_camps.gd`, the `bots` block of `camps.json`): a bot squad leader with no human ping pings a camp (the hot zone first, else a rim or mid region no bot squad has; the Crown at most once a match). After landing the squad clears its region's camps smallest first until 2:30, leaving a camp when it is unsafe, the Blight is within 40 m, or a squad with a higher total level is at it; later a squad under level 5 detours to a camp that came back within 60 m. `--camp-pace-check` runs ten bot trios over five seeds and asserts the level pace.

## Consequences
- Net: each peer pays its own Hunters. The "mobdead" event now carries the host's XP for the kill, peers pay knock XP from the "knock" event, and a new "campclr" event carries the clear toast. Noted in the unreleased 0.24.4 entry of Net.VERSION (no number change; the alternative is 0.24.5).
- Rolling loses CAMP_RESPAWN, `camps`, `note_camp` and `_camp_respawns`. Its "picked over" start calls `Camps.picked_over`.
- New check `--camps-check`. `--rolling-check` drops its camp-respawn rows (the comeback is asserted in `--camps-check`).
- Left to the levels task: the new XP curve, the pace and gap bonuses, rarity multipliers, the XP bar, and the 300 last-hit boss pay.
