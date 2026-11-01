extends RefCounted
## --mantle-check: ledges you mean to climb, you climb; ledges you don't, never grab you.
## The ledge float (Hunter._ledge_float): touching the side of ground above you in the air while your
## keys push into it floats you up the face, and you keep steering the whole time.
##   1. Below an island's rim over the void, pushing back in: you float up and land on top, without
##      ever being inside the cliff (also as a downed wisp).
##   2. Jumping at a wall two terraces high while pushing into it: you end up on top.
##   3. Walking along a wall, jumping beside one with the keys along it, or standing and jumping next
##      to one with no keys: no float, and you're never moved toward the wall.
##   4. Mid-rise your keys change your path: steering along the face moves you along it; steering
##      away takes you off it (nothing holds you there).
##   6. The fling: a jump in the window near the top flings you higher and further than a jump before
##      it or no jump at all.
##   5. Sheer cliffs (authored maps) never catch you.
## Counts fixed simulation steps; never touches the save. Prints "MCHECK ok|FAIL ..." lines and
## "MCHECK DONE, failures: N".

const DT := Match.DT
var bad := 0
var m: Match
var w: World
var h: Hunter

func ok(cond: bool, msg: String) -> void:
	print("MCHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	h = m.hunters[0]
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(Vector3(-500, 50, -500)); o.out = true
	h.ctrl = "local"      # players float up on a jump or a fall, never by walking into walls
	# the kin sits this one out: a kin fainting off a cliff mid-trial would wipe the downed hunter's squad
	for kk in [h.kin, h.kin2]:
		if kk: m.kins.erase(kk); kk.queue_free()
	h.kin = null; h.kin2 = null
	w = m.world
	_rims()
	var walls := _walls(2)
	if walls.size() < 4:
		walls.append_array(_carve_walls(6 - walls.size()))
	print("MCHECK %d walls two terraces high to test against" % walls.size())
	_jump_climbs(walls)
	_no_grab(walls)
	_steering(walls)
	_fling(walls)
	_sheer()
	print("MCHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _reset(at: Vector3, v := Vector3.ZERO, grounded := false) -> void:
	h.out = false; h.downed = false; h.down_hp = 100.0; h.hp = h.max_hp
	h.teleport(at)
	h.grounded = grounded; h.vel = v; h.pad = {}; h.grap = {}; h.grap_cd = 0.0; h.mantle_cd = 0.0; h.roll_t = 0.0
	h.lfloat = {}; h.gliding = false; h.knock_t = 0.0; h.fly_t = 0.0; h.stun_t = 0.0; h.kb_t = -9.0
	h.dropping = false; h.diving = false; h.last_gy = at.y; h.air_t = 0.0 if grounded else 0.3
	for k in ["glide", "jump", "dash", "fire"]: h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

# ---------------------------------------------------------------- 1. rims over the void
func _rims() -> void:
	var tried := 0; var good := 0; var clip := 0; var worst := 0.0; var durs: Array = []
	for downed_case in [false, true]:
		for trial in 12:
			# find an edge: a ground tile next to the void
			var at := Vector3.INF; var dir := Vector2.ZERO
			for k in 400:
				var g := w.random_ground()
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					# on an authored map only rims with a lip can be grabbed; sheer ones are checked below
					var rim_ok := w.lip.is_empty() or w.lip.has(w.idx(int(floor(g.x + d.x * 0.9)), int(floor(g.z + d.y * 0.9)))) or w.lip.has(w.idx(int(floor(g.x)), int(floor(g.z))))
					# (and open air where the hunter hangs: not under a bridge running past the rim)
					var open_below := true
					for dd in [1.1, 1.6, 2.2, 2.8, 3.4]:
						if not w.is_void(g.x + d.x * dd + d.y * 0.4, g.z + d.y * dd + d.x * 0.4) or not w.is_void(g.x + d.x * dd - d.y * 0.4, g.z + d.y * dd - d.x * 0.4): open_below = false
					if w.is_void(g.x + d.x * 1.6, g.z + d.y * 1.6) and not w.is_void(g.x, g.z) and k % 12 == trial and rim_ok and open_below:
						at = g; dir = d; break
				if at != Vector3.INF: break
			if at == Vector3.INF: continue
			tried += 1
			var top := w.ground_at(at.x, at.z)
			# hanging in the air just off the edge, 2.5m below the lip, pushing back toward the island
			# (the side of an island catches you up to Hunter.MANTLE_REACH_ABYSS below its lip; see --abyss-check)
			var edge_x := at.x; var edge_z := at.z
			while not w.is_void(edge_x + dir.x * 0.25, edge_z + dir.y * 0.25):
				edge_x += dir.x * 0.25; edge_z += dir.y * 0.25
			_reset(Vector3(edge_x + dir.x * (h.r + 0.6), top - 2.5, edge_z + dir.y * (h.r + 0.6)), Vector3(0, -2.0, 0))
			h.downed = downed_case
			h.last_gy = top
			var t := 0.0; var floated := false; var landed := false; var t_m := 0.0
			while t < 3.0:
				h.inp["move"] = -dir
				m.step(DT); t += DT
				if h.mantling():
					if not floated: t_m = t
					floated = true
					# inside the cliff: standing below solid ground that's under you
					var gh := w.ground_at(h.pos.x, h.pos.z)
					if not w.is_void(h.pos.x, h.pos.z) and gh > h.pos.y + 0.06:
						clip += 1; worst = maxf(worst, gh - h.pos.y)
				if floated and not h.mantling() and h.grounded:
					landed = absf(h.pos.y - top) < 0.6
					durs.append(snappedf(t - t_m, 0.01))
					break
			if floated and landed: good += 1
	h.downed = false
	print("MCHECK rims: climb times %s" % str(durs))
	ok(tried > 0 and good == tried, "below a rim over the void, pushing in: floated up and landed on top %d of %d (half as a downed wisp)" % [good, tried])
	ok(clip == 0, "never inside the cliff while floating (%d frames, worst %.2fm)" % [clip, worst])
	var slow := 0.0
	for dd in durs: slow = maxf(slow, float(dd))
	ok(durs.size() > 0 and slow < 1.4, "a 2.5m float to the top takes at most %.2fs (want < 1.4s; [footage] ~0.8s from a full second deep)" % slow)

# ---------------------------------------------------------------- walls to test against
## Ground tiles with a neighbour exactly `lv` terraces higher, and open level ground 3m back from the
## wall and 2.5m along it both ways: {at (on the low side, touching), n (into the wall), top}.
func _walls(lv: int) -> Array:
	var out: Array = []
	for z in range(2, w.h - 2):
		for x in range(2, w.w - 2):
			if out.size() >= 16: return out
			var i := w.idx(x, z)
			if w.kind[i] != World.T_GROUND: continue
			var l0 := int(w.level[i])
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var hi: Vector2i = Vector2i(x, z) + d
				if not w.inb(hi.x, hi.y): continue
				var j := w.idx(hi.x, hi.y)
				if w.kind[j] != World.T_GROUND or int(w.level[j]) != l0 + lv or w.sheer.has(j): continue
				# a straight wall: the tiles beside the high one are just as high, the low side is open and level
				var side := Vector2i(int(d.y), int(d.x))
				var good := true
				for s in range(-2, 3):
					var hs: Vector2i = hi + side * s
					var ls: Vector2i = Vector2i(x, z) + side * s
					if not w.inb(hs.x, hs.y) or w.kind[w.idx(hs.x, hs.y)] != World.T_GROUND or int(w.level[w.idx(hs.x, hs.y)]) != l0 + lv: good = false
					for back in range(0, 4):
						var lb: Vector2i = ls - d * back
						if not w.inb(lb.x, lb.y) or w.kind[w.idx(lb.x, lb.y)] != World.T_GROUND or int(w.level[w.idx(lb.x, lb.y)]) != l0: good = false
				if not good: continue
				var n := Vector2(d)
				# the wall face is the high tile's near edge
				var face := Vector2(hi.x + 0.5, hi.y + 0.5) - n * 0.5
				out.append({"at": face - n * (h.r + 0.02), "n": n, "low": l0 * World.LEVEL, "top": (l0 + lv) * World.LEVEL})
				break
	return out

## Raises a 5x3 block two terraces high beside flat open ground (the map has too few straight walls
## of its own): the same {at, n, low, top} as _walls.
func _carve_walls(n_want: int) -> Array:
	var out: Array = []
	for k in 3000:
		if out.size() >= n_want: break
		var g := w.random_ground()
		var x0 := int(floor(g.x)); var z0 := int(floor(g.z))
		var lv := int(w.level[w.idx(x0, z0)])
		var good := true
		for dz in range(-4, 5):
			for dx in range(-5, 6):
				var tx := x0 + dx; var tz := z0 + dz
				if not w.inb(tx, tz): good = false; break
				var i := w.idx(tx, tz)
				if w.kind[i] != World.T_GROUND or int(w.level[i]) != lv or w.stairs.has(i) or w.walls.has(i): good = false
			if not good: break
		if not good: continue
		for dz in range(-2, 3):
			for dx in range(1, 4):
				w.level[w.idx(x0 + dx, z0 + dz)] = lv + 2
		var face := Vector2(x0 + 1.0, z0 + 0.5)
		out.append({"at": face - Vector2(1, 0) * (h.r + 0.02), "n": Vector2(1, 0), "low": lv * World.LEVEL, "top": (lv + 2) * World.LEVEL})
	return out

# ---------------------------------------------------------------- 2. jump at a high wall and climb it
func _jump_climbs(walls: Array) -> void:
	var tried := 0; var good := 0
	for wl in walls:
		var n: Vector2 = wl["n"]
		var at: Vector2 = (wl["at"] as Vector2) - n * 1.2
		_reset(Vector3(at.x, wl["low"], at.y), Vector3.ZERO, true)
		m.step(DT)
		tried += 1
		var floated := false
		for i in 120:
			h.inp["move"] = n
			h.inp["jump"] = i == 8
			m.step(DT)
			if h.mantling(): floated = true
			if floated and h.grounded and absf(h.pos.y - float(wl["top"])) < 0.1: good += 1; break
	ok(tried > 0 and good == tried, "jumping at a wall two terraces high (1.6m) while pushing into it: on top %d of %d" % [good, tried])

# ---------------------------------------------------------------- 3. never grabbed when you don't push in
func _no_grab(walls: Array) -> void:
	var cases := 0; var grabbed := 0; var pulled := 0.0
	for wl in walls:
		var n: Vector2 = wl["n"]
		var along := Vector2(-n.y, n.x)
		# a) walking along the wall, touching it; b) jumping along it; c) standing and jumping next to it
		# with no keys; d) jumping along it with the keys 30 degrees off the face (glancing)
		for mode in ["walk", "jump", "still", "glance"]:
			cases += 1
			var at: Vector2 = wl["at"] - along * 1.5
			if mode == "still": at = wl["at"]
			_reset(Vector3(at.x, wl["low"], at.y), Vector3.ZERO, true)
			m.step(DT)
			var keys := Vector2.ZERO
			if mode == "walk" or mode == "jump": keys = along
			if mode == "glance": keys = along.rotated(-deg_to_rad(25.0) * signf(along.cross(n)))
			var got := false
			for i in 30:      # (0.5s: stays alongside the wall, short of its ends)
				h.inp["move"] = keys
				h.inp["jump"] = mode != "walk" and i == 3
				var b := Vector2(h.pos.x, h.pos.z)
				m.step(DT)
				var a := Vector2(h.pos.x, h.pos.z)
				if h.mantling(): got = true
				# moved toward the wall more than the keys asked
				pulled = maxf(pulled, (a - b).dot(n) - maxf(0.0, keys.dot(n)) * h.base_speed * 1.3 * DT)
			if got:
				grabbed += 1
				print("MCHECK   floated: %s along the wall at %s (keys %s)" % [mode, str(at), str(keys)])
	ok(grabbed == 0, "walking or jumping along a wall, glancing it, or jumping beside it with no keys: no float in %d cases (%d floated)" % [cases, grabbed])
	ok(pulled <= 0.004, "never moved toward the wall more than the keys ask (worst %.4fm in a step)" % pulled)

# ---------------------------------------------------------------- 4. your keys steer mid-float
func _steering(walls: Array) -> void:
	var cases := 0; var steered := 0; var let_go := 0; var worst_side := 1e9
	for wl in walls:
		var n: Vector2 = wl["n"]
		var along := Vector2(-n.y, n.x)
		var res := {}
		for mode in ["in", "along", "away"]:
			var at: Vector2 = wl["at"] - n * 0.6
			_reset(Vector3(at.x, wl["low"], at.y), Vector3.ZERO, true)
			m.step(DT)
			var start := Vector2.INF
			var went := false; var left_at := -1
			for i in 90:
				var keys := n
				if start != Vector2.INF and i - int(res.get("i0_" + mode, 0)) >= 3:
					if mode == "along": keys = (n + along * 2.0).normalized()      # mostly along, still a bit in
					if mode == "away": keys = -n
				h.inp["move"] = keys
				h.inp["jump"] = i == 2
				m.step(DT)
				if start == Vector2.INF and h.mantling():
					start = Vector2(h.pos.x, h.pos.z); res["i0_" + mode] = i; went = true
				if mode == "away" and went and left_at < 0 and not h.mantling():
					left_at = i - int(res["i0_" + mode])
				if start != Vector2.INF and i - int(res["i0_" + mode]) >= 12:
					break
			if not went:
				res[mode] = null
				continue
			res[mode] = Vector2(h.pos.x, h.pos.z)
			res["start_" + mode] = start
			if mode == "away": res["left"] = left_at
		if res.get("in") == null or res.get("along") == null or res.get("away") == null:
			continue
		cases += 1
		var side: float = ((res["along"] as Vector2) - (res["start_along"] as Vector2)).dot(along) - ((res["in"] as Vector2) - (res["start_in"] as Vector2)).dot(along)
		worst_side = minf(worst_side, side)
		if side > 0.25: steered += 1
		var back: float = ((res["away"] as Vector2) - (res["start_away"] as Vector2)).dot(-n)
		if back > 0.15: let_go += 1
	ok(cases > 0 and steered == cases, "steering along the face mid-float moves you along it: %d of %d (least %.2fm further along in 0.15s)" % [steered, cases, worst_side if cases > 0 else 0.0])
	ok(cases > 0 and let_go == cases, "steering away mid-rise flings you off the face (nothing holds you to it): %d of %d" % [let_go, cases])

# ---------------------------------------------------------------- 6. the fling
## Jump at a 1.6m wall, rise, and: no jump / a jump as soon as the rise starts / a jump in the window.
## Height reached above the top and distance onto it, keys held into the wall.
func _fling(walls: Array) -> void:
	if walls.is_empty():
		return
	var res := {}
	for mode in ["none", "early", "timed"]:
		var hs := 0.0; var ds := 0.0; var nn := 0
		for wl in walls.slice(0, 6):
			var n: Vector2 = wl["n"]
			# in the air beside the face, 1.35m below its top (the whole rise to play with), pushing in
			var at: Vector2 = (wl["at"] as Vector2) - n * 0.05
			var top: float = wl["top"]
			_reset(Vector3(at.x, top - 1.35, at.y), Vector3.ZERO, false)
			var rising := 0; var peak := -1e9; var x_top := Vector2.INF; var jumped := false
			for i in 120:
				h.inp["move"] = n
				var jump := false
				if h.mantling(): rising += 1
				if not jumped and h.mantling():
					if mode == "early" and rising == 2: jump = true; jumped = true
					if mode == "timed" and bool(h.lfloat.get("win", false)): jump = true; jumped = true
				h.inp["jump"] = jump
				m.step(DT)
				if rising > 0 and not h.mantling():
					peak = maxf(peak, h.pos.y)
					if x_top == Vector2.INF: x_top = Vector2(h.pos.x, h.pos.z)
				if rising > 0 and h.grounded and not h.mantling():
					break
			if x_top == Vector2.INF: continue
			nn += 1
			hs += peak - top
			ds += (Vector2(h.pos.x, h.pos.z) - x_top).dot(n)
		res[mode] = [hs / maxf(1.0, nn), ds / maxf(1.0, nn), nn]
	print("MCHECK fling: none +%.2fm %.2fm on, early +%.2fm %.2fm, timed +%.2fm %.2fm (over %d walls)" % [res["none"][0], res["none"][1], res["early"][0], res["early"][1], res["timed"][0], res["timed"][1], res["timed"][2]])
	ok(res["timed"][0] > res["none"][0] + 0.3 and res["timed"][0] > res["early"][0] and res["timed"][1] > res["none"][1], "a jump timed in the window near the top flings you higher and further than an early one or none")

# ---------------------------------------------------------------- 5. sheer cliffs
func _sheer() -> void:
	if w.sheer.is_empty():
		return
	var s_tried := 0; var s_caught := 0
	var sheer_keys: Array = w.sheer.keys()
	for trial in 12:
		var i: int = sheer_keys[(trial * 37) % sheer_keys.size()]
		var gx := float(i % w.w) + 0.5; var gz := float(i / w.w) + 0.5
		var dir := Vector2.ZERO
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			if w.is_void(gx + d.x, gz + d.y): dir = d; break
		if dir == Vector2.ZERO: continue
		s_tried += 1
		var top := w.ground_at(gx, gz)
		_reset(Vector3(gx + dir.x * (0.5 + h.r + 0.6), top - 3.0, gz + dir.y * (0.5 + h.r + 0.6)), Vector3(0, -2.0, 0))
		h.last_gy = top
		var t := 0.0
		while t < 1.5:
			h.inp["move"] = -dir
			m.step(DT); t += DT
			if h.mantling() and h.lfloat.has("tile"):
				# caught: fine only if it was a lip tile away from the sheer one, not it or its neighbour
				var lt: Vector2i = h.lfloat["tile"]
				if w.sheer.has(w.idx(lt.x, lt.y)) or Vector2(lt.x + 0.5 - gx, lt.y + 0.5 - gz).length() < 1.2:
					s_caught += 1
					print("MCHECK   sheer caught: sheer tile (%.1f, %.1f) dir %s, rose from tile %s, hunter at %s, %.2fm under the top" % [gx, gz, str(dir), str(lt), str(h.pos.snapped(Vector3(0.01, 0.01, 0.01))), top - h.pos.y])
				break
	ok(s_caught == 0, "sheer cliffs: caught %d of %d falling past (should be 0)" % [s_caught, s_tried])
