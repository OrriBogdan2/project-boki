class_name JuggernautDrop
extends RefCounted
## Kael's airborne Smash, the Meteor Drop (`rmb.drop` in content/archetypes/juggernaut.json; the source's air
## slam, briefs/hero-ref/juggernaut.md "Air Slam" and "Jump and landing": ~0.85s airborne, ~0.5s recovery).
## Press in the air: a short hang at the top while he gathers (the blade hauled overhead, a tuck and a half
## flip) over a landing marker everyone sees at the clamped cursor, then a visible dive onto it with flame
## streaks, a heavy landing (a crouch, a crack in the ground, a shock ring the size of the stun, dust and
## debris, a shake and a deep boom), and a recovery rising from the crouch. Owned by JuggernautKit.

const PURPLE := Color("b06aff")       # the landing marker (the damage area)
const CORE := Color("ff5ad8")         # its centre ring: the stun area, and the shock ring on impact

var k: JuggernautKit
var phase := ""                       # "" | hang | dive | recover
var t := 0.0                          # s into the phase
var land := Vector3.ZERO              # where it lands (locked on the press)
var from := Vector3.ZERO              # where the dive starts
var dive_t := 0.0                     # s the dive takes
var pressed_at := 0.0
# (tests)
var drops := 0
var last_drop := Vector3.ZERO
var phases: Array = []                # the phases the last one went through
var last_air := 0.0                   # s from the press to the impact
var last_recover := 0.0               # s the last recovery ran
var last_shock_r := 0.0               # m, the shock ring drawn on impact

func _init(kit: JuggernautKit) -> void:
	k = kit

func data() -> Dictionary:
	return k.rmb_def()["drop"]

func running() -> bool:
	return phase != ""

## In the air until the impact.
func airborne() -> bool:
	return phase == "hang" or phase == "dive"

## Planted through the drop and the start of the recovery, then rising back to a walk.
func move_k() -> float:
	if airborne():
		return 0.0
	if phase == "recover":
		var planted := float(data()["planted"])
		return lerpf(0.3, 1.0, clampf((t - planted) / maxf(0.05, float(data()["recover"]) - planted), 0.0, 1.0)) \
				if t >= planted else 0.0
	return 1.0

## Where a Meteor Drop would land now: the cursor, clamped to the reach from under you, on open ground.
func point() -> Vector3:
	var h := k.h
	var at := AimMode.point(h, float(data().get("reach", 5.0)), AimMode.CURSOR, 0.0)
	if k.m.world.is_void(at.x, at.z) or k.m.world.is_block(at.x, at.z):
		at = Vector3(h.pos.x, at.y, h.pos.z)
	return k.ground(at)

## The press (the slot is already spent): the hang begins over the marker.
func start() -> void:
	var h := k.h
	land = point()
	phase = "hang"
	t = 0.0
	pressed_at = k.m.time
	phases = ["hang"]
	h.gliding = false
	h.vel = Vector3.ZERO
	k.play("jug_meteor")
	k.vfx("drop_tell")
	_marker(0.0)

## The marker at the landing point (everyone sees it): the damage area, and the stun core inside it.
func _marker(fill: float) -> void:
	var dd := data()
	AimKit.circle(k.h, "drop", {"at": land, "r": float(dd["radius"]), "col": PURPLE, "all": true, "ticks": true,
			"fill": fill, "dur": 0.12})
	AimKit.circle(k.h, "drop_core", {"at": land, "r": float(dd["core"]), "col": CORE, "all": true, "hot": fill,
			"dur": 0.12})

## A merge, a stun or a knock in the air: it simply stops (no slam).
func cancel() -> void:
	if airborne():
		AimKit.hide(k.h, "drop")
		AimKit.hide(k.h, "drop_core")
	phase = ""

func tick(dt: float) -> void:
	if phase == "":
		return
	var h := k.h
	t += dt
	if airborne() and (h.downed or h.stun_t > 0.0 or KinMerge.active(h)):
		cancel()
		return
	match phase:
		"hang": _tick_hang(dt)
		"dive": _tick_dive()
		"recover":
			# done, or cut short: dashed or jumped out of, or knocked off his feet
			if t >= float(data()["recover"]) or h.roll_t > 0.0 or not h.grounded:
				last_recover = t
				phase = ""

## The gather at the top: held in the air (a touch of lift), the marker filling. An air dash in it carries him
## on (the gather keeps its time), and the dive comes down onto the marker from wherever it took him.
func _tick_hang(dt: float) -> void:
	var h := k.h
	var hang := float(data()["hang"])
	_marker(0.5 * minf(t / hang, 1.0))
	HeroVfx.of(k.m).hold(h, "drop_gather", minf(t / hang, 1.0))
	if h.roll_t > 0.0:
		return
	h.vel = Vector3(0.0, 0.6 * (1.0 - t / hang) + Hunter.H_GRAV * dt, 0.0)
	if t >= hang:
		var dd := data()
		phase = "dive"
		phases.append("dive")
		t = 0.0
		from = h.pos
		var span := from.distance_to(land)
		dive_t = clampf(span / float(dd["dive_speed"]), float(dd["dive_t"][0]), float(dd["dive_t"][1]))
		k.vfx("drop_dive", h.pos, Vector2(land.x - from.x, land.z - from.z).normalized())

## The dive: down along a steepening curve onto the marker (seen all the way, not a teleport), flame streaks.
func _tick_dive() -> void:
	var h := k.h
	var u := clampf(t / dive_t, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u) * 0.35 + u * u * 0.65        # eased out of the hang, accelerating into the ground
	var at := Vector3(lerpf(from.x, land.x, e), lerpf(from.y, land.y, u * u), lerpf(from.z, land.z, e))
	h.vel = Vector3.ZERO
	h.teleport(at)
	_marker(0.5 + 0.5 * u)
	if k.tells_visible():
		HeroVfx.of(k.m).hold(h, "drop_comet")
	if u >= 1.0:
		_impact()

func _impact() -> void:
	var h := k.h
	h.grounded = true
	h.vel = Vector3.ZERO
	AimKit.hide(h, "drop")
	AimKit.hide(h, "drop_core")
	phase = "recover"
	phases.append("impact")
	phases.append("recover")
	t = 0.0
	drops += 1
	last_drop = h.pos
	last_air = k.m.time - pressed_at
	k.play("jug_meteor_land")
	_hit(h.pos)
	_impact_fx(h.pos)

func _hit(at: Vector3) -> void:
	var dd := data()
	var stg := k.stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(dd["radius"])},
		"effects": [{"type": "damage", "amount": float(dd["dmg"]) * k.smash_k()},
				{"type": "slow", "duration": float(dd["slow_t"]), "strength": float(dd["slow"])}]})
	k.run_own(stg, k.cx("rmb", "meteor_drop", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f) or f.dead: return
		if stunned_at(f.pos, f.r, at):
			f.hurt(float(dd["dmg"]) * k.smash_k() * float(dd["core_k"]) * k.power("sec"), k.h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "meteor_core"], "stun": float(dd["stun"]),
							"dr": true})
			k.m.fx.word(f.pos + Vector3(0, 2.3, 0), "CRUSHED", k.res_col(), false)}))

## True when a body of radius `r` at `p` touches the stun core (the ring drawn on impact) of a slam at `at`.
func stunned_at(p: Vector3, r: float, at: Vector3) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() < float(data()["core"]) + r

## The landing: the ground breaking open across the damage area, a wall of flame at the stun's edge, dust and
## debris, a shake, the boom.
func _impact_fx(at: Vector3) -> void:
	var dd := data()
	last_shock_r = float(dd["core"])
	k.vfx("drop_hit", at, k.h.aim_dir(), {"r": float(dd["radius"]), "core": last_shock_r})
	Shake.incoming_big(k.m, at, 0.5, k.h)
