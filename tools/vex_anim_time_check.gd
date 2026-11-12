extends RefCounted
## Vex's move timing through her clips (docs/heroes/gunslinger.md, "Animation timing"), run inside
## --gunslinger-combo-check: each keyed move is played in a real match with the model rendered, and the frames
## the footage gives (briefs/hero-ref/venator.md, 0.2 s a frame) are checked against what the clip shows: when
## it blends in, the frame its visible release lands on (read off vex.glb's keys) against the kit's effect, when
## it hands the body back, and that the legs walk (not freeze in the clip) when she walks out of a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2       # s past a clip's end the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const SLIDE_UP := 0.62       # s: the dash clip's stand-up key (tools/art1/vex_clips.py): the skid ends before it
const CLIP_TOL := 0.04       # s: the GLB samples its clips at 30 fps, so a length can sit a frame long
const KEY_DT := 1.0 / 30.0   # s: vex.glb's key spacing
const FRAME := 0.2           # s: one footage frame (5 fps): a visible release this close to its effect is on it
const ROUND_GAP := [0.12, 0.14]   # s between rounds held: the source's ten rounds in about 1.4 s
var C                        # the combo check (ok, ac)

func _init(check) -> void:
	C = check

func run(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Vex timing: her clips are on (nothing to time)", false)
		return
	_settle(m, P, home, 0.6)
	_clip_ends(P)
	_lmb(m, P, K, home)
	_lmb_held(m, P, K, home)
	_rmb(m, P, K, home)
	_dash(m, P, K, home)
	_slide(m, P, K, home)
	_dash_firing(m, P, K, home)
	_needle(m, P, K, T, home)
	_nuke(m, P, K, home)
	_knock(m, P, K, T, home)
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
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	P.inp["dash_down"] = false
	P.teleport(home)
	for f in int(secs / DT):
		_frame(m, P)

## Plays `secs` of frames from a press and reads the move's beats off the clips, in s from the press: when the
## kit plays it (play), when it owns the body (in), when the kit's event fires (hit, `event` turns true) and how
## far into the clip that is (at), the clip and its length, and when the body is back with the legs (out).
func _time(m: Match, P: Hunter, K: GunslingerKit, move: String, secs: float, event: Callable,
		each := Callable()) -> Dictionary:
	var c := _clips(P)
	var r := {"play": -1.0, "in": -1.0, "hit": -1.0, "at": -1.0, "clip": "", "len": 0.0, "out": -1.0}
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

## Walks forward from `from` s after the press and reads, at `until`, how the body is shared: the full-body
## channel (the clip's legs) against the upper one (the legs walking) and her ground speed.
func _walk_probe(P: Hunter, from: float, until: float, rec: Dictionary) -> Callable:
	return func(t: float) -> void:
		if t >= from:
			P.inp["move"] = Vector2(0, 1)
		if t >= until and not rec.has("speed"):
			var c := _clips(P)
			rec["speed"] = Vector2(P.vel.x, P.vel.z).length()
			rec["full"] = c.act_w
			rec["upper"] = c.up_w

func _walk_line(what: String, rec: Dictionary) -> String:
	return "%s: %.1f m/s, full %.2f upper %.2f" % [what, rec.get("speed", 0.0), rec.get("full", 0.0),
			rec.get("upper", 0.0)]

## Walking under a move: she moves, the clip is on the upper channel only and the legs (full channel) are free.
func _legs_walk(rec: Dictionary) -> bool:
	return float(rec.get("speed", 0.0)) > 1.0 and float(rec.get("upper", 0.0)) >= 0.99 \
			and float(rec.get("full", 1.0)) <= 0.01

## LMB: the round leaves and the move plays on the same frame (its kick is the next), a round every 0.12 s.
func _lmb(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	P.ammo = 30
	P.fire_cd = 0.0
	K.anim_id = ""
	var n0 := P.shot_n
	P.inp["fire"] = true
	var r := _time(m, P, K, "gunslinger_lmb", 0.3, func() -> bool: return P.shot_n > n0)
	P.inp["fire"] = false
	C.ok("Vex timing LMB: the round and its move leave on the press's frame, the clip is on within a frame",
			float(r["hit"]) >= 0.0 and float(r["hit"]) <= DT * 2.5 and absf(float(r["play"]) - float(r["hit"])) < DT
			and float(r["in"]) <= BLEND_IN, "hit %.2f play %.2f in %.2f" % [r["hit"], r["play"], r["in"]])
	_release("LMB kick", float(r["play"]) + _snap(P, "gunslinger_lmb", "forearm.R", 0.0, 0.2), float(r["hit"]))
	_settle(m, P, home, 0.8)

## RMB (item 112, a launcher tap): the Burr leaves on the press; the launcher swings over 0.5 s and the legs
## keep walking under it ("upper": "moving").
func _rmb(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var n0 := K.burrs.size()
	var walk := {}
	K.press_rmb()
	var r := _time(m, P, K, "gunslinger_rmb", 1.0, func() -> bool: return K.burrs.size() > n0,
			_walk_probe(P, 0.1, 0.35, walk))
	C.ok("Vex timing RMB: fired on the press, the swing on within a frame, the arm back by 0.5 s + the fade",
			float(r["hit"]) <= DT and float(r["in"]) <= BLEND_IN and absf(float(r["len"]) - 0.5) < CLIP_TOL
			and float(r["out"]) < 0.5 + HAND_BACK, "in %.2f len %.2f out %.2f" % [r["in"], r["len"], r["out"]])
	C.ok("Vex timing RMB: walking through it, the legs walk (the swing is upper body)",
			_legs_walk(walk),
			_walk_line("at 0.35", walk))
	_release("RMB Burr", float(r["play"]) + _snap(P, "gunslinger_rmb", "forearm.L", 0.0, 0.3), float(r["hit"]))
	_settle(m, P, home, 0.8)

## Shift tap: the skid is the roll (0.45 s x the dash feel), the clip has her up by 0.62 and ready by 0.85: the
## source's "upright by 0.55-0.6, about 0.6 start to stand" within a frame. Walking out of it, the legs walk.
func _dash(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	P.inp["move"] = Vector2.ZERO
	var r := _time(m, P, K, "gunslinger_dash", 1.3, func() -> bool: return K.slide.is_empty())
	C.ok("Vex timing Shift tap: the skid ends before the clip's stand-up key, the clip runs 0.85 s, legs back by 1.05",
			float(r["hit"]) >= 0.45 - DT and float(r["hit"]) <= SLIDE_UP and absf(float(r["len"]) - 0.85) < CLIP_TOL
			and float(r["out"]) > 0.85 and float(r["out"]) < 0.85 + HAND_BACK,
			"skid %.2f len %.2f out %.2f" % [r["hit"], r["len"], r["out"]])
	var keys := _slide_keys(P)
	_release("Shift low", float(r["play"]) + float(keys[0]), 0.0)
	_release("Shift tap stand-up", float(r["play"]) + float(keys[1]), float(r["hit"]))
	_settle(m, P, home, 0.8)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var walk := {}
	_time(m, P, K, "gunslinger_dash", 1.0, func() -> bool: return K.slide.is_empty(), _walk_probe(P, 0.0, 0.75, walk))
	C.ok("Vex timing Shift tap: walking straight out of the skid, the legs are hers again by 0.75 s",
			float(walk.get("speed", 0.0)) > 1.0 and float(walk.get("full", 1.0)) <= 0.01, _walk_line("at 0.75", walk))
	_settle(m, P, home, 0.8)

## Shift held: the clip stays on its slide key while the skid lasts (0.18 + 0.55 s), so she stands up as it
## ends, not a quarter second into it.
func _slide(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.inp["dash_down"] = true
	P.do_dash()
	var hold := func(t: float) -> void:
		P.inp["dash_down"] = t < 1.5
		P.inp["move"] = Vector2(0, 1) if t < 0.1 else Vector2.ZERO
	var r := _time(m, P, K, "gunslinger_dash", 1.8, func() -> bool: return K.slide.is_empty(), hold)
	C.ok("Vex timing Shift held: she slides 0.73 s low (the clip held on its slide key) and stands up as it ends",
			float(r["hit"]) > 0.7 and float(r["hit"]) < 0.8 and float(r["at"]) <= 0.45 + DT * 2
			and float(r["out"]) > float(r["hit"]) + 0.4 - DT and float(r["out"]) < float(r["hit"]) + 0.4 + HAND_BACK,
			"skid %.2f clip at %.2f out %.2f" % [r["hit"], r["at"], r["out"]])
	_release("Shift held stand-up", float(r["hit"]) + float(_slide_keys(P)[1]) - float(r["at"]), float(r["hit"]))
	_settle(m, P, home, 0.8)

## E: the charge is 0.6 s (the source's cast bar), the beam at 0.63 lands on the clip's fire key (0.65), the
## recoil and settle run to 1.05: the source's beam at 0.6, a 0.2 s shove and about 0.4 s to recover. Walking
## off after the shove, the legs walk.
func _needle(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	C.ac.fresh(T)
	T.teleport(home + Vector3(8.0, 0, 0))
	_settle(m, P, home, 0.2)
	C.ac.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	var hits0 := K.needle_hits
	var walk := {}
	K.use_e()
	var r := _time(m, P, K, "gunslinger_e", 1.5, func() -> bool: return K.needle_hits > hits0,
			_walk_probe(P, 0.85, 1.05, walk))
	C.ok("Vex timing E: the beam fires at 0.63 s on the clip's fire key, the move settles by 1.05 s + the fade",
			absf(float(r["hit"]) - 0.63) <= DT * 2 and absf(float(r["at"]) - 0.63) <= DT * 2
			and absf(float(r["len"]) - 1.05) < CLIP_TOL and float(r["out"]) < 1.05 + HAND_BACK,
			"hit %.2f len %.2f out %.2f" % [r["hit"], r["len"], r["out"]])
	C.ok("Vex timing E: walking off after the shove, the legs are hers again by 1.05 s",
			float(walk.get("speed", 0.0)) > 1.0 and float(walk.get("full", 1.0)) <= 0.01, _walk_line("at 1.05", walk))
	_release("E beam", float(r["play"]) + _snap(P, "gunslinger_e", "hand.L", 0.3, 1.0), float(r["hit"]))
	_settle(m, P, home, 0.5)

## R: the barrel comes up over 0.1 s and the shot leaves on its kick key (0.14 s), not at the press: the source's
## raise, then fire. The arm is back by 0.6 s (the source's 0.8 s is within a frame). Walking, the legs walk.
func _nuke(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(8.0, 0, 0))
	K.cd["x"] = 0.0
	var walk := {}
	K.cast_ult()
	var fired := func() -> bool:
		return K.ult.shells.size() > 0 and bool((K.ult.shells[0] as Dictionary).get("fired", true))
	var r := _time(m, P, K, "gunslinger_x", 1.0, fired, _walk_probe(P, 0.0, 0.3, walk))
	C.ok("Vex timing R: the shot leaves on the raised barrel (0.14 s), the arm is down by 0.6 s + the fade",
			absf(float(r["hit"]) - GunslingerUlt.FIRE_T) <= DT * 1.5 and absf(float(r["len"]) - 0.6) < CLIP_TOL
			and float(r["out"]) < 0.6 + HAND_BACK, "hit %.2f len %.2f out %.2f" % [r["hit"], r["len"], r["out"]])
	C.ok("Vex timing R: walking through the cast, the legs walk (the raise is upper body)",
			_legs_walk(walk),
			_walk_line("at 0.3", walk))
	# the kick past the raise (the arm goes up on clip 0-0.03, the barrel kicks on 0.1-0.13)
	_release("R shot", float(r["play"]) + _snap(P, "gunslinger_x", "forearm.L", 0.05, 0.3), float(r["hit"]))
	_settle(m, P, home, 2.0)
	K.ult.shells.clear()

## The knock cue: a 0.6 s upper-body beat (no source frames: the footage shows no knock).
func _knock(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	K.knocked.clear()
	P.dashes = 0.0
	T.hp = 0.0
	T.downed = true
	K.on_deal(T, 5.0, {"src": "abil", "ab": "k1"})
	var r := _time(m, P, K, "gunslinger_knock", 1.0, func() -> bool: return P.dashes >= 1.0)
	T.downed = false
	T.hp = T.max_hp
	C.ok("Vex timing knock: the cue plays its 0.6 s and hands back",
			absf(float(r["len"]) - 0.6) < CLIP_TOL and float(r["out"]) > 0.6 and float(r["out"]) < 0.6 + HAND_BACK,
			"len %.2f out %.2f" % [r["len"], r["out"]])

## A visible release (a clip key, on the move clock from the press) against the kit's effect: within a footage frame.
func _release(what: String, at: float, effect: float) -> void:
	print("TIME release %s %.2f, effect %.2f" % [what, at, effect])
	C.ok("Vex timing %s: the visible release lands within a footage frame (0.2 s) of the effect" % what,
			at >= 0.0 and absf(at - effect) <= FRAME, "release %.2f effect %.2f" % [at, effect])

func _anim(P: Hunter, move: String) -> Animation:
	var c := _clips(P)
	return c.lib.get_animation(String((c.d["kmoves"][move] as Dictionary)["clip"]))

func _track(a: Animation, bone: String, type: int) -> int:
	for i in a.get_track_count():
		if a.track_get_type(i) == type and String(a.track_get_path(i).get_concatenated_subnames()) == bone:
			return i
	return -1

## The clip second `bone` turns fastest in [from, to] (vex.glb's keys): the frame a kick or a snap shows.
func _snap(P: Hunter, move: String, bone: String, from: float, to: float) -> float:
	var a := _anim(P, move)
	var tr := _track(a, bone, Animation.TYPE_ROTATION_3D)
	var best := -1.0
	var at := -1.0
	var t := ceilf(from / KEY_DT - 0.01) * KEY_DT    # on the key grid: a step across a key would split its turn
	while tr >= 0 and t + KEY_DT <= to + 0.001:
		var turn := a.rotation_track_interpolate(tr, t).angle_to(a.rotation_track_interpolate(tr, t + KEY_DT))
		if turn > best:
			best = turn
			at = t + KEY_DT
		t += KEY_DT
	return at

## The dash clip's root (vex.glb): the clip seconds it is half way down into the slide and half way back up.
func _slide_keys(P: Hunter) -> Array:
	var a := _anim(P, "gunslinger_dash")
	var tr := _track(a, "root", Animation.TYPE_POSITION_3D)
	var ys: Array[float] = []
	for k in int(a.length / KEY_DT) + 1 if tr >= 0 else 0:
		ys.append(a.position_track_interpolate(tr, k * KEY_DT).y)
	var keys := [-1.0, -1.0]
	if ys.is_empty():
		return keys
	var half := (ys[0] + float(ys.min())) * 0.5
	for k in ys.size():
		if float(keys[0]) < 0.0 and ys[k] <= half:
			keys[0] = k * KEY_DT
		elif float(keys[0]) >= 0.0 and float(keys[1]) < 0.0 and ys[k] > half:
			keys[1] = k * KEY_DT
	return keys

## GunslingerKit.CLIP_END (a round past it takes the upper body back) against her clips: every move but the
## rifle's own (the merge's mf_xform too: the kit plays it) has its clip's length there.
func _clip_ends(P: Hunter) -> void:
	var off := []
	for mv in _clips(P).d["kmoves"]:
		if mv != "gunslinger_lmb" and absf(_anim(P, mv).length - float(GunslingerKit.CLIP_END.get(mv, -1.0))) > DT:
			off.append("%s %.2f" % [mv, _anim(P, mv).length])
	C.ok("Vex timing: the kit's clip ends match her clips (a round past one shoulders the rifle again)",
			off.is_empty(), str(off))

## LMB held (the source: ten rounds in about 1.4 s, the kick in the gun, the legs walk): a round every
## 0.12-0.14 s, each re-plays the clip from its kick, and walking while she fires, the legs walk.
func _lmb_held(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	P.ammo = 30
	P.fire_cd = 0.0
	K.anim_id = ""
	P.inp["fire"] = true
	var walk := {}
	var probe := _walk_probe(P, 0.2, 1.0, walk)
	var rounds: Array[float] = []
	var plays := 0
	var n0 := P.shot_n
	var last_at := -1.0
	var t0 := m.time
	for f in int(1.4 / DT):
		probe.call(m.time - t0)
		_frame(m, P)
		if P.shot_n != n0:
			n0 = P.shot_n
			rounds.append(m.time - t0)
		if K.anim_id == "gunslinger_lmb" and K.anim_at != last_at:
			last_at = K.anim_at
			plays += 1
	P.inp["fire"] = false
	var gap := (rounds[-1] - rounds[0]) / maxf(rounds.size() - 1, 1) if rounds.size() > 1 else 0.0
	print("TIME gunslinger_lmb held: %d rounds in 1.4 s, one every %.3f s, %d clip plays" % [rounds.size(), gap, plays])
	C.ok("Vex timing LMB held: a round every 0.12-0.14 s (the source's ten in ~1.4 s), each re-plays the kick",
			gap >= float(ROUND_GAP[0]) - DT * 0.5 and gap <= float(ROUND_GAP[1]) + DT * 0.5 and plays == rounds.size(),
			"%d rounds every %.3f s, %d plays" % [rounds.size(), gap, plays])
	C.ok("Vex timing LMB held: walking while she fires, the legs walk (the kick is upper body)", _legs_walk(walk),
			_walk_line("at 1.0", walk))
	_settle(m, P, home, 0.8)

## Shift tap and held with the trigger down (the source fires throughout and is upright by 0.55-0.6): rounds keep
## leaving through the skid at the rifle's cadence without cutting the dash clip, and the first round past the
## clip's end (GunslingerKit.CLIP_END on the move clock; held, the clip waits on its slide key to the skid's end)
## shoulders the rifle again for its kick, within a round of it.
func _dash_firing(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	for held in [false, true]:
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.ammo = 30
		P.fire_cd = 0.0
		P.dashes = P.max_dashes()
		P.inp["fire"] = true
		P.inp["move"] = Vector2(0, 1)
		P.inp["dash_down"] = held
		P.do_dash()
		var t0 := m.time
		var rec := {"skid": -1.0, "at": 0.0, "in_skid": 0, "back": -1.0}
		var n0 := P.shot_n
		for f in int(1.8 / DT):
			var t := m.time - t0
			P.inp["dash_down"] = held and t < 1.5
			P.inp["move"] = Vector2(0, 1) if t < 0.1 else Vector2.ZERO
			_frame(m, P)
			t = m.time - t0
			if P.shot_n != n0:
				n0 = P.shot_n
				if float(rec["skid"]) < 0.0:
					rec["in_skid"] = int(rec["in_skid"]) + 1
			if float(rec["skid"]) < 0.0 and K.slide.is_empty():
				rec["skid"] = t
				rec["at"] = m.time - K.anim_at
			if K.anim_id == "gunslinger_lmb" and float(rec["back"]) < 0.0:
				rec["back"] = t
		P.inp["fire"] = false
		var end := float(rec["skid"]) - float(rec["at"]) + float(GunslingerKit.CLIP_END["gunslinger_dash"])
		var what := "held" if held else "tap"
		print("TIME gunslinger_dash %s firing: skid %.2f, %d rounds in it, clip ends %.2f, the kick back at %.2f"
				% [what, rec["skid"], rec["in_skid"], end, rec["back"]])
		C.ok("Vex timing Shift %s firing: rounds leave through the skid at the rifle's cadence, the clip uncut" % what,
				int(rec["in_skid"]) >= int(float(rec["skid"]) / float(ROUND_GAP[1]))
				and float(rec["back"]) > float(rec["skid"]), "%d rounds in %.2f s, back %.2f" % [rec["in_skid"],
				rec["skid"], rec["back"]])
		C.ok("Vex timing Shift %s firing: the first round past the clip shoulders the rifle again" % what,
				float(rec["back"]) >= end - DT and float(rec["back"]) <= end + float(P.wpn["rate"]) + DT * 2,
				"clip ends %.2f, the kick at %.2f" % [end, rec["back"]])
		_settle(m, P, home, 0.8)
