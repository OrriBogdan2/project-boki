# Project Boki roadmap

What has shipped, what is being built, and what comes next. The main session updates this file at every check-in and every ship. For how things work today, see the [wiki](wiki/Home.md). Known shortcuts and their owners are in [DEBT.md](DEBT.md), and design decisions are in [decisions/](decisions/).

Last updated: 2026-11-02, sync61.

## Shipped

| Build | Date | What landed |
|---|---|---|
| sync61 | Nov 2 | Five hero pairs: Vireo, Venator, Ashwick, Dredge, Tender, Rimewright, Dolm, Ostra, plus an accuracy pass on Archer and Bulwark. Every hero drops its holds when you merge. New check registry (tools/check_registry.gd). Net 0.14.0. |
| sync60 | Nov 2 | Feel fixes (walk off ledges, dash pips, characters lean back, Orchid Isle bridge, swimming, safe Demo landing, class switch on the farm, secondary keybinds). Gear: one signature weapon per hero, rarity on armour, boots, gloves and utility, in-run weapon upgrades. Economy: Drift Pens, Tradewind Exchange, economy floor. Rolling sessions. Polish. Net 0.13.0. |
| sync59 | Nov 1 | The Merge reworked: a 0.7s transformation, then a form with its own kit. Heavy Star, Stormwing and Prism Shell so far. R again fires the form's ultimate and separates you. Shell health while merged, no tiers, R keeps your meter while your Boki is down. Rescue is a 3.5s cradle. Net 0.11.0. |
| sync58 | Nov 1 | Your Boki follows you by default. G sends it at the cursor or calls it back; hold G for the order wheel (Chase, Guard, Return, Follow). Capture by scan replaces taming: knock it out, hold F, then a 4s scan into your box. Field Book. Net 0.10.0. |
| sync57 | Nov 1 | The Boki system: G throw and recall, C casts from the Boki, a downed Boki you rescue by touch, R is the Merge for every class. Net 0.9.0. |
| sync56 | Nov 1 | The Hollow Crown, a handcrafted map. Thief and Juggernaut kits. Abyss tint and cue fixes. Agent rules (AGENTS.md), the health gate and the wiki. |
| sync44-54 | Oct 31 - Nov 1 | Hero art, UI pass, Arena, movement feel, the Blight, farm start, abyss lift, camera, demo readiness. |

## In progress

| Branch | Built by | What | Expected |
|---|---|---|---|
| ext/kits2-nor, ext/farmbuild | other session (ready) | Thief and Juggernaut follow-ups; the farm building pass (buildings unlock over time, Boki labour and materials) | next merge, sync62 |
| ext/equal | other session | Equal footing with bring-in gear: no armour or perks from home; gloves, boots and 1/2/3 utility items can be brought in (rarity capped by tier). Perk orbs instead of the 1/2/3 prompt. Level-ups grow your weapon automatically. Themed shops at landmarks. Chests need keys from predictable carriers. The bush mimic. Hiding cover varied by biome. | this evening |
| ext/market | other session (queued) | Neopets-style: Shelter (adopt Boki for gems, which are destroyed; rehoming pays nothing), weekly Boki transfer, player stalls with search, Auction House, more item variety, fees and taxes as sinks | late tonight or tomorrow |

## Next (main session)

- Stormwing: the wings render too large and float off the body.
- Merge forms for the other six Boki (Vespyx, Hivara, Echolop, Lunowl, Mycroll, Cairnback), each with a signature twist: contagion, swarm, echo, gravity well, spore field, rune walls.
- Simtest seed 5 ends "team wiped" instead of extracting (truce-betrayal behaviour; the smoke test shouldn't depend on it).
- Carried bonuses rebalanced to about 70-80% of the Boki's value when it's out, one distinct effect per species.

## Later

- ext/classes: "class" naming everywhere, a starter set of 3, the rest unlocked through play.
- ext/cleanup: every remaining inline check into the registry, v1/v2 content merged, god files split, object pooling and spatial grid.
- Exchange server for online trading, adoption and auctions (docs/EXCHANGE_SERVER.md).
- Remote players see full-body kit poses.

## Open design questions

- Should the Merge unlock earlier than run level 6?
- Item rarity caps per difficulty tier for brought-in gear (numbers to tune after playtests).
