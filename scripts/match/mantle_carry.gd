class_name MantleCarry
extends RefCounted
## Item 185b and the abyss edge: a mantle keeps your momentum. You fly into a ledge from a jump, a dash, a glide
## or the abyss and come over the top still moving: one motion, not a stop and climb.
##  - Keys into the face within APPROACH_DOT (about 60 degrees) catch a ledge; with the keys idle, so
##    does momentum: heading into it that closely at PUSH_SPEED or more. Keys along or away from a
##    wall never pull you up it.
##  - Over the abyss a side you touch launches you once (launch, content/rules/hunter_move.json edge_mantle
##    [game data]): straight up by how far the lip is above your feet; under mini_h it's a mini mantle (the
##    edge pop: launched at once, then pushed forward, see step), deeper you freeze wait_s first and leave
##    with no sideways speed. Then cd before the next one.
##  - Over a dry-ground lip (our terrace climb) you leave at HunterMove.mantle_launch_keep of the speed you came
##    in with, never under HunterMove.mantle_launch nor above EXIT_K of your run speed; a dash or a launch
##    glancing off a ledge doesn't fling you off the top, and while you rise the speed above that bleeds at
##    RISE_BLEED. A jump in the rise is the mini mantle's launch from where you are.
##  - After any of them the mini mantle's push runs for mini_s while you're in the air.
## The speed you came in with is a decaying peak (carry_v), so the wall that stopped you a step
## before the catch doesn't count as having stopped you.

const APPROACH_DOT := 0.45  # keys or momentum this far into the face (cos ~63 degrees) catch a ledge
const PUSH_SPEED := 2.0  # m/s into the face: momentum alone is a push
const PEAK_DECAY := 6.0  # m/s per s: how fast the remembered approach speed fades
const EXIT_K := 1.2  # x run speed: the fastest you leave a mantle (a little forward flow, never a launch)
const RISE_BLEED := 60.0  # m/s per s: speed above exit_cap lost while rising up a face (19 m/s gone in ~0.2s)
static var rules: Dictionary = MoveRules.data()["edge_mantle"]


## Every step, before the move: hold a fresh mantle's speed, and remember how fast you're going (a
## decaying peak). Returns the horizontal velocity to move with.
static func step(h: Hunter, hv: Vector2, dt: float) -> Vector2:
	var wait := float(h.carry_mini.get("wait", 0.0))
	if wait > 0.0:
		h.carry_mini["wait"] = wait - dt
		if wait - dt > 0.0:
			return Vector2.ZERO  # held against the face, no gravity (Hunter._physics), rising slowly
		h.vel.y = float(h.carry_mini["vz"])
		h.carry_mini = {}
		return Vector2.ZERO
	hv = _mini_push(h, hv, dt)
	hv = suction(h, hv, dt)
	if not h.lfloat.is_empty():
		hv = hv.limit_length(maxf(exit_cap(h), hv.length() - RISE_BLEED * dt))
	h.carry_v = maxf(hv.length(), h.carry_v - PEAK_DECAY * dt)
	if hv.length() > 0.5:
		h.carry_dir = hv.normalized()
	return hv


## The mini mantle's push [game data]: toward a goal of mini_keep x the speed you came in with (at least mini_min),
## easing to half by the end, the shortfall gained at mini_push a second toward a heading that turns from the one
## you came in with to your keys; and over the top, rising fast is pulled back down (a pop, not a launch).
static func _mini_push(h: Hunter, hv: Vector2, dt: float) -> Vector2:
	var cm := h.carry_mini
	if cm.is_empty():
		return hv
	cm["t"] = float(cm["t"]) - dt
	if cm["t"] <= 0.0 or h.grounded or not h.lfloat.is_empty():
		h.carry_mini = {}
		return hv
	var p := 1.0 - float(cm["t"]) / float(rules["mini_s"])
	var goal := (1.0 - 0.5 * p) * float(cm["v"])
	var mv: Vector2 = h.inp["move"]
	var d0: Vector2 = cm["dir"]
	var d := d0.lerp(mv.normalized() if mv.length() > 0.3 else d0, p)
	if hv.length() < goal:
		hv += d * (goal - hv.length()) * float(rules["mini_push"]) * dt
	var top: float = h.lip_y if h.over_void() else h.ground()
	var soft := float(rules["mini_soft_cap"])
	if h.pos.y > top and h.vel.y > soft:
		h.vel.y -= (
			(h.vel.y - soft)
			* float(rules["mini_down"])
			* (1.0 - float(rules["mini_fade"]) * p)
			* dt
		)
	return hv


## The wall suction [game data] (rules "suction"): falling (not gliding) over the abyss with the mantle cooldown
## idle, a line from your feet along your sideways speed finds the island side you're heading into (within
## head_on degrees of straight in) up to trace m away (x near_k at speed[0] m/s or slower, full at speed[1]):
## you're pulled on toward it at force[0..1] m/s^2 by force_curve over dist[0..1] m (strongest close in). Under
## its top by up_h m or less, within up_dist[1] m of it and rising no faster than up_vy m/s, you're also pulled
## up at up[0..1] m/s^2 (deeper is stronger) x up_curve over up_dist. Touching the side then launches you.
static func suction(h: Hunter, hv: Vector2, dt: float) -> Vector2:
	if (
		h.grounded
		or h.gliding
		or h.downed
		or h.out
		or h.stun_t > 0.0
		or h.mantle_cd > 0.0
		or not h.lfloat.is_empty()
		or h.knock_t > 0.0
	):  # (ours) a knock flies on its own: a pull would feed our wall slam, not the catch
		return hv
	var sp := hv.length()
	if sp < 0.05 or not h.over_void():
		return hv
	var r: Dictionary = rules["suction"]
	var bs := HunterMove.body_scale
	var spd: Array = r["speed"]
	var s_frac := clampf(
		(sp - float(spd[0]) * bs) / ((float(spd[1]) - float(spd[0])) * bs), 0.0, 1.0
	)
	var near_k := float(r["near_k"])
	var reach := float(r["trace"]) * (near_k + (1.0 - near_k) * s_frac)
	var dir := hv / sp
	var hit := _wall_ahead(h, dir, reach)
	if hit.is_empty():
		return hv
	var dist := float(hit["d"])
	var fd: Array = r["dist"]
	var fo: Array = r["force"]
	var uf := clampf((dist - float(fd[0])) / (float(fd[1]) - float(fd[0])), 0.0, 1.0)
	hv += dir * lerpf(float(fo[0]), float(fo[1]), _curve(r["force_curve"], uf)) * bs * dt
	var under := float(hit["top"]) - h.pos.y
	var ud: Array = r["up_dist"]
	if (
		under >= 0.0
		and under <= float(r["up_h"])
		and dist <= float(ud[1])
		and h.vel.y <= float(r["up_vy"])
	):
		var up: Array = r["up"]
		var k := _curve(
			r["up_curve"], clampf((dist - float(ud[0])) / (float(ud[1]) - float(ud[0])), 0.0, 1.0)
		)
		h.vel.y += lerpf(float(up[0]), float(up[1]), under / float(r["up_h"])) * k * dt
	return hv


## The first island side (a ground tile whose top is above your feet, not a smooth sheer cliff) along `dir`
## within `reach` m of your feet, facing you within the suction's head_on angle: {d: m to it, top: its height}.
static func _wall_ahead(h: Hunter, dir: Vector2, reach: float) -> Dictionary:
	var w: World = h.m.world
	var cos_on := cos(deg_to_rad(float(rules["suction"]["head_on"])))
	var x := h.pos.x
	var z := h.pos.z
	var cx := int(floor(x))
	var cz := int(floor(z))
	var sx := 1 if dir.x > 0.0 else -1
	var sz := 1 if dir.y > 0.0 else -1
	var nx := cx + maxi(sx, 0)  # the next grid line ahead on each axis
	var nz := cz + maxi(sz, 0)
	var tx := (nx - x) / dir.x if absf(dir.x) > 1e-6 else INF
	var tz := (nz - z) / dir.y if absf(dir.y) > 1e-6 else INF
	var dtx := absf(1.0 / dir.x) if absf(dir.x) > 1e-6 else INF
	var dtz := absf(1.0 / dir.y) if absf(dir.y) > 1e-6 else INF
	while minf(tx, tz) <= reach:
		var along_x := tx < tz
		var d := tx if along_x else tz
		if along_x:
			cx += sx
			tx += dtx
		else:
			cz += sz
			tz += dtz
		if not w.inb(cx, cz):
			return {}
		var i := w.idx(cx, cz)
		if w.kind[i] != World.T_GROUND or w.sheer.has(i):
			continue
		var top := w.level[i] * World.LEVEL
		if top <= h.pos.y + 0.05:
			continue
		if absf(dir.x if along_x else dir.y) < cos_on:
			return {}  # a side met at a glance: no pull
		return {"d": d, "top": top}
	return {}


## A curve sampled at x = 0, 0.1, 0.25, 0.5, 0.75, 1 (the data's keys), read linearly at `x`.
static func _curve(keys: Array, x: float) -> float:
	var xs := [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
	for i in range(1, xs.size()):
		if x <= xs[i]:
			return lerpf(float(keys[i - 1]), float(keys[i]), (x - xs[i - 1]) / (xs[i] - xs[i - 1]))
	return float(keys[-1])


## The mantle's launch speed (m/s up) from a lip `lip_h` metres above your feet: `is_mini` adds the mini mantle's bonus.
static func launch_vz(lip_h: float, is_mini: bool) -> float:
	var lv: Array = rules["launch_vz"]
	var vz := lerpf(float(lv[0]), float(lv[1]), clampf(lip_h / float(rules["depth"]), 0.0, 1.0))
	return vz + (float(rules["mini_bonus"]) if is_mini else 0.0)


## A mantle from `lip_h` metres under a lip (the abyss catch, or a jump in a dry-ground rise): the glider shuts,
## your speed is zeroed and you're launched (a mini mantle) or held a moment and then launched (a full one).
static func launch(h: Hunter, lip_h: float) -> void:
	var v_in := maxf(h.carry_v, Vector2(h.vel.x, h.vel.z).length())
	var dir := h.carry_dir if h.carry_v > 0.5 else Vector2(h.vel.x, h.vel.z).normalized()
	var is_mini := lip_h < float(rules["mini_h"])
	h.gliding = false
	h.lfloat = {}
	h.roll_t = 0.0  # (a dash ends in the mantle)
	h.vel = Vector3.ZERO
	h.mantle_cd = float(rules["cd"]) + (0.0 if is_mini else float(rules["wait_s"]))  # (counted from the launch)
	h.stats["mantles"] = int(h.stats.get("mantles", 0)) + 1
	var min_v := float(rules["mini_min"]) * HunterMove.body_scale
	if is_mini:
		h.vel.y = launch_vz(lip_h, true)
		var v := maxf(v_in * float(rules["mini_keep"]), min_v)
		if not h.over_void():
			v = minf(v, exit_cap(h))  # a dry-ground ledge never flings you off its top (--mantle-fling-check)
		h.carry_mini = {"t": float(rules["mini_s"]), "v": v, "dir": dir}
	else:
		h.vel.y = v_in * float(rules["wait_rise"])
		h.carry_mini = {"wait": float(rules["wait_s"]), "vz": launch_vz(lip_h, false)}


## Holding against the face before a full mantle's launch (no gravity then).
static func waiting(h: Hunter) -> bool:
	return float(h.carry_mini.get("wait", 0.0)) > 0.0


## Just mantled: the glider stays shut (no_glide_s after the launch).
static func blocks_glide(h: Hunter) -> bool:
	return h.mantle_cd > float(rules["cd"]) - float(rules["no_glide_s"])


## A Shift dash that meets a ledge in reach hands over to the mantle: what's left of the dash is dropped (the
## source's mini-mantle sets your speed from here, exit()), and the dash's speed takes you up the face, capped
## at HunterFeel.lrise_speed, instead of the suction's slow pull ([footage] dash at a rim, on top ~0.2 s later
## at dash-trail speed, no stop). 0 when you aren't dashing.
static func dash_rise(h: Hunter) -> float:
	if h.roll_t <= 0.0 or h.move_kind != "dash":
		return 0.0
	return minf(h.carry_v, HunterFeel.lrise_speed)


## A teleport (a blink, a respawn, a portal) starts you with no momentum to carry.
static func forget(h: Hunter) -> void:
	h.carry_v = 0.0
	h.carry_mini = {}


## Does heading `toward` (from you to the face) count as pushing into it: keys or momentum?
static func pushing(h: Hunter, toward: Vector2, mv: Vector2) -> bool:
	if toward.length() < 0.01:
		return mv.length() > 0.3
	var tn := toward.normalized()
	if mv.length() > 0.3:
		return tn.dot(mv.normalized()) >= APPROACH_DOT
	return h.carry_v >= PUSH_SPEED and tn.dot(h.carry_dir) >= APPROACH_DOT


## The way you're heading when the keys are idle (momentum), else the keys.
static func heading(h: Hunter, mv: Vector2) -> Vector2:
	if mv.length() > 0.3:
		return mv
	return h.carry_dir * (1.0 if h.carry_v >= PUSH_SPEED else 0.0)


## The fastest you leave a mantle, in m/s.
static func exit_cap(h: Hunter) -> float:
	return h.base_speed * EXIT_K


## Over the lip: at least HunterMove.mantle_launch_keep of the speed you caught the ledge with, toward your keys
## (or on in the direction you were going), capped at that speed and at exit_cap.
static func exit(h: Hunter, hv: Vector2, n: Vector2, mv: Vector2, v_in: float) -> Vector2:
	var cap := exit_cap(h)
	var d := mv.normalized() if mv.length() > 0.3 else n
	if d.dot(n) < 0.0:
		return hv.limit_length(cap)  # steering back off the ledge: your keys win
	var floor_v := maxf(
		v_in * HunterMove.mantle_launch_keep, HunterMove.mantle_launch(h.base_speed)
	)
	var want := minf(floor_v, minf(maxf(v_in, h.base_speed), cap))
	var along := hv.dot(d)
	if along < want:
		hv += d * (want - along)
	h.carry_mini = {"t": float(rules["mini_s"]), "v": want, "dir": d}
	return hv.limit_length(cap)
