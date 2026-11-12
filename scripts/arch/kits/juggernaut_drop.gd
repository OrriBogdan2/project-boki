class_name JuggernautDrop
extends RefCounted
## Kael's airborne Smash, the Meteor Drop (`rmb.drop` in content/archetypes/juggernaut.json): a down slam, owner
## spec 11-10. Only from the air (he must already be jumping or falling; on the ground RMB is the Finishing Slam or
## the Lunge). Press: his drift stops, a beat of hang with the blade hauled overhead (`hang`, <= 0.1s), then a fast
## straight drop to the ground under him (no dive across, no leap, no extra height). The hit is a small circle
## a little ahead of where he lands, in the facing at the press, shown to everyone from the press: everyone in it
## is knocked down and anyone airborne is spiked to the ground (Displace.spike); a crack, a shock ring, cel dust
## and debris, a shake for those nearby and a deep boom. Then a recovery rising from the crouch. Owned by
## JuggernautKit.

const PURPLE := Color("b06aff")       # the hit circle (the damage area)
const CORE := Color("ff5ad8")         # its centre ring: the stun area
const SPIKE_OVER := 0.3               # m over the landing a foe counts as airborne (spiked down, not only knocked down)

var k: JuggernautKit
var phase := ""                       # "" | hang | dive | recover
var t := 0.0                          # s into the phase
var dir := Vector2.RIGHT              # facing at the press: the hit sits `ahead` m this way from the landing
var land := Vector3.ZERO              # where his feet land (fixed when the drop starts)
var from := Vector3.ZERO              # where the drop starts
var dive_t := 0.0                     # s the drop takes
var pressed_at := 0.0
# (tests)
var drops := 0
var last_drop := Vector3.ZERO         # where he landed
var last_hit := Vector3.ZERO          # the centre of the hit circle
var phases: Array = []                # the phases the last one went through
var last_air := 0.0                   # s from the press to the impact
var last_recover := 0.0               # s the last recovery ran
var last_shock_r := 0.0               # m, the shock ring drawn on impact
var spiked := 0                       # airborne foes the landings spiked to the ground

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

## The centre of the hit for a landing at `feet` facing `d`: `ahead` m in front, on the ground.
func hit_at(feet: Vector3, d: Vector2) -> Vector3:
	var c := feet + Vector3(d.x, 0.0, d.y) * float(data()["ahead"])
	return Vector3(c.x, feet.y, c.z)

## Where a Meteor Drop pressed now would hit: ahead of the ground straight under him, in his aim.
func point() -> Vector3:
	return hit_at(k.ground(k.h.pos), k.h.aim_dir())

## The press (the slot is already spent): his drift stops and the short hang begins.
func start() -> void:
	var h := k.h
	dir = h.aim_dir()
	phase = "hang"
	t = 0.0
	pressed_at = k.m.time
	phases = ["hang"]
	h.gliding = false
	h.vel = Vector3.ZERO
	k.play("jug_meteor")
	k.vfx("drop_tell")
	_marker(hit_at(k.ground(h.pos), dir), 0.0)

## The hit circle (everyone sees it): the damage area, and the stun core inside it.
func _marker(at: Vector3, fill: float) -> void:
	var dd := data()
	AimKit.circle(k.h, "drop", {"at": at, "r": float(dd["radius"]), "col": PURPLE, "all": true, "ticks": true,
			"fill": fill, "dur": 0.12})
	AimKit.circle(k.h, "drop_core", {"at": at, "r": float(dd["core"]), "col": CORE, "all": true, "hot": fill,
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

## The wind-up: held where he is (gravity cancelled), the blade going up. An air dash in it carries him on, and
## the drop then falls from wherever that left him.
func _tick_hang(dt: float) -> void:
	var h := k.h
	var hang := float(data()["hang"])
	_marker(hit_at(k.ground(h.pos), dir), 0.5 * minf(t / hang, 1.0))
	HeroVfx.of(k.m).hold(h, "drop_gather", minf(t / hang, 1.0))
	if h.roll_t > 0.0:
		return
	h.vel = Vector3(0.0, Hunter.H_GRAV * dt, 0.0)
	if t >= hang:
		var dd := data()
		phase = "dive"
		phases.append("dive")
		t = 0.0
		from = h.pos
		land = k.ground(h.pos)
		dive_t = clampf((from.y - land.y) / float(dd["dive_speed"]), float(dd["dive_t"][0]), float(dd["dive_t"][1]))
		k.vfx("drop_dive", h.pos, dir)

## The drop: straight down, accelerating (seen all the way, not a teleport), flame streaks rising off him.
func _tick_dive() -> void:
	var h := k.h
	var u := clampf(t / dive_t, 0.0, 1.0)
	h.vel = Vector3.ZERO
	h.teleport(Vector3(from.x, lerpf(from.y, land.y, u * u), from.z))
	_marker(hit_at(land, dir), 0.5 + 0.5 * u)
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
	last_hit = hit_at(h.pos, dir)
	last_air = k.m.time - pressed_at
	k.play("jug_meteor_land")
	_hit(last_hit)
	_impact_fx(last_hit)

## The landing burst: everyone in it is knocked down (a short stun) and anyone off the ground is spiked down to it;
## the core takes more and stays down longer.
func _hit(at: Vector3) -> void:
	var dd := data()
	var stg := k.stage("rmb", {"delivery": {"type": "burst", "origin": "aim", "radius": float(dd["radius"])},
		"effects": [{"type": "damage", "amount": float(dd["dmg"]) * k.smash_k()}]})
	k.run_own(stg, k.cx("rmb", "meteor_drop", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f) or f.dead: return
		var core := stunned_at(f.pos, f.r, at)
		if f.pos.y > at.y + SPIKE_OVER or (f is Hunter and (f as Hunter).gliding):
			k.m.displace.spike(f, -float(dd["spike_vy"]), k.h)
			spiked += 1
		var extra := float(dd["dmg"]) * k.smash_k() * float(dd["core_k"]) * k.power("sec") if core else 1.0
		var tag := "meteor_core" if core else "meteor_down"
		f.hurt(extra, k.h, {"src": "abil", "ab": "utility", "tags": ["utility", tag],
				"stun": float(dd["stun"] if core else dd["down"]), "dr": true})}))

## True when a body of radius `r` at `p` touches the stun core of a slam whose hit is centred at `at`.
func stunned_at(p: Vector3, r: float, at: Vector3) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() < float(data()["core"]) + r

## The landing: the ground cracking across the hit circle, a shock ring and cel dust, debris, the boom, and a light
## shake for anyone else close by (Shake: your own moves never shake your screen).
func _impact_fx(at: Vector3) -> void:
	var dd := data()
	last_shock_r = float(dd["radius"])
	k.vfx("drop_hit", at, dir, {"r": last_shock_r, "core": float(dd["core"])})
	Shake.incoming_big(k.m, at, 0.35, k.h)
