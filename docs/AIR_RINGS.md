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

## Not done here
- Bots fly lanes (they are glide links) but do not plan around lift rings; they climb by stairs as before.
- Lane choice for bots is by hops, not time (the island graph search counts links), so a bot may still walk a
  bridge where a lane would be faster.
