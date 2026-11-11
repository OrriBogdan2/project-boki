class_name AmbBeds
extends RefCounted
## The expedition's place and weather beds, on top of the match wind (tools/gen_ambience.py). MusicDir
## calls tick() every quarter second; Sfx.amb_layer fades each bed to its level, so walking from
## meadow to rock to shore is a crossfade by position.
##   meadow / cliffs   by the ground around you: nine samples (the spot and a ring of eight) vote, so a
##                     bed fades out over the last few metres of its island instead of switching
##   water             on the shores (WATER_ISLANDS), on top of that island's own bed
##   gust / rain       the raid condition's weather (RaidLook), the same everywhere
##   blight            a low rumble that grows with the Blight's strength where you stand (it climbs
##                     toward the core and with the session's age), and in the last minute and a half
##                     as the islands near their fall
## Reads the match, never changes it.

## Beds this adds (audio/amb_<name>.ogg); --sfx-set-check asserts the files exist.
const BEDS := ["meadow", "cliffs", "water", "gust", "rain", "blight"]
const BED_OF_STYLE := {
	"meadow": "meadow", "bloom": "meadow",
	"frost": "cliffs", "ember": "cliffs", "storm": "cliffs", "gloom": "cliffs",
}
const WATER_ISLANDS := ["saltmere"]
const RING_R := 7.0               # m: how far round you the ring of samples reaches
const RING_N := 8
const CENTRE_W := 2.0             # the spot you stand on counts twice
const COLLAPSE_RAMP := 90.0       # s before the islands fall that the rumble starts to climb
## Bed level 0..1 per raid condition (Sfx.amb_layer scales 1 to the ambience's full level).
const GUST := {"clear": 0.2, "day": 0.2, "dusk": 0.35, "night": 0.5, "ash": 1.0, "fog": 0.2}
const RAIN := {"clear": 0.0, "day": 0.0, "dusk": 0.45, "night": 0.0, "ash": 0.0, "fog": 0.3}

func tick(m: Match, p: Hunter) -> void:
	var w: World = m.world
	var meadow := 0.0
	var cliffs := 0.0
	var water := 0.0
	for k in RING_N + 1:
		var wt := CENTRE_W
		var x := p.pos.x
		var z := p.pos.z
		if k < RING_N:
			var a := TAU * k / RING_N
			wt = 1.0
			x += cos(a) * RING_R
			z += sin(a) * RING_R
		var ii := w.island_of(x, z)
		if ii < 0 or ii >= w.islands.size():
			continue
		var bed := String(BED_OF_STYLE.get(w.style_at(w.idx(int(floorf(x)), int(floorf(z)))), ""))
		if bed == "meadow": meadow += wt
		elif bed == "cliffs": cliffs += wt
		if String((w.islands[ii] as Dictionary).get("id", "")) in WATER_ISLANDS: water += wt
	var total := RING_N + CENTRE_W
	Sfx.amb_layer("meadow", meadow / total)
	Sfx.amb_layer("cliffs", cliffs / total)
	Sfx.amb_layer("water", water / total)
	Sfx.amb_layer("gust", float(GUST.get(m.raid, 0.0)))
	Sfx.amb_layer("rain", float(RAIN.get(m.raid, 0.0)))
	Sfx.amb_layer("blight", rumble(m, p))

## 0..1: the Blight's strength here against its top, or the fall of the islands, whichever is nearer.
func rumble(m: Match, p: Hunter) -> float:
	var k := clampf(1.0 - (m.length - m.time) / COLLAPSE_RAMP, 0.0, 1.0)
	if m.blight:
		k = maxf(k, m.blight.level(p.pos, p.team) / BlightDir.LVL_MAX)
	return k
