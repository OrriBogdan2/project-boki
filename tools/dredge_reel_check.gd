extends RefCounted
## The Deep Reach reel against the source, for --dredge-combo-check (docs/heroes/dredge.md, "Reel parity"):
## the arm's reach, the reel's speed curve, where the body stops, what the reeled foe can do,
## what Grimble can do while he reels, and what a miss costs. One row of the doc's table per assert.

const BH := 1.8  # m in one body height of the footage (briefs/hero-ref/linwick.md scale)
const REEL_SPD := 5.0 * BH  # m/s the reel hauls: about 5 bh/s (frames 124-129)
const CATCH := 9.0  # m: the foe's start, the footage's 5 bh catch
const REEL_T := 1.0  # s the footage's 5 bh reel takes, grab to arrival (frames 124-129)
const SNUG := 0.3  # m of air at most between the bodies at the stop ("adjacent", 0130)

var ak = null
var ok_fn: Callable


func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb


func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)


func run() -> void:
	await _reel()
	await _tap()
	await _miss()


## A foe 9 m out: the arm's out-speed, the reel's curve and time, the stop, and what both sides can do meanwhile.
func _reel() -> void:
	var r: Array = ak.setup("dredge", CATCH)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var k: DredgeKit = p.ak
	t_v.set_arch("gunslinger")
	t_v.unlock_all()
	t_v.dashes = t_v.max_dashes()
	ak.aim_at(p, t_v.pos)
	ak.tap(m, p)
	var out_spd := 0.0  # the hook's step per frame while it flies (its launch point is off his hand)
	var t := 0.0
	while k.pull.is_empty() and t < 1.0:
		var at0: Vector3 = k.hook_sd.get("pos", Vector3.ZERO)
		m.step(ak.DT)
		t += ak.DT
		if k.flying and not k.hook_sd.is_empty():
			out_spd = Vector2(k.hook_sd["pos"].x - at0.x, k.hook_sd["pos"].z - at0.z).length() / ak.DT
	ok(
		"reel parity: the arm reaches out at rmb.speed (the owner's note, not the footage)",
		not k.pull.is_empty() and absf(out_spd - float(k.rmb_def()["speed"])) < 1.0,
		"%.1f m/s, caught %.2f s after the tap" % [out_spd, t]
	)
	# the reel: its speed each frame, and whether the foe or Grimble could act
	var from := Vector2(t_v.pos.x - p.pos.x, t_v.pos.z - p.pos.z).normalized()
	var speeds: Array = []
	var stun_min := 99.0
	var tr := 0.0
	var acted := false
	var jumped := false
	var dash0 := t_v.dashes
	var shots0 := t_v.shot_n
	while not k.pull.is_empty() and tr < 3.0:
		var d := p.flat_dist(t_v)
		stun_min = minf(stun_min, t_v.stun_t)
		t_v.inp["fire"] = true
		t_v.do_jump()
		t_v.do_dash()
		t_v.ak.press_rmb()
		t_v.ak.use_e()
		p.do_jump()
		jumped = jumped or p.vel.y > 0.5 or not p.grounded
		acted = acted or k.cast_ult() or k.broadside.running()
		m.step(ak.DT)
		tr += ak.DT
		speeds.append((d - p.flat_dist(t_v)) / ak.DT)
	t_v.inp["fire"] = false
	var top: float = speeds.max() if not speeds.is_empty() else 0.0
	var first: float = speeds[0] if not speeds.is_empty() else 0.0
	ok("reel parity: the reel hauls at the footage's ~9 m/s (5 bh/s)", absf(top - REEL_SPD) < 1.0, "%.1f m/s" % top)
	ok(
		"reel parity: full speed from the grab frame, no ease-in (frames 124-129 even)",
		first >= top * 0.9,
		"first frame %.1f of %.1f m/s" % [first, top]
	)
	ok("reel parity: a 5 bh catch arrives in about 1 s", k.arrivals == 1 and absf(tr - REEL_T) < 0.15, "%.2f s" % tr)
	var air := p.flat_dist(t_v) - p.r - t_v.r
	var at := Vector2(t_v.pos.x - p.pos.x, t_v.pos.z - p.pos.z).normalized()
	var off_line := rad_to_deg(at.angle_to(from))
	var off_face := rad_to_deg(at.angle_to(Vector2(-sin(p.face), -cos(p.face))))
	ok(
		"reel parity: the body stops adjacent (bodies all but touching)",
		air >= -0.05 and air <= SNUG,
		"%.2f m between them" % air
	)
	ok(
		"reel parity: ... in front of him, on the line it was reeled along",
		absf(off_line) < 15.0 and absf(off_face) < 30.0,
		"%.0f deg off the reel line, %.0f off his facing" % [off_line, off_face]
	)
	ok(
		"reel parity: the foe is stunned the whole reel and can't jump, dash, cast or shoot",
		(
			stun_min > 0.0
			and t_v.dashes == dash0
			and float(t_v.ak.cd.get("rmb", 0.0)) <= 0.0
			and float(t_v.ak.cd.get("e", 0.0)) <= 0.0
			and t_v.shot_n == shots0
			and t_v.pos.y < p.pos.y + 0.3
		),
		"stun min %.2f, dashes %.0f/%.0f, shots %d" % [stun_min, t_v.dashes, dash0, t_v.shot_n - shots0]
	)
	ok(
		"reel parity: he arrives stunned, not Grounded (data over the wiki), free within 0.3 s",
		t_v.stun_t > 0.0 and not KitStatus.grounded(t_v),
		"stun %.2f" % t_v.stun_t
	)
	ak.step(m, 0.3)
	ok("reel parity: ... and acts again after it", t_v.stun_t <= 0.0, "stun %.2f" % t_v.stun_t)
	ok("reel parity: Grimble can't jump or start the X while he reels", not jumped and not acted)
	await ak.done(m)


## LMB tapped 0.2 s into the 1 s reel: the gun stays locked, and the tap fires one volley within a step of the
## arrival (DECISIONS: every interaction is chainable; no press is lost), not a stream.
func _tap() -> void:
	var r: Array = ak.setup("dredge", CATCH)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var k: DredgeKit = p.ak
	p.ammo = int(p.wpn["mag"])
	ak.aim_at(p, t_v.pos)
	ak.tap(m, p)
	var t := 0.0
	while k.pull.is_empty() and t < 1.5:
		m.step(ak.DT)
		t += ak.DT
	var shots0 := p.shot_n
	var tap_at := roundi(0.2 / ak.DT)  # the step 0.2 s into the reel
	var n := 0
	var tr := 0.0
	var mid := 0
	while not k.pull.is_empty() and tr < 3.0:
		p.inp["fire"] = n == tap_at
		m.step(ak.DT)
		n += 1
		tr += ak.DT
		if not k.pull.is_empty():
			mid = p.shot_n - shots0
	p.inp["fire"] = false
	var steps := 0
	while p.shot_n == shots0 + mid and steps < 10:
		m.step(ak.DT)
		steps += 1
	ak.step(m, 0.6)
	ok(
		"reel: an LMB tapped 0.2 s into a 1 s reel fires one volley within one step of the arrival",
		k.arrivals == 1 and mid == 0 and steps <= 1 and p.shot_n - shots0 == 1,
		"reel %.2f s, shots mid-reel %d, fired %d step(s) after it, shots %d" % [tr, mid, steps, p.shot_n - shots0]
	)
	await ak.done(m)


## A miss: the arm flies its full 11.5 m and snaps back, the full cooldown is spent (no refund, even at rank 3),
## and his walk is back as it ends.
func _miss() -> void:
	var r: Array = ak.setup("dredge", CATCH)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	var rdf := k.rmb_def()
	t_v.teleport(home + Vector3(0, 0, 9.0))
	p.slot_lv["sec"] = 3
	ak.aim_at(p, home + Vector3(5.0, 0, 0))
	ak.tap(m, p)
	var cd0 := float(k.cd["rmb"])
	var far := 0.0
	var t: float = ak.DT
	while (k.flying or k.coil > 0.0) and t < 2.0:
		if not k.hook_sd.is_empty():
			far = maxf(far, Vector2(k.hook_sd["pos"].x - p.pos.x, k.hook_sd["pos"].z - p.pos.z).length())
		m.step(ak.DT)
		t += ak.DT
	var fly_t := float(rdf["windup"]) + float(rdf["range"]) / float(rdf["speed"])
	ok(
		"miss: the arm flies its full 11.5 m in windup + range/speed and grabs nothing",
		k.grapples == 0 and absf(far - float(rdf["range"])) < 0.8 and absf(t - fly_t) < 0.1,
		"%.1f m in %.2f s (%.2f expected)" % [far, t, fly_t]
	)
	ok(
		"miss: the whole cooldown is spent, no refund at rank 3 (only an enemy hit halves it)",
		absf(float(k.cd["rmb"]) - (cd0 - t + ak.DT)) < 0.1 and k.pull.is_empty(),
		"cd %.2f of %.2f" % [float(k.cd["rmb"]), cd0]
	)
	ok(
		"miss: his walk and the gun are back the moment it ends",
		k.move_k() >= 0.99 and k.can_shoot(),
		"move %.2f" % k.move_k()
	)
	await ak.done(m)
