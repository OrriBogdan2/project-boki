class_name HunterWisp
extends RefCounted
## A downed Hunter shows as a Wisp instead of the hero (docs/decisions/0019-downed-wisp.md). Purely
## presentation: it follows Hunter.downed and Hunter.out and changes nothing about timers, speed, revive
## or targeting. Per hunter, tick() runs a small state machine:
##   hero --down--> fall (the hero plays its hit clip stretched over pop_in.time; the Wisp fades in on the
##                   last pop_in.fade s, then the hero hides and the Wisp puffs)
##                   -> on (bob, flicker, lean and trail when moving)
##   on --revive--> rise (the Wisp brightens and fades while the hero plays the same clip backwards over
##                  pop_out.time) -> hero
##   on --bleed out or executed--> snuffed (the Wisp breaks into sparks)
## The look (colours, effects, timing) is WispLook's data. State lives in the hunter's meta "wisp".

const IN := "in"
const ON := "on"
const OUT := "out"
const LEAN_RATE := 8.0        # 1/s: how fast the tilt and stretch follow the speed
const MOVE_SPEED := 0.8       # m/s above which the Wisp counts as moving (starts the trail)
const FULL_LEAN_SPEED := 6.0  # m/s at which the lean and stretch are full
const POP_OVERSHOOT := 1.70158   # the "back" ease's overshoot: the pop swells a little past full size
const POP_FROM := 0.3         # fraction of full size the Wisp pops in from
const FLASH_BOOST := 3.0      # extra glow at the instant of a pop
const EYES_AHEAD := 0.4       # how far the eyes turn from the camera toward the facing

## Runs every render frame, before the hero's own basis is built: advances the state and poses the Wisp.
static func tick(h: Hunter, dt: float) -> void:
	var st := _state(h)
	_advance(h, st)
	var mode := String(st["mode"])
	if mode == "":
		return
	st["t"] = float(st["t"]) + dt
	match mode:
		IN: _pose_in(h, st)
		ON: _pose_on(h, st, dt)
		OUT: _pose_out(h, st, dt)

## True while the hero model stays hidden (the Wisp stands in).
static func hides(h: Hunter) -> bool:
	return String(_state(h)["mode"]) == ON

## How far the hero is through its fall (0 up .. 1 down; the rise runs it back), -1 when it plays neither.
## HunterAnim's state "fall": the Hero's clips seek their hit clip to it.
static func fall_k(h: Hunter) -> float:
	var st := _state(h)
	var look: Dictionary = st["look"]
	match String(st["mode"]):
		IN: return clampf(float(st["t"]) / float(look["pop_in"]["time"]), 0.0, 1.0)
		OUT: return 1.0 - clampf(float(st["t"]) / float(look["pop_out"]["time"]), 0.0, 1.0)
	return -1.0

## The Wisp's node, or null when the hero is up.
static func node_of(h: Hunter) -> Node3D:
	return _state(h)["node"] as Node3D

static func mode_of(h: Hunter) -> String:
	return String(_state(h)["mode"])

static func _state(h: Hunter) -> Dictionary:
	if not h.has_meta("wisp"):
		var fresh := {"mode": "", "t": 0.0, "node": null, "look": {}}
		fresh.merge({"last": Vector3.ZERO, "lean": 0.0})
		h.set_meta("wisp", fresh)
	return h.get_meta("wisp")

static func _advance(h: Hunter, st: Dictionary) -> void:
	var mode := String(st["mode"])
	var look: Dictionary = st["look"]
	if h.out and (mode == IN or mode == ON):
		_snuff(h, st)
	elif h.downed and not h.out and (mode == "" or mode == OUT):
		_pop_in(h, st)
	elif not h.downed and (mode == IN or mode == ON):
		_pop_out(h, st)
	elif mode == IN and float(st["t"]) >= float(look["pop_in"]["time"]):
		st["mode"] = ON
		_pop_fx(h, look["pop_in"], float(look["hover"]))
	elif mode == OUT and float(st["t"]) >= float(look["pop_out"]["time"]):
		_finish(st)

static func _look_id(h: Hunter) -> String:
	return WispLook.equipped() if h.is_local() else ""

static func _team_col(h: Hunter) -> Color:
	return SideColor.of(h.m, h)      # the colour of the hunter's ring and downed marker

static func _pop_in(h: Hunter, st: Dictionary) -> void:
	_free_node(st)
	var look := WispLook.get_look(_look_id(h))
	var node := WispLook.build(look, _team_col(h))
	node.position = Vector3(0, float(look["hover"]), 0)
	h.add_child(node)
	st["node"] = node
	st["look"] = look
	st["mode"] = IN
	st["t"] = 0.0
	st["last"] = h.position
	st["lean"] = 0.0
	_set_glow(node, 1.0, 0.0)

static func _pop_out(h: Hunter, st: Dictionary) -> void:
	var look: Dictionary = st["look"]
	st["mode"] = OUT
	st["t"] = 0.0
	_pop_fx(h, look["pop_out"], 0.5)

## Ring, burst and sound of a pop; a Wisp nobody can see makes none.
static func _pop_fx(h: Hunter, spec: Dictionary, height: float) -> void:
	if not h.visible:
		return
	var at := h.position + Vector3(0, height, 0)
	var col := _team_col(h)
	h.m.fx.ring(h.position, float(spec["ring"]), col, float(spec["time"]))
	h.m.fx.burst(at, col.lightened(0.5), int(spec["burst"]), 4.0, 0.45, -1.0, 0.9)
	h.m.sfx(String(spec["sfx"]), h.position, -6.0 if h.is_local() else -12.0)

## Bled out or executed: the Wisp breaks into sparks where it floated.
static func _snuff(h: Hunter, st: Dictionary) -> void:
	var spec: Dictionary = (st["look"] as Dictionary)["snuff"]
	var at := h.position + Vector3(0, float((st["look"] as Dictionary)["hover"]), 0)
	h.m.fx.burst(at, _team_col(h).lightened(0.4), int(spec["burst"]), 5.0, 0.7, 4.0, 1.0)
	h.m.sfx(String(spec["sfx"]), h.position, -8.0)
	_free_node(st)
	st["mode"] = ""

static func _finish(st: Dictionary) -> void:
	_free_node(st)
	st["mode"] = ""

static func _free_node(st: Dictionary) -> void:
	var node := st["node"] as Node3D
	if node and is_instance_valid(node):
		node.queue_free()
	st["node"] = null

## The "back" ease: swells a little past 1 and settles. k in 0..1.
static func _back(k: float) -> float:
	var u := k - 1.0
	return 1.0 + (POP_OVERSHOOT + 1.0) * u * u * u + POP_OVERSHOOT * u * u

static func _set_glow(node: Node3D, flash: float, fade: float) -> void:
	for mat in node.get_meta("mats", []):
		(mat as ShaderMaterial).set_shader_parameter("flash", flash)
		(mat as ShaderMaterial).set_shader_parameter("fade", fade)

static func _pose_in(h: Hunter, st: Dictionary) -> void:
	var node := st["node"] as Node3D
	var look: Dictionary = st["look"]
	var spec: Dictionary = look["pop_in"]
	var k := clampf((float(st["t"]) - (float(spec["time"]) - float(spec["fade"]))) / float(spec["fade"]), 0.0, 1.0)
	node.scale = Vector3.ONE * lerpf(POP_FROM, 1.0, _back(k))
	_set_glow(node, 1.0 + FLASH_BOOST * (1.0 - k), k)
	_pose_body(h, st, 0.0)

static func _pose_on(h: Hunter, st: Dictionary, dt: float) -> void:
	var node := st["node"] as Node3D
	node.scale = Vector3.ONE
	_set_glow(node, 1.0, 1.0)
	_pose_body(h, st, dt)

## Bob, lean toward the way it moves, stretch along it, and the trail while moving.
static func _pose_body(h: Hunter, st: Dictionary, dt: float) -> void:
	var node := st["node"] as Node3D
	var look: Dictionary = st["look"]
	var t := float(st["t"])
	var moved := (h.position - (st["last"] as Vector3)) * Vector3(1, 0, 1)
	st["last"] = h.position
	var speed := moved.length() / maxf(dt, 0.0001) if dt > 0.0 else 0.0
	var follow := 1.0 - exp(-LEAN_RATE * dt)
	st["lean"] = lerpf(float(st["lean"]), clampf(speed / FULL_LEAN_SPEED, 0.0, 1.0), follow)
	var lean := float(st["lean"])
	node.position.y = float(look["hover"]) + sin(t * TAU * float(look["bob_hz"])) * float(look["bob"])
	var tilt := node.get_node("Tilt") as Node3D
	var forward := moved.normalized() if speed > MOVE_SPEED else Vector3.ZERO
	if forward != Vector3.ZERO:
		tilt.basis = Basis(Vector3.UP.cross(forward).normalized(), -lean * float(look["lean"]))
	elif lean < 0.05:
		tilt.basis = Basis.IDENTITY
	var stretch := float(look["stretch"]) * lean
	tilt.scale = Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5)
	_aim_eyes(h, tilt.get_node_or_null("Eyes") as Node3D)
	(node.get_node("Trail") as CPUParticles3D).emitting = speed > MOVE_SPEED

## The eyes look up at the camera (from the top-down view they would sit on the Wisp's edge), a little
## toward where the hunter faces.
static func _aim_eyes(h: Hunter, eyes: Node3D) -> void:
	var cam := h.get_viewport().get_camera_3d() if eyes else null
	if cam == null:
		return
	var to_cam := (cam.global_position - eyes.global_position).normalized()
	var ahead := Basis(Vector3.UP, h.face) * Vector3.FORWARD
	eyes.look_at(eyes.global_position + to_cam + ahead * EYES_AHEAD, Vector3.UP)

static func _pose_out(h: Hunter, st: Dictionary, dt: float) -> void:
	var look: Dictionary = st["look"]
	var spec: Dictionary = look["pop_out"]
	var k := clampf(float(st["t"]) / float(spec["time"]), 0.0, 1.0)
	var node := st["node"] as Node3D
	if node:
		node.scale = Vector3.ONE * (1.0 + 0.6 * k)
		_set_glow(node, 1.0 + FLASH_BOOST * k, 1.0 - k)
		_pose_body(h, st, dt)
