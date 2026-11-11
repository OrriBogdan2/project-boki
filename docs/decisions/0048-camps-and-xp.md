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

## Consequences
- Net: each peer pays its own Hunters. The "mobdead" event now carries the host's XP for the kill, peers pay knock XP from the "knock" event, and a new "campclr" event carries the clear toast. Noted in the unreleased 0.24.4 entry of Net.VERSION (no number change; the alternative is 0.24.5).
- Rolling loses CAMP_RESPAWN, `camps`, `note_camp` and `_camp_respawns`. Its "picked over" start calls `Camps.picked_over`.
- New check `--camps-check`. `--rolling-check` drops its camp-respawn rows (the comeback is asserted in `--camps-check`).
- Left to the levels task: the new XP curve, the pace and gap bonuses, rarity multipliers, the XP bar, and the 300 last-hit boss pay.
- XP readout: every payment goes through `XpRules` (`pay_squad`, `pay_one`), which tallies per Hunter (meta `xp_tally`) by source (camp, mob, boss incl. the Watcher, knock), camps cleared, and steals made/suffered (the last hit's squad did less of a camp's XP or a boss's damage than another squad). The results screen shows one line per squadmate ("Level 8: 6 camps, 4 knocks, 1 boss"); `XPLOG` lines with the same counts and levels go to stdout at 2:00, 4:00, 5:15, 8:00, 10:00 and at the end. Each game tallies only the Hunters it owns. Rolling's bounty XP and tutorial/demo grants are not counted. No Net change.
- Bots (ext/early-camps-bots): `BotCamps` (`scripts/match/bot_camps.gd`, numbers in `camps.json` "bots") picks a bot squad's drop as a camp in gliding reach of the ship (the hot zone at `HotZone.BOT_PICK` if nobody has pinged it, else a rim or mid region with at most one other squad and no other bot squad; the Crown once, last), then clears that region smallest first until 2:00 while the squad keeps within 25 m, and after that detours to a camp within 60 m while at or under `XpRules.pace_level` (the pace table in `xp.json`). Bots avoid a squad 2 levels up unless it is fighting, press one 2 down, try the last hit on a prize monster (`xp.json` "steal") in its kill window, and hold fire at 30% when a rival is near. It replaces the old hot-zone landing (`HotZone.landing`, `CROWD_R`) and the bot vault pick. `--camp-pace-check` runs seeded 10-trio matches to 12:00 against the pace band.
