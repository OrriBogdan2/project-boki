extends RefCounted
## Motley's move timing through his clips (docs/heroes/ostra.md, "Timing pass"), run inside --ostra-combo-check:
## each keyed move is played in a real match with the model rendered, and the beats the footage gives
## (briefs/hero-ref/ostra.md, 0.2 s a frame) are checked against what the clip shows: when it blends in, the
## frame its release or hit lands on, when it hands the body back, his hover and that he never plants a foot.
## Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2       # s past a clip's end the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const FRAME := 0.2           # s: one footage frame, the resolution of every source time
var C                        # the combo check (ok, ac)

func _init(check) -> void:
	C = check

func run(m: Match, P: Hunter, K: OstraKit, T: Hunter, home: Vector3) -> void:
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Motley timing: his clips are on (nothing to time)", false)
		return
	_settle(m, P, K, home, 0.6)
	_orb(m, P, K, home)
	_snap(m, P, K, T, home)
	_swap(m, P, K, T, home)
	_seed(m, P, K, T, home)
	_settle(m, P, K, home, 0.6)
	_float(m, P, K, home)
	_settle(m, P, K, home, 1.0)

func _clips(P: Hunter) -> WardenClips:
	return P.model.get_node("Warden/Sync").get("clips") as WardenClips

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _settle(m: Match, P: Hunter, K: OstraKit, home: Vector3, secs: float) -> void:
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	P.inp["dash_down"] = false
	if not K.seed.is_empty():
		K._pop(false)
	K._drop_holds()
	K.swollen_t = 0.0
	K.anim_id = ""
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.dashes = P.max_dashes()
	K.cd["e"] = 0.0
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	for f in int(secs / DT):
		_frame(m, P)

## Plays `secs` of frames from a press and reads the move's beats off the clips, in s from the press: when the
## kit plays it (play), when it owns the body (in), when the kit's event fires (hit, `event` turns true) and how
## far into the clip that is (at), the clip and its length, and when the body is back with the legs (out).
func _time(
		m: Match, P: Hunter, K: OstraKit, moves: Array, secs: float, event: Callable, each := Callable()) -> Dictionary:
	var c := _clips(P)
	var r := {"play": -1.0, "in": -1.0, "hit": -1.0, "at": -1.0, "clip": "", "len": 0.0, "out": -1.0}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		if each.is_valid():
			each.call(m.time - t0)
		_frame(m, P)
		var t := m.time - t0
		if float(r["hit"]) < 0.0 and event.call():
			r["hit"] = t
			r["at"] = m.time - K.anim_at
		if not K.anim_id in moves:
			continue
		if float(r["play"]) < 0.0:
			r["play"] = K.anim_at - t0
		var w := maxf(c.act_w, c.up_w)
		if float(r["in"]) < 0.0 and w >= 0.999:
			r["in"] = t
		var mv: Dictionary = (c.d["kmoves"] as Dictionary).get(K.anim_id, {})
		var live := _upper(c) if bool(mv.get("upper", false)) else c.cur
		if live != "" and String(r["clip"]) == "":
			r["clip"] = live
			r["len"] = c.lib.get_animation(live).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	print("TIME %s play %.2f in %.2f hit %.2f (clip %.2f) %s %.2f out %.2f"
			% [moves[0], r["play"], r["in"], r["hit"], r["at"], r["clip"], r["len"], r["out"]])
	return r

## The clip on the upper-body channel (a move with "upper": the legs keep walking under it).
func _upper(c: WardenClips) -> String:
	return ((c.tree.tree_root as AnimationNodeBlendTree).get_node("anim_u") as AnimationNodeAnimation).animation

## `r` (a _time result) read against the footage: the clip owns the body by BLEND_IN, the kit's event lands within
## `ev` s of the press, and the body is back with the legs by the clip's end + HAND_BACK (a move he holds: no `out`).
func _beats(what: String, r: Dictionary, ev: float, held := false) -> void:
	var out := float(r["out"])
	var back: bool = held or (out > 0.0 and out <= float(r["hit"]) + float(r["len"]) + HAND_BACK + 0.05)
	C.ok("%s: owns the body by %.2f s, the beat lands by %.2f s, the legs are back after" % [what, BLEND_IN, ev],
		float(r["in"]) >= 0.0 and float(r["in"]) <= BLEND_IN + 0.001 and float(r["hit"]) >= 0.0
			and float(r["hit"]) <= ev + 0.001 and back,
		"in %.2f hit %.2f out %.2f clip %s %.2f" % [r["in"], r["hit"], r["out"], r["clip"], r["len"]])

## LMB: the orb leaves on the press's frame and the flick plays with it (source: an orb about every 0.6 s, one-hand
## flicks); the flick is upper body so he keeps drifting; a full orb has its own, longer flick.
func _orb(m: Match, P: Hunter, K: OstraKit, home: Vector3) -> void:
	C.aim_at(P, home + Vector3(6.0, 0, 0))
	K.last_shot_t = m.time - 0.1           # (a shot a moment ago: the wait has not charged this one)
	P.fire_cd = 0.0
	var n0 := P.shot_n
	P.inp["fire"] = true
	var tap := func(t: float) -> void: P.inp["fire"] = t < 0.1
	var r := _time(m, P, K, ["ostra_orb"], 0.9, func() -> bool: return P.shot_n > n0, tap)
	_beats("LMB orb", r, 0.05)
	var mv: Dictionary = _clips(P).d["kmoves"]["ostra_orb"]
	C.ok("LMB orb: the flick is the one-hand clip, upper body (legs keep drifting)",
		String(r["clip"]).begins_with("orb") and bool(mv.get("upper", false)))
	_settle(m, P, K, home, 1.6)
	n0 = P.shot_n
	K.last_shot_t = -9.0                   # (a long wait: the full orb)
	P.fire_cd = 0.0
	r = _time(m, P, K, ["ostra_orb_hot"], 1.0, func() -> bool: return P.shot_n > n0, tap)
	_beats("LMB full orb", r, 0.05)
	C.ok("LMB full orb: his own, longer flick than the plain one's",
		String(r["clip"]) == "orb_hot" and float(r["len"]) > 0.4, "%s %.2f" % [r["clip"], r["len"]])
	_settle(m, P, K, home, 0.8)

## RMB: the wind-up holds its loaded pose, the shard leaves on the release and the shove clip plays with it
## (source: a black sphere at the hand for a frame, the shard cluster on the next: released by 2 frames).
func _snap(m: Match, P: Hunter, K: OstraKit, T: Hunter, home: Vector3) -> void:
	T.teleport(home + Vector3(6.0, 0, 0))
	C.fresh(T)
	C.aim_at(P, T.pos)
	var s0 := K.snaps
	P.ak.press_rmb()
	var r := _time(m, P, K, ["ostra_snap_wind", "ostra_snap"], 1.6, func() -> bool: return K.snaps > s0)
	_beats("RMB Snap", r, 2.0 * FRAME)
	C.ok("RMB Snap: released at the end of his 0.32 s wind-up, after the sphere frame",
		absf(float(r["hit"]) - 0.32) < 0.04 and float(r["hit"]) >= FRAME - 0.001, "%.2f" % r["hit"])
	_settle(m, P, K, home, 0.8)

## Shift: the aim pose holds while the key is down; the lantern leaves on the release (the lob clip's hand lets go
## at its 0.14 key) and the flight takes 1.8 s (source: cast 0158, teleport 0168, "about 1.8 s"); he arrives on the
## landing frame.
func _swap(m: Match, P: Hunter, K: OstraKit, T: Hunter, home: Vector3) -> void:
	T.teleport(home + Vector3(6.0, 0, 0))
	C.fresh(T)
	C.aim_at(P, T.pos)
	var s0 := K.swaps
	P.inp["dash_down"] = true
	var cast := [-1.0]
	var hold := func(t: float) -> void:
		P.inp["dash_down"] = t < 0.5
		if cast[0] < 0.0 and not K.swap.is_empty():
			cast[0] = t
	K.on_dash(false)
	var landed := func() -> bool: return K.swaps > s0
	var r := _time(m, P, K, ["ostra_swap_aim", "ostra_swap", "ostra_arrive"], 3.0, landed, hold)
	print("TIME swap cast %.2f" % cast[0])
	C.ok("Shift: the aim pose owns the body by %.2f s and the lantern leaves on the key's release" % BLEND_IN,
		float(r["in"]) >= 0.0 and float(r["in"]) <= BLEND_IN + 0.001 and cast[0] >= 0.5 and cast[0] <= 0.5 + 0.05,
		"in %.2f cast %.2f" % [r["in"], cast[0]])
	var flight: float = float(r["hit"]) - float(cast[0])
	C.ok("Shift: the flight takes the source's 1.8 s from the throw to the landing (and he lands then)",
		absf(flight - 1.8) < 0.05, "%.2f" % flight)
	C.ok("Shift: the body is back with the legs during the flight, before the landing frame",
		float(r["out"]) > cast[0] and float(r["out"]) < float(r["hit"]), "out %.2f" % r["out"])
	_settle(m, P, K, home, 0.8)

## E: the seed is down on the press and the palm turns over it by 0.2 s; the recast pops it, the fists clench in.
func _seed(m: Match, P: Hunter, K: OstraKit, T: Hunter, home: Vector3) -> void:
	T.teleport(home + Vector3(6.0, 0, 0))
	C.fresh(T)
	C.aim_at(P, T.pos)
	K.cast_e()
	var r := _time(m, P, K, ["ostra_seed"], 1.4, func() -> bool: return not K.seed.is_empty())
	_beats("E seed", r, FRAME)          # (source 0352: the orb drops within the cast's one frame)
	var p0 := K.pops
	K.e_recast()
	r = _time(m, P, K, ["ostra_pop"], 1.4, func() -> bool: return K.pops > p0)
	_beats("E recast pop", r, 0.05)
	_settle(m, P, K, home, 0.8)

## The lowest bone's height over his ground point, m (the hem: the model has no feet or legs to plant).
func _low(P: Hunter) -> float:
	var low := INF
	for sk in P.model.find_children("*", "Skeleton3D", true, false):
		for i in sk.get_bone_count():
			low = minf(low, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y)
	return low - P.pos.y

## His hover, as the model shows it (docs: about 0.3 m up, a slow +-0.03 m bob at 0.6 Hz) and that he never plants a
## foot: no bone is named for one, and the lowest bone keeps its gap standing, walking and jumping.
func _float(m: Match, P: Hunter, K: OstraKit, home: Vector3) -> void:
	var feet := []
	for sk in P.model.find_children("*", "Skeleton3D", true, false):
		for i in sk.get_bone_count():
			var nm: String = sk.get_bone_name(i).to_lower()
			if "foot" in nm or "leg" in nm or "toe" in nm or "shin" in nm or "thigh" in nm:
				feet.append(nm)
	var lo := [INF, -INF]
	for f in int(1.8 / DT):
		_frame(m, P)
		var g := _low(P)
		lo = [minf(lo[0], g), maxf(lo[1], g)]

	print("TIME float idle gap %.3f..%.3f feet %s" % [lo[0], lo[1], feet])
	var wl := [INF, -INF]
	P.inp["move"] = Vector2(1, 0)
	for f in int(1.0 / DT):
		_frame(m, P)
		var g := _low(P)
		wl = [minf(wl[0], g), maxf(wl[1], g)]
	P.inp["move"] = Vector2.ZERO
	print("TIME float walk gap %.3f..%.3f" % [wl[0], wl[1]])
	var mid: float = (lo[0] + lo[1]) * 0.5
	C.ok("he floats about 0.3 m over his ground point (source 0.25-0.35 m), the bob +-0.03 m",
		mid > 0.25 and mid < 0.35 and (lo[1] - lo[0]) < 0.08, "%.3f..%.3f" % [lo[0], lo[1]])
	C.ok("he never plants a foot: no foot bone, and walking keeps the gap (no step lowers him to the ground)",
		not feet.any(func(n): return "foot" in n or "toe" in n) and wl[0] > 0.2,
		"walk %.3f..%.3f, bones %s" % [wl[0], wl[1], feet])
