class_name JuggernautChain
extends RefCounted
## Kael's E, the Warchain (his "e" data in content/archetypes/juggernaut.json; the source's tether chain).
## The states and every transition are in docs/heroes/juggernaut.md "Warchain: the state machine":
## ready -> throwing (the hook flies at the cursor) -> hooked (a foe or a wall: the link chain stays on while
## you move, paying out to its full length and holding there, 5s) -> pulling (E again: an impulse toward the
## anchor that his movement input and facing curve, and backing away first slingshots; Shift or a jump exits) ->
## arriving (a short window that keeps some of the pull's speed and still takes the Cinder Spin) -> ready.
## A miss, a stun or the time running out breaks it. Owned by JuggernautKit.

const ORANGE := Color("ff8a2a")     # the bright links (and the zig-zag in flight)
const DARK := Color("3a2418")       # the dark iron links
const HOT := Color("ffd04a")        # the links pulled taut, and while it hauls you in
const TAUT := 0.85                  # share of its full length where the chain starts to strain (glow and creak)

var k: JuggernautKit
var state := "ready"                # ready | throwing | hooked | pulling | arriving
var target: Ent = null              # the hooked foe (null on a wall)
var anchor := Vector3.ZERO          # where the hook bit (follows a hooked foe)
var tether_t := 0.0                 # s the hook still holds
var e_pressed_at := -9.0            # an E pressed while the hook flew (becomes the pull if it bites soon)
var pull_dir := Vector2.ZERO        # the pull's heading now (it turns toward the anchor, bent by input and facing)
var pull_speed := 0.0               # m/s of the pull (the reel speed plus the slingshot)
var pull_t := 0.0                   # s left before the pull gives up (a wall in the way)
var sling := 0.0                    # (tests) m/s the slingshot added to the last pull
var line := Vector2.ZERO            # the chain's line when the pull started (the steer is sideways to it)
var steer := 0.0                    # m the arrival point has been steered sideways of the anchor
var stall_t := 0.0
var arrive_t := 0.0                 # s left of the arrival window
var strained := false
var tightened := false              # the chain has hit its full length since it bit (one creak per hold)
# (tests)
var throws := 0
var hooks := 0
var misses := 0
var breaks := 0
var holds := 0                      # times the chain held at its full length
var reels := 0
var arrivals := 0
var exits := ""                     # how the last pull ended: arrived | dash | jump | stopped
var last_arrival := Vector3.ZERO

func _init(kit: JuggernautKit) -> void:
	k = kit

func data() -> Dictionary:
	return k.e_def()

func hooked() -> bool:
	return state == "hooked"

func pulling() -> bool:
	return state == "pulling"

## The pull and the short window after it: a Smash here is the Cinder Spin.
func spin_window() -> bool:
	return state == "pulling" or state == "arriving"

## E pressed (the kit has checked busy()): throw, pull, or buffer a pull while the hook still flies.
func press() -> void:
	var h := k.h
	match state:
		"hooked":
			pull()
		"throwing":
			e_pressed_at = k.m.time
		"pulling", "arriving":
			pass                    # the pull is committed: no second pull, no stop
		_:
			if float(k.cd["e"]) > 0.0 or h.root_t > 0.0 or KitStatus.grounded(h):
				h._ab_feedback("k1", "deny")
				return
			_throw()
			throws += 1
			h.used["k1"] = int(h.used.get("k1", 0)) + 1
			h._ab_feedback("k1", "cast")
			CombatBus.ability_used.emit(h, k.id + "_e", "kin")
			k.last_e = String(data().get("name", ""))

func _throw() -> void:
	var ed := data()
	var h := k.h
	state = "throwing"
	e_pressed_at = -9.0
	k.play("jug_chain")
	var stg := k.stage("e", {"delivery": {"type": "projectile", "speed": float(ed["speed"]),
			"range": float(ed["range"]), "size": 0.22, "rope": true},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}]})
	var shots0: int = k.m.shots.size()
	k.run(stg, k.cx("e", "warchain", k.aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if state == "throwing" and is_instance_valid(f) and not f.dead: _hook(f, f.pos),
		"on_shot_end": func(at: Vector3, why: String, e: Ent):
			if state != "throwing" or e != null: return
			if why == "wall": _hook(null, at)
			else: _miss(at)}))
	if k.m.shots.size() > shots0 and k.m.shots[-1]["by"] == h:
		var sd: Dictionary = k.m.shots[-1]
		k.fx().ride(sd, "hook", ORANGE, Color("ffcf6a"), 0.6, 0.15)
		# the shared hook look and its thin pale rope would draw over the Warchain's own chain
		if sd.has("deco") and is_instance_valid(sd["deco"]):
			(sd["deco"] as Node3D).visible = false
	k.m.sfx("jug_chain", h.pos, -3.0, 1.0)
	k.m.sfx("ab_tether", h.pos, -6.0, 0.7)

func _hook(f: Ent, at: Vector3) -> void:
	var ed := data()
	var m := k.m
	state = "hooked"
	target = f
	anchor = at
	tether_t = float(ed["time"])
	strained = false
	tightened = false
	hooks += 1
	k.fx().star(at + Vector3(0, 1.0 if f else 0.5, 0), Color("ffd84a"), 0.9, 0.18)      # the spark at the anchor
	if f:
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "CHAINED", k.col_of(ed), true)
	else:
		m.fx.word(at + Vector3(0, 1.4, 0), "ANCHORED", k.col_of(ed), false)
	m.sfx("ab_tether", at, -2.0, 1.0)
	m.sfx("jug_taut", at, -6.0, 1.1)
	k.net_bolt(k.h.pos + Vector3(0, 1.0, 0), at + Vector3(0, 1.0, 0), k.col_of(ed))
	if m.time - e_pressed_at <= JuggernautKit.BUFFER:
		pull()                      # E was pressed a hair before it bit

func _miss(at: Vector3) -> void:
	state = "ready"
	misses += 1
	k.start_e_cd()                  # hooked nothing: the chain breaks, its cooldown starts
	k.m.fx.word(at + Vector3(0, 1.2, 0), "MISS", Color("c0b0a0"), false)

## Breaks a throw or a hold (a stun, the time, a merge): the cooldown starts.
func snap(word := "CHAIN BROKE") -> void:
	if state == "throwing" or state == "hooked":
		breaks += 1
		k.start_e_cd()
		if word != "": k.m.fx.word(k.h.pos + Vector3(0, 2.2, 0), word, Color("c0b0a0"), false)
	elif state == "pulling":
		_stop("stopped", false)
	state = "ready"
	target = null
	k.fx().unchain(_fx_id())

## The Chain Lunge ran down it: the chain is used up and its cooldown starts.
func spend() -> void:
	state = "ready"
	target = null
	k.start_e_cd()
	k.fx().unchain(_fx_id())

func _fx_id() -> String:
	return "war%d" % k.h.get_instance_id()

## E on a hooked chain: flown to the anchor (a Lunge charging becomes a Haul Slam for the arrival).
func pull() -> void:
	var ed := data()
	var h := k.h
	k.start_e_cd()
	state = "pulling"
	if k.busy() or h.root_t > 0.0:
		_stop("stopped", false)
		return
	k.arm_haul()
	var at := _anchor_now()
	var to := Vector2(at.x - h.pos.x, at.z - h.pos.z)
	var dist := to.length()
	stall_t = 0.0
	reels += 1
	if dist < _gap() + 0.4:
		pull_dir = to.normalized()
		_arrive()
		return
	_launch(to.normalized())
	pull_t = dist / pull_speed + 0.5
	h.dash_with({"type": "dash", "speed": pull_speed, "time": pull_t, "kind": "rush", "dir": pull_dir,
			"invuln": 0.0})
	if k.anim_id != "jug_haul_wind": k.play("jug_reel")
	k.fx().puff(h.pos + Vector3(0, 0.2, 0), Color(1, 1, 1, 0.8), 0.9, 0.35)        # the start puff (footage 0333)
	k.m.fx.dust(h.pos, 8)
	k.m.sfx("jug_reel", h.pos, -3.0 if h.is_local() else -7.0, 1.0)
	k.last_e = "reel"

## The pull's start along `toward` (the chain's line): the reel speed, plus a slingshot from his speed away from
## the anchor at the press (backing away stretches it); the sideways part of his motion carries in, so a strafe
## swings the pull wide from the start.
func _launch(toward: Vector2) -> void:
	var ed := data()
	var h := k.h
	var v := Vector2(h.vel.x, h.vel.z)
	var side := Vector2(-toward.y, toward.x)
	sling = minf(maxf(0.0, -v.dot(toward)) * float(ed["sling_k"]), float(ed["sling_max"]))
	line = toward
	steer = 0.0
	pull_speed = float(ed["reel_speed"]) + sling
	pull_dir = (toward * pull_speed + side * v.dot(side)).normalized()

## How far short of the anchor the pull ends: against a hooked foe's body, or 0.7 m off a wall.
func _gap() -> float:
	return (target.r + k.h.r + 0.2) if target != null and is_instance_valid(target) else 0.7

## The heading the pull turns toward: a point beside the anchor that his movement input (steer_rate m/s, up to
## steer_max) and where he faces (face_k of it) slide sideways of the chain's line, so holding a strafe or
## looking aside curves him in beside it.
func _want(dt: float) -> Vector2:
	var ed := data()
	var h := k.h
	var side := Vector2(-line.y, line.x)
	var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
	var push := clampf(mv.dot(side), -1.0, 1.0) + h.aim_dir().dot(side) * float(ed["face_k"])
	var most := float(ed["steer_max"])
	steer = clampf(steer + push * float(ed["steer_rate"]) * dt, -most, most)
	var goal := _anchor_now() + Vector3(side.x, 0, side.y) * steer
	return Vector2(goal.x - h.pos.x, goal.z - h.pos.z).normalized()

## Each step (before the hunter moves).
func tick(dt: float) -> void:
	match state:
		"hooked": _tick_hooked(dt)
		"pulling": _tick_pull(dt)
		"arriving":
			arrive_t -= dt
			if arrive_t <= 0.0:
				state = "ready"
	if state == "throwing":
		if k.h.stun_t > 0.0:
			snap()                  # a stun breaks the throw too
		else:
			_draw_flight()

func _tick_hooked(dt: float) -> void:
	var h := k.h
	tether_t -= dt
	if target != null:
		if not is_instance_valid(target) or target.dead or (target is Hunter and (target as Hunter).downed):
			snap()
			return
		anchor = target.pos
	if h.stun_t > 0.0:
		snap()
		return
	if tether_t <= 0.0:
		snap("")
		return
	var most := float(data()["tether_max"])
	var stretch := Vector2(anchor.x - h.pos.x, anchor.z - h.pos.z).length() / most
	if stretch > 1.0:
		_hold_taut(most)
		stretch = 1.0
	_draw_hooked(stretch)

## The chain paid out to its full length holds: whoever is moving away is stopped at the end of it (him, or a
## hooked foe trying to walk off); nothing breaks.
func _hold_taut(most: float) -> void:
	var h := k.h
	var out := Vector2(h.pos.x - anchor.x, h.pos.z - anchor.z).normalized()
	var mover: Ent = h
	if target != null and Vector2(h.vel.x, h.vel.z).dot(out) <= 0.0:
		mover = target                    # he's standing: it's the foe pulling away
		out = -out
	var from := anchor if mover == h else h.pos
	var at := Vector3(from.x + out.x * most, mover.pos.y, from.z + out.y * most)
	mover.pos.x = at.x
	mover.pos.z = at.z
	var away := Vector2(mover.vel.x, mover.vel.z).dot(out)
	if away > 0.0:
		mover.vel.x -= out.x * away
		mover.vel.z -= out.y * away
	if not tightened:
		tightened = true
		holds += 1
		k.m.sfx("jug_taut", h.pos, -3.0, 0.75)          # the chain snapping taut at its length

## The attached chain: straight striped links that pull taut and glow hotter as it stretches (with a creak).
func _draw_hooked(stretch: float) -> void:
	var h := k.h
	var tension := clampf((stretch - 0.5) / (TAUT - 0.5), 0.0, 1.0)
	if stretch >= TAUT and not strained:
		k.m.sfx("jug_taut", h.pos, -5.0, 0.9)
		k.fx().star(anchor + Vector3(0, 1.0, 0), HOT, 0.6, 0.15)
	strained = stretch >= TAUT
	if not (k.tells_visible() or target != null):
		return
	var a := h.pos + Vector3(0, 1.0, 0)
	var b := anchor + Vector3(0, 1.0 if target != null else 0.6, 0)
	k.fx().chain(_fx_id(), a, b, 0.3 * (1.0 - tension), ORANGE.lerp(HOT, tension * 0.6), DARK, 0.13 + 0.03 * tension)

func _draw_flight() -> void:
	for s in k.m.shots:
		if s["by"] == k.h and (s["x"] as Dictionary).get("rope", false):
			k.fx().chain(_fx_id(), k.h.pos + Vector3(0, 1.0, 0), s["pos"], 1.0, ORANGE, ORANGE, 0.12)
			return

func _tick_pull(dt: float) -> void:
	var h := k.h
	var ed := data()
	if h.stun_t > 0.0 or h.root_t > 0.0 or h.knock_t > 0.0 or h.downed:
		_stop("stopped", false)
		return
	if not h.grounded and h.vel.y > 0.5:
		_jump_out()
		return
	if h.roll_t <= 0.0 or h.move_kind != "rush":
		_stop("stopped", false)     # something else took over the movement
		return
	var at := _anchor_now()
	var side := Vector2(-line.y, line.x) * steer
	var to := Vector2(at.x + side.x - h.pos.x, at.z + side.y - h.pos.z)
	var step := pull_speed * dt
	stall_t = stall_t + dt if h.vel.length() < pull_speed * 0.3 and pull_t < 0.5 else 0.0
	pull_t -= dt
	var touching := target != null and is_instance_valid(target) and h.flat_dist(target) <= target.r + h.r + 0.25
	# curved in beside it: the anchor is already behind the heading, close by
	var passed := to.dot(pull_dir) <= 0.0 and to.length() < float(ed["steer_reach"])
	if to.length() <= _gap() + step or touching or passed or pull_t <= 0.0 or stall_t > 0.1:
		_arrive()
		return
	var want := _want(dt)
	var turn := float(ed["turn"]) * dt
	pull_dir = pull_dir.rotated(clampf(pull_dir.angle_to(want), -turn, turn))
	h.roll_dir = pull_dir
	h.roll_speed = pull_speed
	h.roll_t = maxf(h.roll_t, dt * 2.0)
	var a := h.pos + Vector3(0, 1.0, 0)
	k.fx().chain(_fx_id(), a, at + Vector3(0, 1.0 if target != null else 0.6, 0), 0.0, HOT, DARK, 0.16)

func _anchor_now() -> Vector3:
	return target.pos if target != null and is_instance_valid(target) else anchor

## The pull reaches the anchor: some of its speed carries on, an armed Haul Slam lands, the spin window opens.
func _arrive() -> void:
	var h := k.h
	var ed := data()
	var dir := pull_dir
	_stop("arrived", true)
	var keep := dir * maxf(pull_speed, float(ed["reel_speed"])) * float(ed["carry"])
	h.vel.x = keep.x
	h.vel.z = keep.y
	arrivals += 1
	last_arrival = h.pos
	state = "arriving"
	arrive_t = float(ed["arrive_t"])
	k.m.fx.dust(h.pos, 10)
	k.m.sfx("ab_tether", h.pos, -6.0, 1.3)
	k.land_haul()

## Shift mid-pull: the pull ends and the dash takes over the movement.
func dash_out() -> void:
	_stop("dash", false)

## Jumped mid-pull: the pull ends in a jump that keeps most of its speed (the glider takes it too).
func _jump_out() -> void:
	var h := k.h
	var ed := data()
	var dir := pull_dir
	_stop("jump", false)
	var spd := pull_speed * float(ed["jump_carry"])
	h.vel.x = dir.x * spd
	h.vel.z = dir.y * spd
	h.glide_handoff(dir, spd)
	k.play("jug_reel")

func _stop(how: String, arrived: bool) -> void:
	var h := k.h
	exits = how
	state = "ready"
	if h.move_kind == "rush" and how != "dash":
		h.roll_t = 0.0
		if how == "stopped":
			h.vel.x = 0.0
			h.vel.z = 0.0
	k.fx().unchain(_fx_id())
	if not arrived:
		k.drop_haul()
	target = null
