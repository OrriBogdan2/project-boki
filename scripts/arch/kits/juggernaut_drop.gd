class_name JuggernautDrop
extends RefCounted
## Kael's airborne Smash, the Meteor Drop (`rmb.drop` in content/archetypes/juggernaut.json; the source's air
## slam, briefs/hero-ref/juggernaut.md "Air Slam" and "Jump and landing": ~0.85s airborne, ~0.5s recovery).
## Press in the air: a short hang at the top while he gathers (the blade hauled overhead, a tuck and a half
## flip) as he slides over a landing marker everyone sees at the clamped cursor, then a straight vertical slam
## down onto it with flame streaks, a heavy landing (a crouch, a crack in the ground, a shock ring the size of
## the stun, dust and debris, a shake and a deep boom), and a recovery rising from the crouch. Owned by
## JuggernautKit.

const PURPLE := Color("b06aff")       # the landing marker (the damage area)
const CORE := Color("ff5ad8")         # its centre ring: the stun area, and the shock ring on impact
const STREAK := Color("ff7a1a")       # the dive's flame streaks
const STREAK_HOT := Color("ffd04a")
const CRACK := Color("3a2010")        # the cracks in the ground
const DEBRIS := Color("8a7058")
const CRACK_T := 1.6                  # s the crack in the ground stays, fading over the last half
const CRACK_N := 7                    # cracks running out from the impact
const CRACK_SEGS := 4                 # jagged pieces in each
const CLOSE := 0.25                   # share of the dive that closes any gap to the spot left by an air dash

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
var cracks: Node3D = null             # the crack decal (built once, moved to each impact)
var crack_mat: StandardMaterial3D = null
var crack_t := 0.0

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
	k.m.sfx("jug_drop", h.pos, -2.0, 0.85)
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
	if crack_t > 0.0:
		crack_t -= dt
		crack_mat.albedo_color.a = clampf(crack_t / (CRACK_T * 0.5), 0.0, 1.0) * 0.7
		cracks.visible = crack_t > 0.0
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

## The gather at the top: held in the air (a touch of lift), sliding over the spot so the slam comes straight down,
## the marker filling. An air dash in it carries him on (the gather keeps its time), and the dive closes what's left
## at its very start.
func _tick_hang(dt: float) -> void:
	var h := k.h
	var hang := float(data()["hang"])
	_marker(0.5 * minf(t / hang, 1.0))
	if h.roll_t > 0.0:
		return
	var over := clampf(dt / maxf(hang - t, dt), 0.0, 1.0)
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
		k.m.sfx("juggernaut_dash", h.pos, -3.0, 0.7)

## The dive: straight down onto the marker, accelerating (seen all the way, not a teleport), flame streaks rising
## off him.
func _tick_dive() -> void:
	var h := k.h
	var u := clampf(t / dive_t, 0.0, 1.0)
	var e := clampf(u / CLOSE, 0.0, 1.0)         # over the spot already, unless an air dash took him off it
	var at := Vector3(lerpf(from.x, land.x, e), lerpf(from.y, land.y, u * u), lerpf(from.z, land.z, e))
	h.vel = Vector3.ZERO
	h.teleport(at)
	_marker(0.5 + 0.5 * u)
	if k.tells_visible():
		k.m.fx.spark(h.pos + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3)), Vector3.UP, STREAK, 2, 7.0,
				12.0, 0.25, 0.0, 1.0)
		k.m.fx.spark(h.pos + Vector3(0, 1.2, 0), Vector3.UP, STREAK_HOT, 1, 5.0, 8.0, 0.2, 0.0, 0.8)
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
	k.run(stg, k.cx("rmb", "meteor_drop", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f) or f.dead: return
		if stunned_at(f.pos, f.r, at):
			f.hurt(float(dd["dmg"]) * k.smash_k() * float(dd["core_k"]) * k.power("sec"), k.h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "meteor_core"], "stun": float(dd["stun"]),
							"dr": true})
			k.m.fx.word(f.pos + Vector3(0, 2.3, 0), "CRUSHED", k.res_col(), false)}))

## True when a body of radius `r` at `p` touches the stun core (the ring drawn on impact) of a slam at `at`.
func stunned_at(p: Vector3, r: float, at: Vector3) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() < float(data()["core"]) + r

## The landing: a crack in the ground, the shock ring at the stun's edge, dust and debris, a shake, the boom.
func _impact_fx(at: Vector3) -> void:
	var dd := data()
	var m := k.m
	last_shock_r = float(dd["core"])
	m.fx.ring(at, last_shock_r, CORE, 0.45)
	_crack(at)
	m.fx.dust(at, 22)
	m.fx.burst(at + Vector3(0, 0.3, 0), DEBRIS, 18, 6.5, 0.7, 16.0, 1.1, Vector3.UP, 55.0)
	m.sfx("jug_meteor", at, 0.0, 1.0)
	m.sfx("jug_slam_hit", at, -5.0, 0.8)
	Shake.incoming_big(m, at, 0.5, k.h)
	k.net_ring(at, last_shock_r, CORE)

## The crack in the ground: dark jagged fissures of uneven length running out of the impact, kinking as
## they go, toward the damage area's edge (tapering pieces).
func _crack(at: Vector3) -> void:
	if not k.tells_visible():
		return
	if cracks == null or not is_instance_valid(cracks):
		cracks = k.own_node()
		crack_mat = StandardMaterial3D.new()
		crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		crack_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		crack_mat.albedo_color = CRACK
		for i in CRACK_N * CRACK_SEGS:
			var seg := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.orientation = PlaneMesh.FACE_Y
			seg.mesh = q
			seg.material_override = crack_mat
			cracks.add_child(seg)
	cracks.global_position = at + Vector3(0, 0.03, 0)
	var reach := float(data()["radius"]) * 0.85
	for i in CRACK_N:
		var a := TAU * float(i) / float(CRACK_N) + randf_range(-0.3, 0.3)
		var from := Vector3(cos(a), 0, sin(a)) * 0.25
		var out := randf_range(0.3, 1.0) * reach
		for j in CRACK_SEGS:
			a += randf_range(-0.8, 0.8)
			var to := from + Vector3(cos(a), 0, sin(a)) * out / float(CRACK_SEGS) * randf_range(0.6, 1.4)
			_crack_seg(cracks.get_child(i * CRACK_SEGS + j) as MeshInstance3D, from, to, 0.18 - 0.04 * j)
			from = to
	crack_t = CRACK_T
	crack_mat.albedo_color.a = 0.7
	cracks.visible = true

func _crack_seg(seg: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	(seg.mesh as QuadMesh).size = Vector2(width, a.distance_to(b) + width * 0.5)
	seg.position = (a + b) * 0.5
	seg.rotation = Vector3(0, atan2(b.x - a.x, b.z - a.z), 0)
