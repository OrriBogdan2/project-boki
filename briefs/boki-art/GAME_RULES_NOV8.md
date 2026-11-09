# Boki game rules decided Nov 8 (owner): final consolidated version
Supersedes the scattered Nov 8 notes in EXT_TO_MAIN.md (some of those were later reversed). Roster data: `ROSTER_100.html` (array `G`), 124 species.

## 1. Types
- Every species has 1 or 2 types (no type chart, identity only). Add a second type slot.
- 18 themes: the existing 15 plus **Tide** (water), **Wyrm** (dragon) and **Wild** (normal).
- Mapping: Ember fire, Bloom grass, Storm electric, Frost ice, Venom poison, Swarm bug, Tempest flying, Stone rock and ground, Shadow ghost and dark, Lunar psychic, Prism fairy, Gravity steel, Titan fighting, Tide water, Wyrm dragon, Wild normal, plus Spore and Echo (our own).
- Each species' types are in ROSTER_100.html.

## 2. Stages
- Default is 3 stages; some lines have 2; 23 species are single-stage.
- Suggested levels: stage 2 at Grown (level 8), stage 3 at Elder (level 16).
- Evolution is a real form swap (new species id and model), not just a stat node.

## 3. Branching finals (4 lines, last evolution only)
The final form is set by which trained stat (Training post: Power, Guard, Speed) is higher at the moment it evolves. On a tie, the affinity path decides (fierce = Power, steadfast = Guard, swift = Speed). Show a lean hint on the Boki screen before it evolves. Paths otherwise stay as stat flavour only.

| Line | Higher Power | Higher Guard | Higher Speed |
|---|---|---|---|
| Mycroll > Sporcupine | Amanitusk | Ringrove | |
| Vespyx > Vespox | Glaivyx | | Lashyx |
| Prismander > Glassolotl | | Geodelotl | Chandelotl |
| Echolop (2-stage) | Howlop | | Chimelop |

## 4. Inks (new item type)
- 9 Inks, one per type: Ember, Tide, Bloom, Storm, Frost, Shadow, Lunar, Prism, Wyrm.
- Using an Ink evolves:
  - **Ermink** into Flarmink, Rippmink, Blossmink, Voltmink, Rimink, Umbrink, Lunink, Prismink, Wyrmink (each single-type).
  - **Jarmit** (rare, Tide) into Lanternmit (Ember Ink), Stormit (Storm Ink) or Terrarimit (Bloom Ink).
- Never call them shards or essence (shards are armour loot; essence is lore).
- Good boss drops and black-market stock.

## 5. Starters
- Mycroll, Vespyx and Prismander.
- The **mystery egg hatches Ermink** (not a random common Boki, not Hatchet).

## 6. Sex (revised 20:18: one special rule per line)
- Every Boki has a sex, 50/50 (hatch, wild spawn, saved with uid and lineage, used in breeding, shown on the Boki screen).
- **Each line gets at most ONE special rule**: either a branching final (training stat or Ink) OR male/female looks, never both.
- Male/female looks only on these non-branching lines, through every evolved stage (babies differ little or not at all): Bellowary line (Bellowlet, Bellowary, Furnacowary); Gongibbon and Gongrowl; Kestrike, Arcestrel and Voltalon; Lunowl and Eclipsowl (Mothlet little or none); Murmurling.
- The starter lines, Echolop, Ermink and Jarmit branch, so they have ONE look each. (The female Vespox sheet is retired.)
- Per-species flag such as `sex_forms: true`. The existing sheet is the male look.

## 7. Renames and line changes
- Gongibbon evolves into **Gongrowl** (replaces Carillangutan).
- The old Vespox sheet became **Glaivyx**; Vespox is a new, smaller middle form.
- Mystery-egg experiments Hatchet, Skeinling and Lidcoon/Kegpup lines are dropped.

## 8. 3D (coordinator, 20:07)
Only the final form of each line goes to 3D for now; the third-stage forms stay 2D until Meshy credits allow.

## Owner decision 2026-11-08 21:16 ET: branching finals share one Bokidex entry
- The two finals of a branching line are alternate forms of one Bokidex entry, not separate entries.
- Applies to all 4 branching lines: Mycroll (Amanitusk / Ringrove), Vespyx (Glaivyx / Lashyx), Prismander (Geodelotl / Chandelotl), Echolop (Howlop / Chimelop).
- Each form keeps its own name, art, portrait and 3D model. The entry shows both forms (side by side or a toggle).
- The entry counts as caught when either form is owned; owning both forms earns a small "both forms" star.
- Bokidex entries drop by 4 (~120); the species and art count is unchanged.

## Owner decision 2026-11-09: soul-linked Boki wisps
In matches your Boki rides as a small critter-shaped wisp: carry passive always on, a summon button on a long cooldown, and the ult gives a longer summon or merge form. Downed Hunters drop their wisps, which can be stolen for the match only; the thief keeps a soul echo (Field Book unlock, better odds, a small mutation chance). Round wisp = Hunter, critter wisp = Boki. Full rules: DECISIONS.md, 2026-11-09.

## Owner note 2026-11-08 22:17 ET: keep plenty of single-type Boki
- Target about 45% single-type across the whole roster (now 29 of 124 existing, 49 of 77 new).
- Patterns to use: some whole lines stay single-type (like a fire starter that stays pure fire); in other three-stage lines the baby and middle stay single and the second type arrives at the final; dual types are kept where the idea really spans two types.
- Applied to ROSTER_200_NEW.md already. For the existing 124: move roughly 30 babies/middle forms (and a few whole lines) to single-type.

### Applied 2026-11-09 (coordinator): single-type pass on the existing 124
31 retyped in ROSTER_100.html. The existing 124 are now 60 single and 64 dual (48%). With the new 76, about 54% of the roster is single-type.
- Babies and middles go single; the second type arrives at the final:
  - Prismander and Glassolotl: Prism
  - Teapotamus: Ember
  - Kerchick and Jibbatross: Tempest
  - Zippelith: Shadow
  - Glintmole and Geodemole: Stone
  - Kindlewren and Embrook: Ember
  - Dribbara and Soakybara: Tide
  - Kayak and Prowyak: Frost
  - Boltstrich: Storm
  - Bucketmander and Barrelmander: Tide
  - Anvilbrock: Ember
  - Marchleaf and Scythant: Swarm
  - Thrumbird: Echo
  - Echolop: Echo
- Whole lines that are now single:
  - Coolatee, Frigatee, Glaciatee: Frost
  - Kestrike, Arcestrel, Voltalon: Storm
  - Latchling, Lockatara, Vaultara: Titan
- Kept dual because the idea spans two types:
  - Wickapi line (Shadow+Ember, candle in the dark)
  - Nettlynx line (Venom+Bloom, stinging nettle)
  - Bubblisk line (Prism+Tide, soap bubble)
  - Dual single-stage rares
  - All branch finals

### Applied 2026-11-09 (coordinator, owner order): standard type names
Wild=Normal, Ember=Fire, Tide=Water, Bloom and Spore=Grass (merged), Storm=Electric, Frost=Ice, Stone=Rock, Gravity=Ground,
Tempest=Flying, Wyrm=Dragon, Shadow=Dark, Venom=Poison, Swarm=Bug, Titan=Steel, Lunar=Ghost, Prism=Fairy, Echo=Psychic.
17 types (no Fighting yet). Any old type name in older briefs means the new one above. Applied to ROSTER_100.html,
ROSTER_200_NEW.md, roster.json and the Bokidex dex.json; game type table goes through a gated branch.

## Owner decision 2026-11-08 22:29 ET: standard type names
Rename every type to the plain, standard name (18 types):
| old | new |  | old | new |
|---|---|---|---|---|
| Ember | Fire | | Swarm | Bug |
| Tide | Water | | Stone | Rock |
| Bloom | Grass | | Tempest | Flying |
| Storm | Electric | | Wild | Normal |
| Frost | Ice | | Titan | Steel |
| Wyrm | Dragon | | Lunar | Fairy |
| Shadow | Dark | | Prism | Crystal |
| Venom | Poison | | Spore | Spore (kept) |
| Echo | Sound | | Gravity | Psychic |
Applied in ROSTER_200_NEW.md (headers and tables). Main: rename in game data, the in-game Bokidex, the website Bokidex and ROSTER_100. Type matchups are not part of this change.
