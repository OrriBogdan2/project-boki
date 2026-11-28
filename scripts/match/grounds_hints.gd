class_name GroundsHints
extends RefCounted
## The Training Grounds' first-time hints: the first time you come near a station (a pedestal island or the
## Movement Fields) one line says what it does and the key to use, through the same lane as Match._tip and
## once per save. The duel ring has its own (DuelRingHint), the dummies the kit and dodge drills, the Boki
## summon pad its card. Keys are read when the line shows (Settings.key_cap), so a rebind shows in it.

const KEY_PREFIX := "grounds_"  # Save.d["tutorial"] key: grounds_arch, grounds_kin, ...
const NEAR_M := 3.0  # m past a perch's pedestal ring that counts as being on its island
const LANE_NEAR_M := 3.5  # m from a dash lane's line (the lane is 7 m wide)
const ABOVE_M := 4.0  # m above the ground: past this you are flying over it, not at it
const LANE_ID := "lanes"

var m: Match
var _spots: Array = []  # {id, c: Vector3, r: float} one per pedestal island, then {id, a: Vector2, b: Vector2}
var _left := 0  # spots this save has not had yet; 0 = nothing left to watch for


func _init(match_node: Match) -> void:
	m = match_node
	var g := Grounds.data()
	for st in g.get("stations", []):
		var c := Grounds.v3(st["at"])
		c.y = m.world.ground_at(c.x, c.z)
		_spots.append({"id": String(st["kind"]), "c": c, "r": float(st["ring"]) + NEAR_M})
	for lane in g.get("lanes", []):
		_spots.append(
			{"id": LANE_ID, "a": Vector2(float(lane[0]), float(lane[1])), "b": Vector2(float(lane[2]), float(lane[3]))}
		)
	_spots = _spots.filter(func(s): return not Save.d["tutorial"].get(KEY_PREFIX + String(s["id"]), false))
	_left = _spots.size()


## The line for a station kind ("arch", "kin", "gear", "item", "bot", or LANE_ID).
static func line(id: String) -> String:
	var use := Settings.key_cap("interact")
	match id:
		"arch":
			return "Hunter pedestals: stand at one and press %s to play as that Hunter" % use
		"kin":
			return (
				"Boki pedestals: press %s to bring that Boki along, then %s sends it" % [use, Settings.key_cap("throw")]
			)
		"gear":
			return (
				"Gear pedestals: press %s to wear that glove, armor or boots (gloves fire on %s and %s)"
				% [use, Settings.key_cap("gear1"), Settings.key_cap("gear2")]
			)
		"item":
			return (
				"Item pedestals: press %s to fill your belt with that item, then use it on %s to %s"
				% [use, Settings.key_cap("util1"), Settings.key_cap("util4")]
			)
		"bot":
			return "Bot pedestals: press %s to call a sparring bot of that Hunter; the last one clears them" % use
		LANE_ID:
			return "Dash lanes: a tick every 5 m, so you can measure a dash (%s) or a glide" % Settings.key_cap("dash")
	return ""


## Per frame (from Grounds.tick): shows the first station line the player is near, then drops that spot.
func tick() -> void:
	var p: Hunter = m.player
	if _left == 0 or p == null or p.downed or m.hud == null or not Settings.get_v("tips"):
		return
	for s in _spots:
		if not _near(p, s):
			continue
		var id := String(s["id"])
		_spots = _spots.filter(func(o): return o["id"] != id)
		_left = _spots.size()
		m._tip(KEY_PREFIX + id, line(id))
		return


func _near(p: Hunter, s: Dictionary) -> bool:
	if s["id"] == LANE_ID:
		var at := Vector2(p.pos.x, p.pos.z)
		var seg := Geometry2D.get_closest_point_to_segment(at, s["a"], s["b"])
		return at.distance_to(seg) < LANE_NEAR_M and p.pos.y - m.world.ground_at(p.pos.x, p.pos.z) < ABOVE_M
	var c: Vector3 = s["c"]
	return p.flat_dist(c) < float(s["r"]) and absf(p.pos.y - c.y) < ABOVE_M
