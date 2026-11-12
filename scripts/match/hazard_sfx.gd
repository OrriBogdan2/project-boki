class_name HazardSfx
extends RefCounted
## The terrain hazards' sounds (content/sfx/hazards.json "play", tools/gen_sfx_hazards.py, docs/AUDIO.md):
## a quiet bed per area, heard as you near its edge; a contact cue per kind at a hunter on that ground (a
## burn tick, a wade or a swim stroke, a skid, the static's crackle on a shock, a bramble snag); a gasp
## before drowning; and a soft "warded" cue the first time a Boki or perk keeps a kind of ground off you.
## TerrainHazards calls it, for the bodies this game owns. Beds are held loops (Sfx.loop_hold), so they
## stop by themselves once the match stops ticking; cues go through the pool (Sfx.play: positional,
## gapped and stacked like every one-shot).

const PATH := "res://content/sfx/hazards.json"
const MOVING := 1.0          # m/s of ground speed that counts as moving through (a skid, a wade)

static var _play := {}

var tz: TerrainHazards
var beds := {}               # area index -> Vector3: where its bed sounds (its ground nearest the listener)
var scan_t := 0.0
var widest := 0.0            # m: the furthest any bed carries (how far round the listener a scan looks)
var warded := {}             # kind -> true once the player has heard the warded cue for it

static func play_rules() -> Dictionary:
	if _play.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_play = parsed["play"] if parsed is Dictionary else {"kinds": {}}
	return _play

func _init(terrain: TerrainHazards) -> void:
	tz = terrain
	for K in play_rules()["kinds"].values():
		widest = maxf(widest, _reach(String(K["bed"])))

static func _reach(sname: String) -> float:
	return float(Sfx.sound_reach.get(sname, Sfx.hear_range))

# ------------------------------------------------------------------ beds
## Every frame: re-find the nearest beds every bed_scan_s, and hold the ones that sound.
func tick(dt: float) -> void:
	var R := play_rules()
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = float(R["bed_scan_s"])
		scan(Sfx.listener)
	for ai in beds:
		var bed := String(R["kinds"][tz.areas[ai]["kind"]]["bed"])
		Sfx.loop_hold("hazard_bed%d" % ai, bed, beds[ai], float(R["bed_db"]))

## The beds that sound around p: each area's ground nearest p, if its bed carries that far; the nearest
## beds_max of them. Reads the tile lookup in a square round p (a few hundred reads, 4 times a second).
func scan(p: Vector3) -> void:
	beds.clear()
	var w := tz.w
	var cx := int(floor(p.x))
	var cz := int(floor(p.z))
	var r := int(ceil(widest))
	var near := {}           # area index -> squared tiles to its nearest ground
	var spot := {}           # area index -> that tile
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if not w.inb(x, z):
				continue
			var a := tz.cell[w.idx(x, z)] - 1
			var d2 := (x - cx) * (x - cx) + (z - cz) * (z - cz)
			if a >= 0 and d2 < int(near.get(a, 1 << 30)):
				near[a] = d2
				spot[a] = Vector2i(x, z)
	var kinds: Dictionary = play_rules()["kinds"]
	var heard: Array = []
	for a in near:
		var bed := String(kinds[tz.areas[a]["kind"]]["bed"])
		if sqrt(float(near[a])) <= _reach(bed):
			heard.append(a)
	heard.sort_custom(func(x, y): return near[x] < near[y])
	for a in heard.slice(0, int(play_rules()["beds_max"])):
		var c: Vector2i = spot[a]
		beds[a] = Vector3(c.x + 0.5, float(tz.areas[a]["y"]), c.y + 0.5)

# ------------------------------------------------------------------ cues
## A hunter on hazard ground this frame (TerrainHazards._tick_hunter; st is its hazard state). entered: it
## has just stepped onto this area, so the first cue plays at once.
func contact(h: Hunter, kind: String, safe: bool, st: Dictionary, entered: bool, dt: float) -> void:
	var K: Dictionary = play_rules()["kinds"][kind]
	if K.has("breath"):
		_breath(h, K, safe, st)
	var cue := String(K.get("warded_contact", "")) if safe else String(K["contact"])
	if cue == "" or float(K["every_s"]) <= 0.0:
		return
	st["snd"] = 0.0 if entered else float(st.get("snd", 0.0)) - dt
	if float(st["snd"]) > 0.0:
		return
	if not entered and K["moving"] and Vector2(h.vel.x, h.vel.z).length() < MOVING:
		return
	st["snd"] = float(K["every_s"])
	_cue(h, cue)

## A gasp once a dip, as the breath falls under breath_at of full (again only once it has come back over).
func _breath(h: Hunter, K: Dictionary, safe: bool, st: Dictionary) -> void:
	var full := float(TerrainHazards.kind_def("deep_water")["effect"]["breath_s"])
	if float(st["breath"]) >= float(K["breath_at"]) * full:
		st.erase("gasp")
	elif not safe and not st.has("gasp"):
		st["gasp"] = true
		_cue(h, String(K["breath"]))

## The static flats' shock going through an unwarded hunter.
func shock(h: Hunter) -> void:
	_cue(h, String(play_rules()["kinds"]["static"]["contact"]))

## The player's Boki or perk keeps this ground off them: a soft cue, the first time for each kind a match.
func ward(h: Hunter, kind: String) -> void:
	if h != tz.m.player or warded.has(kind):
		return
	warded[kind] = true
	Sfx.play(String(play_rules()["warded"]), h.pos, float(play_rules()["warded_db"]))

func _cue(h: Hunter, sname: String) -> void:
	var R := play_rules()
	Sfx.play(sname, h.pos, float(R["contact_db"]) + (0.0 if h == tz.m.player else float(R["others_db"])))
