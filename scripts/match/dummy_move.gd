class_name DummyMove
extends RefCounted
## How a practice dummy moves (Training Area, content/rules/dummy_move.json): Still stands, Strafe runs side to
## side across the line to whoever it watches in random legs, Dodge adds a normal dash every few seconds. It only
## makes the dummy's input (move, dash); Hunter.do_dash and the movement code do the rest. It never leaves its pen.

const RULES_PATH := "res://content/rules/dummy_move.json"
static var rules: Dictionary = _load()

var mode := "still"
var _side := 1.0          # +1 / -1 across the watch line, flips every leg
var _leg_t := 0.0         # s left in this strafe leg
var _dash_t := 0.0        # s until the next dodge dash
var _dash_set := false    # _dash_t holds a drawn time (else draw one on the next frame)

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	assert(parsed is Dictionary, "%s did not parse" % RULES_PATH)
	return parsed

func _init(start_mode := "still") -> void:
	mode = start_mode

## The next mode in the rules' order (Still, Strafe, Dodge, back to Still).
func cycle() -> void:
	var modes: Array = rules["modes"]
	mode = String(modes[(modes.find(mode) + 1) % modes.size()])
	_leg_t = 0.0
	_dash_set = false

## Sets h's dash input and returns its move input (world x, z) for this frame. mark: the pen's centre, watch:
## who it faces.
func step(h: Hunter, mark: Vector3, watch: Vector3, dt: float, rng: RandomNumberGenerator) -> Vector2:
	if mode == "still":
		return Vector2.ZERO
	var pen := float(rules["pen_r"])
	var off := Vector2(h.pos.x - mark.x, h.pos.z - mark.z)
	if off.length() > pen:
		return -off.normalized()      # pushed out (a knockback, a pull): head home first
	var fwd := Vector2(watch.x - h.pos.x, watch.z - h.pos.z)
	var side := Vector2(-fwd.y, fwd.x).normalized() if fwd.length() > 0.1 else Vector2.RIGHT
	_leg_t -= dt
	if _leg_t <= 0.0 or (off.length() > pen - 0.3 and off.dot(side * _side) > 0.0):
		_side = -_side
		_leg_t = rng.randf_range(float(rules["leg_min"]), float(rules["leg_max"]))
	if mode == "dodge":
		_dodge(h, off, side, rng, dt)
	return side * _side * float(rules["strafe_share"])

## Counts down to the next dash and fires it across the line, on whichever side has room for the whole dash.
func _dodge(h: Hunter, off: Vector2, side: Vector2, rng: RandomNumberGenerator, dt: float) -> void:
	if not _dash_set:
		_dash_set = true
		_dash_t = rng.randf_range(float(rules["dash_min"]), float(rules["dash_max"]))
	_dash_t -= dt
	if _dash_t > 0.0 or h.dashes < 1.0:
		return
	var reach := Hunter.DASH_SPEED * Hunter.DASH_TIME
	var pen := float(rules["pen_r"])
	for s in [_side, -_side]:
		if (off + side * s * reach).length() <= pen:
			_side = s
			h.inp["dash"] = true
			_dash_set = false
			return
