# Heart Raid: PvE mode (prototype, 2026-11-12)

Owner ask (11-11, 7 PM EST): a PvE mode next to Expeditions, solo or up to 4. It stays inside "every expedition
is a fight over the Heart": same map, Heart, Blight tide, monsters, bots, loot, Relics and Boki. The opposition is
waves and one boss, not other squads. Code: `scripts/match/heart_raid.gd`, numbers: `content/rules/heart_raid.json`,
check: `--heart-raid-check` (a sim per difficulty). Decision note: docs/decisions/0061-heart-raid-prototype.md.

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

## Waves follow the clarity rule (CORE SERIES PRINCIPLES 1, owner 11-11)
Scripted, timed and telegraphed; nothing random in where or when (`HeartRaidGates`, `heart_raid.json` "gates",
"waves", "warn_s"):
- **Fixed gates.** Six spawn points by bearing from the Heart (clockwise from north): three inner gates 11 m out
  (N, SE, SW; their monsters guard the Heart) and three outer gates 28 m out (NE, S, NW; their monsters come for
  the squad). An outer gate is pulled in to 4 m inside the tide ring the tide has at that wave's time (the tide
  runs on the fixed heart.json clock, so this is the same every raid).
- **Fixed timers.** Wave 1 at 1:15, then one every 75 s. Each wave names its groups and their gates (wave 1: two
  Skitters from N, one from NE; ...; wave 8: SE and S). A group's monsters stand 1.4 m apart round the gate.
- **Telegraph.** 10 s before a wave its gates are marked: an ember ring on the ground with a seconds countdown
  over it, a badge with a filling arc on the minimap, and the raid strip reads "Wave 4 out of the marks in 0:08".
  Clients work the marks out from the synced wave number (no new net traffic).
- Idle wave monsters still go for the nearest Hunter within 32 m (who to chase is not a spawn).

## Difficulty: Normal / Hard / Nightmare
Picked on the raid panel (three buttons over the squad tiles), in the lobby (press the raid mode again to step it),
or `--match --heart-raid=4:nightmare`. It multiplies the squad scale below (`heart_raid.json` "difficulty"):

| Difficulty | Monster HP | Damage (waves and boss) | Wave headcount and alive cap | Boss HP | Boss | Raid Boki that can turn up |
|---|---|---|---|---|---|---|
| Normal | x1.0 | x1.0 | x1.0 | x1.0 | Colossus kit | commons |
| Hard | x1.3 | x1.25 | x1.25 | x1.35 | Colossus kit | + rares |
| Nightmare | x1.7 | x1.5 | x1.5 | x1.8 | + **rockfall** as a regular attack (marked circles, 0.9-1.8 s) | + very rares |

The extra mechanic is the lair's `extra` attack (`Boss.attacks`): the Colossus's phase-change rockfall
(`Boss._rockfall`) also comes as an attack of its own, so a Nightmare squad has to keep moving between slams.

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

## The raid's Boki (CORE SERIES PRINCIPLES 2)
Where each Boki is found comes from `content/rules/boki_modes.json` (`BokiModes`, cherry-picked from
ext/series-boki-1112, docs/design/SERIES_BOKI_MODES.md). Heart Raid has 21 lines of its own: 10 commons (Normal),
7 rares (from Hard), 4 very rares (from Nightmare). `HeartRaid.boki(difficulty)` is the raid's pool; the raid's
wild spots, rare spots and its reward egg draw from it with the rarity tickets (6/3/1).

None of the raid's lines is in the game yet, so each draws as a **stand-in** game species of the same rarity
(`heart_raid.json` "stand_ins", a TODO: delete an entry when its line gets a model and a `kin` id):

| Raid line | Rarity, from | Stand-in |
|---|---|---|
| bellowlet, grainspin, lurklet | common, Normal | kindlewren, glintmole, gloamshell |
| kitlet, malletary | rare, Hard | threadwyrm, kilnbadger |
| sarcobra, siegephant | very rare, Nightmare | umbrathere, moundvark |

The stand-ins are Expedition Boki (boki_modes.json keeps every game species in Expeditions), so until the raid's
own models land the raid's Boki are not yet found *only* there. The prototype's `"only_in"` field and
`Data.wild_kin` are gone (one system: BokiModes); Umbrathere and Knotwyrm are back in the Expedition wild table.
Alternative not taken: move three game species from Expeditions to the raid in boki_modes.json (truly raid-only
now, but it takes Boki players find today out of Expeditions, against the series doc's rule).

## Rewards vs Expeditions
- **Raid win:** an egg of one of the raid's Boki open at the difficulty (rarer ones on Hard and Nightmare), 2 of each seed, 2 heartwood, 100 gems, 15 trust, plus what you carried.
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

## Balance sweep (2026-11-12, `--heart-raid-check`)
First numbers, 5 fixed seeds (1-5) per cell. The player's seat is autopiloted and plays the three starter Hunters in turn
(seed 1 Juggernaut, 2 Gunslinger, 3 Archer, 4 Juggernaut, 5 Gunslinger); the other seats are bots. One raid:
`godot --headless --path . -- --heart-raid-check --seed=N --sweep=SQUAD:difficulty:arch` prints an `HRSWEEP` line
(result, seconds, downs, wave, boss). "Downs" counts every time any Hunter of the squad went down (solo has no down
state: the first death is the loss, so 0). Time is the match clock (limit 900 s).

| Squad | Difficulty | Cleared | Time won / lost (s) | Downs avg (max) | Wave reached (avg of 8) | Boss reached |
|---|---|---|---|---|---|---|
| 1 | Normal | 0/5 (0%) | - / 545 | 0.0 (0) | 6.0 | 1/5 |
| 1 | Hard | 1/5 (20%) | 721 / 572 | 0.0 (0) | 7.0 | 2/5 |
| 1 | Nightmare | 0/5 (0%) | - / 512 | 0.0 (0) | 5.8 | 2/5 |
| 2 | Normal | 1/5 (20%) | 824 / 643 | 7.0 (16) | 7.8 | 2/5 |
| 2 | Hard | 0/5 (0%) | - / 787 | 18.0 (36) | 8.0 | 4/5 |
| 2 | Nightmare | 0/5 (0%) | - / 752 | 11.8 (37) | 7.6 | 3/5 |
| 4 | Normal | 1/5 (20%) | 781 / 838 | 37.4 (126) | 8.0 | 5/5 |
| 4 | Hard | 1/5 (20%) | 850 / 780 | 26.8 (47) | 7.8 | 4/5 |
| 4 | Nightmare | 0/5 (0%) | - / 758 | 58.4 (118) | 8.0 | 3/5 |

Reading it: only 5 of 45 raids were won (11%), and every difficulty is within noise of each other (5 seeds is 20% a step).
Solo Normal and solo Nightmare are 0% with 0 downs, the only cells the brief lets me change. I tried easing the solo row
(`scale.count[0]` 1.0 -> 0.75, `scale.hp[0]` 0.8 -> 0.7) and re-ran the 15 solo raids: Normal 0/5 (wave 5.6), Hard 1/5
(6.4), Nightmare 0/5 (6.8), no better than before, so **heart_raid.json is unchanged**. The loss is not the wave
numbers: the autopilot and bots stall below the Heart plateau (docs/DEBT.md, "bots do not climb onto the Heart plateau"), so
the squad rarely holds the ring, and a solo run also loses to one bad pull. The sweep measures the bots as much as the numbers.

Proposals (the owner's call):
1. Fix the bots/autopilot climbing to the Heart first, then re-run this sweep; tuning numbers before that tunes the bot.
2. Squad of 4 takes the most downs (Normal 37 avg): cap 17 live wave monsters at squad 4 may be high; try `cap[3]` 14.
3. Difficulty steps barely separate (Hard 2/5 won overall, Normal 2/5, Nightmare 0/5): the Hard step (hp 1.3, count 1.25) is
   mild; Nightmare's is the only one that shows (more downs at 4).
4. Solo: `boss_hp[0]` 0.2 is already small, yet 4 of 5 solo runs never see the boss: slow the waves for solo (`wave_every_s`
   by squad) rather than shrink them.
5. 10 more seeds per cell before any number moves.

## Risks
- **Player split:** a second queue thins the Expedition lobbies. Keep the raid offline/party-only (no matchmaking)
  until the player count supports both. Bots fill the seats anyway.
- **Matchmaking:** there is no raid queue. Online is the existing lobby ("Heart Raid" mode, the first 4 ready, the
  host fills the rest with bots). Clients see a lair boss as a plain monster: the bar over its head, no top bar.
- **Perf:** at most 4 Hunters + 8 Boki + 17 wave monsters + 1 boss, against 30 Hunters + 60 Boki in an Expedition.
  Real GPU (jobq 20261112-112407-28815, rp1-0, RTX 4090, `--perf-bench --quality=medium`): the bench plays a plain
  Expedition match, not a raid (`--perf-bench` ignores `--heart-raid`, job -10360 benched the hub): match wall avg 76.7 ms,
  p99 216 ms (one 4.7 s start hitch), against 74-75 / 86-99 ms on main in GATE_1112c2, so no regression is visible, but the
  raid's own load (17 wave monsters + boss) is **not** measured: a `--perf-bench` raid scene is open.
- **Balance:** the numbers are first guesses. The smoke runs print a line a minute to tune from.

## Next steps
1. Playtest solo and as 4. Tune the waves, scale and boss HP in heart_raid.json.
2. A Boki-model boss (Cairnback first). Then Zephyrak and Hivara, rolled per raid.
3. Blighted Boki in the waves: wild kin turned hostile, with a Blight tint.
4. Models for the raid's own Boki lines (then drop their stand-ins).
5. Decide the loss rule and the raid's place in the economy pass. Add a raid queue only if the player count allows.
