extends RefCounted
## Vex's move timing through her clips (docs/heroes/gunslinger.md, "Timing pass"), run inside
## --gunslinger-combo-check: each keyed move is played in a real match with the model rendered, and the frames
## the footage gives (briefs/hero-ref/venator.md, 0.2 s a frame) are checked against what the clip shows: when
## it blends in, the frame its hit or release lands on, when it hands the body back, and that the legs walk
## (not freeze in the clip) when she walks out of a move. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2       # s past a clip's end the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const SLIDE_UP := 0.62       # s: the dash clip's stand-up key (tools/art1/vex_clips.py): the skid ends before it
const CLIP_TOL := 0.04       # s: the GLB samples its clips at 30 fps, so a length can sit a frame long
var C                        # the combo check (ok, ac)

func _init(check) -> void:
	C = check

func run(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	if P.model == null or not P.model.has_node("Warden/Sync"):
		C.ok("Vex timing: her clips are on (nothing to time)", false)
		return
	_settle(m, P, home, 0.6)
	_lmb(m, P, K, home)
	_rmb(m, P, K, home)
	_dash(m, P, K, home)
	_slide(m, P, K, home)
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
			live = _upper(c)
		if live != "" and String(r["clip"]) == "":
			r["clip"] = live
			r["len"] = c.lib.get_animation(live).length
		owned = owned or w >= 0.999
		if owned and float(r["out"]) < 0.0 and w <= 0.0:
			r["out"] = t
	print("TIME %s play %.2f in %.2f hit %.2f (clip %.2f) %s %.2f out %.2f"
			% [move, r["play"], r["in"], r["hit"], r["at"], r["clip"], r["len"], r["out"]])
	return r

## The clip on the upper-body channel (a move with "upper": the legs keep walking under it).
func _upper(c: WardenClips) -> String:
	var live := "anim_u" + "ab"[c.chan_u]     # two crossfaded channels: read the live one
	return ((c.tree.tree_root as AnimationNodeBlendTree).get_node(live) as AnimationNodeAnimation).animation

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
