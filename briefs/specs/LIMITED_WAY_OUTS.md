# Limited Way Outs: THE extraction mode, driven by the Blight zone

Rev 2, job 20261110-171438-a4 (design lead, docs only). Rev 1 was job 20261110-062145-a4. Implements DECISIONS 2026-11-10 "LIMITED WAY OUTS, one mode" plus the owner order of 11-10: the Blight is a real battle-royale shrinking zone.
One mode, no toggle, no open extraction. Trios, 10 squads, 30 Hunters, on the 2x Hollow Crown (305 m). Build list: `briefs/specs/WAYS_OUT_ZONE_TASKS.jsonl`.

## Owner summary (10 lines)
1. The match is 12 minutes and has **five beats, one every two minutes: 2:00, 4:00, 6:00, 8:00, 10:00**.
2. On every beat two things happen together: **the Blight closes one circle** and **a way out changes**. One clock to learn.
3. 2:00 the Sealed Lair opens. 4:00 the Heart wakes (small-reward exit ready at 5:15). 6:00 the Uplink powers on. 8:00 the Uplink shuts. 10:00 the Heart opens for the big reward.
4. The next circle is always drawn on the map before it closes, and it **leans toward the next way out**, so each match moves a different way across the map.
5. Outside the wall the Blight hurts: a tickle at first (3.5 minutes to die), deadly at the end (3 seconds). It never outruns you; a Hunter runs 3 times faster than the wall.
6. Each way out is swallowed by the Blight right after it shuts. A seat you skipped is gone for good.
7. At 8:50 the zone is The Crown island. From 10:00 it closes to a 12 m circle round the Heart: the last fight is forced, nobody can hide.
8. Still four seats, one squad each: at most 4 of 10 squads leave. Last squad standing gets the big Heart exit at once.
9. Squads that never get out lose what they carried, keep every Boki of their own, and get placement gems. Dying to the Blight never costs a Boki.
10. Bots obey the zone, run for the Heartspark and fight the final. The hot zone is picked apart from the zone: reading both on the drop map is the drop decision.

**Owner calls (my default is built unless you say otherwise):**
1. *Zone leans toward the way outs* (default) or always centred on the Heart. Leaning gives different routes each match and keeps each seat alive until it shuts; centred is easier to read but every match plays the same.
2. *Final circle closes to 12 m round the Heart* (default) or stops at The Crown (48 m). 12 m forces a winner; 48 m lets a beaten squad hide and run the clock out.
3. *Hot zone is picked apart from the zone* (default) or always inside the first circle. Apart means some matches the rich land is on the dying side (loot fast, then run); inside means it is always the safe crowded pick.

## 1. The rule in five lines
1. Nobody leaves for free. A match has **four seats out**, each takes **one squad**, each is used **once**.
2. Two are quest exits (race, first squad to finish leaves): the **Sealed Lair** (2:00) and the **Uplink** (6:00).
3. Two belong to the Heart: an **early seat** (wakes 4:00, ready 5:15, MINOR reward) and the **final seat** (10:00, MAJOR reward).
4. **The Blight zone closes on the five beats** and takes each seat's ground soon after the seat shuts. No seat works outside the wall.
5. Everyone else dies to rivals or the Blight. The final seat is the last-team-standing win: there is no fifth way.

At most 4 of 10 squads (12 of 30 Hunters) get out. Expected about 3 (section 14).

## 2. What this replaces
| Before | Now |
|---|---|
| Normal extraction stays open (11-08) | Gone. Skiff docks, Rift hatches and Rift Keys are deleted (task 3, running) |
| Heart Night variant; several Heartsparks per match | One mode, one Heartspark (the early seat). Built on ext/ways-out-heart-seats |
| Rev 1 Blight: one ring centred on the Heart, closing smoothly 1:30 to 10:00, 11 damage stages | **Five stepped circles on the five beats**, each shown before it closes, leaning toward the next way out, 5 damage stages, then a final collapse to 12 m |
| Rev 1 Sealed Lair 2:00 to 5:30, sealed fight up to 90 s | 2:00 to **5:00**, sealed fight up to **70 s** (done by 6:10; the wall reaches the lair at 6:11) |
| Rev 1 "the early seat never expires" | It ends when the Blight takes the Heart Gate, 10:24 |

## 3. The Blight zone
All radii below are for the 2x Hollow Crown (305 m). Rules data holds them in 216-map metres (in brackets) and the game scales by `map size / 216` (1.41 here). **Times never scale.**

| Circle | Beat (starts closing) | Closes over | Then holds until | Radius | Centre | Fastest wall | Hurt outside, per second (medium Hunter, 145 hp) |
|---|---|---|---|---|---|---|---|
| start | | | 2:00 | 184 m (130): whole map | Heart | | none |
| 1 | 2:00 | 60 s | 4:00 | 136 m (96) | 40 m (28) from the Heart toward the Sealed Lair | 1.5 m/s | 0.7 hp, dead in 3.5 min |
| 2 | 4:00 | 45 s | 6:00 | 100 m (71) | 15 m (11) toward the Sealed Lair | 1.3 m/s | 5.6 hp, dead in 26 s |
| 3 | 6:00 | 40 s | 8:00 | 75 m (53) | 10 m (7) toward the Uplink | 1.25 m/s | 17 hp, dead in 9 s |
| 4 | 8:00 | 50 s | 10:00 | 48 m (34): The Crown | Heart | 0.75 m/s | 34 hp, dead in 4 s |
| 5 | 10:00 | 60 s | 12:00 | 12 m (8.5) | Heart | 0.6 m/s | 51 hp, dead in 3 s |

- **How the next circle is chosen.** Not random. Every circle contains the Heart and sits fully inside the one before. Circles 1 and 2 lean toward this match's Sealed Lair, circle 3 toward this match's Uplink, circles 4 and 5 sit on the Heart. The lair and the uplink are picked by the match seed, so the zone path differs per match (3 lairs x 2 uplinks) and can be read off the map from the first second. The zone is a pure function of (seed picks, clock): nothing new is synced.
- **How it is shown.** Circle 1 is on the drop map from 0:00. After that the next circle appears (dashed, on map and minimap) the moment the current close ends: 3:00, 4:45, 6:40, 8:50. The wall itself is the existing `BlightWall` at the current circle. While a circle closes, radius and centre move in a straight line from old to new.
- **Damage.** Stage k runs from beat k to beat k+1 and applies everywhere outside the wall. Same source curve as built (`tide_dmg` at source hp 1290), five points: 6, 50, 150, 300, 450, scaled to a medium Hunter: 0.7 / 5.6 / 17 / 34 / 51 hp per second, flat for every class (light 124 hp, heavy 193 hp), 1 s tick, armour ignored, as `_tide_tick` does today. A downed Hunter outside the wall takes it too.
- **Speed.** A Hunter runs 4.4 m/s; the wall never moves faster than 1.5 m/s. The wall is a deadline, not a chaser: what kills is being far out when the stage steps up.
- **What the wall takes, and when** (checked by script on the real 2x coordinates, every lair and uplink pick): far-side corner islands 2:15 to 2:45, the corner on the lean side about 4:10; inner-ring islands 4:10 to 6:20; the two lairs that are not sealed 4:10 to 6:00; the Sealed Lair arena 6:11 to 6:23; the Uplink yard edge 8:08 to 8:25 (its centre 8:19 or later, after the lift closes at 8:15); the Heart Gate 10:24.

Rules data (replaces the nine `tide_*` keys in `content/rules/heart.json`):
```json
"zone": {
  "map_ref": 216,
  "beat_s":  [120, 240, 360, 480, 600],
  "close_s": [60, 45, 40, 50, 60],
  "r":       [130, 96, 71, 53, 34, 8.5],
  "lean":    [0, 28, 11, 7, 0, 0],
  "lean_to": ["", "lair", "lair", "uplink", "", ""],
  "dmg":     [0, 6, 50, 150, 300, 450],
  "src_hp": 1290, "tick_s": 1, "boost": 0.55, "heat": 0.06
}
```
Nesting holds by the numbers: each step's centre move is no more than its radius drop (28 <= 34, 17 <= 25, 18 <= 18, 7 <= 19).

## 4. One match, minute by minute (2x map)
| Time | Blight | Way out | Squads alive (guess) |
|---|---|---|---|
| 0:00 | Whole map safe. Circle 1 already drawn | Drop. Map shows the four seats with their times, the hot zone and circle 1 | 10 |
| **2:00** | **Beat 1:** closes to circle 1 (136 m) by 3:00 | **Sealed Lair opens** (1 of 3, by seed) | 9-10 |
| 3:00 | Holds. Circle 2 drawn | | 9 |
| **4:00** | **Beat 2:** closes to circle 2 (100 m) by 4:45 | **Heart wakes.** Heartspark charges 75 s in plain sight | 8 |
| 5:00 | Holds. Circle 3 drawn since 4:45 | Sealed Lair shuts (a fight already sealed in may finish, 70 s at most) | 7 |
| 5:15 | | Heartspark ready: carry it to the Heart Gate, squad out, MINOR | 7 |
| **6:00** | **Beat 3:** closes to circle 3 (75 m) by 6:40. Takes the Sealed Lair | **Uplink powers on** (the outpost farther from the Sealed Lair) | 6 |
| **8:00** | **Beat 4:** closes to The Crown (48 m) by 8:50. Takes the Uplink | Uplink shuts (lift stays 15 s for a squad that just finished) | 4-5 |
| 8:50 | Holds on The Crown. Final circle drawn | Only Heart seats remain | 3-4 |
| **10:00** | **Beat 5:** closes to 12 m round the Heart by 11:00. Takes the Heart Gate at 10:24 | **The Heart opens: final seat**, MAJOR | 2-4 |
| 11:00 | Holds at 12 m | Everyone alive is within 12 m of the Heart | 1-3 |
| 12:00 | The islands fall | Anyone left is gone | 0 |

## 5. The four seats
| Seat | Opens to shuts | How you win it | Who can stop you | Reward on top of what you carry |
|---|---|---|---|---|
| Sealed Lair | 2:00 to 5:00 | Crack the gate locks, step in (gate seals behind you), kill the boss, ride the updraft out | Only before the gate seals; then the boss | The lair's own drops |
| Heart, early | ready 5:15, until the Blight takes the Gate (10:24) | Take the Heartspark (hold 1.5 s), carry it revealed and 15% slower to the Heart Gate (34 m from the Heart), hold 4 s | Anyone: kill the carrier, take the spark | **MINOR** |
| Uplink | 6:00 to 8:00 | Hold the outpost yard: 40 s alone, 27 s with two, 22 s with three; rivals in the yard stall it, 5 s alone steals it. Lift opens 15 s for the squad that finished it | Anyone who steps in the yard | Nothing extra |
| Heart, final | 10:00 to 12:00 | Hold the Heart ring (6 m): 20 s alone, 11 s with three; stalls while a standing rival is in it, drains when empty | Anyone alive | **MAJOR** |

Shared rules:
- A seat fires once and takes the squad members inside it at that moment (downed ones too). A living squadmate who was not there is still in the match.
- The seat reward goes to every member of the squad, dead ones included. Carried loot comes home only with the Hunters who physically left.
- A hit from a rival resets the Heart Gate hold. **A seat whose ground is outside the wall does not work.**
- Why each seat sits where it does on the zone clock: the lair is inside circles 1 and 2 with 20 m to spare and is taken one minute after it shuts; the uplink is inside circle 3 with 14 m to spare and is taken as it shuts; the Gate is inside The Crown and is taken 24 s into the final collapse, which ends the "leave small" choice exactly when the last fight starts.

Rewards per Hunter (`heart.json` "reward", unchanged from rev 1):
| | MINOR (early) | MAJOR (final) |
|---|---|---|
| Rare egg | none | 1 |
| Evolution foods (4 kinds) | 1 each | 3 each |
| Heartwood / starstone | 1 heartwood | 2 + 2 |
| Gems | 40 | 150 |
| Boki trust | +6 | +20 |

MAJOR is worth about 5x MINOR. With about 6 squads left at 5:15 a top squad wins the final 1 time in 4, so leaving with 100 gems of loot (worth about 160 with MINOR) equals staying. That is the intended coin flip. Tune the ratio, not the structure.

The Heart is the spine (two peaks, 5:15 and 10:00, at the centre where the zone ends). The quest seats are pressure valves: they pull 2 squads off the centre, test PvE and ground-holding instead of PvP, and the zone's lean walks the lobby past them.

## 6. The end: final circle, last squad standing, 12:00
- **Where the final circle lands:** always on the Heart. Circle 4 is The Crown island (48 m round the Throne), held 8:50 to 10:00: the staging ground, 3 or 4 squads on one island. Circle 5 is 12 m round the Heart; the final ring (6 m) is its middle. From 11:00 every living Hunter is within 12 m of the ring, and stepping out kills in 3 s. A beaten squad can no longer hide and stall.
- **Taking the final seat** ends the match: the islands fall 15 s later (existing `end_after_final_s`).
- **Last squad standing, at any time:** the final seat opens for them at once at double speed (existing `on_last_team`, `rush_k` 2: 10 s alone, 5.5 s three). They get MAJOR. The zone keeps its clock; the Heart is inside every circle, so they can always reach it.
- **12:00 with squads still alive and the seat not taken:** the Blight takes everyone. No winner, no MAJOR. They rank above every squad wiped earlier and tie with each other.

## 7. Squads that never get out (about 7 in 10 at equal skill)
- **Carried loot** (gems, seeds, goods, scans, belt, backpack): lost, into the deathbox as today. A box behind the wall stays lootable for anyone who pays the health. Rivals carry it out, so income moves to the leavers instead of vanishing.
- **Your own Boki always come home, at every tier.** Limited seats and the Blight never cost a Boki.
- **Placement pay:** 5 gems per squad wiped before yours (0 to 40), plus the progress counters `Game.apply_result` keeps. Second place goes home with 40 gems.
- **The Hollow (tier 2):** a Boki is held for ransom only if a rival took it AND that rival left through a seat. Taken by a squad that also dies, not taken, or killed by the Blight: it comes home free. About 1 Hollow match in 7.
- Tiers 0 and 1: nothing of yours is ever held. With wisps on (0041) the thief who leaves keeps the soul echo and the bonus.

## 8. Bots
Most lobbies are 1 human squad and 9 bot squads, and today no bot knows the Blight exists. Without zone sense every bot dies to the wall and the human wins by default, so this is in the 0.24.4 set.
- **Zone sense (every bot).** A bot outside the next circle sets off for a point 8 m inside it when `time until that circle finishes closing <= 1.5 x (distance / run speed) + 15 s`, and takes no new goal outside it from 30 s before the beat. A bot taking Blight hurt at stage 2 or later drops everything except fighting back and runs in.
- **Final (every bot squad still alive):** head for the Heart at 9:30, fight for the ring from 10:00 for real.
- **Plans, per squad, by seed:**

| Plan | Share | Does |
|---|---|---|
| Raider | 30% | Sealed Lair at 2:30 (existing bold-bot lair goal), rides the updraft out |
| Runner | 30% | At the Heart by 5:15; takes the spark if no rival within 15 m; carries it to the Gate |
| Holder | 20% | Uplink at 6:30, holds the yard (existing yard goal) |
| Stayer | 20% | Loots inside the zone, then the final |
- A squad whose seat is taken or shut falls through to the next open one, then the final.
- Fairness: bots start a seat 30 s after it opens, and bot squads take at most `min(2, bot_squads / 3)` of the three early seats per match.
- Target: a median human squad in a 9-bot lobby gets out about half the time; the Blight causes at most 10% of bot deaths.

## 9. The map: 2x Hollow Crown, squads, hot zone, sky train
- **Size and squads.** 305 m, Heart on the Throne at the centre. 10 trios (30 Hunters): 40 is not frame-time flat yet. The zone and the four seats do not change if 13 squads come later; the seat share drops from 40% to 31% and the sim decides whether a fifth seat is needed. Not now.
- **Sites, measured from the Heart:** lairs 90 to 95 m (Eyrie, Forge, Thornhive, as placed); two outposts at 59 to 71 m, at least 90 degrees apart, at least 60 m from the Heart Gate (task 6); Heart Gate 34 m, angle by seed.
- **Rule the map check enforces (replaces rev 1's "inside the ring for 150 s"):** for every lair and uplink pick, (a) circles nest and hold the Heart; (b) the Sealed Lair arena is inside the wall until `lair_shut_s + lair_fight_max_s` and outside circle 3; (c) the Uplink yard is inside circle 3, outside circle 4, and its centre is inside the wall until `uplink_shut_s + uplink_lift_s`; (d) the Gate is at least 10 m inside circle 4.
- **Hot zone.** Stays as built (`hot_zone.gd`: 1 of 8 outer regions by seed, +1 rarity) and is picked apart from the zone. On the lean side it is rich and safe until 4:00 or later, so expect a fight. On the far side the wall passes it at 2:15 to 2:45 at 0.7 hp per second: about 90 s of paid looting, then a run. No code change.
- **Sky train.** Keeps running the whole match (halts at 107 to 130 m). It is the fast way round in stages 1 and 2 and is fully outside the wall after 6:40. Riders take Blight hurt like anyone.

## 10. Monsters and Boki in a closing zone
- **Only Hunters take Blight hurt.** Unchanged from what is built.
- **Blight monsters** (Skitters, Wardens) are stronger and spawn faster outside the wall (existing `boost` 0.55 and `heat` 0.06, now read from the zone). The wall is where they come from.
- **Camp monsters, lair bosses and wild Boki** are not hurt and do not move in 0.24.4. A wild Boki outside the wall can still be linked by a Hunter who pays the health. The two lairs that are not sealed are loot only and are gone by 6:00.
- **Your own Boki** are never hurt by the Blight and always come home.
- Later, not 0.24.4: monsters more than 30 m behind the wall are removed (frees budget for the final), and wild Boki run ahead of the wall so the zone herds them toward the players.

## 11. UI
- **Beat clock** (top centre, first thing in the Ways Out strip): "Blight closes in 0:45", then "Blight closing" while it moves. A sting 10 s before each beat.
- **Map, minimap, drop map:** solid line = the wall now; dashed line = the next circle; the four seat sites with their times; the hot zone. Circle 1 and all four sites are on the drop map.
- **Outside the next circle:** "Safe ground 85 m" with a direction tick. **Outside the wall:** the existing tint and pulse (ext/blight-edge-read) plus the hurt per second.
- **Ways Out strip:** four pips, Lair / Heart / Uplink / Final. Each shows locked with countdown, open, in use (squad colour), taken (struck through), or lost to the Blight. Beside it "Squads left: N".
- **Calls** (banner, feed, sound; `HeartSfx.call_out` from ext/sfx-ways-out): seat opens; seat started and by whom; seat taken ("Amber squad left by the Sealed Lair. 3 ways out left."); 30 s before a seat shuts; "The Blight took the Uplink."
- **Heart Gate prompt** for the carrier: "Leave now: small reward" with the list, hold 4 s. Under it: "Stay and the Heart opens at 10:00."
- **Dead and watching:** "Ways out left: N". **Results:** how you left or your placing, placement pay, seat reward, at The Hollow one line per Boki.

## 12. Where it plugs in
- Built: ext/ways-out-heart-seats d1ad12175 (rev 1 tasks 1 and 2: `heart.gd` state enum, `heart.json`, decision 0051, the smooth tide as `Heart.tide_*` statics), ext/ways-out-map-sites 8f60b9ca8 (`tools/ways_out_sites.py`, authored Heart site), ext/sfx-ways-out 214f8368b, ext/vfx-ways-out-seats, ext/map-2x-0245 2bd777c00 (on the release candidate).
- Zone callers today: `heart.gd` (`_tide_tick`, wall update), `blight_dir.gd`, `blight_wall.gd`, `scripts/ui/heart_hud.gd`, `tools/blight_check.gd`, `tools/heart_check.gd`, `tools/blight_edge_shots.gd`. The zone becomes one new file, `scripts/match/blight_zone.gd`, and the `Heart.tide_*` statics are deleted.
- `scripts/match/bot.gd` has no zone code at all.

## 13. Build plan
**Running tasks, what changes:**
- **Task 3** (delete open extraction, ext/ways-out-no-open): no change.
- **Task 4** (quest seats, ext/ways-out-quests): no code change. Two numbers in `heart.json` "quest" change, and the zone task makes them: `lair_shut_s` 330 to 300, `lair_fight_max_s` 90 to 70. Task 4 must read both from data (as its brief says). At integration the zone's lean reads Exits' Sealed Lair and Uplink picks.
- **Task 6** (map sites, ext/ways-out-map-sites): keep going as briefed (authored Heart, two outposts in the 59 to 71 m band on 2x, Gate arc). One follow-up task swaps `ring_r` in `tools/ways_out_sites.py` for the zone table and the rule in section 9.

**New tasks** are in `briefs/specs/WAYS_OUT_ZONE_TASKS.jsonl`, in dependency order. Waves for the 0.24.4 set (about 12 hours with parallel workers):
| Wave | Tasks | Needs |
|---|---|---|
| 0 (running) | tasks 3, 4, 6 | |
| 1 (start now) | zone core; results and Boki | ext/ways-out-heart-seats |
| 2 | bots zone sense + final + Runner + sim; zone HUD; map rule | zone core (map rule also task 6) |
| 3 | bots Raider/Holder; Ways Out strip; integration onto the release candidate | task 4, wave 2 |
| 4 | sim gates; GPU perf; feel pass | integration |

If the Raider/Holder bots or the strip are late, the release does not wait for them: the mode is whole without them (humans simply get the quest seats to themselves, and the beat clock and pips fall back to the zone HUD line).

## 14. Risks and gates
| # | Risk | Number | Answer |
|---|---|---|---|
| 1 | Most matches end with no carried loot | Cap 40% of squads out, expected 30% | Loot concentrates in leavers, placement pay, seat bundles. Gate: mean take-home per Hunter at least 85% of today's |
| 2 | Bots die to the wall | Today: all of them | Zone sense is in the 0.24.4 set. Gate: Blight causes at most 10% of bot deaths |
| 3 | The wall kills new players unfairly | Stage 1 is 0.7 hp/s; first deadly stage is 4:00 | Circle drawn 2 minutes ahead, beat sting, "Safe ground" line. Gate: Blight share of human deaths under 20% |
| 4 | Whole lobby on one island | Up to 5 squads on The Crown at 8:50, 12 Hunters inside 12 m at 11:00 | GPU perf bench before release; quest seats and the lean keep squads off the centre until 8:00 |
| 5 | Final with no winner | A stall needs a living rival in a 12 m circle for 60 s | Collapse to 12 m. Gate: no-winner matches at most 5% |
| 6 | A seat is swallowed while in use | Lair done by 6:10, wall at 6:11; lift closes 8:15, wall at the yard centre 8:19 | The map check asserts both for every pick on every map |
| 7 | Bots eat the seats | 9 bot squads, equal pace: 73% chance a human sees no early seat | 30 s delay and the cap in section 8 |
| 8 | Hot zone on the dying side feels like a trap | 3 or 4 matches in 8 | It is drawn next to circle 1 on the drop map; stage 1 hurt is mild. Owner call 3 |
| 9 | Net and saves | Zone is derived, not synced; rule numbers change | One `Net.VERSION` bump at integration; no save change |

Sim gates (200 bot matches on the 2x map, `--ways-out-sim`): seats used 2.6 to 3.4 per match (1.6 to 2.4 if the Raider/Holder bots are not in); final taken at least 90%; squads alive at 10:00 between 2 and 4; first seat used between 3:30 and 5:30; Blight share of bot deaths at most 10%; no squad wiped by the Blight before 8:00 in more than 3% of matches; no-winner matches at most 5%.
