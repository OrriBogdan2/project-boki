extends RefCounted
## Meeko's move timing through her clips (docs/heroes/tender.md, "Animation timing"), run inside
## --tender-combo-check: each keyed move is played in a real match with the model rendered, and the beats the
## footage gives (briefs/hero-ref/mooshmoosh.md, 0.2 s a frame, 0.1 s for the ult) are checked against what
## the clip shows: when it blends in, the frame its release lands on, when it hands the body back, and that
## no frame between two moves falls back to the standing pose. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const FRAME := 0.2           # s: one frame of the 5 fps footage
var C                        # the combo check (ok, sc)

func _init(check) -> void:
	C = check

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
	for f in int(secs / DT):
		_frame(m, P)

func run(m: Match, P: Hunter, K: TenderKit, A: Hunter, home: Vector3) -> void:
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Meeko timing: her clips are on (nothing to time)", false)
		return
	_settle(m, P, home, 0.6)
	_lmb(m, P, K, home)
	_rmb(m, P, K, home)
	_hearth(m, P, K, home)
	_x(m, P, K, A, home)
	_dashes(m, P, K, home)
	_run(m, P, home)
	_settle(m, P, home, 1.0)

## Plays `secs` of frames and reads the move's beats off the clips, in s from the start: when the kit plays it
## (play), when it owns the body (in), when `event` turns true (hit) and how far into the clip that is (at),
## the clip and its length, and when the body is back with the legs (out). `gaps` counts the frames the move
## was playing but no clip owned the body.
func _time(m: Match, P: Hunter, K: TenderKit, move: String, secs: float, event: Callable,
		each := Callable()) -> Dictionary:
	var c := _clips(P)
	var r := {"play": -1.0, "in": -1.0, "hit": -1.0, "at": -1.0, "clip": "", "len": 0.0, "out": -1.0, "gaps": 0}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		if each.is_valid():
			each.call(m.time - t0)
		_frame(m, P)
		var t := m.time - t0
		if K.anim_id != move:
			continue
		if float(r["play"]) < 0.0:
			r["play"] = K.anim_at - t0
		var w := maxf(c.act_w, c.up_w)
		if float(r["in"]) < 0.0 and w >= 0.999:
			r["in"] = t
		if float(r["hit"]) < 0.0 and event.call():
			r["hit"] = t
			r["at"] = m.time - K.anim_at
		var live := c.cur
		if live == "" and c.up_w > 0.0:
			live = c.cur_u
		if live != "" and String(r["clip"]) == "":
			r["clip"] = live
			r["len"] = c.lib.get_animation(live).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	print("TIME %s play %.2f in %.2f hit %.2f (clip %.2f) %s %.2f out %.2f"
			% [move, r["play"], r["in"], r["hit"], r["at"], r["clip"], r["len"], r["out"]])
	return r

## LMB: the ember leaves and the move plays on the same frame, every 0.4 s from alternating hands.
func _lmb(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	C.sc.aim_at(P, home + Vector3(6.0, 0, 0))
	K.anim_id = ""
	var n0 := P.shot_n
	P.inp["fire"] = true
	_time(m, P, K, "mm_shot_r", 0.6, func() -> bool: return P.shot_n > n0)
	P.inp["fire"] = false
	_settle(m, P, home, 0.8)

## RMB: the seed_aim wind-up (1.0 s), then the hop and throw. No frame between them may lose the body.
func _rmb(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	C.sc.aim_at(P, home + Vector3(6.0, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.press_rmb()
	_time(m, P, K, "mm_seed_aim", 1.0, func() -> bool: return not K.seed_aim)
	_time(m, P, K, "mm_seed", 0.6, func() -> bool: return false)
	_settle(m, P, home, 0.8)

## E, then E again: the lantern lifted, then thrown.
func _hearth(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	K.cd["e"] = 0.0
	P.inp["sig"] = true
	_time(m, P, K, "mm_hearth", 0.5, func() -> bool: return not K.hearth.is_empty(),
			func(_t): P.inp["sig"] = false)
	P.inp["sig"] = true
	_time(m, P, K, "mm_toss", 0.5, func() -> bool: return K.hearth.get("tossed", false),
			func(_t): P.inp["sig"] = false)
	_settle(m, P, home, 0.8)

## X: the tether on a teammate, held, then ended.
func _x(m: Match, P: Hunter, K: TenderKit, A: Hunter, home: Vector3) -> void:
	P.lvl = 6
	K.cd["x"] = 0.0
	A.teleport(home + Vector3(4.0, 0, 0))
	C.sc.aim_at(P, A.pos)
	HunterKeys.ult_pressed(P)
	_time(m, P, K, "mm_call", 0.5, func() -> bool: return not K.hearth_call.is_empty())
	_time(m, P, K, "mm_call_hold", 1.0, func() -> bool: return not K.hearth_call.is_empty())
	K.call("_call_end", true)
	_time(m, P, K, "mm_call_end", 0.8, func() -> bool: return true)
	_settle(m, P, home, 0.8)

func _dashes(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	_time(m, P, K, "mm_skip", 0.6, func() -> bool: return P.roll_t > 0.0, func(_t): P.inp["dash"] = false)
	_settle(m, P, home, 0.6)
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	P.ex_cd = 0.0
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(true)
	_time(m, P, K, "mm_float", 1.4, func() -> bool: return P.roll_t > 0.0)
	_settle(m, P, home, 0.6)

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
