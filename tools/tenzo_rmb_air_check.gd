extends "res://tools/hero_pair_check.gd"
## --tenzo-rmb-air-check: Tenzo's Quakefall (RMB) from every footing. Owner 11-26: 'still feels buggy, especially
## from the air'. Each case presses RMB from the ground (tap, hold), at a jump's apex, while falling, at a run's
## apex, while gliding, off a 1.6m ledge, up onto a 0.8m terrace, and into a wall, then logs the run: the path, the
## end, the time until he can move again, the largest one-step jump of the body (a snap), the time spent stuck,
## the slams and hits it dealt, his facing against the aim, the clips it played, and any frame under the floor.
## The asserts: one slam and at most one hit per press, no snap, never under the floor, never stuck in the air,
## control back within CONTROL_MAX, facing the aim; an air press glides down onto the cursor's spot clamped to
## AIR_REACH (lands within LAND_TOL of it), never straight down and never faster than the plunge cap.

const CONTROL_MAX := 1.3  # s from the press until the move keys move him again (the slowest: a hop off a ledge)
const SNAP_MAX := 0.6  # m: the most the body may move in one 60 Hz step (26 m/s plunge = 0.43 m)
const LAND_TOL := 0.9  # m: an air press lands this close to its clamped target
const FACE_TOL := 0.35  # rad: his facing against the aim at the end
const AIM_AT := 4.0  # m ahead of the start the cursor sits

var m: Match
var hero: Hunter
var kit: DolmKit
var dummy: Hunter
var home: Vector3
var lv := 0
var rows: Array = []


func run(main_node: Node) -> void:
	main = main_node
	var r := setup("dolm", 30.0)
	m = r[0]
	hero = r[1]
	kit = hero.ak
	dummy = r[2]
	home = r[3]
	lv = r[4]
	for c in [
		"ground_tap",
		"ground_hold",
		"apex",
		"falling",
		"run_apex",
		"glide",
		"ledge",
		"terrace_hold",
		"terrace_air",
		"wall_hold",
		"wall_air",
		"air_hit"
	]:
		_case(c)
	for row in rows:
		print("TENZO-RMB %s" % row)
	print("PAIRCHECK tenzo-rmb-air DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## The strip back to flat ground at the start's level, then the case's own shape: a 1.6m ledge under the start,
## a 0.8m terrace from 2.5m ahead, or a wall of blocks 2m ahead.
func _layout(shape: String) -> void:
	var w: World = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-12, 13):
		for dx in range(-8, 26):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			if shape == "ledge" and dx <= 0:
				w.level[i] = lv + 2
			elif shape.begins_with("terrace") and dx >= 2:
				w.level[i] = lv + 1
			elif shape.begins_with("wall") and dx == 2 and absi(dz) <= 4:
				w.kind[i] = World.T_BLOCK
	w._aref = PackedFloat32Array()


func _reset(shape: String) -> void:
	_layout(shape)
	hero.teleport(home + Vector3(0, 2 * World.LEVEL if shape == "ledge" else 0.0, 0))
	hero.vel = Vector3.ZERO
	hero.gliding = false
	hero.glide_fuel = 1.0
	hero.glide_cd = 0.0
	hero.roll_t = 0.0
	hero.fly_t = 0.0
	hero.stun_t = 0.0
	hero.hp = hero.max_hp
	kit.drop_holds()
	kit.ch_rmb = 1.0
	kit.cd["rmb"] = 0.0
	for key in ["fire", "sec_hold", "jump", "glide", "crouch"]:
		hero.inp[key] = false
	hero.inp["move"] = Vector2.ZERO
	dummy.teleport(home + Vector3(30, 0, 0))
	fresh(dummy)
	step(m, 0.25)
	hero.face = atan2(-1.0, 0.0)
	aim_at(hero, home + Vector3(AIM_AT, 0, 0))


func _jump() -> void:
	hero.inp["jump"] = true
	m.step(DT)


## Steps until he stops rising (the apex), up to 1s.
func _to_apex() -> void:
	var t := 0.0
	while hero.vel.y > 0.0 and t < 1.0:
		m.step(DT)
		t += DT


func _case(c: String) -> void:
	var shape := "flat"
	if c == "ledge":
		shape = "ledge"
	elif c.begins_with("terrace"):
		shape = "terrace"
	elif c.begins_with("wall"):
		shape = "wall"
	_reset(shape)
	if c == "air_hit":
		dummy.teleport(home + Vector3(AIM_AT, 0, 0))
		fresh(dummy)
	match c:
		"ground_tap", "ground_hold", "terrace_hold", "wall_hold":
			pass
		"apex", "air_hit", "terrace_air", "wall_air":
			_jump()
			_to_apex()
		"falling":
			_jump()
			_to_apex()
			step(m, 0.15)
		"run_apex":
			hero.inp["move"] = Vector2(1, 0)
			step(m, 0.3)
			_jump()
			_to_apex()
			hero.inp["move"] = Vector2.ZERO
		"glide":
			hero.teleport(home + Vector3(0, 6.0, 0))
			hero.inp["glide"] = true
			step(m, 0.4, func(): hero.inp["glide"] = true)
			hero.inp["glide"] = false
		"ledge":
			hero.inp["move"] = Vector2(1, 0)
			var t := 0.0
			while hero.grounded and t < 1.0:
				m.step(DT)
				t += DT
			step(m, 0.05)
			hero.inp["move"] = Vector2.ZERO
	var start := hero.pos
	var was_air := not hero.grounded
	if was_air:
		aim_at(hero, Vector3(start.x + AIM_AT, home.y, start.z))
	var aim: Vector3 = hero.inp["aim"]
	var slams0 := kit.slams
	var hits := [0]
	var hp := [dummy.hp]
	var snap := [0.0]
	var under := [0]
	var stuck := [0.0]
	var path: Array = []
	var clips: Array = []
	var ring := [Vector2.INF]  # where the circle first showed the landing once the press was let go
	var note := func():
		if kit.anim_id != "" and (clips.is_empty() or clips[-1] != kit.anim_id):
			clips.append(kit.anim_id)
	var watch := func(was: Vector3, t: float):
		snap[0] = maxf(snap[0], hero.pos.distance_to(was))
		var g := m.world.ground_at(hero.pos.x, hero.pos.z)
		if g > World.VOID + 1.0 and hero.pos.y < g - 0.05:
			under[0] += 1
		if not hero.grounded and was.distance_to(hero.pos) < 0.001:
			stuck[0] += DT
		if dummy.hp < hp[0] - 0.01:
			hits[0] += 1
		hp[0] = dummy.hp
		var e := AimKit.entry(hero, "rmb")
		if e.has("at") and ring[0] == Vector2.INF:
			ring[0] = e["at"]
		if int(t / DT) % 6 == 0:
			path.append("%.1f,%.1f" % [hero.pos.x - home.x, hero.pos.y - home.y])
		note.call()
	if c.ends_with("hold"):
		hold(m, hero, 0.45)
	else:
		tap(m, hero)
	note.call()
	# no keys: the move runs its course; control is back once he is down, the move is over and a key moves him
	var t := 0.0
	var back := -1.0
	var was := hero.pos
	while t < 3.0:
		var free: bool = hero.grounded and not kit.dive and kit.slam.wind_t < 0.0 and not kit.slam.hop_on
		if free and back < 0.0:
			back = t
		m.step(DT)
		t += DT
		watch.call(was, t)
		was = hero.pos
		if back >= 0.0 and t > back + 0.3:
			break
	var land := hero.pos
	var want := aim - start
	var reach := float(kit.slam.feel()["air_reach"])
	var target := Vector2(start.x, start.z) + Vector2(want.x, want.z).limit_length(reach)
	if c == "wall_air":
		target.x = minf(target.x, home.x + 1.5 - hero.r)
	var miss := Vector2(land.x, land.z).distance_to(target)
	var ad := hero.aim_dir()
	var ring_off := -1.0
	if ring[0] != Vector2.INF:
		ring_off = Vector2(land.x, land.z).distance_to(ring[0])
	var face_err := absf(angle_difference(hero.face, atan2(-ad.x, -ad.y)))
	var slammed := kit.slams - slams0
	var row := (
		(
			"%-12s air %-5s end (%.1f, %.1f) travel %.1fm miss %.2fm circle %.2fm control %.2fs snap %.2fm"
			+ " stuck %.2fs slams %d hits %d face %.2f under %d clips %s path %s"
		)
		% [
			c,
			was_air,
			land.x - home.x,
			land.y - home.y,
			Vector2(land.x - start.x, land.z - start.z).length(),
			miss,
			ring_off,
			back,
			snap[0],
			stuck[0],
			slammed,
			hits[0],
			face_err,
			under[0],
			"/".join(clips),
			" ".join(path)
		]
	)
	rows.append(row)
	var bad: Array = []
	if slammed != 1:
		bad.append("slams %d" % slammed)
	if hits[0] > 1:
		bad.append("hits %d" % hits[0])
	if c == "air_hit" and hits[0] != 1:
		bad.append("air slam missed the foe on its spot")
	if snap[0] > SNAP_MAX:
		bad.append("snap %.2fm" % snap[0])
	if under[0] > 0:
		bad.append("under the floor %d frames" % under[0])
	if stuck[0] > 0.1:
		bad.append("stuck %.2fs" % stuck[0])
	if back < 0.0 or back > CONTROL_MAX:
		bad.append("control %.2fs" % back)
	if face_err > FACE_TOL:
		bad.append("facing off %.2f" % face_err)
	if c != "ground_tap" and not (ring_off >= 0.0 and ring_off < LAND_TOL):
		bad.append("landed %.2fm from the circle" % ring_off)
	if was_air and miss > LAND_TOL:
		bad.append("landed %.2fm off its spot" % miss)
	if c == "terrace_air" and land.y < home.y + World.LEVEL - 0.05:
		bad.append("short of the terrace it aimed at")
	ok("rmb %s" % c, bad.is_empty(), ", ".join(bad))
