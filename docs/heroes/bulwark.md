# Bulwark (id `bulwark`, Heavy) - accuracy pass

Behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (internal note; nothing of the source's names or look ships).

## Research summary
Sources (gameplay only, in our own words):
- The reference hero's public kit page and guides (see the Inspired-by table in docs/ARCHETYPES.md)
- The page's inline patch history: 11.12.24 (wall stun 1s to 0.5s, field heal -20%, no longer repairs a broken shield), 20.11.24 (field heal scales with shield), 05.02.25 (wind-down frames after throw and spin)

What the source does: a thrown hammer that passes through foes and can be recalled (and shows allies the ground around it); a hold-to-charge smash, full at 1.25s; a hold shield that blocks the front, with a bash on the dash key while it is up; a spinning dash that knocks, with a shorter plain dash during a smash; a healing field at the hammer that mends the shield only while it is raised; a travelling, stunning fissure ultimate; a passive where a bash or a full smash that knocks a foe into terrain or another foe stuns briefly and heals.

Where sources disagreed: the dash cooldown shows two values (11 / 7); read as full dash vs the short dash during a smash. The passive heal (250 of 1180 HP) is scaled to our Heavy class as 24 of 193. Chosen: latest patch values (wall stun 0.5, shield only mended while raised).
Version chosen: the latest listed (patch 05.02.25 and the current rank rows).

## Per-slot table (slot, input, our behaviour, source behaviour, difference and why)
| Slot | Input | Before | What it does now (our words) | Source behaviour | Difference and why |
|---|---|---|---|---|---|
| Passive | knock into wall/foe | Crushed: stun 0.8, heal 14 | stun 0.5 (latest patch), heal 24 (about 12% of the Heavy class's 193 HP, in line with the source's per-knock share); only Bash, Shield Charge and a full Crushing Blow count (Whirl does not) | Shield Bash or full smash into a wall/enemy stuns briefly and heals | Heal scaled to our health. The Guard meter (Shield Slam at 50) stays as our own loop |
| LMB | tap / again | throw the mace through foes, recall on a second tap | unchanged | Throw, recall hitting on the way, allies see around the hammer | Already matched; move set added |
| LMB | hold | Crushing Blow, full at 1.25s | unchanged, charge pose | Hammer smash, full at 1.25s | - |
| RMB | hold | Shield, Bash on tap/release | unchanged | Hold to block the front | Bash on tap is our extension (source puts the bash on Shift) |
| Shift | tap | Whirl | unchanged; plus a short plain dash while a Crushing Blow is charging (spends half a charge, the wind-up goes on) | Spin dash; with the shield up a bash that knocks; short dash mid-smash | Shield Charge stands in for the shield bash; the charge refund at rank 4 does not exist (our max rank is 3) |
| E (source Q) | tap | Mending Ground, mended the shield always | mends the shield only while it is raised; rank 2 healing +25%, rank 3 cooldown -20% | Field at the hammer, heals and mends shield only while up | Matches the 11.12.24 patch; no wisp revive in our game |
| R | - | Fissure | removed | Fissure ultimate | See Ultimate |

## Ultimate choice
The source ultimate (a stunning, erupting fissure) is flavour: the loop is block, knock into walls, heal. Dropped: the loop does not need it; no R (R is the Merge).

## Scaling
Heavy class (193 HP): shield 160 HP, Crushing Blow 14-34 and push 4-12, Bash 12, Slam 18, Crushed 8 + stun 0.5 + heal 24, Mending Ground 26 (+25% rank 2). Ratios from the source: smash 1.25s full, stun 0.5s, field cooldown 12s class.

## Cross-ability interactions
| Combination | Result | Check |
|---|---|---|
| Bash into a wall | Crushed: stun 0.5, heal | `--bulwark-combo-check` |
| Shield up, Shift | Shield Charge, Crushed on a wall | same |
| Whirl into a wall | knock only, no Crush | same |
| Half-charged blow into a wall | no Crush | same |
| Full Crushing Blow into a wall | Crushed | same |
| Hold LMB, Shift | short dash for half a charge, wind-up continues | same |
| Mace thrown, then E | Mending Ground blooms where the mace lies | same |
| E with shield down / raised | heals / heals and mends the shield | same |

## Animations (HunterAnim.KMOVES ids per ability)
| Ability | Move id(s) | Notes |
|---|---|---|
| LMB tap (throw) | `bul_throw` | |
| LMB tap again (recall) | `bul_recall` | |
| LMB hold (Crushing Blow) | `bul_smash_wind` (held), `bul_smash` | |
| RMB tap / release (Bash) | `bul_bash` | the raised shield itself has no move |
| Shift (Whirl) | `bul_whirl` | |
| Shift with shield up (Shield Charge) | `bul_charge` | |
| Shift during a charging blow | `bul_short` | |
| E (Mending Ground) | `bul_mend` | |
Frame strips live in the shots folder (see MANIFEST.txt); each is rendered by `--arena-shot=anim_<id>`.

## Engine notes
- Kit logic: `scripts/arch/kits/bulwark_kit.gd` plus `content/archetypes/bulwark.json`. No class R (`K.d` has no `r`); kit card, wiki generator and archetype check skip R rows.
- Crushed is decided by `_try_crush` (a foe, or terrain within `crush_reach` along the push) and only for Bash, Shield Charge and a full Crushing Blow; Whirl and half charges are excluded in code.
- The short dash during a Crushing Blow spends half a charge and leaves the wind-up running, so it is a kit-local state, not a new dash type.
- Mending Ground mends the shield only while it is raised; the shield is capped at its max (fixed in this pass).
- No Net shape change: rings use the existing `net_ring` fx event; stun and heal ride the normal hit path.
- Tooling: `--bulwark-combo-check` / `--hero-combo-check`, arena strips in `scripts/match/arena_demo.gd`.

## Payoff
CRUSHED: stun, heal, T4 hitstop and shake, own sound.
