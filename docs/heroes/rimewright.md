# Tamsin, the Rimewright (`rimewright`, light skirmisher with a shelter)

Internal design doc. Source behaviour reference: SUPERVIVE's Celeste (gameplay only).

## Research summary
Sources: supervive.wiki.gg/wiki/Celeste (abilities and upgrade tables). The patch-note search returned only other games' Celeste patches, nothing SUPERVIVE-specific, so the wiki's current kit is the version built.
Important finding: in the source Celeste is an ice damage and control hero, not a healer, although the task brief calls both heroes healers. We kept the source behaviour and gave her the squad-facing part through the Rink Wall (a frost shield for teammates who touch it, once per wall). Flagged as an open question.
Where the wiki has no E (Q is the wall): we map the wall to E (Q is the glove slot).

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Hoarfrost | | Damaging abilities Chill for 4s (slightly slower, frost mist). Knocking a Chilled hunter, or felling a Chilled monster, makes them Shatter 0.4s later: 30 damage within 3m and more Chill | Shatter (Chill) | Chill carries a 15% slow so the state is readable and useful |
| LMB Hoar Fan | hold | Flurry: 4 light homing shards (3.4 each, 0.1s apart) then 3 heavy ones (x2 damage, faster, 1.4x range), 0.5s pause. 8 shards on one foe Shatter them (20, 2.4m). Double damage while skating | Ice Darts | Homing is a soft turn rate (2.4 rad/s inside a 40 degree cone) |
| RMB Sleet Lance | tap, 2 charges | Lance 22 m/s, 12m: 12 damage (x0.8 close to x1.25 far), slow 55% close to 20% far, Chills; goes off again 0.7s later for 15 in 1.8m (rank 3: 45% bigger) | Cryo Spear | Same shape; near/far tradeoff kept |
| Shift Skate | hold | Skate at 11.5 m/s up to 1.6s, steering gently; release stops; stopping early refunds up to 60% of a charge. Fan keeps firing and does double damage. In the air: the usual long dash | Skate | Rank 3 ice-bridge-over-abyss left as a visual puff only (no terrain editing yet; open question) |
| E Rink Wall | tap, tap again | 4.2m wall (70 HP) slides 3.2 m/s for up to 4s, stops enemy shots, shoves foes; press again to freeze it (lasts 8s). Teammates touching it get an 18 frost shield (6s), once per wall; online squadmates receive it as a heal | Frozen Barricade | Uses the shared wall system (`Verbs.add_wall`) |
| R | none | Removed per owner update | Chilling Finale | Flavour: a panic button; does not feed the Chill/Shatter loop |

Scaling: light HP 124. Fan 3.4 per shard against 12 lance and 30 Shatter keeps the source ratio (about 1 : 4.6 : 10).

## Combinations
| Interaction | Check |
|---|---|
| Fan darts Chill; Chill slows | `--rimewright-combo-check` |
| Skate doubles the fan; Shift held starts skating; early release refunds | same |
| 8 shards on one foe Shatter them | same |
| Lance: Chills, slow stronger up close, second burst | same |
| Knock a Chilled foe: Shatter after a beat hits neighbours | same |
| Rink Wall slides, E again freezes it | same |
| Wall touch shields teammates | `--support-check` |
