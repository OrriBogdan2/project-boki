# Heart Raid: PvE mode (prototype, 2026-11-12)

Owner ask (11-11, 7 PM EST): a PvE mode next to Expeditions, solo or up to 4. It stays inside "every expedition
is a fight over the Heart": same map, Heart, Blight tide, monsters, bots, loot, Relics and Boki. The opposition is
waves and one boss, not other squads. Code: `scripts/match/heart_raid.gd`, numbers: `content/rules/heart_raid.json`,
check: `--heart-raid-check`. Decision note: docs/decisions/0061-heart-raid-prototype.md.

## Loop
Drop as one squad (1-4 Hunters; offline a squad of 4 has bots in the empty seats). Loot and level on the camps while
the tide closes on the Heart (heart.json timings, unchanged). Waves come for the Heart and for you. Then the boss
rises at the Heart. Bring it down and the Heart's final seat opens: hold the ring (20 s alone, faster together) to
leave with the reward. **Lose:** the squad is wiped (the tide counts) or the islands fall at 15:00.

## Pacing (target 12-15 min)
| Time | Beat |
|---|---|
| 0:00-1:00 | drop, first camps, gear |
| 1:15 | wave 1 (3 small monsters). Then a wave every 75 s, 8 in all, harder each time (spitters, bombers, Blight Skitters, brutes, a Blight Watcher last) |
| 1:30-10:00 | the tide closes 184 m to 48 m round the Heart (same as Expeditions) |
| 11:00 (or 20 s after wave 8 is cleared) | the boss rises at the Heart |
| ~12:00-13:30 | boss down, hold the Heart ring: **win** |
| 15:00 | the islands fall: **lose** |

Each wave splits into **heart** monsters (out of the ground 9-15 m from the Heart, guarding it) and **edge**
monsters (from the Blight's side, 14-20 m past the squad on the line from the Heart, but always inside the
tide ring). Idle wave monsters go for the
nearest Hunter within 32 m.

## Bosses (pick existing Boki: the lair-boss species)
1. **Blighted Cairnback** (prototype): the Stone Colossus kit. Slams with shockwave rings to jump, thrown boulders,
   fissures, rockfall each phase. Slow and readable, a good first boss.
2. **Blighted Zephyrak**: the Stormcoil kit. It circles and lunges on telegraphed lines and calls lightning on
   marked circles. It punishes a squad that bunches up on the Heart.
3. **Blighted Hivara**: the Brood Mother kit. Acid fans and puddles, egg sacs that hatch adds, burrows under you.
   An add-pressure finale for squads of 3-4.

The prototype uses the Colossus model. Next step: a Blight-tinted, scaled-up model of the Boki itself.

## Scaling by squad size (every Hunter counts, bots too)
| Squad | Wave headcount | Monster HP | Boss HP (x 4000 x tier) | Wave monsters alive cap |
|---|---|---|---|---|
| 1 | x1.0 | x0.8 | x0.2 (800) | 8 |
| 2 | x1.4 | x1.0 | x0.45 (1800) | 11 |
| 3 | x1.8 | x1.15 | x0.7 (2800) | 14 |
| 4 | x2.2 | x1.3 | x1.0 (4000) | 17 |

## Mode-exclusive Boki
"Found only in that mode", not locked to it: `content/kin/<id>.json` `"only_in": "heart_raid"` takes a species out of
every other mode's wild spawn table (`Data.wild_kin(mode)`: wild spots and rare-kin spots). Hatched, traded or
bought, it goes anywhere. Placeholders: **Umbrathere** and **Knotwyrm** (`threadwyrm`). The raid's reward egg is one
of them.

## Rewards vs Expeditions
- **Raid win:** an egg of a raid-only Boki, 2 of each seed, 2 heartwood, 100 gems, 15 trust, plus what you carried.
- **Expedition:** the Heart's major seat pays 150 gems, a Rare (boss) egg and starstone. The PvP risk earns more,
  so Expeditions stay the best source of rare eggs and gems.
- **Raid loss:** as an Expedition loss. What you carried stays out, and there is no placement pay with one squad.
  Next: a softer loss (keep the XP and some gems) if playtests find it too punishing for solo.

## Reused vs new
- **Reused:** the map, drop, camps, chests, Blight and tide, the Heart's final seat and pay, the Lair boss kit, bots
  and the squad ping, Relics and Boki, the results screen.
- **New:** the wave director and its rules file, the boss in the open (a lair-shaped square round the Heart), the
  per-mode spawn table, the HUD strip (in place of the Ways Out strip), the results line, the Expedition panel button
  and a lobby mode.
- **Off in a raid:** rival squads, lairs, outposts and the Heart's early seat (`Heart.locked`).

## Risks
- **Player split:** a second queue thins the Expedition lobbies. Keep the raid offline/party-only (no matchmaking)
  until the player count supports both. Bots fill the seats anyway.
- **Matchmaking:** there is no raid queue. Online is the existing lobby ("Heart Raid" mode, the first 4 ready, the
  host fills the rest with bots). Clients see a lair boss as a plain monster: the bar over its head, no top bar.
- **Perf:** at most 4 Hunters + 8 Boki + 17 wave monsters + 1 boss, against 30 Hunters + 60 Boki in an Expedition.
  Not yet measured on a real GPU (--perf-bench).
- **Balance:** the numbers are first guesses. The smoke runs print a line a minute to tune from.

## Next steps
1. Playtest solo and as 4. Tune the waves, scale and boss HP in heart_raid.json.
2. A Boki-model boss (Cairnback first). Then Zephyrak and Hivara, rolled per raid.
3. Blighted Boki in the waves: wild kin turned hostile, with a Blight tint.
4. Wave telegraphs: an edge marker and sound a few seconds before a wave lands.
5. Decide the loss rule and the raid's place in the economy pass. Add a raid queue only if the player count allows.
