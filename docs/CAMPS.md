# Camps: fixed places, fixed monsters, XP

Owner 11-11 core principle: no random enemy spawns. A camp is at a place a player can learn and holds what the
player learned. Code: `scripts/match/camps.gd` (`Camps`, owned by `Match.camps`), numbers in
`content/rules/camps.json`, check `--camps-check`.

## What a camp is
- One camp per camp spot of the map (`World.camp_spots`). Its layout kind is its size: light = Small Camp,
  normal = Camp, heavy = Great Camp (data: `sizes`).
- Its monsters come from the region's table (`BiomeRun.camp_comp`) or, off a biome map, the size's own mix.
  The dice is seeded by the spot alone (`Camps.dice_at`), never `Match.rng` or the match seed: the same
  camp has the same monsters, rarities, mutations and offsets in every match.
- XP is the kill reward already on main (`KillXp`: the last hit's squad and squadmates within 30 m). A camp's
  XP (`cp["xp"]`) is the sum of its monsters' kill XP; nothing is paid on the clear itself.
- A cleared camp returns once, `back_s` (240 s) after the clear, with no Hunter within `back_clear_r` (22 m).
  Rolling sessions drive it (`Rolling` calls `Camps.comeback`) and start picked over (`Camps.picked_over`).
- Host only. Clients see the monsters through snapshots; no wire change, no `Net.VERSION` bump.

## Bots
`BotCamps.goal` sends a bot with nothing urgent to the nearest standing camp it is strong enough for
(`sizes.lvl`: Small 1, Camp 2, Great 4), in place of a random monster. `bot_camp_share` of its roam picks go
to a camp, the rest still explore.

## Steal window
Prize monsters (`content/rules/steal_window.json` `prize`: Brute, Glimmer, Warden, the lair bosses) cry once at
the quarter-health line `StealTell` already marks and stand open for `reel` (1.2 s: no attacks, normal damage)
on the first drop under it (`StealReel`, `Mob.reel`): the fighting squad's planned burst. The cry and the reel
read off the health every machine sees, so nothing is synced.

## Not here yet
Camp markers on the drop map and minimap, region lines, smoke, camp idle sounds, steal stings, Boon cues, a
guarded rare Boki and the summon-cooldown refund (needs P05). Online clients have no camp list.
