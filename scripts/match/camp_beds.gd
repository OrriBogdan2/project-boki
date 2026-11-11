class_name CampBeds
extends RefCounted
## The idle bed of each live monster camp (tools/gen_sfx_camps.py, content/sfx/camps.json, the "bed"
## block of content/rules/camps.json): you hear a camp before you see it. Each camp spot's bed is a
## loop of its monsters' voices (skitter chitter, spitter gurgle, brute grunts), picked by how many are
## up, so a bigger camp is louder and denser; it fades in from 35 m (the sounds' reach) and stops once
## the camp is cleared. A camp that comes back after standing empty plays a short relight cue. Only the
## nearest few play at once, and they sink under a fight (MusicDir.heat).
## Every game runs it from what it sees: a monster belongs to the camp spot nearest its home (Mob.camp),
## so it works the same online, where only the host keeps Camps' own list. Ticked by MusicDir; reads
## the match, never changes it.

const RECOUNT_S := 0.25        # s between recounts of each camp's monsters (the beds are held every frame)
const RELIGHT_GAP_S := 20.0    # s a camp must stand empty before its return plays the relight cue (so
                               # monsters first coming into view online do not play it)

static var _rules: Dictionary = Camps.rules()["bed"]

var spots: Array = []          # {pos, n (monsters up), sound, key, empty_t (s it has stood empty)}
var playing: Array = []        # indices into spots of the beds playing now, nearest first
var _spot_of := {}             # monster instance id -> its camp spot (-1: not a camp's)
var _recount_t := 0.0

func tick(m: Match, dt: float, heat: float) -> void:
	if spots.is_empty():
		for c in m.world.camp_spots:
			spots.append({"pos": c["pos"], "n": 0, "sound": "", "key": "", "empty_t": 0.0})
	_recount_t -= dt
	if _recount_t <= 0.0:
		_recount(m, RECOUNT_S - _recount_t)
		_recount_t = RECOUNT_S
		_pick()
	var duck := heat * float(_rules["combat_db"])
	for i in playing:
		var s: Dictionary = spots[i]
		Sfx.loop_hold(s["key"], s["sound"], s["pos"], float(s["db"]) + duck)

## Counts each camp's monsters up, picks its bed, and plays the relight cue for a camp back from empty.
func _recount(m: Match, dt: float) -> void:
	var counts := PackedInt32Array()
	counts.resize(spots.size())
	for mb in m.mobs:
		if not is_instance_valid(mb) or mb.dead:
			continue
		var i: int = _spot_of.get(mb.get_instance_id(), -2)
		if i == -2:
			i = _spot_near(mb.camp)
			_spot_of[mb.get_instance_id()] = i
		if i >= 0:
			counts[i] += 1
	for i in spots.size():
		var s: Dictionary = spots[i]
		var was := int(s["n"])
		s["n"] = counts[i]
		if counts[i] == 0:
			s["empty_t"] = float(s["empty_t"]) + dt
			continue
		if was == 0 and float(s["empty_t"]) >= RELIGHT_GAP_S:
			Sfx.play("camp_relight", s["pos"], float(_rules["relight_db"]), 0.05)
		s["empty_t"] = 0.0
		for t in _rules["tiers"]:
			if counts[i] >= int(t["min"]):
				s["sound"] = String(t["sound"])
				s["db"] = float(t["db"])
		s["key"] = "campbed%d_%s" % [i, s["sound"]]

func _spot_near(home: Vector3) -> int:
	var r := float(_rules["spot_r"])
	for i in spots.size():
		var p: Vector3 = spots[i]["pos"]
		if Vector2(home.x - p.x, home.z - p.z).length() <= r:
			return i
	return -1

## The nearest live camps within their bed's reach, at most near_n of them.
func _pick() -> void:
	var near: Array = []
	var lp := Sfx.listener
	for i in spots.size():
		var s: Dictionary = spots[i]
		if int(s["n"]) == 0:
			continue
		var d := Vector2(lp.x - s["pos"].x, lp.z - s["pos"].z).length()
		if d <= float(Sfx.sound_reach.get(s["sound"], Sfx.hear_range)):
			near.append(Vector2(d, i))
	near.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	playing = near.slice(0, int(_rules["near_n"])).map(func(v): return int(v.y))
