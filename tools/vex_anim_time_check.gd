extends RefCounted
## Vex's move timing through her clips (docs/heroes/gunslinger.md, "Timing pass"), run inside
## --gunslinger-combo-check: each keyed move is played in a real match with the model rendered, and the frames
## the footage gives (briefs/hero-ref/venator.md, 0.2 s a frame) are checked against what the clip shows: when
## it blends in, the frame its hit or release lands on, when it hands the body back, and that the legs walk
## (not freeze in the clip) when she walks out of a move. Prints one TIME line a move.
const DT := 1.0 / 60.0
const BLEND_IN := 0.12       # s: a move owns the body by this (WardenClips.FADE 0.1 + a frame)
const BACK_SLACK := 2 * DT   # s past a clip's end and its blend-out (warden_anim "fade_out") the legs are back
const SLIDE_UP := 0.62       # s: the dash clip's stand-up key (tools/art1/vex_clips.py): the skid ends before it
const BEND := 0.25           # m: the most a walk key bends the Longneedle's recoil shove (Hunter knock_steer);
                             # walking the hold would be ~2 m
const CLIP_TOL := 0.04       # s: the GLB samples its clips at 30 fps, so a length can sit a frame long
var c_v                        # the combo check (ok, ac)

func _init(check) -> void:
	c_v = check

func run(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	if p.model == null or not p.model.has_node("Warden/Sync"):
		c_v.ok("Vex timing: her clips are on (nothing to time)", false)
		return
	_settle(m, p, home, 0.6)
	_lmb(m, p, k, home)
	_rmb(m, p, k, home)
	_dash(m, p, k, home)
	_slide(m, p, k, home)
	_needle(m, p, k, t, home)
	_nuke(m, p, k, home)
	_knock(m, p, k, t, home)
	_settle(m, p, home, 1.0)

func _clips(p: Hunter) -> WardenClips:
	return p.model.get_node("Warden/Sync").get("clips") as WardenClips

## How long past its clip's end `move` keeps the body: its own blend back to the legs, and a frame or two.
func _back(p: Hunter, move: String) -> float:
	return float(_clips(p).d["kmoves"][move].get("fade_out", WardenClips.FADE_LOCO)) + BACK_SLACK

## How much longer than the base 0.16 s `move` blends back: the walk-out rows wait that much more.
func _extra(p: Hunter, move: String) -> float:
	return _back(p, move) - BACK_SLACK - WardenClips.FADE_LOCO

func _frame(m: Match, p: Hunter) -> void:
	m.step(DT)
	p.render(DT, 1.0)
	var sync: Node = p.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _settle(m: Match, p: Hunter, home: Vector3, secs: float) -> void:
	p.inp["fire"] = false
	p.inp["move"] = Vector2.ZERO
	p.inp["dash_down"] = false
	p.teleport(home)
	for f in int(secs / DT):
		_frame(m, p)

## Plays `secs` of frames from a press and reads the move's beats off the clips, in s from the press: when the
## kit plays it (play), when it owns the body (in), when the kit's event fires (hit, `event` turns true) and how
## far into the clip that is (at), the clip and its length, and when the body is back with the legs (out).
func _time(m: Match, p: Hunter, k: GunslingerKit, move: String, secs: float, event: Callable,
		each := Callable()) -> Dictionary:
	var c := _clips(p)
	var r := {"play": -1.0, "in": -1.0, "hit": -1.0, "at": -1.0, "clip": "", "len": 0.0, "out": -1.0}
	var t0 := m.time
	var owned := false
	for f in int(secs / DT):
		if each.is_valid():
			each.call(m.time - t0)
		_frame(m, p)
		var t := m.time - t0
		if k.anim_id != move:
			continue
		if float(r["play"]) < 0.0:
			r["play"] = k.anim_at - t0
		var w := maxf(c.act_w, c.up_w)
		if float(r["in"]) < 0.0 and w >= 0.999:
			r["in"] = t
		if float(r["hit"]) < 0.0 and event.call():
			r["hit"] = t
			r["at"] = m.time - k.anim_at
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
func _walk_probe(p: Hunter, from: float, until: float, rec: Dictionary) -> Callable:
	return func(t: float) -> void:
		if t >= from:
			p.inp["move"] = Vector2(0, 1)
		if t >= until and not rec.has("speed"):
			var c := _clips(p)
			rec["speed"] = Vector2(p.vel.x, p.vel.z).length()
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
func _lmb(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	c_v.ac.aim_at(p, home + Vector3(6.0, 0, 0))
	p.ammo = 30
	p.fire_cd = 0.0
	k.anim_id = ""
	var n0 := p.shot_n
	p.inp["fire"] = true
	var r := _time(m, p, k, "gunslinger_lmb", 0.3, func() -> bool: return p.shot_n > n0)
	p.inp["fire"] = false
	c_v.ok("Vex timing LMB: the round and its move leave on the press's frame, the clip is on within a frame",
			float(r["hit"]) >= 0.0 and float(r["hit"]) <= DT * 2.5 and absf(float(r["play"]) - float(r["hit"])) < DT
			and float(r["in"]) <= BLEND_IN, "hit %.2f play %.2f in %.2f" % [r["hit"], r["play"], r["in"]])
	_settle(m, p, home, 0.8)

## RMB (item 112, a tap): the coin leaves her free hand on the press; the flick is home by 0.5 s and the legs
## keep walking under it ("upper": "moving").
func _rmb(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	c_v.ac.aim_at(p, home + Vector3(6.0, 0, 0))
	k.cd["rmb"] = 0.0
	k.ch_rmb = 1.0
	var n0 := k.burrs.size()
	var walk := {}
	k.press_rmb()
	var r := _time(m, p, k, "gunslinger_rmb", 1.0, func() -> bool: return k.burrs.size() > n0,
			_walk_probe(p, 0.1, 0.35, walk))
	c_v.ok("Vex timing RMB: fired on the press, the flick on within a frame, the hand back by 0.5 s + the fade",
			float(r["hit"]) <= DT and float(r["in"]) <= BLEND_IN and absf(float(r["len"]) - 0.5) < CLIP_TOL
			and float(r["out"]) < 0.5 + _back(p, "gunslinger_rmb"),
			"in %.2f len %.2f out %.2f" % [r["in"], r["len"], r["out"]])
	c_v.ok("Vex timing RMB: walking through it, the legs walk (the flick is upper body)",
			_legs_walk(walk),
			_walk_line("at 0.35", walk))
	_settle(m, p, home, 0.8)

## Shift tap: the skid is the roll (0.45 s x the dash feel), the clip has her up by 0.62 and ready by 0.85: the
## source's "upright by 0.55-0.6, about 0.6 start to stand" within a frame. Walking out of it, the legs walk.
func _dash(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(0, 1)
	p.do_dash()
	p.inp["move"] = Vector2.ZERO
	var r := _time(m, p, k, "gunslinger_dash", 1.6, func() -> bool: return k.slide.is_empty())
	c_v.ok("Vex timing Shift tap: the skid ends before the clip's stand-up key, the clip runs 0.85 s, "
			+ "legs back by 0.85 + the fade",
			float(r["hit"]) >= 0.45 - DT and float(r["hit"]) <= SLIDE_UP and absf(float(r["len"]) - 0.85) < CLIP_TOL
			and float(r["out"]) > 0.85 and float(r["out"]) < 0.85 + _back(p, "gunslinger_dash"),
			"skid %.2f len %.2f out %.2f" % [r["hit"], r["len"], r["out"]])
	_settle(m, p, home, 0.8)
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(0, 1)
	p.do_dash()
	var walk := {}
	var by := 0.75 + _extra(p, "gunslinger_dash")
	_time(m, p, k, "gunslinger_dash", 1.3, func() -> bool: return k.slide.is_empty(), _walk_probe(p, 0.0, by, walk))
	c_v.ok("Vex timing Shift tap: walking straight out of the skid, the legs are hers again by 0.75 s + the fade",
			float(walk.get("speed", 0.0)) > 1.0 and float(walk.get("full", 1.0)) <= 0.01,
			_walk_line("at %.2f" % by, walk))
	_settle(m, p, home, 0.8)

## Shift held: the clip loops its slide window (0.367-0.5 s, three keys) while the skid lasts (0.18 + 0.55 s), so
## she stands up as it ends, not a quarter second into it.
func _slide(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(0, 1)
	p.inp["dash_down"] = true
	p.do_dash()
	var clock: Array[float] = []
	var hold := func(t: float) -> void:
		p.inp["dash_down"] = t < 1.5
		p.inp["move"] = Vector2(0, 1) if t < 0.1 else Vector2.ZERO
		if k.anim_id == "gunslinger_dash" and not k.slide.is_empty():
			clock.append(m.time - k.anim_at)
	var r := _time(m, p, k, "gunslinger_dash", 1.8, func() -> bool: return k.slide.is_empty(), hold)
	var wraps := 0
	for i in range(1, clock.size()):
		wraps += 1 if clock[i] < clock[i - 1] - 0.05 else 0
	var end := GunslingerKit.SLIDE_LOOP_FROM + GunslingerKit.SLIDE_LOOP_T
	c_v.ok("Vex timing Shift held: she slides 0.73 s low (the clip loops its slide window) and stands up as it ends",
			float(r["hit"]) > 0.7 and float(r["hit"]) < 0.8 and wraps >= 1 and clock.max() <= end + DT * 2
			and float(r["at"]) >= GunslingerKit.SLIDE_LOOP_FROM - DT and float(r["at"]) <= end + DT * 2
			and float(r["out"]) > float(r["hit"]) + 0.3
			and float(r["out"]) < float(r["hit"]) + 0.4 + _back(p, "gunslinger_dash"),
			"skid %.2f clip at %.2f (peak %.2f, %d wraps) out %.2f" % [r["hit"], r["at"], clock.max(), wraps, r["out"]])
	_settle(m, p, home, 0.8)

## E: the beam on the clip's fire key (0.63 s), then the source's recovery: held E_RECOVER (0.6 s) after it, the
## recoil shove still carrying her back. Walking and an RMB press early in the hold do nothing; an RMB press in its
## last Loco.press_buffer goes as it lifts, on the frame the clip hands the body back. Then she walks off on her legs.
func _needle(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	c_v.ac.fresh(t)
	t.teleport(home + Vector3(8.0, 0, 0))
	_settle(m, p, home, 0.2)
	c_v.ac.aim_at(p, t.pos)
	k.cd["e"] = 0.0
	k.cd["rmb"] = 0.0
	k.ch_rmb = 2.0
	var hits0 := k.needle_hits
	var u0 := int(p.used.get("utility", 0))
	var rec := {}
	var probe := _lock_probe(p, 0.7, [["sec", 0.75], ["sec", 1.12]], 1.15, 1.45, rec,
			func() -> bool: return int(p.used.get("utility", 0)) > u0)
	k.use_e()
	var r := _time(m, p, k, "gunslinger_e", 1.6, func() -> bool: return k.needle_hits > hits0, probe)
	var lift := float(r["hit"]) + GunslingerKit.E_RECOVER
	c_v.ok("Vex timing E: the beam fires at 0.63 s on the clip's fire key, the clip hands back as the hold lifts",
			absf(float(r["hit"]) - 0.63) <= DT * 2 and absf(float(r["at"]) - 0.63) <= DT * 2
			and absf(float(r["len"]) - 1.05) < CLIP_TOL and absf(float(r["out"]) - lift) <= DT * 1.5,
			"hit %.2f len %.2f out %.2f lift %.2f" % [r["hit"], r["len"], r["out"], lift])
	_lock_lines("E", "0.6 s after the beam (venator.md E 4: 0.2 s shove + ~0.4 s recovery)", lift,
			int(p.used.get("utility", 0)) - u0, rec)
	_settle(m, p, home, 0.5)

## R: the barrel comes up over 0.1 s and the shot leaves on its kick key (0.14 s), not at the press: the source's
## raise, then fire. She is never held: walking through it the legs walk under the raised rifle (an
## upper-body clip), slowed to GunslingerUlt.WINDUP_MOVE in the 0.25 s wind-up and at full speed after; a jump in
## the wind-up goes at once.
func _nuke(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	c_v.ac.aim_at(p, home + Vector3(8.0, 0, 0))
	k.cd["x"] = 0.0
	var walk := {}
	var rec := {}
	var wp := _walk_probe(p, 0.0, 0.2, walk)
	var probe := func(t: float) -> void:
		wp.call(t)
		if not rec.has("free") and t >= GunslingerUlt.WINDUP + 0.1:
			rec["free"] = Vector2(p.vel.x, p.vel.z).length()
	k.cast_ult()
	var fired := func() -> bool:
		return k.ult.shells.size() > 0 and bool((k.ult.shells[0] as Dictionary).get("fired", true))
	var r := _time(m, p, k, "gunslinger_x", 1.4, fired, probe)
	p.inp["move"] = Vector2.ZERO
	c_v.ok("Vex timing R: the shot leaves on the raised barrel (0.14 s), the clip plays its 0.6 s and hands back",
			absf(float(r["hit"]) - GunslingerUlt.FIRE_T) <= DT * 1.5 and absf(float(r["len"]) - 0.6) < CLIP_TOL
			and float(r["out"]) > 0.6 and float(r["out"]) < 0.6 + _back(p, "gunslinger_x"),
			"hit %.2f len %.2f out %.2f" % [r["hit"], r["len"], r["out"]])
	var run_v := p.base_speed
	c_v.ok("Vex timing R: walking through the wind-up the legs walk, slowed but never stopped",
			_legs_walk(walk) and float(walk.get("speed", 0.0)) < run_v * 0.8,
			_walk_line("at 0.2", walk) + " (run %.1f)" % run_v)
	c_v.ok("Vex timing R: after the 0.25 s wind-up she runs at full speed",
			float(rec.get("free", 0.0)) > run_v * 0.9, "%.2f m/s (run %.1f)" % [rec.get("free", 0.0), run_v])
	_settle(m, p, home, 2.0)
	k.ult.shells.clear()
	k.x_wind_end = 0.0
	# a jump in the wind-up goes at once (no hold)
	k.cd["x"] = 0.0
	k.cast_ult()
	var j0 := m.time
	p.inp["jump"] = true
	_frame(m, p)
	p.inp["jump"] = false
	c_v.ok("Vex timing R: a jump in the wind-up goes at once", p.jump_at >= j0,
			"jump_at %.2f t0 %.2f" % [p.jump_at, j0])
	_settle(m, p, home, 2.0)
	k.ult.shells.clear()

## Walks from `from` s after the press and presses each [key, at] for one step; reads her speed and how far she
## has gone along the walk key at `held_at` (inside the hold) and `free_at` (after it), and when `went` first turns
## true (the press that waited went).
func _lock_probe(p_v: Hunter, from: float, presses: Array, held_at: float, free_at: float, rec: Dictionary,
		went: Callable) -> Callable:
	return func(t: float) -> void:
		p_v.inp["move"] = Vector2(0, 1) if t >= from else Vector2.ZERO
		for p in presses:
			p_v.inp[p[0]] = absf(t - float(p[1])) < DT * 0.5
		if not rec.has("went") and went.call():
			rec["went"] = t
		if not rec.has("p0"):
			rec["p0"] = p_v.pos
		for probe in [["held", held_at], ["free", free_at]]:
			if t >= float(probe[1]) and not rec.has(probe[0]):
				rec[probe[0]] = {"speed": Vector2(p_v.vel.x, p_v.vel.z).length(), "full": _clips(p_v).act_w,
						"z": absf(p_v.pos.z - (rec["p0"] as Vector3).z)}

## The hold's lines: she does not walk in it (no step along the walk key, across the recoil), the early press is
## dropped and the late one goes on the frame the hold lifts, and after it she walks.
func _lock_lines(move: String, what: String, lift: float, went: int, rec: Dictionary) -> void:
	var held: Dictionary = rec.get("held", {})
	var after: Dictionary = rec.get("free", {})
	c_v.ok("Vex timing %s: held %s, walking does not move her" % [move, what],
			float(held.get("z", 1.0)) < BEND and float(held.get("speed", 9.0)) < 0.6,
			"held: %.2f m/s, %.2f m along the walk" % [held.get("speed", -1.0), held.get("z", -1.0)])
	c_v.ok("Vex timing %s: a press early in the hold is dropped, one in its last 0.15 s goes as it lifts" % move,
			went == 1 and absf(float(rec.get("went", -1.0)) - lift) <= DT * 1.5,
			"went %d, at %.2f (lift %.2f)" % [went, rec.get("went", -1.0), lift])
	c_v.ok("Vex timing %s: after the hold she walks" % move, float(after.get("speed", 0.0)) > 1.0,
			"free: %.2f m/s" % after.get("speed", 0.0))

## The knock cue: a 0.6 s upper-body beat (no source frames: the footage shows no knock).
func _knock(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, _home: Vector3) -> void:
	k.knocked.clear()
	p.dashes = 0.0
	t.hp = 0.0
	t.downed = true
	k.on_deal(t, 5.0, {"src": "abil", "ab": "k1"})
	var r := _time(m, p, k, "gunslinger_knock", 1.3, func() -> bool: return p.dashes >= 1.0)
	t.downed = false
	t.hp = t.max_hp
	c_v.ok("Vex timing knock: the cue plays its 0.6 s and hands back",
			absf(float(r["len"]) - 0.6) < CLIP_TOL and float(r["out"]) > 0.6
			and float(r["out"]) < 0.6 + _back(p, "gunslinger_knock"),
			"len %.2f out %.2f" % [r["len"], r["out"]])
