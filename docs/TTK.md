# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `sv/briefs/kits.md` (sv/briefs on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (28 of 38 rows today); that is the finding, not a flake. No number was tuned; the outliers are listed with their causes as suggestions.
PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `sv/briefs/kits.md` (sv/briefs on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (20 of 38 rows today); that is the finding, not a flake. Tuned so far: Sparkle's and Sable's damage (ext/parity-ttk-sparkle-sable-lace, pinned in content/rules/kit_parity.json); the other outliers are listed with their causes as suggestions. Rows of Hunters not tuned here moved since 11-09 with other changes on main.
PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `sv/briefs/kits.md` (sv/briefs on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (18 of 38 rows today); that is the finding, not a flake. Only Motley is tuned (below); the other outliers are listed with their causes as suggestions.

**Method**
- Target: full health and full armour. Ours 154 health (mean of the 12), armour 339 (x2.2) and the game's 20% reduction. Source 1285 Base HP (mean of the 12, sv/briefs/physics.md) and Common armour, 20% reduction (sv/DATA.md section 3). Both armours outlast the health, so only the 20% counts. Void, Oath and Shiv tooltips were read at level 15, so their source target is the level 15 mean (1285 + 14 x 77.1); a footage row read at level N faces the level N mean (1285 + (N - 1) x 77.1).
- (a) LMB only, held (taps for Kael and Albert, a 1.1 s draw for Lace). (b) Combo: every direct-damage non-ult ability the source has a number for, cast once at the start and again whenever its cooldown or charge is back, LMB between. Conditional bonuses (Dazed, Static, Ignite, Quickflip's empowered shot, sweet spots, stacks) are left out of the source side; ours runs live, so its passives count.
- Rank 0 is the unspent rank (slot_lv 1); max is rank 3 for ours and every listed upgrade for the source (a "x2" upgrade counts for both tiers it covers, charges included). LMB has no ranks, so (a) is the same at both.
- Source shots land at 0.00 s and every interval after; ours includes wind-ups, flight time and recoveries.
- Bar: ours / source time to knock inside 0.8 to 1.25. Below 1 means ours knocks faster. An outlier passes only with an owner override from DECISIONS in `OVERRIDES` (none yet: line 162, Motley "loses ~15% held-fire DPS, no compensation buff", explains 15% of a 1.9x gap, so it does not cover Motley).
- Gil has no source hero. His bar is the roster median: the median source time of the same row (LMB or combo, same rank) across the Hunters that have one. He gets no per-cast share rows. His combo varies by a few tenths of a second between runs, because the Grab Bag draws vary.
- Bar: ours / source time to knock inside 0.8 to 1.25. Below 1 means ours knocks faster. An outlier passes only with an owner override from DECISIONS in `OVERRIDES`, which names the damage share the owner gave up; a row then passes as override up to 1.25 / (1 - share). One today: Motley, DECISIONS 2026-11-06 (item 117, briefs/archive/OWNER_REVIEW_1103-2026-11-06.md) "loses ~15% held-fire DPS, no compensation buff", so up to 1.47.

**Footage LMB (Lace, Meeko, Tenzo, Grimble, Neve).** `sv/briefs/kits.md` has no LMB damage for these five, so their LMB row is read from the floating damage numbers in the hero-ref footage (origin/ext/hero-ref-footage, frames named below; trust order puts it under the tooltips, which have no number to beat it). The damage is the source's own number at the level the clip shows, against the mean Hunter at that level, the same conversion as the level 15 tooltips. Interval is the card cooldown where the hits agree with it, else the hit spacing in the footage.

| Hunter (source) | Clip, level | Hits read | Source LMB used | Interval |
|---|---|---|---|---|
| Lace (Myth) | pin 0207, 0215, 0224 (knock), 0242; level 9 | Supercharged 505, 505; overdrawn 263 | 505 per full draw (ours draws 1.1 s) | 1.7 s: hits 8 and 9 frames apart (Supercharged ready at 1.2-1.4 s plus the 0.5 s card) |
| Meeko (Elluna) | mooshmoosh 0084-0101; level 9 | 64, 66, ~75 (half hidden), 84, 93, 93, 93 | 64 rising 7.25 a hit, capped at 93 (+45%) | 0.4 s card (footage 2-3 frames, mean 0.57 s) |
| Tenzo (Tetra) | breah 0110, 0112, 0115, 0117; level about 18 (badge unreadable; max HP 2,6x1 against Tetra 1290 + 77.4 a level) | boulder 169 x4 | 169 per tap | 0.6 s card (footage 7 frames for 3, 0.58 s) |
| Grimble (Kingpin) | dredge 0062, 0066, 0073; level 9 | point-blank volleys split into 49 + 97 + 193 and 97 + 241: 338-339 each, 7 slugs of about 48 | 339 per volley (the 193 in the hero-ref sheet is one part) | 0.5 s card |
| Neve (Celeste) | tamsin 0061-0067; level 9 | 35 x8, then Shatter 520 (0069) | 35 per dart; Shatter left out (a stack bonus, method above) | 0.2 s: 8 darts in 7 frames |

Their abilities keep no source numbers here: the tooltips are level 1 (Tetra 15) and the LMB is level 9 (Tetra about 18), so no combo row mixes the two.

<!-- ttk:table -->
| Hunter (source) | Row | Ours s | Source s | Ours / source | Verdict |
|---|---|---|---|---|---|
| gunslinger (Ghost) | LMB rank 0 | 5.47 | 2.48 | 2.20 | FAIL |
| gunslinger (Ghost) | LMB rank max | 5.47 | 2.48 | 2.20 | FAIL |
| gunslinger (Ghost) | combo rank 0 | 2.72 | 1.92 | 1.41 | FAIL |
| gunslinger (Ghost) | combo rank max | 2.38 | 1.76 | 1.35 | FAIL |
| juggernaut (Brall) | LMB rank 0 | 8.47 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | LMB rank max | 8.47 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | combo rank 0 | 4.42 | 7.70 | 0.57 | FAIL |
| juggernaut (Brall) | combo rank max | 4.52 | 7.00 | 0.65 | FAIL |
| ashwick (Felix) | LMB rank 0 | 5.72 | 6.20 | 0.92 | ok |
| ashwick (Felix) | LMB rank max | 5.62 | 6.20 | 0.91 | ok |
| ashwick (Felix) | combo rank 0 | 3.93 | 4.30 | 0.91 | ok |
| ashwick (Felix) | combo rank max | 2.63 | 3.00 | 0.88 | ok |
| mage (Joule) | LMB rank 0 | 13.68 | 13.60 | 1.01 | ok |
| mage (Joule) | LMB rank max | 13.68 | 13.60 | 1.01 | ok |
| mage (Joule) | combo rank 0 | 8.13 | 9.00 | 0.90 | ok |
| mage (Joule) | combo rank max | 6.63 | 6.40 | 1.04 | ok |
| bulwark (Oath) | LMB rank 0 | 6.55 | 6.75 | 0.97 | ok |
| bulwark (Oath) | LMB rank max | 6.55 | 6.75 | 0.97 | ok |
| bulwark (Oath) | combo rank 0 | 5.92 | 5.85 | 1.01 | ok |
| bulwark (Oath) | combo rank max | 5.27 | 5.00 | 1.05 | ok |
| thief (Shiv) | LMB rank 0 | 4.70 | 4.95 | 0.95 | ok |
| thief (Shiv) | LMB rank max | 4.70 | 4.95 | 0.95 | ok |
| thief (Shiv) | combo rank 0 | 4.23 | 4.95 | 0.86 | ok |
| thief (Shiv) | combo rank max | 4.23 | 4.95 | 0.86 | ok |
| ostra (Void) | LMB rank 0 | 7.23 | 6.60 | 1.10 | ok |
| ostra (Void) | LMB rank max | 7.23 | 6.60 | 1.10 | ok |
| ostra (Void) | combo rank 0 | 5.43 | 4.80 | 1.13 | ok |
| ostra (Void) | combo rank max | 4.83 | 4.80 | 1.01 | ok |
| archer (Myth) | LMB rank 0 | 7.83 | 6.80 | 1.15 | ok |
| archer (Myth) | LMB rank max | 7.83 | 6.80 | 1.15 | ok |
| tender (Elluna) | LMB rank 0 | 7.12 | 10.40 | 0.68 | FAIL |
| tender (Elluna) | LMB rank max | 7.12 | 10.40 | 0.68 | FAIL |
| dolm (Tetra) | LMB rank 0 | 13.48 | 11.40 | 1.18 | ok |
| dolm (Tetra) | LMB rank max | 13.48 | 11.40 | 1.18 | ok |
| dredge (Kingpin) | LMB rank 0 | 6.85 | 3.50 | 1.96 | FAIL |
| dredge (Kingpin) | LMB rank max | 6.85 | 3.50 | 1.96 | FAIL |
| rimewright (Celeste) | LMB rank 0 | 3.35 | 13.40 | 0.25 | FAIL |
| rimewright (Celeste) | LMB rank max | 3.35 | 13.40 | 0.25 | FAIL |
| gil (roster median) | LMB rank 0 | 6.43 | 6.78 | 0.95 | ok |
| gil (roster median) | LMB rank max | 6.43 | 6.78 | 0.95 | ok |
| gil (roster median) | combo rank 0 | 5.28 | 4.95 | 1.07 | ok |
| gil (roster median) | combo rank max | 4.95 | 4.95 | 1.00 | ok |

| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source | Bar |
|---|---|---|---|---|---|
| gunslinger (Ghost) | rmb | 0.143 | 0.128 | 1.11 | ok |
| gunslinger (Ghost) | e | 0.156 | 0.157 | 0.99 | ok |
| juggernaut (Brall) | rmb | 0.169 | 0.101 | 1.67 | out |
| juggernaut (Brall) | dash | 0.058 | 0.038 | 1.53 | out |
| juggernaut (Brall) | e | 0.039 | 0.023 | 1.67 | out |
| ashwick (Felix) | rmb | 0.094 | 0.082 | 1.14 | ok |
| ashwick (Felix) | dash | 0.117 | 0.117 | 1.00 | ok |
| ashwick (Felix) | e | 0.058 | 0.060 | 0.98 | ok |
| mage (Joule) | rmb | 0.104 | 0.104 | 1.00 | ok |
| mage (Joule) | dash | 0.119 | 0.119 | 1.00 | ok |
| mage (Joule) | e | 0.126 | 0.126 | 1.00 | ok |
| bulwark (Oath) | dash | 0.156 | 0.154 | 1.01 | ok |
| thief (Shiv) | rmb | 0.019 | 0.019 | 1.00 | ok |
| ostra (Void) | rmb | 0.117 | 0.117 | 1.00 | ok |
| ostra (Void) | e | 0.172 | 0.154 | 1.11 | ok |
| rimewright (Celeste) | rmb | 0.260 | 0.269 | 0.96 | ok |
| rimewright (Celeste) | x | 0.299 | 0.121 | 2.48 | out |
| archer (Myth) | rmb | 0.195 | 0.027 | 7.15 | out |
| archer (Myth) | e | 0.130 | 0.095 | 1.37 | out |
| archer (Myth) | x | 0.385 | 0.836 | 0.46 | out |
| tender (Elluna) | rmb | 0.058 | 0.038 | 1.53 | out |
| dredge (Kingpin) | e | 0.162 | 0.205 | 0.79 | out |
<!-- ttk:table -->

**11-11 slice (ext/ttk-slice-1111, run 2026-11-11 on worker rpc1).** The owner-direct 11-11 kit branches were run one by one and merged together (scratch: origin/main 88b06b9e7 + ext/kael-owner-1111 4cb48148d + ext/lace-1111 cf1adae16 + ext/vex-rmb-1111 a796f3a38 + ext/albert-hold-cinder-orb 4cf2f22b4; the first two carry ext/release-integ-0245 272368589, also run on its own). All seven runs print the same 54 lines: **none of the four branches moves a TTK row.** They change shapes, timing and visuals but no damage, cooldown or cadence the idle-target fight reads (Kael: slam lane 4.3 x 0.72 m instead of the 70 deg cone, the Chain Lunge and its 1.25x chain Smash removed; Lace: Heavy Shot from the bow mouth, roll 3.0 -> 3.375; Vex: Burr Charge no longer procs in the air; Cinder: the pilot flame only while the lance spools up). The table above is therefore what origin/main writes today; the rows that differ from 11-09 are main drift (Kael, Sparkle and Albert combos, Cinder LMB max), not these branches.

| Hunter (source) | Branch | Row | 11-09 doc | origin/main | branch alone | all four merged | Source s (sv/briefs/kits.md) |
|---|---|---|---|---|---|---|---|
| Kael (Brall) | kael-owner-1111 | LMB rank 0 / max | 8.45 s, 0.65 | 8.45 s, 0.65 | 8.45 s, 0.65 | 8.45 s, 0.65 | 12.95 (Caldera tap 43 / 0.35 s) |
| Kael (Brall) | kael-owner-1111 | combo rank 0 | 3.48 s, 0.45 | 4.22 s, 0.55 | 4.22 s, 0.55 | 4.22 s, 0.55 | 7.70 (+ Execution Slam 130 / 2.5 s, Flame Step 49 / 13 s x2, Feysteel Chain 30 / 16 s) |
| Kael (Brall) | kael-owner-1111 | combo rank max | 1.15 s, 0.16 | 4.15 s, 0.59 | 4.15 s, 0.59 | 4.15 s, 0.59 | 7.00 (+40% slam, Flame Step 8 s x3, chain 10 s) |
| Kael (Brall) | kael-owner-1111 | Rampage share | 0.175, 4.60 | 0.058, 1.53 | 0.058, 1.53 | 0.058, 1.53 | 0.038 (Flame Step 49) |
| Lace (Myth) | lace-1111 | LMB rank 0 / max | 7.83 s, n/a | 7.83 s, n/a | 7.83 s, n/a | 7.83 s, n/a | none: Greenwood Bow has no damage number |
| Vex (Ghost) | vex-rmb-1111 | LMB rank 0 / max | 8.07 s, 3.25 | 8.07 s, 3.25 | 8.07 s, 3.25 | 8.07 s, 3.25 | 2.48 (MK7 51 / 0.08 s) |
| Vex (Ghost) | vex-rmb-1111 | combo rank 0 | 1.77 s, 0.92 | 1.77 s, 0.92 | 1.77 s, 0.92 | 1.77 s, 0.92 | 1.92 (+ Spike Grenade 165 / 9 s, Railgun 202 / 12 s) |
| Vex (Ghost) | vex-rmb-1111 | combo rank max | 1.37 s, 0.78 | 1.37 s, 0.78 | 1.37 s, 0.78 | 1.37 s, 0.78 | 1.76 (grenade 6 s, Railgun +40%) |
| Cinder (Felix) | albert-hold-cinder-orb | LMB rank 0 | 4.87 s, 0.78 | 4.87 s, 0.78 | 4.87 s, 0.78 | 4.87 s, 0.78 | 6.20 (Flamethrower 258 dmg/s) |
| Cinder (Felix) | albert-hold-cinder-orb | LMB rank max | 4.72 s, 0.76 | 4.62 s, 0.74 | 4.62 s, 0.74 | 4.62 s, 0.74 | 6.20 |
| Cinder (Felix) | albert-hold-cinder-orb | combo rank 0 | 3.03 s, 0.76 | 3.03 s, 0.76 | 3.03 s, 0.76 | 3.03 s, 0.76 | 4.00 (+ Embry Bolt 106 / 9 s, Pyro Pounce 190.4 / 9 s x2 (the check reads 150.4 + the 40 base-dmg upgrade at both ranks), Heat Shield 76.8 / 13 s) |
| Cinder (Felix) | albert-hold-cinder-orb | combo rank max | 1.83 s, 0.61 | 1.83 s, 0.61 | 1.83 s, 0.61 | 1.83 s, 0.61 | 3.00 |
| Albert (Oath) | albert-hold-cinder-orb | combo rank 0 / max | 0.70 / 0.73 | 0.70 / 0.84 | 0.70 / 0.84 | 0.70 / 0.84 | 5.85 / 5.00 (Spin Dash 364) |

Out of the bar after the slice, each with the number that puts it there: **Kael** LMB 0.65, Slash 8 = 5.2% of our target against Caldera 43 = 3.3%; combo 0.55 / 0.59, Smash 26 = 16.9% against Execution Slam 130 = 10.1% (1.67x) and Warchain 8 against Feysteel Chain 30 (2.23x). The move from 0.45 / 0.16 is Rampage 0.175 -> 0.058 (tip 18 no longer lands; source Flame Step 49 = 0.038). **Vex** LMB 3.25, our 0.12 s cadence with `sustain_loss` 0.5 against MK7 51 every 0.08 s; combo max 0.78, Railgun share 0.234 against 202 = 0.157 (1.49x). **Cinder** LMB 0.78 / 0.74, stream 25.6% of the target a second against Flamethrower 258/s = 20.1%; combo 0.76 / 0.61, Cinder Shot 0.131 against Embry Bolt 106 = 0.082 (1.59x). **Lace** has no source row (Greenwood Bow has no damage number in sv/briefs/kits.md). No kit was tuned in this job.

**11-19 re-run on current main (ext/ttk-main-1116, origin/main d254692c3f; no number changed).** Kits, ranks, armour tiers and cooldowns moved since the 11-11 slice, so both checks were run again.

*`--ttk-check`*: 42 rows, 14 FAIL, 28 ok. The table between the `ttk:table` markers above is what main prints today: every row is identical to the 11-11 table (to the hundredth), except Gil's two combo rows (5.28 / 4.95 s in the doc, 4.95 / 4.62 s now; his Grab Bag draws vary, see Method). So for Vex, Kael, Lace and Cinder the delta against 11-11 is **0.00 on every row**; the later kit, rank, armour and cooldown merges did not move the idle-target fight.

*`--ttk-matrix-check`* needed two tool changes first (tools/ttk_matrix_check.gd, no game file): (1) it failed 12 of 156 checks on main, because Lace's bow looses nothing on a held or mashed click since 8cc948ce6e (`draw_min`), so hold and tap never down the dummy; a **draw** mode (hold 1.2 s, release one step, only for weapons with a `draw` table) now measures her. (2) New optional args `--ttk-matrix-set=<arch,arch>`, `--ttk-matrix-level=N` (both sides at level N: `LevelGrowth` health +6% of base a level, ability power) and `--ttk-matrix-armor=none|tierN` (the dummy's `ArmorRules` tier N; tier 2 = Rare, 30% block, 350 durability; the base run is tier 0 Common, 20%). Without them the output is the old one. `tools/ttk_pairs.py` builds the tables below from the logs. Base run: 156 checks, 0 failures with the draw mode. Seconds to down; `~` = Kael measured at 2.7 m (a melee tap cannot reach 8 m). "Doc 11-11" is docs/TTK_MATRIX.md, last generated 11-10 and not re-run since; the delta is main drift since then (the four 11-11 branches move no TTK row, see above), and is not isolated per commit here. Lace has no source number, so no source seconds and no bar for her as attacker.

| Pair (attacker into defender) | Doc 11-11, L1 Common | Now, L1 Common | Delta | L1 none | L1 tier 2 | L6 none | L6 tier 2 |
|---|---|---|---|---|---|---|---|
| Vex into Vex | 7.6 | 5.2 | -2.4 | 4.2 | 6.0 | 5.4 | 8.2 |
| Vex into Kael | 10.7 | 7.6 | -3.1 | 5.5 | 8.4 | 7.8 | 11.3 |
| Vex into Lace | n/a | 4.5 | n/a | 3.9 | 5.1 | 4.6 | 7.4 |
| Vex into Cinder | 10.2 | 7.6 | -2.6 | 5.5 | 8.4 | 7.8 | 11.3 |
| Kael into Vex | 8.7 | 5.5 | -3.2 | 4.3~ | 6.3~ | 5.5~ | 7.9~ |
| Kael into Kael | 11.5 | 6.7 | -4.8 | 5.1~ | 7.5~ | 7.1~ | 10.3~ |
| Kael into Lace | n/a | 3.9 | n/a | 3.5~ | 4.7~ | 4.3~ | 6.3~ |
| Kael into Cinder | 10.7 | 6.7 | -4.0 | 5.1~ | 7.9~ | 7.1~ | 9.9~ |
| Lace into Vex | n/a | 7.4 | n/a | 5.0 | 7.4 | 7.4 | 9.8 |
| Lace into Kael | n/a | 9.8 | n/a | 7.4 | 11.1 | 9.8 | 13.5 |
| Lace into Lace | n/a | 6.2 | n/a | 5.0 | 6.2 | 6.2 | 8.6 |
| Lace into Cinder | n/a | 9.8 | n/a | 7.4 | 11.1 | 9.8 | 13.5 |
| Cinder into Vex | 5.0 | 5.8 | +0.8 | 4.9 | 6.5 | 5.9 | 8.0 |
| Cinder into Kael | 5.4 | 7.2 | +1.8 | 5.9 | 8.0 | 7.2 | 9.8 |
| Cinder into Lace | n/a | 5.0 | n/a | 4.2 | 5.5 | 5.1 | 6.8 |
| Cinder into Cinder | 5.2 | 7.2 | +2.0 | 6.0 | 8.0 | 7.2 | 9.8 |

Ours / source time to down (bar 0.8 to 1.25). The source side is its base HP (sv/briefs/physics.md, +6% of base a level) over 1 - block (none 0, Common 0.2, tier 2 0.3) over the LMB DPS in `tools/ttk_matrix_source.json` (Vex 51 / 0.08 s, Kael 43 / 0.2 s, Cinder 258/s); Lace has none.

| Pair | L1 none ours / source = ratio | L1 tier 2 ours / source = ratio | L6 none ours / source = ratio | L6 tier 2 ours / source = ratio |
|---|---|---|---|---|
| Vex into Vex | 4.2 / 1.9 = 2.20 **out** | 6.0 / 2.7 = 2.17 **out** | 5.4 / 2.5 = 2.15 **out** | 8.2 / 3.6 = 2.31 **out** |
| Vex into Kael | 5.5 / 2.0 = 2.74 **out** | 8.4 / 2.9 = 2.91 **out** | 7.8 / 2.6 = 2.95 **out** | 11.3 / 3.8 = 3.00 **out** |
| Vex into Lace | 3.9 / 1.7 = 2.25 **out** | 5.1 / 2.5 = 2.08 **out** | 4.6 / 2.2 = 2.06 **out** | 7.4 / 3.2 = 2.32 **out** |
| Vex into Cinder | 5.5 / 2.0 = 2.74 **out** | 8.4 / 2.9 = 2.91 **out** | 7.8 / 2.6 = 2.95 **out** | 11.3 / 3.8 = 3.00 **out** |
| Kael into Vex | 4.3 / 5.7 = 0.76 **out** | 6.3 / 8.1 = 0.78 **out** | 5.5 / 7.4 = 0.75 **out** | 7.9 / 10.6 = 0.75 **out** |
| Kael into Kael | 5.1 / 6.0 = 0.85 | 7.5 / 8.6 = 0.88 | 7.1 / 7.8 = 0.91 | 10.3 / 11.1 = 0.93 |
| Kael into Lace | 3.5 / 5.1 = 0.69 **out** | 4.7 / 7.3 = 0.65 **out** | 4.3 / 6.7 = 0.65 **out** | 6.3 / 9.5 = 0.67 **out** |
| Kael into Cinder | 5.1 / 6.0 = 0.85 | 7.9 / 8.6 = 0.93 | 7.1 / 7.8 = 0.91 | 9.9 / 11.1 = 0.89 |
| Cinder into Vex | 4.9 / 4.7 = 1.04 | 6.5 / 6.8 = 0.96 | 5.9 / 6.2 = 0.96 | 8.0 / 8.8 = 0.91 |
| Cinder into Kael | 5.9 / 5.0 = 1.18 | 8.0 / 7.1 = 1.12 | 7.2 / 6.5 = 1.11 | 9.8 / 9.3 = 1.05 |
| Cinder into Lace | 4.2 / 4.3 = 0.99 | 5.5 / 6.1 = 0.91 | 5.1 / 5.5 = 0.92 | 6.8 / 7.9 = 0.86 |
| Cinder into Cinder | 6.0 / 5.0 = 1.20 | 8.0 / 7.1 = 1.12 | 7.2 / 6.5 = 1.11 | 9.8 / 9.3 = 1.06 |


**Owner calls from the 11-19 table (listed, nothing built).**
- Vex into all four (2.06 to 3.00 in all four settings; ttk-check LMB 2.20, combo 1.41 / 1.35): the LMB, which has no rank. Per round the damage share matches (6 of 154 = 3.9%, 51 of 1285 = 4.0%); ours fires every 0.12 s against about 0.08 s (cadence is [F], not [D]) and `sustain_loss` 0.5 halves every round after the tenth. His abilities are in the bar (Spike Grenade 1.11, Railgun 0.99), so the combo miss is the LMB. Owner call: cadence 0.12 -> 0.08 and sustain_loss, or accept the gap.
- Kael into Vex (0.75 to 0.78) and into Lace (0.65 to 0.69): not an ability and not his rank. Kael into Kael and into Cinder is inside the bar (0.85 to 0.93). The cause is the defender's health: ours is 124 / 145 / 193 (light / medium / heavy, 0.64 / 0.75 / 1.00 of a heavy), the source's 1100 / 1225 / 1290 (0.85 / 0.95 / 1.00), so every attacker is relatively faster into a light or medium Hunter. Owner call: the class health spread (KIT_PARITY Health), not Kael's Slash. His own ttk-check rows stay out of the bar: LMB 0.65 (Slash 8 against Caldera 43); combo 0.57 / 0.65 (RMB Smash 1.67x at rank 1, Rampage dash 1.53x, Warchain E 1.67x).
- Lace as attacker: no pairing verdict (Greenwood Bow has no damage number in sv/briefs/kits.md); her ttk-check LMB is inside (1.15), but her RMB row reads 7.15x because the check taps RMB and never looses the held Heavy Shot (a measurement gap), E 1.37x, X 0.46x. Owner call: supply her LMB number, and say whether the RMB row should hold and release.
- Cinder: inside the bar at all 16 cell-settings with 0.86 to 1.20; the high edge is into the heavy Kael and Cinder at level 1 with no armour (1.18, 1.20) and the low edge into Lace at level 6 with tier 2 (0.86). No call.
- Level and armour do not change a verdict: every pair keeps the same side of the bar at level 1 and 6, with no armour and with tier 2 (Vex 2.06 to 3.00, Kael into Vex / Lace 0.65 to 0.78, the rest inside). Tier 2 and level 6 lengthen ours and the source in proportion, because both sides take the same block and the same +6% health a level.
- docs/TTK_MATRIX.md (the 12 x 12 table) still shows the pre-11-11 numbers and has no Lace row; regenerating it needs the full 12-attacker log (about 12 minutes). Owner call: regenerate it in a follow-up.

**Outliers and causes (suggestions, nothing built)**

| Hunter | Rows | Cause | Suggestion |
|---|---|---|---|
| Vex (Ghost) | LMB 3.25x slow; combo max 0.78 | Per round the shares match (6 of 154 = 3.9%, 51 of 1285 = 4.0%), but ours fires every 0.12 s (wiki and weapon sheet say 0.08 s; our 5 fps footage says about 0.14 s) and `sustain_loss` 0.5 halves every round after the tenth, where the source's first 10 rounds are the extra ones and rounds 11 to 30 stay at base. Our grenade matches (1.11x), the E beam is 1.49x. | Drop `sustain_loss` so rounds 11+ keep full damage and the first 10 get a bonus; settle 0.08 vs 0.12 s from footage first. |
| Cinder (Felix) | LMB 0.78, 0.76; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | combo 0.30, 0.20 (LMB 1.00 and every ability 1.00) | Traced 11-12 at rank 0: the Rod's orb gives the Wirerun back at 1.17 s, and the run at 1.27 s goes through a full-Static target, so it hits double and Blowouts: 64 of 154 health in one pass, 42% of the knock. With the orb off: 0.90 / 1.03. The source has the same loop but no number for its payoff, and the source side leaves the loop out. A loop modelled with our payoff as a stand-in would be circular, and since source casts land at once it pushes max rank to about 1.7. Every slot is at the source share, so no data change. | Owner: a number for the source payoff, or an override for these two rows. |
| Albert (Oath) | LMB 0.73; combo 0.71, 0.73 | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Meeko (Elluna) | LMB 0.68 | Lantern 8 is 5.2% of our target every 0.4 s against 64 of 1902 = 3.4% (rising to 4.9% at 93); our Kindle ramp runs on top. | Lantern 8 -> about 5 (64 / 1902 x 154 = 5.2), ramp capped at +45% like the source. |
| Grimble (Kingpin) | LMB 2.70 | A full volley is 7 x 2 = 14 = 9.1% of our target against 339 of 1902 = 17.8% (0.51x), and ours takes 9.4 s where 14 full volleys at 0.5 s (192.5 raw after the 20%) would be 6.5 s, so not every pellet lands at 1.5 m (`pellet_floor` 0.457). | Pellet 2 -> about 3.9 (339 / 7 / 1902 x 154), then check how many pellets land point-blank. |
| Neve (Celeste) | LMB 0.22 | Dart 4 is 2.6% every 0.18 s against 35 of 1902 = 1.8% every 0.2 s (1.6x), and our live Shatter (60 = 39% of the target every 8 darts) counts while the source side leaves it out. Without Shatter ours would be about 8.6 s (48 darts), ratio about 0.64. | Dart 4 -> about 2.8 (35 / 1902 x 154); decide whether the check should count Shatter on both sides (the source pops 520 = 27% of 1902 every 8 darts). |
| Kael (Brall) | LMB 0.65; combo 0.55 and 0.59 | Slash 8 is 5.2% of our target against 43 = 3.3% (1.56x, cadence 0.34 vs 0.35 s matches). Rampage now lands only its pass hit 9 = 5.8% against Flame Step 49 = 3.8% (1.53x; the tip 18 misses a target 1.5 m ahead since main moved on from 11-09, data unchanged); Warchain 5.2% vs 2.3% (2.2x); Smash 16.9% vs 10.1% (1.67x). Max rank adds +40% Smash and a shorter dash recharge on top. | Slash 8 -> 5, Rampage hit 9 / tip 18 -> about 2 / 4 (the tip doubling is ours), Warchain hit 8 -> 3.6, Smash 26 -> 15. |
| Sparkle (Joule) | LMB 0.77; combo 0.17, 0.20 (were 0.81, 0.64 on 11-09) | Bolt 12 every 0.648 s is 12.0% a second against 90 every 0.8 s = 8.8% (1.37x); the owner set 0.648 s (items 70 and 116 in docs/heroes/mage.md, not in DECISIONS). Abilities are at parity per cast (1.03 to 1.13x), yet the combo now knocks in 1.53 / 1.27 s against 9.00 / 6.40: something outside the three casts (main drift since 11-09, not found here) adds most of the damage. | Bolt 12 -> 9 keeps 0.648 s (owner) at parity; ask the owner whether item 116 covers the damage. |
| Albert (Oath) | LMB 0.72; combo 0.70 (max 0.84 is now inside) | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Gil (roster median) | before 11-12: LMB 1.32; combo 1.38, 1.23 | Damage per hit: the swordfish chain 7 / 7 / 11 at 0.32 s was 26 a second raw, too little for a held melee chain. The cadence and chain shape were fine. | Done 11-12: chain x1.3 to 9.2 / 9.2 / 14.5. LMB 0.97, combo 1.10 to 1.15 and 1.02 to 1.08 (two runs). |
| Motley (Void) | LMB 1.91; combo 2.15, 1.74 | Orb 9 is 5.8% of the target against 263 of 2365 = 11.1% (0.53x). Spear 0.53x, bomb 0.59x. The whole kit sits about half the source. Held fire never charges (owner item 60, DECISIONS line 162 -15%). | Orb 9 -> 17, spear x1.9, bomb x1.7. |

Within the bar: Cinder at every row (0.88 to 0.92), Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Oath combo rank max (0.84), Lace (1.15) and Tenzo (1.17; at level 19 instead of 18 the source is about 0.6 s slower, still inside). The ours side of Kael, Sparkle and Oath combo rows moved with main since the last write (Sparkle combo rank 0 0.81 -> 0.17, Kael combo 0.45 -> 0.55); the causes above were written against the older numbers.

**Cinder and Neve (set from the source).** Direct damage is the source's tooltip x 154/1285 (our / source mean Hunter health): Flamethrower 258/s -> 31/s, Embry Bolt 106 -> 13, Pyro Pounce 150.4 (+40 at tier IV; this table used to read 190.4 at rank 0) -> 18 (+5), Heat Shield 76.8 -> 9; the Flue Flight carpet stays 4.5/s (owner burst cap, SERVER_UPDATE6; the source's 239.2/s would be 28.7). With only that, Cinder knocked at 0.54 to 0.71: the whole gap was our Flashover numbers (burn, stream bonus and health chip), which the source has no number for and this table leaves out on its side (with them at zero every row was 1.05 to 1.11). They are now a quarter of what they were (burn 0.5% / 1% a second, +6% / +10%, chip 0.4% / 0.6%), which puts every row at about 0.9. Neve: detonation 22 = 190/156 x hit 18, Rimelock 18 = 155/156 x 18.
Within the bar: Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Albert combo rank max (0.84).
Within the bar: Gil (roster median, since 11-12), Sable at both ranks (0.85 to 0.95; Bola now 3 / +6.1, the source's share), Sparkle LMB (1.00), Vex combo rank 0, Albert combo max.

**Not done here:** no tuning; Lace, Meeko, Tenzo, Grimble and Neve have footage LMB rows only, no combo rows (their ability tooltips are a different level from the footage).
**Lace (Myth), shares of the target with no LMB anchor** (source level 1 against 1285, ours against 154; not tuned, no check row: the check's RMB tap does not loose her held Heavy Shot): Heavy Shot 16 to 30 is 10.4 to 19.5% against Heartpiercer 35 = 2.7% (3.8 to 7.1x), its wall hit +79 to +148 against +173 = 13.5% (3.8 to 7.1x); Hail Wall 10 a second is 6.5% against Rain of Arrows 61 = 4.7% a second (1.37x); Starpiercer 18 / 18 / 23.3 is 11.7 / 11.7 / 15.1% against 326 / 326 / 422 = 25.4 / 25.4 / 32.8% (0.46x). The third beam keeps the source's 422 : 326 = 1.29x (25 -> 23.3). At the source's shares: Heavy Shot about 4.2, wall +20.7, Hail Wall 3.7 a tick, Starpiercer 39 / 50.6.
| Motley (Void) | was LMB 1.91; combo 2.15, 1.74; now 1.09; 1.13, 1.00 | Orb 9 was 5.8% of the target against 263 of 2365 = 11.1%; Snap and seed about half the source. | Done (ext/parity-ttk-motley): orb 9 -> 14.5 (the source's 17.1 share less the owner's ~15%, item 117), Snap 9.5 -> 18 and seed 12.5 -> 23.7 (source shares, hit 1.00x and 1.11x), seed burn 8.2 -> 16.2 (250 vs 365). The 0.6 s cadence, the charge to 1.4 s, the +34% full orb, Swollen +44% and the 3.5x peak are unchanged. |

Within the bar: Motley at both ranks (1.00 to 1.13), Sable at both ranks, Vex combo rank 0, Albert combo rank max (0.84). The Kael, Sparkle and Albert causes above predate main's later kit merges (the 2026-11-11 table moved Kael's combo to 0.55 and 0.59, Sparkle's to 0.17 and 0.20); re-read them before tuning.

**Not done here:** no tuning past Sparkle and Sable; the five Hunters with no LMB number (and their combos) need the source's LMB damage, which no file in briefs has.
