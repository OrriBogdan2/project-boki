# Dolm (archetype id `dolm`, Medium)

Internal note: the behaviour reference is the SUPERVIVE hero Tetra. Nothing below is player-facing; every name, number and
word in the shipped game is our own (renames done in the finish pass: Stonesight -> Tremor Sense, Landslide -> Rubble Rush,
Rockwave -> Stone Row, which had matched the source names).

## Research summary
- Sources read: https://supervive.wiki.gg/wiki/Tetra (ability text, level table; the Patch History section is empty),
  plus the shared kit conventions in docs/ARCHETYPES.md and docs/DASHES_AND_ABILITY_FEEL.md (Tetra rows: dash and kit cohesion).
  The wiki gives no ranges, stun times or damage numbers for this hero, so ours are derived from our own time-to-kill.
- Where sources disagree: none. The only mismatch is internal: the page lists the wall under Q and has no E; our kit
  uses E for the wall (ours has no gear-Q conflict because gloves own Q, but the E slot is the kit slot for a tool).
- Version chosen: the page as of Nov 2026 (the game shut down Feb 2026, so these are final values).
- Copied: structure and interactions (sneak-reveal, tap boulder / hold punch, wall stun, charged slam with jump-leap and
  abyss dunk, dash that launches a rock, three-rock wall, ult that makes terrain over the abyss). Not copied: names, text,
  numbers, art, sound.

## Design
Weight Medium (145 hp, 5 m/s, 1 dash charge). Fixed weapon Rubble Fists (`content/weapons/rubble_fists.json`, hero_only so it
never drops as loot). Palette ochre stone `#d9a35b`, umber and pale sandstone; stone-plated shoulder, chest slab, rubble collar,
bare head under a stone brow band (GearPair). Payoff word ROCKFALL (sound `pay_rockfall`, synthesised by tools/gen_pair_sfx.py).

## Scaling used
- Health class Medium; base kit numbers set so a full-health Medium dies to roughly 6 clean hits or one slam plus a launched rock.
- Rank 2 (shared step): cooldown -10% and +15% damage on RMB and E, dash recharge 9s -> 7.6s. Rank 3 (the source's level 4
  specials): RMB cooldown 10 -> 8s and +30% damage with the shield, dash +1/3 distance, E second row and bridge.
- Boulder 9 dmg / 0.6s at 11m; punch 12-24 over a 0.28-0.9s hold; slam 14-30 with radius 1.7-2.7 and centre stun 0.5-1.2s;
  rocks 45 hp, 9s life, launched rock 14 dmg. Wall stun 0.9s stays under the soft-CC stun cap (0.8 hard, 1.0 for charged melee).
- No rank scaling on the passive (source has none).

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Tremor Sense | sneak | foes in a 70 degree cone within 16m show as stone rings through walls and fog, refreshed every 0.5s | sneaking reveals enemies in front, outside vision | ring markers instead of a hard reveal so it reads on our fog; cone and range ours |
| LMB Rubble Fists | tap / hold + release | tap: boulder 9 dmg, 11m, 0.6s. Hold 0.28-0.9s: punch cone 2.7m, 12-24 dmg, throws foes back, wall stun 0.9s, launches rocks in reach (3.4m) | tap throws a rock, hold punches enemies and rocks, wall = stun, punched rocks shred armor | a burst rock applies Shred (+15% damage taken, 3s) because we have no armor-shred stat |
| RMB Quakefall | hold to charge, release | slam 2.4m ahead, radius 1.7-2.7, damage 14-30, centre stun 0.5-1.2s, rocks in the ring fly outward; 10s cooldown; a knock or kill resets it; in the air a dive that slams on landing, foes in the air are dunked (+40%, +20 over the abyss) | hold to charge, release to slam; centre stuns; dunk over the abyss; jump while charging leaps | the air press dives instead of leaping while charging (we have no charge-jump input); reset-on-knock is ours (the loop reward) |
| Shift Rubble Rush | tap | 4.2m barrel, a boulder shoved ahead rockets 12m at the end, 12 dmg + Shred, 9s | makes a rock, dashes, launches it forward at the end | the boulder is created at the dash end so placement rules apply once, not twice |
| E Stone Row | tap | three rocks in a line 3m ahead, 9s life, 45 hp, block bodies and enemy shots, 13s | wall of three rocks, ground only, allies hop over, level 4 adds a second wall | allies cannot hop (our walls are solid to all); placement via HeroZones |
| R Tetraform | none | folded into Stone Row rank 3: second row and, aimed over the abyss, a temporary rock bridge (9m, 6s) | big wall angled by dragging, makes terrain over the abyss, slowing rocks | no angle drag (no R input for classes any more); see ult choice |

## Ult choice
Folded into Stone Row rank 3 (bridge and second row) and not kept as a separate R: R is now the Boki Merge (BRIEF_UPDATE4), and the
terrain-over-the-abyss identity is the part of the ult that matters, so it lives on the wall the hero already uses. The source
ult's slowing rocks and drag angle were dropped.

## Combinations (`--dolm-combo-check`, `--zone-check`; both run tools/hero_pair_check.gd)
| Combo | Result | Asserted by |
|---|---|---|
| Punch into a wall | stun 0.9s | `combo: punch into a wall = stun` |
| Tap vs hold | boulder / punch with knockback and charge shown | `lmb: tap = boulder`, `lmb: hold + release = punch, knocks back`, `lmb: hold shows a charge` |
| Stone Row then punch | rocks launch, burst, Shred, ROCKFALL on a hunter | `combo: Stone Row > punch launches the rocks` |
| Stone Row then slam | rocks fly outward from the impact | `combo: Stone Row > slam launches the rocks` |
| Slam centre | stun scales with charge | `rmb: tap slam hits the centre and stuns`, `rmb: a full charge hits harder` |
| Slam that knocks or kills | Quakefall resets | `combo: a slam that knocks resets Quakefall` |
| Slam on a foe in the air | dunk, spiked down | `rmb: a foe in the air is dunked` |
| Rubble Rush | boulder at dash end, Shred | `dash: Rubble Rush shoves a boulder as it ends` |
| Rank 3 slam | shield stacks | `rank 3: slamming a foe gives a shield` |
| Rank 3 Stone Row | second row | `rank 3: Stone Row raises a second row` |
| Rank 3 over the abyss | bridge, solid ground untouched, abyss restored | `bridge (rank 3): abyss tiles become ground`, `bridge: solid ground is never changed`, `bridge: the abyss comes back when it ends` |
| Sneak | rings, front only | `passive: Tremor Sense shows foes in front only` |
| Placement | rocks only on legal ground: not at an abyss edge, through walls or bodies | `stone row: ...` assertions in `_zones` (legal ground, collision, abyss ahead, edge, not through a rock, not inside a body) |
| Net | rocks, launches and the bridge rebuild identically on a second game | `net: ...` assertions (announced, same places, remote rocks block, launch removes, bridge rebuilt) |

## Animation moves (HunterAnim.KMOVES)
| Ability | Move id |
|---|---|
| LMB boulder | `dolm_lmb` |
| LMB punch held / released | `dolm_wind` (hold) / `dolm_punch` |
| RMB Quakefall held / released | `dolm_rmb_wind` (hold) / `dolm_rmb` |
| Rubble Rush | `dolm_dash` |
| Stone Row | `dolm_e` |
Stance entry `dolm` in the body-stance table (lean 0.08, wide knees). Strips: `--arena-demo=anim_dol_boulder|dol_punch|dol_dash|dol_slam|dol_wave`.

## Engine notes
- Kit: `scripts/arch/kits/dolm_kit.gd` (ArchKit subclass), data in `content/archetypes/dolm.json`, weapon `rubble_fists.json`.
- Rocks and bridges go through `scripts/arch/hero_zones.gd` (HeroZones): solid ground within a step of the caster, no blocker
  tiles, no walls or rocks, no bodies inside, line of sight from the caster, never over the abyss. Bridges only replace abyss tiles
  and restore them. Rocks are Verbs walls (`rock: true`), so they use existing collision.
- Net 0.14.0: `["zone", ...]` events (rock, rockgo, bridge, seed, pop) through the existing "ev" topic; this is the only sync change.
- Look: `scripts/match/gear_pair.gd`, `hero_arms.gd`; kit card: `kit_card.gd` shows kits without R.
- Bot: `bot_use` in the kit (Stone Row when foes close in, punch/slam at range, dash for the boulder).
- Checks: `--zone-check`, `--dolm-combo-check` (register in main.gd with three lines); screenshots via `scripts/arch/pair_demo.gd`.
