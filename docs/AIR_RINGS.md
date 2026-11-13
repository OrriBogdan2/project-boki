# Air rings (Hollow Crown 2.0 traversal system)

Owner 2026-11-11 (briefs/DECISIONS.md, "Hollow Crown 2.0"): the bigger map must stay fast to cross, so fixed
air rings lay readable air routes between regions and up to high ground. Code: `scripts/match/air_rings.gd`
(AirRings), map drawing `scripts/ui/air_map.gd` (AirMap), tuning `content/rules/air_rings.json`, check
`--air-rings-check` (tools/air_rings_check.gd).

## Two kinds
- **Glide ring (cyan, stands up across its lane).** Fly through it and your glide is thrown along the lane at
  `speed` (13 m/s; a plain glide cruises at 5), held there for `hold` s while you keep gliding, eased to the
  lane's height, and the glider cools by `heat`. A lane runs level at its higher end's height and climbs or
  drops only over the `rise` m next to its lower end: over the void a glider can't sink below where it took
  off, so a lane sloping down all the way would leave its low rings under you. Rings sit
  every `gap` m, so a chain is a continuous fast lane: a 95 m lane takes 8-9.5 s from rim to landing instead of being past a
  glider's 45 m reach. Your keys still steer; leave the line and the hold runs out. Stopped or turned back (a wall) the
  hold ends at once: it never throws you back the way you came.
- **Lift ring (gold, lies flat over an updraft at the foot of high ground).** Hop into it: it throws you up
  at `lift_vy` and opens the glider (it stays open until you land), the updraft under it carries you over the
  plateau's rim, and you glide onto the top.

Both give a whoosh, a ring flash and the "rings" stat (the Ring Runner challenge). Rings are the same on every
peer; each peer runs them for the hunters it moves, so nothing new is synced.

## Map data (content/maps/hollowcrown.json, written by tools/make_hollowcrown.py)
Re-placing the routes for a new layout means editing two lists in the generator, nothing in code:
- `glides[]` with `rings: true` is an **air lane**: `{name, a, b, take, land, rings}`. One entry runs both ways
  (AirRings.lay adds the way back as a bot route); the rings are laid evenly from `first` m past `take` to
  `end` m short of `land`. Bots already fly glides straight from take to land, so they go through the rings.
- `updrafts[]` with `ring: true` is a **lift ring**: `{region, at, top}` (top = the terrace level it lifts to).
  `region` names whose high ground it serves.
The generator refuses a lane that starts or ends on the wrong island, crosses another island, takes longer
than 25 s at ring speed, or puts a ring over land or within 5 m of the sky train's track; and a lift ring that is not on its
region's ground at the foot (within 4 m) of its level, or sits on stairs. It prints each lane's length, rings
and time.

## Current routes (Hollow Crown 2.0, the 540 m map; re-placed 11-13)
| Lane | Regions | Length | Rings |
|---|---|---|---|
| Eyrie Line | Stormcrown Gaol -> the Crown | 121 m | 7 |
| Lantern Line | Highwatch -> the Crown | 80 m | 5 |
| Salt Line | Saltmere -> Stormbreak (Shrine Table shard) | 63 m | 4 |
| Moor Line | Duskmoor -> Stormbreak (Shrine Table shard) | 51 m | 3 |
| Bramble Leap | Larkhollow <-> Thorn Shard | 48 m | 3 |
| Ember Leap | the Crown <-> Cinder Steps | 32 m | 2 |
| Slag Leap | Ember Shard <-> Cinder Steps | 34 m | 2 |

Ember, Slag and Bramble Leap were the v2 map's plain bot glides (a pair each way); they are lanes now (one
entry runs both ways). The four Lines are new. The v2 sky train runs close round most rims, so every lane
was searched for take-offs and landings that keep each ring 5 m off the track (`check_air`); take-offs and
lift rings keep a tenth of a metre (`sc_air`), the rest of the map rounds to whole metres.
Design note: Salt and Moor Line give Stormbreak an air way in beside its chokepoint bridges (MAP_V2: "every
route across it a chokepoint bridge"); a lane is a readable, shootable route, so it was kept. Alternative not
taken: land them on Salt Shard / Ember Shard instead (drop the lines if the Hollow should stay bridges only).

Lift rings: the Throne (Crown, from the keep on its north side, lv 8 -> 12), the Frostgate ice shelf (from the
Rimefield, 4 -> 10), Highwatch's lv 11 tower (east foot, 2 -> 11), the Kilns' crest (Cinder, from the lv 10
tier, 10 -> 14), the Shrine Table (Stormbreak, north foot, 2 -> 6), Bramble Rise (Thornwood, south foot,
2 -> 6). Every region has at least one ring.

Measured by `--air-rings-check` (keys held like a player: run off the rim, jump, glide toward the landing):
every lane both ways goes through all its rings and lands in 3-10 s, never more than 1.7 s between rings; a
bot crosses the 121 m Eyrie Line on its own crossing logic in 10 s (7 of 7 rings); a bot below each lift ring
stands on its high ground in 1.7-5 s (v2 map, 11-13).

## Source (SUPERVIVE's hoops)
docs/SUPERVIVE_FEEL.md lists the hoop boost among the values still unknown. Searched Nov 12 2026: the game data
notes (`briefs/supervive-data/supervive_physics.md`, `PHYSICS_PARITY.md`) and the hero-ref footage sheets
(`briefs/hero-ref/*.md`), all on `ext/agent-briefs`. The hoop numbers are constructor defaults in the game's
encrypted code (`GlideBoostBonusSpeed`, `GlideBoostDuration`, `GlideBoostDecayDuration`, `GlideBoostForceMul`;
supervive_physics.md "Glide boost (hoops/jetstreams)"), and no hero-ref clip goes through a hoop or jetstream.
Every row below is **[?]**: nothing found, ours kept. The same notes sit in `content/rules/air_rings.json`
"sources" (text only, nothing reads them as numbers). Nothing here invents a ring mechanic the source may not have.

| Row | Source | Ours |
|---|---|---|
| Entry speed | [?] | any; the ring throws you at the faster of your speed and `speed` |
| Boost | [?] | `speed` 13 m/s along the lane (plain glide cruise 5) |
| How long | [?] | `hold` 1.4 s at or above ring speed while you glide; then glide drag |
| A dash inside | [?] | `Hunter.do_dash` as anywhere in the air: the dash folds the glider, the hold drops |
| The glider inside | [?] | steers as ever; the hold keeps ring speed and, on a lane, the lane's height |
| Lift ring | [?] (no equivalent found) | `lift_vy` 8 m/s up, glider open, the updraft does the rest |

What would settle it: a 60 fps clip of one Hunter through a hoop, speed before, inside and after, and one
dashing inside it.

## Hand-over
A ring's exit speed goes into the ordinary moves by their own rules; nothing of the ring's rides along past its
hold:
- **Glide.** The ring opens a shut glider (auto, like a pad: it stays open until a fresh press takes it back, and
  letting go then shuts it, hold and all: the player's glide is press-only). Through the hold you are at ring
  speed or faster; after it `Loco.glide_step`'s drag takes the speed back toward cruise within the dash-into-glide
  bounds (`--move-feel-check` dashglide_1s/2s), never over the glide's max.
- **Dash.** Pressed inside the hold the dash starts at its own speed and folds the glider, so the hold drops with it;
  as the dash ends the ring-opened glider is back the same step at the dash's own velocity (a kit's presses round
  its dash go through DashFlow as ever), and the glide's drag has it under 9 m/s a second on. Ring speed is never
  re-applied.
- **Wall kick.** Thrown head-on into a wall the stop eats the throw (no bounce head-on, WallMoves) and ends the hold
  (before this pass the hold re-threw the wall's small push-off at full ring speed, back the way you came); a jump there
  kicks by the kick's own numbers: keys into the wall rise KICK_RISE, keys away push off at KICK_PUSH, the glider
  shut for the rise and the hold gone.

`--air-rings-check` "hand-over" rows measure each of these on a flat spot (the kick against a 20-terrace wall it
raises there, the class dash and the player's own kit).

## On the maps
The full map always shows lanes (dashed cyan lines, a tick per ring) and lift rings (gold ring with an up
chevron). The minimap shows them as the DETAIL kind "air" (hold Tab or the map key, or while riding in).

## Bots (scripts/match/bot_route.gd, BotRoute)
- **Route by time.** A bot heading for another island plans the quickest chain of hops (Dijkstra over the
  island graph): the run to each take-off at 5 m/s plus the hop's flight, a ringed lane at the ring speed, a
  plain glide at glide speed, a wind road at 14 m/s, a pad at 10 m/s, a bridge on foot, and 2 s per hop.
  The plan is made once per trip, so a ringed lane beats a walk round by a bridge.
- **Lift rings.** A bot whose goal is 2.5 m or more above it on its own island takes a lift ring when the
  ring's way (walk to its foot, ~4.5 s up, walk on) takes under 0.7 of the walk by the stairs, or when no
  walk gets there. It walks to the foot, hops in, holds still with the glider open until over the top,
  then steers onto it. A lift that doesn't put it on top is skipped for 20 s.
- Bots no longer walk straight at a cliff: a straight line with a rise over 1.7 m (Bot.STEP_MAX) is not
  "clear", so they take the tile path round by the stairs (or the lift).

`--air-rings-check` also checks that the plan from each lane's take-off is that lane, and that a bot 3 m
off each lift ring's foot sent up to its high ground stands on top within 7 s (four of the six rings by the
ring, two (the Throne, Bramble Rise) by stairs that are quicker there).
