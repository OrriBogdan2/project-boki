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
	var tail := 0                  # frames the body was letting go while the kit still played a move
	var prev := K.anim_id
	for f in int(secs / DT):
		if each.is_valid():
			each.call(m.time - t0)
		_frame(m, P)
		var t := m.time - t0
		var w0 := maxf(c.act_w, c.up_w)
		# a hand-off gap: the move's clip let go before the kit handed the body to its next move
		if K.anim_id != prev and K.anim_id != "" and prev != "":
			r["gaps"] = int(r["gaps"]) + tail
		prev = K.anim_id
		tail = tail + 1 if owned and w0 < 0.999 else 0
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
		if String(r["clip"]) == "":
			r["clip"] = String(c.d["kmoves"][move]["clip"])
			r["len"] = c.lib.get_animation(String(r["clip"])).length
		# a gap: the kit still plays the move but its clip let go of the body
		if owned and w < 0.999 and m.time - K.anim_at < KMovesCare.length(move) - DT:
			r["gaps"] = int(r["gaps"]) + 1
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	print("TIME %s play %.2f in %.2f hit %.2f (clip %.2f) %s %.2f out %.2f gaps %d"
			% [move, r["play"], r["in"], r["hit"], r["at"], r["clip"], r["len"], r["out"], r["gaps"]])
	return r

## LMB, held 1.5 s: every ember plays its move on the frame it leaves, 0.4 s apart, the hands alternating
## (the first after a pause is the Empowered one), and the clips hold the body from one shot to the next.
func _lmb(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	C.sc.aim_at(P, home + Vector3(6.0, 0, 0))
	K.anim_id = ""
	var c := _clips(P)
	var shots: Array = []          # [s from the press, the move it played, s from the shot to that move's start]
	var n := P.shot_n
	var gaps := 0
	var t0 := m.time
	P.inp["fire"] = true
	for f in int(1.5 / DT):
		_frame(m, P)
		if not shots.is_empty() and String(shots[-1][1]) == "":
			shots[-1][1] = K.anim_id
			shots[-1][2] = K.anim_at - t0 - float(shots[-1][0])
		if P.shot_n != n:
			n = P.shot_n
			shots.append([m.time - t0, "", 0.0])
		if shots.size() > 1 and maxf(c.act_w, c.up_w) < 0.999:
			gaps += 1
	P.inp["fire"] = false
	var line := "TIME lmb"
	var steady := shots.size() >= 4
	var synced := true
	var alternate := true
	for i in shots.size():
		line += " %.2f %s" % [shots[i][0], String(shots[i][1]).trim_prefix("mm_shot_")]
		synced = synced and absf(float(shots[i][2])) < DT * 1.5
		if i >= 2:
			steady = steady and absf(float(shots[i][0]) - float(shots[i - 1][0]) - 0.4) < DT * 1.5
			alternate = alternate and shots[i][1] != shots[i - 1][1]
	print(line, " gaps %d" % gaps)
	C.ok("mm timing LMB: an ember every 0.4 s, each move starting on its ember's frame", steady and synced)
	C.ok("mm timing LMB: the hands alternate shot to shot (the source's left-right)", alternate)
	C.ok("mm timing LMB: no frame between two embers drops back to the legs", gaps == 0)
	_settle(m, P, home, 0.8)

## RMB: the seed_aim wind-up (1.0 s), then the hop and throw. No frame between them may lose the body.
func _rmb(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	C.sc.aim_at(P, home + Vector3(6.0, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.press_rmb()
	# the seed's move starts the frame the wind-up throws: 1.1 s in, play -0.1 means the throw at 1.0 s
	var aim := _time(m, P, K, "mm_seed_aim", 1.1, func() -> bool: return not K.seed_aim)
	var hop := _time(m, P, K, "mm_seed", 0.6, func() -> bool: return false)
	C.ok("mm timing RMB: the 1.0 s wind-up (the source's) throws on its clip's last frame, no gap into the hop",
			absf(1.1 + float(hop["play"]) - 1.0) < DT * 1.5 and absf(float(aim["len"]) - 1.0) < DT
			and int(aim["gaps"]) + int(hop["gaps"]) == 0)
	_settle(m, P, home, 0.8)

## E, then E again: the lantern lifted, then thrown (the toss lands within a footage frame).
func _hearth(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	C.sc.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["e"] = 0.0
	K.cast_e()
	var lit := _time(m, P, K, "mm_hearth", 0.7, func() -> bool: return not K.hearth.is_empty())
	K.e_recast()
	var toss := _time(m, P, K, "mm_toss", 0.6, func() -> bool: return K.hearth.get("tossed", false))
	C.ok("mm timing E: the lift and the toss each own the body within the 0.1 s blend, with no gap",
			float(lit["in"]) <= BLEND_IN and float(toss["in"]) <= BLEND_IN
			and int(lit["gaps"]) + int(toss["gaps"]) == 0)
	_settle(m, P, home, 0.8)

## X: the tether on a teammate, held, then ended.
func _x(m: Match, P: Hunter, K: TenderKit, A: Hunter, home: Vector3) -> void:
	P.lvl = 6
	K.cd["x"] = 0.0
	A.teleport(home + Vector3(4.0, 0, 0))
	C.sc.aim_at(P, A.pos)
	HunterKeys.ult_pressed(P)
	var cast := _time(m, P, K, "mm_call", 0.5, func() -> bool: return not K.hearth_call.is_empty())
	_time(m, P, K, "mm_call_hold", 1.0, func() -> bool: return not K.hearth_call.is_empty())
	C.ok("mm timing X: the cast hands the body to the channel within the clip (ring by f28, 0.3 s), no gap",
			KMovesCare.length("mm_call") <= float(cast["len"]) + 0.001 and int(cast["gaps"]) == 0)
	K._call_end(true)
	var end := _time(m, P, K, "mm_call_end", 0.8, func() -> bool: return true)
	C.ok("mm timing X: the end hands back to the legs inside the source's f74-f77 (0.4 s + the blend)",
			float(end["out"]) > 0.0 and float(end["out"]) <= 0.4 + BLEND_IN + 0.05)
	_settle(m, P, home, 0.8)

func _dashes(m: Match, P: Hunter, K: TenderKit, home: Vector3) -> void:
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(false)
	var skip := _time(m, P, K, "mm_skip", 0.6, func() -> bool: return P.roll_t > 0.0)
	C.ok("mm timing dash: the ground skip owns the body within the blend and covers the dash",
			float(skip["in"]) >= 0.0 and float(skip["in"]) <= BLEND_IN and float(skip["len"]) >= 0.174)
	_settle(m, P, home, 0.6)
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	P.ex_cd = 0.0
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(true)
	var glide := _time(m, P, K, "mm_float", 1.4, func() -> bool: return P.roll_t > 0.0)
	C.ok("mm timing glide: the float clip covers the 0.95 s glide (Elluna's 0.8-1.1 s), no gap",
			float(glide["in"]) <= BLEND_IN and float(glide["len"]) >= 0.95 and int(glide["gaps"]) == 0)
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
