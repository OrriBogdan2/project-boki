class_name TutorialGuide
extends RefCounted
## Pell, the tutorial's guide: a freed soul, part bird and part person (a placeholder model until the art
## lands). At each step with a line for it (content/rules/tutorial.json "pell") it flies to you and says it
## through the NPC dialogue box, and the match holds until you have read it (Tutorial.holding), for
## TALK_MAX_S at most. Then it
## flies on ahead to where the step wants you and waits there, glowing, with an edge arrow while it is
## off screen. Tutorial owns one as `pell`.

const ID := "pell"
const HOVER := 1.4              # m above the ground it flies at (it flies, so gaps don't stop it)
const COME_SPEED := 16.0        # m/s: flying back to you when a step starts
const LEAD_SPEED := 7.5         # m/s: flying ahead, a little faster than you walk
const AHEAD := 6.0              # m: the farthest ahead of you it waits, so it never leaves you behind
const TALK_AT := 2.4            # m in front of you it hovers to talk
const TALK_REACH := 0.8         # m from its talking spot that counts as there
const COME_MAX_S := 1.6         # s: it starts talking from wherever it is after this
const BESIDE := Vector3(1.8, 0.0, 1.2)   # m: where it hovers when the step has nowhere to go (a fight)
const TALK_MAX_S := 3.0         # s at most the match holds for one line: then the box closes by itself
const TEST_READ_S := 0.5        # s of hold before the headless driver closes the box (TutorialDrive)
const BOB_HZ := 1.3             # its hover's bob
const BOB_M := 0.12
const FLAP_HZ := 3.2            # its wings
const SOUL := Color("eaf3ff")   # pale soul-light: a freed soul is not the kingdom's red
const PLUME := Color("9fd8ff")

var tu
var model: Node3D
var beacon: NpcBeacon
var box: NpcDialogue = null
var state := "lead"             # "come" (flying to you), "talk" (the match holds), "lead"
var talked: Array = []          # the steps it stopped you for
var pos := Vector3.ZERO         # where it is, without the bob
var _come_t := 0.0
var _held_t := 0.0
var _t := 0.0
var _wings: Array = []

func _init(tutorial) -> void:
	tu = tutorial

## Built once the world is there, waiting over the landing meadow.
func build() -> void:
	model = _make_model()
	tu.m.add_child(model)
	pos = tu.stop("land") + Vector3(BESIDE.x, HOVER, BESIDE.z)
	model.position = pos
	beacon = NpcBeacon.attach(model, ID)
	beacon.wants_arrow = true

## A new step: it comes to tell you about it, if it has something to say and a box to say it in.
func begin(sid: String) -> void:
	close()
	state = "come" if tu.m.hud and _lines(sid).size() > 0 else "lead"
	_come_t = 0.0

func talking() -> bool:
	return state == "talk"

## Every tutorial update while the match runs.
func tick(dt: float) -> void:
	var p: Hunter = tu.m.player
	if state == "come":
		_come_t += dt
		var spot := _talk_spot(p)
		_fly(spot, COME_SPEED, dt)
		if pos.distance_to(spot) < TALK_REACH or _come_t > COME_MAX_S:
			_talk(p)
	elif state == "lead":
		var spot := _wait_spot(p)
		_fly(spot, LEAD_SPEED, dt)
		_face(p.pos if pos.distance_to(spot) < 0.5 else spot)
	_pose(dt)

## While the match holds for it (Tutorial.hold_wait): it bobs, and lets go once the box is gone or
## TALK_MAX_S has passed (nothing blocks the player for more than a few seconds).
func hold(dt: float) -> void:
	_held_t += dt
	_pose(dt)
	if not is_instance_valid(box) or box.is_queued_for_deletion() or _held_t >= TALK_MAX_S:
		close()

## The headless driver's "read it": closes the box after a moment of hold.
func test_skip() -> void:
	if talking() and _held_t >= TEST_READ_S:
		close()

func close() -> void:
	if is_instance_valid(box):
		box.queue_free()
	box = null
	if state == "talk":
		state = "lead"
	if beacon:
		beacon.lit = false

func _talk(p: Hunter) -> void:
	var sid: String = tu.id()
	var moods: Dictionary = Content.rules("tutorial").get("pell_moods", {})
	var pages: Array = _lines(sid).map(func(x): return {"text": tu.fill(String(x)),
		"mood": String(moods.get(sid, "neutral"))})
	state = "talk"
	_held_t = 0.0
	talked.append(sid)
	_face(p.pos)
	box = NpcDialogue.make(ID, pages, model)
	tu.m.hud.add_child(box)
	box.finished.connect(close)
	beacon.lit = true

func _lines(sid: String) -> Array:
	return Content.rules("tutorial").get("pell", {}).get(sid, [])

## Where this step wants you (the pad before a gap, the goal, the meadow while you drop), or INF.
func _goal() -> Vector3:
	var sid: String = tu.id()
	return tu.stop("land") if sid == "land" else tu._lead_goal(sid)

## In front of you, on the way to the step's goal.
func _talk_spot(p: Hunter) -> Vector3:
	var g := _goal()
	var dir := Vector3(g.x - p.pos.x, 0, g.z - p.pos.z) if g != Vector3.INF else Vector3.ZERO
	if dir.length() < 0.5:
		dir = Vector3(pos.x - p.pos.x, 0, pos.z - p.pos.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	return _air(p.pos + dir * TALK_AT, p)

## On the way to the goal, at most AHEAD in front of you; beside you when there is no goal.
func _wait_spot(p: Hunter) -> Vector3:
	var g := _goal()
	if g == Vector3.INF:
		return _air(p.pos + BESIDE, p)
	var to := Vector3(g.x - p.pos.x, 0, g.z - p.pos.z)
	var at := g if to.length() <= AHEAD else p.pos + to.normalized() * AHEAD
	return _air(at, p)

## HOVER over the ground at `at`; over the void, HOVER over you.
func _air(at: Vector3, p: Hunter) -> Vector3:
	var w = tu.m.world
	var y: float = p.pos.y if w.is_void(at.x, at.z) else maxf(w.ground_at(at.x, at.z), p.pos.y - 2.0)
	return Vector3(at.x, y + HOVER, at.z)

func _fly(to: Vector3, speed: float, dt: float) -> void:
	pos = pos.move_toward(to, speed * dt)

## Turns its face (-Z) toward `at`.
func _face(at: Vector3) -> void:
	var d := Vector2(at.x - pos.x, at.z - pos.z)
	if d.length() > 0.1:
		model.rotation.y = atan2(-d.x, -d.y)

func _pose(dt: float) -> void:
	_t += dt
	model.position = pos + Vector3(0, sin(_t * TAU * BOB_HZ) * BOB_M, 0)
	var flap := sin(_t * TAU * FLAP_HZ) * (0.25 if state == "talk" else 0.5)
	for i in _wings.size():
		(_wings[i] as Node3D).rotation.z = (1.0 if i == 0 else -1.0) * (0.5 + flap)

## The placeholder: a small pale figure with a bird's head and beak, wings for arms, a crest and a tail
## of plumes, softly lit from inside. Faces -Z, like every NPC model.
func _make_model() -> Node3D:
	var n := Node3D.new()
	n.name = "Pell"
	var soul := Models.toon(SOUL, true, 0.6)
	var plume := Models.toon(PLUME, true, 0.5)
	var beak := Models.toon(Color("f2c46a"), true, 0.2)
	var eye := Models.toon(Color("2a3550"), false)
	Models.part(n, Models.sphere(0.32, 14), soul, Vector3(0, 0.75, 0), Vector3(0.9, 1.25, 0.8))
	Models.part(n, Models.sphere(0.24, 14), soul, Vector3(0, 1.32, -0.04))
	Models.part(n, Models.cyl(0.0, 0.07, 0.24, 8), beak, Vector3(0, 1.28, -0.3), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		Models.part(n, Models.sphere(0.045, 8), eye, Vector3(sx * 0.1, 1.38, -0.19))
		Models.part(n, Models.cyl(0.03, 0.04, 0.42, 6), soul, Vector3(sx * 0.1, 0.24, 0))
		var wing := Node3D.new()
		wing.position = Vector3(sx * 0.24, 1.0, 0.02)
		n.add_child(wing)
		Models.part(wing, Models.box(0.62, 0.05, 0.3), plume, Vector3(sx * 0.32, -0.04, 0))
		Models.part(wing, Models.box(0.4, 0.04, 0.24), soul, Vector3(sx * 0.68, -0.1, 0.04))
		_wings.append(wing)
	for k in 3:
		var a := (k - 1) * 0.35
		Models.part(n, Models.box(0.06, 0.26, 0.04), plume, Vector3(sin(a) * 0.06, 1.6, 0.04),
			Vector3.ONE, Vector3(0.3, 0, -a))
		Models.part(n, Models.box(0.1, 0.04, 0.42), plume, Vector3(sin(a) * 0.12, 0.5, 0.36),
			Vector3.ONE, Vector3(-0.5, a, 0))
	var light := OmniLight3D.new()
	light.light_color = SOUL
	light.omni_range = 4.0
	light.light_energy = 0.8
	light.position = Vector3(0, 0.9, 0)
	n.add_child(light)
	return n
