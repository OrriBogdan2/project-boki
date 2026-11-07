# Project Boki wiki

Project Boki is a top-down PvPvE extraction game with creature raising, built in Godot 4.6.2. You raise
Boki on a floating-island farm, take one along on expeditions into the Skylands, fight rival squads,
monsters and the Blight, and try to get home with what you found. Your Boki can come home changed, or
not at all.

The code still says **kin** for Boki and **Kinfall** for the game in places (ids, file names, class
names). Player-facing text says Boki and Project Boki.

Pages marked *(generated)* are written by `tools/gen_wiki.py` from the game's data. Don't edit them by
hand; change the data and rerun the script. Hand-written pages may also hold generated blocks between
`<!-- gen:... -->` markers.

## For players

| Page | What's in it |
|---|---|
| [Getting started](Getting-Started.md) | Your first egg, the tutorial, the farm and your first expedition |
| [Controls](Controls.md) | Every key, in a match and at home |
| [Classes](Classes.md) | The twelve classes and how levels and ranks work |
| [The Hired Gun](Class-Hired-Gun.md), [The Unbroken](Class-Unbroken.md), [The Flame Queen](Class-Flame-Queen.md), [The Dawnfox](Class-Dawnfox.md), [The Stone Seer](Class-Stone-Seer.md), [The Red Stitch](Class-Red-Stitch.md), [The Scrap King](Class-Scrap-King.md), [The Snowglider](Class-Snowglider.md), [The Void Jester](Class-Void-Jester.md), [The Barnacle Knight](Class-Barnacle-Knight.md), [The Storm Chaser](Class-Storm-Chaser.md), [The Silver Thief](Class-Silver-Thief.md) | One page per class |
| [Boki](Boki.md) | Types, personality, scanning, breeding, bonds, losing a Boki |
| [Boki species](Boki-Species.md) *(generated)* | Every species with its abilities, merge and evolution paths |
| [Boki growth](Boki-Growth.md) *(generated)* | Evolution nodes, mutations, bond ranks, IVs, natures |
| [Expeditions](Expeditions.md) | The drop, gliding, the abyss, lairs, exits, the Blight, weather, dying |
| [Maps and biomes](Maps.md) *(generated)* | Every map, its regions, lairs, exits and what's rolled |
| [The farm](The-Farm.md) | Building, stations, materials, Boki at work |
| [Farm reference](Farm-Reference.md) *(generated)* | Every buildable, work element, tool and crop |
| [Gear and items](Gear-and-Items.md) | Weapons, gloves, tonics, keys, eggs, the backpack |
| [Weapons](Weapons.md) *(generated)* | Weapon stats, rarities, elements, named weapons, run perks |
| [Gloves](Gloves.md) *(generated)* | Every glove |
| [Rules](Rules.md) *(generated)* | Tiers, death and revive numbers, bond meter, Boki AI, combos |
| [Arena and training](Arena-and-Training.md) | Practice tools, the training island and the duel room |

## For the team

| Page | What's in it |
|---|---|
| [Architecture](Architecture.md) | How the game is put together |
| [Code map](Code-Map.md) | Every folder under `scripts/`, one line per important file |
| [Checks](Checks.md) | Every `--*-check` hook and what it asserts |
| [Build and ship](Build-and-Ship.md) | Godot version, worktrees, ship.sh, exports, releases |
| [Networking](Networking.md) | `Net`, the relay, message topics, `Net.VERSION` |
| [Roadmap](../ROADMAP.md) | What shipped, what is being built, and what comes next (updated every build) |
| [Design docs](Design-Docs.md) | Index of `docs/` and the `design` branch |
| [Contributing and licensing](Contributing-and-Licensing.md) | GPL code, the asset license, NOTICE, the CLA |
| [Inspirations](Inspirations.md) | Which mechanics came from which games (design notes) |

## Keeping it current

```
python3 tools/gen_wiki.py          # rewrite the generated pages and blocks
python3 tools/gen_wiki.py --check  # exit 1 if any generated page is out of date
```
