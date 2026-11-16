# Series Boki modes: every Boki is found in exactly one mode

Owner rule (briefs/DECISIONS.md, 2026-11-11, CORE SERIES PRINCIPLES 2): Project Boki is a series of many
games/modes, and every Boki type is found in exactly one of them. Each mode has its own spawn table
with three rarities, COMMON, RARE and VERY RARE, and the rarer Boki sit behind its harder
difficulties. It's not an ownership lock: a Boki you own goes anywhere, you just only *find* it in
its mode. The Bokidex shows where each Boki is found and how rare it is.

## The rule
- **One line, one mode.** An evolution line stays together; its base form decides the mode.
- **Three rarities per mode.** A species' draw tickets: common 6, rare 3, very rare 1 (a very rare
  one is 6x less likely than a common one in the same pool).
- **Difficulty gates.** A line has a `min_difficulty` in its mode's ladder. Heart Raid:
  Normal = commons, Hard = + rares, Nightmare = + very rares. Modes with no ladder yet use `normal`.
- **Clarity first (principle 1).** Rarity only picks *which* Boki. *Where* and *when* stay fixed:
  wild spots, rare spots and lair eggs keep their fixed points and timers; no new randomness.
- **Hero/starter lines stay put.** The three starter-egg lines (Vespyx/cindle, Prismander/puddlet,
  Mycroll/burrlet) and the other launch kin (zapple, pebbit, wisplet) stay Expedition commons, where
  players meet them today.

## Data and code
- `content/rules/boki_modes.json`: every Bokidex line (keyed by its dex base id; `kin` = the game's
  species id when the game has it) with `mode`, `rarity`, `min_difficulty`; the mode list with each
  mode's difficulty ladder and, for Expeditions, which rarities each spawn site draws.
- `scripts/core/boki_modes.gd` (`BokiModes`): `of(species)`, `tickets(species)`,
  `pool(mode, rarities, difficulty)`, `site_pool(mode, site)`, `draw(pool, rng)` (one rng draw).
  Heart Raid asks `BokiModes.pool("heart_raid", ["common", "rare", "very_rare"], difficulty)`.
- Expeditions: wild spots draw `site_pool("expedition", "wild")` (commons + rares), the Rare Boki
  spots (SpawnPlan) draw `"rare_spot"` (rares + very rares). Boss-egg kin (content/kin `"rare"`)
  never spawn; they only hatch from their lair boss's Rare Egg, and they are Expedition very rares.
  The hatch scene's mystery egg draws with the same tickets (its odds are unchanged).
- Check: `--boki-modes-check` (every species has one mode, Expedition pools never yield another
  mode's Boki, ticket odds, Heart Raid gates).

## Rarity of the 50 game kin
From docs/boki/ROSTER_50.md: starter and common = COMMON, uncommon = RARE, rare (the big and rideable
ones) and boss = VERY RARE. This keeps the mystery egg's odds exactly (6/3/1) and gives three tiers of
similar size, with the tickets making each step rarer in play. Alternative not taken: common +
uncommon = COMMON (34 commons, 13 rares, 3 very rares), flatter and it would change the mystery egg.

## Counts (lines)
| Mode | COMMON | RARE | VERY RARE | Total |
|---|---|---|---|---|
| Expeditions | 15 | 19 | 16 | 50 |
| Heart Raid | 10 | 7 | 4 | 21 |
| The farm | 4 | 3 | 1 | 8 |
| Tutorial | 2 | 1 | 0 | 3 |
| Tidewatch (future) | 4 | 3 | 2 | 9 |
| Blightdeep (future) | 5 | 5 | 3 | 13 |
| Skyrun (future) | 4 | 6 | 3 | 13 |
| **All** | 44 | 44 | 29 | 117 |

Types are spread so every mode has its own flavour without owning a type: Expeditions cover all 18
types; Heart Raid 16 (no Grass or Flying lines); the future modes lean on a theme (Water for
Tidewatch, Dark/Poison/Bug/Spore for Blightdeep, Flying/Fairy/Sound for Skyrun). The Bokidex-only
lines (not in the game yet) go to Heart Raid, the farm, the tutorial and the three reserved modes, so
no Boki players can find today disappears from Expeditions.

## Expeditions (PvPvE): the 50 game kin
117 lines = the 116 Bokidex lines plus Bellowary (`cindowary`), which is in the game but has no
Bokidex page yet.

| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| barokit | sentrikat | barokit > barokat > barostorm | Electric/Normal | COMMON | Normal |
| echolop | zapple | echolop > howlop | Sound | COMMON | Normal |
| glintmole | glintmole | glintmole > geodemole > druzemole | Rock | COMMON | Normal |
| gloamshell | gloamshell | gloamshell > gloamspire | Dark/Fairy | COMMON | Normal |
| glomwort | glomwort | glomwort > glomworth | Poison/Fairy | COMMON | Normal |
| kindlewren | kindlewren | kindlewren > embrook > pyrraven | Fire | COMMON | Normal |
| marchleaf | marchleaf | marchleaf > shinobant > scythant (+2) | Bug | COMMON | Normal |
| moatpole | basaltoad | moatpole > rampartoad | Normal | COMMON | Normal |
| mossgrade | mossgrade | mossgrade > mossbastion | Grass/Steel | COMMON | Normal |
| mothlet | wisplet | mothlet > lunowl > eclipsowl | Fairy | COMMON | Normal |
| murmurling | murmurling | murmurling > murmuron | Bug/Sound | COMMON | Normal |
| mycroll | burrlet | mycroll > sporcupine > ringrove | Spore | COMMON | Normal |
| prismander | puddlet | prismander > glassolotl > chandelotl | Crystal | COMMON | Normal |
| rimekit | rimeshrew | rimekit > rimeshrew > rimefang | Ice | COMMON | Normal |
| vespyx | cindle | vespyx > vespox > glaivyx | Poison | COMMON | Normal |
| bubblisk | opalisk | bubblisk > tidalisk | Crystal/Water | RARE | Normal |
| crofthorn | heatherhorn | crofthorn > crofthollow | Grass/Normal | RARE | Normal |
| dribbara | lilybara | dribbara > soakybara > geysirbara | Water | RARE | Normal |
| effigeetle | goliathite | effigeetle > effigoon > mortarfly | Rock/Bug | RARE | Normal |
| gongibbon | gibbelle | gongibbon > gongrowl | Sound | RARE | Normal |
| gravadillo | pebbit | gravadillo > gravitank | Psychic/Bug | RARE | Normal |
| kayak | glaciyak | kayak > prowyak > dreadnoyak | Ice | RARE | Normal |
| kerchick | squalltross | kerchick > jibbatross > canvastross | Flying | RARE | Normal |
| kestrike | kestrike | kestrike > arcestrel > voltalon | Normal | RARE | Normal |
| knotling | threadwyrm | knotling > knotwyrm | Spore/Dragon | RARE | Normal |
| lanterloris | moonloris | lanterloris > lanternlong | Fairy/Fire | RARE | Normal |
| lodestick | lodestick | lodestick > lodestaff | Psychic/Dark | RARE | Normal |
| nettlynx | nettlynx | nettlynx > thistlynx > briarlynx | Poison/Grass | RARE | Normal |
| pipewurm | velvorm | pipewurm > pipeworth | Poison | RARE | Normal |
| skidlet | hoarheron | skidlet > skateron > lanceron | Ice | RARE | Normal |
| terrasloth | orchisloth | terrasloth | Grass/Crystal | RARE | Normal |
| thrumbird | thrumbird | thrumbird > lyrewing | Flying | RARE | Normal |
| tinbrock | kilnbadger | tinbrock > anvilbrock > forgebrock | Fire | RARE | Normal |
| zipling | caecilith | zipling > zippelith > seamwyrm | Dark | RARE | Normal |
| anchorbill | casquebill | anchorbill > anchorhorn | Psychic/Water | VERY RARE | Normal |
| bucketmander | spatewader | bucketmander > barrelmander > cisternmander | Water | VERY RARE | Normal |
| buckleron | limpetor | buckleron > bulwartoad | Rock/Water | VERY RARE | Normal |
| cairnback | cairnback | cairnback | Steel/Rock | VERY RARE | Normal |
| cindowary | cindowary | cindowary | Fire | VERY RARE | Normal |
| coolatee | floenatee | coolatee > frigatee > glaciatee | Ice | VERY RARE | Normal |
| fizzlet | nimbostrich | fizzlet > boltstrich > thunderstrich | Electric | VERY RARE | Normal |
| hivara | hivara | hivara | Bug/Steel | VERY RARE | Normal |
| latchling | tuatrune | latchling > lockatara > vaultara | Steel | VERY RARE | Normal |
| moundlet | moundvark | moundlet > spirevark | Normal | VERY RARE | Normal |
| parasolth | umbrathere | parasolth > umbrathere | Dark | VERY RARE | Normal |
| selenfin | selenfin | selenfin > selenwhale | Fairy/Water | VERY RARE | Normal |
| spanglin | nacrolin | spanglin > mirrolin | Normal | VERY RARE | Normal |
| teapotamus | scaldamus | teapotamus > chuggamus | Fire | VERY RARE | Normal |
| wickapi | duskapi | wickapi > snuffapi > chandelapi | Dark/Fire | VERY RARE | Normal |
| zephyrak | zephyrak | zephyrak | Flying/Dragon | VERY RARE | Normal |

## Heart Raid (PvE): its own set, gated by difficulty
Normal finds the commons, Hard adds the rares, Nightmare adds the very rares (the four boss-tier
Boki). None of these are in the game yet: the raid brings them in.

| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| bellowlet | - | bellowlet > furnacowary | Fire | COMMON | Normal |
| clinkpede | - | clinkpede > chainipede | Bug | COMMON | Normal |
| foldbat | - | foldbat > fanpire | Sound | COMMON | Normal |
| grainspin | - | grainspin > sandwidow > hourachnid | Rock | COMMON | Normal |
| lensling | - | lensling > scopeleon > domeleon | Fairy | COMMON | Normal |
| lurklet | - | lurklet > snapler > maulangler | Dark | COMMON | Normal |
| pebblamb | - | pebblamb > tesselamb | Water/Crystal | COMMON | Normal |
| proofhop | - | proofhop > loafhopper | Spore | COMMON | Normal |
| puffuse | - | puffuse > blastopuff | Electric | COMMON | Normal |
| scoopsy | - | scoopsy > sundormouse | Ice | COMMON | Normal |
| filefin | - | filefin > carpenjaw > sawright | Water/Steel | RARE | Hard |
| gravigrub | - | gravigrub > orbitle > scarabit > meteorab | Psychic | RARE | Hard |
| jerbit | - | jerbit > jerbolt > dynaboa | Electric | RARE | Hard |
| kitlet | - | kitlet > ribbonwyrm > dragonkite | Dragon | RARE | Hard |
| malletary | - | malletary | Normal/Steel | RARE | Hard |
| narfoil | - | narfoil > parrywhal | Ice | RARE | Hard |
| quivertoad | - | quivertoad | Poison | RARE | Hard |
| calderoise | - | calderoise | Fire/Rock | VERY RARE | Nightmare |
| glaciammoth | - | glaciammoth | Ice/Steel | VERY RARE | Nightmare |
| sarcobra | - | sarcobra | Dragon/Dark | VERY RARE | Nightmare |
| siegephant | - | siegephant | Steel/Rock | VERY RARE | Nightmare |

## The farm / home
Found at the farm (Shelter strays and the stray that turns up when you have none, once these lines
are in the game).

| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| bonsolith | - | bonsolith | Grass | COMMON | Normal |
| citadoad | - | citadoad | Normal | COMMON | Normal |
| morelkin | - | morelkin > truffapir > morelossus | Spore | COMMON | Normal |
| oarlet | - | oarlet > oarter > galleotter | Water | COMMON | Normal |
| foalaround | - | foalaround > canopony > carrousteed | Fairy | RARE | Normal |
| pinguin | - | pinguin > rollguin > kingpinguin | Ice/Normal | RARE | Normal |
| stamproo | - | stamproo > postroo > pillaroo | Normal | RARE | Normal |
| luckhop | - | luckhop | Grass/Fairy | VERY RARE | Normal |

## Tutorial
The first Boki you meet; all Normal type on purpose.

| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| cubbat | - | cubbat > pipwom > critwom | Normal | COMMON | Normal |
| ermink | - | ermink > flarmink > rippmink (+7) | Normal | COMMON | Normal |
| bastling | - | bastling | Normal | RARE | Normal |

## Reserved: three future modes
Each idea gets a set of reserved lines with its rarity already picked, so it can ship with its own
Boki list, rarity table and difficulty gates on day one.

1. **Tidewatch** (co-op, 1-4): hold a harbour lighthouse through a night of tides. Every wave rolls
   in from a marked channel on a fixed clock with a countdown; between tides you repair sea walls
   and catch what washed in. Water and Crystal Boki.
2. **Blightdeep** (solo or duo): a descent into the Blight on hand-built floors. Each floor has fixed
   camps and a sealed exit that opens on a timer; deeper floors are the difficulty ladder and hold
   the three blight-tier Boki. Dark, Poison, Bug and Spore Boki.
3. **Skyrun** (up to 8): glider races through marked ring courses over the islands, with fixed
   updraft lanes and timed gates. Winning heats on harder cups finds the three ultra-tier Boki.
   Flying, Fairy, Sound and Electric Boki.

### Tidewatch
| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| bastionpet | - | bastionpet | Rock/Water | COMMON | Normal |
| bathilus | - | bathilus > torpecone > dreadmonite | Psychic | COMMON | Normal |
| olmlet | - | olmlet > glazolm > kintsuwyrm | Water/Crystal | COMMON | Normal |
| pocketpus | - | pocketpus > bladypus | Poison | COMMON | Normal |
| glacione | - | glacione | Ice/Fairy | RARE | Normal |
| pawnfry | - | pawnfry > gambitfin > checkmare | Normal | RARE | Normal |
| xylogator | - | xylogator > marimbite > glockodile | Water/Sound | RARE | Normal |
| jarmit | - | jarmit > lanternmit > stormit > terrarimit | Water | VERY RARE | Normal |
| wayshell | - | wayshell | Water/Psychic | VERY RARE | Normal |

### Blightdeep
| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| blotlet | - | blotlet > slog > sloggoth | Dark | COMMON | Normal |
| bullpole | - | bullpole > bullsfrog | Poison | COMMON | Normal |
| fawngus | - | fawngus > hatstag | Spore | COMMON | Normal |
| grammite | - | grammite > dobsabre | Bug | COMMON | Normal |
| polyshroom | - | polyshroom > starcap > medushroom | Spore | COMMON | Normal |
| ghoulamari | - | ghoulamari | Fairy/Dark | RARE | Normal |
| gilabacus | - | gilabacus | Poison/Fairy | RARE | Normal |
| mumblet | - | mumblet > klaxada > sirencada | Bug | RARE | Normal |
| nymphane | - | nymphane > rosedart | Bug | RARE | Normal |
| reelacine | - | reelacine | Dark/Normal | RARE | Normal |
| cindermaw | - | cindermaw | Fire/Dark | VERY RARE | Normal |
| palloth | - | palloth | Bug/Dark | VERY RARE | Normal |
| sphinxblight | - | sphinxblight | Poison/Psychic | VERY RARE | Normal |

### Skyrun
| Line (dex base) | Game id | Evolution line | Types | Rarity | From difficulty |
|---|---|---|---|---|---|
| chiptero | - | chiptero > pickadactyl | Rock | COMMON | Normal |
| pinster | - | pinster > tiltster | Steel/Bug | COMMON | Normal |
| rattlebub | - | rattlebub > maracoil | Sound | COMMON | Normal |
| tootle | - | tootle > gramofrill > phonodrake | Sound | COMMON | Normal |
| cometail | - | cometail | Fairy/Psychic | RARE | Normal |
| lockwren | - | lockwren | Flying/Steel | RARE | Normal |
| pagodito | - | pagodito > pagoguana | Dragon | RARE | Normal |
| pavonazar | - | pavonazar | Fairy/Crystal | RARE | Normal |
| pharoheron | - | pharoheron | Flying/Electric | RARE | Normal |
| twinklup | - | twinklup | Normal/Fairy | RARE | Normal |
| aurostag | - | aurostag | Ice/Fairy | VERY RARE | Normal |
| cetorgan | - | cetorgan | Sound/Fairy | VERY RARE | Normal |
| hydrangor | - | hydrangor | Grass/Dragon | VERY RARE | Normal |

## Not wired yet (on purpose, nothing to find there today)
Shelter and farm strays (Shelter, Lifeline), rival hunters' Boki (Match.bot_kin_record), town
visitors and the starter-roster gifts still draw from `Data.common_kin()`. Every game species is an
Expedition Boki today, so nothing leaks; when farm or Heart Raid lines join the game, those draws
move to `BokiModes.pool("farm", ...)` / the raid's own pool (docs/DEBT.md).
