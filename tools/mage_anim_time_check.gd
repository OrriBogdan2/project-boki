extends RefCounted
## Sparkle's (Ryzz's) move timing through her clips (docs/heroes/mage.md, "Animation timing"), run inside
## --mage-combo-check: each keyed move is played in a real match with the model rendered, and the frames the
## footage gives (briefs/hero-ref/vireo.md, 0.2 s a frame) are checked against what the clip shows: when it
## blends in, the frame its release or hit lands on, when it hands the body back, and that the Skycall arm
## stays raised for as long as the drag and the countdown last. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2       # s past a clip's end the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const CLIP_TOL := 0.04       # s: the GLB samples its clips at 30 fps, so a length can sit a frame long
var C                        # the combo check (ok, ac)

func _init(check) -> void:
	C = check

func run() -> void:
	var r: Array = C.ac.setup("mage", 8.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	T.teleport(home + Vector3(0, 0, 30))
	T2.teleport(home + Vector3(30, 0, 30))
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Sparkle timing: her clips are on (nothing to time)", false)
		return
	_settle(m, P, home, 0.6)
	_lmb(m, P, K, home)
	_rmb_tap(m, P, K, home)
	_rmb_full(m, P, K, home)
	_wirerun(m, P, K, home)
	_skycall(m, P, K, home)
	_settle(m, P, home, 1.0)

func _clips(P: Hunter) -> WardenClips:
	return P.model.get_node("Warden/Sync").get("clips") as WardenClips

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _settle(m: Match, P: Hunter, home: Vector3, secs: float) -> void:
	for k in ["fire", "dash_down", "sec_hold", "e_down"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	P.teleport(home)
	for f in int(secs / DT):
		_frame(m, P)
	P.ak.anim_id = ""

## Plays `secs` of frames from t = 0 and reads one move's beats off the clips, in s from t = 0: when the kit
## plays it (play), when it owns the body (in), when its event fires (hit) and how far into the clip that is
## (at), the clip and its length, and when the body is back with the legs (out). `each(t)` drives the inputs.
func _time(m: Match, P: Hunter, K: MageKit, move: String, secs: float, event: Callable, each: Callable) -> Dictionary:
	var c := _clips(P)
	var r := {"play": -1.0, "in": -1.0, "hit": -1.0, "at": -1.0, "clip": "", "len": 0.0, "out": -1.0, "up": -1.0}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		var t0f := m.time - t0
		each.call(t0f)
		_frame(m, P)
		var t := m.time - t0
		if float(r["hit"]) < 0.0 and event.call():
			r["hit"] = t
			if K.anim_id == move:
				r["at"] = m.time - K.anim_at
		if K.anim_id != move:
			continue
		if float(r["play"]) < 0.0:
			r["play"] = K.anim_at - t0
		var w := maxf(c.act_w, c.up_w)
		if float(r["in"]) < 0.0 and w >= 0.999:
			r["in"] = t
		var live := c.cur
		if live == "" and c.up_w > 0.0:
			live = ((c.tree.tree_root as AnimationNodeBlendTree).get_node("anim_u") as AnimationNodeAnimation).animation
		if live != "" and String(r["clip"]) == "":
			r["clip"] = live
			r["len"] = c.lib.get_animation(live).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	print("TIME %s play %.2f in %.2f hit %.2f (clip %.2f) %s %.2f out %.2f"
			% [move, r["play"], r["in"], r["hit"], r["at"], r["clip"], r["len"], r["out"]])
	return r

func _shots(m: Match, P: Hunter) -> int:
	var n := 0
	for s in m.get("shots"):
		if s["by"] == P:
			n += 1
	return n

## LMB: the bolt leaves and the beat plays on the same frame; a 0.35 s beat (release key 0.06 s in).
func _lmb(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	P.fire_cd = 0.0
	var n0 := P.shot_n
	var r := _time(m, P, K, "mage_lmb_l", 0.7, func() -> bool: return P.shot_n > n0,
			func(t: float) -> void: P.inp["fire"] = t < 0.05)
	P.inp["fire"] = false
	C.ok("Sparkle timing LMB: bolt and beat on the press's frame, the arm on within a frame, back by 0.35 s + fade",
			float(r["hit"]) <= DT * 2.5 and absf(float(r["play"]) - float(r["hit"])) < DT * 1.5
			and float(r["in"]) <= BLEND_IN and float(r["out"]) < float(r["len"]) + HAND_BACK,
			"hit %.2f play %.2f in %.2f out %.2f" % [r["hit"], r["play"], r["in"], r["out"]])
	_settle(m, P, home, 0.8)

## Storm Rod, a tap (min_t 0.33): the rod leaves at 0.33 s whatever the tap length, so the throw beat plays then,
## not on the release.
func _rmb_tap(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var n0 := _shots(m, P)
	var r := _time(m, P, K, "mage_rmb", 1.2, func() -> bool: return _shots(m, P) > n0, func(t: float) -> void:
		if t < 0.01:
			P.inp["sec_hold"] = true
			K.press_rmb()
		P.inp["sec_hold"] = t < 0.1)
	C.ok("Sparkle timing RMB tap: the throw beat plays as the rod leaves (0.33 s), not on the release",
			float(r["hit"]) > 0.3 and absf(float(r["play"]) - float(r["hit"])) < DT * 1.5,
			"rod leaves %.2f beat %.2f" % [r["hit"], r["play"]])
	_settle(m, P, home, 0.8)

## Storm Rod, held: the charge flash at 1.0 s, the throw at the release; the throw beat (0.7 s clip, release key
## 0.16) is on within a frame and the arm is back by its end + the fade.
func _rmb_full(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var n0 := _shots(m, P)
	var r := _time(m, P, K, "mage_rmb", 2.0, func() -> bool: return _shots(m, P) > n0, func(t: float) -> void:
		if t < 0.01:
			P.inp["sec_hold"] = true
			K.press_rmb()
		P.inp["sec_hold"] = t < 1.0)
	C.ok("Sparkle timing RMB held 1.0 s: the rod and its beat leave on the release, the arm back by 0.7 s + fade",
			absf(float(r["hit"]) - 1.0) <= DT * 2.5 and absf(float(r["play"]) - float(r["hit"])) < DT * 1.5
			and float(r["in"]) - float(r["play"]) <= BLEND_IN and absf(float(r["len"]) - 0.7) < CLIP_TOL
			and float(r["out"]) - float(r["play"]) < 0.7 + HAND_BACK,
			"release %.2f play %.2f len %.2f out %.2f" % [r["hit"], r["play"], r["len"], r["out"]])
	_settle(m, P, home, 0.8)

## Wirerun held to its full charge: the crouch is on within a frame of the press, the streak leaves at the release
## (hold 0.6 s), the run clip plays then and the landing beat follows the arrival.
func _wirerun(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(12.0, 0, 0))
	P.dashes = P.max_dashes()
	var r := _time(m, P, K, "mage_dash", 0.5, func() -> bool: return not K.wire.is_empty(), func(t: float) -> void:
		if t < 0.01:
			P.inp["dash_down"] = true
			P.do_dash()
		P.inp["dash_down"] = true)
	C.ok("Sparkle timing Wirerun charge: the crouch is on within a frame of the press",
			float(r["hit"]) <= DT * 2.5 and float(r["in"]) <= BLEND_IN, "in %.2f" % r["in"])
	P.inp["dash_down"] = false
	_settle(m, P, home, 1.0)
	P.dashes = P.max_dashes()
	C.ac.aim_at(P, home + Vector3(12.0, 0, 0))
	var run_at := {"t": -1.0}
	r = _time(m, P, K, "mage_dash_go", 1.8, func() -> bool: return K.run_t > 0.0, func(t: float) -> void:
		if t < 0.01:
			P.inp["dash_down"] = true
			P.do_dash()
		P.inp["dash_down"] = t < float(K.wire_hold()))
	P.inp["dash_down"] = false
	C.ok("Sparkle timing Wirerun held: the streak leaves at the full charge and its beat plays then",
			absf(float(r["hit"]) - float(K.wire_hold())) <= DT * 2.5
			and absf(float(r["play"]) - float(r["hit"])) < DT * 1.5,
			"leaves %.2f beat %.2f" % [r["hit"], r["play"]])
	_settle(m, P, home, 1.0)

## Skycall: the arm goes up on the press and stays up through the drag and the 0.8 s countdown (up to 1.8 s), then the
## snap beat plays from the raised arm. A short drag (release at 0.3 s) and the longest (release at 1.0 s).
func _skycall(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	var at := home + Vector3(7.0, 0, 0)
	for rel in [0.3, 1.0]:
		C.ac.aim_at(P, at)
		K.cd["e"] = 0.0
		var rec := {"up": 1.0}
		var c := _clips(P)
		var r := _time(m, P, K, "mage_e", 2.3, func() -> bool: return K.anim_id == "mage_e_snap",
				func(t: float) -> void:
			if t < 0.01:
				P.inp["e_down"] = true
				P.ak.use_e()
			P.inp["e_down"] = t < rel
			C.ac.aim_at(P, at)
			if K.anim_id == "mage_e" and t > 0.5 and t < rel + 0.75:   # (the arm up, snap not yet)
				rec["up"] = minf(float(rec["up"]), c.up_w))
		C.ok("Sparkle timing Skycall (drag released at %.1f s): the arm stays raised until the snap" % rel,
				float(rec["up"]) >= 0.99 and float(r["in"]) <= BLEND_IN,
				"arm weight min %.2f in %.2f" % [rec["up"], r["in"]])
		_settle(m, P, home, 2.0)
		K.strikes.clear()
