class_name HunterLedge
extends RefCounted
## A Hunter's ledge grab, rise, fling and grapple: the climbing moves that pull it up onto a lip.
## Hunter keeps the entry points.


## Where a mantle has you at progress k (0..1): up the face with an ease-out (a quick pull that
## slows near the top), then over the lip with a small hop and an ease-in-out onto the top. The
## height never drops below the lip while you're over the cliff, so you can't sink into it.
static func _mantle_point(h: Hunter, k: float) -> Vector3:
	var a: Vector3 = h.pad["from"]
	var f: Vector3 = h.pad["face"]
	var b: Vector3 = h.pad["to"]
	var lip: float = h.pad["lip"]
	var sp: float = h.pad["split"]
	if k < sp:
		var u := k / maxf(0.001, sp)
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var hz := clampf(u * 3.0, 0.0, 1.0)  # snap against the wall in the first third
		return Vector3(lerpf(a.x, f.x, hz), lerpf(a.y, lip, e), lerpf(a.z, f.z, hz))
	var u2 := (k - sp) / maxf(0.001, 1.0 - sp)
	var e2 := u2 * u2 * (3.0 - 2.0 * u2)
	return Vector3(lerpf(f.x, b.x, e2), lerpf(lip, b.y, e2) + 0.22 * sin(u2 * PI), lerpf(f.z, b.z, e2))


## True while you're rising up a ledge (or in a scripted pad mantle).
static func mantling(h: Hunter) -> bool:
	return not h.lfloat.is_empty() or (not h.pad.is_empty() and h.pad.has("face"))


## How far through the climbing part of a mantle you are (0 when not mantling), for the animation.
static func mantle_k(h: Hunter) -> float:
	if not h.lfloat.is_empty():
		return 1.0
	if h.pad.is_empty() or not h.pad.has("face"):
		return 0.0
	var k := clampf(float(h.pad["t"]) / float(h.pad["dur"]), 0.0, 1.0)
	return 1.0 if k < float(h.pad["split"]) + 0.15 else 0.0


static func _try_ledge_grab(h: Hunter, dt: float) -> void:
	if (
		not h.lfloat.is_empty()
		or h.grap.size() > 0
		or h.pad.size() > 0
		or h.fly_t > 0.0
		or h.charge.size() > 0
		or h.dropping
		or h.shot_down
		or h.pos.y < h.last_gy - 14.0
		or h.stun_t > 0.0
		or h.root_t > 0.0
	):
		h.push_t = 0.0
		return
	var w: World = h.m.world
	var mv: Vector2 = h.inp["move"]
	var reach := 0.0
	var max_rise := HunterFeel.mantle_reach + (HunterFeel.tall_climb_extra if HunterMove.climbs_tall(h) else 0.0)
	if h.grounded:
		# as in Supervive, walking into a wall doesn't climb it: jump, and you mantle at the top.
		# Bots still lean their way up so their paths work.
		if mv.length() < 0.5 or h.grap_cd > 0.0 or h.ctrl == "local":
			h.push_t = 0.0
			return
		var probe := Vector2(h.pos.x, h.pos.z) + mv.normalized() * (h.hull_r() + 0.35)
		var g2 := w.ground_at(probe.x, probe.y)
		# (stairs: walked)
		var walkable := g2 <= h.pos.y + World.STEP + w.stair_slope(h.pos.x, h.pos.z, probe.x, probe.y)
		if w.is_block(probe.x, probe.y) or walkable or g2 - h.pos.y > World.LEVEL * 2.0 + 0.05:
			h.push_t = 0.0
			return
		h.push_t += dt
		if h.push_t < 0.08:
			return
		reach = h.hull_r() + 0.6
		max_rise = World.LEVEL * 2.0 + 0.1
	else:
		h.push_t = 0.0
		# a hard launch carries you a moment before you can catch anything
		if h.grap_cd > 0.0 or (h.m.time - h.kb_t < 0.3 and Vector2(h.vel.x, h.vel.z).length() > 8.0):
			return
		# no magnet: you have to be below the edge, right up against the cliff, and pushing into it
		# (or, over the abyss, thrown into its side: the shove counts as the push)
		if mv.length() < 0.3:
			# thrown or glided into the face
			var shoved := h.over_void() or h.gliding or h.glide_off_t < HunterFeel.feather_keep
			if shoved and h.wall_hit_v.length() >= 2.0:
				mv = h.wall_hit_v.normalized()
			elif h.carry_v >= MantleCarry.PUSH_SPEED:
				mv = MantleCarry.heading(h, mv)  # flying in with momentum is a push (item 185b)
			else:
				return
		reach = h.hull_r() + 0.4
	var void_here := h.over_void()
	if not h.grounded and mv.length() > 0.3:
		# a smooth sheer cliff right in front of you has nothing to hold, and its neighbours don't
		# catch you through it either (the deep abyss reach would otherwise reach round its corner)
		var fr := Vector2(h.pos.x, h.pos.z) + mv.normalized() * (h.hull_r() + 0.3)
		var fi := Vector2i(int(floor(fr.x)), int(floor(fr.y)))
		if w.inb(fi.x, fi.y) and w.sheer.has(w.idx(fi.x, fi.y)) and w.ground_at(fr.x, fr.y) > h.pos.y + World.STEP:
			return
	if not h.grounded and void_here and h.last_gy - h.pos.y > 0.3:
		max_rise = HunterFeel.mantle_reach_abyss  # deep in the abyss, any island wall you touch springs you back up
		# and a wall a short step away catches you too: falling at full speed just off a
		# face while steering along it used to slip past (wall-hug check: 15 of 40 at 3m down)
		reach = h.hull_r() + HunterFeel.wall_catch_reach
		var sr := h.hull_r() + HunterFeel.wall_catch_reach + 0.6
		for sz in range(int(floor(h.pos.z - sr)), int(floor(h.pos.z + sr)) + 1):
			for sx in range(int(floor(h.pos.x - sr)), int(floor(h.pos.x + sr)) + 1):
				if w.inb(sx, sz) and w.sheer.has(w.idx(sx, sz)):
					reach = h.r + 0.4  # a smooth sheer cliff nearby: only the usual reach
	var best := {}
	var bd := 1e9
	for z in range(int(floor(h.pos.z - reach)), int(floor(h.pos.z + reach)) + 1):
		for x in range(int(floor(h.pos.x - reach)), int(floor(h.pos.x + reach)) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			# a smooth sheer cliff (authored maps) has nothing to hold: you can't catch it from the air
			if not h.grounded and w.sheer.has(w.idx(x, z)):
				continue
			var gz := w.level[w.idx(x, z)] * World.LEVEL
			var dz := gz - h.pos.y
			if dz < (0.05 if not h.grounded and h.over_void() else World.STEP + 0.05) or dz > max_rise:
				continue
			var ex := clampf(h.pos.x, x + 0.06, x + 0.94)
			var ez := clampf(h.pos.z, z + 0.06, z + 0.94)
			var d := Vector2(ex - h.pos.x, ez - h.pos.z).length()
			var toward := Vector2(ex - h.pos.x, ez - h.pos.z)
			if h.grounded and toward.dot(mv) <= 0.0:
				continue
			# over the abyss below a lip, steering mostly along a wall still counts as pushing
			# into it (up to ~78 degrees off straight in): SUPERVIVE rarely lets a wall-hugger sink under
			# an island. Elsewhere the ledge rise wants keys or momentum into it, up to ~60 degrees off (MantleCarry)
			if not h.grounded and toward.length() > 0.01:
				if void_here and h.last_gy - h.pos.y > 0.3:
					if toward.normalized().dot(mv.normalized()) < 0.2:
						continue
				elif not MantleCarry.pushing(h, toward, mv):
					continue
			if not h.grounded and not void_here:
				# off the void, only a wall you're heading into and that rises above where you last stood:
				# hopping down a terrace must not float you back up it (later, only the plain reach: no tall climb)
				# and one that shares an edge with your tile: the tile ahead along a wall isn't the wall you press
				if absi(x - int(floor(h.pos.x))) + absi(z - int(floor(h.pos.z))) > 1:
					continue
				var stepping_back := (
					gz <= h.last_gy + World.STEP and (dz > HunterFeel.mantle_reach or not GlideLift.airborne_long(h))
				)
				if stepping_back or (toward.dot(mv) <= 0.0 and toward.dot(Vector2(h.vel.x, h.vel.z)) <= 0.0):
					continue
			if d < bd and d < reach:
				bd = d
				best = {"x": x, "z": z, "gz": gz, "ex": ex, "ez": ez}
	if best.is_empty():
		return
	# (ledge rise) no snap and no fixed path: you gain upward momentum and float up the face while
	# your own keys and momentum carry you sideways (see _ledge_rise)
	var dir_in := Vector2(float(best["ex"]) - h.pos.x, float(best["ez"]) - h.pos.z)
	if dir_in.length() < 0.01:
		dir_in = mv
	h.lfloat = {
		"lip": float(best["gz"]),
		"n": dir_in.normalized(),
		"t": 0.0,
		"g0": bool(h.inp.get("glide", false)),
		"shove": (h.inp["move"] as Vector2).length() < 0.3,  # thrown into the side with no keys: it carries you over
		"kb0": h.kb_t,  # (a fresh knock ends the rise; the one that threw you here doesn't)
		"at": Vector2(h.pos.x, h.pos.z),
		"y0": h.pos.y,
		"downed": h.downed,
		"win": false,
		"tile": Vector2i(int(best["x"]), int(best["z"])),
		"v_in": h.carry_v,  # the speed you came in with comes over the top (item 185b)
		"dash_vy": MantleCarry.dash_rise(h),  # a dash hands over: its speed takes you up the face
		"max_t": HunterMove.rise_time(float(best["gz"]) - h.pos.y) * (1.35 if h.downed else 1.0) + 0.3
	}
	if h.grounded:
		h.vel.y = maxf(h.vel.y, HunterFeel.lrise_min)  # walking into it: under way at once
	h.grounded = false
	h.grap = {}
	h.grap_cd = HunterFeel.ledge_cd
	h.push_t = 0.0
	h.roll_t = 0.0
	ClimbSfx.play(h, ClimbSfx.GRAB)
	h.m.on_ledge_grab(h)


static func _ledge_rise(h: Hunter, dt: float, mv: Vector2) -> bool:
	var lf := h.lfloat
	lf["t"] = float(lf["t"]) + dt
	var n: Vector2 = lf["n"]
	var glide_now: bool = h.inp.get("glide", false)
	if not glide_now:
		lf["g0"] = false
	var off := (Vector2(h.pos.x, h.pos.z) - (lf["at"] as Vector2)).dot(-n) > HunterFeel.lrise_off
	# (a teleport; or you've slid along past the end of the face, so there's nothing beside you to rise up)
	var drift := (
		Vector2(h.pos.x, h.pos.z).distance_to(lf.get("last", Vector2(h.pos.x, h.pos.z))) > 1.5
		or not _face_near(h, float(lf["lip"]))
	)
	lf["last"] = Vector2(h.pos.x, h.pos.z)
	var on_top := h.grounded and h.pos.y >= float(lf["lip"]) - 0.05  # stepped onto the top before the pop: topped out
	if (
		off
		or drift
		or h.gliding
		or h.downed != bool(lf["downed"])
		or h.out
		or h.roll_t > 0.0
		or h.stun_t > 0.0
		or h.kb_t > float(lf.get("kb0", h.kb_t))
		or h.fly_t > 0.0
		or (h.grounded and not on_top)
		or h.dropping
		or float(lf["t"]) > float(lf["max_t"])
		or (glide_now and not bool(lf["g0"]))
	):
		h.lfloat = {}
		return false
	# (props raise the top)
	var lip := maxf(float(lf["lip"]), h.m.world.ground_at(h.pos.x + n.x * (h.r + 0.3), h.pos.z + n.y * (h.r + 0.3)))
	var left := lip + 0.12 - h.pos.y
	if left <= 0.0 or on_top:
		# over the lip: a small pop, carried toward your keys
		h.lfloat = {}
		ClimbSfx.play(h, ClimbSfx.MANTLE)
		h.vel.y = HunterFeel.lrise_pop
		var hv := Vector2(h.vel.x, h.vel.z)
		if mv.length() > 0.3:
			var d := mv.normalized()
			var along := hv.dot(d)
			if along < h.base_speed * 0.9:
				hv += d * (h.base_speed * 0.9 - along)
		# keys still leaning into the ledge (or a shove that threw you at it): enough speed onto the top
		# to land on it, on top of whatever your keys asked for
		if (
			(mv.length() > 0.3 and mv.normalized().dot(n) > 0.15)
			or (bool(lf.get("shove", false)) and mv.length() <= 0.3)
		):
			var short := HunterMove.mantle_launch(h.base_speed) - hv.dot(n)
			if short > 0.0:
				hv += n * short
		hv = MantleCarry.exit(h, hv, n, mv, float(lf.get("v_in", 0.0)))
		h.vel.x = hv.x
		h.vel.z = hv.y
		h.mantle_cd = 0.3
		return true
	if not bool(lf["win"]) and left <= HunterFeel.lrise_window:
		# the fling window opens: a tick, so the timing reads
		lf["win"] = true
		if h.is_local():
			h.m.sfx("click", h.pos, -8.0, 1.6)
	var rise := HunterMove.rise_vy(h.vel.y, left, 0.75 if h.downed else 1.0, HunterFeel.lrise_speed, dt)
	h.vel.y = maxf(rise, float(lf["dash_vy"]))
	return true


## A jump during a ledge rise: in the window near the top, a strong fling (higher, faster, a whoosh);
## earlier, a weaker one. Either way toward the keys you hold (or up and onto the ledge with none).
static func _ledge_fling(h: Hunter) -> void:
	var lf := h.lfloat
	h.lfloat = {}
	var mvv: Vector2 = h.inp.get("move", Vector2.ZERO)
	var d: Vector2 = mvv.normalized() if mvv.length() > 0.3 else (lf["n"] as Vector2)
	var hv := Vector2(h.vel.x, h.vel.z)
	var timed: bool = lf.get("win", false)
	var spd := HunterFeel.fling_speed if timed else h.base_speed
	hv = MantleCarry.fling(h, hv, d, spd)
	h.vel.x = hv.x
	h.vel.z = hv.y
	# up speed to peak fling_height (or fling_early_height) over the top from wherever you are on the face
	var left := maxf(0.0, float(lf["lip"]) + 0.12 - h.pos.y)
	h.vel.y = sqrt(2.0 * Hunter.H_GRAV * (left + (HunterFeel.fling_height if timed else HunterFeel.fling_early_height)))
	h.mantle_cd = 0.3
	h.air_t = 0.0  # (held Space opens the glider a beat later, as after any jump)
	h.stats["flings"] = int(h.stats.get("flings", 0)) + (1 if timed else 0)
	h.m.sfx("jump", h.pos, -6.0)
	if timed:
		h.m.sfx("whoosh", h.pos, -6.0 if h.is_local() else -12.0, 1.3)
		h.m.fx.ghost(h.position, h.face, Color("e6f6ff"), float(h.cdat["scale"]))


## Floating up the side: rise to the lip, drift onto it, then a small hop onto the top.
static func _grapple(h: Hunter, dt: float) -> void:
	h.grap["t"] += dt
	var tz: float = h.grap["gz"] + 0.5
	var rise := clampf(tz - h.pos.y, -HunterFeel.float_speed * dt, HunterFeel.float_speed * dt)
	h.pos.y += rise
	var hd := Vector2(h.grap["ex"] - h.pos.x, h.grap["ez"] - h.pos.z)
	var hs := 11.0 * dt
	if hd.length() <= hs:
		h.pos.x = h.grap["ex"]
		h.pos.z = h.grap["ez"]
	else:
		var hn := hd.normalized() * hs
		h.pos.x += hn.x
		h.pos.z += hn.y
	h.vel = Vector3.ZERO
	h.grounded = false
	h.grap["fx"] -= dt
	if h.grap["fx"] <= 0.0:
		h.grap["fx"] = 0.07
		h.m.fx.debris(h.pos + Vector3(0, 0.6, 0), Color("cfeaff"), 2, 1.2, 0.35, 0.0)
	if (absf(tz - h.pos.y) < 0.02 and hd.length() < 0.05) or h.grap["t"] > 2.0:
		h.pos = Vector3(h.grap["ex"], maxf(h.pos.y, tz), h.grap["ez"])
		var land: Vector3 = h.grap["land"]
		h.grap = {}
		h.pad = {"from": h.pos, "to": land, "t": 0.0, "dur": 0.22, "h": 0.4, "ledge": true}


## Is there ground at the ledge's height within reach of your side (the face you're rising up)?
static func _face_near(h: Hunter, lip: float) -> bool:
	var w: World = h.m.world
	var rr := h.r + HunterFeel.wall_catch_reach + 0.2
	for z in range(int(floor(h.pos.z - rr)), int(floor(h.pos.z + rr)) + 1):
		for x in range(int(floor(h.pos.x - rr)), int(floor(h.pos.x + rr)) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			if absf(w.level[w.idx(x, z)] * World.LEVEL - lip) > 0.05:
				continue
			var ex := clampf(h.pos.x, x, x + 1.0)
			var ez := clampf(h.pos.z, z, z + 1.0)
			if Vector2(ex - h.pos.x, ez - h.pos.z).length() <= rr:
				return true
	return false
