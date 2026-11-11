class_name WaterSfx
extends RefCounted
## Hunters and Boki moving through shallow water (the "water" surface StepSurface finds underfoot): a
## landing splash in the weight class (water_land_<light|medium|heavy>), a dash's spray (water_dash) and
## a wading loop (water_wade) whose level and pitch follow speed. Nothing plays on dry ground. All placed
## where they happen and synthesised (set "water", tools/gen_sfx_water.py). Swimming exists only in the
## farm's ponds, whose strokes are HomeWater's. Levels: "water" in content/rules/move_sfx.json.

const KIN_WEIGHT := {"small": "light", "medium": "medium", "large": "heavy"}    # a Boki's size -> splash class
const KIN_PITCH := 1.1     # a Boki is smaller than a Hunter: its water sounds a little higher

static func rules() -> Dictionary:
	return MoveSfx.rules()["water"]

static func wet(m: Match, pos: Vector3) -> bool:
	return m.world != null and StepSurface.at(m.world, m.skytrain, pos) == "water"

## A Hunter's landing at `vol_db` (MoveSfx.land): its weight class's splash when it lands in water.
static func land(h: Hunter, vol_db: float) -> void:
	if wet(h.m, h.pos):
		var vol := MoveSfx.level(h, vol_db) + float(rules()["splash_db"])
		Sfx.play("water_land_" + StepSurface.weight_of(h), h.pos, vol, 0.08, MoveSfx.pitch(h.arch))

## A Hunter's dash on the ground in water: a spray.
static func dash(h: Hunter) -> void:
	if h.grounded and wet(h.m, h.pos):
		Sfx.play("water_dash", h.pos, MoveSfx.level(h, float(rules()["dash_db"])), 0.08, MoveSfx.pitch(h.arch))

## Each frame of a Hunter: wading through water holds its loop (silent sneaking, unseen or downed).
static func wade(h: Hunter) -> void:
	var k := Vector2(h.vel.x, h.vel.z).length() / maxf(1.0, h.base_speed)
	if h.grounded and not (h.crouch or h.unseen or h.downed) and _wading(h.m, h.pos, k):
		_hold(h.get_instance_id(), h.pos, k, MoveSfx.level(h, 0.0), MoveSfx.pitch(h.arch))

## A Boki landing (thrown, or the end of a leap): its size's splash in water.
static func kin_land(k: Kin) -> void:
	if wet(k.m, k.pos):
		var vol := float(rules()["kin_db"]) + float(MoveSfx.rules()["step_db"]) + float(rules()["splash_db"])
		Sfx.play("water_land_" + kin_weight(k), k.pos, vol, 0.1, KIN_PITCH)

## A Boki's charge starting in water: a spray.
static func kin_dash(k: Kin) -> void:
	if k.grounded and wet(k.m, k.pos):
		Sfx.play("water_dash", k.pos, float(rules()["dash_db"]) + float(rules()["kin_db"]), 0.1, KIN_PITCH)

## Each ground step of a Boki: wading through water holds its loop.
static func kin_wade(k: Kin) -> void:
	var f := Vector2(k.vel.x, k.vel.z).length() / maxf(1.0, k.speed)
	if k.grounded and _wading(k.m, k.pos, f):
		_hold(k.get_instance_id(), k.pos, f, float(rules()["kin_db"]), KIN_PITCH)

static func kin_weight(k: Kin) -> String:
	return KIN_WEIGHT.get(k.ks.size if k.ks else "small", "light")

## The key a mover's wading loop is held under (Sfx.loop_hold).
static func wade_key(id: int) -> String:
	return "wade%d" % id

## Whether a mover at `pos` going `k` of its run speed is wading where you can hear it.
static func _wading(m: Match, pos: Vector3, k: float) -> bool:
	if k < float(rules()["wade_min_k"]):
		return false
	var reach := float(MoveSfx.rules()["step_reach_m"])
	return Vector2(pos.x - Sfx.listener.x, pos.z - Sfx.listener.z).length() <= reach and wet(m, pos)

## Holds mover `id`'s wading loop at `pos`, louder and higher the nearer `k` gets to its run speed; the
## loop stops by itself (Sfx.HOLD_MS) once the mover stops wading and these calls stop.
static func _hold(id: int, pos: Vector3, k: float, db: float, pitch: float) -> void:
	var r := rules()
	var f := clampf(inverse_lerp(float(r["wade_min_k"]), 1.0, k), 0.0, 1.0)
	var vols: Array = r["wade_db"]
	var pitches: Array = r["wade_pitch"]
	var vol := db + lerpf(float(vols[0]), float(vols[1]), f)
	Sfx.loop_hold(wade_key(id), "water_wade", pos, vol, pitch * lerpf(float(pitches[0]), float(pitches[1]), f))
