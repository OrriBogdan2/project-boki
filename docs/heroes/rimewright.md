# Tamsin, the Rimewright (`rimewright`, light skirmisher with a shelter)

Internal design doc. Source behaviour reference: SUPERVIVE's Celeste (gameplay only).

## Research summary
Sources:
- https://supervive.wiki.gg/wiki/Celeste (abilities and upgrade tables; the only source used)
- a patch-note search returned only other games' Celeste patches, nothing SUPERVIVE-specific.

Version chosen: the wiki's current kit as it stood when the branch was built (late Oct 2026).
Important finding: in the source Celeste is an ice damage and control hero, not a healer, although the task brief calls both heroes healers. We kept the source behaviour and gave her the squad-facing part through the Rink Wall (a frost shield for teammates who touch it, once per wall). Flagged as an open question.
Where the wiki has no E (Q is the wall): we map the wall to E (Q is the glove slot).

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Hoarfrost | | Damaging abilities Chill for 4s (slightly slower, frost mist). Knocking a Chilled hunter, or felling a Chilled monster, makes them Splinter 0.4s later: 30 damage within 3m and more Chill | Shatter (Chill) | Chill carries a 15% slow so the state is readable and useful |
| LMB Hoar Fan | hold | Flurry: 4 light homing shards (3.4 each, 0.1s apart) then 3 heavy ones (x2 damage, faster, 1.4x range), 0.5s pause. 8 shards on one foe Splinter them (20, 2.4m). Double damage during a Rinkrun | Ice Darts | Homing is a soft turn rate (2.4 rad/s inside a 40 degree cone) |
| RMB Sleet Lance | tap, 2 charges | Lance 22 m/s, 12m: 12 damage (x0.8 close to x1.25 far), slow 55% close to 20% far, Chills; goes off again 0.7s later for 15 in 1.8m (rank 3: 45% bigger) | Cryo Spear | Same shape; near/far tradeoff kept |
| Shift Rinkrun | hold | Rinkrun at 11.5 m/s up to 1.6s, steering gently; release stops; stopping early refunds up to 60% of a charge. Fan keeps firing and does double damage. In the air: the usual long dash | Skate | Rank 3 ice-bridge-over-abyss left as a visual puff only (no terrain editing yet; open question) |
| E Rink Wall | tap, tap again | 4.2m wall (70 HP) slides 3.2 m/s for up to 4s, stops enemy shots, shoves foes; press again to freeze it (lasts 8s). Teammates touching it get an 18 frost shield (6s), once per wall; online squadmates receive it as a heal | Frozen Barricade | Uses the shared wall system (`Verbs.add_wall`) |
| R | none | Removed per owner update | Chilling Finale | Flavour: a panic button; does not feed the Chill and Splinter loop |

## Scaling
Light HP 124. Fan 3.4 per shard against 12 lance and 30 Splinter keeps the source ratio (about 1 : 4.6 : 10). Ranks follow the per-slot steps in `rank2` / `rank_next` of the JSON (about 10% shorter cooldown and +15% power at rank 2, about 20 to 25% shorter and +30% at rank 3), with the rank-3 effects: (second lance burst 45% bigger, a Rinkrun over open sky lays a short ice bridge as a visual only, the wall +40 HP and a doubled frost shield).

## Ult choice
No R. The source's finale is a panic button that does not feed the Chill and Splinter loop, and R is now the Boki Merge. Nothing was folded in; the squad value comes from the Rink Wall instead.

## Combinations
| Interaction | Check |
|---|---|
| Fan darts Chill; Chill slows | `--rimewright-combo-check` ("fan darts Chill") |
| Rinkrun doubles the fan; Shift held starts a Rinkrun; early release refunds | same |
| 8 shards on one foe Splinter them | same |
| Lance: Chills, slow stronger up close, second burst | same |
| Knock a Chilled foe: Splinter after a beat hits neighbours | same |
| Rink Wall slides, E again freezes it | same |
| Wall touch shields teammates | `--support-check` |

## Animation moves
Full-body cast moves are `HunterAnim.KMOVES` entries, played by the kit with `play()`.

| Ability | KMOVES id | Shape |
|---|---|---|
| RMB Sleet Lance | `rime_javelin` | shoulders wound back, whipped through into a throw (0.19s) |
| E Rink Wall | `rime_slam` | hands together low, then pushed out and down onto the ice (0.22s) |
| LMB, Rinkrun | none | shared weapon-hold and rush poses |

## Engine notes
- Kit: `scripts/arch/kits/rimewright_kit.gd` plus `care_util.gd`; look in `scripts/match/hero_gear_care.gd`; data in `content/archetypes/rimewright.json` and `content/weapons/hoar_fan.json`; sounds `audio/rime_*.wav` (`tools/gen_care_sfx.py`).
- The wall is the shared `Verbs.add_wall` system; the frost shield for teammates goes through `CareUtil` (a "heal" event for online squadmates).
- The Rinkrun sets `move_kind = "rinkrun"`, which `hunter.gd` maps to the rush dash animation.
- No R in the data (see tender.md engine notes). Net is 0.10.1 because of the carry event of the pair.
- Open: the rank-3 ice bridge is a puff only (no terrain editing). Checks: `--support-check`, `--rimewright-combo-check`.
