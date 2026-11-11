# Monster camps and boss wake times (predictable spawns)

Owner, 2026-11-11 (Hollow Crown 2.0): players should be able to plan routes. Camps are fixed and named, each with a
known monster set, tier, respawn timer and a reward that fits its region. Bosses rise on known spots at a known
time every match.

## Data (content/maps/hollowcrown.json, written by tools/make_hollowcrown.py `CAMPS` and `lairs`)
- `regions[].camps`: `[{id, name, at: [x, z], tier, set, respawn, reward}]`
  - `tier` 1 light, 2 normal, 3 heavy. It sets the monsters' rarity (`Camps.TIER_RARITY`: common, uncommon, rare)
    and the reward's rarity floor.
  - `set` is the monster kinds, exactly (no dice).
  - `respawn` is the seconds after the clear before the camp comes back. The timer is fixed: it comes back on time
    even with someone standing in it.
  - `reward` drops once on the clear, at the camp: `armor`, `glove`, `boots`, `relic` (gear for that slot,
    rarity at least tier - 1), `treasure` (a valuable) or `seed` (one per tier).
- `lairs[].wake`: the match second the lair's boss rises. Until then the lair is shut and the map counts down.
  The Forge wakes at 1:30, the Eyrie at 2:00 (when the Sealed Lair way out opens), the Hive at 3:00.

To re-place camps for a new layout, edit `CAMPS` (design grid) and run `python3 tools/make_hollowcrown.py`. A
camp needs open ground at `at`; the generator's checks flag anything off the ground. A region that leans one gear
slot (`loot.slots`) pays that slot from its camps (`--camps-check` holds this).

| Region | Camps (tier, back in) | Reward |
|---|---|---|
| The Crown | Throne Guard (3, 3:30), Gloom Barracks (3, 3:30), Crownfall Pit (3, 4:00) | treasure |
| Frostgate | Rimefield Pack (1, 1:30), Keep Sentries (2, 2:30), Span Breakers (3, 3:30) | armor |
| Cinder Steps | Slag Yard (1, 1:15), Kiln Rats (2, 2:00), Forge Breakers (3, 3:00) | gloves |
| Stormbreak | Shrine Strays (1, 1:45), Halt Raiders (2, 2:30), Thunder Ledge (3, 3:30) | boots |
| Thornwood | Bramble Lurkers (1, 1:30), Hive Wardens (3, 3:00) | seeds |
| Larkhollow | Meadow Grazers (1, 1:30) | seeds |
| Highwatch | Lookout Snipers (2, 2:30) | boots |
| Duskmoor | Chapel Ghouls (1, 1:45), Moor Crypt (2, 2:45) | relics |
| Saltmere | Riverbed Scavengers (2, 2:15) | treasure |

## Code
- `scripts/match/camps.gd` (`Camps`, `Match.camps`): builds the list from `World.camp_spots`, fills camps (host),
  checks for clears and refills on a 0.25 s pass (not every frame), drops rewards, and handles scouting.
  Maps without named camps (Skyreach, generated maps) keep the rolled sets. Those camps only come back in a
  rolling session (`ROLL_RESPAWN`, 4 min). This replaces the old `Match._spawn_mobs` composition code and
  Rolling's camp respawn.
- Scouting: once your squad gets eyes on a camp (`SpawnPlan.team_sees`, the same rule caches use), its icon
  shows. Each peer scouts only for its own squad.
- `scripts/ui/camp_map.gd` (`CampMap`): on the full map, every camp spot is a faint dot (the map is fixed). A
  scouted camp shows its reward icon and one pip per tier. Once cleared it greys out over a countdown. The
  minimap shows scouted camps while a countdown runs, or while the map key or Tab is held (`MapDetail` kind
  `camp`). Lairs waiting to wake show "WAKES m:ss".
- `Lairs.activate` defers `_raise` until `wake_left` is 0. The waiting lair keeps everyone out with its own line.
- Net: the host sends `["camp", index, cleared_at]` on a clear (Net 0.24.6). Every peer counts the same timer,
  and the refilled monsters arrive through the normal monster snapshot. A peer that joins mid-match misses
  earlier clears; its icons fix themselves on the next clear.
- Far monsters keep their 20 Hz step (`Mob._far_step`); camps add no per-monster work.

Check: `--camps-check`.
