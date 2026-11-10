extends RefCounted
## Grimble's move timing through his clips (docs/heroes/dredge.md, "Animation timing"), run inside
## --dredge-combo-check: each keyed move is played in a real match with the model rendered, and the beats the
## footage gives (briefs/hero-ref/dredge.md, 5 fps, 0.2 s a frame; the ult at 10 fps) are checked against what
## the clip shows: when it owns the body, the frame its hit lands on, when it hands the body back. Prints one
## TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const KEY_TOL := 0.02        # s: the GLB keys at 30 fps
const FRAME := 0.2           # s: one footage frame
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

## Is there a key within KEY_TOL of `t` in clip `clip` (any track)?
func _has_key(P: Hunter, clip: String, t: float) -> bool:
	var a := _clips(P).lib.get_animation(clip)
	for i in a.get_track_count():
		for k in a.track_get_key_count(i):
			if absf(a.track_get_key_time(i, k) - t) <= KEY_TOL:
				return true
	return false

## Plays `secs` of frames and reads the move's beats off the clips, in s from the press: when the kit plays it
## (play), when it owns the body (in), the first frame each named event turns true (ev) and the move clock then
## (at), the clip and its length, and when the body is back with the legs (out).
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
		var live := c.cur
		if live == "" and c.up_w > 0.0:
			live = c.cur_u
		if live != "" and String(r["clip"]) == "":
			r["clip"] = live
			r["len"] = c.lib.get_animation(live).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	var line := "TIME %s play %.2f in %.2f %s %.2f out %.2f" % [move, r["play"], r["in"], r["clip"], r["len"], r["out"]]
	for ev in r["ev"]:
		line += " | %s %.2f (clip %.2f)" % [ev, r["ev"][ev], r["at"][ev]]
	print(line)
	return r

func _ev(r: Dictionary, name_: String) -> float:
	return float((r["ev"] as Dictionary).get(name_, -1.0))

func _near(a: float, b: float, tol: float) -> bool:
	return a >= 0.0 and absf(a - b) <= tol

## LMB: seven slugs leave on the press with the kick (the clip's 0.05 key lands inside the blend-in), the body is
## back on the aim in about a frame, a volley every 0.5 s held, the cone's bloom capped and gone when released.
func _shot(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	K.shot_at = -9.0
	K.anim_id = ""
	var v0 := K.volleys
	var n0 := m.shots.size()
	var counted := [0]
	var seen := func() -> bool:
		if K.volleys > v0 and counted[0] == 0:
			for i in range(n0, m.shots.size()):
				if m.shots[i].get("by") == P:
					counted[0] += 1
		return K.volleys > v0
	P.inp["fire"] = true
	var r := _time(m, P, K, "dr_shot", 0.5, {"volley": seen})
	var first: int = counted[0]
	var bloom1 := P.wbloom
	var held := [_ev(r, "volley")]
	var v1 := K.volleys
	var t0 := m.time
	var cap := bloom1
	for f in int(1.5 / DT):
		_frame(m, P)
		cap = maxf(cap, P.wbloom)
		if K.volleys != v1:
			v1 = K.volleys
			held.append(m.time - t0 + 0.5)
	P.inp["fire"] = false
	var gaps := []
	for i in range(1, held.size()):
		gaps.append(snappedf(float(held[i]) - float(held[i - 1]), 0.01))
	var rest := 0.0
	while P.wbloom > 0.01 and rest < 3.0:
		_frame(m, P)
		rest += DT
	print("TIME dr_shot held: gaps %s, bloom %.1f after one, peak %.1f, gone %.2f s after release" % [gaps, bloom1, cap, rest])
	C.ok("Grimble timing LMB: seven slugs and the kick on the press's frame, the clip owns the body within the blend",
			first == 7 and _ev(r, "volley") <= DT * 2.5 and absf(float(r["play"]) - _ev(r, "volley")) < DT
			and float(r["in"]) <= BLEND_IN + DT, "%d slugs, hit %.2f play %.2f in %.2f" % [first, _ev(r, "volley"), r["play"], r["in"]])
	C.ok("Grimble timing LMB: the kick is keyed at 0.05 and the body is back on the aim by 0.24 (one frame, 0.2 s, after)",
			_has_key(P, "shot", 0.05) and _has_key(P, "shot", 0.24), "")
	var even := true
	for g in gaps:
		even = even and absf(float(g) - 0.5) <= 0.03
	C.ok("Grimble timing LMB held: a volley every 0.5 s, the cone's bloom capped at 15 degrees",
			gaps.size() >= 2 and even and cap <= 15.01, "gaps %s, peak %.1f" % [gaps, cap])
	_settle(m, P, home, 0.8)

## RMB: the arm punches out on the press (the clip's out key 0.14 inside the blend-in), is out by the grab, the grab of a
## body 5 body heights (9 m) away lands in the source's 0.4-0.6 s, the reel clip takes over on the grab and the pull-end
## on the arrival, and the pull of 5 body heights takes about a second.
func _throw_reel(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, T: Hunter, home: Vector3) -> void:
	T.teleport(home + Vector3(9.0, 0, 0))
	ak.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.anim_id = ""
	var grab := func() -> bool: return not K.pull.is_empty()
	P.inp["sec_hold"] = false
	K.press_rmb()
	var r := _time(m, P, K, "dr_throw", 1.0, {"flies": func() -> bool: return K.flying, "grab": grab})
	var grab_t := _ev(r, "grab")
	var reeled := 0.0
	var f_end := 0
	while not K.pull.is_empty() and f_end < 240:
		_frame(m, P)
		f_end += 1
	reeled = f_end * DT
	var pe := K.anim_id
	print("TIME dr_reel: pull %.2f s after the grab, then %s" % [reeled, pe])
	C.ok("Grimble timing RMB: the arm punches out on the press and reaches a body 5 bh away in the source's 0.4-0.6 s",
			_ev(r, "flies") <= DT * 2.5 and grab_t >= 0.3 and grab_t <= 0.6 and _has_key(P, "throw", 0.14),
			"flies %.2f grab %.2f" % [_ev(r, "flies"), grab_t])
	C.ok("Grimble timing RMB: the reel clip takes the body on the grab and the arm is still out then",
			absf(float(r["at"]["grab"]) - grab_t - (float(r["at"]["flies"]) - _ev(r, "flies"))) < 0.05
			and float(r["at"]["grab"]) >= 0.22 and float(r["at"]["grab"]) <= 0.7, "clip %.2f" % float(r["at"]["grab"]))
	C.ok("Grimble timing RMB: the pull of 5 bh takes about the source's second (within a frame)",
			reeled >= 0.8 - FRAME and reeled <= 1.0 + FRAME and pe == "dr_pullend", "%.2f s, %s" % [reeled, pe])
	ak.fresh(T)
	_settle(m, P, home, 1.0)

## E: the slam lands at the windup's end (0.38 s, the source's ~0.4 s) on the clip's slam key, in the press's frame
## count, and the body is back at rest by the source's ~0.8 s (the clip's recover key 0.75).
func _anchor(ak: RefCounted, m: Match, P: Hunter, K: DredgeKit, home: Vector3) -> void:
	ak.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["e"] = 0.0
	K.anim_id = ""
	var a0 := K.anchors
	var lift := {"y": 0.0}
	var y0 := P.pos.y
	K.use_e()
	var r := _time(m, P, K, "dr_anchor", 1.4, {"slam": func() -> bool: return K.anchors > a0})
	C.ok("Grimble timing E: the slam lands at the 0.38 s windup on the clip's slam key",
			_near(_ev(r, "slam"), float(K.e_def()["windup"]), DT * 1.5) and _near(float(r["at"]["slam"]), 0.38, DT * 1.5)
			and _has_key(P, "anchor", 0.38), "slam %.2f clip %.2f" % [_ev(r, "slam"), r["at"]["slam"]])
	C.ok("Grimble timing E: the raised fist and the turn are keyed by 0.12 s and the recover by 0.75 s (source ~0.8 s)",
			_has_key(P, "anchor", 0.12) and _has_key(P, "anchor", 0.75) and float(r["len"]) <= 1.01, "")
	lift["y"] = P.pos.y - y0
	_settle(m, P, home, 1.0)

## X: wave 1 at the end of the 1.1 s charge (the source's f22-f33, wave at f34) on the clip's shove key, wave 2 0.6 s
## later (f40), the move over at about 2.1 s.
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
	C.ok("Grimble timing X: wave 1 at the end of the 1.1 s charge, wave 2 0.6 s later, each on the clip's shove key",
			_near(_ev(r, "wave1"), 1.1, DT * 1.5) and _near(_ev(r, "wave2"), 1.7, DT * 1.5)
			and _has_key(P, "blast", 1.1) and _has_key(P, "blast", 1.7), "waves %.2f / %.2f" % [_ev(r, "wave1"), _ev(r, "wave2")])
	C.ok("Grimble timing X: the clip runs the cast's 2.1 s and he is planted back at the aim by then",
			_near(float(r["len"]), 2.1, 0.04) and float(r["out"]) <= 2.1 + 0.2, "len %.2f out %.2f" % [r["len"], r["out"]])
	_settle(m, P, home, 1.0)

## Shift three times, each as the gap lets it: the lunge replays on every press, lands (its squash key 0.18) as the
## dash ends, and he is never handed back to the legs between the three (the clip is as long as dash + gap).
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
	for f in int(1.6 / DT):
		if presses.size() < 3 and m.time >= K.next_barge and P.roll_t <= 0.0:
			P.do_dash()
		if K.anim_id == "dr_lunge" and K.anim_at != last:
			last = K.anim_at
			presses.append(K.anim_at - t0)
			if presses.size() == 1:
				land = P.roll_t
		_frame(m, P)
		if presses.size() >= 1 and m.time - t0 < float(presses[0]) + 1.1:
			min_w = minf(min_w, maxf(c.act_w, c.up_w)) if presses.size() >= 2 and m.time - t0 >= float(presses[1]) else min_w
	var gaps := []
	for i in range(1, presses.size()):
		gaps.append(snappedf(float(presses[i]) - float(presses[i - 1]), 0.01))
	print("TIME dr_lunge x3: presses %s, gaps %s, dash %.2f s, clip %.3f s, lowest ownership %.2f" % [
			presses, gaps, land, c.lib.get_animation("lunge").length, min_w])
	C.ok("Grimble timing barge: three chained lunges replay on each press, a dash and a gap (0.38 s) apart",
			presses.size() == 3 and (gaps[0] as float) <= land + float(K.dash_def()["gap"]) + 0.05, "%s" % [gaps])
	C.ok("Grimble timing barge: the lunge lands as the dash ends and the body stays on the clip through the chain",
			_has_key(P, "lunge", 0.18) and absf(0.18 - land) <= 0.04 and min_w >= 0.5, "dash %.2f, owned >= %.2f" % [land, min_w])
	_settle(m, P, home, 1.0)

## Air Shift: the pounce plays on the press; its keys are ours (the footage never shows an air dash).
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
	C.ok("Grimble timing air barge: the pounce plays on the press and keeps its drop key (no source: ours)",
			float(r["play"]) <= DT * 1.5 and _has_key(P, "pounce", 0.24), "dash %.2f play %.2f in %.2f" % [dash, r["play"], r["in"]])
	_settle(m, P, home, 1.0)

## Run cadence: his run clip against the sheet's build note (cadence 0.9, stride 0.7, no clean run in the footage).
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
	P.inp["move"] = Vector2.ZERO
