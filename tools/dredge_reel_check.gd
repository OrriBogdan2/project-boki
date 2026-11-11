extends RefCounted
## The Abyssal Hand reel against the source, for --dredge-combo-check (docs/heroes/dredge.md, "Reel parity"):
## the arm's out-speed and reach, the reel's speed curve, where the body stops, what the reeled foe can do,
## what Grimble can do while he reels, and what a miss costs. One row of the doc's table per assert.

const BH := 1.8                  # m in one body height of the footage (briefs/hero-ref/linwick.md scale)
const OUT_SPD := 12.5 * BH       # m/s the arm reaches out: 5 bh in 0.4 s (frames 121-123)
const REEL_SPD := 5.0 * BH       # m/s the reel hauls: about 5 bh/s (frames 124-129)
const CATCH := 9.0               # m: the foe's start, the footage's 5 bh catch
const REEL_T := 1.0              # s the footage's 5 bh reel takes, grab to arrival (frames 124-129)
const SNUG := 0.3                # m of air at most between the bodies at the stop ("adjacent", 0130)

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	await _reel()
	await _miss()

## A foe 9 m out: the arm's out-speed, the reel's curve and time, the stop, and what both sides can do meanwhile.
func _reel() -> void:
	var r: Array = ak.setup("dredge", CATCH)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	T.set_arch("gunslinger")
	T.unlock_all()
	T.dashes = T.max_dashes()
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	var out_spd := 0.0               # the hook's step per frame while it flies (its launch point is off his hand)
	var t := 0.0
	while K.pull.is_empty() and t < 1.0:
		var at0: Vector3 = K.hook_sd.get("pos", Vector3.ZERO)
		m.step(ak.DT)
		t += ak.DT
		if K.flying and not K.hook_sd.is_empty():
			out_spd = Vector2(K.hook_sd["pos"].x - at0.x, K.hook_sd["pos"].z - at0.z).length() / ak.DT
	ok(
		"reel parity: the arm reaches out at the footage's ~22 m/s (5 bh in 0.4 s)",
		not K.pull.is_empty() and absf(out_spd - OUT_SPD) < 1.0, "%.1f m/s, caught %.2f s after the tap" % [out_spd, t]
	)
	# the reel: its speed each frame, and whether the foe or Grimble could act
	var from := Vector2(T.pos.x - P.pos.x, T.pos.z - P.pos.z).normalized()
	var speeds: Array = []
	var stun_min := 99.0
	var tr := 0.0
	var acted := false
	var jumped := false
	var dash0 := T.dashes
	var shots0 := T.shot_n
	while not K.pull.is_empty() and tr < 3.0:
		var d := P.flat_dist(T)
		stun_min = minf(stun_min, T.stun_t)
		T.inp["fire"] = true
		T.do_jump()
		T.do_dash()
		T.ak.press_rmb()
		T.ak.use_e()
		P.do_jump()
		jumped = jumped or P.vel.y > 0.5 or not P.grounded
		acted = acted or K.cast_ult() or K.broadside.running()
		m.step(ak.DT)
		tr += ak.DT
		speeds.append((d - P.flat_dist(T)) / ak.DT)
	T.inp["fire"] = false
	var top: float = speeds.max() if not speeds.is_empty() else 0.0
	var first: float = speeds[0] if not speeds.is_empty() else 0.0
	ok(
		"reel parity: the reel hauls at the footage's ~9 m/s (5 bh/s)",
		absf(top - REEL_SPD) < 1.0, "%.1f m/s" % top
	)
	ok(
		"reel parity: full speed from the grab frame, no ease-in (frames 124-129 even)",
		first >= top * 0.9, "first frame %.1f of %.1f m/s" % [first, top]
	)
	ok(
		"reel parity: a 5 bh catch arrives in about 1 s",
		K.arrivals == 1 and absf(tr - REEL_T) < 0.15, "%.2f s" % tr
	)
	var air := P.flat_dist(T) - P.r - T.r
	var at := Vector2(T.pos.x - P.pos.x, T.pos.z - P.pos.z).normalized()
	var off_line := rad_to_deg(at.angle_to(from))
	var off_face := rad_to_deg(at.angle_to(Vector2(-sin(P.face), -cos(P.face))))
	ok(
		"reel parity: the body stops adjacent (bodies all but touching)",
		air >= -0.05 and air <= SNUG, "%.2f m between them" % air
	)
	ok(
		"reel parity: ... in front of him, on the line it was reeled along",
		absf(off_line) < 15.0 and absf(off_face) < 30.0,
		"%.0f deg off the reel line, %.0f off his facing" % [off_line, off_face]
	)
	ok(
		"reel parity: the foe is stunned the whole reel and can't jump, dash, cast or shoot",
		stun_min > 0.0 and T.dashes == dash0 and float(T.ak.cd.get("rmb", 0.0)) <= 0.0
			and float(T.ak.cd.get("e", 0.0)) <= 0.0 and T.shot_n == shots0 and T.pos.y < P.pos.y + 0.3,
		"stun min %.2f, dashes %.0f/%.0f, shots %d" % [stun_min, T.dashes, dash0, T.shot_n - shots0]
	)
	ok(
		"reel parity: he arrives stunned, not Grounded (data over the wiki), free within 0.3 s",
		T.stun_t > 0.0 and not KitStatus.grounded(T), "stun %.2f" % T.stun_t
	)
	ak.step(m, 0.3)
	ok("reel parity: ... and acts again after it", T.stun_t <= 0.0, "stun %.2f" % T.stun_t)
	ok("reel parity: Grimble can't jump or start the X while he reels", not jumped and not acted)
	await ak.done(m)

## A miss: the arm flies its full 11.5 m and snaps back, the full cooldown is spent (no refund, even at rank 3),
## and his walk is back as it ends.
func _miss() -> void:
	var r: Array = ak.setup("dredge", CATCH)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	var rdf := K.rmb_def()
	T.teleport(home + Vector3(0, 0, 9.0))
	P.slot_lv["sec"] = 3
	ak.aim_at(P, home + Vector3(5.0, 0, 0))
	ak.tap(m, P)
	var cd0 := float(K.cd["rmb"])
	var far := 0.0
	var t: float = ak.DT
	while K.flying and t < 2.0:
		far = maxf(far, Vector2(K.hook_sd["pos"].x - P.pos.x, K.hook_sd["pos"].z - P.pos.z).length())
		m.step(ak.DT)
		t += ak.DT
	var fly_t := float(rdf["range"]) / float(rdf["speed"])
	ok(
		"miss: the arm flies its full 11.5 m in range/speed and grabs nothing",
		K.grapples == 0 and absf(far - float(rdf["range"])) < 0.8 and absf(t - fly_t) < 0.1,
		"%.1f m in %.2f s (%.2f expected)" % [far, t, fly_t]
	)
	ok(
		"miss: the whole cooldown is spent, no refund at rank 3 (only an enemy hit halves it)",
		absf(float(K.cd["rmb"]) - (cd0 - t + ak.DT)) < 0.1 and K.pull.is_empty(),
		"cd %.2f of %.2f" % [float(K.cd["rmb"]), cd0]
	)
	ok("miss: his walk and the gun are back the moment it ends", K.move_k() >= 0.99 and K.can_shoot(),
			"move %.2f" % K.move_k())
	await ak.done(m)
