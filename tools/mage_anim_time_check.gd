extends RefCounted
## Sparkle's move timing through her clips (docs/heroes/mage.md, "Animation timing"), run inside --mage-combo-check:
## each keyed move is played in a real match with the model rendered, and what the footage gives
## (briefs/hero-ref/vireo.md, 0.2 s a frame) is checked against what the clips show: when a move's clip owns the
## body, the frame its hit or release lands on, when it hands the body back, and that no clip lets go of the arm
## before the move is done. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2       # s past a clip's end the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const CLIP_TOL := 0.04       # s: the GLB samples its clips at 30 fps, so a length can sit a frame long
const FRAMES := 2.5          # a kit event lands "on the press" within this many frames
const RMB_KEY := 0.06        # clip s: the rmb clip's release key (tools/art1/ryzz_clips.py)
const FULL := 0.999          # a clip owns the body at this weight
const RUN_TOL := 1.2       # m: two frames of the streak (40 m/s over 1/60 s); the travel stops on a frame
var C                        # the combo check (ok, ac)
var m: Match
var P: Hunter
var K: MageKit
var T: Hunter
var home: Vector3

func _init(check) -> void:
	C = check

func run(archetype_check: RefCounted) -> void:
	var r: Array = archetype_check.setup("mage", 6.0, "", true)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[4]
	K = P.ak
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Sparkle timing: her clips are on (nothing to time)", false)
		return
	_settle(0.6)
	_lmb()
	_lmb_held()
	_rmb()
	_wire()
	_sky()
	_kitefall()
	_run()
	_settle(0.6)
	await archetype_check.done(m)

func _clips() -> WardenClips:
	return P.model.get_node("Warden/Sync").get("clips") as WardenClips

func _frame() -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _settle(secs: float) -> void:
	for k in ["fire", "dash_down", "sec_hold", "e_down"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	K.strikes.clear()
	K.sparks.clear()               # no Static, no reset boost carried from the last move into the next
	K.reset_dash_boost = false
	T.hp = T.max_hp
	T.teleport(home + Vector3(30, 0, 8))
	P.teleport(home)
	P.dashes = P.max_dashes()
	for f in int(secs / DT):
		_frame()
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))

## Plays `secs` of frames and keeps, a frame each: t (s from the start), id (the kit's move), at (the move's
## clock, kmove_t), w (how much a clip owns the body), clip (the one playing), ph (Kitefall's phase), x.
func _rec(secs: float, each := Callable()) -> Array:
	var c := _clips()
	var out := []
	var t0 := m.time
	for f in int(secs / DT):
		if each.is_valid():
			each.call(m.time - t0)
		_frame()
		var live := c.cur
		if live == "" and c.up_w > 0.0:
			live = c.cur_u
		out.append({"t": m.time - t0, "id": K.anim_id, "at": m.time - K.anim_at, "w": maxf(c.act_w, c.up_w),
				"clip": live, "ph": K.ult.phase(), "x": P.pos.x, "z": P.pos.z, "hp": T.hp})
	return out

## The first frame's t where `pred` holds (-1 when none).
func _first(s: Array, pred: Callable) -> float:
	for f in s:
		if pred.call(f):
			return float(f["t"])
	return -1.0

## When the move `id` first owns the body.
func _in(s: Array, id: String) -> float:
	return _first(s, func(f: Dictionary) -> bool: return f["id"] == id and float(f["w"]) >= FULL)

## When the move is first played (the kit's call), from the start.
func _play(s: Array, id: String) -> float:
	return _first(s, func(f: Dictionary) -> bool: return f["id"] == id)

## Between `from` and `to` (s), the first frame the body is not fully a clip's: a let-go inside a move.
func _drop(s: Array, from: float, to: float) -> float:
	return _first(s, func(f: Dictionary) -> bool:
		return float(f["t"]) >= from and float(f["t"]) < to and float(f["w"]) < FULL)

## The first frame after `from` that the clips are off the body (the legs are hers again).
func _out(s: Array, from: float) -> float:
	return _first(s, func(f: Dictionary) -> bool: return float(f["t"]) > from and float(f["w"]) <= 0.0)

func _at(s: Array, t: float) -> Dictionary:
	for f in s:
		if float(f["t"]) >= t - DT * 0.5:
			return f
	return s[-1]

## LMB: the round leaves and the move plays on the same frame, the clip's release key (0.06) lands inside the
## blend-in, the arm is back by the clip's end (0.35 s), the legs by the next.
func _lmb() -> void:
	P.ammo = 99
	P.fire_cd = 0.0
	var n0 := P.shot_n
	P.inp["fire"] = true
	var s := _rec(0.8, func(_t: float) -> void:
		if P.shot_n != n0:
			P.inp["fire"] = false)
	var hit := _first(s, func(f: Dictionary) -> bool: return P.shot_n > n0)
	var play := _play(s, "mage_lmb_l")
	var inn := _in(s, "mage_lmb_l")
	var clip_len := _clips().lib.get_animation("lmb_l").length
	var out := _out(s, play + clip_len)
	print("TIME mage_lmb play %.2f in %.2f hit %.2f clip %.2f out %.2f" % [play, inn, hit, clip_len, out])
	C.ok("Sparkle timing LMB: the bolt and its move leave on the press's frame, the clip owns the arm within the blend",
			hit >= 0.0 and hit <= DT * FRAMES and play >= 0.0 and play <= DT * FRAMES and inn >= 0.0
				and inn <= BLEND_IN,
			"hit %.2f play %.2f in %.2f" % [hit, play, inn])
	C.ok("Sparkle timing LMB: the arm and legs are hers again within a fade of the clip's end (0.35 s)",
			absf(clip_len - 0.35) < CLIP_TOL and out > clip_len - DT and out < clip_len + HAND_BACK,
				"len %.2f out %.2f" % [clip_len, out])
	P.inp["fire"] = false
	_settle(0.8)

## LMB held (the source: one bolt every 0.8 s; ours 0.648, the owner's item 116): a bolt every 0.648 s, the hands
## alternate, each bolt re-plays its clip from the start.
func _lmb_held() -> void:
	P.ammo = 99
	P.fire_cd = 0.0
	P.inp["fire"] = true
	var n0 := P.shot_n
	var rounds: Array = []
	var ids: Array = []
	var t0 := m.time
	for f in int(2.2 / DT):
		_frame()
		if P.shot_n != n0:
			n0 = P.shot_n
			rounds.append(m.time - t0)
			ids.append(K.anim_id)
	P.inp["fire"] = false
	var gap := (float(rounds[-1]) - float(rounds[0])) / maxf(rounds.size() - 1, 1) if rounds.size() > 1 else 0.0
	print("TIME mage_lmb held: %d bolts in 2.2 s, one every %.3f s (%s)" % [rounds.size(), gap, ids])
	C.ok("Sparkle timing LMB held: a bolt every 0.648 s, the hands alternating, each re-plays its clip",
			rounds.size() >= 3 and absf(gap - 0.648) < DT * 1.5 and ids[0] != ids[1] and ids[0] == ids[2],
			"%d bolts every %.3f s %s" % [rounds.size(), gap, ids])
	_settle(0.8)

## One Storm Rod: held `rel` s then let go (-1: held through the auto throw). Gives the beats from the press: the
## flash (full), the throw clip (play), the bolt leaving (coil) and when the hold pose let go before it.
func _rod(rel: float) -> Dictionary:
	_settle(0.5)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var n0: int = (m.get("shots") as Array).size()
	var rec := {"full": -1.0, "coil": -1.0}
	P.inp["sec_hold"] = true
	K.press_rmb()
	var s := _rec(2.5, func(t: float) -> void:
		P.inp["sec_hold"] = rel < 0.0 or t < rel
		if K.rod_full and float(rec["full"]) < 0.0:
			rec["full"] = t
		if (m.get("shots") as Array).size() > n0 and float(rec["coil"]) < 0.0:
			rec["coil"] = t)
	var play := _play(s, "mage_rmb")
	var held_in := _in(s, "mage_rmb_hold")
	var drop := _drop(s, held_in, play) if play > 0.0 else -1.0
	var clip_len := _clips().lib.get_animation("rmb").length
	var out := _out(s, play + clip_len) if play >= 0.0 else -1.0
	var how := "auto" if rel < 0.0 else "let go at %.1f" % rel
	print("TIME mage_rmb %s: hold in %.2f full %.2f throw clip %.2f bolt %.2f hold let go %.2f out %.2f"
			% [how, held_in, rec["full"], play, rec["coil"], drop, out])
	var r := {"full": rec["full"], "play": play, "coil": rec["coil"], "in": held_in, "drop": drop, "out": out,
		"len": clip_len}
	_settle(0.5)
	return r

## RMB Storm Rod (the source: press -> the rod appears, the white flash at 1.0 s, the throw at 1.2 s, about 0.4 s
## to recover): the hold clip owns the arm within the blend and keeps it to the throw, the flash is at 1.0, the
## auto throw at 1.2, and the throw clip's release key lands on the bolt (a tap's 0.33 s summon included).
func _rmb() -> void:
	var a := _rod(-1.0)
	C.ok("Sparkle timing RMB: the rod clip owns the arm within the blend and keeps it until the throw",
			float(a["in"]) >= 0.0 and float(a["in"]) <= BLEND_IN and float(a["drop"]) < 0.0,
			"in %.2f let go %.2f" % [a["in"], a["drop"]])
	C.ok("Sparkle timing RMB: the white flash at 1.0 s (the source's +5 frames), the auto throw at 1.2 s (+6)",
			absf(float(a["full"]) - 1.0) <= DT * 2.0 and absf(float(a["play"]) - 1.2) <= DT * 2.0
			and absf(float(a["coil"]) - float(a["play"])) <= DT * 2.0,
			"full %.2f throw %.2f bolt %.2f" % [a["full"], a["play"], a["coil"]])
	C.ok("Sparkle timing RMB: the arm recovers by the clip's end (0.7 s), the legs a fade after (source ~0.4 s)",
			absf(float(a["len"]) - 0.7) < CLIP_TOL and float(a["out"]) > float(a["play"]) + 0.6
			and float(a["out"]) < float(a["play"]) + float(a["len"]) + HAND_BACK,
			"len %.2f throw %.2f out %.2f" % [a["len"], a["play"], a["out"]])
	var b := _rod(1.0)
	C.ok("Sparkle timing RMB: let go at the flash, the throw clip and the bolt leave on that frame",
			absf(float(b["play"]) - 1.0) <= DT * 2.0 and absf(float(b["coil"]) - float(b["play"])) <= DT * 2.0,
			"throw %.2f bolt %.2f" % [b["play"], b["coil"]])
	var c := _rod(0.1)
	C.ok("Sparkle timing RMB: a tap's throw clip puts its release key (0.06 s) on the bolt (summon takes 0.33 s)",
			float(c["coil"]) >= 0.3 and absf(float(c["coil"]) - (float(c["play"]) + RMB_KEY)) <= DT * 2.0
			and float(c["drop"]) < 0.0,
			"throw %.2f bolt %.2f let go %.2f" % [c["play"], c["coil"], c["drop"]])

## Wirerun held `hold_s` s with a foe `foe` m ahead: the beats from the press.
func _wire_run(hold_s: float, foe: float) -> Dictionary:
	_settle(0.5)
	T.teleport(home + Vector3(foe, 0, 0))
	C.ac.aim_at(P, T.pos)
	var hp0 := T.hp
	P.inp["dash_down"] = true
	P.do_dash()
	var spot := home + Vector3(foe, 0, 0)
	var s := _rec(2.2, func(t: float) -> void:
		T.teleport(spot)               # the Arena dummy walks back toward her: held on its spot in the lane
		T.inv_t = 0.0                  # and open to the hit (its landing grace, match.on_drop_landed)
		C.ac.aim_at(P, T.pos)
		P.inp["dash_down"] = t < hold_s)
	var go := _play(s, "mage_dash_go")
	var land := _play(s, "mage_dash_land")
	var crouch := _in(s, "mage_dash")
	var hit := _first(s, func(f: Dictionary) -> bool: return float(f["hp"]) < hp0)
	var fa := _at(s, go - DT)
	var fb := _at(s, land + DT)
	var flat := Vector2(float(fb["x"]) - float(fa["x"]), float(fb["z"]) - float(fa["z"]))
	var dist := flat.length() if land > 0.0 else 0.0
	var run_t := land - go
	var out := _out(s, land)
	var drop := _drop(s, crouch, go) if crouch >= 0.0 and go > 0.0 else -1.0
	var hit_f := _at(s, hit) if hit >= 0.0 else {}
	var land_len := _clips().lib.get_animation("dash_land").length
	var hit_clip: String = hit_f.get("clip", "")
	print(("TIME mage_dash hold %.1f: crouch in %.2f let go %.2f, run %.2f -> %.2f (%.2f s, %.1f m, %.0f m/s), "
			+ "pass hit %.2f (%s), land %.2f, out %.2f")
			% [hold_s, crouch, drop, go, land, run_t, dist, dist / maxf(run_t, 0.01), hit, hit_clip, land, out])
	var r := {"crouch": crouch, "drop": drop, "go": go, "land": land, "run": run_t, "dist": dist, "hit": hit,
			"hit_clip": hit_clip, "out": out, "len": land_len}
	_settle(0.5)
	return r

## Wirerun (the source: ~0.2 s crouch, release, a streak at a constant speed, an abrupt stop, ~0.4 s to re-form; the
## pass hit as the body crosses): the crouch is held on its pose while she charges, the run takes length / 40 m/s
## (the owner's; the source's 30-37), the go pose is up before she stops, the pass hit lands in the streak and she
## re-forms over the land clip's 0.42 s.
func _wire() -> void:
	var a := _wire_run(1.0, 5.0)
	C.ok("Sparkle timing Wirerun: charged to the auto release (0.9 s) she stays in the crouch pose until the streak",
			float(a["crouch"]) >= 0.0 and float(a["crouch"]) <= BLEND_IN and float(a["drop"]) < 0.0
			and absf(float(a["go"]) - 0.9) <= DT * 2.0, "crouch in %.2f let go %.2f go %.2f" % [a["crouch"],
				a["drop"], a["go"]])
	var feel_t := float(K.dash_feel()["time"])     # the global dash feel (rules/dash_feel.json) slows every dash
	C.ok("Sparkle timing Wirerun: the full run goes 9.75 m at 40 m/s (the owner's; source ~32) times the dash feel",
			absf(float(a["dist"]) - 9.75) < RUN_TOL and absf(float(a["run"]) - 9.75 / 40.0 * feel_t) <= DT * 2.0
			and float(a["land"]) > float(a["go"]),
			"%.1f m in %.2f s" % [a["dist"], a["run"]])
	C.ok("Sparkle timing Wirerun: the pass hit lands inside the streak, on the go clip",
			float(a["hit"]) >= float(a["go"]) and float(a["hit"]) <= float(a["land"]) and a["hit_clip"] == "dash_go",
			"hit %.2f in %.2f..%.2f on %s" % [a["hit"], a["go"], a["land"], a["hit_clip"]])
	C.ok("Sparkle timing Wirerun: she re-forms over the land clip (0.42 s; source ~0.4), legs back a fade after",
			absf(float(a["len"]) - 0.42) < CLIP_TOL and float(a["out"]) > float(a["land"]) + 0.38
			and float(a["out"]) < float(a["land"]) + float(a["len"]) + HAND_BACK,
			"land %.2f len %.2f out %.2f" % [a["land"], a["len"], a["out"]])
	var b := _wire_run(0.0, 5.0)
	C.ok("Sparkle timing Wirerun: a tap runs 5.6 m at 40 m/s times the dash feel within a few frames",
			absf(float(b["dist"]) - 5.6) < RUN_TOL and absf(float(b["run"]) - 5.6 / 40.0 * feel_t) <= DT * 2.0
			and float(b["go"]) <= DT * 4.0, "go %.2f, %.1f m in %.2f s" % [b["go"], b["dist"], b["run"]])

## One Skycall: E held `drag` s from the press then let go, the strike's beats from the press.
func _sky_run(drag: float) -> Dictionary:
	_settle(0.5)
	K.cd["e"] = 0.0
	var at := home + Vector3(7.0, 0, 0)
	C.ac.aim_at(P, at)
	var rec := {"commit": -1.0}
	P.inp["e_down"] = true
	K.use_e()
	var s := _rec(drag + 0.8 + 0.8, func(t: float) -> void:
		C.ac.aim_at(P, at + Vector3(0, 0, 1.0) * minf(t, 0.3))
		P.inp["e_down"] = t < drag
		for st in K.strikes:
			if st["phase"] == "count" and float(rec["commit"]) < 0.0:
				rec["commit"] = t)
	var play := _play(s, "mage_e")
	var inn := _in(s, "mage_e")
	var snap := _play(s, "mage_e_snap")
	var snap_in := _in(s, "mage_e_snap")
	var drop := _drop(s, inn, snap) if snap > 0.0 else -1.0
	var at_snap := float(_at(s, snap)["at"]) if snap > 0.0 else -1.0
	var clip_len := _clips().lib.get_animation("sky").length
	var out := _out(s, snap + 0.3)
	print(("TIME mage_e drag %.1f: play %.2f in %.2f commit %.2f strike %.2f (%.2f after the commit) "
			+ "arm let go %.2f snap in %.2f out %.2f, sky clip %.2f")
			% [drag, play, inn, rec["commit"], snap, snap - float(rec["commit"]), drop, snap_in, out, clip_len])
	var r := {"play": play, "in": inn, "commit": rec["commit"], "snap": snap, "snap_in": snap_in, "drop": drop,
			"out": out, "len": clip_len, "at_snap": at_snap}
	_settle(0.5)
	return r

## Skycall (the source: the strike 0.8 s after the commit, a one-arm sweep, no long wind-up; the drag time is not
## shown): the arm goes up on the press and stays up through the drag (up to 1 s) and the 0.8 s count to the strike,
## then the snap clip sweeps it down on the strike's frame.
func _sky() -> void:
	var a := _sky_run(0.0)
	C.ok("Sparkle timing Skycall: the arm goes up on the press, owned within the blend",
			float(a["play"]) >= 0.0 and float(a["play"]) <= DT * FRAMES and float(a["in"]) >= 0.0
				and float(a["in"]) <= BLEND_IN,
			"play %.2f in %.2f" % [a["play"], a["in"]])
	C.ok("Sparkle timing Skycall: a tap strikes 0.8 s after the commit and the snap sweeps on that frame",
			absf(float(a["snap"]) - float(a["commit"]) - 0.8) <= DT * 2.0
				and float(a["snap_in"]) - float(a["snap"]) <= BLEND_IN
			and float(a["drop"]) < 0.0, "commit %.2f strike %.2f in %.2f let go %.2f" % [a["commit"],
				a["snap"], a["snap_in"], a["drop"]])
	var b := _sky_run(1.0)
	C.ok("Sparkle timing Skycall: dragged 1.0 s, the arm stays up through the count to the strike (clip 1.4 s)",
			float(b["commit"]) >= 0.95 and float(b["snap"]) > float(b["len"]) and float(b["drop"]) < 0.0
			and absf(float(b["snap"]) - float(b["commit"]) - 0.8) <= DT * 2.0,
			"commit %.2f strike %.2f (clip %.2f) arm let go %.2f" % [b["commit"], b["snap"], b["len"], b["drop"]])
	C.ok("Sparkle timing Skycall: the arm comes down over the snap clip (0.55 s) and the legs are hers a fade after",
			float(b["out"]) > float(b["snap"]) + 0.5 and float(b["out"]) < float(b["snap"]) + 0.55 + HAND_BACK,
			"strike %.2f out %.2f" % [b["snap"], b["out"]])

## One Kitefall: cast at 0, the second press at `recast` s (-1: none, she comes down by herself); the phases' times
## from the press and any frame the clips let go of the body inside the cast.
func _ult_run(recast: float) -> Dictionary:
	_settle(0.5)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	P.lvl = int(Hunter.ULT_AT[0])
	K.cd["x"] = 0.0
	C.ac.aim_at(P, T.pos)
	var cast := HunterKeys.ult_pressed(P)
	var pressed := {"done": false}
	var s := _rec(3.8, func(t: float) -> void:
		C.ac.aim_at(P, T.pos)
		if recast >= 0.0 and t >= recast and not bool(pressed["done"]):
			pressed["done"] = true
			HunterKeys.ult_pressed(P))
	var r := {"cast": cast}
	for ph in [MageUlt.CROUCH, MageUlt.RISE, MageUlt.AIR, MageUlt.FALL, MageUlt.AFTER]:
		r[ph] = _first(s, func(f: Dictionary) -> bool: return f["ph"] == ph)
	r["end"] = _first(s, func(f: Dictionary) -> bool: return f["ph"] == "" and float(f["t"]) > float(r[MageUlt.AFTER]))
	r["in"] = _in(s, "mage_x")
	r["drop"] = _drop(s, float(r["in"]), float(r["end"]))
	r["out"] = _out(s, float(r["end"]))
	print(("TIME mage_x recast %.1f: crouch %.2f rise %.2f air %.2f fall %.2f land %.2f end %.2f, "
			+ "clip in %.2f let go %.2f out %.2f")
			% [recast, r[MageUlt.CROUCH], r[MageUlt.RISE], r[MageUlt.AIR], r[MageUlt.FALL], r[MageUlt.AFTER],
			r["end"], r["in"], r["drop"], r["out"]])
	_settle(0.5)
	return r

## Kitefall (the source: the leap ~0.4 s after the press, up 1.2-1.8 s, the streak down, the pillar after): the
## crouch is 0.3 s (the data; the source's frames give 0.4-0.6), the climb 0.3, the hover 1.7 (inside the source's
## 1.2-1.8), the drop 0.2, the strike's re-form 0.5, and one clip or another owns the body from the press to the
## re-form's end.
func _kitefall() -> void:
	var a := _ult_run(-1.0)
	var xd := K.x_def()
	var rise_at := float(xd["windup"])
	C.ok("Sparkle timing Kitefall: crouch 0.3, climb 0.3, hover 1.7 (source 1.2-1.8), drop 0.2, re-form 0.5 s",
			bool(a["cast"]) and absf(float(a[MageUlt.RISE]) - rise_at) <= DT * 2.0
			and absf(float(a[MageUlt.AIR]) - float(a[MageUlt.RISE]) - float(xd["rise"])) <= DT * 2.0
			and absf(float(a[MageUlt.FALL]) - float(a[MageUlt.AIR]) - float(xd["hover"])) <= DT * 2.0
			and absf(float(a[MageUlt.AFTER]) - float(a[MageUlt.FALL]) - float(xd["drop"])) <= DT * 2.0
			and absf(float(a["end"]) - float(a[MageUlt.AFTER]) - float(xd["after"])) <= DT * 2.0,
			"%.2f %.2f %.2f %.2f %.2f %.2f" % [a[MageUlt.CROUCH], a[MageUlt.RISE], a[MageUlt.AIR], a[MageUlt.FALL],
			a[MageUlt.AFTER], a["end"]])
	C.ok("Sparkle timing Kitefall: a clip owns the body from the crouch to the re-form's end (no let-go)",
			float(a["in"]) >= 0.0 and float(a["in"]) <= BLEND_IN and float(a["drop"]) < 0.0
			and float(a["out"]) >= float(a["end"]) - DT, "in %.2f let go %.2f out %.2f end %.2f" % [a["in"],
				a["drop"], a["out"], a["end"]])
	var b := _ult_run(0.8)
	C.ok("Sparkle timing Kitefall: a second press in the hover brings her down at once (drop 0.2 s)",
			float(b[MageUlt.FALL]) >= 0.8 - DT and float(b[MageUlt.FALL]) <= 0.8 + DT * 3.0
			and absf(float(b[MageUlt.AFTER]) - float(b[MageUlt.FALL]) - float(xd["drop"])) <= DT * 2.0
			and float(b["drop"]) < 0.0, "fall %.2f land %.2f let go %.2f" % [b[MageUlt.FALL],
				b[MageUlt.AFTER], b["drop"]])

## The run: the clip's rate at her speed, the stride cycle in Hz and metres, against the sheet's six-hunter measure
## (briefs/hero-ref/vireo.md: ~2.3 Hz, short steps) for the report; nothing asserted, the re-key is the model's.
func _run() -> void:
	_settle(0.3)
	P.inp["move"] = Vector2(0, 1)
	for f in int(1.5 / DT):
		_frame()
	var c := _clips()
	var spd := Vector2(P.vel.x, P.vel.z).length()
	var rate := float(c.tree.get("parameters/loco_rate/scale"))
	var hz := rate / c.lib.get_animation("run_f").length
	print("TIME run: %.2f m/s, clip rate %.2f, a stride cycle at %.2f Hz (%.1f steps/s), %.2f m (%.2f bh) a cycle"
			% [spd, rate, hz, hz * 2.0, spd / hz, spd / hz / 1.8])
	C.ok("Sparkle timing run: she runs and the clip plays at the speed (the cadence is the model's re-key)",
			spd > 3.0 and rate > 0.5, "%.2f m/s rate %.2f" % [spd, rate])
	P.inp["move"] = Vector2.ZERO
