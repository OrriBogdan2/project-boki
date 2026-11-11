# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `supervive_kits.md` (briefs/supervive-data on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (22 of 38 rows today); that is the finding, not a flake. Tuned so far: the per-cast shares of the five Hunters with no source LMB (Lace, Meeko, Grimble; ext/ttk-five-cast-share, pinned in content/rules/kit_parity.json); the other outliers are listed with their causes as suggestions. Rows of Hunters not tuned here moved with other changes on main (Kael, Sparkle and Albert combos since 11-09).

**Method**
- Target: full health and full armour. Ours 154 health (mean of the 12), armour 339 (x2.2) and the game's 20% reduction. Source 1285 Base HP (mean of the 12, supervive_physics.md) and Common armour, 20% reduction (docs/SUPERVIVE_DATA.md section 3). Both armours outlast the health, so only the 20% counts. Void, Oath and Shiv tooltips were read at level 15, so their source target is the level 15 mean (1285 + 14 x 77.1).
- (a) LMB only, held (taps for Kael and Albert, a 1.1 s draw for Lace). (b) Combo: every direct-damage non-ult ability the source has a number for, cast once at the start and again whenever its cooldown or charge is back, LMB between. Conditional bonuses (Dazed, Static, Ignite, Quickflip's empowered shot, sweet spots, stacks) are left out of the source side; ours runs live, so its passives count.
- Rank 0 is the unspent rank (slot_lv 1); max is rank 3 for ours and every listed upgrade for the source (a "x2" upgrade counts for both tiers it covers, charges included). LMB has no ranks, so (a) is the same at both.
- Source shots land at 0.00 s and every interval after; ours includes wind-ups, flight time and recoveries.
- Share table: one cast against the unarmoured standard target, watched 2 s (ults 4.5 s), as a share of its health against the source number over the source target. Lace's Heavy Shot is held to full draw (1.1 s); Rain of Arrows' damage a second counts over the same 2 s; Meeko's Burrseed shows the hit only (the burst 2 s after it sticks has no source number); Starpiercer's three shots are fired. A share outside 0.8 to 1.25 is marked `out` (Bar column; it does not fail the check) and listed below.
- Bar: ours / source time to knock inside 0.8 to 1.25. Below 1 means ours knocks faster. An outlier passes only with an owner override from DECISIONS in `OVERRIDES` (none yet: line 162, Motley "loses ~15% held-fire DPS, no compensation buff", explains 15% of a 1.9x gap, so it does not cover Motley).

**Gaps in the source data.** `supervive_kits.md` has no LMB damage for Lace, Meeko, Tenzo, Grimble and Neve, so those five have no source row (n/a, ours only). Their abilities with a damage number have no LMB to fill the time between them, so no combo row either, but each has a row in the share table: Lace's Heartpiercer (35), Rain of Arrows (61 a second) and Virideth's Fury (326 + 326 + 422), Meeko's Darkside Binding (49 on hit), Grimble's Primal Slam (264), Neve's Cryo Spear (156 + 190) and Chilling Finale (155). Tenzo's card gives no base damage (Volcano Crusher only "+50 dmg" as an upgrade), so he has none.

<!-- ttk:table -->
| Hunter (source) | Row | Ours s | Source s | Ours / source | Verdict |
|---|---|---|---|---|---|
| gunslinger (Ghost) | LMB rank 0 | 8.07 | 2.48 | 3.25 | FAIL |
| gunslinger (Ghost) | LMB rank max | 8.07 | 2.48 | 3.25 | FAIL |
| gunslinger (Ghost) | combo rank 0 | 1.77 | 1.92 | 0.92 | ok |
| gunslinger (Ghost) | combo rank max | 1.37 | 1.76 | 0.78 | FAIL |
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

| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source | Bar |
|---|---|---|---|---|---|
| gunslinger (Ghost) | rmb | 0.143 | 0.128 | 1.11 | ok |
| gunslinger (Ghost) | e | 0.234 | 0.157 | 1.49 | out |
| juggernaut (Brall) | rmb | 0.169 | 0.101 | 1.67 | out |
| juggernaut (Brall) | dash | 0.058 | 0.038 | 1.53 | out |
| juggernaut (Brall) | e | 0.052 | 0.023 | 2.23 | out |
| ashwick (Felix) | rmb | 0.131 | 0.082 | 1.59 | out |
| ashwick (Felix) | dash | 0.104 | 0.148 | 0.70 | out |
| ashwick (Felix) | e | 0.045 | 0.060 | 0.76 | out |
| mage (Joule) | rmb | 0.117 | 0.104 | 1.13 | ok |
| mage (Joule) | dash | 0.130 | 0.119 | 1.09 | ok |
| mage (Joule) | e | 0.130 | 0.126 | 1.03 | ok |
| bulwark (Oath) | dash | 0.156 | 0.154 | 1.01 | ok |
| thief (Shiv) | rmb | 0.032 | 0.019 | 1.67 | out |
| ostra (Void) | rmb | 0.062 | 0.117 | 0.53 | out |
| ostra (Void) | e | 0.091 | 0.154 | 0.59 | out |
| archer (Myth) | rmb | 0.027 | 0.027 | 1.00 | ok |
| archer (Myth) | e | 0.095 | 0.095 | 1.00 | ok |
| tender (Elluna) | rmb | 0.038 | 0.038 | 1.00 | ok |
| dredge (Kingpin) | e | 0.205 | 0.205 | 1.00 | ok |
| rimewright (Celeste) | rmb | 0.506 | 0.269 | 1.88 | out |
| rimewright (Celeste) | x | 0.299 | 0.121 | 2.48 | out |
| archer (Myth) | x | 0.396 | 0.836 | 0.47 | out |
<!-- ttk:table -->

**Outliers and causes (suggestions, nothing built)**

| Hunter | Rows | Cause | Suggestion |
|---|---|---|---|
| Vex (Ghost) | LMB 3.25x slow; combo max 0.78 | Per round the shares match (6 of 154 = 3.9%, 51 of 1285 = 4.0%), but ours fires every 0.12 s (wiki and weapon sheet say 0.08 s; our 5 fps footage says about 0.14 s) and `sustain_loss` 0.5 halves every round after the tenth, where the source's first 10 rounds are the extra ones and rounds 11 to 30 stay at base. Our grenade matches (1.11x), the E beam is 1.49x. | Drop `sustain_loss` so rounds 11+ keep full damage and the first 10 get a bonus; settle 0.08 vs 0.12 s from footage first. |
| Kael (Brall) | LMB 0.65; combo 0.45 and 0.16 | Slash 8 is 5.2% of our target against 43 = 3.3% (1.56x, cadence 0.34 vs 0.35 s matches). Rampage hits 9 + tip 18 = 17.5% of the target against Flame Step 49 = 3.8% (4.6x); Warchain 5.2% vs 2.3% (2.2x); Smash 16.9% vs 10.1% (1.67x). Max rank adds +40% Smash and a shorter dash recharge on top. | Slash 8 -> 5, Rampage hit 9 / tip 18 -> about 2 / 4 (the tip doubling is ours), Warchain hit 8 -> 3.6, Smash 26 -> 15. |
| Cinder (Felix) | LMB 0.78, 0.76; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | LMB 0.77; combo max 0.64 | Bolt 12 every 0.648 s is 12.0% a second against 90 every 0.8 s = 8.8% (1.37x); the owner set 0.648 s (items 70 and 116 in docs/heroes/mage.md, not in DECISIONS). Abilities are at parity (1.03 to 1.13x), so max rank (+90% spear, +100% dash, +50% strike on the source side vs our +15% and +30% steps) is where the combo drifts. | Bolt 12 -> 9 keeps 0.648 s (owner) at parity; ask the owner whether item 116 covers the damage. |
| Albert (Oath) | LMB 0.73; combo 0.71, 0.73 | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Lace (Myth) | shares: Heavy Shot 7.15, Rain of Arrows 1.37, Starpiercer 0.47 | Heavy Shot 30 at full draw was 19.5% of the target against Heartpiercer 35 = 2.7% (its wall hit 4.94x on top, a full pin 178); Hail Wall 5 a tick, 10 a second = 6.5% against 61 = 4.75%. Starpiercer 18 / 18 / 25 is 40% against 84% of the target. | Built: Heavy Shot 16 / 30 -> 2.2 / 4.2 (the pair keeps its charge curve; the wall hit follows by 4.94x, 11 to 21), Hail Wall 5 -> 3.66 a tick; both 1.00. Starpiercer kept: the owner's burst cap (docs/heroes/archer.md, the ult then the merge never one-shots a full-health light). |
| Meeko (Elluna) | share: Burrseed 6.98 with the burst, 1.53 the hit | The seed hit 9 is 5.8% against Darkside Binding 49 = 3.8%; the 32 burst has no source number. | Built: seed hit 9 -> 5.87, 1.00. Burst 32 left (unsourced: the card's delayed hit has an AP ratio but no number). |
| Grimble (Kingpin) | share: Anchor Drop 0.79 | Anchor 25 is 16.2% against Primal Slam 264 = 20.5% (the footage's 1.8x a volley). | Built: 25 -> 31.6, 1.00. |
| Neve (Celeste) | shares: Ice Spear 1.88, Rimelock 2.48 | Spear 18 + detonation 60 against 156 + 190; crash 40 (46 measured with the Shatter stacks) against 155. | Not tuned here: ext/parity-ttk-cinder-neve (unmerged) sets detonation 22 and crash 18 (0.96 / 0.97) and adds the same two rows. |
| Motley (Void) | LMB 1.91; combo 2.15, 1.74 | Orb 9 is 5.8% of the target against 263 of 2365 = 11.1% (0.53x). Spear 0.53x, bomb 0.59x. The whole kit sits about half the source. Held fire never charges (owner item 60, DECISIONS line 162 -15%). | Orb 9 -> 17, spear x1.9, bomb x1.7. |

Within the bar: Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Sparkle combo rank 0 (0.81).

**Not done here:** the five Hunters with no LMB number still have no LMB or combo row: those need the source's LMB damage, which no file in briefs has.
