extends RefCounted
## Grimble's move timing against the footage (briefs/hero-ref/dredge.md, 5 fps: one frame = 0.2 s), for
## --dredge-combo-check (docs/heroes/dredge.md, "Animation timing"): measured in the match, press to hit frame to
## recovery, plus the .glb clips' lengths against the kit's keyed moves (the clip IS the visible hit frame), and the
## clips as drawn: when each owns the body, when its hit lands (read off the GLB: the frame its pose stops moving
## after its fastest swing, _arrive), when it hands the body back.

const BH := 1.8  # m per body height (the sheet's unit: 3.5 bh = the 6.3 m slug stop)
const FRAME := 0.2  # s per footage frame
const DT := 1.0 / 60.0
const BLEND_IN := 0.12  # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const BEAT_TOL := 0.05  # s: a clip beat against the gameplay event (the GLB samples at 30 fps)
const CLIP_FPS := 30.0

var ak = null
var ok_fn: Callable


func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb


func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)


func run() -> void:
	await _throw_and_reel()
	await _anchor()
	await _barge()
	_clips()
	await _clip_beats()


## Abyssal Hand (0121-0129): the arm is out at full reach 0.4 s after the cast (~5 bh), then the pull takes ~1.0 s.
func _throw_and_reel() -> void:
	var r: Array = ak.setup("dredge", 5.0 * BH, "", false)
	var m: Match = r[0]
	var me: Hunter = r[1]
	var foe: Hunter = r[2]
	var kit: DredgeKit = me.ak
	foe.face = PI / 2.0
	ak.aim_at(me, foe.pos)
	ak.tap(m, me)
	var t: float = ak.DT
	var grab := -1.0
	var arrive := -1.0
	while t < 3.5 and arrive < 0.0:
		m.step(ak.DT)
		t += ak.DT
		if grab < 0.0 and not kit.pull.is_empty():
			grab = t
		elif grab >= 0.0 and kit.pull.is_empty():
			arrive = t
	var rdf := kit.rmb_def()
	var want := float(rdf["windup"]) + 5.0 * BH / float(rdf["speed"])
	ok(
		"timing throw: coil, then 5 bh at hook speed (slowed from the footage 0.4 s on purpose, owner 11-10)",
		grab > 0.0 and absf(grab - want) <= FRAME,
		"%.2f s, want %.2f" % [grab, want]
	)
	ok(
		"timing reel: a 5 bh pull takes about 1.0 s (footage 0124-0129)",
		arrive > 0.0 and absf(arrive - grab - 1.0) <= FRAME,
		"%.2f s" % (arrive - grab)
	)
	await ak.done(m)


## Iron Smash (0221-0236): a hop up and about 1 bh forward, the hit at ~0.4 s, over by ~0.8 s.
func _anchor() -> void:
	var r: Array = ak.setup("dredge", 2.2, "", false)
	var m: Match = r[0]
	var me: Hunter = r[1]
	var foe: Hunter = r[2]
	var kit: DredgeKit = me.ak
	foe.teleport(me.pos + Vector3(2.2, 0, 0))
	ak.aim_at(me, foe.pos)
	var from := me.pos
	var hp0 := foe.hp
	var anchors := kit.anchors
	kit.cd["e"] = 0.0
	kit.use_e()
	var t := 0.0
	var hit := -1.0
	var hop := 0.0
	while t < 1.0 and hit < 0.0:
		m.step(ak.DT)
		t += ak.DT
		if kit.anchors > anchors:
			hit = t
			hop = me.flat_dist(from)
	ok(
		"timing anchor: the fist lands 0.4 s after the press (footage 0221-0223)",
		hit > 0.0 and absf(hit - 0.4) <= FRAME and foe.hp < hp0,
		"%.2f s" % hit
	)
	ok(
		"timing anchor: he hops about 1 bh forward before the slam (footage 0222)",
		hop >= 0.6 * BH and hop <= 1.4 * BH,
		"%.2f m (%.1f bh)" % [hop, hop / BH]
	)
	await ak.done(m)


## Brute Dash (0188): about 2.5-3 bh in a frame or less, then a crouch and back on the aim within a frame.
func _barge() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", false)
	var m: Match = r[0]
	var me: Hunter = r[1]
	var home: Vector3 = r[4]
	ak.aim_at(me, home + Vector3(0, 0, -6.0))
	var from := me.pos
	me.do_dash()
	var t := 0.0
	while me.roll_t > 0.0 and t < 1.0:
		m.step(ak.DT)
		t += ak.DT
	ok("timing barge: over inside one frame (0.2 s)", t > 0.0 and t <= FRAME, "%.2f s" % t)
	var far := me.flat_dist(from)
	ok("timing barge: short, 1.5-3 bh", far >= 1.5 * BH * 0.8 and far <= 3.0 * BH, "%.2f m" % far)
	await ak.done(m)


## The clip in the .glb is what is drawn: each held-less move's clip lasts exactly the kit's keyed move, so the hit key
## (shot 0.05, anchor 0.38, lunge 0.18...) is the same instant in both.
func _clips() -> void:
	var glb := (load("res://art/wardens/dredge/dredge.glb") as PackedScene).instantiate()
	var player := glb.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var cfg: Dictionary = WardenClips.data("dredge")
	var off: Array = []
	for k in cfg["kmoves"]:
		var mv: Dictionary = cfg["kmoves"][k]
		if mv.has("hold_from") or not KMovesPair.MOVES.has(k):
			continue
		var keys: Array = KMovesPair.MOVES[k]["keys"]
		var kit_end := float((keys[-1] as Array)[0])
		var clip_end := player.get_animation(String(mv["clip"])).length
		if absf(clip_end - kit_end) > 0.03:
			off.append("%s %.2f/%.2f" % [k, clip_end, kit_end])
	glb.free()
	ok("timing clips: every move's .glb clip lasts as long as the kit's keyed move", off.is_empty(), str(off))


## The clips through WardenClips in a live match with the model on: one TIME line a move.
func _clip_beats() -> void:
	var r: Array = ak.setup("dredge", 9.0, "", false)
	var m: Match = r[0]
	var me: Hunter = r[1]
	var foe: Hunter = r[2]
	var home: Vector3 = r[4]
	var kit: DredgeKit = me.ak
	if me.model == null or not me.model.has_node("Warden/Sync"):
		ok("Grimble timing: his clips are on (nothing to time)", false)
		await ak.done(m)
		return
	_settle(m, me, home, 0.6)
	_shot(m, me, kit, home)
	_throw_reel(m, me, kit, foe, home)
	_anchor_beats(m, me, kit, home)
	_blast(m, me, kit, home)
	_barge_chain(m, me, kit, home)
	_pounce(m, me, kit, home)
	_run(m, me, home)
	await ak.done(m)


func _warden(me: Hunter) -> WardenClips:
	return me.model.get_node("Warden/Sync").get("clips") as WardenClips


func _frame(m: Match, me: Hunter) -> void:
	m.step(DT)
	me.render(DT, 1.0)
	var sync: Node = me.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)


func _settle(m: Match, me: Hunter, home: Vector3, secs: float) -> void:
	me.inp["fire"] = false
	me.inp["move"] = Vector2.ZERO
	me.teleport(home)
	me.vel = Vector3.ZERO
	for f in int(secs / DT):
		_frame(m, me)


## The clip's pose speed: per 1/30 s sample, the summed turn of every rotation track since the sample before.
func _speed(me: Hunter, clip: String) -> PackedFloat32Array:
	var a := _warden(me).lib.get_animation(clip)
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
func _arrive(me: Hunter, clip: String, from: float, to: float) -> float:
	var sp := _speed(me, clip)
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
func _time(m: Match, me: Hunter, kit: DredgeKit, move: String, secs: float, events: Dictionary) -> Dictionary:
	var c := _warden(me)
	var r := {"play": -1.0, "in": -1.0, "clip": "", "len": 0.0, "out": -1.0, "ev": {}, "at": {}}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		_frame(m, me)
		var t := m.time - t0
		for ev in events:
			if not (r["ev"] as Dictionary).has(ev) and (events[ev] as Callable).call():
				r["ev"][ev] = t
				r["at"][ev] = m.time - kit.anim_at
		if kit.anim_id != move:
			continue
		if float(r["play"]) < 0.0:
			r["play"] = kit.anim_at - t0
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


func _ev(r: Dictionary, ev_name: String) -> float:
	return float((r["ev"] as Dictionary).get(ev_name, -1.0))


func _at(r: Dictionary, ev_name: String) -> float:
	return float((r["at"] as Dictionary).get(ev_name, -1.0))


func _near(a: float, b: float, tol: float) -> bool:
	return a >= 0.0 and absf(a - b) <= tol


## LMB: seven slugs leave on the press and the kick lands in the clip's first beat (source: on the shot frame),
## the body is back on the aim a footage frame later, a volley every 0.5 s held (source 0.4-0.6), the cone's
## bloom capped at 15 degrees and gone after the release.
func _shot(m: Match, me: Hunter, kit: DredgeKit, home: Vector3) -> void:
	ak.aim_at(me, home + Vector3(6.0, 0, 0))
	kit.shot_at = -9.0
	kit.anim_id = ""
	var v0 := kit.volleys
	var n0 := m.shots.size()
	me.inp["fire"] = true
	var r := _time(m, me, kit, "dr_shot", 0.2, {"volley": func() -> bool: return kit.volleys > v0})
	var first := 0
	for i in range(n0, m.shots.size()):
		if m.shots[i].get("by") == me:
			first += 1
	var bloom1 := me.wbloom
	var held := [_ev(r, "volley")]
	var v1 := kit.volleys
	var t0 := m.time - 0.2
	var cap := bloom1
	for f in int(1.6 / DT):
		_frame(m, me)
		cap = maxf(cap, me.wbloom)
		if kit.volleys != v1:
			v1 = kit.volleys
			held.append(m.time - t0)
	me.inp["fire"] = false
	var gaps := []
	for i in range(1, held.size()):
		gaps.append(snappedf(float(held[i]) - float(held[i - 1]), 0.01))
	var rest := 0.0
	while me.wbloom > 0.01 and rest < 3.0:
		_frame(m, me)
		rest += DT
	var kick := _arrive(me, "shot", 0.0, 0.1)
	# the recoil swing; after its 0.24 aim key the clip only eases to the stance
	var back := _arrive(me, "shot", kick + 0.02, 0.26)
	print(
		(
			"TIME dr_shot: kick %.2f, aim %.2f; held gaps %s, bloom %.1f after one, peak %.1f, gone %.2f s"
			% [kick, back, gaps, bloom1, cap, rest]
		)
	)
	ok(
		"Grimble timing LMB: seven slugs on the press, the kick lands within the blend-in (source: the shot frame)",
		first == 7 and _ev(r, "volley") <= DT * 2.5 and float(r["in"]) <= BLEND_IN + DT and kick <= BLEND_IN,
		"%d slugs, volley %.2f in %.2f kick %.2f" % [first, _ev(r, "volley"), r["in"], kick]
	)
	ok(
		"Grimble timing LMB: the body is back on the aim one footage frame (0.2 s) after the kick",
		back - kick <= FRAME + BEAT_TOL,
		"kick %.2f back %.2f" % [kick, back]
	)
	var even := true
	for g in gaps:
		even = even and absf(float(g) - 0.5) <= 0.03
	ok(
		"Grimble timing LMB held: a volley every 0.5 s, the cone's bloom capped at 15 degrees",
		gaps.size() >= 3 and even and cap <= 15.01,
		"gaps %s, peak %.1f" % [gaps, cap]
	)
	_settle(m, me, home, 0.8)


## RMB: the arm leaves on the press and the punch lands in the throw clip's first beat; the reel clip takes the
## body on the grab and the pull-end clip when the reel ends. (The arm's and the reel's speeds against the
## source's 0.4 s / 1.0 s are ext/feel-grimble-reel's; this only prints them.)
func _throw_reel(m: Match, me: Hunter, kit: DredgeKit, foe: Hunter, home: Vector3) -> void:
	foe.teleport(home + Vector3(9.0, 0, 0))
	ak.aim_at(me, foe.pos)
	kit.cd["rmb"] = 0.0
	kit.anim_id = ""
	me.inp["sec_hold"] = false
	kit.press_rmb()
	var reel_on := func() -> bool: return kit.anim_id == "dr_reel"
	var r := _time(
		m,
		me,
		kit,
		"dr_throw",
		0.8,
		{
			"flies": func() -> bool: return kit.flying,
			"grab": func() -> bool: return not kit.pull.is_empty(),
			"reel": reel_on
		}
	)
	var tow: Dictionary = {} if kit.pull.is_empty() else kit.pull["tow"]
	var from := foe.pos
	var f_end := 0
	while not kit.pull.is_empty() and f_end < 240:
		tow = kit.pull["tow"]
		_frame(m, me)
		f_end += 1
	var pulled := (f_end * DT) + (0.8 - _ev(r, "grab"))
	var punch := _arrive(me, "throw", 0.0, 0.2)
	print(
		(
			'TIME dr_reel: grab %.2f, pull %.2f s, %.2f m, ended "%s", then %s; throw clip punch lands %.2f'
			% [_ev(r, "grab"), pulled, from.distance_to(foe.pos), tow.get("end", ""), kit.anim_id, punch]
		)
	)
	ok(
		"Grimble timing RMB: the arm leaves on the press and the throw's punch lands within its blend-in",
		_ev(r, "flies") <= DT * 2.5 and float(r["in"]) <= BLEND_IN + DT and punch <= 0.2,
		"flies %.2f in %.2f punch %.2f" % [_ev(r, "flies"), r["in"], punch]
	)
	ok(
		"Grimble timing RMB: the reel clip takes the body on the grab, the pull-end when the reel ends",
		_near(_ev(r, "reel"), _ev(r, "grab"), DT * 1.5) and kit.anim_id == "dr_pullend",
		"grab %.2f reel %.2f, then %s" % [_ev(r, "grab"), _ev(r, "reel"), kit.anim_id]
	)
	ak.fresh(foe)
	_settle(m, me, home, 1.0)


## E: the slam lands at the windup's end (0.38 s, the source's ~0.4 s) on the clip's slam beat, and the body is
## back with the legs by the source's ~0.8 s total (the clip ends at 0.8, then the hand-back to the legs).
func _anchor_beats(m: Match, me: Hunter, kit: DredgeKit, home: Vector3) -> void:
	ak.aim_at(me, home + Vector3(6.0, 0, 0))
	kit.cd["e"] = 0.0
	kit.anim_id = ""
	var a0 := kit.anchors
	kit.use_e()
	var r := _time(m, me, kit, "dr_anchor", 1.4, {"slam": func() -> bool: return kit.anchors > a0})
	var slam := _arrive(me, "anchor", 0.3, 0.45)
	var wind := float(kit.e_def()["windup"])
	print("TIME dr_anchor clip: slam lands %.2f, clip %.2f s" % [slam, r["len"]])
	ok(
		"Grimble timing E: the slam lands at the 0.38 s windup (source ~0.4 s) on the clip's slam beat",
		_near(_ev(r, "slam"), wind, DT * 1.5) and _near(slam, wind, BEAT_TOL),
		"slam %.2f clip beat %.2f" % [_ev(r, "slam"), slam]
	)
	ok(
		"Grimble timing E: the clip ends at the source's ~0.8 s and the body is back with the legs a hand-back after",
		float(r["len"]) <= 0.8 + 0.02 and _near(float(r["out"]), float(r["len"]), WardenClips.FADE_LOCO + 2.0 * DT),
		"len %.2f out %.2f" % [r["len"], r["out"]]
	)
	_settle(m, me, home, 1.0)


## X: wave 1 at the end of the 1.1 s charge (the source's f22-f33, wave at f34) on the clip's first shove, wave
## 2 0.6 s later (f40) on its second, the move over at about 2.1 s (f41-f43 recovery).
func _blast(m: Match, me: Hunter, kit: DredgeKit, home: Vector3) -> void:
	ak.aim_at(me, home + Vector3(6.0, 0, 0))
	kit.cd["x"] = 0.0
	me.lvl = 6
	kit.anim_id = ""
	var w0 := kit.broadside.waves
	HunterKeys.ult_pressed(me)
	var r := _time(
		m,
		me,
		kit,
		"dr_blast",
		2.6,
		{
			"wave1": func() -> bool: return kit.broadside.waves > w0,
			"wave2": func() -> bool: return kit.broadside.waves > w0 + 1
		}
	)
	var s1 := _arrive(me, "blast", 1.0, 1.2)
	var s2 := _arrive(me, "blast", 1.6, 1.8)
	print("TIME dr_blast clip: shoves land %.2f / %.2f" % [s1, s2])
	ok(
		"Grimble timing X: wave 1 at the end of the 1.1 s charge, wave 2 0.6 s later, each on the clip's shove",
		(
			_near(_ev(r, "wave1"), 1.1, DT * 1.5)
			and _near(_ev(r, "wave2"), 1.7, DT * 1.5)
			and _near(s1, _ev(r, "wave1"), BEAT_TOL)
			and _near(s2, _ev(r, "wave2"), BEAT_TOL)
		),
		"waves %.2f / %.2f, shoves %.2f / %.2f" % [_ev(r, "wave1"), _ev(r, "wave2"), s1, s2]
	)
	ok(
		"Grimble timing X: the clip runs the source's 2.1 s and hands the body back right after",
		_near(float(r["len"]), 2.1, 0.04) and float(r["out"]) <= 2.1 + WardenClips.FADE_LOCO + 2.0 * DT,
		"len %.2f out %.2f" % [r["len"], r["out"]]
	)
	_settle(m, me, home, 1.0)


## Shift three times, each as the gap lets it: the dash covers its ground inside one footage frame (source
## <= 0.2 s), the lunge replays on every press, and the body stays on the clip through the chain (the clip
## outlasts dash + gap, so it is never handed to the legs between barges).
func _barge_chain(m: Match, me: Hunter, kit: DredgeKit, home: Vector3) -> void:
	ak.aim_at(me, home + Vector3(6.0, 0, 0))
	me.dashes = me.max_dashes()
	kit.anim_id = ""
	var c := _warden(me)
	var presses := []
	var min_w := 1.0
	var land := 0.0
	var t0 := m.time
	var last := -9.0
	var owned := []  # [s from the start, how much a clip owns the body]
	for f in int(1.6 / DT):
		if presses.size() < 3 and m.time >= kit.next_barge and me.roll_t <= 0.0:
			me.do_dash()
		if kit.anim_id == "dr_lunge" and kit.anim_at != last:
			last = kit.anim_at
			presses.append(kit.anim_at - t0)
			if presses.size() == 1:
				land = me.roll_t
		_frame(m, me)
		owned.append([m.time - t0, maxf(c.act_w, c.up_w)])
	var gaps := []
	for i in range(1, presses.size()):
		gaps.append(snappedf(float(presses[i]) - float(presses[i - 1]), 0.01))
	if not presses.is_empty():
		for o in owned:  # from the first lunge's blend-in to the last press
			if float(o[0]) >= float(presses[0]) + BLEND_IN and float(o[0]) <= float(presses[-1]) + DT:
				min_w = minf(min_w, float(o[1]))
	var clip := c.lib.get_animation("lunge").length
	print(
		(
			"TIME dr_lunge x3: presses %s, gaps %s, dash %.2f s, clip %.3f s, lowest ownership %.2f"
			% [presses, gaps, land, clip, min_w]
		)
	)
	var longest := 0.0
	for g in gaps:
		longest = maxf(longest, float(g))
	ok(
		"Grimble timing barge: three lunges, one a press, a dash and a gap apart; the dash inside a footage frame",
		presses.size() == 3 and longest <= land + float(kit.dash_def()["gap"]) + 0.05 and land <= FRAME,
		"gaps %s dash %.2f" % [gaps, land]
	)
	ok(
		"Grimble timing barge: the lunge clip outlasts the chain gap and the body stays on it through the three",
		clip >= longest and min_w >= 0.95,
		"clip %.2f gaps %s, owned >= %.2f" % [clip, gaps, min_w]
	)
	_settle(m, me, home, 1.0)


## Air Shift: the pounce plays on the press and owns the body inside the blend-in (no source: the footage
## never shows an air dash).
func _pounce(m: Match, me: Hunter, kit: DredgeKit, home: Vector3) -> void:
	me.teleport(home + Vector3(0, 3.0, 0))
	me.vel = Vector3.ZERO
	me.grounded = false
	me.ex_cd = 0.0
	ak.aim_at(me, home + Vector3(6.0, 0, 0))
	_frame(m, me)
	kit.anim_id = ""
	me.do_dash()
	var dash := me.roll_t
	var r := _time(m, me, kit, "dr_pounce", 0.8, {})
	ok(
		"Grimble timing air barge: the pounce plays on the press and owns the body within the blend-in (no source)",
		float(r["play"]) <= DT * 1.5 and float(r["in"]) <= BLEND_IN + DT,
		"dash %.2f play %.2f in %.2f" % [dash, r["play"], r["in"]]
	)
	_settle(m, me, home, 1.0)


## Run cadence: his run clip against the sheet's build note (cadence 0.9, stride 0.7; no clean run in the
## footage, so no source). The clip's rate stays near 1 so the feet don't skate.
func _run(m: Match, me: Hunter, home: Vector3) -> void:
	_settle(m, me, home, 0.3)
	me.inp["move"] = Vector2(0, 1)
	for f in int(1.5 / DT):
		_frame(m, me)
	var c := _warden(me)
	var spd := Vector2(me.vel.x, me.vel.z).length()
	var rate := float(c.tree.get("parameters/loco_rate/scale"))
	var hz := rate / c.lib.get_animation("run_f").length
	print(
		(
			"TIME run: %.2f m/s, clip rate %.2f, a stride cycle at %.2f Hz (%.1f steps/s), %.2f m (%.2f bh) a cycle"
			% [spd, rate, hz, hz * 2.0, spd / hz, spd / hz / 1.8]
		)
	)
	ok(
		"Grimble timing run: the run clip plays near its keyed rate at his run speed (no source cadence)",
		rate >= 0.85 and rate <= 1.2,
		"rate %.2f at %.2f m/s" % [rate, spd]
	)
	me.inp["move"] = Vector2.ZERO
