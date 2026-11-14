# Save chain from v11 (0.24.5 and the READY branches)

One ordered line of save versions after v11, the last tagged release's (v0.24.3). Each READY branch that
bumped `Save.VERSION` on its own takes the number below and nothing else. Decision: docs/decisions/0109-save-chain-0245.md.
`--save-chain-check` (tools/save_chain_check.gd) loads a v11 save, runs every step in order, and fails if a
step is missing, skipped or not listed here.

Rules:
- Every step only adds what is missing (as in decision 0060), so running it twice changes nothing. That lets
  a dev save from a branch that used a number for something else still load: it re-runs or later gets the
  step it missed.
- A step that has landed never changes number or meaning. A new step takes the next free number and gets a
  row here in the same change.
- 0.24.4 shipped v12 = Evo, so v12 and v13 stay as release-integ-0245 has them (decision 0060).

## Landed on ext/save-chain-0245

| Step | Branch | What it does |
|---|---|---|
| v11 -> v12 | release-integ-0245 (ext/evolution-rules-1108 + ext/garden-integrated) | `Evo.migrate` (levels capped, old form kept) and base life (`rec["bonds"] = {}`) |
| v12 -> v13 | release-integ-0245 (ext/garden-waystone, ext/garden-items line) | v11 -> v12 again, then `GardenZones.migrate` and `Care.ensure` on every Boki |
| v13 -> v14 | main (ext carry-pick, docs/decisions/0090-carry-pick.md) | carry 2: `d["active2"] = ""` (the second starts empty). Main took v14 before this chain landed, so the chain's v14-v18 moved up by one |
| v14 -> v15 | ext/tut-move-drills (was its v11 -> v12, then v13 -> v14) | v12 -> v13 again (heals the first-time-hints line's v13), then `d["drills"] = {}` |
| v15 -> v16 | ext/tut-resume (was v11 -> v12, then v14 -> v15) | `TutorialResume.migrate`: a played save is past the combat tutorial |
| v16 -> v17 | ext/clans-slice-1/-2 (was v11 -> v12, then v15 -> v16) | a guild becomes its clan as a member (`Social.clan_for`); a clan it already has stays |
| v17 -> v18 | ext/tut-xp-hint / ext/tut-xp-share (was v11 -> v12, then v16 -> v17) | `XpHints.migrate`: the XP first-time lines are unseen |
| v18 -> v19 | ext/garden-sleepovers (was v12 -> v13, then v17 -> v18) | `d["sleepovers"] = []`; also `d["active2"] = ""` if missing (a dev save from this chain's v14-v18 skipped carry 2) |

The clash noted on ext/garden-waystone: ext/tutorial-beats-7-8-rebased and the other `*-rebased` branches
of merge candidate mc-20261110-1030 use v13 = `FirstTimeHint.migrate`, while 0.24.5 uses v13 = zones. A
dev save from that line skips the garden half at v13, so v14 -> v15 (drills) re-runs it first; its hints
step comes at its own number below.

## Next numbers, in this order, for the branches not merged here

These conflict with 0.24.5 far beyond save.gd (each is a feature merge of its own), so they are not on
this branch. Each takes the next free number when it lands, in this order, and adds its row above:

| Planned | Branch | Its old number | Step |
|---|---|---|---|
| v19 -> v20 | ext/tutorials-cut line (ext/tutorial-beats-7-8-rebased, ext/first-hints-check, ...) | v11 -> v12 or v12 -> v13 | `FirstTimeHint.migrate` |
| v20 -> v21 | ext/hunter-first-hints | v13 -> v14 | `HunterHints.migrate` |
| v21 -> v22 | ext/wisp-cosmetics | v12 -> v13 | `BokiWispCosmetics.migrate` |
| v22 -> v23 | ext/tut-first-breed | v12 -> v13 | `FirstBreed.migrate` |
| v23 -> v24 | ext/farm-boki-xp-curve | v13 -> v14 | `Evo.migrate_xp` (saved XP keeps its share of the level) |

The order is the order of their READY lines in briefs/EXT_TO_MAIN.md. `Evo.migrate_xp` rescales XP and is
not idempotent as written: when it lands it needs a marker (or another guard) so a second run changes
nothing.

All the other READY branches with a v12/v13/v14 save only carry one of the steps above from the branch they
were built on: ext/evolution-rules-1108 (Evo), ext/garden-integrated (bonds), tutorials-cut (first-time
hints) and the garden-items/zones lines.
