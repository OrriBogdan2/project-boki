## Vex and Kael re-check on main dae69e1c59 (2026-11-23, branch ext/parity-recheck-vex-kael)

Every Vex (`gunslinger`, source Ghost) and Kael (`juggernaut`, source Brall) row was re-read on today's main against `docs/heroes/{gunslinger,juggernaut}.md` and the data and kit files (`content/archetypes/{gunslinger,juggernaut}.json`, `content/weapons/{quill_rifle,greatsword}.json`, `content/dash_flow/{gunslinger,juggernaut}.json`, `content/rules/kit_parity.json`, `scripts/arch/kits/{gunslinger,juggernaut}_*.gd`). The source numbers are the ones those docs quote from `sv/briefs/kits.md` and `briefs/hero-ref` (not in this tree). The last full read was 11-12 (main 88b06b9e7). The current rows are the Vex and Kael sections of `docs/KIT_PARITY.md`, which lost their stacks of superseded duplicate rows (and a Vex table that sat inside the Lace section) in this branch. No number was changed.

Owner rows left alone: all cooldown ratios (gap 10: Vex RMB 6.5 vs 9, R 42 vs 55; Kael air RMB 7.2 vs 9, R 36 vs 45), Kael's LMB with no knock (11-11), the RMB straight thrust and its perfect release, the straight down Meteor Drop, Vex's needle width, air control.

### Drift since 11-12, with the commit that moved it

| # | Item | Was (doc) | Now (data) | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | Vex Dazed rifle bonus | +90% (six places in `gunslinger.md`, and the card line `card.weapons.quill_rifle`) | +76% (`rattle_k` 0.76; asserted `Dazed: the rifle does +76%`) | `f1faa19908` (11-11) | source +39 on a 51 round | none (parity); **fixed** the doc rows and the card line (wiki `Class-Hired-Gun.md` regenerated) |
| 2 | Vex rifle cadence | 0.12 | 0.08 (~12 rounds/s) | `f1faa19908` (11-11, fun audit) | source rate | none; **fixed** the Parity-pass row (it said 0.12 unchanged); the dated Timing pass row (Nov 8) keeps 0.12 |
| 3 | Vex Palm Lance damage | 36 | 24 (0.157 of a target) | `f1faa19908` | source share | none; Scaling paragraph said 36, fixed |
| 4 | Vex RMB | Burr Charge, a launcher shot, a lane on hold | Coin Blast: a tap, a coin tossed from her free hand (`coin_flick`); same numbers (22 hit, cone 16, 10.5 m, cd 6.5) | `bb80b9b55c`, `d4da0a8765` (11-17) | owner 11-17 playtest "RMB should clearly be a coin toss", item 112 | owner row; **fixed** the per-slot row (`gunslinger_rmb_hold` and the "white lane" no longer exist) |
| 5 | Vex E | Longneedle fired from the rifle | Palm Lance from her open palm (`palm_cast`); numbers unchanged | `bb80b9b55c`, `3a4e648b27` (11-17) | owner 11-17 "from her palm" | owner |
| 6 | Vex E yaw lock | 90 deg/s in the per-slot row | 30 deg/s (`turn.e.early`) | `128ff87287` (11-09), moved into the turn block by `3b3a04ceae` (11-19) | owner 11-09 "a strong yaw lock" | **fixed** the stale row |
| 7 | Vex E recovery | `linger` 0.75 | the kit holds her 0.6 s after the beam (`E_RECOVER`); the `linger` field is gone | `0ad0192a63`, `c78f8d7359` (11-11) | source recovery ~0.4 s after the 0.2 s shove | none; **fixed** the doc row and the Cancels table (it kept an older "no lock" row beside the held row) |
| 8 | Vex Slipstep charges | not stated | one charge, no Second Wind, no pips; locked in `kit_parity.json` | `edcc12b9d9` (11-16), `3b3a04ceae` (11-19) | source has one | none (parity) |
| 9 | Vex hold slide length | 10.3 m in the 11-10 re-check (finding B) | 7 m in all, from the press | `25f65d942` (merged `2ab972947a`, 11-13) | the source gives no hold length; 7 m kept | closed |
| 10 | Vex Cinderfall hold | rooted 0.76 s | no hold: a 0.25 s wind-up at 70% walk | `5687b9120d` (11-17) | owner 11-17 "shouldn't cause her to not move at all" | owner; **fixed** the casting-speed row (said 1.0) |
| 11 | Vex clips | `vex.glb` 36 clips | 41 clips, plus `vex_cast_clips.glb` 2; 8 moves in `warden_anim/vex.json` | `ca32bd9725`, `5149267aa6` (11-17) | v95 swap, idle/stance rework | none; coverage still full |
| 12 | Kael Slam | reach 4.0, angle 70 `[?]` | a lane 4.3 long, 0.72 wide, pinned in `kit_parity.json`; no angle | `704b7636e` (`ext/parity-kael-slam-lane`), `5e09138b3a` (11-13) | footage 0157: a magenta lane 0.4 bh wide, not a cone | none; the angle row is closed, ranges table and the per-slot row said 4.0, 70 or "4m": fixed |
| 13 | Kael Lunge length | 4.5 to 7.5 | travels 4.5 to 5.4 (`dist` [5.3, 6.35] x 0.85 feel), perfect release 6.5 | `4ea2625c13` (11-20) | footage 2.5 to 3 bh, DECISIONS 11-11 short lunge | none (parity); ranges table fixed |
| 14 | Kael Riposte reset | a hunter taken down | a hunter taken down, or any living foe it kills (monster, foe Boki) | `4ea2625c13` (11-20) | data "killing a living enemy", footage f99-f101 | none; Assumption 10 and the "no reset from monsters" row fixed |
| 15 | Kael Meteor Drop | cursor disc 2.2 (pin 2.2 +-0.22) | straight down, 2.4 m circle 0.8 m ahead (pin 2.4) | `0a97eddab`, `adc81b267` (owner 11-10), pin `baa8eadd1` (11-11) | owner 11-10 | owner; "regressed" is not a regression, fixed in the ranges table; per-slot "5 m reach" rows fixed |
| 16 | Kael CC riders | fireblast slow 30%, Lunge stun .35, Haul stun .25 to .6 | none | `9aff9d0b13` (11-11) | the source has none | none; "0.24.5 mark" lines that said "unchanged" were stale |
| 17 | Kael ours-only knocks | Lunge 7, Haul Slam 7, Flame Step 5 and 9, Riposte 6 | 0; LMB never knocks (owner 11-11, `d6fc02f946`) | `6df6e79d9e` (11-20) | the cards list no knock | none (the Slam push 6 stays) |
| 18 | Kael Searing Wave charge walk | 0 (planted) | 55% (`juggernaut_kit.gd:206`) | set by `b196ca6af2` (11-12), lost when `82ec860fc6` (11-14) reverted the merge that carried it | none; the footage cannot settle it (docs/MOVEMENT_FEEL.md) | none; **open** only as `[?]` |
| 19 | Kael LMB wave | range 6 to 10, 12 to 28 (stale per-slot rows) | range 7 to 14, 12 to 20, 36 m/s, burn 4 s | `e6429ccb05` (11-03) | footage 36 m/s, 2.5x a slash | none; **fixed** the rows (Assumption 4 too) |
| 20 | Kael Riposte | 34 damage, 22 s cooldown, key X (per-slot row) | 43, 36 s, key R (the Boki Merge is X) | `c6afc3901c` (11-03) and the key move | source heal 80%, ratio | none; **fixed** the row |
| 21 | Kael Rampage | 7 along it, tip 14, a big knock | 9, tip 18, no knock, cd 10.4 | `c6afc3901c` (11-03), `6df6e79d9e` | Flame Step has no knock | none; the stale per-slot rows are gone |
| 22 | Kael Warchain cooldown | 9.5 s in the per-slot rows | 12.8 (11.2, 8) | `6c420a82f6` fixed one row (11-20) | 0.8 x 16 | the other stale copies are gone |
| 23 | Kael clips | `kael.glb` 49 clips, 20 or 21 moves | 54 clips, 22 moves in `warden_anim/kael.json` | `12b7999661`, `a6075c29bd` (11-17, 11-18) | v95 swap under main's clips | none |
| 24 | Kael Scaling paragraph (`juggernaut.md`) | "slash 5.2, Slam 15.6, Lunge 7.1 to 10.1, ..." as if in the game | the JSON still has slash 8, Slam 26, Lunge 14 to 20, Meteor 18, Spin 18, Rampage 9 and 18, Warchain 6 | `4df7d9a186` (11-11) wrote the share cut into the doc and loosened `dancer_jug_check.gd`; no content file | `ext/ttk-kael` never landed and is not on origin | text **fixed**; the gap is open, below |
| 25 | `docs/TTK.md` Kael combo rows | 4.42 s (0.57) and 4.52 s (0.65) | 4.78 s (0.62) and 3.18 s (0.45) in `--ttk-check` today | not isolated: the 11-20 re-run (`e43e06aa0e`) read them unchanged, and a run on the parent of `c6369f7de1` (the 11-23 cast-into-cast commit) printed the same 4.78 and 3.18, so the move is between 11-20 and 11-23; a bisect needs a full import per commit and was not run | | doc table left as written; **open** |

Not moved since 11-12 (re-read, same): Vex rifle 6 a round, mag 30, refill 40/s after 0.35 s, sustain 50% over 10; Coin Blast 22 / 16, range 10.5, cone 6 m at 100 degrees, push 11, stun 0.7; Palm Lance charge 0.6, range 18, width 1.8, recoil 6, shave 20% / 30%; Cinderfall delay 1.6, 24 (+50% centre), radius 3.4, core 1.2, 3 s, 3.5 every 0.5 s, slow 30%, range 14; Slipstep tap 4.8 m / .45 s, hold 7 m at +40% cd, cd 8.5; Fever 6% for 3.5 s. Kael Smash cd 2.0, hold .3, sweet spot 2.4 to 4.2 m at +40%; Lunge 14 to 20, walk 80%, miss doubles the cd; Meteor 18, down .45 s, core stun .8 s, cd 7.2 (4.8); Warchain 13 m, 32 m/s, 6 damage, 5 s, pull 22, tether 24; Riposte guard .65, strike .1, recover .35, heal 80%; Rampage 4.5 m / .17 s, 2 charges (3 at rank 2); Rage Enraged 6 s +15% damage, +12% dash, +20% cooldown speed, knock heal 20%; ranks Vex RMB 5.4 / 4.3, dash 7.4 / 6.3, E +20% / +40%; Kael dash 8.8 / 6.4, Warchain 11.2 / 8, Smash +20% / +40%.

### Still open (source value in brackets; none is a number change made here)

- **Time to knock** (`--ttk-check`): Vex LMB 5.47 s against 2.48 (2.20x), combo 2.72 against 1.92 (1.41x) and 2.38 against 1.76 (1.35x); Kael LMB 8.47 against 12.95 (0.65x), combo 4.78 against 7.70 (0.62x) and 3.18 against 7.00 (0.45x). Bar 0.8 to 1.25. Source shares for Kael's hits (Brall's number over 1285 Base HP times our 154): slash 5.2, Slam 15.6, Lunge 7.1 to 10.1, Meteor 10.5, Spin 11.9, Rampage 2 along it with tip 4, Warchain 3.6. Vex's source rifle time is 2.48 s against our 5.47 s.
- **Cooldowns** (gap 10, owner): Vex RMB 6.5 (source 9, footage 5.4), R 42 (55); Kael air RMB 7.2 (9), R 36 (45).
- **Kael RMB into Shift turn limit** (patch 05.02.25): not built; `ext/kael-rmb-dash-turn` is no longer on origin.
- **Unsourced `[?]`**: Vex R range 14 (no clamp seen) and hold-slide length; Kael tether max 24 m, Warchain leash, Searing Wave charge walk 55%.
- **Failing checks on main, not touched here** (`--gunslinger-combo-check`, 4 of 167, identical with and without this branch): the RMB direct-hit body flash (0.00 against a lit time above 0.12 s), `air steer gunslinger` (Palm Lance recoil, carry 4.6 m/s), `Vex sounds` (the string's top-up reads no kit sounds) and `Vex cancel E recovery + any: no lock, as owner item 51 asks` (the kit holds her 0.6 s after the beam, `E_RECOVER` since `0ad0192a63` 11-11, and buffers a press in the last `Loco.press_buffer` since `f1a1b9473a` 11-16; the check, written 11-12, expects a jump, RMB and LMB within 0.1 s, so either the check or the hold is stale: owner call, docs follow the kit). `--juggernaut-combo-check`: 1 of 321 (`DASHFLOW` E on the first step after a dive landing).
- **Unmerged branches that touch these rows**: `ext/kael-lmb-press` (LMB press swings at once), `ext/kael-guard-edges` (guard edge asserts), `ext/kit-parity-tidy` (an older tidy of the same KIT_PARITY sections: expect a merge conflict in the hero sections and the ranges table).

### Not drift (checked and left)

- `docs/KIT_PARITY.md` still carries dated snapshot sections that name Burr Charge, Longneedle, "Zedran" and the 11-10 numbers (hit shapes 11-12, crowd control 11-09, knock table 11-19, casting speed 11-12, starter trio 11-10 with its gaps A to C). They are labelled with their date and were not rewritten; read the hero sections and this fragment as current. Gap A (Coin Blast and Palm Lance not on the branch) is closed by row 4 and 5.
- `docs/heroes/juggernaut.md` "Parity verify, Nov 9": its `kit:732`-style line numbers are Nov 9 line numbers of the kit files, not re-resolved.
- `docs/wiki/Rules.md` was out of date on main before this branch (data changes since its last write); regenerated here with `tools/gen_wiki.py`.

### Checks (this branch)

| Check | Main dae69e1c59 | This branch |
|---|---|---|
| `--kit-parity-check` | 0 failures | 0 failures |
| `--ttk-check` | 42 rows, 14 FAIL (Vex 4 and Kael 4 as in "Still open") | 42 rows, 14 FAIL, same rows and numbers (no data moved) |
| `--card-numbers-check` | not run on main (no card data differs) | 344 numbers, 0 failures |
| `--gunslinger-combo-check` | 167 checks, 4 failures (run with main's `gunslinger.json`) | 167 checks, the same 4 failures |
| `--juggernaut-combo-check` | not run on main (this branch changes no Kael data or code) | 321 checks, 1 failure (`DASHFLOW juggernaut e pressed on the first step after a dive landing`) |
| `python3 tools/health.py --strict` | red: style ratchet, 5 files worse than baseline | red, the same 5 files and numbers: `scripts/core/save.gd` long_line 9 -> 10, `scripts/heroes/warden_props.gd` long_line 0 -> 4, `tools/boss_check.gd` long_line 0 -> 88 / semicolon 0 -> 52 / nested_ternary 0 -> 1, `tools/checks/combat.gd` long_line 0 -> 4, `tools/checks/misc.gd` long_line 0 -> 1. NEW-RED 0; none is in a file this branch touches, so they are left for their authors |
| `python3 tools/gen_wiki.py --check` | red: `Rules.md` | OK (regenerated: `Class-Hired-Gun.md` for the card line, `Rules.md` for main's own drift) |
