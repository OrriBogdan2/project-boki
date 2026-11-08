class_name AshwickJet
extends RefCounted
## Cinder's ultimate on X, Flue Flight (docs/heroes/ashwick.md): a ring of embers at lift-off, then 1.8s of
## low flight toward the cursor that steers with the aim at a capped turn rate. A molten carpet forms under
## him as he goes and lasts 5.2s: it burns, slows and builds Char. X again lands early; a stun ends the flight;
## a knockback, or Shift (a poof from the bellows), speeds it up; a jump leaps off it, keeping its speed. The
## carpet never forms over the abyss. An enemy hunter it burns (or knocks, or kills) fills the Boki bond
## (HeroUlt.landed).

const LAY_STEP := 1.0           # m between two carpet pieces (each one is a pooled LDFx lava strip)
const OVERLAP := 0.45           # m each piece reaches back over the last, so the carpet reads as one strip
const NET_EVERY := 3            # carpet pieces between two rings sent to other players' games
const STEER_LEAD := 1.0         # m the heading lane runs past where the flight will end
const LAVA_DY := 1.6            # m above the carpet a body still stands in it
const RING_PUFFS := 10          # flame puffs standing round the lift-off ring
const FOOTING := 0.05           # s: the low flight counts as footing for a jump (Hunter.coyote) while it runs
const JET_ANCHORS := ["anchor_jet_0", "anchor_jet_1"]   # the tank's two exhaust stacks on the model

var k: AshwickKit
var h: Hunter
var m: Node
var stacks: Array = []          # the model's stack anchors (Node3D), once it has them
var flight := {}                # hold: the flight under way {t, dir, speed, last, set_v}
var trail: Array = []           # carpet pieces: {a, b, until}
var tick_acc := 0.0
var laid := 0
var flights := 0                # (tests)
var locked := 0                 # (tests) presses the flight swallowed
var landings := 0
var early := 0
var boosts := 0
var leaps := 0
var trail_hits := 0
var void_skips := 0

func _init(kit: AshwickKit) -> void:
	k = kit
	h = kit.h
	m = kit.m

func xd() -> Dictionary:
	return k.x_def()

func running() -> bool:
	return not flight.is_empty()

## Flue Flight: ONLY E (Heat Shield) and X (land early) work; the flight's own steering and a jump stay. Every
## other ability or item press is dropped before it reaches its handler (not buffered): RMB (Cinder Shot, and a
## hold carried in is cancelled with nothing fired), Shift (no poof, no Soot Ram), the glove/utility slots,
## gear, the Boki's C and a throw. A press answers with the soft "can't" tick.
const LOCKED := ["dash", "sec", "util1", "util2", "util3", "util4", "gear1", "gear2", "kin_ab", "skill", "throw"]

func lock_inputs() -> void:
	if not running():
		return
	for key in LOCKED:
		if h.inp.get(key, false):
			locked += 1
			h.inp[key] = false
			h._ab_feedback(key if key in ["dash", "sec"] else "base", "deny")
	h.dash_buf = 0.0
	h.inp["dash_down"] = false
	h.inp["sec_hold"] = false
	if k.rmb_down:
		k.rmb_down = false           # a hold carried in: its release must not fire
		k.aiming = false
		AimKit.hide(h, "rmb")

## Lift-off: an ember ring at his feet, the jet roars, the flight starts toward the cursor.
func start() -> bool:
	if running():
		return false
	var x := xd()
	var dir := h.aim_dir()
	var speed := float(x["speed"])
	h.dash_with({"speed": speed, "time": float(x["time"]), "invuln": 0.0, "dir": dir, "kind": "jet"})
	h.gliding = false
	flight = {"t": float(x["time"]), "dir": dir, "speed": speed, "last": k.ground(h.pos), "set_v": dir * speed,
		"knock": h.knock_t}
	flights += 1
	k.play("lw_jet")
	_liftoff_fx()
	return true

## X while flying: land now.
func recast() -> bool:
	if not running():
		return false
	early += 1
	_land()
	return true

## A Boki merge: the flight ends where he is, with no landing (the carpet already laid stays).
func drop() -> void:
	if not running():
		return
	flight = {}
	h.roll_t = 0.0
	AimKit.hide(h, "x_steer")
	k.play("")

func tick(dt: float) -> void:
	if running():
		_fly(dt)
	if not trail.is_empty():
		_burn(dt)

## Is this body standing in the carpet?
func in_lava(f: Ent) -> bool:
	return _lava_at(f) != null

# ------------------------------------------------------------------ flight
func _fly(dt: float) -> void:
	if h.stun_t > 0.0 or h.downed or h.out or KinMerge.active(h):
		_land()
		return
	if h.inp.get("jump", false) and h.vel.y > 0.0:
		_leap()
		return
	h.coyote = maxf(h.coyote, FOOTING)
	if h.dash_buf > 0.0:
		h.dash_buf = 0.0            # Shift in the flight (Hunter.do_dash holds it for the flight's end): a poof now
		k.on_dash(true)
	var x := xd()
	flight["t"] = float(flight["t"]) - dt
	_take_boost(x)
	var dir: Vector2 = flight["dir"]
	var turn := deg_to_rad(float(x["turn_deg"])) * dt
	dir = dir.rotated(clampf(dir.angle_to(h.aim_dir()), -turn, turn))
	flight["dir"] = dir
	var speed := float(flight["speed"])
	h.roll_dir = dir
	h.roll_speed = speed
	h.roll_t = maxf(0.02, float(flight["t"]))
	flight["set_v"] = dir * speed
	_hover(float(x["hover"]), dt)
	var p := k.ground(h.pos)
	if Vector2(p.x - (flight["last"] as Vector3).x, p.z - (flight["last"] as Vector3).z).length() >= LAY_STEP:
		_lay(flight["last"], p)
		flight["last"] = p
	_jet_fx(dir)
	var left := speed * maxf(0.0, float(flight["t"])) + STEER_LEAD
	AimKit.lane(h, "x_steer", {"dir": dir, "len": left, "width": float(x["trail_w"]), "chevrons": 3,
		"col": k.col_of(x), "alpha": 0.75})
	if float(flight["t"]) <= 0.0:
		_land()

## A knockback mid-flight (a fresh Hunter.impulse pushed the body off the flight's velocity) adds to the
## flight's speed and bends it the way it was pushed.
func _take_boost(x: Dictionary) -> void:
	var fresh := h.knock_t > float(flight["knock"]) + 0.001
	flight["knock"] = h.knock_t
	var push := Vector2(h.vel.x, h.vel.z) - (flight["set_v"] as Vector2)
	if not fresh or push.length() < 1.5:
		return
	_feed(push, x)

## Shift in the flight: a poof from the bellows along `dir` feeds it like a knockback: the poof's kept speed
## (Soot Ram's air_keep share of it) adds to the flight's, and the heading bends its way.
func poof(dir: Vector2) -> void:
	var dd := k.dash_def()
	var kept := float(dd["air_dist"]) / float(dd["air_time"]) * float(dd["air_keep"])
	_feed(dir.normalized() * kept, xd())

## A push adds to the flight's speed (up to boost_max over its own) and bends it the way it was pushed.
func _feed(push: Vector2, x: Dictionary) -> void:
	boosts += 1
	var top := float(x["speed"]) + float(x["boost_max"])
	flight["speed"] = minf(top, float(flight["speed"]) + push.length() * float(x["boost_k"]))
	var dir: Vector2 = flight["dir"]
	flight["dir"] = (dir * float(flight["speed"]) + push).normalized()

## Low and upright: eased up to `hover` over the ground; over the abyss he holds his height.
func _hover(hover: float, dt: float) -> void:
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	h.vel.y = 0.0
	if gy <= World.VOID + 1.0:
		return
	if h.pos.y < gy + hover:
		h.pos.y = move_toward(h.pos.y, gy + hover, 6.0 * dt)
	h.grounded = false

## A jump in the flight (Hunter.do_jump took off from it): he leaps off the jet, the flight over (no landing, the
## carpet laid stays), keeping a jump out of a dash's share of its speed, handed on to a glide.
func _leap() -> void:
	var dir: Vector2 = flight["dir"]
	var speed := float(flight["speed"])
	flight = {}
	leaps += 1
	h.roll_t = 0.0
	var keep := dir * speed * Hunter.DASH_JUMP_CARRY
	h.vel.x = keep.x
	h.vel.z = keep.y
	h.glide_handoff(dir, speed)
	AimKit.hide(h, "x_steer")
	k.play("lw_hop")                 # tucked for the leap off (no burst: the jet's own flame just stops)

func _land() -> void:
	flight = {}
	landings += 1
	h.roll_t = 0.0
	h.vel.x *= 0.3
	h.vel.z *= 0.3
	AimKit.hide(h, "x_steer")
	k.play("lw_land")
	m.fx.dust(h.pos, 10)
	m.sfx("lw_jet_land", h.pos, -3.0, 1.0)

# ------------------------------------------------------------------ the carpet
## One carpet piece from a to b, only where both ends are over ground (never over the abyss).
func _lay(a: Vector3, b: Vector3) -> void:
	var W = m.world
	if W.ground_at(a.x, a.z) <= World.VOID + 1.0 or W.ground_at(b.x, b.z) <= World.VOID + 1.0:
		void_skips += 1
		return
	var x := xd()
	trail.append({"a": a, "b": b, "until": m.time + float(x["trail_t"])})
	var along := (b - a).normalized()
	k.fx.lava(a - along * OVERLAP, b, float(x["trail_w"]), float(x["trail_t"]))
	laid += 1
	if laid % NET_EVERY == 0:
		k.net_ring(b, float(x["trail_w"]) * 0.5, k.col_of(x))
		m.sfx("lw_trail", b, -6.0, 1.0)

## Every tick (0.3s): burn, slow and Char whoever stands in the carpet; the oldest pieces fade first.
func _burn(dt: float) -> void:
	trail = trail.filter(func(t): return float(t["until"]) > m.time)
	tick_acc += dt
	var x := xd()
	var every := float(x["tick"])
	if tick_acc < every:
		return
	tick_acc -= every
	var dmg := float(x["trail_dps"]) * every * k.power("x")
	var opts := {
		"src": "flame", "ab": "ult", "tags": ["flame", "ult"], "slow": float(x["slow_for"]), "slow_k": float(x["slow"])
	}
	for f in m.foes_of(h.team):
		if not f.hittable() or _lava_at(f) == null:
			continue
		f.hurt(dmg, h, opts)
		k.add_char(f, float(x["char"]))
		trail_hits += 1
		HeroUlt.landed(k, f)
	for t in trail:
		if randf() < 0.35 and k.tells_visible():
			m.fx.burst((t["b"] as Vector3) + Vector3(0, 0.2, 0), Color("ff8a3a"), 2, 1.5, 0.4, -3.0, 1.2)

## The carpet piece this body stands in, or null.
func _lava_at(f: Ent):
	var rr := float(xd()["trail_w"]) * 0.5 + f.r
	var fp := Vector2(f.pos.x, f.pos.z)
	for t in trail:
		var a: Vector3 = t["a"]
		var b: Vector3 = t["b"]
		if absf(f.pos.y - b.y) > LAVA_DY:
			continue
		var on := Geometry2D.get_closest_point_to_segment(fp, Vector2(a.x, a.z), Vector2(b.x, b.z))
		if on.distance_to(fp) < rr:
			return t
	return null

# ------------------------------------------------------------------ looks
## A red-orange ember ring about 1.2 bh round his feet (a solid ring of flame puffs over a deep red wave, so
## it holds on bright grass), a jagged burst and the roar of the bellows jet.
func _liftoff_fx() -> void:
	var x := xd()
	var r := float(x["burst_r"])
	var at := k.ground(h.pos)
	k.fx.wave(at, r, Color("d8281a"), 0.4, Color(Color("ff8a2a"), 0.7))
	k.fx.sunburst(at + Vector3(0, 0.3, 0), r * 0.75, Color("ff4a1a"), Color("ffc040"), 0.3)
	for i in RING_PUFFS:
		var ang := TAU * float(i) / RING_PUFFS
		k.fx.puff(at + Vector3(cos(ang) * r, 0.45, sin(ang) * r), LDFx.M_FLAME, Color.BLACK, Color.BLACK, 0.7, 0.4)
	m.fx.burst(at + Vector3(0, 0.3, 0), Color("ff6a3a"), 26, 6.0, 0.45, 3.0, 1.2)
	m.sfx("lw_jet", h.pos, -1.0, 1.0)
	k.net_ring(at, r, k.col_of(x))

## The tank's two exhaust stacks: a hot core on each (the model's anchor_jet_*; its flight clip stretches
## their flames) and embers blown down behind her. With no model: one core at her back.
func _jet_fx(dir: Vector2) -> void:
	if not k.tells_visible():
		return
	var cores := jet_points(dir)
	var down := Vector3(-dir.x * 0.6, -1.0, -dir.y * 0.6).normalized()
	for at in cores:
		k.fx.orb(at, Color("ff9a3a"), Color("fff4c0"), 0.55 / sqrt(float(cores.size())), 0.06)
		var embers := 2 if cores.size() == 1 else 1
		m.fx.burst(at, Color("ff7a2a"), embers, 4.0, 0.3, 2.0, 0.9, down, 25.0)

## Where the jets burn: each stack's mouth on the model, else the one point at her back.
func jet_points(dir: Vector2) -> Array:
	if stacks.is_empty() and h.model:
		for nm in JET_ANCHORS:
			var a := WardenGlb.anchor(h.model, nm)
			if a:
				stacks.append(a)
	var out: Array = []
	for a in stacks:
		if is_instance_valid(a) and (a as Node3D).is_inside_tree():
			out.append((a as Node3D).global_position)
	if out.is_empty():
		out.append(h.pos + Vector3(0, 1.1, 0) - Vector3(dir.x, 0, dir.y) * 0.45)
	return out
