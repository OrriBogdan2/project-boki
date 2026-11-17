# Bokidex order proposal (draft for the owner, 2026-11-10)

Goal: common, expected Boki early; cooler and rarer ones later (in general, not strictly). We borrow the structure of the Pokemon regional dexes only. No names or designs.

Status: proposal. Nothing in the game, the site or the manifest was changed.

## (a) How Pokemon orders a regional dex

Source: the PokeAPI data files (regional dex numbers, legendary, mythical and baby flags, types), checked by script for Kanto, Johto (Gen 2), Hoenn (Gen 3), Sinnoh (Diamond/Pearl and Platinum), Unova (Black/White) and Paldea. Bulbapedia and Serebii could not be reached from this session.

1. **Starters are always 1 to 9.** Three lines of three stages, in the order grass, fire, water. True in all six dexes.
2. **Then the early-route commons, slots 10 to about 35.** A bird, a rodent or other plain Normal animal, and one or two bugs that evolve fast. Kanto: bugs 10 to 15, bird 16 to 18, rat 19 to 20. Johto: birds 10 to 16, rodents 17 to 20, bugs 24 to 33. Hoenn: pup 10, raccoon 12, bug 14 to 18, bird 25. Sinnoh: bird 10, beaver 13, cricket 15. Paldea: pig 10, bugs 12 to 15, bird 19.
3. **The long middle follows the order you meet them in the game.** Route by route, cave, sea, snow. This is why sea sections have runs of Water lines.
4. **Evolution lines are never split.** Zero split lines in all six dexes (78 to 204 lines each). Stages run in order. A baby sits directly before its parent. Branching families sit together (the Eevee family is one block).
5. **Single-stage creatures sit in the back half.** Their middle position is 54% to 87% of the way through each dex, and at most one is in the first quarter.
6. **Fossils have no fixed place.** Late in Kanto (138 to 142 of 151) and Johto (220 to 224 of 251), mid in Hoenn (133 to 136 of 202) and Unova (70 to 73 of 156), early in Sinnoh (36 to 39 of 151).
7. **A three-stage dragon-like "pseudo-legendary" line sits near the end**, right before or inside the legendary block. Hoenn 187 to 192 (two lines), Unova 139 to 141, Paldea 388 to 390, Kanto 147 to 149, Johto 241 to 246. Sinnoh is the exception (109 to 111).
8. **Legendaries come last, in rising rank:** trios first, then the box mascots, then mythicals at the very end. The block starts 92% to 98% of the way through. Share of the dex: Kanto 5 of 151 (3%), Johto 11 of 251 (4%), Hoenn 10 of 202 (5%), Sinnoh 6 of 151 (4%), Unova 13 of 156 (8%), Paldea 6 of 400 (1.5%).
9. **Type spread is loose, not a rule.** Counting whole lines by primary type, the longest same-type run is 2 in Unova and 3 in Kanto, but 5 to 8 Water lines in a row in Johto, Hoenn, Sinnoh and Paldea. Our rule (never more than 2 lines) is stricter than Pokemon.

## Where the current order lives

- **Game repo** (`/home/user/project-boki`): there is no dex order file. The number is the position in `Data.KIN` (`scripts/ui/dex_view.gd`, `number()`). `scripts/core/data.gd` `load_kin_content()` builds it: six hard-coded ids first (`cindle` Vespyx, `puddlet` Prismander, `burrlet` Mycroll, `zapple` Echolop, `pebbit` Gravadillo, `wisplet` Lunowl), then every other id in alphabetical order of the internal id (`basaltoad` Rampartoad, `caecilith` Zippelith, `cairnback`, ...). The game has 50 species (`content/kin_v2/*.json`), one type each, with the old theme names (ember, bloom, storm, ...).
- **Art repo**: `BOKI_NAMES.csv` has a `dex_no` column, 1 to 227, plus 5 rows marked "new". It starts Vespyx, Prismander, Mycroll lines, then follows the order Boki were added (the old 50, then Roster 200 in alphabetical order, then later additions). 27 of the 259 have no number.
- **Types** in this document use the standard names the owner chose on 11-08 (Fire, Grass, Water, ...), as in ROSTER_100.html and ROSTER_200_NEW.md. Old names: Ember Fire, Bloom Grass, Storm Electric, Frost Ice, Venom Poison, Swarm Bug, Tempest Flying, Stone Rock, Shadow Dark, Lunar Fairy, Prism Crystal, Gravity Psychic, Titan Steel, Tide Water, Wyrm Dragon, Wild Normal, Spore Spore, Echo Sound.
- "(guess)" marks a type that is not in the roster docs: 56 Boki. Most are new stages typed from their line, or type guesses the art session and coordinator posted in CHANNEL.md. Owner-set types from CHANNEL.md (Kestrike line Normal, Olmlet line Water/Crystal, Pipeworth Poison/Dragon, Jerbit line Electric, Pinster line Steel, and others) are used without a mark.

## (b) Proposed bands

| Band | Slots | Count | What goes here |
|---|---|---|---|
| Starters | 1 to 9 | 9 | Mycroll, Vespyx, Prismander lines (GAME_RULES_NOV8.md section 5) |
| Mystery egg | 10 to 19 | 10 | Ermink and its nine Ink forms, one block |
| Early common | 20 to 80 | 61 | First bird (Kestrike), first rodent (Jerbit), cocoon bug (Sculptillar), ant and cicada, then simple Normal, Water, Grass and Bug lines and the old launch commons |
| Mid game | 81 to 189 | 109 | Everything with a place feel: coast, forge, snow, sea, ruins. Two-stage lines and the bigger three-stage lines. Fossil-like Chiptero sits here |
| Late game | 190 to 234 | 45 | Dark, Dragon, Psychic and Fairy lines, the single-stage rares, then the three boss-egg rares (Hivara, Cairnback, Zephyrak) |
| Pseudo-legendary | 235 to 240 | 6 | Two three-stage dragon lines: Zipling to Seamwyrm (Dark/Dragon), then Kitlet to Kitedrake (Dragon) |
| Legendary: minor | 241 to 249 | 9 | The three cute ones first, Pavonazar last |
| Legendary: boss | 250 to 253 | 4 | Calderoise, Siegephant, Glaciammoth, Sarcobra |
| Legendary: ultra | 254 to 256 | 3 | Aurostag, Cetorgan, Hydrangor |
| Legendary: blight | 257 to 259 | 3 | Cindermaw, Enigmane, Palloth (last) |

Shares: early bands end at 31%, legendaries start at 93% (Pokemon: 92% to 98%) and are 19 of 259 (7%, close to Unova's 8%).

Rules checked by script on the table below:
- All 259 manifest Boki appear exactly once.
- Every line is one block in stage order. Branching families are one block (Ermink, Marchleaf, Echolop, Jarmit, Gravigrub).
- Never more than 2 lines in a row with the same primary type. It happens only three times (Ermink then Kestrike, Marchleaf then Mumblet, Ghoulamari then Pavonazar).
- Legendary tiers match `legendary_tier` in LIVE_MANIFEST.json.

Notes:
- Name shown is the display name; the file id follows in brackets when it differs.
- Chimelop (Jinglop) is placed with Echolop as its second final, as GAME_RULES_NOV8.md says. The lines file lists it alone.
- The 11-08 decision says branching finals share one Bokidex entry. This table still gives every form its own number so all 259 are placed. See question 5.

## (c) Full proposed order

| # | Name | Line | Type(s) | Band | Reason |
|---|---|---|---|---|---|
| 1 | Mycroll | Mycroll | Spore | Starters | starter |
| 2 | Sporcupine | Mycroll | Spore | Starters | starter |
| 3 | Ringrove | Mycroll | Spore/Grass | Starters | starter |
| 4 | Vespyx | Vespyx | Poison | Starters | starter |
| 5 | Vespox | Vespyx | Poison | Starters | starter |
| 6 | Sabryx (Glaivyx) | Vespyx | Poison/Steel | Starters | starter |
| 7 | Prismander | Prismander | Crystal | Starters | starter |
| 8 | Glassolotl | Prismander | Crystal | Starters | starter |
| 9 | Crystalotl (Chandelotl) | Prismander | Crystal/Fairy | Starters | starter |
| 10 | Ermink | Ermink | Normal | Mystery egg | egg |
| 11 | Embermink (Flarmink) | Ermink | Fire | Mystery egg | egg |
| 12 | Rippmink | Ermink | Water | Mystery egg | egg |
| 13 | Blossmink | Ermink | Grass | Mystery egg | egg |
| 14 | Voltmink | Ermink | Electric | Mystery egg | egg |
| 15 | Rimink | Ermink | Ice | Mystery egg | egg |
| 16 | Nightmink (Umbrink) | Ermink | Dark | Mystery egg | egg |
| 17 | Lunink | Ermink | Fairy | Mystery egg | egg |
| 18 | Prismink | Ermink | Crystal | Mystery egg | egg |
| 19 | Wyrmink | Ermink | Dragon | Mystery egg | egg |
| 20 | Kestrike | Kestrike | Normal | Early common | bird |
| 21 | Arcestrel | Kestrike | Normal | Early common | bird |
| 22 | Voltalon | Kestrike | Normal/Electric | Early common | bird |
| 23 | Jerbit | Jerbit | Electric | Early common | rodent |
| 24 | Jerbolt | Jerbit | Electric | Early common | rodent |
| 25 | Dynaboa | Jerbit | Electric | Early common | rodent |
| 26 | Sculptillar (Effigeetle) | Sculptillar | Rock/Bug | Early common | cocoon |
| 27 | Effigoon | Sculptillar | Rock/Bug (guess) | Early common | cocoon |
| 28 | Mortarfly | Sculptillar | Rock/Bug (guess) | Early common | cocoon |
| 29 | Marchleaf | Marchleaf | Bug | Early common | bug |
| 30 | Scythant | Marchleaf | Bug | Early common | bug |
| 31 | Harvantis | Marchleaf | Bug (guess) | Early common | bug |
| 32 | Shinobant | Marchleaf | Bug (guess) | Early common | bug |
| 33 | Reapant | Marchleaf | Bug/Grass | Early common | bug |
| 34 | Mumblet | Mumblet | Bug | Early common | bug |
| 35 | Klaxada | Mumblet | Bug | Early common | bug |
| 36 | Sirencada | Mumblet | Sound/Bug | Early common | bug |
| 37 | Dribbara | Dribbara | Water | Early common | pond |
| 38 | Soakybara | Dribbara | Water | Early common | pond |
| 39 | Geyserbara (Geysirbara) | Dribbara | Grass/Water | Early common | pond |
| 40 | Cubwom (Cubbat) | Cubwom | Normal | Early common | burrower |
| 41 | Pipwom | Cubwom | Normal | Early common | burrower |
| 42 | Critwom | Cubwom | Normal | Early common | burrower |
| 43 | Crofthorn | Crofthorn | Grass/Normal | Early common | meadow |
| 44 | Crofthollow | Crofthorn | Grass/Normal (guess) | Early common | meadow |
| 45 | Kindlewren | Kindlewren | Fire | Early common | bird |
| 46 | Embrook | Kindlewren | Fire | Early common | bird |
| 47 | Pyrraven | Kindlewren | Fire/Flying | Early common | bird |
| 48 | Moatpole | Moatpole | Rock/Water (guess) | Early common | pond |
| 49 | Rampartoad | Moatpole | Rock/Water | Early common | pond |
| 50 | Echolop | Echolop | Sound | Early common | hare |
| 51 | Howlop | Echolop | Sound/Dark | Early common | hare |
| 52 | Jinglop (Chimelop) | Echolop | Sound/Fairy | Early common | hare |
| 53 | Nymphane | Nymphane | Bug | Early common | bug |
| 54 | Rosedart | Nymphane | Bug/Crystal | Early common | bug |
| 55 | Pailmander (Bucketmander) | Pailmander | Water | Early common | pond |
| 56 | Kegmander (Barrelmander) | Pailmander | Water/Electric | Early common | pond |
| 57 | Vatmander (Cisternmander) | Pailmander | Water/Grass | Early common | pond |
| 58 | Mothlet | Mothlet | Fairy | Early common | owl |
| 59 | Lunowl | Mothlet | Fairy/Flying | Early common | owl |
| 60 | Eclipsowl | Mothlet | Fairy/Dark | Early common | owl |
| 61 | Glintmole | Glintmole | Rock | Early common | mole |
| 62 | Geodemole | Glintmole | Rock | Early common | mole |
| 63 | Gemole (Druzemole) | Glintmole | Rock/Crystal | Early common | mole |
| 64 | Nettlynx | Nettlynx | Poison/Grass | Early common | kitten |
| 65 | Thistlynx | Nettlynx | Poison/Grass | Early common | kitten |
| 66 | Briarlynx | Nettlynx | Poison/Grass | Early common | kitten |
| 67 | Stamproo | Stamproo | Normal (guess) | Early common | hopper |
| 68 | Postroo | Stamproo | Normal (guess) | Early common | hopper |
| 69 | Pillaroo | Stamproo | Normal (guess) | Early common | hopper |
| 70 | Mossgrade | Mossgrade | Grass/Steel | Early common | moss |
| 71 | Mosstodon (Mossbastion) | Mossgrade | Grass/Steel (guess) | Early common | moss |
| 72 | Murmurling | Murmurling | Bug/Sound | Early common | bird |
| 73 | Murmuron | Murmurling | Bug/Sound (guess) | Early common | bird |
| 74 | Oarlet | Oarlet | Water | Early common | river |
| 75 | Oarter | Oarlet | Water | Early common | river |
| 76 | Galleotter | Oarlet | Water/Steel | Early common | river |
| 77 | Scoopsy | Scoopsy | Ice | Early common | rodent |
| 78 | Sundormouse | Scoopsy | Ice/Normal | Early common | rodent |
| 79 | Gravadillo | Gravadillo | Psychic/Bug | Early common | common |
| 80 | Gravidon (Gravitank) | Gravadillo | Psychic/Bug (guess) | Early common | common |
| 81 | Fizzlet | Fizzlet | Electric | Mid game | plains |
| 82 | Boltstrich | Fizzlet | Electric | Mid game | plains |
| 83 | Thundrich (Thunderstrich) | Fizzlet | Electric/Flying | Mid game | plains |
| 84 | Bullpole | Bullpole | Poison | Mid game | pond |
| 85 | Bullsfrog | Bullpole | Poison/Normal | Mid game | pond |
| 86 | Quivertoad | Bullpole | Poison (guess) | Mid game | pond |
| 87 | Kerchick | Kerchick | Flying | Mid game | coast |
| 88 | Jibbatross | Kerchick | Flying | Mid game | coast |
| 89 | Canvastross | Kerchick | Flying/Water | Mid game | coast |
| 90 | Tinbrock | Tinbrock | Fire | Mid game | forge |
| 91 | Anvilbrock | Tinbrock | Fire | Mid game | forge |
| 92 | Forgebrock | Tinbrock | Fire/Steel | Mid game | forge |
| 93 | Proofhop | Proofhop | Spore | Mid game | bug |
| 94 | Loafhopper | Proofhop | Spore | Mid game | bug |
| 95 | Moundlet | Moundlet | Bug (guess) | Mid game | bug |
| 96 | Spirevark | Moundlet | Bug/Rock | Mid game | bug |
| 97 | Bubblisk | Bubblisk | Crystal/Water | Mid game | lizard |
| 98 | Tidalisk | Bubblisk | Crystal/Water | Mid game | lizard |
| 99 | Coolatee | Coolatee | Ice | Mid game | sea |
| 100 | Frigatee | Coolatee | Ice | Mid game | sea |
| 101 | Glaciatee | Coolatee | Ice | Mid game | sea |
| 102 | Thrumbird | Thrumbird | Flying | Mid game | bird |
| 103 | Lyrewing | Thrumbird | Sound/Flying | Mid game | bird |
| 104 | Buckleron | Buckleron | Rock/Water | Mid game | shore |
| 105 | Bulwartoad | Buckleron | Rock (guess) | Mid game | shore |
| 106 | Citadoad | Buckleron | Rock/Water (guess) | Mid game | shore |
| 107 | Fawnshroom (Fawngus) | Fawnshroom | Spore | Mid game | bog |
| 108 | Hatstag | Fawnshroom | Spore/Grass | Mid game | bog |
| 109 | Pinster | Pinster | Steel, second type open | Mid game | bug |
| 110 | Tiltster | Pinster | Steel, second type open | Mid game | bug |
| 111 | Bastling | Bastling | Water/Rock (guess) | Mid game | shore |
| 112 | Crabulwark (Bastionpet) | Bastling | Water/Rock (guess) | Mid game | shore |
| 113 | Gongibbon | Gongibbon | Sound | Mid game | temple |
| 114 | Gongrowl | Gongibbon | Sound/Steel | Mid game | temple |
| 115 | Pangolith (Terrasloth) | Pangolith | Grass/Crystal | Mid game | forest |
| 116 | Bonsolith | Pangolith | Grass (guess) | Mid game | forest |
| 117 | Rimekit | Rimekit | Ice (guess) | Mid game | snow |
| 118 | Rimeshrew | Rimekit | Ice | Mid game | snow |
| 119 | Rimefang | Rimekit | Ice (guess) | Mid game | snow |
| 120 | Pocketpus | Pocketpus | Poison | Mid game | river |
| 121 | Bladypus | Pocketpus | Poison | Mid game | river |
| 122 | Barokit | Barokit | Electric (guess) | Mid game | weather |
| 123 | Barokat | Barokit | Electric/Normal | Mid game | weather |
| 124 | Barostorm | Barokit | Electric (guess) | Mid game | weather |
| 125 | Teapotamus | Teapotamus | Fire | Mid game | steam |
| 126 | Chuggamus | Teapotamus | Fire/Steel | Mid game | steam |
| 127 | Magnestick (Lodestick) | Magnestick | Psychic/Dark | Mid game | bug |
| 128 | Magnestaff (Lodestaff) | Magnestick | Psychic/Dark (guess) | Mid game | bug |
| 129 | Pinguin | Pinguin | Ice/Normal (guess) | Mid game | snow |
| 130 | Rollguin | Pinguin | Ice/Normal (guess) | Mid game | snow |
| 131 | Kingpinguin | Pinguin | Ice/Normal (guess) | Mid game | snow |
| 132 | Glomwort | Glomwort | Spore/Poison | Mid game | slime |
| 133 | Glombulus (Glomworth) | Glomwort | Spore/Poison (guess) | Mid game | slime |
| 134 | Foldbat | Foldbat | Sound | Mid game | cave |
| 135 | Fanpire | Foldbat | Sound | Mid game | cave |
| 136 | Chiptero | Chiptero | Rock | Mid game | fossil |
| 137 | Pickadactyl | Chiptero | Rock | Mid game | fossil |
| 138 | Clinkpede | Clinkpede | Poison | Mid game | scrapyard |
| 139 | Chainipede | Clinkpede | Poison/Bug | Mid game | scrapyard |
| 140 | Skidlet | Skidlet | Ice | Mid game | ice |
| 141 | Skateron | Skidlet | Ice/Flying | Mid game | ice |
| 142 | Lanceron | Skidlet | Ice/Flying | Mid game | ice |
| 143 | Anchorpup (Anchorbill) | Anchorpup | Psychic/Water | Mid game | coast |
| 144 | Harpwhal (Anchorhorn) | Anchorpup | Psychic/Water (guess) | Mid game | coast |
| 145 | Bellowlet | Bellowlet | Fire | Mid game | forge |
| 146 | Furnowary (Furnacowary) | Bellowlet | Fire/Steel | Mid game | forge |
| 147 | Xylogator | Xylogator | Water/Sound (guess) | Mid game | swamp |
| 148 | Marimbite | Xylogator | Water/Sound (guess) | Mid game | swamp |
| 149 | Glockodile | Xylogator | Water/Sound (guess) | Mid game | swamp |
| 150 | Spanglin | Spanglin | Crystal (guess) | Mid game | cave |
| 151 | Mirrolin | Spanglin | Crystal/Psychic | Mid game | cave |
| 152 | Rattlebub | Rattlebub | Sound | Mid game | desert |
| 153 | Maracoil | Rattlebub | Sound/Poison | Mid game | desert |
| 154 | Filefin | Filefin | Water/Steel (guess) | Mid game | sea |
| 155 | Carpenjaw | Filefin | Water/Steel (guess) | Mid game | sea |
| 156 | Sawright | Filefin | Water/Steel (guess) | Mid game | sea |
| 157 | Lanterloris | Lanterloris | Fairy/Fire | Mid game | night |
| 158 | Glowris (Lanternlong) | Lanterloris | Fairy/Fire (guess) | Mid game | night |
| 159 | Kayak | Kayak | Ice | Mid game | tundra |
| 160 | Prowyak | Kayak | Ice | Mid game | tundra |
| 161 | Dreadnoyak | Kayak | Ice/Steel | Mid game | tundra |
| 162 | Puffuse | Puffuse | Electric | Mid game | sea |
| 163 | Blastopuff | Puffuse | Electric/Psychic | Mid game | sea |
| 164 | Polyshroom | Polyshroom | Spore | Mid game | sea |
| 165 | Starcap | Polyshroom | Spore | Mid game | sea |
| 166 | Medushroom | Polyshroom | Spore/Poison | Mid game | sea |
| 167 | Pebblamb | Pebblamb | Water/Crystal | Mid game | shore |
| 168 | Tesselamb | Pebblamb | Rock/Normal (guess) | Mid game | shore |
| 169 | Latchling | Latchling | Steel | Mid game | ruins |
| 170 | Lockatara | Latchling | Steel | Mid game | ruins |
| 171 | Vaultara | Latchling | Steel | Mid game | ruins |
| 172 | Jarmit | Jarmit | Water | Mid game | branching |
| 173 | Lanternmit | Jarmit | Water/Fire | Mid game | branching |
| 174 | Stormit | Jarmit | Water/Electric | Mid game | branching |
| 175 | Terrarimit | Jarmit | Water/Grass | Mid game | branching |
| 176 | Tootle | Tootle | Sound | Mid game | ruins |
| 177 | Gramofrill | Tootle | Sound | Mid game | ruins |
| 178 | Phonodrake | Tootle | Sound | Mid game | ruins |
| 179 | Narfoil | Narfoil | Ice | Mid game | sea |
| 180 | Parrywhal | Narfoil | Ice | Mid game | sea |
| 181 | Foalaround | Foalaround | Fairy (guess) | Mid game | fair |
| 182 | Canopony | Foalaround | Fairy (guess) | Mid game | fair |
| 183 | Carrousteed | Foalaround | Fairy (guess) | Mid game | fair |
| 184 | Morelkin | Morelkin | Spore | Mid game | forest |
| 185 | Truffapir | Morelkin | Spore | Mid game | forest |
| 186 | Morelossus | Morelkin | Spore/Steel | Mid game | forest |
| 187 | Grainspin | Grainspin | Rock | Mid game | ruins |
| 188 | Sandwidow | Grainspin | Rock | Mid game | ruins |
| 189 | Hourachnid | Grainspin | Rock/Fairy | Mid game | ruins |
| 190 | Parasolth | Parasolth | Dark | Late game | shadow |
| 191 | Ribbrella (Umbrathere) | Parasolth | Dark/Flying | Late game | shadow |
| 192 | Gravigrub | Gravigrub | Psychic | Late game | cosmic |
| 193 | Orbitle | Gravigrub | Psychic | Late game | cosmic |
| 194 | Scarabit | Gravigrub | Psychic/Fairy | Late game | cosmic |
| 195 | Meteorab | Gravigrub | Psychic/Rock | Late game | cosmic |
| 196 | Wickapi | Wickapi | Dark/Fire | Late game | shadow |
| 197 | Snuffapi | Wickapi | Dark/Fire | Late game | shadow |
| 198 | Candelapi (Chandelapi) | Wickapi | Dark/Fire | Late game | shadow |
| 199 | Pagodito | Pagodito | Dragon | Late game | dragon |
| 200 | Pagoguana | Pagodito | Dragon/Rock | Late game | dragon |
| 201 | Lensling | Lensling | Fairy | Late game | mystic |
| 202 | Scopeleon | Lensling | Fairy | Late game | mystic |
| 203 | Domeleon | Lensling | Fairy/Crystal | Late game | mystic |
| 204 | Blotlet | Blotlet | Dark | Late game | shadow |
| 205 | Slog | Blotlet | Dark | Late game | shadow |
| 206 | Sloggoth | Blotlet | Dark/Psychic | Late game | shadow |
| 207 | Knotling | Knotling | Spore (guess) | Late game | dragon |
| 208 | Knotwyrm | Knotling | Spore/Dragon | Late game | dragon |
| 209 | Bathilus | Bathilus | Psychic | Late game | fossil |
| 210 | Torpecone | Bathilus | Psychic | Late game | fossil |
| 211 | Dreadmonite | Bathilus | Psychic/Water | Late game | fossil |
| 212 | Grammite | Grammite | Bug | Late game | dragon |
| 213 | Dobsabre | Grammite | Dragon/Bug | Late game | dragon |
| 214 | Duskargot (Gloamshell) | Duskargot | Dark/Fairy | Late game | shadow |
| 215 | Duskspire (Gloamspire) | Duskargot | Dark/Fairy (guess) | Late game | shadow |
| 216 | Olmlet | Olmlet | Water/Crystal | Late game | porcelain |
| 217 | Glazolm | Olmlet | Water/Crystal | Late game | porcelain |
| 218 | Gildwyrm (Kintsuwyrm) | Olmlet | Water/Crystal | Late game | porcelain |
| 219 | Malletary | single | Normal/Steel | Late game | rare |
| 220 | Lurklet | Lurklet | Dark | Late game | deep |
| 221 | Snapler | Lurklet | Dark | Late game | deep |
| 222 | Maulangler | Lurklet | Dark | Late game | deep |
| 223 | Pipewurm | Pipewurm | Poison | Late game | dragon |
| 224 | Pipeworth | Pipewurm | Poison/Dragon | Late game | dragon |
| 225 | Lunafin (Selenfin) | Lunafin | Fairy/Water | Late game | moon |
| 226 | Lunarca (Selenwhale) | Lunafin | Fairy/Water (guess) | Late game | moon |
| 227 | Reelacine | single | Dark/Normal | Late game | rare |
| 228 | Pawnfry | Pawnfry | Normal | Late game | dragon |
| 229 | Gambitfin | Pawnfry | Normal | Late game | dragon |
| 230 | Checkmare | Pawnfry | Dragon/Steel | Late game | dragon |
| 231 | Gilabacus | single | Poison/Fairy | Late game | rare |
| 232 | Hivara | single | Bug/Steel | Late game | boss-egg |
| 233 | Cairnback | single | Steel/Rock | Late game | boss-egg |
| 234 | Zephyrak | single | Flying/Dragon | Late game | boss-egg |
| 235 | Zipling | Zipling | Dark | Pseudo-legendary | pseudo |
| 236 | Zipperpent (Zippelith) | Zipling | Dark | Pseudo-legendary | pseudo |
| 237 | Seamwyrm | Zipling | Dark/Dragon | Pseudo-legendary | pseudo |
| 238 | Kitlet | Kitlet | Dragon | Pseudo-legendary | pseudo |
| 239 | Ribbonwyrm | Kitlet | Dragon/Flying | Pseudo-legendary | pseudo |
| 240 | Kitedrake (Dragonkite) | Kitlet | Dragon/Flying | Pseudo-legendary | pseudo |
| 241 | Luckhop | single | Grass/Fairy (guess) | Legendary: minor | minor |
| 242 | Twinklup | single | Normal/Fairy (guess) | Legendary: minor | minor |
| 243 | Lockwren | single | Flying/Steel (guess) | Legendary: minor | minor |
| 244 | Clionice (Glacione) | single | Ice/Fairy | Legendary: minor | minor |
| 245 | Cometail | single | Fairy/Psychic (guess) | Legendary: minor | minor |
| 246 | Wayshell | single | Water/Psychic (guess) | Legendary: minor | minor |
| 247 | Pharoheron | single | Flying/Electric (guess) | Legendary: minor | minor |
| 248 | Ghoulamari | single | Fairy/Dark | Legendary: minor | minor |
| 249 | Pavonazar | single | Fairy/Crystal | Legendary: minor | minor |
| 250 | Calderoise | single | Fire/Rock (guess) | Legendary: boss | boss |
| 251 | Siegephant | single | Steel/Rock (guess) | Legendary: boss | boss |
| 252 | Glaciammoth | single | Ice/Steel | Legendary: boss | boss |
| 253 | Sarcobra | single | Dragon/Dark | Legendary: boss | boss |
| 254 | Aurostag | single | Ice/Fairy (guess) | Legendary: ultra | ultra |
| 255 | Organwhal (Cetorgan) | single | Sound/Fairy | Legendary: ultra | ultra |
| 256 | Hydrangor | single | Grass/Dragon | Legendary: ultra | ultra |
| 257 | Cindermaw | single | Fire/Dark (guess) | Legendary: blight | blight |
| 258 | Enigmane (Sphinxblight) | single | Poison/Psychic (guess) | Legendary: blight | blight |
| 259 | Palloth | single | Bug/Dark (guess) | Legendary: blight | blight |

## (d) Open questions for the owner

1. **Starters.** The docs say Mycroll, Vespyx and Prismander. Is that still the trio, and is Mycroll first the right order? There is no Fire or Water starter; is that on purpose?
2. **Ermink.** It is the mystery egg, so it sits at 10 to 19 right after the starters. Pokemon puts its branching gift creature late. Keep it early, or move the block to the late band?
3. **Pseudo-legendary line.** We propose Kitlet to Kitedrake as the last line before the legendaries, with Zipling to Seamwyrm just before it. Right pick, or should it be one line only?
4. **Types.** 56 Boki have guessed types, Pinster's second type is open, and Glombulus changed to a paint look. The game still has 50 species with one old-name type each. Which list is the source of truth, and who sets the missing types?
5. **Numbers for branch forms.** Do branch finals and Ink forms get their own numbers (259 entries, as here) or share one entry with the base (fewer numbers)?
6. **Meet order.** Pokemon orders the middle by where you meet each creature. Our docs have no biome per Boki. Should the mid band be re-sorted by biome once main assigns them, and are the boss-egg rares right at 232 to 234?
