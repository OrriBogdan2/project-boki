class_name AmbBeds
extends RefCounted
## The expedition's place and weather beds, on top of the match wind (tools/gen_ambience.py). MusicDir
## calls tick() every quarter second; Sfx.amb_layer fades each bed to its level, so walking from
## meadow to rock to shore is a crossfade by position.
##   meadow / cliffs   by the ground around you: nine samples (the spot and a ring of eight) vote, so a
##                     bed fades out over the last few metres of its island instead of switching
##   region            on a map with named regions (Hollow Crown) each region has its own bed, from
##                     content/rules/region_ambience.json (docs/AUDIO.md): the same nine-sample vote,
##                     so a border is a position crossfade, and every bed takes fade_s (3.5 s) to
##                     come or go. Inside the Blight (past the tide ring) the place beds drop to
##                     blight_k of their level and the blight rumble carries the place
##   water             on the shores (WATER_ISLANDS), on top of that island's own bed
##   gust / rain       the raid condition's weather (RaidLook), the same everywhere
##   blight            a low rumble that grows with the Blight's strength where you stand (it climbs
##                     toward the core and with the session's age), and in the last minute and a half
##                     as the islands near their fall
## Reads the match, never changes it.

const RULES_PATH := "res://content/rules/region_ambience.json"
## Beds this adds (audio/amb_<name>.ogg); --sfx-set-check asserts the files exist.
const BEDS := ["meadow", "cliffs", "water", "gust", "rain", "blight"]
const BED_OF_STYLE := {
	"meadow": "meadow",
	"bloom": "meadow",
	"frost": "cliffs",
	"ember": "cliffs",
	"storm": "cliffs",
	"gloom": "cliffs",
}
const WATER_ISLANDS := ["saltmere"]
const RING_R := 7.0  # m: how far round you the ring of samples reaches
const RING_N := 8
const CENTRE_W := 2.0  # the spot you stand on counts twice
const COLLAPSE_RAMP := 90.0  # s before the islands fall that the rumble starts to climb
## Bed level 0..1 per raid condition (Sfx.amb_layer scales 1 to the ambience's full level).
const GUST := {"clear": 0.2, "day": 0.2, "dusk": 0.35, "night": 0.5, "ash": 1.0, "fog": 0.2}
const RAIN := {"clear": 0.0, "day": 0.0, "dusk": 0.45, "night": 0.0, "ash": 0.0, "fog": 0.3}

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules


## The bed a region plays (its id as in the layout's regions), "" for none.
static func bed_of_region(region_id: String) -> String:
	return String(rules()["beds"].get(region_id, ""))


## The bed of the region this island belongs to ("" off a map with regions or for a region with no bed).
static func bed_of_island(w: World, island_id: String) -> String:
	for r in w.regions:
		if island_id in (r as Dictionary).get("islands", []):
			return bed_of_region(String((r as Dictionary).get("id", "")))
	return ""


## 1 outside the Blight's tide ring, falling to blight_k forty metres inside it: the place beds' share.
static func blight_share(m: Match, p: Vector3) -> float:
	if m.heart == null:
		return 1.0
	return lerpf(1.0, float(rules()["blight_k"]), Heart.tide_out(m, p))


## Every place bed's level 0..1 at the player, by the nine-sample vote: bed -> level.
func place_levels(m: Match, p: Hunter) -> Dictionary:
	var w: World = m.world
	var votes := {}
	for b in BED_OF_STYLE.values():
		votes[b] = 0.0
	for b in rules()["beds"].values():
		votes[b] = 0.0
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
		var iid := String((w.islands[ii] as Dictionary).get("id", ""))
		var bed := bed_of_island(w, iid)
		if bed == "":
			bed = String(BED_OF_STYLE.get(w.style_at(w.idx(int(floorf(x)), int(floorf(z)))), ""))
		if bed != "":
			votes[bed] = float(votes[bed]) + wt
		if iid in WATER_ISLANDS:
			water += wt
	var total := RING_N + CENTRE_W
	var k := blight_share(m, p.pos)
	var out := {"water": water / total * k}
	for b in votes:
		out[b] = float(votes[b]) / total * k
	return out


func tick(m: Match, p: Hunter) -> void:
	var fade := float(rules()["fade_s"])
	var lv := place_levels(m, p)
	for b in lv:
		Sfx.amb_layer(b, lv[b], fade)
	Sfx.amb_layer("gust", float(GUST.get(m.raid, 0.0)))
	Sfx.amb_layer("rain", float(RAIN.get(m.raid, 0.0)))
	Sfx.amb_layer("blight", rumble(m, p))


## 0..1: the Blight's strength here against its top, or the fall of the islands, whichever is nearer.
func rumble(m: Match, p: Hunter) -> float:
	var k := clampf(1.0 - (m.length - m.time) / COLLAPSE_RAMP, 0.0, 1.0)
	if m.blight:
		k = maxf(k, m.blight.level(p.pos, p.team) / BlightDir.LVL_MAX)
	return k
