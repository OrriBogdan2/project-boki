# Run-level pace (XP per source)

Hunters start each expedition at level 1 with every ability locked. Each level is a point to rank an
ability, and R opens at level 6 (rank 2 at 9). This page compares how fast those levels come with the
reference game, and records the XP numbers we chose. The level-up rules are unchanged: the level table
`XP_TO`, `SLOT_MAX` and `ULT_AT` in `scripts/match/hunter.gd`. Only the XP gains moved to data, in the
`xp` block of `content/rules/level_growth.json` (read by `LevelGrowth.xp`).

## What the source tells us

- **No XP or level tables.** `briefs/supervive-data/supervive_kits.md` and `supervive_physics.md` [D]
  have no XP per monster, knock, objective or second, and no XP-to-level curve. All [D] gives is that
  upgrade tiers II/III/IV are per-ability level-ups and R has II/III only (kits.md line 4). Ours
  matches that (3 ranks per ability, 2 for R).
- **No level-up timestamps in the footage.** The hero-ref sheets [F] are ability showcases and
  practice-range clips with the hunter already at a fixed level (9 for Juggernaut, Linwick, Venator
  and Dredge; 15 for the kits read in [D]). No sheet has a level-up during a real match, so there is
  no source time-to-level to compare with. I didn't fetch frames: they would show the same fixed-level
  clips.
- **What [F] does show** (`briefs/hero-ref/HUD.md`): levels 1-15 seen on plates (so the source goes to
  at least 15; ours stops at 10), a long XP bar under the level, and small "+17 XP" pop-ups. That
  means XP comes in many small gains, the same as our damage XP.
- `briefs/DECISIONS.md` has no owner pace target. It only says level-ups rank abilities and give no
  stat bonuses (2026-11-05). That is unchanged.

So the target below is our own, set to fit our 612 s expedition (360 s x 1.7 on the big map):

| Level | What it opens | Target |
|---|---|---|
| 2-4 | the first ranks of a kit that starts locked | the first fight (about 1 min) |
| 6 | R | the middle of the match (3-4 min) |
| 10 (max) | everything | near the end, only for hunters who fight all match |

## Measured: 3 headless 30-hunter bot matches

`godot --headless --path . -- --level-pace-sim --seed=N` (seeds 1-2-3; 10 squads of 3, all bots,
tier 1). Times are match seconds (from the drop) to the median hunter's **first** time at that level,
taken over the hunters who got there. Over all 30 hunters the median for level 6 is "never", because
most bots go out in the first 2-3 minutes (7-14 of 30 reach R). That is about survival, not XP.

| Level | Before: seeds 1 / 2 / 3 | Before median | After: seeds 1 / 2 / 3 | After median |
|---|---|---|---|---|
| 2 | 35 / 39 / 37 s | **37 s** | 43 / 47 / 40 s | **43 s** |
| 4 | 54 / 80 / 61 s | **61 s** | 71 / 100 / 71 s | **71 s** |
| 6 (R) | 107 / 126 / 187 s | **126 s** | 209 / 251 / 178 s | **209 s** |
| 10 (max) | 376 / 271 / 455 s | **376 s** | 575 / 548 / 535 s | **548 s** |
| reached R | 6 / 11 / 14 of 30 | | 7 / 10 / 8 of 30 | |

Before, R came at about 2 minutes and the survivors hit max level by minute 4-7, leaving the rest of
the match with nothing to gain. After, R comes at about 3.5 minutes and max at about 9 minutes, close
to the end. Levels 2-4 still come in the first fight.

XP per hunter by source (after; the mean over all 30, dead ones included), seeds 1 / 2 / 3: trickle
163 / 209 / 127, knocks 99 / 96 / 102, damage and lair bosses 288 / 270 / 275. Damage is the biggest
source and knocks are the biggest single gains.

## The numbers (`content/rules/level_growth.json` `xp`)

| Key | Before | After | Why |
|---|---|---|---|
| `trickle_per_s` | 1.2 | 1.0 | with no fights at all, R takes 650 s (was 540 s), just past the end: R is earned by fighting |
| `per_dmg_monster` | 0.35 | 0.2 | farming monsters was the fastest road to max |
| `per_dmg_hunter` | 0.6 | 0.45 | fighting hunters still pays more than twice monster damage |
| `knock` | 90 | 90 | the knock stays the biggest single reward (the source has a knock callout on screen too) |
| `lair_boss` | 260 | 200 | a boss still gives about a level, scaled down with damage XP |

**Recommendation:** keep these. Two follow-ups are not part of this change: bots die early (fewer than
half reach R in any match: a bot-survival or match-flow pass), and the source goes past level 10
(changing the level table is a rule change, so it's the owner's call).
