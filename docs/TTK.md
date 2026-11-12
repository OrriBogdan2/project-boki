# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `supervive_kits.md` (briefs/supervive-data on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (22 of 38 rows today); that is the finding, not a flake. No number was tuned; the outliers are listed with their causes as suggestions.

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
| juggernaut (Brall) | LMB rank 0 | 8.47 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | LMB rank max | 8.47 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | combo rank 0 | 4.42 | 7.70 | 0.57 | FAIL |
| juggernaut (Brall) | combo rank max | 4.15 | 7.00 | 0.59 | FAIL |
| ashwick (Felix) | LMB rank 0 | 4.87 | 6.20 | 0.78 | FAIL |
| ashwick (Felix) | LMB rank max | 4.62 | 6.20 | 0.74 | FAIL |
| ashwick (Felix) | combo rank 0 | 3.03 | 4.00 | 0.76 | FAIL |
| ashwick (Felix) | combo rank max | 1.83 | 3.00 | 0.61 | FAIL |
| mage (Joule) | LMB rank 0 | 10.43 | 13.60 | 0.77 | FAIL |
| mage (Joule) | LMB rank max | 10.43 | 13.60 | 0.77 | FAIL |
| mage (Joule) | combo rank 0 | 1.52 | 9.00 | 0.17 | FAIL |
| mage (Joule) | combo rank max | 1.25 | 6.40 | 0.20 | FAIL |
| bulwark (Oath) | LMB rank 0 | 4.88 | 6.75 | 0.72 | FAIL |
| bulwark (Oath) | LMB rank max | 4.88 | 6.75 | 0.72 | FAIL |
| bulwark (Oath) | combo rank 0 | 4.37 | 5.85 | 0.75 | FAIL |
| bulwark (Oath) | combo rank max | 4.37 | 5.00 | 0.87 | ok |
| thief (Shiv) | LMB rank 0 | 4.70 | 4.95 | 0.95 | ok |
| thief (Shiv) | LMB rank max | 4.70 | 4.95 | 0.95 | ok |
| thief (Shiv) | combo rank 0 | 4.23 | 4.95 | 0.86 | ok |
| thief (Shiv) | combo rank max | 4.23 | 4.95 | 0.86 | ok |
| ostra (Void) | LMB rank 0 | 12.63 | 6.60 | 1.91 | FAIL |
| ostra (Void) | LMB rank max | 12.63 | 6.60 | 1.91 | FAIL |
| ostra (Void) | combo rank 0 | 10.35 | 4.80 | 2.16 | FAIL |
| ostra (Void) | combo rank max | 8.37 | 4.80 | 1.74 | FAIL |
| archer (Myth) | LMB rank 0 | 7.83 | never | n/a | n/a |
| archer (Myth) | LMB rank max | 7.83 | never | n/a | n/a |
| tender (Elluna) | LMB rank 0 | 7.12 | never | n/a | n/a |
| tender (Elluna) | LMB rank max | 7.12 | never | n/a | n/a |
| dolm (Tetra) | LMB rank 0 | 12.70 | never | n/a | n/a |
| dolm (Tetra) | LMB rank max | 12.70 | never | n/a | n/a |
| dredge (Kingpin) | LMB rank 0 | 7.40 | never | n/a | n/a |
| dredge (Kingpin) | LMB rank max | 7.40 | never | n/a | n/a |
| rimewright (Celeste) | LMB rank 0 | 2.97 | never | n/a | n/a |
| rimewright (Celeste) | LMB rank max | 2.97 | never | n/a | n/a |

| Hunter (source) | Cast | Ours (share of target) | Source | Ours / source |
|---|---|---|---|---|
| gunslinger (Ghost) | rmb | 0.143 | 0.128 | 1.11 |
| gunslinger (Ghost) | e | 0.234 | 0.157 | 1.49 |
| juggernaut (Brall) | rmb | 0.169 | 0.101 | 1.67 |
| juggernaut (Brall) | dash | 0.058 | 0.038 | 1.53 |
| juggernaut (Brall) | e | 0.052 | 0.023 | 2.23 |
| ashwick (Felix) | rmb | 0.131 | 0.082 | 1.58 |
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
| Kael (Brall) | LMB 0.65; combo 0.57 and 0.59 | Slash 8 is 5.2% of our target against 43 = 3.3% (1.56x, cadence 0.34 vs 0.35 s matches). Rampage hits 9 + tip 18 = 17.5% of the target against Flame Step 49 = 3.8% (4.6x); Warchain 5.2% vs 2.3% (2.2x); Smash 16.9% vs 10.1% (1.67x). Max rank adds +40% Smash and a shorter dash recharge on top. | Slash 8 -> 5, Rampage hit 9 / tip 18 -> about 2 / 4 (the tip doubling is ours), Warchain hit 8 -> 3.6, Smash 26 -> 15. |
| Cinder (Felix) | LMB 0.78, 0.76; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | LMB 0.77; combo 0.17 and 0.20 | Bolt 12 every 0.648 s is 12.0% a second against 90 every 0.8 s = 8.8% (1.37x); the owner set 0.648 s (items 70 and 116 in docs/heroes/mage.md, not in DECISIONS). Abilities are at parity (1.03 to 1.13x), so max rank (+90% spear, +100% dash, +50% strike on the source side vs our +15% and +30% steps) is where the combo drifts. | Bolt 12 -> 9 keeps 0.648 s (owner) at parity; ask the owner whether item 116 covers the damage. |
| Albert (Oath) | LMB 0.72; combo 0.74 (max 0.87 is in the bar) | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Motley (Void) | LMB 1.91; combo 2.15, 1.74 | Orb 9 is 5.8% of the target against 263 of 2365 = 11.1% (0.53x). Spear 0.53x, bomb 0.59x. The whole kit sits about half the source. Held fire never charges (owner item 60, DECISIONS line 162 -15%). | Orb 9 -> 17, spear x1.9, bomb x1.7. |

Within the bar now: Sable at both ranks (0.85 to 0.95), Vex combo rank 0 (0.92), Albert combo max (0.87). Sparkle combo rank 0 (0.81) left it.

The cause cells above were written on 0.24.4 and are kept for the numbers they quote; the rows moved since, see the next section.

## Changed since 0.24.4 (0.24.6: origin/ext/w0246-combat-a + origin/ext/w0246-feel on origin/main 53e2fe7f3)

Measured as three runs of `--ttk-check`: main (this file before), main + combat-a, and the stack with feel. Which wave moved a row is measured; the commit named is read from the diff of the Hunter's files, not bisected. Failures stay 22 of 38 rows (before: 22). Only two rows crossed the bar.

- **Vex:** no row moved. LMB 3.25 and combo max 0.78 stay out; combo rank 0 0.92 stays in.
- **Kael:** combat-a moved the combo, out of the bar both times: rank 0 3.48 -> 4.22 s (0.45 -> 0.55), max 1.15 -> 4.15 s (0.16 -> 0.59). Probable: c73595043 (ranks follow the source tiers, tier IV folds into rank 3: the 1.15 s was the stacked dash recharge and Smash gain), b4ffaa6ed / 559d56bd5 (Rampage 3.6 m then back to 4.5 m / 0.17 s). feel adds 4.22 -> 4.42 s on rank 0 (0.57). LMB 8.45 -> 8.47 s (0.65).
- **Cinder:** LMB max 4.72 -> 4.62 s (0.76 -> 0.74), combat-a (a863574d8, ranks B). Still out on all four rows.
- **Sparkle:** combo rank 0 7.32 -> 1.52 s (0.81 ok -> 0.17 FAIL) and max 4.07 -> 1.25 s (0.64 -> 0.20), both combat-a. LEFT THE BAR. The per-cast shares did not move (rmb 1.13, dash 1.09, e 1.03), so something outside the three casts lands damage on the idle target in the combo; a89a84bed (Sparkle Wirerun 22 -> 9), 1325b9836 (Skycall's Grounded now applies to any foe, Skycall drag) and a2dc282d1 (bot Skycall drag) touch the slots, none is shown to cause it. Needs a trace before any tuning. LMB 10.42 -> 10.43 s.
- **Albert:** combo max 3.65 -> 4.08 s (0.73 FAIL -> 0.82 ok) in combat-a (c73595043, ranks to the source tiers), then 4.35 s (0.87) with feel. ENTERED THE BAR. Combo rank 0 4.12 -> 4.08 -> 4.35 s (0.70 -> 0.74, still out). LMB unchanged at 0.72.
- **Sable (thief):** 4.68 -> 4.70 s, all four rows still in the bar (0.85 to 0.95).
- **Motley:** LMB 12.62 -> 12.63, combo 10.33 -> 10.35; no row moved (1.91 to 2.16 out).
- **Lace, Meeko, Tenzo, Grimble, Neve (no source row):** LMB seconds moved, no verdict. Tenzo 13.30 -> 12.67 -> 12.70 (combat-a; ef38f084b, the Quake Punch cooldown starts on the press). Grimble 9.43 -> 7.35 -> 7.40 (combat-a; the Abyssal Hand and gun changes of w0246-combat-a, gun hold and pull). Meeko 7.10 -> 7.12, Neve 2.93 -> 2.97, Lace 7.83 (feel adds 0.01 to 0.04 s to most LMB rows: its frame and hit timing).

The 0.24.6 waves cut riders and changed ranks, but the cut riders (Meeko) and the Storm Rod damage do not show in these rows: this check casts every direct-damage non-ult once and the changed numbers are in rank steps (Kael, Albert), not base damage.

## Still outside the bar, for a follow-up job (slot and source number to fit; no number was changed here)

Share = source tooltip over the source's 1285 Base HP, times our 154 target.
- **Vex:** LMB, fire interval 0.12 s -> the source's 0.08 s with `sustain_loss` only after round 10 (source 51 = 4.0%, ours 6 of 154 already matches); E Longneedle for combo max: source 202 = 15.7% = 24 of 154.
- **Kael:** LMB Slash 8 -> 5 (source 43 = 3.3% = 5.2); Rampage dash hit source 49 = 3.8% = 5.9 in all (ours 9 + tip 18); Warchain E source 30 = 2.3% = 3.6; Finishing Slam RMB source 130 = 10.1% = 15.6.
- **Cinder:** LMB Stream source 258 a second = 20.1% = 31 a second (ours 39); Cinder Shot RMB source 106 = 8.2% = 12.7 (ours 20); dash source 190.4 = 14.8% = 22.8; cloak E source 76.8 = 6.0% = 9.2.
- **Sparkle:** LMB bolt 12 -> 9 at 0.648 s (source 90 = 7.0% a 0.8 s shot = 10.8; 9 keeps the owner's 0.648 s at 8.8% a second); combo: first find what lands the extra damage (1.52 s against the source's 9.0 s), then fit.
- **Albert:** LMB Hammer 12 (source 192 of 2365 = 8.1%): the throw-and-recall cadence 0.45 s -> match the source 6.75 s, ours 4.88; settle whether the source recall hits; combo rank 0: 4.35 s -> the source's 5.85 s.
- **Motley:** LMB Orb 9 -> 17 (source 263 of 2365 = 11.1% = 17.1); RMB spear x1.9 (0.53x), E bomb x1.7 (0.59x).
**Not done here:** no tuning; the five Hunters with no LMB number (and their combos) need the source's LMB damage, which no file in briefs has.
