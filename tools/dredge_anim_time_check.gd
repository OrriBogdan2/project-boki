extends RefCounted
## Grimble's move timing through his clips (docs/heroes/dredge.md, "Animation timing"), run inside
## --dredge-combo-check: each keyed move is played in a real match with the model on, and the beats the footage
## gives (briefs/hero-ref/dredge.md, 5 fps, 0.2 s a frame; the ult at 10 fps) are checked against what the body
## shows: when the clip owns it, when its hit lands, when it hands the body back. A clip's "hit" is read off the
## GLB itself: the frame its pose stops moving after its fastest swing (_arrive). Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const FRAME := 0.2           # s: one footage frame
const BEAT_TOL := 0.05       # s: a clip beat against the gameplay event (the GLB samples at 30 fps)
const CLIP_FPS := 30.0
var C                        # the combo check (ok, ak)

func _init(check) -> void:
	C = check

func run(ak: RefCounted) -> void:
	var r: Array = ak.setup("dredge", 9.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Grimble timing: his clips are on (nothing to time)", false)
		await ak.done(m)
		return
	_settle(m, P, home, 0.6)
	_shot(ak, m, P, K, home)
	_throw_reel(ak, m, P, K, T, home)
	_anchor(ak, m, P, K, home)
	_blast(ak, m, P, K, home)
	_barges(ak, m, P, K, home)
	_pounce(ak, m, P, K, home)
	_run(m, P, home)
	await ak.done(m)

func _clips(P: Hunter) -> WardenClips:
	return P.model.get_node("Warden/Sync").get("clips") as WardenClips

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _settle(m: Match, P: Hunter, home: Vector3, secs: float) -> void:
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	P.teleport(home)
	P.vel = Vector3.ZERO
	for f in int(secs / DT):
		_frame(m, P)

## The clip's pose speed: per 1/30 s sample, the summed turn of every rotation track since the sample before.
func _speed(P: Hunter, clip: String) -> PackedFloat32Array:
	var a := _clips(P).lib.get_animation(clip)
	var n := int(roundf(a.length * CLIP_FPS)) + 1
	var sp := PackedFloat32Array()
	sp.resize(n)
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var q0 := a.rotation_track_interpolate(i, 0.0)
		for k in range(1, n):
			var q1 := a.rotation_track_interpolate(i, minf(k / CLIP_FPS, a.length))
			sp[k] += q0.angle_to(q1)
			q0 = q1
	return sp

## When the clip's swing inside [from, to] s lands: the first sample after its fastest one that moves under a
## quarter of that speed.
func _arrive(P: Hunter, clip: String, from: float, to: float) -> float:
	var sp := _speed(P, clip)
	var k0 := int(ceilf(from * CLIP_FPS))
	var k1 := mini(int(to * CLIP_FPS), sp.size() - 1)
	var top := k0
	for k in range(k0, k1 + 1):
		if sp[k] > sp[top]:
			top = k
	for k in range(top + 1, sp.size()):
		if sp[k] < sp[top] * 0.25:
			return k / CLIP_FPS
	return sp.size() / CLIP_FPS

## Plays `secs` of frames and reads the move's beats, in s from the press: when the kit plays it (play), when it
## owns the body (in), the first frame each named event turns true (ev) and the move clock then (at), the clip
## and its length, and when the body is back with the legs (out).
func _time(m: Match, P: Hunter, K: DredgeKit, move: String, secs: float, events: Dictionary) -> Dictionary:
	var c := _clips(P)
	var r := {"play": -1.0, "in": -1.0, "clip": "", "len": 0.0, "out": -1.0, "ev": {}, "at": {}}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		_frame(m, P)
		var t := m.time - t0
		for ev in events:
			if not (r["ev"] as Dictionary).has(ev) and (events[ev] as Callable).call():
				r["ev"][ev] = t
				r["at"][ev] = m.time - K.anim_at
		if K.anim_id != move:
			continue
		if float(r["play"]) < 0.0:
			r["play"] = K.anim_at - t0
		var w := maxf(c.act_w, c.up_w)
		if float(r["in"]) < 0.0 and w >= 0.999:
			r["in"] = t
		if c.cur != "" and String(r["clip"]) == "":
			r["clip"] = c.cur
			r["len"] = c.lib.get_animation(c.cur).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.001:
			r["out"] = t
	var line := "TIME %s play %.2f in %.2f %s %.2f out %.2f" % [move, r["play"], r["in"], r["clip"], r["len"], r["out"]]
	for ev in r["ev"]:
		line += " | %s %.2f (clip %.2f)" % [ev, r["ev"][ev], r["at"][ev]]
	print(line)
	return r

func _ev(r: Dictionary, name_: String) -> float:
	return float((r["ev"] as Dictionary).get(name_, -1.0))

func _at(r: Dictionary, name_: String) -> float:
	return float((r["at"] as Dictionary).get(name_, -1.0))

func _near(a: float, b: float, tol: float) -> bool:
	return a >= 0.0 and absf(a - b) <= tol

## LMB: seven slugs leave on the press and the kick lands in the clip's first beat (source: on the shot frame),
## the body is back on the aim a footage frame later, a volley every 0.5 s held (source 0.4-0.6), the cone's
## bloom capped at 15 degrees and gone after the release.
func _shot(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	K.shot_at = -9.0
	K.anim_id = ""
	var v0 := K.volleys
	var n0 := m.shots.size()
	P.inp["fire"] = true
	var r := _time(m, P, K, "dr_shot", 0.2, {"volley": func() -> bool: return K.volleys > v0})
	var first := 0
	for i in range(n0, m.shots.size()):
		if m.shots[i].get("by") == P:
			first += 1
	var bloom1 := P.wbloom
	var held := [_ev(r, "volley")]
	var v1 := K.volleys
	var t0 := m.time - 0.2
	var cap := bloom1
	for f in int(1.6 / DT):
		_frame(m, P)
		cap = maxf(cap, P.wbloom)
		if K.volleys != v1:
			v1 = K.volleys
			held.append(m.time - t0)
	P.inp["fire"] = false
	var gaps := []
	for i in range(1, held.size()):
		gaps.append(snappedf(float(held[i]) - float(held[i - 1]), 0.01))
	var rest := 0.0
	while P.wbloom > 0.01 and rest < 3.0:
		_frame(m, P)
		rest += DT
	var kick := _arrive(P, "shot", 0.0, 0.1)
	# the recoil swing; after its 0.24 aim key the clip only eases to the stance
	var back := _arrive(P, "shot", kick + 0.02, 0.26)
	print("TIME dr_shot: kick %.2f, aim %.2f; held gaps %s, bloom %.1f after one, peak %.1f, gone %.2f s"
			% [kick, back, gaps, bloom1, cap, rest])
	C.ok("Grimble timing LMB: seven slugs on the press, the kick lands within the blend-in (source: the shot frame)",
			first == 7 and _ev(r, "volley") <= DT * 2.5 and float(r["in"]) <= BLEND_IN + DT and kick <= BLEND_IN,
			"%d slugs, volley %.2f in %.2f kick %.2f" % [first, _ev(r, "volley"), r["in"], kick])
	C.ok("Grimble timing LMB: the body is back on the aim one footage frame (0.2 s) after the kick",
			back - kick <= FRAME + BEAT_TOL, "kick %.2f back %.2f" % [kick, back])
	var even := true
	for g in gaps:
		even = even and absf(float(g) - 0.5) <= 0.03
	C.ok("Grimble timing LMB held: a volley every 0.5 s, the cone's bloom capped at 15 degrees",
			gaps.size() >= 3 and even and cap <= 15.01, "gaps %s, peak %.1f" % [gaps, cap])
	_settle(m, P, home, 0.8)

## RMB: the arm leaves on the press and the punch lands in the throw clip's first beat; the reel clip takes the
## body on the grab and the pull-end clip when the reel ends. (The arm's and the reel's speeds against the
## source's 0.4 s / 1.0 s are ext/feel-grimble-reel's; this only prints them.)
func _throw_reel(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, T: Hunter, home: Vector3) -> void:
	T.teleport(home + Vector3(9.0, 0, 0))
	ak.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.anim_id = ""
	P.inp["sec_hold"] = false
	K.press_rmb()
	var reel_on := func() -> bool: return K.anim_id == "dr_reel"
	var r := _time(m, P, K, "dr_throw", 0.8, {"flies": func() -> bool: return K.flying,
			"grab": func() -> bool: return not K.pull.is_empty(), "reel": reel_on})
	var tow: Dictionary = {} if K.pull.is_empty() else K.pull["tow"]
	var from := T.pos
	var f_end := 0
	while not K.pull.is_empty() and f_end < 240:
		tow = K.pull["tow"]
		_frame(m, P)
		f_end += 1
	var pulled := (f_end * DT) + (0.8 - _ev(r, "grab"))
	var punch := _arrive(P, "throw", 0.0, 0.2)
	print("TIME dr_reel: grab %.2f, pull %.2f s, %.2f m, ended \"%s\", then %s; throw clip punch lands %.2f"
			% [_ev(r, "grab"), pulled, from.distance_to(T.pos), tow.get("end", ""), K.anim_id, punch])
	C.ok("Grimble timing RMB: the arm leaves on the press and the throw's punch lands within its blend-in",
			_ev(r, "flies") <= DT * 2.5 and float(r["in"]) <= BLEND_IN + DT and punch <= 0.2,
			"flies %.2f in %.2f punch %.2f" % [_ev(r, "flies"), r["in"], punch])
	C.ok("Grimble timing RMB: the reel clip takes the body on the grab, the pull-end when the reel ends",
			_near(_ev(r, "reel"), _ev(r, "grab"), DT * 1.5) and K.anim_id == "dr_pullend",
			"grab %.2f reel %.2f, then %s" % [_ev(r, "grab"), _ev(r, "reel"), K.anim_id])
	ak.fresh(T)
	_settle(m, P, home, 1.0)

## E: the slam lands at the windup's end (0.38 s, the source's ~0.4 s) on the clip's slam beat, and the body is
## back with the legs by the source's ~0.8 s total (the clip ends at 0.8, then the hand-back to the legs).
func _anchor(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["e"] = 0.0
	K.anim_id = ""
	var a0 := K.anchors
	K.use_e()
	var r := _time(m, P, K, "dr_anchor", 1.4, {"slam": func() -> bool: return K.anchors > a0})
	var slam := _arrive(P, "anchor", 0.3, 0.45)
	var wind := float(K.e_def()["windup"])
	print("TIME dr_anchor clip: slam lands %.2f, clip %.2f s" % [slam, r["len"]])
	C.ok("Grimble timing E: the slam lands at the 0.38 s windup (source ~0.4 s) on the clip's slam beat",
			_near(_ev(r, "slam"), wind, DT * 1.5) and _near(slam, wind, BEAT_TOL),
			"slam %.2f clip beat %.2f" % [_ev(r, "slam"), slam])
	C.ok("Grimble timing E: the clip ends at the source's ~0.8 s and the body is back with the legs a hand-back after",
			float(r["len"]) <= 0.8 + 0.02 and _near(float(r["out"]), float(r["len"]), WardenClips.FADE_LOCO + 2.0 * DT),
			"len %.2f out %.2f" % [r["len"], r["out"]])
	_settle(m, P, home, 1.0)

## X: wave 1 at the end of the 1.1 s charge (the source's f22-f33, wave at f34) on the clip's first shove, wave
## 2 0.6 s later (f40) on its second, the move over at about 2.1 s (f41-f43 recovery).
func _blast(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["x"] = 0.0
	P.lvl = 6
	K.anim_id = ""
	var w0 := K.broadside.waves
	HunterKeys.ult_pressed(P)
	var r := _time(m, P, K, "dr_blast", 2.6, {
		"wave1": func() -> bool: return K.broadside.waves > w0,
		"wave2": func() -> bool: return K.broadside.waves > w0 + 1})
	var s1 := _arrive(P, "blast", 1.0, 1.2)
	var s2 := _arrive(P, "blast", 1.6, 1.8)
	print("TIME dr_blast clip: shoves land %.2f / %.2f" % [s1, s2])
	C.ok("Grimble timing X: wave 1 at the end of the 1.1 s charge, wave 2 0.6 s later, each on the clip's shove",
			_near(_ev(r, "wave1"), 1.1, DT * 1.5) and _near(_ev(r, "wave2"), 1.7, DT * 1.5)
			and _near(s1, _ev(r, "wave1"), BEAT_TOL) and _near(s2, _ev(r, "wave2"), BEAT_TOL),
			"waves %.2f / %.2f, shoves %.2f / %.2f" % [_ev(r, "wave1"), _ev(r, "wave2"), s1, s2])
	C.ok("Grimble timing X: the clip runs the source's 2.1 s and hands the body back right after",
			_near(float(r["len"]), 2.1, 0.04) and float(r["out"]) <= 2.1 + WardenClips.FADE_LOCO + 2.0 * DT,
			"len %.2f out %.2f" % [r["len"], r["out"]])
	_settle(m, P, home, 1.0)

## Shift three times, each as the gap lets it: the dash covers its ground inside one footage frame (source
## <= 0.2 s), the lunge replays on every press, and the body stays on the clip through the chain (the clip
## outlasts dash + gap, so it is never handed to the legs between barges).
func _barges(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	P.dashes = P.max_dashes()
	K.anim_id = ""
	var c := _clips(P)
	var presses := []
	var min_w := 1.0
	var land := 0.0
	var t0 := m.time
	var last := -9.0
	var owned := []              # [s from the start, how much a clip owns the body]
	for f in int(1.6 / DT):
		if presses.size() < 3 and m.time >= K.next_barge and P.roll_t <= 0.0:
			P.do_dash()
		if K.anim_id == "dr_lunge" and K.anim_at != last:
			last = K.anim_at
			presses.append(K.anim_at - t0)
			if presses.size() == 1:
				land = P.roll_t
		_frame(m, P)
		owned.append([m.time - t0, maxf(c.act_w, c.up_w)])
	var gaps := []
	for i in range(1, presses.size()):
		gaps.append(snappedf(float(presses[i]) - float(presses[i - 1]), 0.01))
	if not presses.is_empty():
		for o in owned:     # from the first lunge's blend-in to the last press
			if float(o[0]) >= float(presses[0]) + BLEND_IN and float(o[0]) <= float(presses[-1]) + DT:
				min_w = minf(min_w, float(o[1]))
	var clip := c.lib.get_animation("lunge").length
	print("TIME dr_lunge x3: presses %s, gaps %s, dash %.2f s, clip %.3f s, lowest ownership %.2f" % [
			presses, gaps, land, clip, min_w])
	var longest := 0.0
	for g in gaps:
		longest = maxf(longest, float(g))
	C.ok("Grimble timing barge: three lunges, one a press, a dash and a gap apart; the dash inside a footage frame",
			presses.size() == 3 and longest <= land + float(K.dash_def()["gap"]) + 0.05 and land <= FRAME,
			"gaps %s dash %.2f" % [gaps, land])
	C.ok("Grimble timing barge: the lunge clip outlasts the chain gap and the body stays on it through the three",
			clip >= longest and min_w >= 0.95, "clip %.2f gaps %s, owned >= %.2f" % [clip, gaps, min_w])
	_settle(m, P, home, 1.0)

## Air Shift: the pounce plays on the press and owns the body inside the blend-in (no source: the footage
## never shows an air dash).
func _pounce(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	P.teleport(home + Vector3(0, 3.0, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	P.ex_cd = 0.0
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	_frame(m, P)
	K.anim_id = ""
	P.do_dash()
	var dash := P.roll_t
	var r := _time(m, P, K, "dr_pounce", 0.8, {})
	C.ok("Grimble timing air barge: the pounce plays on the press and owns the body within the blend-in (no source)",
			float(r["play"]) <= DT * 1.5 and float(r["in"]) <= BLEND_IN + DT,
			"dash %.2f play %.2f in %.2f" % [dash, r["play"], r["in"]])
	_settle(m, P, home, 1.0)

## Run cadence: his run clip against the sheet's build note (cadence 0.9, stride 0.7; no clean run in the
## footage, so no source). The clip's rate stays near 1 so the feet don't skate.
func _run(m: Match, P: Hunter, home: Vector3) -> void:
	_settle(m, P, home, 0.3)
	P.inp["move"] = Vector2(0, 1)
	for f in int(1.5 / DT):
		_frame(m, P)
	var c := _clips(P)
	var spd := Vector2(P.vel.x, P.vel.z).length()
	var rate := float(c.tree.get("parameters/loco_rate/scale"))
	var hz := rate / c.lib.get_animation("run_f").length
	print("TIME run: %.2f m/s, clip rate %.2f, a stride cycle at %.2f Hz (%.1f steps/s), %.2f m (%.2f bh) a cycle"
			% [spd, rate, hz, hz * 2.0, spd / hz, spd / hz / 1.8])
	C.ok("Grimble timing run: the run clip plays near its keyed rate at his run speed (no source cadence)",
			rate >= 0.85 and rate <= 1.2, "rate %.2f at %.2f m/s" % [rate, spd])
	P.inp["move"] = Vector2.ZERO
