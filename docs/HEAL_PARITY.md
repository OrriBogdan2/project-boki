# Heal and shield parity: 12 Hunters against the source (2026-11-09)

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). Companion to [KIT_PARITY.md](KIT_PARITY.md); damage, crowd control and health are audited elsewhere. Ideas of ours are in "Not built", nothing else was added.

**Evidence.** [D] game data (briefs/supervive-data/supervive_kits.md on origin/ext/agent-briefs), [F] footage sheets (briefs/hero-ref, 5 fps, 0.2 s a frame), [W] the wiki page of the source hero (read 2026-11-09, level-1 numbers), [O] owner note. Order of trust: O > D > W > F. Source health at level 1 [W]: Elluna 1030, Oath 1180, Felix 1367, Ghost 980, Brall 1205, Shiv 980, Kingpin 1531, Myth 880, Tetra 1290, Void 1030. Ours: light 124, medium 145, heavy 193. A source flat number is turned into a share of its own health, then of ours.

**Verdict.** `match` within rounding; `differ` built, not the same; `open` the source gives no number (ours kept); `owner` an owner call, see below. Hunters: Meeko = tender (Elluna), Albert = bulwark (Oath), Tenzo = dolm (Tetra), Cinder = ashwick (Felix), Vex = gunslinger (Ghost), Kael = juggernaut (Brall), Sable = thief (Shiv), Grimble = dredge (Kingpin), Lace = archer (Myth), Neve = rimewright, Sparkle = mage, Motley = ostra (Void).

## Heals and shields

| Hunter, ability | Ours | Source | Verdict | Evidence |
|---|---|---|---|---|
| Meeko E Hearthlight, heal | 10 over 2.5 s, burst 22 (15.2% of 145); 11 s | burst 90 (+54% AP) = 8.7% of 1030, "over 2.5 s", 12 s | differ: burst about 1.7x as large as a share of health; over-time part has no source number | [W] Elluna; tender.json `e` |
| Meeko E, self and Wisp | self 33%, downed teammate 500% | self 33%, Wisp 500% | match | [W]; `--support-check` |
| Meeko E, thrown | 9 m, 1 s of +50% (+100% at rank 3), latches on | 1 s boost after the throw, doubled at rank 4; number not listed | open | [W]; tender.json `rank_next` |
| Meeko E ranks | cd -10%, heal +15% (r2); cd -20%, +30% (r3) | +22.5%, +27.5%, -3 s, boost doubled | differ: the shared 3-rank scheme folds four tiers | [W]; tender.json |
| Meeko R Hearth Call | 7 a second for 5 s = 35 (24.1% of 145); 46 s | 28.2 (+6% AP) a second for 5 s = 141 (13.7% of 1030); 60 s | differ: about 1.8x as a share of health (cooldown is the 0.76x scale, gap 10) | [W]; tender.json `x` |
| Meeko R, downed ally | heal goes to her, then they stand and are pulled to her | same | match | [D] kits.md R; `--support-check` |
| Meeko passive Carrier shield | none (cut) | Soulpack: shield 200 to 450 by level (19% to 44% of 1030), refilled on pickup | owner: cut by DECISIONS 2026-11-07 ("ours-only riders") on the belief it is ours; the wiki says the source has one | [W]; DECISIONS |
| Albert E Mending Ground | 2 every 0.5 s for 4 s, burst 18, aegis mend 60; 12 s | scales with max health; no amounts listed; 12 s; patch 11.12.24 -20% | open | [W] Oath; bulwark.json `e` |
| Albert E ranks | r2 heal +25%, r3 12 -> 8 s and +50% in all | L2 +25%, L3 -4 s, L4 +25% | match (L3 and L4 folded) | [W]; `--bulwark-combo-check` |
| Albert RMB Brightshield | 160 shield, regen 20 a second (30 at r3), rank +25% / +50% | blocks all frontal damage; shield amount and regen not listed; L2 and L4 +25% | open (ranks match) | [W]; bulwark.json `rmb.shield` |
| Albert passive | wall stun 0.5 s, 8 damage, no heal | wall stun 0.5 s; [D] "no heal"; [W] adds "restores 250 on a knock" | owner: the data and wiki disagree, data kept | [D], [W] |
| Tenzo Molten Guard | punch at a rock: 18 shield per punch, 4 stacks, 6 s (12.4% of 145 a stack) | tooltip: temporary shield, no number; [W] Volcano Crusher L4: 250 per slam or rock, 4 stacks = 19.4% of 1290 | open: 18 comes from the data's level-15 share, the wiki share would be 28 | [D] kits.md Tetra; [W]; dolm.json |
| Cinder E Furnace Cloak shield | 6.4% of max health + 5.1% per foe hit, 3 s | same | match, now asserted | [W] Felix; `--ashwick-combo-check` "cloak: Anti-Heal 3s and a shield of 6.4% + ..." |
| Cinder E ranks | r2 +15%, r3 +30% and 30% more | L2 and L3 +25%, L4 +50% | differ: shared rank scheme; ashwick.md lists it | [W]; ashwick.md |
| Cinder Shift rank 3 | 11.6% of health, 2 s, +16% speed | 150 shield, 2 s, +75 speed (150 of 1290 = 11.6%) | match | [D] kits.md Felix |
| Vex omnivamp | one flat 6% for 3.5 s from any ability hit that is not LMB | [D] flat +6% for 3.5 s; [W] "stacking 6% for 3.5 s" (8% cut to 6%, patch 19.03.25) | match to [D]; the wiki's stacking is not built (gunslinger.md row, wears off all at once) | [D], [W]; `--gunslinger-combo-check` "Fever is one flat level of 6%" |
| Kael R Gilded Riposte heal | 80% of damage dealt | [F] card "heals for 80%"; [W] "Heal for 60% of damage dealt" | differ, unsettled: card and wiki disagree, may be a patch | [F] juggernaut.md l.217; [W] Brall |
| Motley Trade, rank 3 | allies beside him: 26 shield, 3 s (17.9% of 145) | [D] 375, 3 s; [W] 300, 3 s = 29% of 1030 (42 on 145) | open: 26 uses the data's level-15 share; duration matches | [D], [W] Void; ostra.json |
| Neve, Sparkle | none | none in [D] (Celeste, Joule) | match | kits.md |

## Heal on a knock

Ours is the shared takedown reset (`DashReset.HEAL`, 5% of max health, dash back) plus a kit extra. The source [W] has a flat heal on every hunter fetched but Tetra. [D] lists a knock heal only for Brall and Shiv. `ext/heal-knock-source` (READY, not on main) settles the Brall/Shiv/Felix/Kingpin extras against the data and asserts the totals; the rows below agree with it, and its premise "the data has no heal for Felix and Kingpin" is now weaker: the wiki has 250 for both.

| Hunter | Ours (kit + shared 5%) | Source | Verdict | Evidence |
|---|---|---|---|---|
| Meeko | 5% | 500 = 48.5% of 1030 | differ (owner call, see below) | [W] Elluna |
| Albert | 5% | none in [D]; [W] 250 = 21.2% | owner, see Albert passive | [D], [W] |
| Tenzo | 5% | none | match | [W] Tetra |
| Cinder | 16% + 5% = 21% | [W] 250 = 18.3% of 1367 | match within 3 points | [W] Felix |
| Vex | 5% | 500 = 51% of 980 | differ (owner call) | [W] Ghost |
| Kael | 20% of the knocked hunter's max + 5% | [W] "20% of the enemy's max health" (also on a creep kill) and a flat 250 | match | [W] Brall; [D] |
| Sable | knock 15% + 5% = 20%, assist 25% | knock 250 = 25.5% of 980, assist 25% | knock 5 points low; assist match | [W] Shiv; [D] |
| Grimble | 16% + 5% = 21% | 250 = 16.3% of 1531 | match within 5 points | [W] Kingpin |
| Lace | 5% | 500 = 56.8% of 880 | differ (owner call) | [W] Myth |
| Motley | 5% | 500 = 48.5% of 1030 | differ (owner call) | [W] Void |
| Neve, Sparkle | 5% | not read | open | |

## Anti-heal

Ours: one rule for all (`Ent.blight_t`, healing and regen cut 60% while it lasts, `KitStatus` "blt"). The source gives the duration on its pages and no percentage anywhere.

| Hunter, ability | Ours | Source | Verdict | Evidence |
|---|---|---|---|---|
| Cinder E | 3 s | 3 s | match, asserted | [W] Felix |
| Kael E spin (Scorching Spin) | 5 s (was 4) | 5 s | fixed, asserted | [W] Brall; `--kit-combo-check` |
| Sable R outer ring | 6 s | 6 s | match | [W] Shiv; `rim_blight` |
| Grimble R | 3 s a slug | "Anti-Heal" on each wave, no duration | open | [D], [W] Kingpin |
| Lace E | 1 s, refreshed every 0.5 s in the wall; 2.5 s after a cremation | "applies Anti-Heal", no duration | open | [D], [W] Myth |
| Percentage | 60% | not listed | open | |

## Fixed in this branch

1. Kael's Cinder Spin Anti-Heal 4 s -> 5 s (`content/archetypes/juggernaut.json` spin and its text); asserted in `--kit-combo-check` ("combo jug: the spin's Anti-Heal lasts 5s ... cuts healing 60%").

Also added: the Cinder cloak row asserted exactly (`--ashwick-combo-check`). Nothing else was a clear number without an owner note: the rest is below.

## Not fixed (for the owner or a source number)

- Knock heal: Meeko, Vex, Lace and Motley get 5% where the wiki has about 50% (Albert, Sable, Cinder, Grimble 16% to 25%). Changing it is a balance call, not a typo.
- Meeko E and R sizes (1.7x to 1.8x as a share of health) and the Hearthlight over-time part (no source number).
- Kael R: 80% (card) against 60% (wiki).
- Tenzo's 18 and Motley's 26 are the data's level-15 share; the wiki's level-1 numbers would give 28 and 42.
- Sable's knock total 20% against 25.5%: with `ext/heal-knock-source`.
- Meeko's Carrier shield: the source has Soulpack (200 to 450 by level); the owner cut ours.
- Cinder's and Meeko's rank steps differ by design (three ranks).

## Not built (ideas of ours)

A universal flat knock heal as the wiki shows it; Soulpack back as a pickup shield; the wiki's stacking omnivamp; a separate Anti-Heal percentage per source.
