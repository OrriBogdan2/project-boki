# Bots that play like people (2026-11-11)

Branch `ext/bots-human-1111`, base `origin/ext/release-integ-0245` (92df78ce4). Decision note:
docs/decisions/0061-bots-play-as-a-squad.md.

An expedition is 10 squads of 3 and most of them are bots, so the bots are most of what a player meets. This
pass watched full bot expeditions headless, ranked what gives a bot away, and fixed the top of the list.

## How it was measured

`tools/bot_human_check.gd` (`--bot-human-check`) runs a whole expedition with 30 bots, samples every hunter
twice a second and prints one `BOTHUMAN <tier> | <metric> | <value>` row per measure, plus a `BOTLOG` line for
knocks and for fights a squadmate ignored.

Before and after come from the same build: the match option `bot_plain` (probe flag `--bh-plain`) switches the
new rules off, which is the old behaviour. The numbers below are the last batch: 24 expeditions of 730 s,
medium 6 + 6, easy 3 + 3, expert 3 + 3.

```
godot --headless -- --bot-human-check --bh-measure --bh-diff=medium --bh-seeds=11 --bh-log=30
godot --headless -- --bot-human-check --bh-measure --bh-plain --bh-diff=medium --bh-seeds=11
```

A match does not repeat for a seed, and totals (engages, knocks) swing up to three times between two runs of
the same build. Shares are steadier. Read a difference under about 0.1 on three runs as noise.

## The ten that break it, ranked

| # | What a player sees | Evidence (before) | State |
|---|---|---|---|
| 1 | Squadmates run their own errands, islands apart | easy: no mate within 30 m 21% of the time, nearest mate 19 m on average; half of all knocks happen with no mate within 30 m | fixed |
| 2 | Hurt bots walk around unhealed with tonics on the belt | calm, under 70% health, heal in the belt, not drinking: 71% of that time (medium) | fixed |
| 3 | A bot loots or wanders next to a squadmate's fight | 70% of squadmates within 35 m join (medium), 52% (expert); `t=80 OatmealRaider fights sourpatch_; duskrunner is 7 m away doing 'chest'` | fixed |
| 4 | No disengage: bots trade to zero with heals left | 94% of knocked bots still had a heal; `low 1.1 s (backing off 0.0 s), heals left 4` | expert: fixed; medium and easy: weak (second pass: leave on the hits coming in) |
| 5 | Each bot shoots its own target | same target as a fighting squadmate 81% (medium) | fixed, small; second pass holds a fresh pick |
| 6 | One bot leaves for the way out or crashes a rival uplink, the other two do not | each bot rolled on its own | fixed |
| 7 | Belt items other than the tonic are never used in a fight | the belt was only read with no target | wired, small (bots seldom carry them) |
| 8 | Fights taken and kept while outnumbered | 66% of knocks are against more rivals than squad nearby | partly: no unprovoked start; knocks unchanged |
| 9 | Standing in telegraphed abilities | not measured here | in flight on ext/combat-bot-dodge-rebased |
| 10 | Almost nobody leaves: 0 to 3 of 30 extract | 0.5 per expedition before, 0.2 after (medium, noise) | left |

Not ranked because the probe could not measure them: kiting quality, ability timing, loot choice. "Idle at a
box" looked like a fault and is not: it is a bot kneeling at a squadmate's deathbox to bring them back.

## What changed

- `scripts/match/bot_squad.gd` (new, `BotSquad`): the squad. A bot with nothing pressing heads back when its
  nearest mate is over 28 m away, and bases to them past 55 m. It notices a squadmate's fight from 24 m (easy)
  to 38 m (expert), goes there and treats that rival as provoked. It shoots the rival the squad has called (a
  player's target first, else the first bot's). It does not start a fight against more than it has nearby (one
  extra rival for medium and up, two for easy). Leaving and crashing an uplink are decided once for the squad.
  A squad with a player on it keeps to the player.
- `scripts/match/bot_retreat.gd` (new, `BotRetreat`): leaving a fight. Under a health mark (easy 32%, expert
  44%; 20 points higher when outnumbered) a bot may notice it is losing (easy about half the time, expert
  always), backs off toward a mate over safe ground, dashes clear, and drinks once it has not been hit for
  1.1 s and the rival is 8 m off or out of sight. It gives up running after 9 s and does not run from a rival
  that is nearly down.
- `scripts/match/bot_belt.gd`: the belt is read in a fight too; a calm bot with two tonics tops up under 70%.
- `scripts/match/bot.gd`: 30 lines of hooks. `Data.BOT_DIFF` is untouched; every rule reads the tier's `skill`
  and `abil`.
- Off in the duel room and with `bot_plain`.

## Before and after (per expedition, 730 s)

| Measure | Medium before | after | Easy before | after | Expert before | after |
|---|---|---|---|---|---|---|
| No mate within 30 m (share of time) | 0.11 | 0.05 | 0.21 | 0.09 | 0.12 | 0.09 |
| Nearest mate, metres | 11.0 | 6.9 | 19.1 | 11.6 | 11.4 | 10.5 |
| Calm and hurt with a heal unused (share) | 0.71 | 0.19 | 0.64 | 0.36 | 0.71 | 0.17 |
| Calm and hurt, seconds | 1826 | 583 | 1268 | 410 | 2023 | 1013 |
| Squadmates within 35 m that join a fight | 0.70 | 0.83 | 0.60 | 0.78 | 0.52 | 0.65 |
| Same target as a fighting squadmate | 0.81 | 0.89 | 0.88 | 0.91 | 0.93 | 0.92 |
| Knocked with no mate within 30 m | 0.49 | 0.31 | 0.53 | 0.36 | 0.35 | 0.30 |
| Low in a fight with a heal unused | 0.84 | 0.81 | 0.74 | 0.91 | 0.80 | 0.49 |
| Knocked with heals left | 0.94 | 0.93 | 0.85 | 0.93 | 0.91 | 0.75 |
| Knocked without ever backing off | 0.08 | 0.04 | 0.09 | 0.01 | 0.06 | 0.01 |
| Fights that turned (under 50%) and were survived | 0.48 | 0.43 | 0.58 | 0.38 | 0.49 | 0.52 |
| Knocked against more rivals than squad | 0.66 | 0.74 | 0.63 | 0.69 | 0.52 | 0.61 |
| Engages started outnumbered | 0.24 | 0.22 | 0.24 | 0.22 | 0.23 | 0.26 |
| Target changes per fight minute | 3.5 | 7.8 | 2.2 | 6.7 | 3.4 | 7.0 |
| Knocked hunters brought back | 0.85 | 0.85 | 0.77 | 0.41 | 0.90 | 0.82 |
| Extracted (of 30) | 0.5 | 0.2 | 1.0 | 1.3 | 1.0 | 1.3 |

Tiers still differ after the change: an easy squad is apart more than an expert one, heals less when calm
(0.36 against 0.17 unused) and only the expert drinks in a losing fight (0.49 unused against 0.91 for easy).

Decision log, before:

```
t=71 moonwalker99 knocked by glitchwitch: low 1.1 s (backing off 0.0 s), heals left 4, 1v1, nearest mate 119 m (keyhunt)
t=73 Cr0ssfade knocked by Hunter: low 1.2 s (backing off 0.0 s), heals left 3, 1v3, nearest mate 130 m (lair_dial)
t=80 OatmealRaider fights sourpatch_; duskrunner is 7 m away doing 'chest'
t=74 pepper_jack fights nova_nick; wheezy_ is 28 m away doing 'lair_fight'
```

After:

```
t=98 midnight_oil knocked by sk8rboi_: low 16.7 s (backing off 2.5 s), heals left 0, 2v3, nearest mate 14 m (fighting)
t=97 moonwalker99 knocked by duskrunner: low 3.4 s (backing off 3.5 s), heals left 2, 3v3, nearest mate 9 m (fighting)
t=82 kn1ghtowl knocked by sk8rboi_: low 4.9 s (backing off 1.0 s), heals left 4, 2v3, nearest mate 9 m (assist)
```

## What did not work, and what it cost

- **Retreat rarely saves a medium or easy bot.** Under focus fire the last third of a health bar lasts about
  a second, so the bot is knocked while it turns. Fights survived after dropping under 50% did not improve
  (0.48 to 0.43 medium). Expert bots do get their drink in. A real fix needs the bot to leave earlier on what it
  can see coming (three rivals closing), not on its own health.
- **Target changes doubled** (3.5 to 7.8 per fight minute, all tiers). Fights are now three against three, so
  there is more to switch between, and a follower switches when the caller does. It was not watched on screen;
  if it reads as twitchy, hold a called target for a few seconds in `BotSquad.called`.
- **Easy squads go down together.** In two of three easy runs only 12% and 20% of knocked hunters were brought
  back (0.60 to 0.89 before): the squad fights as one and nobody is left to pick up. Medium and expert did not
  move. Hunter time on their feet per expedition is the same before and after.
- **Outnumbered knocks did not fall.** Bots no longer start those fights, but squads meet squads and a fight
  that loses one hunter is outnumbered from then on.
- **Extraction is unchanged**: 0 to 3 of 30. Only four seats leave by design (docs/decisions/0051), but most
  squads never try.

## Second pass (same day): leaving on what is coming, holding a target, two twitches

Measured against the first pass's head (e88b9dfa8), not against `bot_plain`: 730 s expeditions on jobq
workers, base medium 2, easy 3, expert 3; branch medium 4, easy 3, expert 4.

- **Leave on the hits coming in** (`BotRetreat.down_in`): a bot keeps a damage rate (health and armor, smoothed
  over 0.6 s). When that rate would put it down within 0.8 s + 1.6 s per point of skill (easy 1.2 s, expert
  2.3 s), it counts as losing even at high health, and it stays out at least 2 s before it thinks again. Under
  focus fire from three rivals that is near full health. In a 1v1 trade the old health mark still decides.
- **Hold a fresh pick** (`BotSquad.held`): for 2.5 s after it picks a rival, a bot scores that rival +14 instead
  of +6.
- **Don't drop the current rival when the odds turn**: `outnumbered` was meant to stop a bot starting a fight,
  but it also dropped the rival a bot was already fighting. A trace of 32 target flips in a 330 s run found 4 of
  them came from this (11 were the rival leaving team vision, 13 were out-scored, 4 were reach or height). It now
  only applies to a new pick.
- **Assist under a ledge**: in reach of the rival with no shot, a helper goes to its squadmate instead of walking
  at a spot it cannot reach (the `assist` facing twitch from the first pass).
- **Roam wobble**: one sanity run flagged a follower with goal `roam` turning on the spot for 25 s. It was walking
  onto a squad lead that was busy, or to the lead's leftover wander spot. A follower now follows the lead's live
  roam goal, and within 6 m of a busy lead it waits on one spot (`roam` joins the goals a bot stops on).

| Measure (mean per expedition) | Medium base | branch | Easy base | branch | Expert base | branch |
|---|---|---|---|---|---|---|
| Fights that turned (under 50%) and were survived | 0.42 | 0.41 | 0.52 | 0.50 | 0.39 | 0.50 |
| Low in a fight with a heal unused | 0.64 | 0.80 | 0.83 | 0.84 | 0.59 | 0.49 |
| Knocked with heals left | 0.81 | 0.90 | 0.89 | 0.96 | 0.83 | 0.79 |
| Target changes per fight minute | 9.0 | 6.4 | 5.3 | 6.4 | 8.4 | 7.4 |
| Engages started outnumbered | 0.28 | 0.27 | 0.26 | 0.20 | 0.30 | 0.24 |
| Knocked against more rivals than squad | 0.68 | 0.68 | 0.72 | 0.62 | 0.63 | 0.65 |
| Calm and hurt with a heal unused | 0.09 | 0.28 | 0.20 | 0.32 | 0.18 | 0.19 |
| Knocked hunters brought back | 0.66 | 0.53 | 0.65 | 0.67 | 0.87 | 0.87 |
| Extracted (of 30) | 0.0 | 1.75 | 0.67 | 2.0 | 0.33 | 0.25 |

How to read it: with three or four runs a side, only a gap above about 0.1 means anything. Expert bots survive more
of the fights that turned (0.39 to 0.50). Medium target changes fell by a quarter. Neither of these held on
easy, which is the tier with the smallest window. Medium "calm and hurt" rose, but one of its runs had only 14 calm
hurt seconds, and the first pass measured the same rule anywhere from 0.03 to 0.58. Medium extraction rose from a
base of two runs with nobody out. Treat that as noise until more runs agree.

Bot sanity (`--bot-sanity-check`, three seeds of 150 s): the 25 s roam wobble did not come back in four branch
runs. Two runs had one or two single-window flags (`keyhunt`, or `roam` while crossing to an island). Those are the
kinds the base flags too, and that base run was clean.

## Left

1. Easy bots still mostly fail to get out: their window (1.2 s) is shorter than a turn under focus fire. To change
   that, easy would need a bigger window, at the cost of the gap between tiers.
2. Easy squads go down together (knocked hunters brought back stayed at 0.65 to 0.67 this pass).
3. More squads heading for a way out in the last third of the match.
4. Kiting, ability timing and loot choice need their own probe rows.
5. Medium squads apart 14% to 22% of the time on some runs (see The check).
6. Most of the remaining target changes come from the rival dropping out of team vision. A short memory of a
   rival's last seen spot would cover it.
7. Not duplicated here, in flight elsewhere: dodging (ext/combat-bot-dodge-rebased), ring and downed play
   (ext/combat-bots-ring, ext/combat-bots-downed), Boki summons (ext/bot-boki-summon).

## The check

`--bot-human-check` with no flags runs one medium expedition (730 s of match, about 7 minutes) and fails when
calm hurt bots leave a heal unused more than 70% of the time, when no mate is within 30 m more than 30% of the
time, or when fewer than 60% of nearby squadmates join a fight. It skips its limits when the wall clock cuts
the run short.

One expedition is a noisy sample, so the limits only catch the behaviour going away, not a small slide. The
heal limit is the one that tells old from new on a single run: the new behaviour measured 0.03 to 0.58 on
fourteen medium runs, the old 0.42 to 0.95 on eight (five of them over the limit). Squad apart measured 0.00
to 0.08 on eleven new runs and 0.14, 0.21 and 0.22 on three (old: 0.05 to 0.31), so that limit sits wide at
0.30 and one run cannot tell old from new on it. Those three runs were not looked into; a bot shut in a lair
away from its squad would produce them. For a real comparison run several seeds both ways with `--bh-measure`
as above.

## Other checks, and one twitch

Run on remote workers through `jobq`, each red one also run on the base commit:

- Green: `--check`, `--simtest --seed=5`, `--extract-check`, `--lair-lock-check`, `--equal-check`,
  `--equal-migrate-check`, `--hot-zone-check`, `--base-check`, `--crowd-check`, `--biome-check`,
  `--heart-check`, `--keys-check`, `--ping-check`, `--duo-check`.
- Red on the base too, same lines: `--bot-kit-use` (ashwick, gil), `--teammate-check` (three tutorial lines),
  `--box-revive-check`, `--revive-net-check`, `--rolling-check` (the wave), `--new-player-flow-check` (no skiff).
  Two earlier branch runs of the new-player flow failed elsewhere (the hatch took 60 s; the driver stalled at
  the glove). The tutorial match has no bots in it, and two later branch runs matched the base.
- `--bot-sanity-check` is red on the base (three flagged windows) and on the branch (none to two per run). One
  of the branch's is new: a bot with the `assist` goal and no target changed facing 19 times in five seconds
  (seed 5 after seed 3, t=106). It showed in two of three plain runs and in none of seven runs with the watch
  on (six of those ran seed 5 alone, which plays out differently), so the cause was not found. A guess: the rival is in earshot but on a ledge the bot cannot shoot at, and
  the bot wobbles under it.
- The whole fast suite was not run: the box's Godot queue was jammed for most of the session.
