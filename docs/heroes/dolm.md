# Dolm (archetype id `dolm`, Medium) 

Internal note: behaviour reference is the SUPERVIVE hero Tetra. Nothing below is player-facing.

## Research summary
Sources: supervive.wiki.gg/wiki/Tetra (ability summary and rank table). Patch notes and guides were not fetched
(the wiki fetch carried the rank tables; the usage budget asked for few sources). Open points: the wiki lists no
ranges or stun values, so ours are derived from our time-to-kill. Version chosen: the wiki page as of Nov 2026.

## Design
Weight Medium (145 hp). Fixed weapon Rubble Fists. Palette ochre stone `#d9a35b`, umber and pale sandstone; a stone-plated
shoulder, chest slab, rubble collar, bare head under a stone brow band. Payoff word ROCKFALL (sound `pay_rockfall`).

| Slot | Input | Ours | Source behaviour | Difference |
|---|---|---|---|---|
| Passive Stonesight | sneak | foes in a 70 degree cone within 16m show as stone rings through walls and fog | detects enemies in front while sneaking | ring markers refreshed every 0.5s |
| LMB Rubble Fists | tap / hold + release | tap: boulder 9 dmg, 11m, 0.6s. Hold 0.28-0.9s: punch cone 2.7m, 12-24 dmg, throws foes back, wall stun 0.9s, launches rocks in reach | tap throws a rock, hold punches, wall = stun, launches rocks | rocks that burst Shred (+15% damage taken, 3s) |
| RMB Quakefall | hold to charge, release | slam 2.4m ahead, radius 1.7-2.7, damage 14-30, centre stun 0.5-1.2s, rocks in the ring fly outward, 10s; a knock or kill resets it; in the air: a dive that slams on landing, foes in the air are dunked (+40%, +20 over the abyss) | charge slam, jump-leap while charging, dunk over the abyss, reset on knock | air press dives instead of leaping while charging |
| Shift Landslide | tap | 4.2m barrel, boulder launched at the end 12 dmg, 9s | rock shoved ahead then launched | boulder is created at the end of the dash |
| E Rockwave | tap | three rocks in a line 3m ahead, 9s, 45 hp each, block bodies and enemy shots, 13s | wall of three rocks, ground only | rocks keep placement rules (HeroZones) |
| R Tetraform | none | folded into E rank 3: second row of rocks and, aimed over the abyss, a temporary rock bridge (9m, 6s) | giant wall, bridges the abyss | no angle drag; ult choice: central to the abyss identity, so folded, not a separate R |

Rank 2: shorter cooldown and +15% damage. Rank 3: Quakefall shields 18 per slam (4 stacks), Landslide a third longer,
Rockwave second row and bridge.

## Combinations (`--dolm-combo-check`)
| Combo | Result |
|---|---|
| Punch into a wall | stun 0.9s |
| Rockwave then punch | rocks launch, burst, Shred, ROCKFALL on a hunter |
| Rockwave then slam | rocks fly outward from the impact |
| Slam centre | stun scales with charge |
| Slam that knocks or kills | Quakefall resets |
| Slam on a foe in the air | dunk, spiked down |
| Landslide | boulder at dash end, Shred |
| Rank 3 slam | shield stacks |
| Sneak | Stonesight rings |

## Zones
Rocks and bridges go through `HeroZones`: solid ground within a step of the caster, no blocker tiles, no walls or rocks,
no bodies inside, line of sight from the caster, never over the abyss. Bridges only replace abyss tiles and restore them.
Net 0.10.1: `["zone", ...]` events (rock, rockgo, bridge, seed, pop). `--zone-check` covers legality, collision, abyss
edges and Net rebuild on a second game.
