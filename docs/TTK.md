# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `supervive_kits.md` (briefs/supervive-data on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (28 of 38 rows today); that is the finding, not a flake. No number was tuned; the outliers are listed with their causes as suggestions.

**Method**
- Target: full health and full armour. Ours 154 health (mean of the 12), armour 339 (x2.2) and the game's 20% reduction. Source 1285 Base HP (mean of the 12, supervive_physics.md) and Common armour, 20% reduction (docs/SUPERVIVE_DATA.md section 3). Both armours outlast the health, so only the 20% counts. Void, Oath and Shiv tooltips were read at level 15, so their source target is the level 15 mean (1285 + 14 x 77.1); a footage row read at level N faces the level N mean (1285 + (N - 1) x 77.1).
- (a) LMB only, held (taps for Kael and Albert, a 1.1 s draw for Lace). (b) Combo: every direct-damage non-ult ability the source has a number for, cast once at the start and again whenever its cooldown or charge is back, LMB between. Conditional bonuses (Dazed, Static, Ignite, Quickflip's empowered shot, sweet spots, stacks) are left out of the source side; ours runs live, so its passives count.
- Rank 0 is the unspent rank (slot_lv 1); max is rank 3 for ours and every listed upgrade for the source (a "x2" upgrade counts for both tiers it covers, charges included). LMB has no ranks, so (a) is the same at both.
- Source shots land at 0.00 s and every interval after; ours includes wind-ups, flight time and recoveries.
- Bar: ours / source time to knock inside 0.8 to 1.25. Below 1 means ours knocks faster. An outlier passes only with an owner override from DECISIONS in `OVERRIDES` (none yet: line 162, Motley "loses ~15% held-fire DPS, no compensation buff", explains 15% of a 1.9x gap, so it does not cover Motley).

**Footage LMB (Lace, Meeko, Tenzo, Grimble, Neve).** `supervive_kits.md` has no LMB damage for these five, so their LMB row is read from the floating damage numbers in the hero-ref footage (origin/ext/hero-ref-footage, frames named below; trust order puts it under the tooltips, which have no number to beat it). The damage is the source's own number at the level the clip shows, against the mean Hunter at that level, the same conversion as the level 15 tooltips. Interval is the card cooldown where the hits agree with it, else the hit spacing in the footage.

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
| gunslinger (Ghost) | combo rank 0 | 2.20 | 1.92 | 1.15 | ok |
| gunslinger (Ghost) | combo rank max | 1.87 | 1.76 | 1.06 | ok |
| juggernaut (Brall) | LMB rank 0 | 8.45 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | LMB rank max | 8.45 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | combo rank 0 | 4.22 | 7.70 | 0.55 | FAIL |
| juggernaut (Brall) | combo rank max | 4.15 | 7.00 | 0.59 | FAIL |
| ashwick (Felix) | LMB rank 0 | 4.87 | 6.20 | 0.78 | FAIL |
| ashwick (Felix) | LMB rank max | 4.62 | 6.20 | 0.74 | FAIL |
| ashwick (Felix) | combo rank 0 | 3.03 | 4.00 | 0.76 | FAIL |
| ashwick (Felix) | combo rank max | 1.83 | 3.00 | 0.61 | FAIL |
| mage (Joule) | LMB rank 0 | 10.42 | 13.60 | 0.77 | FAIL |
| mage (Joule) | LMB rank max | 10.42 | 13.60 | 0.77 | FAIL |
| mage (Joule) | combo rank 0 | 1.53 | 9.00 | 0.17 | FAIL |
| mage (Joule) | combo rank max | 1.27 | 6.40 | 0.20 | FAIL |
| bulwark (Oath) | LMB rank 0 | 4.88 | 6.75 | 0.72 | FAIL |
| bulwark (Oath) | LMB rank max | 4.88 | 6.75 | 0.72 | FAIL |
| bulwark (Oath) | combo rank 0 | 4.08 | 5.85 | 0.70 | FAIL |
| bulwark (Oath) | combo rank max | 4.18 | 5.00 | 0.84 | ok |
| thief (Shiv) | LMB rank 0 | 4.68 | 4.95 | 0.95 | ok |
| thief (Shiv) | LMB rank max | 4.68 | 4.95 | 0.95 | ok |
| thief (Shiv) | combo rank 0 | 4.22 | 4.95 | 0.85 | ok |
| thief (Shiv) | combo rank max | 4.22 | 4.95 | 0.85 | ok |
| ostra (Void) | LMB rank 0 | 12.62 | 6.60 | 1.91 | FAIL |
| ostra (Void) | LMB rank max | 12.62 | 6.60 | 1.91 | FAIL |
| ostra (Void) | combo rank 0 | 10.33 | 4.80 | 2.15 | FAIL |
| ostra (Void) | combo rank max | 8.37 | 4.80 | 1.74 | FAIL |
| archer (Myth) | LMB rank 0 | 7.83 | 6.80 | 1.15 | ok |
| archer (Myth) | LMB rank max | 7.83 | 6.80 | 1.15 | ok |
| tender (Elluna) | LMB rank 0 | 7.10 | 10.40 | 0.68 | FAIL |
| tender (Elluna) | LMB rank max | 7.10 | 10.40 | 0.68 | FAIL |
| dolm (Tetra) | LMB rank 0 | 13.30 | 11.40 | 1.17 | ok |
| dolm (Tetra) | LMB rank max | 13.30 | 11.40 | 1.17 | ok |
| dredge (Kingpin) | LMB rank 0 | 9.43 | 3.50 | 2.70 | FAIL |
| dredge (Kingpin) | LMB rank max | 9.43 | 3.50 | 2.70 | FAIL |
| rimewright (Celeste) | LMB rank 0 | 2.93 | 13.40 | 0.22 | FAIL |
| rimewright (Celeste) | LMB rank max | 2.93 | 13.40 | 0.22 | FAIL |

| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source |
|---|---|---|---|---|
| gunslinger (Ghost) | rmb | 0.143 | 0.128 | 1.11 |
| gunslinger (Ghost) | e | 0.156 | 0.157 | 0.99 |
| juggernaut (Brall) | rmb | 0.169 | 0.101 | 1.67 |
| juggernaut (Brall) | dash | 0.058 | 0.038 | 1.53 |
| juggernaut (Brall) | e | 0.052 | 0.023 | 2.23 |
| ashwick (Felix) | rmb | 0.131 | 0.082 | 1.59 |
| ashwick (Felix) | dash | 0.104 | 0.148 | 0.70 |
| ashwick (Felix) | e | 0.045 | 0.060 | 0.76 |
| mage (Joule) | rmb | 0.117 | 0.104 | 1.13 |
| mage (Joule) | dash | 0.130 | 0.119 | 1.09 |
| mage (Joule) | e | 0.130 | 0.126 | 1.03 |
| bulwark (Oath) | dash | 0.156 | 0.154 | 1.01 |
| thief (Shiv) | rmb | 0.032 | 0.019 | 1.67 |
| ostra (Void) | rmb | 0.062 | 0.117 | 0.53 |
| ostra (Void) | e | 0.091 | 0.154 | 0.59 |
<!-- ttk:table -->

**11-11 slice (ext/ttk-slice-1111, run 2026-11-11 on worker rpc1).** The owner-direct 11-11 kit branches were run one by one and merged together (scratch: origin/main 88b06b9e7 + ext/kael-owner-1111 4cb48148d + ext/lace-1111 cf1adae16 + ext/vex-rmb-1111 a796f3a38 + ext/albert-hold-cinder-orb 4cf2f22b4; the first two carry ext/release-integ-0245 272368589, also run on its own). All seven runs print the same 54 lines: **none of the four branches moves a TTK row.** They change shapes, timing and visuals but no damage, cooldown or cadence the idle-target fight reads (Kael: slam lane 4.3 x 0.72 m instead of the 70 deg cone, the Chain Lunge and its 1.25x chain Smash removed; Lace: Heavy Shot from the bow mouth, roll 3.0 -> 3.375; Vex: Burr Charge no longer procs in the air; Cinder: the pilot flame only while the lance spools up). The table above is therefore what origin/main writes today; the rows that differ from 11-09 are main drift (Kael, Sparkle and Albert combos, Cinder LMB max), not these branches.

| Hunter (source) | Branch | Row | 11-09 doc | origin/main | branch alone | all four merged | Source s (supervive_kits.md) |
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

Out of the bar after the slice, each with the number that puts it there: **Kael** LMB 0.65, Slash 8 = 5.2% of our target against Caldera 43 = 3.3%; combo 0.55 / 0.59, Smash 26 = 16.9% against Execution Slam 130 = 10.1% (1.67x) and Warchain 8 against Feysteel Chain 30 (2.23x). The move from 0.45 / 0.16 is Rampage 0.175 -> 0.058 (tip 18 no longer lands; source Flame Step 49 = 0.038). **Vex** LMB 3.25, our 0.12 s cadence with `sustain_loss` 0.5 against MK7 51 every 0.08 s; combo max 0.78, Railgun share 0.234 against 202 = 0.157 (1.49x). **Cinder** LMB 0.78 / 0.74, stream 25.6% of the target a second against Flamethrower 258/s = 20.1%; combo 0.76 / 0.61, Cinder Shot 0.131 against Embry Bolt 106 = 0.082 (1.59x). **Lace** has no source row (Greenwood Bow has no damage number in supervive_kits.md). No kit was tuned in this job.

**Outliers and causes (suggestions, nothing built)**

| Hunter | Rows | Cause | Suggestion |
|---|---|---|---|
| Vex (Ghost) | LMB 3.25x slow; combo max 0.78 | Per round the shares match (6 of 154 = 3.9%, 51 of 1285 = 4.0%), but ours fires every 0.12 s (wiki and weapon sheet say 0.08 s; our 5 fps footage says about 0.14 s) and `sustain_loss` 0.5 halves every round after the tenth, where the source's first 10 rounds are the extra ones and rounds 11 to 30 stay at base. Our grenade matches (1.11x), the E beam is 1.49x. | Drop `sustain_loss` so rounds 11+ keep full damage and the first 10 get a bonus; settle 0.08 vs 0.12 s from footage first. |
| Kael (Brall) | LMB 0.65; combo 0.45 and 0.16 | Slash 8 is 5.2% of our target against 43 = 3.3% (1.56x, cadence 0.34 vs 0.35 s matches). Rampage hits 9 + tip 18 = 17.5% of the target against Flame Step 49 = 3.8% (4.6x); Warchain 5.2% vs 2.3% (2.2x); Smash 16.9% vs 10.1% (1.67x). Max rank adds +40% Smash and a shorter dash recharge on top. | Slash 8 -> 5, Rampage hit 9 / tip 18 -> about 2 / 4 (the tip doubling is ours), Warchain hit 8 -> 3.6, Smash 26 -> 15. |
| Cinder (Felix) | LMB 0.78, 0.76; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | LMB 0.77; combo max 0.64 | Bolt 12 every 0.648 s is 12.0% a second against 90 every 0.8 s = 8.8% (1.37x); the owner set 0.648 s (items 70 and 116 in docs/heroes/mage.md, not in DECISIONS). Abilities are at parity (1.03 to 1.13x), so max rank (+90% spear, +100% dash, +50% strike on the source side vs our +15% and +30% steps) is where the combo drifts. | Bolt 12 -> 9 keeps 0.648 s (owner) at parity; ask the owner whether item 116 covers the damage. |
| Albert (Oath) | LMB 0.73; combo 0.71, 0.73 | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Meeko (Elluna) | LMB 0.68 | Lantern 8 is 5.2% of our target every 0.4 s against 64 of 1902 = 3.4% (rising to 4.9% at 93); our Kindle ramp runs on top. | Lantern 8 -> about 5 (64 / 1902 x 154 = 5.2), ramp capped at +45% like the source. |
| Grimble (Kingpin) | LMB 2.70 | A full volley is 7 x 2 = 14 = 9.1% of our target against 339 of 1902 = 17.8% (0.51x), and ours takes 9.4 s where 14 full volleys at 0.5 s (192.5 raw after the 20%) would be 6.5 s, so not every pellet lands at 1.5 m (`pellet_floor` 0.457). | Pellet 2 -> about 3.9 (339 / 7 / 1902 x 154), then check how many pellets land point-blank. |
| Neve (Celeste) | LMB 0.22 | Dart 4 is 2.6% every 0.18 s against 35 of 1902 = 1.8% every 0.2 s (1.6x), and our live Shatter (60 = 39% of the target every 8 darts) counts while the source side leaves it out. Without Shatter ours would be about 8.6 s (48 darts), ratio about 0.64. | Dart 4 -> about 2.8 (35 / 1902 x 154); decide whether the check should count Shatter on both sides (the source pops 520 = 27% of 1902 every 8 darts). |
| Kael (Brall) | LMB 0.65; combo 0.55 and 0.59 | Slash 8 is 5.2% of our target against 43 = 3.3% (1.56x, cadence 0.34 vs 0.35 s matches). Rampage now lands only its pass hit 9 = 5.8% against Flame Step 49 = 3.8% (1.53x; the tip 18 misses a target 1.5 m ahead since main moved on from 11-09, data unchanged); Warchain 5.2% vs 2.3% (2.2x); Smash 16.9% vs 10.1% (1.67x). Max rank adds +40% Smash and a shorter dash recharge on top. | Slash 8 -> 5, Rampage hit 9 / tip 18 -> about 2 / 4 (the tip doubling is ours), Warchain hit 8 -> 3.6, Smash 26 -> 15. |
| Cinder (Felix) | LMB 0.78, 0.74; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | LMB 0.77; combo 0.17, 0.20 (were 0.81, 0.64 on 11-09) | Bolt 12 every 0.648 s is 12.0% a second against 90 every 0.8 s = 8.8% (1.37x); the owner set 0.648 s (items 70 and 116 in docs/heroes/mage.md, not in DECISIONS). Abilities are at parity per cast (1.03 to 1.13x), yet the combo now knocks in 1.53 / 1.27 s against 9.00 / 6.40: something outside the three casts (main drift since 11-09, not found here) adds most of the damage. | Bolt 12 -> 9 keeps 0.648 s (owner) at parity; ask the owner whether item 116 covers the damage. |
| Albert (Oath) | LMB 0.72; combo 0.70 (max 0.84 is now inside) | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Motley (Void) | LMB 1.91; combo 2.15, 1.74 | Orb 9 is 5.8% of the target against 263 of 2365 = 11.1% (0.53x). Spear 0.53x, bomb 0.59x. The whole kit sits about half the source. Held fire never charges (owner item 60, DECISIONS line 162 -15%). | Orb 9 -> 17, spear x1.9, bomb x1.7. |

Within the bar: Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Oath combo rank max (0.84), Lace (1.15) and Tenzo (1.17; at level 19 instead of 18 the source is about 0.6 s slower, still inside). The ours side of Kael, Cinder, Sparkle and Oath combo rows moved with main since the last write (Sparkle combo rank 0 0.81 -> 0.17, Kael combo 0.45 -> 0.55); the causes above were written against the older numbers.
Within the bar: Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Albert combo rank max (0.84).

**Not done here:** no tuning; Lace, Meeko, Tenzo, Grimble and Neve have footage LMB rows only, no combo rows (their ability tooltips are a different level from the footage).
