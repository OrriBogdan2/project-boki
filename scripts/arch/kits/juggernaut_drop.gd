class_name JuggernautDrop
extends RefCounted
## Kael's airborne Smash, the Meteor Drop (`rmb.drop` in content/archetypes/juggernaut.json; the source's air
## slam, briefs/hero-ref/juggernaut.md "Air Slam" and "Jump and landing": ~0.85s airborne, ~0.5s recovery).
## Press in the air: a short hang at the top while he gathers (the blade hauled overhead, a tuck and a half
## flip) as he slides over a landing marker everyone sees at the clamped cursor, then a straight vertical slam
## down onto it with flame streaks, a heavy landing (a crouch, a crack in the ground, a shock ring the size of
## the stun, dust and debris, a shake and a deep boom), and a recovery rising from the crouch. Owned by
## JuggernautKit.
## The Finishing Slam (`rmb.slam`, the Smash tapped on the ground) runs the same flight as a leap: a crouch, a
## spring up and forward in an arc (~3m at the top) toward a landing circle everyone sees, a beat at the top with
## the blade overhead, the crash down onto the circle, and the burst there (JuggernautKit._slam).

const PURPLE := Color("b06aff")       # the landing marker (the damage area)
const CORE := Color("ff5ad8")         # its centre ring: the stun area, and the shock ring on impact
const CLOSE := 0.25                   # share of the dive that closes any gap to the spot left by an air dash

var k: JuggernautKit
var mode := "drop"                    # drop (the Meteor Drop) | leap (the Finishing Slam)
var phase := ""                       # "" | crouch | rise (a leap's) | hang | dive | recover
var t := 0.0                          # s into the phase
var land := Vector3.ZERO              # where it lands (locked on the press)
var from := Vector3.ZERO              # where the leap or the dive starts
var top := Vector3.ZERO               # the top of a leap's arc
var heading := Vector2.ZERO           # the way a leap goes (along the ground)
var dive_t := 0.0                     # s the dive takes
var pressed_at := 0.0
# (tests)
var drops := 0
var last_drop := Vector3.ZERO
var leaps := 0
var last_leap := Vector3.ZERO
var last_apex := 0.0                  # m a leap's arc rose above its takeoff
var phases: Array = []                # the phases the last one went through
var last_air := 0.0                   # s from the press to the impact
var last_recover := 0.0               # s the last recovery ran
var last_shock_r := 0.0               # m, the shock ring drawn on impact

func _init(kit: JuggernautKit) -> void:
	k = kit

func data() -> Dictionary:
	return k.rmb_def()["slam" if mode == "leap" else "drop"]

func running() -> bool:
	return phase != ""

## In the air until the impact.
func airborne() -> bool:
	return phase == "rise" or phase == "hang" or phase == "dive"

## It owns the body: from the press (a leap's crouch) to the impact.
func owns() -> bool:
	return phase != "" and phase != "recover"

## Planted through the flight and the start of the recovery, then rising back to a walk.
func move_k() -> float:
	if owns():
		return 0.0
	if phase == "recover":
		var planted := float(data()["planted"])
		return lerpf(0.3, 1.0, clampf((t - planted) / maxf(0.05, float(data()["recover"]) - planted), 0.0, 1.0)) \
				if t >= planted else 0.0
	return 1.0

## Where it would land now: the cursor, clamped to the reach from under you, on open ground.
func point() -> Vector3:
	var h := k.h
	var at := AimMode.point(h, float(data().get("reach", 5.0)), AimMode.CURSOR, 0.0)
	if k.m.world.is_void(at.x, at.z) or k.m.world.is_block(at.x, at.z):
		at = Vector3(h.pos.x, at.y, h.pos.z)
	return k.ground(at)

## The press (the slot is already spent), `how` drop or leap: a drop's hang begins over the marker; a leap
## crouches under him, the landing circle already down.
func start(how: String) -> void:
	var h := k.h
	mode = how
	land = point()
	from = h.pos
	t = 0.0
	pressed_at = k.m.time
	h.gliding = false
	h.vel = Vector3.ZERO
	if mode == "leap":
		phase = "crouch"
		var go := Vector2(land.x - from.x, land.z - from.z)
		heading = go.normalized() if go.length() > 0.1 else h.aim_dir()
		k.play("jug_leap")
	else:
		phase = "hang"
		k.play("jug_meteor")
		k.vfx("drop_tell")
	phases = [phase]
	_marker(0.0)

## The marker at the landing point (everyone sees it): the damage area, and the ring inside it (a drop's stun
## core; a leap's sweet spot is outside it, the burst's outer ring).
func _marker(fill: float) -> void:
	var dd := data()
	var leap := mode == "leap"
	AimKit.circle(k.h, _keys()[0], {"at": land, "r": float(dd["radius"]), "col": JuggernautKit.SLASH_OUT if leap
			else PURPLE, "all": true, "ticks": true, "fill": fill, "dur": 0.12})
	AimKit.circle(k.h, _keys()[1], {"at": land, "r": float(dd["sweet" if leap else "core"]), "col": CORE,
			"all": true, "hot": 0.0 if leap else fill, "dur": 0.12})

func _keys() -> Array:
	return ["slam", "slam_rim"] if mode == "leap" else ["drop", "drop_core"]

## A merge, a stun or a knock before the impact: it simply stops (no slam; in the air he falls).
func cancel() -> void:
	if owns():
		for key in _keys():
			AimKit.hide(k.h, key)
	phase = ""

func tick(dt: float) -> void:
	if phase == "":
		return
	var h := k.h
	t += dt
	if owns() and (h.downed or h.stun_t > 0.0 or KinMerge.active(h)):
		cancel()
		return
	match phase:
		"crouch": _tick_crouch()
		"rise": _tick_rise()
		"hang": _tick_hang(dt)
		"dive": _tick_dive()
		"recover":
			# done, or cut short: dashed or jumped out of, or knocked off his feet
			if t >= float(data()["recover"]) or h.roll_t > 0.0 or not h.grounded:
				last_recover = t
				phase = ""

## A leap's crouch: planted, the circle down; then the spring (dust off the ground, a trail behind him).
func _tick_crouch() -> void:
	var h := k.h
	var dd := data()
	h.vel = Vector3.ZERO
	_marker(0.0)
	if t < float(dd["crouch"]):
		return
	phase = "rise"
	phases.append("rise")
	t = 0.0
	from = h.pos
	h.grounded = false
	var span := Vector2(land.x - from.x, land.z - from.z) * 0.6
	top = Vector3(from.x + span.x, maxf(from.y, land.y) + float(dd["height"]), from.z + span.y)
	last_apex = top.y - from.y
	k.vfx("slam_tell", from, heading)

## Up and forward to the top of the arc, slowing as he gets there (seen all the way, not a teleport); half way up
## he hauls the blade overhead.
func _tick_rise() -> void:
	var h := k.h
	var u := clampf(t / float(data()["rise"]), 0.0, 1.0)
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	h.vel = Vector3.ZERO
	h.teleport(Vector3(lerpf(from.x, top.x, u), lerpf(from.y, top.y, e), lerpf(from.z, top.z, u)))
	_marker(0.0)
	if k.tells_visible():
		HeroVfx.of(k.m).hold(h, "slam_wind", u)
	if u >= 0.5 and k.anim_id == "jug_leap":
		k.play("jug_meteor")
	if u >= 1.0:
		phase = "hang"
		phases.append("hang")
		t = 0.0

## The gather at the top: held in the air (a touch of lift), the marker filling; a drop slides over the spot so the
## slam comes straight down, a leap hangs where its arc peaked and comes down along it. An air dash in it carries
## him on (the gather keeps its time), and the dive closes what's left.
func _tick_hang(dt: float) -> void:
	var h := k.h
	var hang := float(data()["hang"])
	_marker(0.5 * minf(t / hang, 1.0))
	HeroVfx.of(k.m).hold(h, "slam_wind" if mode == "leap" else "drop_gather", minf(t / hang, 1.0))
	if h.roll_t > 0.0:
		return
	var over := 0.0 if mode == "leap" else clampf(dt / maxf(hang - t, dt), 0.0, 1.0)
	h.teleport(Vector3(lerpf(h.pos.x, land.x, over), h.pos.y, lerpf(h.pos.z, land.z, over)))
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

## The dive: down onto the marker, accelerating (seen all the way, not a teleport), flame streaks rising off him;
## a drop's straight down, a leap's on along its arc.
func _tick_dive() -> void:
	var h := k.h
	var u := clampf(t / dive_t, 0.0, 1.0)
	var e := u if mode == "leap" else clampf(u / CLOSE, 0.0, 1.0)     # (a drop is over the spot already)
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
	for key in _keys():
		AimKit.hide(h, key)
	phase = "recover"
	phases.append("impact")
	phases.append("recover")
	t = 0.0
	last_air = k.m.time - pressed_at
	k.play("jug_meteor_land")
	if mode == "leap":
		leaps += 1
		last_leap = h.pos
		k._slam(heading)
	else:
		drops += 1
		last_drop = h.pos
		_hit(h.pos)
		_impact_fx(h.pos)
	Shake.incoming_big(k.m, h.pos, 0.5, h)

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
