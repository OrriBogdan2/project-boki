## Lace re-check on main c303669761 (2026-11-22, branch ext/parity-recheck-lace)

Every Lace row (LMB, RMB, E, dash, R, passive, cancels, dash-flow, ranges, CC, knock) was re-read on today's main against the source rows in `docs/heroes/archer.md` (Myth data `sv/briefs/kits.md:66-80`, footage `hero-ref/pin.md`) and the kit files: `content/archetypes/archer.json`, `content/weapons/longbow.json`, `content/dash_flow/archer.json`, `content/rules/{kit_parity,dash_feel}.json`, `scripts/arch/kits/archer_kit.gd`, `pin_*.gd`. The last full re-read was 11-12 (main 88b06b9e7); the diff of those data files since then is the drift list below.

DECISIONS 2026-11-22 (parity first, owner rows untouched):
- **Missed arrows linger: kept.** A spent arrow stays stuck in the ground at the cursor for 4 s (`PinFx.SPENT_T`; source: "arrows stay stuck in the ground after firing", `sv/briefs/kits.md:77`). Asserted (`pin vfx: the spent arrow stays stuck in the ground at the cursor`).
- **Hawk Sense kept as the mechanic.** The passive (foes under half health through cover, 22 m, outline in her colour) is the source's "vision of injured hunters"; only the display name became Red Thread (`f323334d1f`, 11-15). The class `HawkSense` and resource id `hawk` keep their names.
- **No Focus, no Deadeye.** Cut 2026-11-07 (`ffa20b0f7`); nothing in the data or footage has them. `archer.json` has no meter, no range bonus, no extra-hit field.

### Rows

| Slot | Source (Myth) | Ours today | Last checked | Verdict |
|---|---|---|---|---|
| LMB | Hold to charge, release; perfect release speeds the next draw | 15 tap / 30 at 0.6 s (range 12, at the cursor) / 60 at 1.15 s (range 16); overdraw 0.5 s x0.5; rate 0.5; quick draw x1.6; tap guard 0.08 s | same numbers | match; tap guard is ours (`8cc948ce6`) |
| RMB | Hold, release, knock, 35 dmg, wall stun up to 173 extra, 16 s | 16 to 30, wall x4.94, stun 1.2, push 8 to 12, hold move x0.38, cd 16, range 14 (+3 rank 3) | same | match; range 14 `[?]` (not determinable) |
| E | Cone, 61/s, slow, anti-heal, 15 s | tell 0.35, 4.4 s, 5 per tick, slow 35% for 0.8 s, blight, cd 15, reach 10.8, 120 deg | reach 9, tick 0.517 s | match; reach **moved** (drift 1), tick **fixed** (drift 2) |
| Dash | Roll to cursor, then Phase Walk, 9.5 s | roll 3.375 m / 0.27 s (felt 3.38 m in 0.386 s), walk 2.8 s x1.1, cd 9.5 | roll 3.0 | owner row (drift 3) |
| R | 3 empowered shots, no charge, first two 326, third 422, 60 s | press = first arrow, 2 more within 6 s, 1.0 s apart, 18 / 18 / 23.3, range 18, width 0.5, cd 60 | 18 / 18 / 25, nock 0.5 | match (drifts 4, 5) |
| Passive | Fog vision of injured; tall-ledge climb | Red Thread 22 m under 50% HP; `climb_tall`; no Focus, no Deadeye | Red Thread / Hawk Sense (duplicate rows) | match (drift 6) |
| Cancels | silent | `--clip-cancels-check` 0 failures; Lace cancel rows (LMB draw + E, X window + RMB / E) pass | same | match |
| Dash flow | silent (`[?]`) | 28 rows, 5 sourced (owner item 51 and the X rules), 23 `[?]`; `--dash-flow-check` 0 Lace failures | 17 rows | rows grew (drift 7); defaults stand |
| Ranges | RMB 14, E 10.8 floor, R 18 / 0.5, none fully seen | 14 (+3), 10.8, 18 / 0.5; LMB 12 / 16 | same | match; RMB and R range `[?]` |
| CC | Heartpiercer stun on terrace hit, Rain slow, Anti-Heal | wall stun 1.2 s, slow 35% 0.8 s refreshed, blight 1 s, X shred 10 armor | same | match; durations not in the source |
| Knock | RMB "knocks back"; bow and ult list none | Heavy push 8 to 12 = 2.52 to 5.12 m; bow and X `kb` 2.0 (nudge, under `Displace.KNOCK_MIN` 2.5) | bow 3.5, X 4 | match (drift 8) |
| Ranks | RMB -3 s x2 and +20% x2; E -2 s x2, +30% x2, tier IV arc +30%; Shift -1 s x2; R -5 s x2 | RMB 16 / 13 / 10, x1.2 / 1.4; E 15 / 13 / 9, x1.3 / 1.6, arc 120 / 156; Shift 9.5 / 8.5 / 7.5 | same | match for RMB, E and Shift; **R: superseded, see `1128-ult-rank-rows-reconcile.md`** (struck: ~~the source has -5 s x2 and +10% x2, X has no ranks, `ult-ranks a48ec55a0` is held~~; main has R ranks 2 and 3 for Lace since `555debe7d2`, 11-19, and this read was on a tree without them) |

### Drift since 11-12, with the commit that moved it

| # | Number | Was | Now | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | E reach | 9 | 10.8 | `4a8b5e8d71` (11-11) | footage floor, locked in `kit_parity.json` | none (parity); older KIT_PARITY rows still say 9 |
| 2 | E tick spacing | 31 frames, 0.517 s (the timer dropped the overshoot, gap C of the 11-10 trio check) | 30 frames, 0.5 s | **this branch**, `archer_kit.gd` `_tick_rain` | source says 0.5 s; +3% damage a second | fixed, asserted (`pin E: Hail Wall ticks every 0.5 s`) |
| 3 | Dash roll | 3.0 m / 0.27 s | 3.375 m / 0.27 s | `01291ba205` (11-11) | owner 11-11 "10-15% further" | owner row, left |
| 3b | Air flick | 4.2 m | 4.25 m / 0.329 s (x0.85 dist, x1.15 time) | `8f9e932522` (11-15) | no source; unsourced Shift moves keep the shared scale | none |
| 4 | R third arrow | 25 | 23.3 | `83386bb77c` (11-11) | source ratio 422 : 326 = 1.29x of 18, pinned in `kit_parity.json` | none (parity); `archer.md` still said 25: fixed in this branch |
| 5 | R nock | 0.5 s before the first beam | none, the press is the first arrow; `recover` 1.0 s between arrows | `a19ee5fd4c` (11-12, owner 11-08 items 18-20) | owner: the ult fires on the press | owner row, left |
| 6 | Passive name | Hawk Sense | Red Thread | `f323334d1f` (11-15) | display text only | none |
| 7 | Dash-flow rows | 17 | 28 (`dash_jump` 4, `air_cast` 4, `into_dash` rmb / e / x) | `ea91ecd095`, `9c81499251`, `b6838eaf17` (11-12 to 11-14) | new tables, all `[?]` with the kit default | none |
| 8 | Bow and X `kb` | 3.5 and 4 | 2.0 and 2.0 | `673b43e50b` (11-20) | cards list no knock; under `KNOCK_MIN` | none (parity) |
| 9 | Body | hit_r 0.392, size 1.01 | hit_r 0.408, hit_h 1.85, size 1.054 | `a8b4449e37` (11-15), `3a50a38abb` (11-18) | height chart (hurtbox parity, head tops) | none |

Not moved since 11-12 (re-read, same): LMB 15 / 30 / 60, 0.6 / 1.15 s, ranges 12 / 16; RMB 16 to 30, x4.94, stun 1.2, cd 16, hold 0.15, max hold 3.0; E dmg 5, every 0.5, slow 0.35, cd 15, width 1.8, tell 0.35, 4.4 s; Shift cd 9.5, walk 2.8 s, inside boost 0.33, ally radius 6; R cd 60, window 6, range 18, width 0.5, execute 12%, shred 10; ranks.

### A red check found and fixed

`--archer-combo-check` was red on main: `combo pin: Spirit Walk climbs a raised terrace wall and drops off the far side` (spirit x -1.7, y -2.36, not grounded). The fixture's flat strip ends 8 tiles west of her start (`archetype_check.gd setup`); the 3.375 m roll plus the drop carries her past the edge into the abyss, so she is falling at the end of the test. The kit is right (she stops at the map edge); the fixture was too close to it. The test now starts her 6 m east. The failure was not bisected to one commit: the roll lengthened on 11-11 (`01291ba205`) and the roll re-key landed 11-12 (`148818a544`).

### Checks (this branch)

| Check | Main c303669761 | This branch |
|---|---|---|
| `--archer-combo-check` | 233 checks, 1 failure | 234 checks, 0 failures |
| `--card-numbers-check` | 343, 0 failures | 343, 0 failures |
| `--kit-parity-check` | 0 failures | 0 failures |
| `--clip-cancels-check` | 0 failures | 0 failures |
| `--dash-flow-check` (archer rows) | 146 ok, 0 failed | 146 ok, 0 failed (2 other-hero failures: bulwark, rimewright) |
| `--move-feel-check` (archer rows) | felt dash 3.38 m / 0.386 s ok; `knock_lace_04_m` 4.242 vs 4.03 to 4.23 red | same; the knock target is stale, see "Knock distances" (push 12 rests at 5.12 m) |

Open, not Lace data: `--move-feel-check` is red on 14 rows, among them the walking brake (`ground_stop_dist` 0.429, all heroes) and `knock_lace_04_m`; the rest are other heroes. `python3 tools/health.py --strict` is red on main (style ratchet, files outside this task).

Rows in the Lace tables above this section (and the older Lace tables in this file) are a merge stack with superseded duplicates (roll 3 m, nock .3 or .5, 25 on the third arrow, Hawk Sense, "not ledges"). Read this section as current; `docs/heroes/archer.md` lost its superseded duplicate rows in the same branch.
