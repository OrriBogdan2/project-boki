class_name TutorialPell
extends RefCounted
## Pell, the tutorial's guide (LORE_MASKS round 5: a freed soul, part bird, part humanoid; an owl-folk in a teal
## hooded cloak, art/npcs/pell). Tutorial owns one: Pell waits beside each course stop as its step begins
## (blinking there like the soul it is), talks the step over for a moment, waves when you first come near, and
## otherwise stands watching you. Pell only stands and gestures here: the step's words stay on the panel.

const SIDE := Vector3(1.8, 0.0, -1.4)  # m: where Pell stands from the stop
const TALK_S := 2.4                     # s of talking as a step begins
const WAVE_S := 2.0                     # s of the wave when you first come near
const NEAR_M := 7.0                     # m: "you came near"
const BLINK_S := 0.35                   # s of the blink to a new spot (out, then in)

var tut: Tutorial
var node: NpcModel
var _step := -1
var _talk_t := 0.0
var _wave_t := 0.0
var _waved := false
var _blink_t := 0.0
var _to := Vector3.INF

func _init(owner_tut: Tutorial) -> void:
	tut = owner_tut
	node = NpcModel.new("pell")
	tut.m.add_child(node)
	node.position = _spot("land")

func tick(dt: float) -> void:
	var p := tut.m.player
	if p == null:
		return
	if tut.step != _step and tut.step < Tutorial.steps().size():
		_step = tut.step
		var at := _spot(tut.id())
		if at.x != INF and at.distance_to(node.position) > 1.0:
			_to = at
			_blink_t = BLINK_S
			_waved = false
		_talk_t = TALK_S
	_blink(dt)
	_talk_t = maxf(0.0, _talk_t - dt)
	_wave_t = maxf(0.0, _wave_t - dt)
	var near := p.global_position.distance_to(node.position) < NEAR_M
	if near and not _waved and _blink_t <= 0.0:
		_waved = true
		_wave_t = WAVE_S
	node.face_to = p.global_position
	node.pose = "idle"
	if _wave_t > 0.0:
		node.pose = "wave"
	elif _talk_t > 0.0:
		node.pose = "talk"

## Shrinks out, moves, grows back in.
func _blink(dt: float) -> void:
	if _blink_t <= 0.0:
		return
	_blink_t -= dt
	var half := BLINK_S * 0.5
	if _blink_t < half and _to.x != INF:
		node.position = _to
		_to = Vector3.INF
	var k := absf(_blink_t - half) / half
	node.scale = Vector3.ONE * clampf(k, 0.05, 1.0)

## Beside a course stop (INF when the step has no stop).
func _spot(sid: String) -> Vector3:
	var at := tut.stop(sid)
	if at.x == INF:
		return at
	var q := at + SIDE
	return Vector3(q.x, tut.m.world.ground_at(q.x, q.z), q.z)
