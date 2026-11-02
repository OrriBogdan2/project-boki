# Bulwark (id `bulwark`, Heavy) - accuracy pass

Behaviour reference: the SUPERVIVE hero Oath (internal note; nothing of the source's names or look ships).

## Research summary
Sources (gameplay only, in our own words):
- https://supervive.wiki.gg/wiki/Oath (passive, every slot, ranks, patch notes inline)
- Patch lines on that page: 11.12.24 (wall stun 1s to 0.5s, field heal -20%, no longer repairs a broken shield), 20.11.24 (field heal scales with shield), 05.02.25 (wind-down frames after throw and spin)

Where they disagreed: the Shift cost/cooldown listing shows two values (11 / 7); read as full dash vs the short dash during a smash. Chosen: latest patch values (wall stun 0.5, shield only mended while raised).

## Source slots against ours
| Slot | Input | Before | After | Source behaviour | Difference and why |
|---|---|---|---|---|---|
| Passive | knock into wall/foe | Crushed: stun 0.8, heal 14 | stun 0.5 (latest patch), heal 14; only Bash, Shield Charge and a full Crushing Blow count (Whirl does not) | Shield Bash or full smash into a wall/enemy stuns briefly and heals | Heal scaled to our health. The Guard meter (Shield Slam at 50) stays as our own loop |
| LMB | tap / again | throw the mace through foes, recall on a second tap | unchanged | Throw, recall hitting on the way, allies see around the hammer | Already matched; move set added |
| LMB | hold | Crushing Blow, full at 1.25s | unchanged, charge pose | Hammer smash, full at 1.25s | - |
| RMB | hold | Shield, Bash on tap/release | unchanged | Hold to block the front | Bash on tap is our extension (source puts the bash on Shift) |
| Shift | tap | Whirl | unchanged; plus a short plain dash while a Crushing Blow is charging (spends half a charge, the wind-up goes on) | Spin dash; with the shield up a bash that knocks; short dash mid-smash | Shield Charge stands in for the shield bash; the charge refund at rank 4 does not exist (our max rank is 3) |
| E (source Q) | tap | Mending Ground, mended the shield always | mends the shield only while it is raised; rank 2 healing +25%, rank 3 cooldown -20% | Field at the hammer, heals and mends shield only while up | Matches the 11.12.24 patch; no wisp revive in our game |
| R | - | Fissure | removed | Fissure ultimate | See Ultimate |

## Ultimate decision
The source ultimate (a stunning, erupting fissure) is flavour: the loop is block, knock into walls, heal. Dropped; no R (R is the Merge).

## Scaling
Heavy class: shield 160 HP, Crushing Blow 14-34 and push 4-12, Bash 12, Slam 18, Crushed 8 + stun 0.5 + heal 14, Mending Ground 26 (+25% rank 2). Ratios from the source: smash 1.25s full, stun 0.5s, field cooldown 12s class.

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

## Animations (HunterAnim.KMOVES)
`bul_throw`, `bul_recall`, `bul_smash_wind` (held), `bul_smash`, `bul_bash`, `bul_whirl`, `bul_charge`, `bul_short`, `bul_mend`.

## Payoff
CRUSHED: stun, heal, T4 hitstop and shake, own sound.
