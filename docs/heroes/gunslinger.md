# Venator (archetype id `gunslinger`, Medium; was Marlowe)

Internal design note (may cite the source for traceability; nothing in the game does).
Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (reference
sheet: briefs/hero-ref/venator.md, from the source's real segment; owner notes override the footage).
Our hero is an original character, the ember-rifle skirmisher: a visored cap, a cropped jacket, a long
streaming scarf, a bandolier of spiked charges, one bronze pauldron and a long-shrouded drum rifle.
Palette: ember orange, bronze and hot white. Payoff word: SKEWERED.

## Kit card (L picker)
- Role: Mid-range rifleman: Daze a foe with the grenade's cone, then shred them while it lasts.
- LMB, RMB, E, Shift, passive: one plain line each in `content/archetypes/gunslinger.json` `card`.

## Scaling
Our Medium has 145 HP against roughly 1.4k to 1.6k, about 1/10. Rifle 6 per round, decaying to half
over a 10-round string; on a Dazed foe +90% (the source reads about 1.9x) with no decay. Grenade cone 16,
Longneedle 36. Cooldowns follow the source ratio 5.4 : 7.5 : 10 at our pace 6.5 : 8.5 : 11.5. Ranges use
1 bh = 1.8 m: rifle 11 m, grenade lane 10.5 m (about 6 bh), cone 6 m (3.5 bh), Longneedle 18 m (10 bh),
slide tap 4.6 m and hold 7 m.

## Per-slot table
| Slot | Input | Aim | What it does | Telegraph / reticle | Move (KMovesVV) | Sound |
|---|---|---|---|---|---|---|
| LMB Quill Rifle | hold | max range (11 m) past the cursor, `"aim": "max"` | auto rifle; a string loses half its punch over 10 rounds; a Dazed foe takes +90% in big gold numbers and the string doesn't decay | the aim line runs to full range; ember tracers with a cooling tail, a bronze muzzle star | `gunslinger_lmb` (shoulder kick per round) | `vn_rifle` |
| RMB Burr Charge | hold to aim, release to throw | max range, a fixed 10.5 m lane | flies the whole lane, **past people** (owner), and sticks to a wall or the ground at the lane's end; a 6 m, 100° cone back toward you for 0.9s, then the blast: 16, a big shove along the cone, Dazed 1.4s; a hunter shoved into more terrain is stunned 0.7s and the cooldown drops 40% | while held: a white lane with an arrow tip, foes inside it marked with a magenta ring; when stuck: the filling cone (everyone sees it); the blast front and a Dazed swirl | `gunslinger_rmb_hold` (cocked overhead), `gunslinger_rmb` (overhand) | `vn_cock`, `vn_throw`, `vn_stick`, `vn_blast` |
| Shift Slipstep | tap / hold | where you move, not the aim | tap 4.6 m skid, hold 7 m slide; you shoot through either; early release refunds 30%; an air tap slides 2/3 of the hold distance | none (a white ring and an ember afterimage at the start) | `gunslinger_dash` (feet first, leaning back, rifle up); with no charge in the air `gunslinger_dash_ex` | `vn_slide` |
| E Longneedle | press, stand still 0.6s | direction, a fixed 18 m line through terrain | a beam through everything in line: 36, +20% on a Dazed foe, a Dazed hunter is Skewered (payoff); a hunter hit takes 30% off the cooldown; the recoil shoves you back a step | a wide bright line narrowing to a thin core over the cast (everyone sees it); cursor charge ring; muzzle orb, flat flare, smoke ring | `gunslinger_e` (brace, recoil overshoot, settle) | `vn_ion_charge`, `vn_ion_fire`, `hero_skewer` |
| Passive Hot Streak | | | a knock gives Slipstep back and heals 25%; abilities that land add Fever (4 x 5% lifesteal, 3.5s, all at once) | pips over the cap; a column and ring on a knock | `gunslinger_knock` (rifle spun up) | `vn_stim` |
| R | | | the Boki Merge (dropped ult) | | | |

## Combinations
| Combination | What fires | Check |
|---|---|---|
| Grenade past a foe, ground cone back over them | Dazed, shoved toward you | `--gunslinger-combo-check` |
| Dazed foe + rifle | +90%, gold numbers, no decay | `--gunslinger-combo-check` |
| Dazed foe + Longneedle | +20%, Skewered on a hunter | `--gunslinger-combo-check` |
| Grenade on a wall, foe shoved into terrain | stun + cooldown -40% | `--gunslinger-combo-check` |
| Longneedle hit on a hunter | cooldown -30% | `--gunslinger-combo-check` |
| Slipstep while firing | rounds keep going, the slide follows the keys | `--gunslinger-combo-check` |
| Knock | Slipstep back, heal; rank 3 resets the grenade | `--gunslinger-combo-check` |
| Stun during the Longneedle cast, or a Boki merge | cast cancelled, nothing fires | `--gunslinger-combo-check` |

## Small mechanics
| Mechanic | Source | Footage | Built and checked |
|---|---|---|---|
| Rifle damage decays over the first 10 rounds to 50% | [wiki: Ghost](https://supervive.wiki.gg/wiki/Ghost) (rifle) | numbers 60 to 30 | yes: data asserted |
| Bonus damage to Dazed targets | [wiki](https://supervive.wiki.gg/wiki/Ghost) | 1.9x yellow numbers | yes: "+90%", gold numbers |
| Wall blast: cone, knockback, launched into terrain = stun, cooldown -40% | [wiki](https://supervive.wiki.gg/wiki/Ghost) (Spike Grenade) | cone shown | yes |
| Combat Slide: tapped in the air for 2/3 of the full-hold distance | [wiki](https://supervive.wiki.gg/wiki/Ghost) patch 05.03.25 | not shown | yes: "an air tap slides 2/3 of the full hold" |
| Released early on the ground: cooldown reduced | [wiki](https://supervive.wiki.gg/wiki/Ghost) | not shown | yes: "let go early, part of it comes back" |
| Knocks reset the slide | [wiki](https://supervive.wiki.gg/wiki/Ghost) | not shown | yes |
| The omnivamp stacks wear off all at once | [wiki](https://supervive.wiki.gg/wiki/Ghost) patch 05.03.25 | not shown | yes: "Fever wears off all at once" |
| Railgun pierces terrain and every target | [wiki](https://supervive.wiki.gg/wiki/Ghost) | crosses a chasm | yes: through a wall, two targets |
| The grenade sticks to dynamic objects (shields, barricades) | [wiki](https://supervive.wiki.gg/wiki/Ghost) patch 20.11.24 | not shown | partly: it sticks to terrain blocks; other heroes' walls that are blocks count |

## Assumptions (the video is silent or the owner overrode it; the owner can correct these)
- **Owner rule:** the grenade never goes off on a person: it flies past people and sticks to a wall or the ground at the lane's end. The ground cone, like the wall cone, points back toward the thrower.
- The throw comes on release of RMB (hold to aim); in the air it throws on the press.
- Dazed is our Rattled status (slow plus the damage window); it now applies to the training dummy too.
- Fever is toned down (4 stacks of 5%) rather than dropped: the footage build only had the knock reset, the later source keeps the omnivamp.
- The Longneedle has no movement while charging (self_slow 1.0) and its recoil is a short shove.
- A slide in the air spends a charge and stops short instead of carrying.

## R (ultimate) choice
Dropped: R is the Boki Merge. The source's placed zone is not needed for the loop.

## Engine notes
- Kit `scripts/arch/kits/gunslinger_kit.gd`; pooled looks `scripts/arch/kits/vv_fx.gd`; moves
  `scripts/match/kmoves_vv.gd`; rifle model `scripts/match/hero_arms_vv.gd`; sounds `tools/gen_vv_sfx.py`.
- Rattled ("Dazed" on screen) is a `KitStatus` status carried by the existing Net event. No Net change.
- Merge cleanup: `_drop_holds()` ends `needle`, `slide` and the grenade hold (`rmb_down`/`rmb_t`).
- Screenshots: `--vv-shots --shots-dir=<dir> --vv-hero=gunslinger`.
