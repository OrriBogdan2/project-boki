class_name HunterWisp
extends RefCounted
## A downed Hunter shows as a Wisp instead of the hero (docs/decisions/0019-downed-wisp.md). Purely
## presentation: it follows Hunter.downed and Hunter.out and changes nothing about timers, speed, revive
## or targeting. Per hunter, tick() runs a small state machine:
##   hero --down--> fall (the knocked-down beat, BEAT by weight: it staggers along the hit's push, drops to a
##   knee and collapses to the floor, then fades as the Wisp rises out of it) -> pop in (the hero hidden, the
##   Wisp swells to full size) -> on (slow bob, trails heavily behind the hunter and settles when they stop, a
##   quiet hum)
##   on --revive--> pop out (Wisp brightens and fades; the hero grows back from the look's hero_from with a
##   squash and stands up: the fall played backwards) -> hero
##   fall or on --bleed out or executed--> snuffed (the Wisp breaks into sparks)
## The beat is only how it looks: the hunter is downed, revivable and hittable from its first frame.
## A Hero with no fall (no clips: Gil, or a procedural model) puffs at once. The look (colours, body, drift,
## hum, pop timing) is WispLook's data. State lives in the hunter's meta "wisp".

const FALL := "fall"
const IN := "in"
const ON := "on"
const OUT := "out"
const DOWN := [FALL, IN, ON]    # the modes of a downed hunter
## The knocked-down beat by the hunter's weight (Hunter.cls): t s long; the body staggers slide m along the hit's
## push; the collapse eases by the power drop (over 1 a heavy body gathers speed and slams down, under 1 a light one
## crumples at once and settles); dust puffs where it lands.
const BEAT := {
	"light": {"t": 0.4, "slide": 0.45, "drop": 0.6, "dust": 4},
	"medium": {"t": 0.44, "slide": 0.35, "drop": 1.0, "dust": 8},
	"heavy": {"t": 0.48, "slide": 0.22, "drop": 1.8, "dust": 14},
}
const STAGGER_K := 0.3    # of the beat (fall_k): staggering along the push (the hit clip) until here,
const KNEE_K := 0.5       # then down on a knee (the kneel clip) until here, then the collapse (the death clip's tail)
const FLOOR_K := 0.8      # of the beat: on the floor (the dust); the hero fades from here as the Wisp rises out
const EMERGE_K := 0.65    # of the beat: the Wisp starts rising out of the body
const RISE_FROM := 0.25   # m: the height the Wisp rises from (the body on the floor)
const POP_OVERSHOOT := 1.70158   # the "back" ease's overshoot: the pop swells a little past full size
const POP_FROM := 0.3         # fraction of full size the Wisp pops in from
const FLASH_BOOST := 3.0      # extra glow at the instant of a pop

## Runs every render frame, before the hero's own basis is built: advances the state and poses the hero's
## size (a pop-out) and the Wisp.
static func tick(h: Hunter, dt: float) -> void:
	var st := _state(h)
	st["t"] = float(st["t"]) + dt      # (before the step, so a timed mode hands over on its own frame)
	_advance(h, st)
	var mode := String(st["mode"])
	if mode == "":
		return
	match mode:
		FALL: _pose_fall(h, st)
		IN: _pose_in(h, st, dt)
		ON: _pose_on(h, st, dt)
		OUT: _pose_out(h, st, dt)

## True while the hero model stays hidden (the Wisp stands in).
static func hides(h: Hunter) -> bool:
	var mode := String(_state(h)["mode"])
	return mode == IN or mode == ON

## The Wisp's node, or null when the hero is up.
static func node_of(h: Hunter) -> Node3D:
	return _state(h)["node"] as Node3D

static func mode_of(h: Hunter) -> String:
	return String(_state(h)["mode"])

## How far the hero is through its fall: 0 standing .. 1 on the floor, held there while the Wisp stands in and
## run back by the rise; -1 when up. HunterAnim's state "wisp_fall": the Hero's clips seek their death clip by it.
static func fall_k(h: Hunter) -> float:
	var st := _state(h)
	match String(st["mode"]):
		FALL: return _drop(st, _beat_k(st))
		IN, ON: return 1.0
		OUT: return float(st["rise"]) * (1.0 - _out_k(st))
	return -1.0

## The key of this hunter's hum loop in Sfx.
static func hum_key(h: Hunter) -> String:
	return "wisp%d" % h.get_instance_id()

static func _state(h: Hunter) -> Dictionary:
	if not h.has_meta("wisp"):
		var fresh := {"mode": "", "t": 0.0, "node": null, "look": {}}
		fresh.merge({"last": Vector3.ZERO, "lag": Vector3.ZERO, "base": Vector3.ONE, "skin": []})
		h.set_meta("wisp", fresh)
	return h.get_meta("wisp")

static func _advance(h: Hunter, st: Dictionary) -> void:
	var mode := String(st["mode"])
	var look: Dictionary = st["look"]
	if h.out and mode in DOWN:
		_snuff(h, st)
	elif h.downed and not h.out and (mode == "" or mode == OUT):
		_fall(h, st)
	elif not h.downed and mode in DOWN:
		_pop_out(h, st)
	elif mode == FALL and _beat_k(st) >= 1.0:
		_pop_in(h, st)
	elif mode == IN and float(st["t"]) >= float(look["pop_in"]["time"]):
		st["mode"] = ON
	elif mode == OUT and float(st["t"]) >= float(look["pop_out"]["time"]):
		_finish(h, st)

static func _look_id(h: Hunter) -> String:
	return WispLook.equipped() if h.is_local() else ""

static func _team_col(h: Hunter) -> Color:
	return SideColor.of(h.m, h)      # the colour of the hunter's ring and downed marker

## Knocked down: the hero is hit and falls to the floor first (the clips play it from fall_k).
static func _fall(h: Hunter, st: Dictionary) -> void:
	_free_node(st)
	if st["mode"] == OUT:
		_restore_hero(h, st)
	st["look"] = WispLook.get_look(_look_id(h))
	st["mode"] = FALL
	st["t"] = 0.0
	st["beat"] = BEAT.get(h.cls, BEAT["medium"])
	st["landed"] = false
	st.erase("push")
	if h.model == null or float(h.model.get_meta(WardenClips.FLOOR_T, 0.0)) <= 0.0:
		_pop_in(h, st)
		return
	# (Oomph.react keeps the last hit's push on every game; no hit seen: it goes over backwards)
	st["push"] = h.hit_from if h.hit_from != Vector2.ZERO else -Vector2(sin(h.face), cos(h.face))
	st["skin"] = h.model.find_children("*", "GeometryInstance3D", true, false)

## How far the beat is, 0..1, in its own time.
static func _beat_k(st: Dictionary) -> float:
	return minf(float(st["t"]) / float((st["beat"] as Dictionary)["t"]), 1.0)

## The collapse (KNEE_K..FLOOR_K) eased by the weight's drop; the stagger and the knee run as they are.
static func _drop(st: Dictionary, k: float) -> float:
	if k <= KNEE_K or k >= FLOOR_K:
		return k
	var u := (k - KNEE_K) / (FLOOR_K - KNEE_K)
	return KNEE_K + (FLOOR_K - KNEE_K) * pow(u, float((st["beat"] as Dictionary)["drop"]))

## The beat's body (the clips pose it from fall_k): the stagger's slide along the push, the landing's dust, and
## from EMERGE_K the Wisp rising out of the body while the hero fades away.
static func _pose_fall(h: Hunter, st: Dictionary) -> void:
	var beat: Dictionary = st["beat"]
	var k := _beat_k(st)
	h.model.position = _slide_at(st, fall_k(h)) + Vector3(0, h.model.position.y, 0)
	if k >= FLOOR_K and not st["landed"]:
		st["landed"] = true
		if h.visible:
			h.m.fx.dust(h.pos + _slide_at(st, 1.0), int(beat["dust"]))
			h.m.sfx("land", h.pos, -6.0 if h.is_local() else -12.0)
	if k < EMERGE_K:
		return
	var rise := (k - EMERGE_K) / (1.0 - EMERGE_K)
	var look: Dictionary = st["look"]
	if st["node"] == null:
		_spawn(h, st)
		_pop_fx(h, look["pop_in"], RISE_FROM)
	var node := st["node"] as Node3D
	var from := _slide_at(st, 1.0)
	var ease_up := 1.0 - (1.0 - rise) * (1.0 - rise)
	node.position = Vector3(from.x * (1.0 - rise), lerpf(RISE_FROM, float(look["hover"]), ease_up), from.z * (1.0 - rise))
	node.scale = Vector3.ONE * lerpf(0.1, POP_FROM, rise)
	_set_glow(node, 1.0 + FLASH_BOOST * rise, rise)
	_fade_hero(st, smoothstep(FLOOR_K, 1.0, k))

## Where the stagger has carried the body (the model's offset), from fall_k: out along the push while
## staggering, held there after; the rise brings it back.
static func _slide_at(st: Dictionary, fk: float) -> Vector3:
	var u := clampf(fk / STAGGER_K, 0.0, 1.0)
	var push: Vector2 = st["push"]
	var d := float((st["beat"] as Dictionary)["slide"]) * (1.0 - (1.0 - u) * (1.0 - u))
	return Vector3(push.x * d, 0, push.y * d)

## The hero's meshes see-through by a (0 solid .. 1 gone).
static func _fade_hero(st: Dictionary, a: float) -> void:
	for gi in st["skin"]:
		if is_instance_valid(gi):
			(gi as GeometryInstance3D).transparency = a

static func _spawn(h: Hunter, st: Dictionary) -> void:
	var look: Dictionary = st["look"]
	var node := WispLook.build(look, _team_col(h))
	node.position = Vector3(0, float(look["hover"]), 0)
	h.add_child(node)
	st["node"] = node

## The end of the beat (or at once, with no fall): the hero hides and the Wisp swells to full size.
static func _pop_in(h: Hunter, st: Dictionary) -> void:
	var look: Dictionary = st["look"]
	if st["node"] == null:
		_spawn(h, st)
		_pop_fx(h, look["pop_in"], float(look["hover"]))
	st["mode"] = IN
	st["t"] = 0.0
	st["last"] = h.position
	st["lag"] = Vector3.ZERO

static func _pop_out(h: Hunter, st: Dictionary) -> void:
	var look: Dictionary = st["look"]
	st["rise"] = fall_k(h)      # (revived before the fall ended: the rise starts from there)
	st["hid"] = st["mode"] != FALL      # (revived during the beat: the hero never hid, so it does not grow back)
	st["mode"] = OUT
	st["t"] = 0.0
	st["base"] = h.model.scale if h.model else Vector3.ONE
	_fade_hero(st, 0.0)
	Sfx.loop_stop(hum_key(h))
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
	Sfx.loop_stop(hum_key(h))
	_free_node(st)
	_stand_in_place(h, st)
	st["mode"] = ""

static func _finish(h: Hunter, st: Dictionary) -> void:
	_restore_hero(h, st)
	_free_node(st)
	st["mode"] = ""

static func _restore_hero(h: Hunter, st: Dictionary) -> void:
	_stand_in_place(h, st)
	if h.model:
		h.model.scale = st["base"]

## The beat undone: the hero solid again and back over the hunter.
static func _stand_in_place(h: Hunter, st: Dictionary) -> void:
	_fade_hero(st, 0.0)
	st["skin"] = []
	if h.model:
		h.model.position = Vector3(0, h.model.position.y, 0)

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
	var mat := node.get_meta("mat") as ShaderMaterial
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("fade", fade)

static func _pose_in(h: Hunter, st: Dictionary, dt: float) -> void:
	var node := st["node"] as Node3D
	var look: Dictionary = st["look"]
	var k := clampf(float(st["t"]) / float(look["pop_in"]["time"]), 0.0, 1.0)
	var grow := lerpf(POP_FROM, 1.0, _back(k))
	node.scale = Vector3.ONE * grow
	_set_glow(node, 1.0 + FLASH_BOOST * (1.0 - k), 1.0)
	_pose_body(h, st, dt)
	_hum(h, st)

static func _pose_on(h: Hunter, st: Dictionary, dt: float) -> void:
	var node := st["node"] as Node3D
	node.scale = Vector3.ONE
	_set_glow(node, 1.0, 1.0)
	_pose_body(h, st, dt)
	_hum(h, st)

## Slow and heavy: a slow bob, and the body stays behind in the world when the hunter moves (up to the
## look's drag), leaning back a little, then catches up over the look's settle time once they stop.
static func _pose_body(h: Hunter, st: Dictionary, dt: float) -> void:
	var node := st["node"] as Node3D
	var look: Dictionary = st["look"]
	var t := float(st["t"])
	var moved := (h.position - (st["last"] as Vector3)) * Vector3(1, 0, 1)
	st["last"] = h.position
	var drag := float(look["drag"])
	var lag: Vector3 = (st["lag"] as Vector3) + moved
	lag *= exp(-dt / float(look["settle"]))
	lag = lag.limit_length(drag)
	st["lag"] = lag
	var bob := sin(t * TAU * float(look["bob_hz"])) * float(look["bob"])
	node.position = Vector3(-lag.x, float(look["hover"]) + bob, -lag.z)
	var body := node.get_node("Body") as Node3D
	var pull := lag.length() / drag
	if pull > 0.01:
		var forward := lag / lag.length()      # the way the hunter went; the body hangs back and leans back
		body.basis = Basis(Vector3.UP.cross(forward).normalized(), -pull * float(look["lean"]))
	else:
		body.basis = Basis.IDENTITY

## The quiet hum, held each frame so it stops on its own if the Wisp goes away any other way; a Wisp
## nobody can see keeps quiet.
static func _hum(h: Hunter, st: Dictionary) -> void:
	if not h.visible:
		Sfx.loop_stop(hum_key(h))
		return
	var hum: Dictionary = (st["look"] as Dictionary)["hum"]
	Sfx.loop_hold(hum_key(h), String(hum["sfx"]), h.pos, float(hum["db"]))

## How far the pop-out is, 0..1.
static func _out_k(st: Dictionary) -> float:
	return clampf(float(st["t"]) / float((st["look"] as Dictionary)["pop_out"]["time"]), 0.0, 1.0)

## The Wisp brightens away while the hero, standing up through the rise (the stagger's slide coming back), grows
## back; a hero revived during the beat never shrank and only gets up.
static func _pose_out(h: Hunter, st: Dictionary, dt: float) -> void:
	var spec: Dictionary = (st["look"] as Dictionary)["pop_out"]
	var k := _out_k(st)
	if h.model and st.has("push"):
		h.model.position = _slide_at(st, fall_k(h)) + Vector3(0, h.model.position.y, 0)
	var node := st["node"] as Node3D
	if node:
		node.scale = Vector3.ONE * (1.0 + 0.6 * k)
		_set_glow(node, 1.0 + FLASH_BOOST * k, 1.0 - k)
		_pose_body(h, st, dt)
	if not st["hid"]:
		return
	# the hero grows back from hero_from, squashing flat as it lands and springing up
	var grow := lerpf(float(spec["hero_from"]), 1.0, _back(k))
	var squash := float(spec["squash"]) * sin(k * PI)
	var base: Vector3 = st["base"]
	if h.model:
		h.model.scale = base * Vector3(grow * (1.0 + squash * 0.5), grow * (1.0 - squash), grow * (1.0 + squash * 0.5))
