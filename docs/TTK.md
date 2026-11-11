# Time to knock against the source

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). `godot --headless --path . -- --ttk-check` fights each Hunter against an idle standard target in a live match and works the same fight out for the source Hunter from `supervive_kits.md` (briefs/supervive-data on origin/ext/agent-briefs). `--ttk-check --write` rewrites the tables below. The check exits 1 while any row is out of the bar without an override (20 of 38 rows today); that is the finding, not a flake. Tuned so far: Sparkle's and Sable's damage (ext/parity-ttk-sparkle-sable-lace, pinned in content/rules/kit_parity.json); the other outliers are listed with their causes as suggestions. Rows of Hunters not tuned here moved since 11-09 with other changes on main.

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
| juggernaut (Brall) | LMB rank 0 | 8.45 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | LMB rank max | 8.45 | 12.95 | 0.65 | FAIL |
| juggernaut (Brall) | combo rank 0 | 4.22 | 7.70 | 0.55 | FAIL |
| juggernaut (Brall) | combo rank max | 4.15 | 7.00 | 0.59 | FAIL |
| ashwick (Felix) | LMB rank 0 | 4.87 | 6.20 | 0.78 | FAIL |
| ashwick (Felix) | LMB rank max | 4.62 | 6.20 | 0.74 | FAIL |
| ashwick (Felix) | combo rank 0 | 3.03 | 4.00 | 0.76 | FAIL |
| ashwick (Felix) | combo rank max | 1.83 | 3.00 | 0.61 | FAIL |
| mage (Joule) | LMB rank 0 | 13.67 | 13.60 | 1.00 | ok |
| mage (Joule) | LMB rank max | 13.67 | 13.60 | 1.00 | ok |
| mage (Joule) | combo rank 0 | 2.68 | 9.00 | 0.30 | FAIL |
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
| juggernaut (Brall) | rmb | 0.169 | 0.101 | 1.67 |
| juggernaut (Brall) | dash | 0.058 | 0.038 | 1.53 |
| juggernaut (Brall) | e | 0.052 | 0.023 | 2.23 |
| ashwick (Felix) | rmb | 0.131 | 0.082 | 1.59 |
| ashwick (Felix) | dash | 0.104 | 0.148 | 0.70 |
| ashwick (Felix) | e | 0.045 | 0.060 | 0.76 |
| mage (Joule) | rmb | 0.104 | 0.104 | 1.00 |
| mage (Joule) | dash | 0.119 | 0.119 | 1.00 |
| mage (Joule) | e | 0.126 | 0.126 | 1.00 |
| bulwark (Oath) | dash | 0.156 | 0.154 | 1.01 |
| thief (Shiv) | rmb | 0.019 | 0.019 | 1.00 |
| ostra (Void) | rmb | 0.062 | 0.117 | 0.53 |
| ostra (Void) | e | 0.091 | 0.154 | 0.59 |
<!-- ttk:table -->

**Outliers and causes (suggestions, nothing built)**

| Hunter | Rows | Cause | Suggestion |
|---|---|---|---|
| Vex (Ghost) | LMB 3.25x slow; combo max 0.78 | Per round the shares match (6 of 154 = 3.9%, 51 of 1285 = 4.0%), but ours fires every 0.12 s (wiki and weapon sheet say 0.08 s; our 5 fps footage says about 0.14 s) and `sustain_loss` 0.5 halves every round after the tenth, where the source's first 10 rounds are the extra ones and rounds 11 to 30 stay at base. Our grenade matches (1.11x), the E beam is 1.49x. | Drop `sustain_loss` so rounds 11+ keep full damage and the first 10 get a bonus; settle 0.08 vs 0.12 s from footage first. |
| Kael (Brall) | LMB 0.65; combo 0.45 and 0.16 | Slash 8 is 5.2% of our target against 43 = 3.3% (1.56x, cadence 0.34 vs 0.35 s matches). Rampage hits 9 + tip 18 = 17.5% of the target against Flame Step 49 = 3.8% (4.6x); Warchain 5.2% vs 2.3% (2.2x); Smash 16.9% vs 10.1% (1.67x). Max rank adds +40% Smash and a shorter dash recharge on top. | Slash 8 -> 5, Rampage hit 9 / tip 18 -> about 2 / 4 (the tip doubling is ours), Warchain hit 8 -> 3.6, Smash 26 -> 15. |
| Cinder (Felix) | LMB 0.78, 0.76; combo 0.76, 0.61 | Stream 25.6% of the target a second vs 20.1% (258 of 1285). Cinder Shot 13.1% vs 8.2% (1.59x); the dash 0.70x and the cloak 0.76x are under. | Stream damage x0.8; Cinder Shot 20 -> 13; dash x1.4, cloak x1.3. |
| Sparkle (Joule) | combo 0.30, 0.20 (LMB 1.00 and every ability 1.00 since the damage set below) | Damage is at the source's share of the target: bolt 9 (every 0.648 s, owner items 70 and 116), Storm Rod 16 to 26.7, Wirerun 18.3, Skycall 19.4. The combo is fast from the passive loop the source side leaves out: the Rod's charge orb gives the Wirerun back at about 1.3 s, and that run goes through a 4-Static foe, so it hits double and Blowouts (16 + 18% of health). With the orb switched off (a test only) the same numbers knock in 8.13 s and 6.62 s (0.90, 1.03). The source has the same loop (Voltaic Spear's orb resets Surge; Surge through 4 Static is "massive bonus dmg + CD reset") but no number for it. | Owner: model the source's orb reset and Blowout on the source side (needs a number for "massive"), or an override in DECISIONS for the combo rows. Not a damage-number gap. |
| Albert (Oath) | LMB 0.73; combo 0.71, 0.73 | Hammer 12 is 7.8% against 192 of 2365 = 8.1% (match). Ours alternates throw and recall hits faster than 0.45 s (about 3.3 hits a second against 2.2); if the source recall hits as well, as the tooltip's "recall (192 dmg)" may mean, the source is 3.4 s and the ratio 1.45, still out. Spin Dash is at parity (1.01x). | Settle whether the source recall deals damage, then set throw_rate or recall_dmg. |
| Motley (Void) | LMB 1.91; combo 2.15, 1.74 | Orb 9 is 5.8% of the target against 263 of 2365 = 11.1% (0.53x). Spear 0.53x, bomb 0.59x. The whole kit sits about half the source. Held fire never charges (owner item 60, DECISIONS line 162 -15%). | Orb 9 -> 17, spear x1.9, bomb x1.7. |

Within the bar: Sable at both ranks (0.85 to 0.95; Bola now 3 / +6.1, the source's share), Sparkle LMB (1.00), Vex combo rank 0, Albert combo max.

**Lace (Myth), shares of the target with no LMB anchor** (source level 1 against 1285, ours against 154; not tuned, no check row: the check's RMB tap does not loose her held Heavy Shot): Heavy Shot 16 to 30 is 10.4 to 19.5% against Heartpiercer 35 = 2.7% (3.8 to 7.1x), its wall hit +79 to +148 against +173 = 13.5% (3.8 to 7.1x); Hail Wall 10 a second is 6.5% against Rain of Arrows 61 = 4.7% a second (1.37x); Starpiercer 18 / 18 / 23.3 is 11.7 / 11.7 / 15.1% against 326 / 326 / 422 = 25.4 / 25.4 / 32.8% (0.46x). The third beam keeps the source's 422 : 326 = 1.29x (25 -> 23.3). At the source's shares: Heavy Shot about 4.2, wall +20.7, Hail Wall 3.7 a tick, Starpiercer 39 / 50.6.

**Not done here:** no tuning past Sparkle and Sable; the five Hunters with no LMB number (and their combos) need the source's LMB damage, which no file in briefs has.
