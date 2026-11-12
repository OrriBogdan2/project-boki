# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `supervive_kits.md` (briefs/supervive-data on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override; that is the finding, not a flake. Every judged row is inside the bar since the 1112 parity pass (table at the end).

**Method**
- Target: full health and full armour. Ours 154 health (mean of the 12), armour 339 (x2.2) and the game's 20% reduction. Source 1285 Base HP (mean of the 12, supervive_physics.md) and Common armour, 20% reduction (docs/SUPERVIVE_DATA.md section 3). Both armours outlast the health, so only the 20% counts. Void, Oath and Shiv tooltips were read at level 15, so their source target is the level 15 mean (1285 + 14 x 77.1).
- (a) LMB only, held (taps for Kael and Albert, a 1.1 s draw for Lace). (b) Combo: every direct-damage non-ult ability the source has a number for, cast once at the start and again whenever its cooldown or charge is back, LMB between. Conditional bonuses the source gives no number for (Static's Blowout, Ignite, Quickflip's empowered shot, sweet spots, stacks) are left out of the source side; ours runs live, so its passives count, except Sparkle's Blowout, which is left out of ours too (one Blowout is about 40% of our target, so it alone decides her row). A bonus with a number is on both sides: Vex's Daze (1.2 s, +39 a round, Railgun +20%) and Sparkle's charge orb (each Storm Rod hit hands Wirerun back, `RESETS`). The `combo + Blowout` rows show her live combo and are not judged. Two exceptions, both Ghost's, because the fight always has them: the rifle's first 10 rounds deal extra (supervive_kits.md; opening at 2x, falling to 51 by round 10, wiki), and in the combo the Spike Grenade's Daze (1.2 s, docs/SUPERVIVE_DATA.md) adds +39 to each rifle round and +20% to the Railgun.
- Rank 0 is the unspent rank (slot_lv 1); max is rank 3 for ours and every listed upgrade for the source (a "x2" upgrade counts for both tiers it covers, charges included). LMB has no ranks, so (a) is the same at both.
- Source shots land at 0.00 s and every interval after; ours includes wind-ups, flight time and recoveries.
- Bar: ours / source time to knock inside 0.85 to 1.15 (+-15%, owner digest 1112). Below 1 means ours knocks faster. An outlier passes only with an owner override from DECISIONS in `OVERRIDES` (none yet: line 162, Motley "loses ~15% held-fire DPS, no compensation buff", explains 15% of a 1.9x gap, so it does not cover Motley).

**Gaps in the source data.** `supervive_kits.md` has no LMB damage for Lace, Meeko, Tenzo, Grimble and Neve, so those five have no source row (n/a, ours only). Neve's, Meeko's, Tenzo's, Grimble's and Lace's abilities do have some numbers but no LMB to fill the time between them, so no combo row either.

**Gil (ours, no source Hunter).** His rows are `gil (roster median)`: his LMB and combo (Grab Bag, Riptide, Ground Swim, no ult) against the median of the 12 Hunters' own times for the same row, with the same 0.85-1.15 bar. His combo moves run to run (the bag draws its potion at random: combo rank 0 5.7-7.7 s, rank max 5.0-7.2 s over 3 runs), so judge it by the range. Fix if out: `content/archetypes/gil.json` `lmb.rate` 0.32 -> 0.23 puts all four rows inside (LMB 0.87, combo 1.11 / 1.07 in the run measured); nothing else was touched.

<!-- ttk:table -->
| Hunter (source) | Row | Ours s | Source s | Ours / source | Verdict |
|---|---|---|---|---|---|
| gunslinger (Ghost) | LMB rank 0 | 2.18 | 2.00 | 1.09 | ok |
| gunslinger (Ghost) | LMB rank max | 2.18 | 2.00 | 1.09 | ok |
| gunslinger (Ghost) | combo rank 0 | 0.77 | 0.80 | 0.96 | ok |
| gunslinger (Ghost) | combo rank max | 0.68 | 0.72 | 0.95 | ok |
| juggernaut (Brall) | LMB rank 0 | 13.20 | 12.95 | 1.02 | ok |
| juggernaut (Brall) | LMB rank max | 13.20 | 12.95 | 1.02 | ok |
| juggernaut (Brall) | combo rank 0 | 7.88 | 7.70 | 1.02 | ok |
| juggernaut (Brall) | combo rank max | 7.25 | 7.00 | 1.04 | ok |
| ashwick (Felix) | LMB rank 0 | 5.72 | 6.20 | 0.92 | ok |
| ashwick (Felix) | LMB rank max | 5.62 | 6.20 | 0.91 | ok |
| ashwick (Felix) | combo rank 0 | 3.93 | 4.30 | 0.91 | ok |
| ashwick (Felix) | combo rank max | 2.63 | 3.00 | 0.88 | ok |
| mage (Joule) | LMB rank 0 | 13.67 | 13.60 | 1.00 | ok |
| mage (Joule) | LMB rank max | 13.67 | 13.60 | 1.00 | ok |
| mage (Joule) | combo rank 0 | 8.47 | 8.80 | 0.96 | ok |
| mage (Joule) | combo rank max | 4.03 | 4.00 | 1.01 | ok |
| bulwark (Oath) | LMB rank 0 | 6.88 | 6.75 | 1.02 | ok |
| bulwark (Oath) | LMB rank max | 6.88 | 6.75 | 1.02 | ok |
| bulwark (Oath) | combo rank 0 | 5.73 | 5.85 | 0.98 | ok |
| bulwark (Oath) | combo rank max | 5.30 | 5.00 | 1.06 | ok |
| thief (Shiv) | LMB rank 0 | 4.68 | 4.95 | 0.95 | ok |
| thief (Shiv) | LMB rank max | 4.68 | 4.95 | 0.95 | ok |
| thief (Shiv) | combo rank 0 | 4.22 | 4.95 | 0.85 | ok |
| thief (Shiv) | combo rank max | 4.22 | 4.95 | 0.85 | ok |
| ostra (Void) | LMB rank 0 | 7.22 | 6.60 | 1.09 | ok |
| ostra (Void) | LMB rank max | 7.22 | 6.60 | 1.09 | ok |
| ostra (Void) | combo rank 0 | 5.42 | 4.80 | 1.13 | ok |
| ostra (Void) | combo rank max | 4.82 | 4.80 | 1.00 | ok |
| archer (Myth) | LMB rank 0 | 7.83 | never | n/a | n/a |
| archer (Myth) | LMB rank max | 7.83 | never | n/a | n/a |
| tender (Elluna) | LMB rank 0 | 7.10 | never | n/a | n/a |
| tender (Elluna) | LMB rank max | 7.10 | never | n/a | n/a |
| dolm (Tetra) | LMB rank 0 | 13.30 | never | n/a | n/a |
| dolm (Tetra) | LMB rank max | 13.30 | never | n/a | n/a |
| dredge (Kingpin) | LMB rank 0 | 9.43 | never | n/a | n/a |
| dredge (Kingpin) | LMB rank max | 9.43 | never | n/a | n/a |
| rimewright (Celeste) | LMB rank 0 | 2.93 | never | n/a | n/a |
| rimewright (Celeste) | LMB rank max | 2.93 | never | n/a | n/a |
| rimewright (Celeste) | combo rank 0 | 2.93 | never | n/a | n/a |
| rimewright (Celeste) | combo rank max | 2.22 | never | n/a | n/a |
| gil (roster median) | LMB rank 0 | 8.73 | 7.16 | 1.22 | FAIL |
| gil (roster median) | LMB rank max | 8.73 | 7.16 | 1.22 | FAIL |
| gil (roster median) | combo rank 0 | 5.70 | 4.82 | 1.18 | FAIL |
| gil (roster median) | combo rank max | 6.88 | 4.12 | 1.67 | FAIL |
| mage (Joule) | combo + Blowout rank 0 | 2.68 | 8.80 | 0.30 | shown |
| mage (Joule) | combo + Blowout rank max | 1.27 | 4.00 | 0.32 | shown |

| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source |
|---|---|---|---|---|
| gunslinger (Ghost) | rmb | 0.127 | 0.128 | 0.99 |
| gunslinger (Ghost) | e | 0.156 | 0.157 | 0.99 |
| juggernaut (Brall) | rmb | 0.101 | 0.101 | 1.00 |
| juggernaut (Brall) | dash | 0.013 | 0.038 | 0.34 |
| juggernaut (Brall) | e | 0.023 | 0.023 | 1.00 |
| ashwick (Felix) | rmb | 0.094 | 0.082 | 1.14 |
| ashwick (Felix) | dash | 0.117 | 0.117 | 1.00 |
| ashwick (Felix) | e | 0.058 | 0.060 | 0.98 |
| mage (Joule) | rmb | 0.104 | 0.104 | 1.00 |
| mage (Joule) | dash | 0.119 | 0.119 | 1.00 |
| mage (Joule) | e | 0.126 | 0.126 | 1.00 |
| bulwark (Oath) | dash | 0.156 | 0.154 | 1.01 |
| thief (Shiv) | rmb | 0.019 | 0.019 | 1.00 |
| ostra (Void) | rmb | 0.117 | 0.117 | 1.00 |
| ostra (Void) | e | 0.172 | 0.154 | 1.11 |
| rimewright (Celeste) | rmb | 0.260 | 0.269 | 0.96 |
| rimewright (Celeste) | x | 0.117 | 0.121 | 0.97 |
<!-- ttk:table -->

**1112 parity pass: before (main 0.24.5) and after, ours / source**

| Hunter | LMB 0, LMB max, combo 0, combo max before | After |
|---|---|---|
| Vex (Ghost) | 3.25, 3.25, 0.92, 0.78 | 1.09, 1.09, 0.96, 0.95 |
| Kael (Brall) | 0.65, 0.65, 0.45, 0.16 | 1.02, 1.02, 1.02, 1.04 |
| Cinder (Felix) | 0.78, 0.76, 0.76, 0.61 | 0.92, 0.91, 0.91, 0.88 |
| Sparkle (Joule) | 0.77, 0.77, 0.81, 0.64 | 1.00, 1.00, 0.96, 1.01 |
| Albert (Oath) | 0.72, 0.72, 0.70, 0.73 | 1.02, 1.02, 0.98, 1.06 |
| Sable (Shiv) | 0.95, 0.95, 0.85, 0.85 | 0.95, 0.95, 0.85, 0.85 |
| Motley (Void) | 1.91, 1.91, 2.15, 1.74 | 1.09, 1.09, 1.13, 1.00 |

What moved each row is in the hero's doc (docs/heroes/) and the kit_parity rows. Sable's combo sits on the bar's edge (0.853).

**Open: Sparkle's Blowout.** With it live her combo knocks in 2.68 s and 1.27 s (0.30 and 0.32 of the source without it; the owner digest's "6x fast" is this, on 0.24.6 combat-a where the old check counted it). The source calls its bonus "massive" with no number, so no row can judge it. Its size is not the lever: `blow_pct` 0.18 -> 0.09 gives 0.45 and 0.32, -> 0 gives 0.53 and 0.32 (measured). At max rank the chain decides it (each Blowout hands Wirerun back and the run through a Live foe hits double), so taming it is a design call for the owner (fewer resets, or no double), not a number to tune here.

**Not done here:** the five Hunters with no LMB number (and their combos) need the source's LMB damage, which no file in briefs has.
