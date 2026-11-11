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
  glider's 45 m reach. Your keys still steer; leave the line and the hold runs out.
- **Lift ring (gold, lies flat over an updraft at the foot of high ground).** Hop into it: it throws you up
  at `lift_vy` and opens the glider (it stays open until you land), the updraft under it carries you over the
  plateau's rim, and you glide onto the top.

Both give a ring flash, the "rings" stat (the Ring Runner challenge) and their own sound (AirRingSfx,
docs/AUDIO.md): a glide ring's pass steps up a note with each ring of a run along its lane, a lift ring swells
as it takes you up, and every ring hums quietly so you can find it. Yours play at full level, other Hunters'
at the ring, quieter. Rings are the same on every peer; each peer runs them for the hunters it moves, so
nothing new is synced (for the hunters another peer moves it plays only the pass's sound).

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

## Current routes (the 0.24.5 Hollow Crown; the v2 layout re-places them)
| Lane | Regions | Length | Rings |
|---|---|---|---|
| Kestrel Line | Larkhollow -> the Crown | 93 m | 6 |
| Moor Line | Duskmoor -> the Crown | 97 m | 6 |
| Salt Line | Saltmere -> Cinder Steps | 75 m | 4 |
| Kiln Leap | Cinder Steps <-> the Crown | 28 m | 1 |
| Storm Leap | Stormbreak <-> the Crown | 31 m | 2 |
| (unnamed) | Highwatch <-> Stormcrown Gaol | 33 m | 2 |
| (unnamed) | Duskmoor <-> Thornwood | 40 m | 2 |

Lift rings: the Throne (Crown, north side), the Frostgate plateau (west foot), the Kilns' plateau (Cinder, east
foot), the Shrine Table (Stormbreak, north foot), the Thornhive rise (Thornwood, north foot), the Highwatch crest
(south foot). Every region has at least one ring.

Measured by `--air-rings-check` (keys held like a player: run off the rim, jump, glide toward the landing):
every lane both ways goes through all its rings and lands in 3-9.5 s, never more than 2.7 s between rings; a
bot crosses the 97 m Moor Line on its own crossing logic in 8 s; every lift ring puts you on its high ground
in about 4.5 s.

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
ring, two by stairs that are quicker there).
