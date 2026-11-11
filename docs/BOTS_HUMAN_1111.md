# Bots that play like people (Nov 11)

Expeditions fill up to 30 slots with bots, so how they play is a large part of how a match feels. This
pass watched full headless expeditions (10 squads of 3, every hunter a bot) and judged the bots the way a
good player of the genre would: target choice, kiting, ability timing, dodging, Boki, looting, rotating
to the way out, backing off when low, and squad play.

## How it was watched
- `--bot-watch [--seed=N] [--bot-diff=D] [--watch-t=S]` (tools/bot_watch.gd): one 720 s expedition.
  Prints a line per down: seconds it kept fighting under 30% health, how much of that it spent backing
  off, the fight items still on its belt, the nearest squadmate, who did it. Ends with a summary: belt
  uses in fights vs calm, how often squadmates in a fight shoot the same rival, squad spread, and how
  many got out.
- `--bot-human-check` (tools/bot_human_check.gd): the fixed behaviours as five staged cases.
- Runs: seed 11 medium and seed 12 hard, before (0.24.5, `92df78ce4`) and after (this branch). The
  full logs are in `docs/bots_human_1111/` (one line per down, then the summary).

## The ten most immersion-breaking behaviours (ranked)
| # | Behaviour | Evidence (before) | Status |
|---|---|---|---|
| 1 | **Nobody rotates to the way out.** Bots never go for the Heart ring; the `bots` plan block in `content/rules/heart.json` (raider/runner/holder/stayer) is read by no code. | 0/30 extracted on both seeds, all 30 out when the islands fall at 720 s. | Partly: the final ring only (0 -> 1 and 3 of 30 out) |
| 2 | **Fights to the death.** A losing bot keeps trading at 10% health; it never steps away. | medium: 16 of 49 downs fought on under 30% for >1.5 s, 0-2% of that time backing off. | Fixed |
| 3 | **Belt items never used in a fight.** `BotBelt.think` ran only with no target, so its in-fight rules (mending kit, smoke, shield cell, stim) were dead. | medium 4 in-fight uses vs 48 calm; 15 downs with a medkit/smoke/stim still on the belt. | Fixed |
| 4 | **Squads scatter.** After the drop each bot roams alone (random camp anywhere on the map, random ground). | squadmates 26-110 m away at the first downs; 24 of 49 (medium), 110 of 267 (hard) downs with no mate within 25 m. | Partly: medium 49% -> 36%, hard unchanged at 41% |
| 5 | **No focus fire, no helping a mate.** Each bot picks its own nearest rival; a mate being shot 15 m away is ignored (reach 8-13 m). | squadmates in a fight on the same rival 64% (medium), 68% (hard). | Fixed |
| 6 | **Target choice ignores a hurt rival.** `- hp * 0.03`: a rival at 20% health was worth 2.4 m over a full one. | code (bot.gd `_choose`) | Fixed (with 5) |
| 7 | **Dies in the Blight tide.** No zone sense: late game the tide kills bots standing outside it. | hard: 222 of 267 downs after 480 s, almost all "by a monster/Blight" with 0 s of fighting. | Left: `ext/combat-bots-ring` (BotRing) |
| 8 | **No dodging.** The only defensive move is a sideways dash after taking 12 damage. | code | Left: `ext/combat-bot-dodge(-rebased)` (AimKit telegraphs) |
| 9 | **Fixed range by class, no kiting.** Preferred range is one number per class/weapon, whatever the rival's gun. | code | Left (see below) |
| 10 | **Boki and camps.** Bots never press Summon; fight choice ignores level. | code | Left: `ext/bot-boki-summon`, `ext/early-camps-bots(-a3)` |

## Checks
- `--bot-human-check`: 5/5 (retreat 6 m -> 15 m, tiers expert 58/60 vs easy 20/60, mending kit used in
  a fight, regroup from 130 m, focus on the squadmate's rival).
- Ran on the branch: revive, box-revive, heart, truce, drop, duel, arena, blight, lair-lock,
  bot-sanity (2 runs), perf-throttle (3 runs): pass. teammate-check: 3 failures, the same 3 on 0.24.5.
- `--perf-throttle-check` setup fixed: it moved a roaming bot that could be mid-glide over a gap (it is
  random; 0.24.5 failed it 1 run in 2 here). It now also drops the glide and the crossing plan.
- `--bot-sanity-check` is unseeded too; it flagged facing flips on the first version of the regroup
  goal (re-aimed at a walking lead every think), fixed by the steady goals above.

Not on the list because they hold up: kit ability timing (checked per Hunter by `--bot-kit-use`),
revives (`--revive-check`), looting (nearby boxes, keys then chests).

## What changed
- **Back off when losing** (`scripts/match/bot_retreat.gd`, `BotRetreat`): under 35% health against a
  rival above 25%, the bot backs off 10 m at a time toward its squad's lead, dashes straight out instead
  of to the side, keeps shooting when it has a line, and only turns on whoever hit it in the last 1.5 s.
  Out of reach it keeps going and drinks. A retreat lasts at most 5 s (cornered: fight), then 8 s before
  it weighs another. Kit moves that carry it at the rival (Shadow Step, leaps, Rampage) are held while
  it backs off, as they already were during a revive.
- **The belt in fights** (`bot_belt.gd`): `BotBelt.think` now runs in fights too. The tonic waits until
  no rival is close (drinking marks you VULNERABLE); the mending kit is the in-fight heal.
- **Play as a squad** (`scripts/match/bot_squad.gd`, `BotSquad`): the lead is the person in the squad,
  else the drop leader, else the first one up. A calm bot past 22 m from the lead walks back (until
  8 m), and with nothing of its own to do goes to its spot beside where the lead is going (goal kind
  `tag`, it stops there). Both goals hold still while the lead stays within 8 m of them, so a walking
  lead doesn't re-plan its followers' paths and gap crossings every think. Followers
  head for the way out when their bot lead does. Target score adds the squad's rival (a mate on it, or
  it hit a mate in the last 4 s) and the reach to it grows to 24 m.
- **Rotate to the Heart** (`Heart.bot_spot`): from 40 s before the final seat opens (or at once when
  it opens early) bots go to their own spot inside the Heart ring and hold it like an uplink yard
  (fight from it, don't base away).

## Difficulty tiers
Nothing in `Data.BOT_DIFF` changed; every new behaviour reads the existing knobs:
- backing off: chance per bad moment `0.3 + 0.7 * skill`: easy ~40%, medium ~65%, hard ~80%, expert ~95%
  (`--bot-human-check` tiers case: expert 58/60, easy 20/60);
- belt in fights: reach rate `abil * 3 /s` (easy ~1.1 s to react, expert ~0.3 s);
- focus bonus `8 m * skill`, hurt-rival weight `6 m * skill`, assist reach `24 m * aggro`.

## Before / after
Same seed, same difficulty, 720 s, every hunter a bot (`--bot-watch`). Logs: one line per down, e.g.
before: `[t= 37.8] DOWN Cr0ssfade (squad 2) fought under 30% for 1.2s, backing off 0% | unused: tonic x3,
smoke x1 | nearest mate 110m | by ghostpepper_`.

| | medium, seed 11 | | hard, seed 12 | |
|---|---|---|---|---|
| | before | after | before | after |
| hunters out by the way out (of 30) | 0 | 1 | 0 | 3 |
| downs | 49 | 78 | 267 | 99 |
| downs after >1.5 s fighting under 30% | 16 (33%) | 10 (13%) | 22 (8%) | 3 (3%) |
| downs with no squadmate within 25 m | 24 (49%) | 28 (36%) | 110 (41%) | 41 (41%) |
| squadmates in a fight on the same rival | 64% | 76% | 68% | 75% |
| squad spread (farthest member from the middle) | 12.0 m | 13.5 m | 15.4 m | 10.7 m |
| belt uses in a fight / calm | 4 / 48 | 8 / 61 | 15 / 73 | 5 / 60 |
| retreats (still down within 10 s) | 0 | 19 (12) | 0 | 22 (15) |

Reading it: medium has more downs because squads now join each other's fights (more of the 30 fight
at all), but the share that died trading at low health fell from a third to an eighth. More than half
the retreats still end in a down within 10 s: a bot backing off is often chased down, which is also
what happens to people; dodging (row 8) and smoke use would help. In-fight belt uses stay low because
most bots carry only the issued tonics and armor kits (one spare item from medium up) and the tonic
now waits until no rival is close; calm uses (drinking after backing off) went up. Hard's late Blight
deaths fell with the rotation to the Heart, but real zone sense is the `ext/combat-bots-ring` branch.
"Alone" downs on hard did not fall in share. One seed each and the bots are unseeded: treat moves of a
few points as noise until more seeds run.

## Left for later
- The full heart.json bot plans (spec task 7): raiders, runners taking the Heartspark to the Gate,
  holders and stayers, the early-seat cap for bot squads. This pass only sends squads to the final ring.
- Kiting by the rival's range (a shotgun bot backing off from a sniper's reach, closing on a shotgun's).
- Zone sense, dodging, Boki and camp choice are on the open branches named in the table; merge those
  before re-measuring rows 7, 8 and 10.
