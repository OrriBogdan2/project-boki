# Roster 50: original Boki for owner review

Status: **proposal, for owner review before any art.** Revised after the owner's review: big Boki now have roles, not just riding. Phase 1 (design, no credits). The owner asked for
"a bunch of original Boki to play with that have good 3D modelling I can later change": 50 species in
total, a range of sizes, and some big rideable ones (revised: big Boki get roles, at most about 6 mounts). Today's 9 count toward the 50, so this adds 41.

- Stubs: `content/kin_v2/<id>.json`, one per new species, in the real kin grammar (docs/KIN_GRAMMAR.md), with home data in
  `content/kin/<id>.json`. All 50 are **loaded by the game** (see "Where the stubs live" below). A species with no model yet
  is drawn by the `KinModels` primitives of its `look`; the 21 with `art/kin/<id>/<id>.glb` use their rig.
- Check: `godot --headless -- --roster-check` (tools/roster_check.gd): 50 species, no name clashes, home data present, 4-6 rideables.
- Big-Boki roles and riding: docs/boki/RIDING_SPEC.md (specs only, waiting for the owner's OK).

## Name map (creature-design pass, 2026-11-07)

The 29 species that had no 3D model were redesigned in `briefs/BOKI_50_DESIGNS.md` (on ext/agent-briefs). Their stubs now carry the
new display name, the two main ingredients of the new mix (`animals` holds at most 2) and a description (`flavor`) made of the design's
hook plus its personality line. Ids, abilities, merge, size, rig, stats and the numeric `personality` weights are unchanged, so every
table and entry below that says "Name" still refers to the old name; look it up here. Murmurling and Umbrathere keep their names.
The 21 species with models and the 8 kept designs are untouched; the 13 "v2 upgrades" are model edits for the art session, not stub edits.

| id | Roster name (before) | Display name now | Stub mix (`animals`) |
|---|---|---|---|
| `opalisk` | Opalisk | **Bubblisk** | Basilisk lizard + Soap bubble |
| `kilnbadger` | Kilnbadger | **Anvilbrock** | Honey badger + Blacksmith's anvil |
| `hoarheron` | Hoarheron | **Skateron** | Grey heron + Ice skates |
| `sentrikat` | Sentrikat | **Barokat** | Meerkat + Brass barometer |
| `basaltoad` | Basaltoad | **Rampartoad** | Cane toad + Castle rampart |
| `orchisloth` | Orchisloth | **Terrasloth** | Three-toed sloth + Glass greenhouse |
| `caecilith` | Caecilith | **Zippelith** | Caecilian + Giant zipper |
| `velvorm` | Velvorm | **Pipewurm** | Velvet worm + Piping bag |
| `gibbelle` | Gibbelle | **Gongibbon** | Gibbon + Bronze temple bell |
| `casquebill` | Casquebill | **Anchorbill** | Hornbill + Ship's anchor |
| `nacrolin` | Nacrolin | **Mirrolin** | Pangolin + Disco ball |
| `moonloris` | Moonloris | **Lanterloris** | Slow loris + Paper lantern |
| `murmurling` | Murmurling | **Murmurling** | Starling + Pan-pipes |
| `threadwyrm` | Threadwyrm | **Knotwyrm** | Slow worm + Knotted hemp rope |
| `tuatrune` | Tuatrune | **Lockatara** | Tuatara + Iron padlock |
| `squalltross` | Squalltross | **Canvastross** | Albatross + Patched ship sails |
| `scaldamus` | Scaldamus | **Chuggamus** | Hippopotamus + Steam locomotive |
| `floenatee` | Floenatee | **Frigatee** | Manatee + Antique icebox |
| `limpetor` | Limpetor | **Buckleron** | Giant limpet + Riveted iron shield |
| `umbrathere` | Umbrathere | **Umbrathere** | Giant ground sloth + Ragged black umbrella |
| `moundvark` | Moundvark | **Spirevark** | Aardvark + Termite clay spire |
| `goliathite` | Goliathite | **Effigeetle** | Goliath beetle + Marble statue face |
| `spatewader` | Spatewader | **Barrelmander** | Giant salamander + Wooden rain barrel |
| `cindowary` | Cindowary | **Bellowary** | Cassowary + Forge bellows |
| `glaciyak` | Glaciyak | **Prowyak** | Yak + Icebreaker prow |
| `nimbostrich` | Nimbostrich | **Boltstrich** | Ostrich + Thunderhead and copper coil |
| `lilybara` | Lilybara | **Soakybara** | Capybara + Hot-spring pool |
| `duskapi` | Duskapi | **Snuffapi** | Okapi + Brass candelabra |
| `heatherhorn` | Heatherhorn | **Crofthorn** | Highland cow + Stone cottage garden |

## Rules this roster follows

- **Every Boki is our own.** Each is a fusion of real animals, plants, minerals and weather, like today's
  nine (fox + scorpion, axolotl + crystal). None is based on, named after or fused from a franchise
  creature (Pokémon, Digimon, Palworld, Temtem, Monster Hunter and the rest). See "Originality check".
- **Size classes.** small = rides a shoulder (or perches if it flies); medium = perches on the pack;
  large = a big Boki you don't ride (it has another big-Boki role, below); rideable = a mount you ride.
  In the grammar all 16 big ones are `body.size: "large"` with `carry.style: "mount"`, because that is the
  only carry style a large kin may have today. `--roster-check` counts mount speed x1.1 and up as
  rideable; the non-ridden big Boki are stubbed at x1.0 or below. The role itself lives in this doc only
  (see "Big-Boki roles" for the grammar field it needs).
- **Big-Boki roles (owner review, 02:30).** Large Boki aren't all mounts. The 16 big ones (today's
  Cairnback and Gravadillo, 14 new) split into six roles, with at most 6 mounts. Each role has a pitch
  and a short spec in docs/boki/RIDING_SPEC.md (for owner approval).
- **Themes are the grammar's cosmetic themes** (`KinParts.THEMES`): no new theme was invented, so every
  stub validates. There is no water theme; aquatic Boki wear frost, storm or lunar (decision 5).
- **Abilities are the existing 16** (`content/abilities_v2`). Each entry also sketches the Boki's own
  ability in grammar parts for Phase 3. Merges reuse the existing 9 by active ability (decision 3).
- **Rarity:** starter (the three starter eggs), common, uncommon, rare (wild only, deeper biomes),
  boss (a boss's Rare Egg; only today's three bosses have one, so no new boss eggs).
- **Body type** picks the shared creature skeleton (the rig), so 50 Boki share 7 skeletons.

## Summary

**Big-Boki roles (the 16 large and rideable):** mount 6, companion 3, bulwark 2, flyer 2, packbeast 2, watchtower 1

**Size:** small 20 (13 new), medium 14 (14 new), large 10 (8 new), rideable 6 (6 new)

**Body type:** quadruped 18 (13 new), winged 8 (7 new), biped 8 (8 new), aquatic 4 (3 new), insect 4 (3 new), serpent 4 (3 new), blob 4 (4 new)

**Theme:** swarm 4 (3 new), ember 4 (4 new), stone 4 (4 new), frost 4 (4 new), bloom 4 (4 new), storm 4 (4 new), shadow 4 (4 new), spore 3 (2 new), venom 3 (2 new), prism 3 (2 new), lunar 3 (2 new), echo 3 (2 new), gravity 3 (2 new), titan 2 (1 new), tempest 2 (1 new)

**Rarity:** uncommon 19 (18 new), rare 13 (13 new), common 12 (10 new), starter 3 (0 new), boss 3 (0 new)

**Where the new 41 live:** Greenreach 11, Bloomwild 9, Gloomheart 8, Stormcrest 5, Emberfall 4, Frostreach 4

**Rig use:** QUAD 10, QUAD-L 8, WING 7, BIPED 5, SERPENT 4, HEXA 3, BLOB 3, BIPED-L 3, FIN 2, FIN-L 2, WING-L 1, BLOB-L 1, HEXA-L 1

## Big-Boki roles

| Role | Count | Who | Pitch |
|---|---|---|---|
| **mount** | 6 | Heatherhorn, Glaciyak, Lilybara, Cindowary, Nimbostrich, Duskapi | You ride it. Fast travel out of combat, one rider; you get off to loot, revive or extract. |
| **companion** | 3 | Gravadillo, Scaldamus, Umbrathere | Walks beside you and fights as a second body. It draws fire, holds a lane and body-blocks a chase; you never sit on it. |
| **flyer** | 2 | Goliathite, Squalltross | Lifts you. Hang from it for a long carried glide, or let it haul you over an abyss gap it can reach. Never free flight. |
| **bulwark** (own idea) | 2 | Cairnback, Limpetor | Plants itself as living cover. You and your squad shoot from behind it while it soaks shots until it cracks. |
| **packbeast** (own idea) | 2 | Floenatee, Spatewader | Carries loot. Extra pack slots on its back that you can extract with; hit it hard enough and the load spills for rivals to grab. |
| **watchtower** (own idea) | 1 | Moundvark | Stands still and lets you climb on top. Height, longer sight and reveal for a sniper, but you're the most visible thing on the island. |

What changed from the first draft: Goliathite (beetle) and Spatewader (salamander) stopped being mounts
and became a flyer and a packbeast; Squalltross (albatross) grew from medium to large to be the second
flyer; today's Cairnback and Gravadillo get roles too (bulwark and companion). Sizes now: small 20,
medium 14, large 10, rideable 6.

**Grammar field needed.** The grammar has no field that can hold these roles. `ai.role` is the combat
style (tank, support...), and `carry.style` accepts only shoulder, perch and mount, and large kin may
only be mount (`KinParts.CARRY`). The natural home is new `carry.style` values for large kin:
`beside` (companion), `flyer`, `bulwark`, `pack`, `tower` next to `mount`, each with its own settings
block like `carry.mount` (for example `carry.pack: {"slots": 4}`). That is a change to
`scripts/kin/parts.gd` and `kin_spec.gd` plus the behaviour behind each; until then the stubs keep
`carry.style: "mount"`, so a non-mount big Boki switched on today would still be ridden on Return.

## The 50 at a glance

| # | id | Name | Mix | Theme | Size | Big-Boki role | Body (rig) | Fights as | Rarity | Where |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `burrlet` | Mycroll *(existing)* | Hedgehog + Toadstool | spore | small | - | quadruped (QUAD) | controller | starter | Starter egg |
| 2 | `cindle` | Vespyx *(existing)* | Fox + Scorpion | venom | small | - | quadruped (QUAD) | bruiser | starter | Starter egg |
| 3 | `puddlet` | Prismander *(existing)* | Axolotl + Crystal | prism | small | - | aquatic (FIN) | support | starter | Starter egg |
| 4 | `wisplet` | Lunowl *(existing)* | Owl + Luna moth | lunar | small | - | winged (WING) | trickster | common | Wild, nest eggs |
| 5 | `zapple` | Echolop *(existing)* | Hare + Bat | echo | small | - | quadruped (QUAD) | skirmisher | common | Wild, nest eggs |
| 6 | `pebbit` | Gravadillo *(existing)* | Armadillo + Rhino beetle | gravity | large | companion | quadruped (QUAD-L) | tank | uncommon | Wild, nest eggs |
| 7 | `cairnback` | Cairnback *(existing)* | Tortoise + Ibex | titan | large | bulwark | quadruped (QUAD-L) | tank | boss | Boss: The Stone Colossus |
| 8 | `hivara` | Hivara *(existing)* | Honeybee + Praying mantis | swarm | small | - | insect (HEXA) | bruiser | boss | Boss: The Brood Mother |
| 9 | `zephyrak` | Zephyrak *(existing)* | Moray eel + Swift | tempest | small | - | serpent (SERPENT) | skirmisher | boss | Boss: Stormcoil, the Sky Serpent |
| 10 | `kindlewren` | Kindlewren | Wren + Ember coal | ember | small | - | winged (WING) | skirmisher | common | Emberfall |
| 11 | `glintmole` | Glintmole | Star-nosed mole + Quartz geode | stone | small | - | quadruped (QUAD) | controller | common | Greenreach |
| 12 | `rimeshrew` | Rimeshrew | Shrew + Hoarfrost | frost | small | - | quadruped (QUAD) | skirmisher | common | Frostreach |
| 13 | `mossgrade` | Mossgrade | Tardigrade + Cushion moss | bloom | small | - | blob (BLOB) | support | common | Bloomwild |
| 14 | `kestrike` | Kestrike | Kestrel + Copper lightning rod | storm | small | - | winged (WING) | skirmisher | uncommon | Stormcrest |
| 15 | `gloamshell` | Gloamshell | Garden snail + Smoked obsidian | shadow | small | - | blob (BLOB) | controller | common | Gloomheart |
| 16 | `nettlynx` | Nettlynx | Lynx kitten + Stinging nettle | venom | small | - | quadruped (QUAD) | bruiser | uncommon | Bloomwild |
| 17 | `thrumbird` | Thrumbird | Hummingbird + Tuning fork | echo | small | - | winged (WING) | support | uncommon | Greenreach |
| 18 | `lodestick` | Lodestick | Stick insect + Lodestone | gravity | small | - | insect (HEXA) | trickster | uncommon | Gloomheart |
| 19 | `selenfin` | Selenfin | Hatchetfish + Moonstone | lunar | small | - | aquatic (FIN) | support | rare | Gloomheart |
| 20 | `marchleaf` | Marchleaf | Leafcutter ant + Leaf | swarm | small | - | insect (HEXA) | bruiser | common | Bloomwild |
| 21 | `opalisk` | Opalisk | Basilisk lizard + Opal | prism | small | - | biped (BIPED) | trickster | uncommon | Greenreach |
| 22 | `glomwort` | Glomwort | Slime mold + Puffball | spore | small | - | blob (BLOB) | controller | common | Bloomwild |
| 23 | `kilnbadger` | Kilnbadger | Honey badger + Kiln brick | ember | medium | - | quadruped (QUAD) | tank | uncommon | Emberfall |
| 24 | `hoarheron` | Hoarheron | Grey heron + Icicle | frost | medium | - | winged (WING) | controller | uncommon | Frostreach |
| 25 | `sentrikat` | Sentrikat | Meerkat + Copper weathervane | storm | medium | - | biped (BIPED) | support | common | Stormcrest |
| 26 | `basaltoad` | Basaltoad | Cane toad + Basalt columns | stone | medium | - | quadruped (QUAD) | tank | common | Greenreach |
| 27 | `orchisloth` | Orchisloth | Three-toed sloth + Orchid | bloom | medium | - | biped (BIPED) | support | uncommon | Bloomwild |
| 28 | `caecilith` | Caecilith | Caecilian + Obsidian | shadow | medium | - | serpent (SERPENT) | trickster | uncommon | Gloomheart |
| 29 | `velvorm` | Velvorm | Velvet worm + Amethyst | venom | medium | - | serpent (SERPENT) | controller | uncommon | Bloomwild |
| 30 | `gibbelle` | Gibbelle | Gibbon + Bellflower | echo | medium | - | biped (BIPED) | controller | uncommon | Greenreach |
| 31 | `casquebill` | Casquebill | Hornbill + Iron meteorite | gravity | medium | - | winged (WING) | controller | rare | Gloomheart |
| 32 | `nacrolin` | Nacrolin | Pangolin + Mother-of-pearl | prism | medium | - | quadruped (QUAD) | tank | rare | Greenreach |
| 33 | `moonloris` | Moonloris | Slow loris + Moonflower | lunar | medium | - | biped (BIPED) | support | uncommon | Gloomheart |
| 34 | `murmurling` | Murmurling | Starling + Flock | swarm | medium | - | winged (WING) | skirmisher | common | Greenreach |
| 35 | `threadwyrm` | Threadwyrm | Slow worm + Mycelium | spore | medium | - | serpent (SERPENT) | controller | uncommon | Bloomwild |
| 36 | `squalltross` | Squalltross | Albatross + Squall cloud | tempest | large | flyer | winged (WING-L) | skirmisher | uncommon | Stormcrest |
| 37 | `tuatrune` | Tuatrune | Tuatara + Rune-cut bronze | titan | medium | - | quadruped (QUAD) | tank | rare | Greenreach |
| 38 | `scaldamus` | Scaldamus | Hippopotamus + Volcanic mud | ember | large | companion | quadruped (QUAD-L) | tank | rare | Emberfall |
| 39 | `floenatee` | Floenatee | Manatee + Pack ice | frost | large | packbeast | aquatic (FIN-L) | support | rare | Frostreach |
| 40 | `limpetor` | Limpetor | Limpet + Granite tor | stone | large | bulwark | blob (BLOB-L) | tank | rare | Greenreach |
| 41 | `umbrathere` | Umbrathere | Giant ground sloth + Night smoke | shadow | large | companion | biped (BIPED-L) | tank | rare | Gloomheart |
| 42 | `moundvark` | Moundvark | Aardvark + Termite mound | swarm | large | watchtower | quadruped (QUAD-L) | tank | rare | Bloomwild |
| 43 | `cindowary` | Cindowary | Cassowary + Charcoal | ember | rideable | mount | biped (BIPED-L) | bruiser | rare | Emberfall |
| 44 | `glaciyak` | Glaciyak | Yak + Glacier ice | frost | rideable | mount | quadruped (QUAD-L) | tank | uncommon | Frostreach |
| 45 | `nimbostrich` | Nimbostrich | Ostrich + Thunderhead | storm | rideable | mount | biped (BIPED-L) | skirmisher | rare | Stormcrest |
| 46 | `goliathite` | Goliathite | Goliath beetle + Marble | stone | large | flyer | insect (HEXA-L) | tank | uncommon | Greenreach |
| 47 | `lilybara` | Lilybara | Capybara + Water lily | bloom | rideable | mount | quadruped (QUAD-L) | support | uncommon | Bloomwild |
| 48 | `duskapi` | Duskapi | Okapi + Dusk smoke | shadow | rideable | mount | quadruped (QUAD-L) | trickster | rare | Gloomheart |
| 49 | `spatewader` | Spatewader | Giant salamander + Flash flood | storm | large | packbeast | aquatic (FIN-L) | tank | rare | Stormcrest |
| 50 | `heatherhorn` | Heatherhorn | Highland cow + Heather | bloom | rideable | mount | quadruped (QUAD-L) | tank | uncommon | Greenreach |

## Entries

Each entry: mix, theme, size, body and rig, how it fights, its big-Boki role (large and rideable
only), a 2-line personality, abilities (E and auto from the existing grammar; the merge the stub uses), a
sketch of its own ability in grammar parts, rarity and where it comes from, and a one-line art note for
the image-gen turnaround (silhouette and palette).

### Small (shoulder or perch)

#### Mycroll (`burrlet`) *(existing, live)*

- **Mix:** Hedgehog + Toadstool. **Theme:** spore. **Size:** small. **Body:** quadruped, rig `QUAD`. **Fights as:** controller.
- **Personality:** Curious and odd, notices small things. Wanders off sometimes, comes back with something.
- **Abilities:** Puffcap Mines (E, `puffcap_mines`), Spore Patch (auto, `thorn_patch`).
- **Rarity / where:** starter, Starter egg.
- **Art note:** Hedgehog with glowing toadstool quills; brown body, cream belly, teal glow.

#### Vespyx (`cindle`) *(existing, live)*

- **Mix:** Fox + Scorpion. **Theme:** venom. **Size:** small. **Body:** quadruped, rig `QUAD`. **Fights as:** bruiser.
- **Personality:** Sly and eager, talks in quick little hisses. Brave, but quick to anger.
- **Abilities:** Stinger Hook (E, `stinger_hook`), Stinger Dash (auto, `flare_dash`).
- **Rarity / where:** starter, Starter egg.
- **Art note:** Sly plum fox with a curled scorpion tail; lilac belly, acid-green glow.

#### Prismander (`puddlet`) *(existing, live)*

- **Mix:** Axolotl + Crystal. **Theme:** prism. **Size:** small. **Body:** aquatic, rig `FIN`. **Fights as:** support.
- **Personality:** Gentle, worried about you, a little formal. Loyal, a bit of a worrier.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`).
- **Rarity / where:** starter, Starter egg.
- **Art note:** Pink axolotl with living crystal frills; pale pink belly, cyan glow.

#### Lunowl (`wisplet`) *(existing, live)*

- **Mix:** Owl + Luna moth. **Theme:** lunar. **Size:** small. **Body:** winged, rig `WING`. **Fights as:** trickster.
- **Personality:** Airy, teasing and dramatic. Quick and slippery.
- **Abilities:** Moon Swap (E, `moon_swap`), Moonlift (auto, `updraft`).
- **Rarity / where:** common, Wild, nest eggs.
- **Art note:** Moonlit lilac owl with pale green moth wings; cream belly, moon-yellow glow.

#### Echolop (`zapple`) *(existing, live)*

- **Mix:** Hare + Bat. **Theme:** echo. **Size:** small. **Body:** quadruped, rig `QUAD`. **Fights as:** skirmisher.
- **Personality:** Hyper and easily distracted. Loves winning.
- **Abilities:** Echo Chain (E, `chain_spark`), Echolocate (auto, `echolocate`).
- **Rarity / where:** common, Wild, nest eggs.
- **Art note:** Long-eared blue hare with purple bat wings; pale blue belly, cyan glow.

#### Hivara (`hivara`) *(existing, live)*

- **Mix:** Honeybee + Praying mantis. **Theme:** swarm. **Size:** small. **Body:** insect, rig `HEXA`. **Fights as:** bruiser.
- **Personality:** Busy and bossy, always organising. Hums when it's happy.
- **Abilities:** Hive Swarm (E, `hive_swarm`), Spore Patch (auto, `thorn_patch`).
- **Rarity / where:** boss, Boss: The Brood Mother.
- **Art note:** Golden bee with folded mantis blades and a wax crown, a halo of tiny bees.

#### Zephyrak (`zephyrak`) *(existing, live)*

- **Mix:** Moray eel + Swift. **Theme:** tempest. **Size:** small. **Body:** serpent, rig `SERPENT`. **Fights as:** skirmisher.
- **Personality:** Wild and quick, crackles with excitement. Loves heights and speed.
- **Abilities:** Gale Lance (E, `gale_lance`), Storm Arc (auto, `storm_arc`).
- **Rarity / where:** boss, Boss: Stormcoil, the Sky Serpent.
- **Art note:** Small sky eel with swept swift wings crackling with static; blue, cyan glow.

#### Kindlewren (`kindlewren`)

- **Mix:** Wren + Ember coal. **Theme:** ember. **Size:** small. **Body:** winged, rig `WING`. **Fights as:** skirmisher.
- **Personality:** Cheeky and impatient, always first into a fight. Sulks if you leave it on your shoulder too long.
- **Abilities:** Gale Lance (E, `gale_lance`), Stinger Dash (auto, `flare_dash`); merge stub: Stormwing (`stormwing`).
- **Own ability later (grammar parts):** Coal Dart: dash 6 m, damage + damage over 3 s.
- **Rarity / where:** common, Emberfall.
- **Art note:** Round brown wren, tail cocked straight up and tipped with a glowing coal; cream belly, ember-orange glow, stubby wings.

#### Glintmole (`glintmole`)

- **Mix:** Star-nosed mole + Quartz geode. **Theme:** stone. **Size:** small. **Body:** quadruped, rig `QUAD`. **Fights as:** controller.
- **Personality:** Shy and fussy, hates bright light. Points its star nose at trouble before anyone sees it.
- **Abilities:** Puffcap Mines (E, `puffcap_mines`), Echolocate (auto, `echolocate`); merge stub: Sporewake (`thornwake`).
- **Own ability later (grammar parts):** Geode Mines: trap x3, root + reveal.
- **Rarity / where:** common, Greenreach.
- **Art note:** Chunky dark mole, pink star-shaped nose, an open geode ridge of lilac quartz down its back, big digging claws.

#### Rimeshrew (`rimeshrew`)

- **Mix:** Shrew + Hoarfrost. **Theme:** frost. **Size:** small. **Body:** quadruped, rig `QUAD`. **Fights as:** skirmisher.
- **Personality:** Frantic, hungry and fearless for its size. Squeaks at things thirty times bigger than it.
- **Abilities:** Hive Swarm (E, `hive_swarm`), Storm Arc (auto, `storm_arc`); merge stub: Hive Crown (`hive_crown`).
- **Own ability later (grammar parts):** Hoarfrost Breath: cone 4 m, frost slow.
- **Rarity / where:** common, Frostreach.
- **Art note:** Tiny long-snouted shrew, white frost feathers along the spine, pale blue-grey coat, icy cyan glow, twitchy nose.

#### Mossgrade (`mossgrade`)

- **Mix:** Tardigrade + Cushion moss. **Theme:** bloom. **Size:** small. **Body:** blob, rig `BLOB`. **Fights as:** support.
- **Personality:** Unbothered and patient, sleeps anywhere. Will not be hurried and will not be hurt.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`); merge stub: Prism Shell (`tidal_shell`).
- **Own ability later (grammar parts):** Moss Cushion: zone 3 m, heal over 4 s to allies.
- **Rarity / where:** common, Bloomwild.
- **Art note:** Barrel-shaped water bear on eight stubby legs, soft wrinkled body, a green moss cushion with tiny flowers on its back.

#### Kestrike (`kestrike`)

- **Mix:** Kestrel + Copper lightning rod. **Theme:** storm. **Size:** small. **Body:** winged, rig `WING`. **Fights as:** skirmisher.
- **Personality:** Proud and watchful, judges your aim. Hovers over you when it thinks you're in danger.
- **Abilities:** Echo Chain (E, `chain_spark`), Storm Arc (auto, `storm_arc`); merge stub: Resonance (`stormcoat`).
- **Own ability later (grammar parts):** Rod Strike: projectile 10 m, stun 0.4 s + chain 1.
- **Rarity / where:** uncommon, Stormcrest.
- **Art note:** Rust-and-slate kestrel, swept falcon wings, a copper rod crest with a spark at the tip, yellow glow, hovering pose.

#### Gloamshell (`gloamshell`)

- **Mix:** Garden snail + Smoked obsidian. **Theme:** shadow. **Size:** small. **Body:** blob, rig `BLOB`. **Fights as:** controller.
- **Personality:** Slow, private and oddly smug. Likes dark corners, and your pocket.
- **Abilities:** Puffcap Mines (E, `puffcap_mines`), Spore Patch (auto, `thorn_patch`); merge stub: Sporewake (`thornwake`).
- **Own ability later (grammar parts):** Dusk Trail: zone line, slow foes + reveal hiders.
- **Rarity / where:** common, Gloomheart.
- **Art note:** Squat grey-violet snail, glassy black spiral shell with a faint violet inner glow, two long eye stalks, dark mist trail.

#### Nettlynx (`nettlynx`)

- **Mix:** Lynx kitten + Stinging nettle. **Theme:** venom. **Size:** small. **Body:** quadruped, rig `QUAD`. **Fights as:** bruiser.
- **Personality:** Prickly and proud, affectionate on its own terms. Bites first, purrs later.
- **Abilities:** Stinger Hook (E, `stinger_hook`), Stinger Dash (auto, `flare_dash`); merge stub: Venom Fusion (`blaze_mantle`).
- **Own ability later (grammar parts):** Nettle Pounce: leap 6 m, damage over 3 s + blight.
- **Rarity / where:** uncommon, Bloomwild.
- **Art note:** Stocky lynx kitten, olive coat with dark spots, nettle-leaf ear tufts and a serrated nettle tail, huge paws, lime glow.

#### Thrumbird (`thrumbird`)

- **Mix:** Hummingbird + Tuning fork. **Theme:** echo. **Size:** small. **Body:** winged, rig `WING`. **Fights as:** support.
- **Personality:** Bright and chatty, can't sit still. Hums when you're hurt, as if that helps. It does.
- **Abilities:** Prism Wall (E, `prism_wall`), Echolocate (auto, `echolocate`); merge stub: Prism Shell (`tidal_shell`).
- **Own ability later (grammar parts):** Sound Wall: wall 3 m, reflect.
- **Rarity / where:** uncommon, Greenreach.
- **Art note:** Tiny emerald hummingbird, needle beak, tail split into a two-prong silver tuning fork, teal glow, blurred wings.

#### Lodestick (`lodestick`)

- **Mix:** Stick insect + Lodestone. **Theme:** gravity. **Size:** small. **Body:** insect, rig `HEXA`. **Fights as:** trickster.
- **Personality:** Still and patient, a deadpan joker. Plays dead whenever it's bored.
- **Abilities:** Moon Swap (E, `moon_swap`), Moonlift (auto, `updraft`); merge stub: Eclipse (`tempest`).
- **Own ability later (grammar parts):** Lodestar: projectile 9 m, pull to the kin.
- **Rarity / where:** uncommon, Gloomheart.
- **Art note:** Thin twiggy stick insect with blocky lodestone joints, iron filings bristling on its legs, purple glow between segments.

#### Selenfin (`selenfin`)

- **Mix:** Hatchetfish + Moonstone. **Theme:** lunar. **Size:** small. **Body:** aquatic, rig `FIN`. **Fights as:** support.
- **Personality:** Serene and a bit aloof, rarely makes a sound. Glows brighter when you're near.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`); merge stub: Prism Shell (`tidal_shell`).
- **Own ability later (grammar parts):** Tidelight: aura 4 m, heal over 3 s.
- **Rarity / where:** rare, Gloomheart.
- **Art note:** Deep, flat, hatchet-shaped silver fish, huge upturned eyes, a pale moonstone set in its keel, floats upright, soft yellow glow.

#### Marchleaf (`marchleaf`)

- **Mix:** Leafcutter ant + Leaf. **Theme:** swarm. **Size:** small. **Body:** insect, rig `HEXA`. **Fights as:** bruiser.
- **Personality:** Dutiful and stubborn, a born foreman. Gets upset when you change plans.
- **Abilities:** Hive Swarm (E, `hive_swarm`), Spore Patch (auto, `thorn_patch`); merge stub: Hive Crown (`hive_crown`).
- **Own ability later (grammar parts):** Column March: projectile x3 (split), damage + slow.
- **Rarity / where:** common, Bloomwild.
- **Art note:** Glossy red-brown ant on four legs carrying a big green leaf like a sail over its head, three tiny ants trailing behind.

#### Opalisk (`opalisk`)

- **Mix:** Basilisk lizard + Opal. **Theme:** prism. **Size:** small. **Body:** biped, rig `BIPED`. **Fights as:** trickster.
- **Personality:** A show-off that startles easily. Runs first, poses later.
- **Abilities:** Moon Swap (E, `moon_swap`), Refraction (auto, `refraction`); merge stub: Eclipse (`tempest`).
- **Own ability later (grammar parts):** Opal Flash: burst 3 m, decoy + slow.
- **Rarity / where:** uncommon, Greenreach.
- **Art note:** Slim upright-running lizard, tall head crest and back sail, white opal scales flashing pink and green, long whip tail.

#### Glomwort (`glomwort`)

- **Mix:** Slime mold + Puffball. **Theme:** spore. **Size:** small. **Body:** blob, rig `BLOB`. **Fights as:** controller.
- **Personality:** Curious about everything, remembers every path. Quietly spreads into your stuff.
- **Abilities:** Puffcap Mines (E, `puffcap_mines`), Spore Patch (auto, `thorn_patch`); merge stub: Sporewake (`thornwake`).
- **Own ability later (grammar parts):** Puffball Net: zone 3 m, root on entry.
- **Rarity / where:** common, Bloomwild.
- **Art note:** Gooey yellow blob with branching vein-net edges, three round puffballs on top, two dot eyes.

### Medium (perch on the pack)

#### Kilnbadger (`kilnbadger`)

- **Mix:** Honey badger + Kiln brick. **Theme:** ember. **Size:** medium. **Body:** quadruped, rig `QUAD`. **Fights as:** tank.
- **Personality:** Fearless and grumpy, loyal like a bad habit. Picks fights it can't win, and wins them.
- **Abilities:** Gravity Slam (E, `slam`), Mass Guard (auto, `rock_guard`); merge stub: Heavy Star (`titan`).
- **Own ability later (grammar parts):** Kiln Charge: dash 5 m, push + damage over 2 s.
- **Rarity / where:** uncommon, Emberfall.
- **Art note:** Low broad badger, black body with a white crown stripe, a cracked brick-red plate saddle on its back glowing orange in the cracks.

#### Hoarheron (`hoarheron`)

- **Mix:** Grey heron + Icicle. **Theme:** frost. **Size:** medium. **Body:** winged, rig `WING`. **Fights as:** controller.
- **Personality:** Patient and severe, says little. Approves of you only when you stand still.
- **Abilities:** Gale Lance (E, `gale_lance`), Spore Patch (auto, `thorn_patch`); merge stub: Stormwing (`stormwing`).
- **Own ability later (grammar parts):** Ice Spear: projectile 10 m, pierce, frost slow.
- **Rarity / where:** uncommon, Frostreach.
- **Art note:** Tall grey heron, legs and dagger beak of clear blue ice, frost plumes on the head, folded wings, stands on one leg.

#### Sentrikat (`sentrikat`)

- **Mix:** Meerkat + Copper weathervane. **Theme:** storm. **Size:** medium. **Body:** biped, rig `BIPED`. **Fights as:** support.
- **Personality:** Alert and bossy, takes guard duty seriously. Can't relax unless it's the one keeping watch.
- **Abilities:** Echo Chain (E, `chain_spark`), Echolocate (auto, `echolocate`); merge stub: Resonance (`stormcoat`).
- **Own ability later (grammar parts):** Storm Warning: burst 15 m, reveal (utility only).
- **Rarity / where:** common, Stormcrest.
- **Art note:** Upright sandy meerkat, dark eye patches, tail ending in a copper arrow weathervane with a spark, standing tall on hind legs.

#### Basaltoad (`basaltoad`)

- **Mix:** Cane toad + Basalt columns. **Theme:** stone. **Size:** medium. **Body:** quadruped, rig `QUAD`. **Fights as:** tank.
- **Personality:** Placid and heavy, a creature of habit. Croaks once, deeply, when it disapproves.
- **Abilities:** Boulder Heave (E, `boulder_heave`), Mass Guard (auto, `rock_guard`); merge stub: Cairn Colossus (`cairn_colossus`).
- **Own ability later (grammar parts):** Column Rise: wall 3 m (blocks shots).
- **Rarity / where:** common, Greenreach.
- **Art note:** Wide squat toad, charcoal grey, its back made of hexagonal basalt column tops at different heights, amber eyes.

#### Orchisloth (`orchisloth`)

- **Mix:** Three-toed sloth + Orchid. **Theme:** bloom. **Size:** medium. **Body:** biped, rig `BIPED`. **Fights as:** support.
- **Personality:** Gentle and dreamy, never in a hurry. Smiles at everything, even danger.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`); merge stub: Prism Shell (`tidal_shell`).
- **Own ability later (grammar parts):** Orchid Mist: zone 4 m, heal over 4 s + slow foes.
- **Rarity / where:** uncommon, Bloomwild.
- **Art note:** Shaggy tan sloth with long hooked arms and a sleepy smile, pink-white orchids and green moss growing through its fur.

#### Caecilith (`caecilith`)

- **Mix:** Caecilian + Obsidian. **Theme:** shadow. **Size:** medium. **Body:** serpent, rig `SERPENT`. **Fights as:** trickster.
- **Personality:** Secretive and sly, loves surprises. Appears where you least expect it, grinning.
- **Abilities:** Moon Swap (E, `moon_swap`), Echolocate (auto, `echolocate`); merge stub: Eclipse (`tempest`).
- **Own ability later (grammar parts):** Underpass: blink 7 m, then burst 2 m slow.
- **Rarity / where:** uncommon, Gloomheart.
- **Art note:** Smooth ringed legless body like a giant earthworm, glossy black obsidian bands, tiny eyes, blunt head, violet glow in the seams.

#### Velvorm (`velvorm`)

- **Mix:** Velvet worm + Amethyst. **Theme:** venom. **Size:** medium. **Body:** serpent, rig `SERPENT`. **Fights as:** controller.
- **Personality:** Gentle-looking and a ruthless hunter. Loves being stroked, hates being ignored.
- **Abilities:** Hive Swarm (E, `hive_swarm`), Spore Patch (auto, `thorn_patch`); merge stub: Hive Crown (`hive_crown`).
- **Own ability later (grammar parts):** Thread Spray: cone 5 m, root 0.8 s + poison.
- **Rarity / where:** uncommon, Bloomwild.
- **Art note:** Long soft velvety purple worm on many stubby legs, two antennae, rows of amethyst studs, slime nozzles beside the mouth.

#### Gibbelle (`gibbelle`)

- **Mix:** Gibbon + Bellflower. **Theme:** echo. **Size:** medium. **Body:** biped, rig `BIPED`. **Fights as:** controller.
- **Personality:** Loud, joyful and a show-off. Sings when happy, and louder when scared.
- **Abilities:** Echo Chain (E, `chain_spark`), Echolocate (auto, `echolocate`); merge stub: Resonance (`stormcoat`).
- **Own ability later (grammar parts):** Bell Peal: burst 4 m, stun 0.4 s + echo.
- **Rarity / where:** uncommon, Greenreach.
- **Art note:** Lanky gibbon with very long arms, lilac-grey fur, a cluster of blue bellflowers at its throat that swells when it sings.

#### Casquebill (`casquebill`)

- **Mix:** Hornbill + Iron meteorite. **Theme:** gravity. **Size:** medium. **Body:** winged, rig `WING`. **Fights as:** controller.
- **Personality:** Dignified and slow to trust, keeps its own counsel. Clacks its bill when it disagrees.
- **Abilities:** Gravity Slam (E, `slam`), Echolocate (auto, `echolocate`); merge stub: Heavy Star (`titan`).
- **Own ability later (grammar parts):** Starfall: leap 7 m, pull to centre + stun.
- **Rarity / where:** rare, Gloomheart.
- **Art note:** Black-and-cream hornbill, huge curved bill topped with a pitted iron meteorite casque glowing violet in the pits.

#### Nacrolin (`nacrolin`)

- **Mix:** Pangolin + Mother-of-pearl. **Theme:** prism. **Size:** medium. **Body:** quadruped, rig `QUAD`. **Fights as:** tank.
- **Personality:** Timid but stubborn, curls up when spoken to sharply. Unrolls for snacks.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`); merge stub: Prism Shell (`tidal_shell`).
- **Own ability later (grammar parts):** Pearl Curl: aura 1.6 m on owner, reflect 1 s.
- **Rarity / where:** rare, Greenreach.
- **Art note:** Pangolin with overlapping iridescent pearl scales, small pointed head, long tail; curls into a pearly ball; cyan sheen.

#### Moonloris (`moonloris`)

- **Mix:** Slow loris + Moonflower. **Theme:** lunar. **Size:** medium. **Body:** biped, rig `BIPED`. **Fights as:** support.
- **Personality:** Soft-spoken and sleepy by day, wide awake at night. Clings to you when it's frightened.
- **Abilities:** Moon Swap (E, `moon_swap`), Moonlift (auto, `updraft`); merge stub: Eclipse (`tempest`).
- **Own ability later (grammar parts):** Moonbloom: burst 6 m, reveal + heal over 3 s.
- **Rarity / where:** uncommon, Gloomheart.
- **Art note:** Round fluffy loris, enormous amber eyes in dark rings, white moonflowers on its head and arms, pale cream fur.

#### Murmurling (`murmurling`)

- **Mix:** Starling + Flock. **Theme:** swarm. **Size:** medium. **Body:** winged, rig `WING`. **Fights as:** skirmisher.
- **Personality:** Sociable and noisy, copies every sound it hears. Gets lonely in a second.
- **Abilities:** Hive Swarm (E, `hive_swarm`), Echolocate (auto, `echolocate`); merge stub: Hive Crown (`hive_crown`).
- **Own ability later (grammar parts):** Murmuration: zone 4 m, damage + slow, follows the kin.
- **Rarity / where:** common, Greenreach.
- **Art note:** Glossy black starling with a green-purple sheen and white spots, a ring of five tiny starlings circling it.

#### Threadwyrm (`threadwyrm`)

- **Mix:** Slow worm + Mycelium. **Theme:** spore. **Size:** medium. **Body:** serpent, rig `SERPENT`. **Fights as:** controller.
- **Personality:** Quiet and thoughtful, an old soul. Likes damp shade and long naps.
- **Abilities:** Puffcap Mines (E, `puffcap_mines`), Spore Patch (auto, `thorn_patch`); merge stub: Sporewake (`thornwake`).
- **Own ability later (grammar parts):** Root Line: zone line 6 m, root on entry.
- **Rarity / where:** uncommon, Bloomwild.
- **Art note:** Smooth bronze legless lizard with glossy scales, white-teal glowing mycelium threads wrapping its body and trailing off its tail.

#### Tuatrune (`tuatrune`)

- **Mix:** Tuatara + Rune-cut bronze. **Theme:** titan. **Size:** medium. **Body:** quadruped, rig `QUAD`. **Fights as:** tank.
- **Personality:** Ancient, calm and faintly amused. Watches you with its third eye when you aren't looking.
- **Abilities:** Boulder Heave (E, `boulder_heave`), Mass Guard (auto, `rock_guard`); merge stub: Cairn Colossus (`cairn_colossus`).
- **Own ability later (grammar parts):** Rune Ward: burst 3 m on owner, shield 40 + reveal.
- **Rarity / where:** rare, Greenreach.
- **Art note:** Stocky olive spiny reptile, a spine crest of bronze plates engraved with glowing gold runes, a small third eye on its forehead.

### Large (big Boki you don't ride: companion, flyer, bulwark, packbeast, watchtower)

#### Gravadillo (`pebbit`) *(existing, live)*

- **Mix:** Armadillo + Rhino beetle. **Theme:** gravity. **Size:** large. **Body:** quadruped, rig `QUAD-L`. **Fights as:** tank.
- **Big-Boki role:** **companion**. Walks beside you and fights as a second body, drawing fire and holding a lane; never ridden.
- **Personality:** Slow and steady, few words. Deeply loyal once trust is earned.
- **Abilities:** Gravity Slam (E, `slam`), Mass Guard (auto, `rock_guard`).
- **Rarity / where:** uncommon, Wild, nest eggs.
- **Art note:** Slate armadillo with a rhino-beetle horn and heavy plates; violet glow.

#### Cairnback (`cairnback`) *(existing, live)*

- **Mix:** Tortoise + Ibex. **Theme:** titan. **Size:** large. **Body:** quadruped, rig `QUAD-L`. **Fights as:** tank.
- **Big-Boki role:** **bulwark**. Plants itself as living cover you and your squad shoot from behind; it soaks shots until it breaks.
- **Personality:** Ancient and calm, speaks like grinding stone. Fiercely protective.
- **Abilities:** Boulder Heave (E, `boulder_heave`), Mass Guard (auto, `rock_guard`).
- **Rarity / where:** boss, Boss: The Stone Colossus.
- **Art note:** Grey tortoise with ibex horns and a rune-carved cairn on its shell; gold glow.

#### Squalltross (`squalltross`)

- **Mix:** Albatross + Squall cloud. **Theme:** tempest. **Size:** large. **Body:** winged, rig `WING-L`. **Fights as:** skirmisher.
- **Big-Boki role:** **flyer**. Lifts you: a carried glide or a hop over an abyss gap it can reach; no free flight.
- **Personality:** Easygoing and fearless, a wanderer. Gets restless when it hasn't seen the sea for a while.
- **Abilities:** Gale Lance (E, `gale_lance`), Moonlift (auto, `updraft`); merge stub: Stormwing (`stormwing`).
- **Own ability later (grammar parts):** Squall Line: projectile 10 m, push + slow.
- **Rarity / where:** uncommon, Stormcrest.
- **Art note:** Huge white albatross, very long narrow wings tipped charcoal, wing-tip rain wisps, a bruised-grey squall cloud swirling under its belly, pale gold beak, hunter-sized feet to hang from.

#### Scaldamus (`scaldamus`)

- **Mix:** Hippopotamus + Volcanic mud. **Theme:** ember. **Size:** large. **Body:** quadruped, rig `QUAD-L`. **Fights as:** tank.
- **Big-Boki role:** **companion**. Walks beside you and fights as a second body, drawing fire and holding a lane; never ridden.
- **Personality:** Lazy until crossed, then unstoppable. Yawns at you to say it likes you.
- **Abilities:** Gravity Slam (E, `slam`), Mass Guard (auto, `rock_guard`); merge stub: Heavy Star (`titan`).
- **Own ability later (grammar parts):** Mud Geyser: zone 3 m, damage over 3 s + slow.
- **Rarity / where:** rare, Emberfall.
- **Art note:** Huge barrel hippo, dark plum-grey hide cracked with glowing lava lines, red steam sweat, tiny ears, wide flat back.

#### Floenatee (`floenatee`)

- **Mix:** Manatee + Pack ice. **Theme:** frost. **Size:** large. **Body:** aquatic, rig `FIN-L`. **Fights as:** support.
- **Big-Boki role:** **packbeast**. Carries loot: extra pack slots on its back, which a rival can knock loose and steal.
- **Personality:** Kind and slow, everyone's friend. Hums low songs you feel through your boots.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`); merge stub: Prism Shell (`tidal_shell`).
- **Own ability later (grammar parts):** Ice Floe: wall 4 m, reflect + frost slow at the ends.
- **Rarity / where:** rare, Frostreach.
- **Art note:** Rotund grey-blue sea cow with paddle flippers and a round tail paddle, a flat slab of white pack ice on its back stacked with frosted crates and a lantern, whiskered snout.

#### Limpetor (`limpetor`)

- **Mix:** Limpet + Granite tor. **Theme:** stone. **Size:** large. **Body:** blob, rig `BLOB-L`. **Fights as:** tank.
- **Big-Boki role:** **bulwark**. Plants itself as living cover you and your squad shoot from behind; it soaks shots until it breaks.
- **Personality:** Stubborn as rock and proud of it. Grudgingly fond of whoever rides it.
- **Abilities:** Boulder Heave (E, `boulder_heave`), Mass Guard (auto, `rock_guard`); merge stub: Cairn Colossus (`cairn_colossus`).
- **Own ability later (grammar parts):** Clamp Down: aura 3 m, knockback immunity + slow foes.
- **Rarity / where:** rare, Greenreach.
- **Art note:** Wide cone-shaped granite shell with lichen patches, a muscular foot and two eye tentacles under the rim, a flat summit to sit on.

#### Umbrathere (`umbrathere`)

- **Mix:** Giant ground sloth + Night smoke. **Theme:** shadow. **Size:** large. **Body:** biped, rig `BIPED-L`. **Fights as:** tank.
- **Big-Boki role:** **companion**. Walks beside you and fights as a second body, drawing fire and holding a lane; never ridden.
- **Personality:** Brooding and protective, slow to anger. Shelters smaller Boki under its arms.
- **Abilities:** Gravity Slam (E, `slam`), Mass Guard (auto, `rock_guard`); merge stub: Heavy Star (`titan`).
- **Own ability later (grammar parts):** Smoke Shroud: zone 5 m, allies hidden (reveal-proof) 3 s.
- **Rarity / where:** rare, Gloomheart.
- **Art note:** Massive shaggy charcoal ground sloth reared on its hind legs and thick tail, huge hooked claws, dark smoke wisps rising from its fur.

#### Moundvark (`moundvark`)

- **Mix:** Aardvark + Termite mound. **Theme:** swarm. **Size:** large. **Body:** quadruped, rig `QUAD-L`. **Fights as:** tank.
- **Big-Boki role:** **watchtower**. Stands still and lets you climb on top: height, longer sight and range, but you're exposed.
- **Personality:** Easy-going and nosy, digs when it's nervous. Talks to its termites more than to you.
- **Abilities:** Hive Swarm (E, `hive_swarm`), Mass Guard (auto, `rock_guard`); merge stub: Hive Crown (`hive_crown`).
- **Own ability later (grammar parts):** Mound Swarm: zone 4 m around the kin, damage + slow.
- **Rarity / where:** rare, Bloomwild.
- **Art note:** Big pink-tan aardvark with a long snout and rabbit ears, a tall ochre termite mound rising from its back like a little tower with a flat lookout top and glowing vents, tiny termites streaming around it.

#### Goliathite (`goliathite`)

- **Mix:** Goliath beetle + Marble. **Theme:** stone. **Size:** large. **Body:** insect, rig `HEXA-L`. **Fights as:** tank.
- **Big-Boki role:** **flyer**. Lifts you: a carried glide or a hop over an abyss gap it can reach; no free flight.
- **Personality:** Earnest and hard-working, a gentle giant. Polishes its shell when it's proud of you.
- **Abilities:** Boulder Heave (E, `boulder_heave`), Mass Guard (auto, `rock_guard`); merge stub: Cairn Colossus (`cairn_colossus`).
- **Own ability later (grammar parts):** Shell Ram: dash 6 m, push + stun 0.4 s.
- **Rarity / where:** uncommon, Greenreach.
- **Art note:** Huge six-legged beetle, polished white marble wing cases veined grey and gold, cases flipped open over smoky amber flight wings, black-and-white striped thorax, a stubby Y horn, two hooked forelegs for gripping a hunter's harness.

#### Spatewader (`spatewader`)

- **Mix:** Giant salamander + Flash flood. **Theme:** storm. **Size:** large. **Body:** aquatic, rig `FIN-L`. **Fights as:** tank.
- **Big-Boki role:** **packbeast**. Carries loot: extra pack slots on its back, which a rival can knock loose and steal.
- **Personality:** Lazy and good-natured, dozes in puddles. Comes alive in a storm.
- **Abilities:** Echo Chain (E, `chain_spark`), Storm Arc (auto, `storm_arc`); merge stub: Resonance (`stormcoat`).
- **Own ability later (grammar parts):** Flash Flood: cone 6 m, push + slow.
- **Rarity / where:** rare, Stormcrest.
- **Art note:** Long flat wrinkled brown-black giant salamander, tiny bead eyes, wide frog grin, frilly skin folds on the flanks, storm-blue river-stone spots, a lashed bundle of driftwood crates riding on its back.

### Rideable (mounts, the riding spec)

#### Cindowary (`cindowary`)

- **Mix:** Cassowary + Charcoal. **Theme:** ember. **Size:** rideable. **Body:** biped, rig `BIPED-L`. **Fights as:** bruiser.
- **Big-Boki role:** **mount**. You ride it: travel speed out of combat, one rider, get off to loot or extract.
- **Personality:** Proud and territorial, fiercely loyal to its rider. Booms a warning before it charges.
- **Abilities:** Gale Lance (E, `gale_lance`), Stinger Dash (auto, `flare_dash`); merge stub: Stormwing (`stormwing`); mount speed x1.25, jump x1.1, turn x0.75.
- **Own ability later (grammar parts):** Ash Kick: cone 3 m, push + damage over 3 s.
- **Rarity / where:** rare, Emberfall.
- **Art note:** Tall flightless runner bird, shaggy ash-black plumage, a charcoal casque with glowing orange cracks, red and blue wattles, thick clawed legs, saddle behind the neck.

#### Glaciyak (`glaciyak`)

- **Mix:** Yak + Glacier ice. **Theme:** frost. **Size:** rideable. **Body:** quadruped, rig `QUAD-L`. **Fights as:** tank.
- **Big-Boki role:** **mount**. You ride it: travel speed out of combat, one rider, get off to loot or extract.
- **Personality:** Steady and warm-hearted, unbothered by anything. Snorts frost when it laughs.
- **Abilities:** Gravity Slam (E, `slam`), Mass Guard (auto, `rock_guard`); merge stub: Heavy Star (`titan`); mount speed x1.1, jump x0.9, turn x0.65.
- **Own ability later (grammar parts):** Glacier Charge: dash 8 m, push + frost slow.
- **Rarity / where:** uncommon, Frostreach.
- **Art note:** Bulky long-haired yak, dark brown coat to the ground with icicle tips, sweeping translucent blue ice horns, frosty breath, broad back.

#### Nimbostrich (`nimbostrich`)

- **Mix:** Ostrich + Thunderhead. **Theme:** storm. **Size:** rideable. **Body:** biped, rig `BIPED-L`. **Fights as:** skirmisher.
- **Big-Boki role:** **mount**. You ride it: travel speed out of combat, one rider, get off to loot or extract.
- **Personality:** Skittish and fast, afraid of nothing but boredom. Races anything that moves.
- **Abilities:** Echo Chain (E, `chain_spark`), Storm Arc (auto, `storm_arc`); merge stub: Resonance (`stormcoat`); mount speed x1.3, jump x1.0, turn x0.7.
- **Own ability later (grammar parts):** Static Sprint: dash 9 m, stun 0.3 s on pass (rider-only).
- **Rarity / where:** rare, Stormcrest.
- **Art note:** Long-necked, long-legged ostrich, body plumage a dark grey storm cloud with yellow lightning flickers, pale pink neck and legs.

#### Lilybara (`lilybara`)

- **Mix:** Capybara + Water lily. **Theme:** bloom. **Size:** rideable. **Body:** quadruped, rig `QUAD-L`. **Fights as:** support.
- **Big-Boki role:** **mount**. You ride it: travel speed out of combat, one rider, get off to loot or extract.
- **Personality:** Calm and sociable, the friend of everything. Nothing ruffles it, not even a fight.
- **Abilities:** Prism Wall (E, `prism_wall`), Refraction (auto, `refraction`); merge stub: Prism Shell (`tidal_shell`); mount speed x1.15, jump x0.9, turn x0.7.
- **Own ability later (grammar parts):** Lily Ring: aura 3 m, heal over 4 s + cleanse.
- **Rarity / where:** uncommon, Bloomwild.
- **Art note:** Barrel-bodied capybara, blunt square snout, small ears, flat back covered in green lily pads, a pink water lily on its head.

#### Duskapi (`duskapi`)

- **Mix:** Okapi + Dusk smoke. **Theme:** shadow. **Size:** rideable. **Body:** quadruped, rig `QUAD-L`. **Fights as:** trickster.
- **Big-Boki role:** **mount**. You ride it: travel speed out of combat, one rider, get off to loot or extract.
- **Personality:** Shy and graceful, vanishes when strangers come. Trusts one rider and only one.
- **Abilities:** Moon Swap (E, `moon_swap`), Echolocate (auto, `echolocate`); merge stub: Eclipse (`tempest`); mount speed x1.25, jump x1.1, turn x0.85.
- **Own ability later (grammar parts):** Fade: blink 8 m, decoy at the start.
- **Rarity / where:** rare, Gloomheart.
- **Art note:** Graceful okapi, deep plum-brown body, white stripes on the hind legs that dissolve into dark smoke, long ears, small horn knobs.

#### Heatherhorn (`heatherhorn`)

- **Mix:** Highland cow + Heather. **Theme:** bloom. **Size:** rideable. **Body:** quadruped, rig `QUAD-L`. **Fights as:** tank.
- **Big-Boki role:** **mount**. You ride it: travel speed out of combat, one rider, get off to loot or extract.
- **Personality:** Gentle and stubborn, grazes mid-fight. Bellows proudly when you climb on.
- **Abilities:** Boulder Heave (E, `boulder_heave`), Spore Patch (auto, `thorn_patch`); merge stub: Cairn Colossus (`cairn_colossus`); mount speed x1.15, jump x0.95, turn x0.7.
- **Own ability later (grammar parts):** Heather Bed: zone 4 m, root on entry + heal allies.
- **Rarity / where:** uncommon, Greenreach.
- **Art note:** Huge long-haired ginger highland cow, fringe over the eyes, wide curved horns, purple heather and wildflowers growing on its back like a saddle blanket.

## Body types and shared skeletons (for the rig plan)

Seven creature skeletons cover all 50. A `-L` rig is the same skeleton scaled up with heavier spine
weights and a **hunter socket** for its role: a saddle bone for mounts, a lookout platform for the
watchtower, a harness or carry bone for flyers, a cargo bone for packbeasts; companions and bulwarks
need none. It is not a separate skeleton. Bone counts are targets for Meshy-to-Blender fitting, not final.

| Body | Count (new) | Skeleton | Bones (target) | Who |
|---|---|---|---|---|
| quadruped | 18 (13) | **QUAD** / QUAD-L | root, pelvis, spine x3, neck x2, head, jaw, 4 legs x3 + toe, tail x3, 2 ear sockets, back socket (geode, bricks, mound) | Mycroll, Vespyx, Echolop, Glintmole, Rimeshrew, Nettlynx, Kilnbadger, Basaltoad, Nacrolin, Tuatrune; L: Gravadillo, Cairnback, Scaldamus, Moundvark, Glaciyak, Lilybara, Duskapi, Heatherhorn |
| biped | 8 (8) | **BIPED** / BIPED-L | root, pelvis, spine x3, neck, head, jaw, 2 legs x3 + toe, 2 arms x3 + hand, tail x3 (balance) | Opalisk, Sentrikat, Orchisloth, Gibbelle, Moonloris; L: Umbrathere, Cindowary, Nimbostrich (the runner birds use BIPED with arms as folded wing stubs) |
| winged | 8 (7) | **WING** / WING-L | root, body x2, neck, head, beak/jaw, 2 legs x2 + toe, 2 wings x3 + 3 feather-fan bones, tail fan x2 | Lunowl, Kindlewren, Kestrike, Thrumbird, Hoarheron, Casquebill, Murmurling; L: Squalltross (flyer: a carry socket under the feet instead of a saddle) |
| serpent | 4 (3) | **SERPENT** | root, spine chain x10, head, jaw, 4 optional limb or wing sockets along the chain | Zephyrak (wing sockets), Caecilith, Velvorm (leg nubs driven procedurally from the chain), Threadwyrm |
| insect | 4 (3) | **HEXA** / HEXA-L | root, thorax, abdomen x2, head, mandibles, 6 legs x3, 2 antennae x2, wing-case and wing sockets | Hivara, Lodestick, Marchleaf (leaf socket); L: Goliathite |
| aquatic | 4 (3) | **FIN** / FIN-L | root (hover), body x4, head, jaw, tail fin x2, 2 pectoral fins, 4 optional limb stubs | Prismander (limbs on), Selenfin; L: Floenatee (flippers), Spatewader (limbs on) |
| blob | 4 (4) | **BLOB** / BLOB-L | root, squash centre, top, 2-8 nub or eye-stalk sockets, shell socket | Mossgrade (8 nubs), Gloamshell (eye stalks, shell), Glomwort (puffball sockets); L: Limpetor |

Notes for the rig plan:
- QUAD carries the most species (18), so it should be the first skeleton built and the most tested.
- The 16 `-L` rigs need their role's socket (saddle 6, harness 2, cargo 2, lookout 1); the 3 companions
  and 2 bulwarks need only the heavier weights.
- Extra props (the geode, kiln bricks, termite mound, heather, ice floe) are separate meshes on the back
  socket, so the owner can change them later without re-rigging, which also serves "models I can later change".

## The mounts

| Boki | Body | Theme | Mount speed / jump / turn | Rarity, where | Fights as |
|---|---|---|---|---|---|
| Heatherhorn | quadruped | bloom | x1.15 / x0.95 / 0.7 | uncommon, Greenreach | tank; the first mount most players meet |
| Glaciyak | quadruped | frost | x1.1 / x0.9 / 0.65 | uncommon, Frostreach | tank; ploughs through snow |
| Lilybara | quadruped | bloom | x1.15 / x0.9 / 0.7 | uncommon, Bloomwild | support; a calm healer |
| Cindowary | biped | ember | x1.25 / x1.1 / 0.75 | rare, Emberfall | bruiser; a fast runner that kicks |
| Nimbostrich | biped | storm | x1.3 / x1.0 / 0.7 | rare, Stormcrest | skirmisher; the fastest |
| Duskapi | quadruped | shadow | x1.25 / x1.1 / 0.85 | rare, Gloomheart | trickster; nimble and hard to see |

The other ten big Boki have the roles in "Big-Boki roles" above.

## Originality check

**How it was checked.** Every name and design was checked from my own knowledge against Pokémon (all
generations through Paldea and its DLC), Digimon, Palworld, Temtem, Monster Hunter, Yo-kai Watch,
Coromon, Cassette Beasts, Nexomon, Monster Sanctuary and Dragon Quest monsters, in three passes:
1. **Name:** not the name of a franchise creature, and not a near-spelling of one. None of the 41 matched.
2. **Concept:** the animal + element pairing is not a franchise creature's pairing. Ideas that failed
   this were dropped while drafting (list below).
3. **Silhouette:** where a shape could still be confused, the art note pins down what makes ours
   different (table below), and the image-gen pass should reject any turnaround that drifts toward it.

This is a memory check, not a database search. Before any name ships in public text, run one web search
per name (41 searches) to catch something I missed, newer releases especially.

**Dropped while drafting** (too close to an existing creature): fire camel (Camerupt), krill shoal that
forms one big fish (Wishiwashi), beluga walking on land (Cetitan), dung beetle rolling a ball (Rellor),
electric beetle (Vikavolt, Charjabug), mushroom-backed arthropod (Paras), mushroom hermit crab (Paras),
dark hyena (Mightyena), boar mount (Rushoar), deer or elk mount (Eikthyrdeer, Sawsbuck), flying manta
(Celaray, Mantine), electric flying squirrel (Emolga), fire salamander (Charmander), crocodile
(Krookodile), dream tapir (Munna), horseshoe crab (Kabuto), coelacanth (Relicanth), cuttlefish
(Malamar), crow (Murkrow), electric zebra (Zebstrika), ice crab (Crabominable), ice reindeer
(Reindrix), wolf mounts (Direhowl), fire ram (Incineram), cicada (Nincada), cricket (Kricketot).

**Watch list** (kept, with what keeps them apart):

| Ours | Could drift toward | Keep it apart by |
|---|---|---|
| Lilybara (capybara) | Temtem's Capyre (a capybara; I'm not sure of its exact look) | water lilies and lily pads, pink and green, no fire; confirm with a search |
| Basaltoad | Seismitoad | charcoal grey, flat hexagonal basalt columns on the back, no blue, no bumps |
| Nettlynx | Shinx / Luxray | olive-green with nettle-leaf ear tufts and tail, no mane, no electric |
| Kestrike | Wattrel, Zapdos | a real kestrel's rust-and-slate plumage, small copper rod crest |
| Sentrikat | Watchog | real meerkat proportions, sandy, a copper weathervane tail |
| Casquebill | Toucannon | hornbill bill, black and cream, pitted iron casque, no toucan colours |
| Scaldamus | Hippowdon | plum-grey hide with glowing lava cracks, no sand, no gaping-mouth pose |
| Floenatee | Cetitan | a manatee with flippers (no legs), lying low, an ice slab on its back |
| Spatewader | Quagsire | flat wrinkled brown-black giant salamander, tiny eyes, side skin frills |
| Cindowary | Blaziken | a real cassowary body (horizontal, bird-like), not upright or humanoid |
| Goliathite | Heracross | goliath beetle stripes, short Y horn, white marble, not blue |
| Moundvark | Heatmor | aardvark ears and snout, a clay termite mound on the back |
| Orchisloth | Slakoth | three-toed sloth with orchids and moss, tan |
| Heatherhorn | Miltank, Mozzarina | shaggy ginger highland cow, long horns, heather on the back |

## Where the stubs live

All 41 new stubs are switched on (ext/boki-50-integ): `content/kin_v2/<id>.json` plus home data `content/kin/<id>.json`
(`size` cm/kg by size class; `rare`/`boss` only for the three boss-egg species). `KinLib` loads them, `Data.KIN` holds all 50, and
`Data.common_kin()` (everything not boss-egg rare, so 47) feeds wild spawns (`spawn_plan.gd`), the mystery starter egg (`hatch.gd`),
rivals, the shelter, the town and the Field Book. A species without a model draws as the `KinModels` primitives of its `look`
(ears, body, tail, feet, aura) in its colours, so it is never missing a mesh. Big-Boki roles and riding stay with docs/boki/RIDING_SPEC.md.

Not done here: per-biome spawn pools (the wild pool is uniform over `common_kin()`; the Rarity / where column is data for that later).

## Credit estimate (Phase 2 art)

Assumption from the brief: about 3 Meshy attempts per species at about 30-40 credits each, so
**90-120 credits a species**. Batches of 10, starter and early Boki first. The existing nine are in the
batches for order; if they are already paid for under S2's "current 9 Boki" phase (~1,200), skip them.

| Batch | Species | Credits |
|---|---|---|
| 1 | Mycroll, Vespyx, Prismander (starters); Lunowl, Echolop, Gravadillo (wild, early); Glintmole, Basaltoad, Murmurling (Greenreach commons); Heatherhorn (first mount) | 900-1,200 |
| 2 | Cairnback, Hivara, Zephyrak (boss eggs); Kindlewren, Rimeshrew, Mossgrade, Gloamshell, Marchleaf, Glomwort, Sentrikat (commons) | 900-1,200 |
| 3 | Kestrike, Nettlynx, Thrumbird, Lodestick, Opalisk, Kilnbadger, Hoarheron, Orchisloth, Gibbelle, Glaciyak | 900-1,200 |
| 4 | Caecilith, Velvorm, Moonloris, Threadwyrm, Squalltross, Lilybara, Goliathite, Selenfin, Casquebill, Nacrolin | 900-1,200 |
| 5 | Tuatrune, Scaldamus, Floenatee, Limpetor, Umbrathere, Moundvark, Cindowary, Nimbostrich, Duskapi, Spatewader | 900-1,200 (big ones may need a 4th try: up to ~1,400) |

- **41 new species: about 3,700-4,900 credits** (5,100 if batch 5's big Boki need extra tries).
- **All 50: about 4,500-6,000.**
- **OWNER: buy about 5,000 credits for the 41 new Boki**, per batch (~1,200 each) if preferred. Agents
  never buy; the art session pauses before it runs out.

## Owner decisions

1. **Approve the roster**, or name any Boki to swap. Nothing is modelled until then.
2. **Big-Boki roles.** Approve the six roles (mount, companion, flyer, bulwark, packbeast, watchtower),
   who has which, and the new `carry.style` values they need (specs in RIDING_SPEC.md).
3. **Merges.** The stubs reuse today's 9 merges (chosen by active ability) so they validate; their
   flavour text names the original Boki. Each new Boki needs its own merge text or form later.
4. **Abilities.** All 41 reuse the 16 existing abilities. The "own ability later" sketches are the Phase 3
   work list; some need nothing new (zones, cones, walls), Smoke Shroud needs a hide effect.
5. **A water theme?** No `tide` theme exists, so aquatic Boki wear frost, storm or lunar. Add one?
6. **Boss eggs.** No new bosses, so no new boss-egg Boki. Mark some rares for future bosses?
7. **Spawn by biome** before switching them on (see above).
8. **Riding and the other roles**: approve the specs in docs/boki/RIDING_SPEC.md.
9. **Credits**: about 5,000 for the 41 new.
