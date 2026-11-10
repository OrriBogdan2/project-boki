extends RefCounted
## Vex's move timing through her clips (docs/heroes/gunslinger.md, "Animation timing"), run inside
## --gunslinger-combo-check: each keyed move is played in a real match with the model rendered, and the frames
## the footage gives (briefs/hero-ref/venator.md, 0.2 s a frame) are checked against what the clip shows: when
## it blends in, the frame its hit or release lands on, when it hands the body back, and that the legs walk
## (not freeze in the clip) when she walks out of a move. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const HAND_BACK := 0.2       # s past a clip's end the legs are back (WardenClips.FADE_LOCO 0.16 + 2 frames)
const SLIDE_UP := 0.62       # s: the dash clip's stand-up key (tools/art1/vex_clips.py): the skid ends before it
const CLIP_TOL := 0.04       # s: the GLB samples its clips at 30 fps, so a length can sit a frame long
const DASH_CLIP := 0.85     # s: the dash clip's length (tools/art1/vex_clips.py)
const RMB_FLICK := 0.07      # clip s: the rmb clip's flick (release) key (tools/art1/vex_clips.py)
const X_UP := 0.1            # clip s: the x clip's barrel-up key, the fire key (tools/art1/vex_clips.py)
const ROUND_GAP := [0.12, 0.14]   # s between rounds held: the source's ten rounds in about 1.4 s
const ARM_UP := 1.2          # m above her feet: the palm at about shoulder height, the arm raised (e clip LP 1.38)
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
	_run(m, P, home)
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

## The kit's table of when each clip ends on the move clock (GunslingerKit.CLIP_END: a round takes the upper body
## back past it) against the clips themselves under clip_warp.
func _clip_ends(P: Hunter) -> void:
	var c := _clips(P)
	var off := []
	for mv in GunslingerKit.CLIP_END:
		var clip := String((c.d["kmoves"][mv] as Dictionary)["clip"])
		var end := _unwarp(mv, c.lib.get_animation(clip).length)
		if absf(end - float(GunslingerKit.CLIP_END[mv])) > CLIP_TOL:
			off.append("%s %.2f" % [mv, end])
	C.ok("Vex timing: the kit's clip ends match her clips on the move clock (rounds re-take the body after)",
			off.is_empty(), str(off))

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

## The move second a clip second plays at under the kit's clip_warp knots (WardenClips._warped inverted).
func _unwarp(move: String, clip_s: float) -> float:
	var knots: Array = Tuning.of("clip_warp")["vex"].get(move, [])
	var prev := [0.0, 0.0]
	for kn in knots:
		if float(kn[1]) >= clip_s:
			var span := float(kn[1]) - float(prev[1])
			var u := (clip_s - float(prev[1])) / span if span > 0.0 else 1.0
			return lerpf(float(prev[0]), float(kn[0]), u)
		prev = kn
	return float(prev[0]) + clip_s - float(prev[1])

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

## LMB held (the source: ten rounds in about 1.4 s, the kick in the gun, the legs walk): a round every
## 0.12-0.14 s, each one re-plays the clip from its kick, and walking while firing the legs walk.
func _lmb_held(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	P.ammo = 30
	P.fire_cd = 0.0
	K.anim_id = ""
	P.inp["fire"] = true
	var walk := {}
	var probe := _walk_probe(P, 0.2, 1.0, walk)
	var rounds: Array = []
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
	var gap := (float(rounds[-1]) - float(rounds[0])) / maxf(rounds.size() - 1, 1) if rounds.size() > 1 else 0.0
	print("TIME gunslinger_lmb held: %d rounds in 1.4 s, one every %.3f s, %d clip plays" % [rounds.size(), gap, plays])
	C.ok("Vex timing LMB held: a round every 0.12-0.14 s (the source's ten in ~1.4 s), each re-plays the kick",
			gap >= float(ROUND_GAP[0]) - DT * 0.5 and gap <= float(ROUND_GAP[1]) + DT * 0.5 and plays == rounds.size(),
			"%d rounds every %.3f s, %d plays" % [rounds.size(), gap, plays])
	C.ok("Vex timing LMB held: walking while she fires, the legs walk (the kick is upper body)", _legs_walk(walk),
			_walk_line("at 1.0", walk))
	_settle(m, P, home, 0.8)

## RMB Coin Blast (the owner's side toss: her coin flicked from the cyborg hand): the coin leaves her palm on
## the press, the clip's flick key lands within the 0.1 s blend-in, it settles by 0.38 s (the source's ~0.2 s throw
## commit to the follow-through, then the hand comes home) and the legs keep walking under it.
func _rmb(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var n0 := K.burrs.size()
	var walk := {}
	var flick := _unwarp("gunslinger_rmb", RMB_FLICK)
	var at_flick := {}
	var probe := _walk_probe(P, 0.1, 0.35, walk)
	var each := func(t: float) -> void:
		probe.call(t)
		if t >= flick and at_flick.is_empty() and K.burrs.size() > n0:
			var b: Dictionary = K.burrs[-1]
			at_flick["ahead"] = (b["pos"] as Vector3).distance_to(K.palm_at())
			at_flick["spin"] = float(b["spin"])
	var left := K.last_flick
	K.press_rmb()
	var from_palm := K.last_flick != left and K.last_flick.distance_to(K.palm_at()) < 0.05
	var r := _time(m, P, K, "gunslinger_rmb", 1.0, func() -> bool: return K.burrs.size() > n0, each)
	var end := _unwarp("gunslinger_rmb", float(r["len"]))
	print("TIME gunslinger_rmb flick key %.3f, coin %.2f m past the palm then, spun %.2f rad, clip ends %.2f"
			% [flick, at_flick.get("ahead", -1.0), at_flick.get("spin", -1.0), end])
	C.ok("Vex timing RMB: the coin leaves her palm on the press, the flick key lands inside the blend-in",
			from_palm and float(r["hit"]) <= DT and flick <= WardenClips.FADE and float(r["in"]) <= BLEND_IN,
			"palm %s hit %.2f flick %.3f in %.2f" % [from_palm, r["hit"], flick, r["in"]])
	C.ok("Vex timing RMB: the 0.5 s clip runs to 0.38 s on the move clock, the arm back by then + the fade",
			absf(float(r["len"]) - 0.5) < CLIP_TOL and absf(end - 0.38) < 0.02 and float(r["out"]) < end + HAND_BACK,
			"len %.2f end %.2f out %.2f" % [r["len"], end, r["out"]])
	C.ok("Vex timing RMB: walking through it, the legs walk (the toss is upper body)",
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

## Shift tap and held with the trigger down (the source fires throughout and is upright by 0.55-0.6): rounds keep
## leaving through the skid at the rifle's cadence, the rounds never cut the dash clip, and the next round after the
## clip's end takes the upper body back (the shouldered kick) within a round of it.
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
		var rec := {"skid": -1.0, "in_skid": 0, "cut": false, "back": -1.0}
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
			if K.anim_id == "gunslinger_lmb" and float(rec["back"]) < 0.0:
				rec["back"] = t
				rec["cut"] = t < float(rec["skid"])
		P.inp["fire"] = false
		# the clip runs from the press on a tap; held, it waits on its slide key and stands up as the skid ends
		var end := float(rec["skid"]) + DASH_CLIP - GunslingerKit.SLIDE_KEY if held else DASH_CLIP
		var what := "held" if held else "tap"
		print("TIME gunslinger_dash %s firing: skid %.2f, %d rounds in it, clip ends %.2f, the kick back at %.2f"
				% [what, rec["skid"], rec["in_skid"], end, rec["back"]])
		C.ok("Vex timing Shift %s firing: rounds leave through the skid at the rifle's cadence, the clip uncut" % what,
				int(rec["in_skid"]) >= int(float(rec["skid"]) / float(ROUND_GAP[1])) and not bool(rec["cut"]),
				"%d rounds in %.2f s" % [rec["in_skid"], rec["skid"]])
		C.ok("Vex timing Shift %s firing: after the clip the next round shoulders the rifle again" % what,
				float(rec["back"]) >= end - DT and float(rec["back"]) <= end + float(P.wpn["rate"]) + DT * 2,
				"clip ends %.2f, the kick at %.2f" % [end, rec["back"]])
		_settle(m, P, home, 0.8)

## E Palm Lance: the charge is 0.6 s (the source's cast bar), the beam at 0.63 lands on the clip's fire key (0.65)
## and leaves her open palm with the arm raised (the owner's: the palm at shoulder height, out ahead of her); the
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
	var arm := {}
	var beam := func() -> bool:
		if K.needle_hits == hits0:
			return false
		var palm := K.palm_at()
		arm["up"] = palm.y - P.pos.y
		arm["out"] = Vector2(palm.x - P.pos.x, palm.z - P.pos.z).dot(P.aim_dir())
		return true
	var r := _time(m, P, K, "gunslinger_e", 1.5, beam, _walk_probe(P, 0.85, 1.05, walk))
	print("TIME gunslinger_e palm at the beam: %.2f m up, %.2f m out" % [arm.get("up", 0.0), arm.get("out", 0.0)])
	C.ok("Vex timing E: the beam leaves the open palm with the arm raised (shoulder height, out in front)",
			float(arm.get("up", 0.0)) >= ARM_UP and float(arm.get("out", 0.0)) > 0.2,
			"%.2f m up, %.2f m out" % [arm.get("up", 0.0), arm.get("out", 0.0)])
	C.ok("Vex timing E: the beam fires at 0.63 s on the clip's fire key, the move settles by 1.05 s + the fade",
			absf(float(r["hit"]) - 0.63) <= DT * 2 and absf(float(r["at"]) - 0.63) <= DT * 2
			and absf(float(r["len"]) - 1.05) < CLIP_TOL and float(r["out"]) < 1.05 + HAND_BACK,
			"hit %.2f len %.2f out %.2f" % [r["hit"], r["len"], r["out"]])
	C.ok("Vex timing E: walking off after the shove, the legs are hers again by 1.05 s",
			float(walk.get("speed", 0.0)) > 1.0 and float(walk.get("full", 1.0)) <= 0.01, _walk_line("at 1.05", walk))
	_settle(m, P, home, 0.5)

## R Cinderfall: the rifle goes straight up and the shot leaves on the clip's barrel-up key (clip 0.1 s, at
## x_fire_s 0.2 s on the warped clock), not at the press or mid-raise: the source's ~0.2 s raise, then fire. The
## clip's 0.6 s run to 0.9 s on the move clock (the source's ~0.8 s commit). Walking, the legs walk.
func _nuke(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	C.ac.aim_at(P, home + Vector3(8.0, 0, 0))
	K.cd["x"] = 0.0
	var walk := {}
	K.cast_ult()
	var fired := func() -> bool:
		return K.ult.shells.size() > 0 and bool((K.ult.shells[0] as Dictionary).get("fired", true))
	var r := _time(m, P, K, "gunslinger_x", 1.4, fired, _walk_probe(P, 0.0, 0.3, walk))
	var up := _unwarp("gunslinger_x", X_UP)
	var end := _unwarp("gunslinger_x", float(r["len"]))
	print("TIME gunslinger_x barrel-up key %.2f, clip ends %.2f" % [up, end])
	C.ok("Vex timing R: the shot leaves on the raised barrel (clip 0.1 s at x_fire_s), the arm down by 0.9 s",
			absf(float(r["hit"]) - up) <= DT * 1.5 and absf(float(Tuning.of("vex")["x_fire_s"]) - up) < 0.005
			and absf(float(r["len"]) - 0.6) < CLIP_TOL and absf(end - 0.9) < 0.02 and float(r["out"]) < end + HAND_BACK,
			"hit %.2f up %.2f len %.2f end %.2f out %.2f" % [r["hit"], up, r["len"], end, r["out"]])
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

## The run (the sheet's six hunters: a stride cycle at ~2.3 Hz covering ~1 bh; Ghost's own is "Unclear", too short
## and busy firing): prints her cadence and stride at full run speed, for the doc's table. Nothing asserted: the
## sheet does not trust a number for her.
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
