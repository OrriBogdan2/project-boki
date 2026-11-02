# Vireo (archetype id `mage`, Light)

Internal design note. This file may name the source hero for traceability; nothing in the game does.
Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md. Our hero is an original character, the storm-kite
runner: flight goggles, a cropped jacket, copper coils on both forearms and a copper rod mast flying a
pennant. Palette: teal and copper. Payoff word: BLOWOUT.

## Research summary
Sources (gameplay only):
- The reference hero's public kit page and guides (see the Inspired-by table in docs/ARCHETYPES.md)

Where they disagreed: the guides rank the Q (lightning strike) and RMB (spear) priorities differently
(Q first in team fights, spear first in duels); the spear's cast time was raised to 0.33s and the ult's to
0.3s in later patches, the dash blast radius shrank (200 to 160). We took the latest wiki values
(spear cast 0.33s, dash radius reduced) and built the kit around the dash-through-charged-target loop.

Version chosen: the wiki page values after the Leveling Rework patch, taking the later number wherever
a patch page and the ability page differ. Rank 4 source upgrades are mapped onto our rank 3.

## Scaling
Source health is roughly 8 to 10 times ours (Light = 124 HP). Damage numbers were scaled by about 1/9 and
rounded; cooldown ratios, ranges (units to metres at about 1/100) and the Spark count (4) were kept.
Coilcaster bolt 8 (about 19 dps), Coilshot 9 to 15, Wirerun pass 10, Skycall 14, Blowout 8 + 15% of
their max health (about 30 on a Light, 30 on a Medium).

## Per-slot table
| Slot | Input | Our text | Source behaviour | Difference and why |
|---|---|---|---|---|
| LMB | hold | **Coilcaster**: a copper forearm coil spits piercing bolts, 8 damage, each hit loads a Spark. | Jolt: piercing bolt, 1 Static stack | Same. Fixed signature weapon (`coilcaster`). |
| Passive | | **Sparks**: bolts, Coilshot and Skycall load Sparks (max 4, 4.5s, refreshed). 4 = Live: crackling pips everyone sees. Wirerun through a Live foe is a **Blowout**: 8 + 15% of their health, a T4 payoff, Sparks spent, dash back at once. A knock heals 15% of your health. | Static Charge: 4 stacks; Surge through = big damage, full Surge reset, mana; knock restores health | No mana in Boki, so the mana refund is dropped. Knock heal is 15% (source 250 HP of about 1.2k). |
| RMB | hold, release | **Coilshot**: wind up 0.33 to 1.0s; 9 to 15 damage, 6 to 13m, a throw of 8 to 14. A foe thrown into a wall or another foe is stunned 0.8s (so is the one it hits). A hit on a hunter drops a charge mote 0.5s later; collecting it refills Wirerun. | Voltaic Spear: hold 1s max, first-hit knockback, stun on collision, Lightning Orb after 0.5s resets Surge | Stun is an instant check along the throw (no travelling collision). Orb is a mote (6s life). |
| Shift | hold, release | **Wirerun**: a lane grows 4 to 7m over 0.45s (everyone sees it); let go to streak. Shots pass through you for the run, every foe crossed takes 10 (double at rank 3). Stun, root or Grounded cancel it. Air press: plain long dash that also lets shots through. | Surge: hold-release dash, projectile-immune, damage on pass, reset on a charged foe or an orb | Same. Not reset by a knock (as source). |
| E | tap | **Skycall**: marks a spot up to 9m (a filling ring), 0.55s later lightning: 14 damage, a Spark, everyone inside is flung along your aim and **Grounded** 1.2s (no dashing). Catches a charge mote and steals a rival's. | Lightning Strike (Q): hold to place, delayed bolt, launch, grounded, orb stealing | Placement is the cursor on the press (our E has no hold-to-place). |
| R | | none | Thunderstorm | See below. |

## R (ultimate) choice
Dropped. In the source the storm is a stack applier and a mobility tool, not the loop itself: the loop
(Jolt, Q or spear to 4 stacks, then dash through) is complete without it. Q already applies a stack and
the spear's mote already resets the dash. If Merge later wants a stack-spreading effect, Sparks has
`add_spark(f, n)` ready.

## Combinations
| Combination | What fires | Check |
|---|---|---|
| 3 weapon Sparks + Coilshot | the 4th Spark: foe is Live | `--mage-combo-check` |
| Wirerun through a Live foe | Blowout (payoff), Sparks spent, dash refunded | `--mage-combo-check` |
| Wirerun through a foe with fewer than 4 Sparks | plain pass hit, no reset | `--mage-combo-check` |
| Wirerun while shots fly | shots pass through; stun/root/Grounded cancel it | `--mage-combo-check` |
| Coilshot into a wall | stun 0.8s | `--mage-combo-check` |
| Coilshot into another foe | both stunned | `--mage-combo-check` |
| Coilshot on a hunter, then pick up the mote | Wirerun refunded | `--mage-combo-check` |
| Skycall over a rival's mote | the mote is flung and becomes yours | `--mage-combo-check` |
| Skycall as the 4th Spark, then Wirerun | the chain: Live then Blowout | `--mage-combo-check` |
| Skycall Grounded on a foe, or on you | no dashing; Wirerun cannot start | `--mage-combo-check` |
| Knock | heal 15% | `--archetype-check` |

## Animation moves (`HunterAnim.KMOVES`)
| Ability | Move id | Look |
|---|---|---|
| LMB Coilcaster | none (stock firing pose) | the bolts and forearm glow carry it |
| RMB Coilshot | `mage_rmb` | coil drawn back, lunge and palm thrust, recover |
| Shift Wirerun (lane growing) | `mage_dash` (held) | sprinter's crouch, both arms back |
| Shift Wirerun (released) | `mage_dash_go` | flat-out streak, arms trailing, easing to stride |
| E Skycall | `mage_e` | one hand to the sky, slammed down at the mark |
Frame strips: `strip_mage_*.png` in the pair's shots folder.

## Engine notes
- Grounded and Rattled are `KitStatus` statuses carried by the Net event `["kst", nid, kind, seconds, k]`
  (Net 0.7.0, already on main): the body's own game runs the rules, every game shows the look. Remote
  players do not run the kit, so they see the Live pips only as the Net ring pulse, not the per-target pips.
- No new Net events or state keys: this branch keeps main's Net version.
- Kit: `scripts/arch/kits/mage_kit.gd`, data `content/archetypes/mage.json`, weapon `content/weapons/coilcaster.json`.
  Look: `scripts/match/hero_gear.gd`. Gallery and screenshot hook: `scripts/arch/hero_demo.gd` (`--hero-demo`).
- Blowout has its own sound `hero_blowout` (`tools/gen_hero_sfx.py`, pure Python).
- `scripts/arch/hex.gd` is unused by this kit now; it is filed in `docs/DEBT.md` for removal with the `"hex"` event.
