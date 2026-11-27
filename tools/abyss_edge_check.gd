extends RefCounted
## --abyss-edge-check: the abyss fall, the abyss mantle launch and the edge pop against the reference's own
## laws (docs/MOVEMENT_FEEL.d/1127-abyss-edge-parity.md). A real match hunter is dropped beside an island's side
## at three depths and pops off the edge at three approach speeds (keys into the island); each run prints the
## launch velocity, apex over the lip, landing distance past the lip, contact-to-landing time and speed at
## landing, next to a small simulation of the reference's law (its numbers below, written in here, never read
## from our rules). Also the free fall from the lip to the point of no return and the glider's lift out.
## Launch speed, apex, fall time and lift time must match within TOL. Landing distance, air time and the speed
## you keep also depend on air steering, which is an owner ruling (ours ~4x the reference's), so they're shown,
## not judged. Counts fixed steps, never touches the save. Prints "AEDGE ..." and "AEDGE DONE, failures: N".

const TOL := 0.05
const DT := 1.0 / 60.0
const G := 14.7  # m/s^2 gravity (both)
# the reference, in metres (uu / 100)
const LAUNCH := Vector2(9.0, 25.5)  # m/s up, lip 0 to DEPTH m above the feet
const DEPTH := 17.5  # m, also the point of no return under the lip
const MINI_H := 3.0  # m, lower lips are a mini mantle
const MINI_BONUS := 5.0  # m/s more up on a mini mantle
const WAIT := Vector2(0.1, 0.25)  # s held before a full launch, rising at this x the speed you came in with
# mini mantle: s, keep, min m/s (body scale), push /s, soft cap m/s, pull down /s, its fade
const MINI := [0.75, 0.6, 3.5 * 1.16, 8.0, 2.0, 5.0, 0.35]
const AIR := 7.5 * 1.16  # m/s^2 air steering, capped at run speed (body scale)
const FALL_KEYS := [
	[0.0, 0.0], [0.1, 0.0099], [0.25, 0.0629], [0.5, 0.2541], [0.75, 0.5755], [1.0, 1.0]
]
const LIFT := [10.0, 40.0, 20.0, 15.5]  # glider under the lip: m/s^2 from, to, over m deeper; m/s cap

var bad := 0
var m: Match
var w: World
var h: Hunter


func ok(cond: bool, what: String) -> void:
	print("AEDGE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(absf(b) * TOL, 0.05)


## A clean straight rim with open void out from it: {ex, ez (the last ground before the void), dir (out), top}.
func _rim() -> Dictionary:
	for k in 8000:
		var g := w.random_ground()
		var gi := w.idx(int(floor(g.x)), int(floor(g.z)))
		if w.is_void(g.x, g.z) or w.sheer.has(gi):
			continue
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var open := true
			for dd in [1.2, 2.0, 3.0, 4.5, 6.0]:
				for s in [-1.5, 0.0, 1.5]:
					if not w.is_void(g.x + d.x * dd + d.y * s, g.z + d.y * dd + d.x * s):
						open = false
			var top := w.ground_at(g.x, g.z)
			for s in [-2.0, -1.0, 1.0, 2.0]:
				if absf(w.ground_at(g.x + d.y * s, g.z + d.x * s) - top) > 0.05:
					open = false
			for back in [1.0, 2.0, 3.0, 4.0, 5.0]:
				if (
					absf(w.ground_at(g.x - d.x * back, g.z - d.y * back) - top) > 0.05
					or w.is_block(g.x - d.x * back, g.z - d.y * back)
				):
					open = false
			if not open:
				continue
			var ex := g.x
			var ez := g.z
			while not w.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
				ex += d.x * 0.25
				ez += d.y * 0.25
			if w.sheer.has(w.idx(int(floor(ex)), int(floor(ez)))):
				continue
			return {"ex": ex + d.x * 0.125, "ez": ez + d.y * 0.125, "dir": d, "top": top}
	return {}


func _reset(at: Vector3, v: Vector3, gy: float) -> void:
	h.out = false
	h.gone = false
	h.downed = false
	h.teleport(at)
	h.grounded = false
	h.vel = v
	h.pad = {}
	h.lfloat = {}
	h.grap = {}
	h.grap_cd = 0.0
	h.mantle_cd = 0.0
	h.roll_t = 0.0
	h.gliding = false
	h.glide_fuel = 1.0
	h.glide_cd = 0.0
	h.knock_t = 0.0
	h.stun_t = 0.0
	h.kb_t = -9.0
	h.shot_down = false
	h.air_t = 0.3
	h.carry_v = Vector2(v.x, v.z).length()
	h.carry_dir = Vector2(v.x, v.z).normalized()
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	h.inp["jump"] = false
	h.inp["dash"] = false
	h.hp = h.max_hp
	h.last_gy = gy  # (where you last stood: the rim)


## Ours: from just under the lip of rim e, `lip_h` metres down, coming in at v_in m/s (and falling at vy0),
## keys into the island. Returns {vz (launch up speed), vxy (launch sideways), apex, land, t, v_land, v_after}.
func _ours(e: Dictionary, lip_h: float, v_in: float, vy0: float) -> Dictionary:
	var dir: Vector2 = e["dir"]
	var top: float = e["top"]
	var start := Vector3(
		e["ex"] + dir.x * (h.r + 0.25), top - lip_h, e["ez"] + dir.y * (h.r + 0.25)
	)
	_reset(start, Vector3(-dir.x * v_in, vy0, -dir.y * v_in), top)
	var r := {
		"depth": lip_h,
		"vz": 0.0,
		"vxy": Vector3.ZERO,
		"apex": -lip_h,
		"land": -9.0,
		"t": 9.0,
		"v_land": 0.0,
		"v_after": 0.0
	}
	var t := 0.0
	var launched := false
	var contact := -1.0
	var landed_t := -1.0
	var last_vy := h.vel.y
	while t < 4.0:
		h.inp["move"] = -dir
		m.step(DT)
		t += DT
		if h.out or h.gone:
			r["t"] = -1.0
			break
		# the contact (the mantle cooldown starts; how deep you were then sets the launch)
		if contact < 0.0 and h.mantle_cd > 0.5:
			contact = t
			r["depth"] = top - h.pos.y
		# the launch: the first step rising far faster than the step before (a jump-sized kick)
		if not launched and h.vel.y - last_vy > 4.0 and h.vel.y > 6.0:
			launched = true
			r["vz"] = h.vel.y + (G * DT if t > contact else 0.0)  # (a held launch's step took its gravity)
			r["vxy"] = Vector3(h.vel.x, 0.0, h.vel.z)
		last_vy = h.vel.y
		r["apex"] = maxf(float(r["apex"]), h.pos.y - top)
		if landed_t < 0.0 and h.grounded:
			landed_t = t
			r["t"] = t
			r["land"] = (Vector2(e["ex"], e["ez"]) - Vector2(h.pos.x, h.pos.z)).dot(dir)
			r["v_land"] = Vector2(h.vel.x, h.vel.z).length()
		if landed_t >= 0.0 and t - landed_t >= 0.25:
			r["v_after"] = Vector2(h.vel.x, h.vel.z).length()
			break
	return r


## The reference's law, the same start: launch, mini push, pull-down over the top, air steering at AIR to run speed;
## the side blocks you (no sideways speed) until your feet are over the lip.
func _ref(lip_h: float, v_in: float, run_v: float, x0: float) -> Dictionary:
	var is_mini := lip_h < MINI_H
	var vz := (
		lerpf(LAUNCH.x, LAUNCH.y, clampf(lip_h / DEPTH, 0.0, 1.0))
		+ (MINI_BONUS if is_mini else 0.0)
	)
	var z := -lip_h
	var x := x0
	var vx := 0.0
	var t := 0.0
	var r := {"vz": vz, "apex": z, "land": -9.0, "t": 9.0, "v_land": 0.0}
	if not is_mini:
		z += WAIT.y * v_in * WAIT.x
		t += WAIT.x
	var goal0 := maxf(v_in * MINI[1], MINI[2])
	var cleared := false
	var s := 0.0
	while s < 4.0:
		s += DT
		var p := clampf(s / MINI[0], 0.0, 1.0)
		if is_mini and s <= MINI[0]:
			var goal := (1.0 - 0.5 * p) * goal0
			if vx < goal:
				vx += (goal - vx) * MINI[3] * DT
			if z > 0.0 and vz > MINI[4]:
				vz -= (vz - MINI[4]) * MINI[5] * (1.0 - MINI[6] * p) * DT
		if vx < run_v:
			vx = minf(vx + AIR * DT, run_v)
		z += (vz - 0.5 * G * DT) * DT
		vz -= G * DT
		x += vx * DT
		if z >= 0.0:
			cleared = true
		if not cleared and x > x0:
			x = x0  # the island's side: the body slides up it until the feet clear the lip, as ours (and UE's) does
			vx = 0.0
		r["apex"] = maxf(float(r["apex"]), z)
		if vz < 0.0 and z <= 0.0 and x > 0.0:
			r["land"] = x
			r["t"] = t + s
			r["v_land"] = vx
			break
	return r


## The reference's fall from the lip to the point of no return (s): its speed cap 12 easing to 10 m/s, 1 to 16.5 m down.
func _ref_fall_t() -> float:
	var z := 0.0
	var vz := 0.0
	var t := 0.0
	while z > -DEPTH:
		t += DT
		var u := clampf((-z - 1.0) / 15.5, 0.0, 1.0)
		var c := 0.0
		for i in FALL_KEYS.size() - 1:
			var a: Array = FALL_KEYS[i]
			var b: Array = FALL_KEYS[i + 1]
			if u >= a[0] and u <= b[0]:
				c = lerpf(a[1], b[1], (u - a[0]) / (b[0] - a[0]))
		var cap := lerpf(12.0, 10.0, c) if -z >= 1.0 else 12.0
		var nvz := maxf(vz - G * DT, -cap)
		z += 0.5 * (vz + nvz) * DT
		vz = nvz
	return t


## The reference glider's lift from `depth` under the lip with no fall (s to the lip).
func _ref_lift_t(depth: float) -> float:
	var z := -depth
	var vz := 0.0
	var t := 0.0
	while z < 0.0 and t < 9.0:
		t += DT
		var acc := lerpf(LIFT[0], LIFT[1], clampf(-z / LIFT[2], 0.0, 1.0)) - 0.025 * G
		vz = minf(vz + acc * DT, LIFT[3])
		z += vz * DT
	return t


func _row(what: String, o: Dictionary, rf: Dictionary) -> void:
	var v: Vector3 = o["vxy"]
	print("AEDGE %s: caught %.2fm under the lip" % [what, o["depth"]])
	print(
		(
			"AEDGE %s ours: launch (%.2f, %.2f, %.2f) apex %.2fm land %.2fm in in %.2fs at %.2f m/s, %.2f m/s 0.25s on"
			% [what, v.x, o["vz"], v.z, o["apex"], o["land"], o["t"], o["v_land"], o["v_after"]]
		)
	)
	print(
		(
			"AEDGE %s ref:  launch (0.00, %.2f, 0.00) apex %.2fm land %.2fm in in %.2fs at %.2f m/s (air %.1f m/s^2)"
			% [what, rf["vz"], rf["apex"], rf["land"], rf["t"], rf["v_land"], AIR]
		)
	)
	ok(
		_near(float(o["vz"]), float(rf["vz"])),
		"%s: launch %.2f vs %.2f m/s" % [what, o["vz"], rf["vz"]]
	)
	var d := float(o["depth"])
	ok(
		_near(float(o["apex"]) + d, float(rf["apex"]) + d),
		(
			"%s: apex %.2f vs %.2f m over the catch"
			% [what, float(o["apex"]) + d, float(rf["apex"]) + d]
		)
	)
	ok(float(o["land"]) > 0.0, "%s: lands on the island (%.2f m past the lip)" % [what, o["land"]])


func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 77,
			"no_drop": true,
			"autoplay": true
		}
	)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h:
			o.teleport(w.random_ground())
	h.ctrl = "local"
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	var e := _rim()
	ok(not e.is_empty(), "found an open straight rim")
	if e.is_empty():
		_done(main)
		return
	var x0 := -(h.r + 0.25)
	# the abyss catch at three depths: falling at the speed that depth brings, drifting in at 3 m/s
	for depth in [1.5, 8.0, 16.0]:
		var vy0 := -minf(sqrt(2.0 * G * depth), 12.0)
		var o := _ours(e, depth, 3.0, vy0)
		_row("abyss %.1fm" % depth, o, _ref(o["depth"], 3.0, h.base_speed, x0))
	# the edge pop (a mini mantle) 0.5 m under the lip at three approach speeds
	for v_in in [2.0, 5.0, 9.0]:
		var o := _ours(e, 0.5, v_in, -2.0)
		_row("edge pop %.0f m/s" % v_in, o, _ref(o["depth"], v_in, h.base_speed, x0))
	_suction(e)
	var cd := h.mantle_cd
	print("AEDGE mantle cooldown left at the end of the last run: %.2fs" % cd)
	# the free fall from the lip, far from any side: time to the point of no return
	var dir: Vector2 = e["dir"]
	var out_at := Vector3(e["ex"] + dir.x * 4.5, float(e["top"]) - 0.01, e["ez"] + dir.y * 4.5)
	_reset(out_at, Vector3.ZERO, float(e["top"]))
	var t := 0.0
	var lost := -1.0
	var kill_d := 0.0
	while t < 5.0 and lost < 0.0:
		kill_d = float(e["top"]) - h.abyss_kill_y()
		m.step(DT)
		t += DT
		if h.out or h.gone or h.pos.distance_to(out_at) > 30.0:
			lost = t
	var rft := _ref_fall_t()
	ok(_near(kill_d, DEPTH), "point of no return %.2f m under the lip (ref %.1f)" % [kill_d, DEPTH])
	ok(
		lost > 0.0 and _near(lost, rft),
		"off the lip to the point of no return in %.2fs (ref %.2fs)" % [lost, rft]
	)
	# the glider's lift from three depths out in the open
	for depth in [3.0, 8.0, 14.0]:
		_reset(out_at - Vector3(0.0, depth, 0.0), Vector3.ZERO, float(e["top"]))
		h.gliding = true
		var lt := 0.0
		var top_vy := 99.0
		while lt < 6.0:
			h.inp["glide"] = true
			m.step(DT)
			lt += DT
			if h.pos.y >= float(e["top"]) or h.out:
				break
		for i in 10:
			h.inp["glide"] = true
			m.step(DT)
		top_vy = h.vel.y
		var rl := _ref_lift_t(depth)
		ok(
			not h.out and _near(lt, rl),
			"glider from %.0fm under the lip: at the lip in %.2fs (ref %.2fs)" % [depth, lt, rl]
		)
		ok(
			top_vy <= 0.5,
			"...and the lift lets go at its top (%.2f m/s up 10 steps later, ref 0)" % top_vy
		)
	_done(main)


## The wall suction vs the reference law: the pull per step at three distances from a head-on side (and the
## upward pull just under its top), none at a glance, gliding or on cooldown; then a live drift in from 2.2 m.
func _suction(e: Dictionary) -> void:
	var dir: Vector2 = e["dir"]
	var top: float = e["top"]
	var ex: float = e["ex"]
	var ez: float = e["ez"]
	# the island side's plane along dir (the edge cell's outer boundary)
	var face := Vector2(ex, ez) - dir * 0.2
	var fx := floorf(face.x) + (1.0 if dir.x > 0.0 else 0.0)
	var fz := floorf(face.y) + (1.0 if dir.y > 0.0 else 0.0)
	var face_at := Vector2(fx if dir.x != 0.0 else ex, fz if dir.y != 0.0 else ez)
	var bs := HunterMove.body_scale
	var fc := [1.0, 0.7513, 0.4623, 0.248, 0.1075, 0.0]
	var uc := [1.0, 0.9909, 0.9609, 0.771, 0.3166, 0.0]
	for dist in [0.75, 1.75, 2.4]:
		var at: Vector2 = face_at + dir * float(dist)
		_reset(Vector3(at.x, top - 4.0, at.y), Vector3.ZERO, top)
		var hv := -dir * 4.5
		var got: float = (MantleCarry.suction(h, hv, DT) - hv).dot(-dir) / DT
		var want := (
			lerpf(2.5, 20.0, MantleCarry._curve(fc, clampf((dist - 0.5) / 2.5, 0.0, 1.0))) * bs
		)
		ok(
			_near(got, want),
			(
				"suction %.2fm from a side at 4.5 m/s: pulled in at %.2f m/s^2 (ref %.2f)"
				% [dist, got, want]
			)
		)
	var at2 := face_at + dir * 1.0
	_reset(Vector3(at2.x, top - 1.0, at2.y), Vector3(0.0, -1.0, 0.0), top)
	MantleCarry.suction(h, -dir * 4.5, DT)
	var up := (h.vel.y + 1.0) / DT
	var up_want := lerpf(25.0, 175.0, 1.0 / 1.5) * MantleCarry._curve(uc, 0.5)
	ok(
		_near(up, up_want),
		"1 m under the top, 1 m from it: pulled up at %.2f m/s^2 (ref %.2f)" % [up, up_want]
	)
	var glance := (-dir).rotated(deg_to_rad(55.0)) * 4.5
	_reset(Vector3(at2.x, top - 4.0, at2.y), Vector3.ZERO, top)
	ok(
		MantleCarry.suction(h, glance, DT) == glance,
		"a side met 55 degrees off: no pull (ref: head-on within 40)"
	)
	h.gliding = true
	ok(MantleCarry.suction(h, -dir * 4.5, DT) == -dir * 4.5, "gliding: no pull")
	h.gliding = false
	h.mantle_cd = 0.5
	ok(MantleCarry.suction(h, -dir * 4.5, DT) == -dir * 4.5, "mantle cooldown running: no pull")
	# live: drifting in at 1.5 m/s from 2.2 m out, 4 m under the top, keys idle
	var live := face_at + dir * 2.2
	_reset(Vector3(live.x, top - 4.0, live.y), Vector3(-dir.x * 1.5, -2.0, -dir.y * 1.5), top)
	var t := 0.0
	var caught := -1.0
	while t < 2.0 and caught < 0.0:
		m.step(DT)
		t += DT
		if h.mantle_cd > 0.5:
			caught = t
	print("AEDGE suction live: drifting in at 1.5 m/s from 2.2 m out, caught after %.2fs" % caught)
	ok(caught > 0.0, "a slow drift toward a side over the abyss is pulled in and caught")


func _done(main: Node) -> void:
	print("AEDGE DONE, failures: ", bad)
	main.get_tree().quit()
