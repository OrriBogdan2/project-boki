class_name HunterWisp
extends RefCounted
## A downed Hunter shows as a Wisp instead of the hero (docs/decisions/0019-downed-wisp.md). Purely
## presentation: it follows Hunter.downed and Hunter.out and changes nothing about timers, speed, revive
## or targeting. Per hunter, tick() runs a small state machine:
##   hero --down--> in: the knocked-down beat (HunterFall: the hero staggers along the hit, drops to a knee and
##   collapses, fading out as the Wisp rises out of it; a ring and a puff mark the down) -> on (hero hidden, slow
##   bob, trails heavily behind the hunter and settles when they stop, a quiet hum)
##   on --revive--> pop out (Wisp brightens and fades, hero grows back from the look's hero_from with a squash) -> hero
##   in or on --bleed out or executed--> elim (the look's snuff time: the hit, the heart flashing in the killer's
##     side colour; the fall, dimming into the deathbox as it grows in; then the Wisp's pop) -> gone (the Wisp
##     was the death: no death clip after it) --back from the dead--> ""
## The look (colours, body, drift, hum, timing) is WispLook's data. State lives in the hunter's meta "wisp".

const IN := "in"
const ON := "on"
const OUT := "out"
const ELIM := "elim"
const GONE := "gone"
const POP_OVERSHOOT := 1.70158   # the "back" ease's overshoot: the pop swells a little past full size
const POP_FROM := 0.3         # fraction of full size the Wisp pops in from
const FLASH_BOOST := 3.0      # extra glow at the instant of a pop
const ELIM_HIT := 0.25        # fraction of the elimination beat that is the hit (the heart in the killer's colour)
const ELIM_DIM := 0.25        # fraction of its opacity the Wisp keeps as it reaches the box
const ELIM_SHRINK := 0.6      # fraction of its size the Wisp keeps as it reaches the box (uniform: it stays round)
const ELIM_BOX_FROM := 0.4    # fraction of its size the deathbox grows in from during the beat
const HIT_RISE := 0.3         # m the hit knocks the Wisp up before it falls
const BOX_IN := 0.15          # m above the box's spot the Wisp falls to (inside the crate)
const BOX_REACH := 2.0        # m: a box further off (abyss, sky train) is not fallen into
const RISE_FROM := 0.15       # m above the ground: where the Wisp leaves the fallen body from

## Runs every render frame, before the hero's own basis is built: advances the state and poses the hero's
## size (a pop-out) and the Wisp.
static func tick(h: Hunter, dt: float) -> void:
	var st := _state(h)
	_advance(h, st)
	var mode := String(st["mode"])
	if mode == "":
		return
	st["t"] = float(st["t"]) + dt
	match mode:
		IN: _pose_in(h, st, dt)
		ON: _pose_on(h, st, dt)
		OUT: _pose_out(h, st, dt)
		ELIM: _pose_elim(h, st)

## True while the hero model stays hidden (the Wisp stands in, or was the death).
static func hides(h: Hunter) -> bool:
	return String(_state(h)["mode"]) in [IN, ON, ELIM, GONE]

## For an out hunter: the node stays up through the elimination beat, or through the hero's death clip
## when there was no Wisp (died outright).
static func out_visible(h: Hunter) -> bool:
	var mode := String(_state(h)["mode"])
	return mode == ELIM or (mode != GONE and WardenClips.dying(h))

## The Wisp's node, or null when the hero is up.
static func node_of(h: Hunter) -> Node3D:
	return _state(h)["node"] as Node3D

static func mode_of(h: Hunter) -> String:
	return String(_state(h)["mode"])

## The key of this hunter's hum loop in Sfx.
static func hum_key(h: Hunter) -> String:
	return "wisp%d" % h.get_instance_id()

static func _state(h: Hunter) -> Dictionary:
	if not h.has_meta("wisp"):
		var fresh := {"mode": "", "t": 0.0, "node": null, "look": {}}
		fresh.merge({"last": Vector3.ZERO, "lag": Vector3.ZERO, "base": Vector3.ONE})
		h.set_meta("wisp", fresh)
	return h.get_meta("wisp")

static func _advance(h: Hunter, st: Dictionary) -> void:
	var mode := String(st["mode"])
	var look: Dictionary = st["look"]
	var fall := HunterFall.of(h)
	if h.out and (mode == IN or mode == ON):
		_elim_start(h, st)
	elif mode == ELIM and (not h.out or float(st["t"]) >= float(look["snuff"]["time"])):
		_elim_end(h, st)
	elif mode == GONE and not h.out:
		st["mode"] = ""
	elif h.downed and not h.out and (mode == "" or mode == OUT):
		_pop_in(h, st)
	elif not h.downed and (mode == IN or mode == ON):
		_pop_out(h, st)
	elif mode == IN and (fall == null or float(st["t"]) >= fall.time):
		HunterFall.stop(h)
		st["mode"] = ON
	elif mode == OUT and float(st["t"]) >= float(look["pop_out"]["time"]):
		_finish(h, st)

static func _look_id(h: Hunter) -> String:
	return WispLook.equipped() if h.is_local() else ""

static func _team_col(h: Hunter) -> Color:
	return SideColor.of(h.m, h)      # the colour of the hunter's ring and downed marker

static func _pop_in(h: Hunter, st: Dictionary) -> void:
	_free_node(st)
	if st["mode"] == OUT:
		_restore_hero(h, st)
	HunterFall.start(h)
	var look := WispLook.get_look(_look_id(h))
	var node := WispLook.build(look, _team_col(h))
	node.position = Vector3(0, float(look["hover"]), 0)
	h.add_child(node)
	st["node"] = node
	st["look"] = look
	st["mode"] = IN
	st["t"] = 0.0
	st["last"] = h.position
	st["lag"] = Vector3.ZERO
	_pop_fx(h, look["pop_in"], float(look["hover"]))

static func _pop_out(h: Hunter, st: Dictionary) -> void:
	var look: Dictionary = st["look"]
	HunterFall.stop(h)       # revived mid-fall: the hero comes back where the hunter is
	st["mode"] = OUT
	st["t"] = 0.0
	st["base"] = h.model.scale if h.model else Vector3.ONE
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

## Bled out or executed: the Wisp stays for the beat, takes the hit in the killer's side colour (its own
## when nobody is known) and heads for the deathbox.
static func _elim_start(h: Hunter, st: Dictionary) -> void:
	var spec: Dictionary = (st["look"] as Dictionary)["snuff"]
	var by := h.last_hit_by
	st["kcol"] = SideColor.of(h.m, by) if by != null and is_instance_valid(by) and by != h else _team_col(h)
	var box := Life.box_of(h.m, h)
	# only this death's box: a remote copy may not have it yet, the abyss keeps none
	st["box"] = box if not box.is_empty() and Life.soul_here(h.m, box) else {}
	st["mode"] = ELIM
	st["t"] = 0.0
	st.erase("from")
	HunterFall.stop(h)       # out mid-fall: the body is back on the hunter (hidden), the Wisp takes the hit
	Sfx.loop_stop(hum_key(h))
	h.m.sfx(String(spec["hit_sfx"]), h.position, -8.0)

## The beat's end: the Wisp pops where it fell and is freed, the box stands at full size. A revive in the
## middle of it ends it at once, with no pop.
static func _elim_end(h: Hunter, st: Dictionary) -> void:
	var node := st["node"] as Node3D
	if h.out:
		_pop_fx(h, (st["look"] as Dictionary)["snuff"], node.position.y)
	_box_scale(st, 1.0)
	_free_node(st)
	st["mode"] = GONE if h.out else ""

static func _box_scale(st: Dictionary, grow: float) -> void:
	var n := (st["box"] as Dictionary).get("node") as Node3D
	if n and is_instance_valid(n):
		n.scale = Vector3.ONE * grow

static func _finish(h: Hunter, st: Dictionary) -> void:
	_restore_hero(h, st)
	_free_node(st)
	st["mode"] = ""

static func _restore_hero(h: Hunter, st: Dictionary) -> void:
	if h.model:
		h.model.scale = st["base"]

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

## The knocked-down beat: the body falls (HunterFall), and as it fades the Wisp comes out of it, white hot, growing
## and rising to its hover.
static func _pose_in(h: Hunter, st: Dictionary, dt: float) -> void:
	var node := st["node"] as Node3D
	var fall := HunterFall.of(h)
	fall.pose(h, clampf(float(st["t"]) / fall.time, 0.0, 1.0))
	var out_k := fall.gone
	node.scale = Vector3.ONE * lerpf(POP_FROM, 1.0, _back(out_k))
	_set_glow(node, 1.0 + FLASH_BOOST * (1.0 - out_k), out_k)
	_pose_body(h, st, dt)
	var body := h.model.position
	var floats := node.position
	node.position = Vector3(lerpf(body.x, floats.x, out_k), lerpf(RISE_FROM, floats.y, _back(out_k)),
			lerpf(body.z, floats.z, out_k))
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

static func _pose_out(h: Hunter, st: Dictionary, dt: float) -> void:
	var look: Dictionary = st["look"]
	var spec: Dictionary = look["pop_out"]
	var k := clampf(float(st["t"]) / float(spec["time"]), 0.0, 1.0)
	var node := st["node"] as Node3D
	if node:
		node.scale = Vector3.ONE * (1.0 + 0.6 * k)
		_set_glow(node, 1.0 + FLASH_BOOST * k, 1.0 - k)
		_pose_body(h, st, dt)
	# the hero grows back from HERO_FROM, squashing flat as it lands and springing up
	var grow := lerpf(float(spec["hero_from"]), 1.0, _back(k))
	var squash := float(spec["squash"]) * sin(k * PI)
	var base: Vector3 = st["base"]
	if h.model:
		h.model.scale = base * Vector3(grow * (1.0 + squash * 0.5), grow * (1.0 - squash), grow * (1.0 + squash * 0.5))

## The hit (the Wisp is knocked up, its heart takes the killer's colour; the rim keeps the team colour), then
## the fall: the Wisp dims and drops into the deathbox as the box grows in. It only ever scales evenly, so
## the round outline holds to the end.
static func _pose_elim(h: Hunter, st: Dictionary) -> void:
	var node := st["node"] as Node3D
	var look: Dictionary = st["look"]
	var k := clampf(float(st["t"]) / float(look["snuff"]["time"]), 0.0, 1.0)
	var hit := k < ELIM_HIT
	var heart := WispLook.colour(String(look["core"]["color"]), _team_col(h))
	var mat := node.get_meta("mat") as ShaderMaterial
	mat.set_shader_parameter("core_col", st["kcol"] if hit else heart)
	var fall := clampf((k - ELIM_HIT) / (1.0 - ELIM_HIT), 0.0, 1.0)
	_set_glow(node, 1.0, lerpf(1.0, ELIM_DIM, fall))
	if not st.has("from"):
		st["from"] = node.position
	var from: Vector3 = st["from"]
	var to := Vector3(from.x, BOX_IN, from.z)
	var box := st["box"] as Dictionary
	if box.has("pos"):
		var off := (box["pos"] as Vector3) - h.position
		if Vector2(off.x, off.z).length() <= BOX_REACH:
			to = off + Vector3(0, BOX_IN, 0)
	var top := float(look["hover"]) + HIT_RISE
	if hit:
		node.position.y = lerpf(float(look["hover"]), top, sin(k / ELIM_HIT * PI * 0.5))
	else:
		var f2 := fall * fall
		node.position = Vector3(lerpf(from.x, to.x, f2), lerpf(top, to.y, f2), lerpf(from.z, to.z, f2))
	node.scale = Vector3.ONE * lerpf(1.0, ELIM_SHRINK, fall)
	_box_scale(st, lerpf(ELIM_BOX_FROM, 1.0, _back(k)))
