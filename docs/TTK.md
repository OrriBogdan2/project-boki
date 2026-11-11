# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `supervive_kits.md` (briefs/supervive-data on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (18 of 38 rows today); that is the finding, not a flake. Kael is tuned to the bar (below); the other outliers are listed with their causes as suggestions.

**Method**
- Target: full health and full armour. Ours 154 health (mean of the 12), armour 339 (x2.2) and the game's 20% reduction. Source 1285 Base HP (mean of the 12, supervive_physics.md) and Common armour, 20% reduction (docs/SUPERVIVE_DATA.md section 3). Both armours outlast the health, so only the 20% counts. Void, Oath and Shiv tooltips were read at level 15, so their source target is the level 15 mean (1285 + 14 x 77.1).
- (a) LMB only, held (taps for Kael and Albert, a 1.1 s draw for Lace). (b) Combo: every direct-damage non-ult ability the source has a number for, cast once at the start and again whenever its cooldown or charge is back, LMB between. Conditional bonuses (Dazed, Static, Ignite, Quickflip's empowered shot, sweet spots, stacks) are left out of the source side; ours runs live, so its passives count.
- Rank 0 is the unspent rank (slot_lv 1); max is rank 3 for ours and every listed upgrade for the source (a "x2" upgrade counts for both tiers it covers, charges included). LMB has no ranks, so (a) is the same at both.
- Source shots land at 0.00 s and every interval after; ours includes wind-ups, flight time and recoveries.
- Bar: ours / source time to knock inside 0.8 to 1.25. Below 1 means ours knocks faster. An outlier passes only with an owner override from DECISIONS in `OVERRIDES` (none yet: line 162, Motley "loses ~15% held-fire DPS, no compensation buff", explains 15% of a 1.9x gap, so it does not cover Motley).

**Gaps in the source data.** `supervive_kits.md` has no LMB damage for Lace, Meeko, Tenzo, Grimble and Neve, so those five have no source row (n/a, ours only). Neve's, Meeko's, Tenzo's, Grimble's and Lace's abilities do have some numbers but no LMB to fill the time between them, so no combo row either.

<!-- ttk:table -->
| Hunter (source) | Row | Ours s | Source s | Ours / source | Verdict |
|---|---|---|---|---|---|
| gunslinger (Ghost) | LMB rank 0 | 8.07 | 2.48 | 3.25 | FAIL |
| gunslinger (Ghost) | LMB rank max | 8.07 | 2.48 | 3.25 | FAIL |
| gunslinger (Ghost) | combo rank 0 | 1.77 | 1.92 | 0.92 | ok |
| gunslinger (Ghost) | combo rank max | 1.37 | 1.76 | 0.78 | FAIL |
| juggernaut (Brall) | LMB rank 0 | 13.20 | 12.95 | 1.02 | ok |
| juggernaut (Brall) | LMB rank max | 13.20 | 12.95 | 1.02 | ok |
| juggernaut (Brall) | combo rank 0 | 7.88 | 7.70 | 1.02 | ok |
| juggernaut (Brall) | combo rank max | 7.25 | 7.00 | 1.04 | ok |
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

| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source |
|---|---|---|---|---|
| gunslinger (Ghost) | rmb | 0.143 | 0.128 | 1.11 |
| gunslinger (Ghost) | e | 0.234 | 0.157 | 1.49 |
| juggernaut (Brall) | rmb | 0.101 | 0.101 | 1.00 |
| juggernaut (Brall) | dash | 0.013 | 0.038 | 0.34 |
| juggernaut (Brall) | e | 0.023 | 0.023 | 1.00 |
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

**Outliers and causes (suggestions, nothing built)**

| Hunter | Rows | Cause | Suggestion |
|---|---|---|---|
| Vex (Ghost) | LMB 3.25x slow; combo max 0.78 | Per round the shares match (6 of 154 = 3.9%, 51 of 1285 = 4.0%), but ours fires every 0.12 s (wiki and weapon sheet say 0.08 s; our 5 fps footage says about 0.14 s) and `sustain_loss` 0.5 halves every round after the tenth, where the source's first 10 rounds are the extra ones and rounds 11 to 30 stay at base. Our grenade matches (1.11x), the E beam is 1.49x. | Drop `sustain_loss` so rounds 11+ keep full damage and the first 10 get a bonus; settle 0.08 vs 0.12 s from footage first. |
| Cinder (Felix) | LMB 0.78, 0.76; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | LMB 0.77; combo 0.17, 0.20 (was 0.81, 0.64: a change on main since, not traced here) | Bolt 12 every 0.648 s is 12.0% a second against 90 every 0.8 s = 8.8% (1.37x); the owner set 0.648 s (items 70 and 116 in docs/heroes/mage.md, not in DECISIONS). Abilities are at parity (1.03 to 1.13x), so max rank (+90% spear, +100% dash, +50% strike on the source side vs our +15% and +30% steps) is where the combo drifts. | Bolt 12 -> 9 keeps 0.648 s (owner) at parity; ask the owner whether item 116 covers the damage. |
| Albert (Oath) | LMB 0.73; combo 0.71, 0.73 | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Motley (Void) | LMB 1.91; combo 2.15, 1.74 | Orb 9 is 5.8% of the target against 263 of 2365 = 11.1% (0.53x). Spear 0.53x, bomb 0.59x. The whole kit sits about half the source. Held fire never charges (owner item 60, DECISIONS line 162 -15%). | Orb 9 -> 17, spear x1.9, bomb x1.7. |

Within the bar: Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Albert combo rank max (0.84), Kael at every row (1.02 to 1.04).

**Kael (Brall), tuned.** Was LMB 0.65, combo 0.55 and 0.59 (0.45 and 0.16 in the first table, when the Rampage tip still landed on the pinned target). Every hit sat at 1.5 to 4.6x the source's share of a target (slash 8 = 5.2% against 43 = 3.3%). Now each damage number is Brall's tooltip over the source's 1285 mean Base HP times our 154 (pinned in content/rules/kit_parity.json as ratios to the slash): slash 5.2 (43), Searing Wave full 12.8 (fireblast 107, part charge 7.7), Slam 15.6 (130), Lunge 7.1 -> 10.1 (84), Meteor Drop 10.5 (88), Cinder Spin 11.9 (99), Rampage 2 + tip 4 (Flame Step 49 for the dash attack; the tip doubling is ours, so pass and tip together are the 49), Warchain 3.6 (30); the Haul Slam has no source number and keeps its place beside the Lunge (8 -> 15.1). Rank bonuses that stack at max: every Smash variant +20% and +40% (source Adaptive Strike +20% / +20%, so they match), the third Rampage charge and its 6.4 s recharge, the Warchain's 8 s cooldown, and Enraged +15% (live on ours, the source's Empowered is left out). Burst at rank 0 is the Slam every 2 s plus two Rampages; at max the Slam's +40% carries it. The Rampage hit row reads 0.34 because the pinned target is shoved off the tip; in play pass and tip land together. Owner notes kept: the Lunge held as long as you like with the perfect release and its 4.5 -> 7.5 m fling, the 2.4 m down slam (11-10). Not tuned: cooldowns (ours a little shorter at max), Rage per damage (Enraged now comes later in a fight), the Gilded Riposte (an ult, 43 against Volcanic Rebuke 230 = 1.56x).

**Not done here:** no tuning; the five Hunters with no LMB number (and their combos) need the source's LMB damage, which no file in briefs has.
