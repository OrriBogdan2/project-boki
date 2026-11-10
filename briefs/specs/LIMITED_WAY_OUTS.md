# Limited Way Outs: THE extraction mode (spec + prototype plan)

Job 20261110-062145-a4 (deep, design only, no game code). Implements DECISIONS 2026-11-10 "LIMITED WAY OUTS, one mode".
One mode, no toggle, no open extraction. Trios, 10 squads, 30 Hunters (DECISIONS 11-08).

## 1. The rule in four lines
1. Nobody leaves for free. A match has **four seats out**, each takes **one squad**, each is used **once**.
2. Two are quest exits (race, first squad to finish leaves): the **Sealed Lair** (2:00) and the **Uplink** (6:00).
3. Two belong to the Heart: an **early seat** (unlocks 4:00, any time after, MINOR reward) and the **final seat** (10:00, MAJOR reward).
4. Everyone else dies to rivals or the Blight. The final seat is the last-team-standing win: there is no fifth way.

So at most 4 of 10 squads (12 of 30 Hunters) get out. Expected about 3 (see Risks; to be measured).

## 2. What this replaces
| 11-08 rule (DECISIONS) | Now |
|---|---|
| Normal extraction stays open | Gone. Skiff docks, Rift hatches and Rift Keys are deleted (section 9, task 4) |
| Heart Night variant (only the spark squad leaves) | Gone as a variant; its idea is the base mode, plus two quest seats |
| Heart cools 90 s and charges a new Heartspark, several per match | One Heartspark per match (the early seat). No cooldown loop |
| Blight closes on the Heart; visible charge; carrier revealed and slowed 15%; Heart Gate; big pay | Kept as built on ext/heartspark-rebased |

The friend's "boss that unlocks at a set time and opens an exit" is the Sealed Lair (the lair code already seals one squad in with a boss). The Heart takes the "timed exit" slot with the owner's early-minor / late-major payout. No new boss is built for the Heart: a boss at the centre with 5 to 8 squads on it is a perf and third-party mess, and the lair already does the job.

## 3. One match, minute by minute (12:00, was 10:12)
Blight ring radius `r(t) = 130 - 0.188 * (t - 90)` m, held at 34 m from 10:00 (Hollow Crown at 216; times 1.41 on the 2x map).

| Time | Ring | Event | Squads alive (guess) |
|---|---|---|---|
| 0:00 | none | Drop. Map already shows all four seats with their open times | 10 |
| 1:30 | 130 m | Blight starts closing | 10 |
| 2:00 | 124 m | **Sealed Lair opens** (1 of the 3 lairs, by seed). Map-wide call | 9-10 |
| 4:00 | 102 m | **Heart unlocks.** Heartspark charges 75 s in plain sight | 8 |
| 5:15 | 88 m | Heartspark ready: take it, run 24 m to the Heart Gate, hold 4 s: squad out, MINOR | 7 |
| 5:30 | 85 m | Sealed Lair shuts (a fight already sealed in may finish, 90 s at most) | 6-7 |
| 6:00 | 79 m | **Uplink powers on** (1 of 2 outposts, the one farther from the Sealed Lair) | 6 |
| 8:00 | 57 m | Uplink shuts. Only Heart seats remain | 4-5 |
| 10:00 | 34 m | **The Heart opens: final seat.** Hold the Heart ring to leave, MAJOR | 2-4 |
| 12:00 | 34 m | The islands fall. Anyone left is gone | 0 |

- Taking the final seat ends the match: the islands fall 15 s later.
- **Last squad standing, at any time:** the final seat opens for them at once at double speed (the existing `Exits.on_last_team` rush). They get MAJOR.
- The early seat never expires. If nobody used it by 10:00, the runner-up of the last fight can still grab the spark and leave with MINOR while the others duel for MAJOR.

## 4. The four seats
| Seat | Opens to shuts | How you win it | Who can stop you | Reward on top of what you carry |
|---|---|---|---|---|
| Sealed Lair | 2:00 to 5:30 | Crack the gate locks, step in (gate seals behind you), kill the boss, ride the updraft out (existing: only those who fought can ride it) | Only before the gate seals; then the boss | The lair's own drops (Rare Egg, weapon, glove) |
| Heart, early | 4:00 on (ready 5:15) | Take the Heartspark (hold 1.5 s), carry it revealed and 15% slower to the Heart Gate, hold 4 s | Anyone: kill the carrier, take the spark | **MINOR** |
| Uplink | 6:00 to 8:00 | Hold the outpost yard: 40 s alone, 27 s with two, 22 s with three; rivals in the yard stall it, 5 s alone steals it. Lift opens 15 s for the squad that finished it only | Anyone who steps in the yard | Nothing extra |
| Heart, final | 10:00 to 12:00 | Hold the Heart ring (6 m): 20 s alone, 11 s with three; stalls while a standing rival is in it, drains when empty | Anyone alive | **MAJOR** |

Rules shared by all four:
- A seat fires once and takes the squad members inside it at that moment (downed ones too). A living squadmate who was not there is still in the match.
- The seat reward goes to every member of the squad, dead ones included (existing "your Boki went home with ..." path). Carried loot comes home only with the Hunters who physically left.
- A hit from a rival resets the Heart Gate hold (existing `extract_time` rule).

Rewards per Hunter (`content/rules/heart.json` "reward" splits in two):
| | MINOR (early) | MAJOR (final) |
|---|---|---|
| Rare egg | none | 1 |
| Evolution foods (4 kinds) | 1 each | 3 each |
| Heartwood / starstone | 1 heartwood | 2 + 2 |
| Gems | 40 | 150 |
| Boki trust | +6 | +20 |
Guide: MAJOR is worth about 5x MINOR. With about 6 squads left when the spark is ready, a top squad wins the final 1 time in 4: by rough sums, leaving now with 100 gems of loot is worth about 160 and staying about 160 too. That is the intended coin flip; rich squads leave, strong poor squads stay. Tune the ratio, not the structure.

## 5. Heart seats vs quest seats
| | Heart (preferred shape) | Quest seats |
|---|---|---|
| Where | Fixed centre, where the Blight closes | Mid ring, seeded per match, so routes differ each match |
| Skill tested | PvP: fight for the spark, escort, last fight | Lair: PvE and lock skill. Uplink: holding ground |
| Read by others | Total: beam, carrier on every map | Partial: open call, then a boss roar or a yard banner |
| Choice it creates | Leave small now or stay for big | Leave with what you have, and hand the final to someone else |
| Cost to build | Mostly built (ext/heartspark-rebased) | Reuses `lairs.gd` and the outpost half of `exits.gd` |
| Main risk | Whole lobby on one island at 4:00 to 5:15 (perf, third parties) | A seat nobody finishes (lair too hard, uplink always contested) |

Verdict: the Heart is the spine and gives the match its two peaks (5:15 and 10:00). The quest seats are the pressure valves that pull 2 squads away from the centre and reward the squads that do not want the big fight. Keep both; without quest seats only 2 of 10 squads could ever leave, which is too thin for the garden economy.

## 6. Squads that never get out (about 7 in 10 at equal skill)
- **Carried loot** (gems, seeds, goods, scans, belt, backpack): lost, into the deathbox as today (`Life`, `Equal.settle_belt`, `Backpacks.settle`). Rivals carry it out, so the squads that leave bring home 2 to 3 squads' worth: income moves to the winners instead of vanishing.
- **Your own Boki always come home, at every tier.** Being forced to stay by limited seats never costs a Boki (11-09: a linked soul always finds its way home).
- **Placement pay:** 5 gems per squad wiped before yours (0 to 40), plus the progress counters `Game.apply_result` already keeps. A second-place squad goes home with 40 gems, not nothing.
- **Pet-loss tier (The Hollow, tier 2):** a Boki is held for ransom only if a rival took it AND that rival left through a seat. Taken by a squad that also dies, or left guarding with nobody taking it: it comes home free (today that is "ransom"). Rough odds per Hollow match: 0.7 wiped x 0.5 taken x 0.4 thief gets out = about 1 in 7. Under the old rule (every unrecovered death is a ransom) limited seats would mean a ransom in 2 of 3 Hollow matches, which nobody would queue for.
- Tiers 0 and 1: unchanged, nothing of yours is ever held. With wisps on (0041), the thief who leaves keeps the soul echo and the bonus at every tier.
- Alternative not taken: no ransom at all (pure 11-09). Then The Hollow is only a loot multiplier and "pet-loss tier" means nothing.

## 7. Bots
Today bots head for any exit when `time_left < 170` or gems > 40 (`bot.gd` 798) and ignore the Heart (0023 known gap). New, per squad, by seed:
| Plan | Share | Does |
|---|---|---|
| Raider | 30% | Goes for the Sealed Lair at 2:30 (existing bold-bot lair goal), rides the updraft out |
| Runner | 30% | At the Heart by 5:15; takes the spark if no rival within 15 m; carries it to the gate and leaves |
| Holder | 20% | Uplink at 6:30, holds the yard |
| Stayer | 20% | Loots, then the final |
- When a squad's seat is taken or shut it falls through to the next open one, then the final. Every bot stays inside the ring (new: none avoid it today).
- Fairness: bots start a seat 30 s after it opens, and bot squads take at most `min(2, bot_squads / 3)` of the three early seats per match. Without the cap a lone human squad among 9 bot squads would see all three early seats gone in about 7 matches of 10 (0.9^3).
- Bots fight the final for real. A human must beat them to win it.
- Target: a median human squad in a 9-bot lobby gets out about half the time; in a full human lobby the natural 30%.

## 8. Map placement (1 tile = 1 m; Hollow Crown 216, Heart at 108,108)
- **Heart site is authored per map**, not seeded: new `"heart": [x, y]` (Hollow Crown: the Throne on The Crown). Every band below is measured from it. Today `Heart.setup` picks one of the three biggest islands.
- **Heart Gate:** 24 m from the Heart (inside the 34 m final ring), angle by seed.
- **Sealed Lair:** the three lairs sit at 64 to 67 m (Eyrie 157,66; Forge 60,150; Thornhive 127,172). The ring reaches them at 7:05 to 7:21, so the 5:30 shut is safe. No move needed.
- **Uplink:** needs two outposts at 42 to 50 m on opposite sides, at least 60 m from the Heart Gate. Today's three are at 72, 113 and 116 m (the corner two are drowned by 3:00): move two, drop the third.
- **Rule the map check enforces:** a seat's site stays inside the ring for 150 s after it opens and lies outside the final ring.
- Docks (15,30 / 201,184) and the five hatches go.
- 2x map (0022): radii and bands times 1.41 (ring 184 to 48 m, lairs about 91 m, uplinks 59 to 71 m). Times do not change.

## 9. UI
- **Ways Out strip** (top centre; replaces the `Exits.clock_line` text under the minimap): four pips, Lair / Heart / Uplink / Final. Each shows locked with countdown, open, in use (squad colour), taken (struck through), or lost to the Blight. Beside it: "Squads left: N".
- **Map and minimap:** the four sites from 0:00, a countdown ring on each, the dashed next Blight ring (ext/blight-edge-read).
- **Calls** (banner, feed, sound): seat opens; seat started and by whom; seat taken ("Amber squad left by the Sealed Lair. 3 ways out left."); 30 s before a seat shuts.
- **Heart Gate prompt** for the carrier: "Leave now: small reward" with the list, hold 4 s. One line under it: "Stay and the Heart opens at 10:00."
- **Dead and watching:** "Ways out left: N" and which one your squad is nearest.
- **Results:** how you left or your placing, placement pay, seat reward, and at The Hollow one line per Boki ("came home" / "held by <name>").
- First-time hints reuse `FirstTimeHint` group "heart" (ext/tut-first-heartspark). The tutorial keeps its uplink step.

## 10. Where it plugs in (real files)
On main: `scripts/match/exits.gd` (1025 lines: docks, hatches, outposts, waves, bot goals, HUD lines), `exit_models.gd`, `lairs.gd` (locks, seal, `VICTORY_T` updraft, `bot_goal`), `match.gd` (`_extract` 5315, `_check_last` 2519, `_update_rules` 5342, `_watch_death`, `_finish`, `length` 687), `bot.gd` 743-805, `scripts/core/game.gd` `apply_result` 127, `data.gd` `MATCH` and `TIERS` text, `scripts/kin/kin_loss.gd` (`fates`, `after_match`), `scripts/core/ransom.gd`, `scripts/ui/hud.gd`, `full_map.gd`, `content/maps/*.json`, `tools/make_hollowcrown.py`, `make_skyreach.py`.
Not on main yet, build on top: ext/blight-edge-read 08afe2d7b (contains ext/blight-damage-source and ext/heartspark-rebased: `scripts/match/heart.gd`, `scripts/ui/heart_hud.gd`, `content/rules/heart.json`, `tools/heart_check.gd`, `blight_wall.gd`, decision 0023), ext/trios-10x3-1108 and ext/no-rolling-rebased (both inside ext/stuck-integ-d4379965), ext/sfx-heartspark, wisp steal 0041.

## 11. Build tasks (in order; each one job, each with its check)
1. **Decision note + numbers.** `docs/decisions/NNNN-limited-ways-out.md`; all times, windows, rewards, placement pay and bot knobs in `content/rules/heart.json` (no second rules file). `Data.MATCH.length` 720 and drop the 1.7 big factor; `tide_start_s` 90, `tide_close_s` 510.
2. **Heart seats (first playable).** `heart.gd` as one state enum: ASLEEP, CHARGING, READY, CARRIED, WAITING, FINAL, DONE. Remove the cooldown loop; gate takes the squad in 8 m; final ring hold reusing `UPLINK_CREW`; MINOR/MAJOR pay; last-squad rush; final taken sets `length = time + 15`. Extend `--heart-check`. Net bump ("ht" shape).
3. **Delete open extraction.** Docks, skiff, hatches, Rift Keys: `exits.gd` (about 400 lines out), `exit_models.gd`, the three `drop_key` callers (`lairs.gd` 691, `chest_loot.gd` 66, `match.gd` 2649), `world.gd` 2482, map JSON and both map generators, bot goals, `--exit-demo` modes, `MATCH.portal_open`, wiki and docs text. After tasks 2 and 3 the mode is playable with Heart seats only.
4. **Quest seats.** `Exits` owns the schedule and the four seat states. Sealed Lair: seeded pick, updraft leaves the match, shut at 5:30 (`lairs.gd`). Uplink: seeded pick, powers on at 6:00, one use, lift for the finishing squad only, shut at 8:00. Extend `--extract-check` and `--lair-lock-check`.
5. **Results and Boki.** Result fields `how` (lair, heart_early, uplink, heart_final) and `place`; placement pay in `Game.apply_result`; `KinLoss` fate "nobody took it, or its taker is out" becomes home; `TIERS` text. No save-format change expected; if one appears it ships with a migration. Extend `--kin-loss-check`.
6. **Map.** `"heart"` site, two outposts in the band, the band check in the map generators, same on Skyreach and the 2x map.
7. **Bots + sim.** Plans, ring avoidance, spark carry, final; the cap and delay. New `--ways-out-sim` (headless, 10x3 bots, N seeds) printing seats used, time of each, squads alive per minute. `--bot-sanity-check`.
8. **UI + sound.** `scripts/ui/ways_out_hud.gd` (strip, calls, gate prompt), `full_map.gd` icons, results lines; cues via `heart_sfx.gd`. GPU screenshots through jobq.
9. **Measure, then tune.** 200 sim matches plus one human playtest against the gates below; `--perf-bench` with 24 Hunters on The Crown.

## 12. Risks, with numbers
| # | Risk | Number | Answer |
|---|---|---|---|
| 1 | Most matches end with no carried loot | Cap 40% of squads out; expected 30% (my estimates: Lair used 75%, early Heart 80%, Uplink 70%, final 95% = 3.2 seats). Today's open-exit rate is unmeasured (guess 45 to 60%) | Loot concentrates in leavers, placement pay, seat bundles. Gate: mean take-home per Hunter per match at least 85% of today's, from the sim |
| 2 | Longer match | 720 s vs 612 s (+18%) | Half the lobby is out by about 6:00 and can requeue |
| 3 | Whole lobby on one island | Up to 8 squads (24 Hunters) plus Blight at 4:00 to 5:15; perf pass capped a match at 30 | Perf bench before merge; the Lair (2:00) and Uplink (6:00) pull squads off the centre on both sides of the peak |
| 4 | Final with no winner | A beaten squad can stand in the ring and stall to 12:00 | Downed Hunters do not stall; ring is 6 m in the open. Gate: no-winner finals at most 5% |
| 5 | Bots eat the seats | 9 bot squads, equal pace: 73% chance a human sees no early seat | 30 s delay and the cap in section 7 |
| 6 | The Hollow becomes too safe or too cruel | Ransom about 1 match in 7 (old rule would be 2 in 3) | Tune by who counts as "taken"; do not bring back ransom on plain death |
| 7 | A seat goes unused every match | Lair or Uplink under 50% in the sim | Lair: one lock fewer on the sealed one. Uplink: 30 s base. If the Lair still fails, swap it for a carried-key quest (not built now) |
| 8 | Early leavers get a thin match | A squad out by the Lair at 3:30 played 3.5 min | Self-balancing: they leave with little |
| 9 | Net and saves | "ht" and exit events change shape | `Net.VERSION` bump in tasks 2 and 4; no save change planned |

Sim gates for task 9: seats used 2.6 to 3.4 per match; final taken at least 90%; squads alive at 10:00 between 2 and 4; first seat used between 3:30 and 5:30.
