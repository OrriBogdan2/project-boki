extends RefCounted
## --wallmove-check: wall kick, wall bounce, ledges that always answer, and the springy abyss lift.
##   1. Wall kick (item 149): a jump pressed against a wall you push into adds about one terrace of height,
##      again on every press (a wall dance), up to WallMoves.HOP_CLIMB_CAP over the take-off. Jump + kick +
##      mantle tops a four-terrace wall (Cinder Steps' plateau); a five-terrace wall stays sheer however much
##      you hop, and the glider never opens from it.
##      Facing a wall with no keys, ten hops in a row, each with its scuff, and never a glider; a standing
##      jump at a one-terrace ledge mantles onto it.
##   2. Wall bounce: an angled hit with speed reflects and keeps most of the speed; head-on it doesn't.
##   3. Ledges: a glide release against a two-terrace ledge, and falling past one, put you on top;
##      keys along or away from the wall never do.
##   4. Abyss lift: opening the glider deep under a lip climbs higher and hangs longer at the top.
##   5. One case per Hunter (wallmove_hunters_check.gd): kick and bounce from a run, a jump, the dash and
##      each ability's recovery, tapped and held.
## Counts fixed simulation steps; never touches the save. Prints "WCHECK ok|FAIL ..." lines and
## "WCHECK DONE, failures: N".

const DT := Match.DT
const DANCE_S := 8.0            # s of wall dancing (a hop is ~0.66 s from the cap to its apex and back)
const LIFT_PEAK_MIN := 0.6      # m above the lip the lift must float to (a lift used to stop at the lip)
const LIFT_HANG_MIN := 0.25     # s spent near the top of the lift (|vertical speed| < 1 m/s, above the lip)
var bad := 0
var m: Match
var w: World
var h: Hunter

func ok(cond: bool, msg: String) -> void:
	print("WCHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	h = m.hunters[0]
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h:
			o.teleport(Vector3(-500, 50, -500))
			o.out = true
	h.ctrl = "local"
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	w = m.world
	var w4: Dictionary = _carve(4, 1)[0]
	var w5 := _carve(5, 2)
	_kick(w4, w5[0], w5[1])
	_dance(w5[1])
	_stand_mantle(_carve(1, 1)[0])
	_bounce(w4)
	_ledges(_carve(2, 2)[0])
	_lift()
	_guards(_carve(2, 1)[0], w5[0])
	_hunters(main)
	print("WCHECK DONE, failures: ", bad)
	main.get_tree().quit()

## 5. Every Hunter: kick and bounce from a run, a jump, the dash and each ability's recovery (own file).
func _hunters(main: Node) -> void:
	load("res://tools/wallmove_hunters_check.gd").new().run(main, func(a: String, blocked: Array) -> void:
		var what := "" if blocked.is_empty() else ": " + ", ".join(blocked)
		ok(blocked.is_empty(), "%s: wall kick and bounce, nothing blocked%s" % [a, what]))

func _reset(at: Vector3, grounded: bool, v := Vector3.ZERO) -> void:
	h.out = false
	h.downed = false
	h.hp = h.max_hp
	h.teleport(at)
	h.grounded = grounded
	h.vel = v
	h.pad = {}
	h.grap = {}
	h.grap_cd = 0.0
	h.mantle_cd = 0.0
	h.roll_t = 0.0
	h.lfloat = {}
	h.gliding = false
	h.glide_fuel = 1.0
	h.glide_cd = 0.0
	h.knock_t = 0.0
	h.fly_t = 0.0
	h.stun_t = 0.0
	h.kb_t = -9.0
	h.dropping = false
	h.last_gy = at.y
	h.air_t = 0.0 if grounded else 0.5
	h.wall_moves.land()
	h.wall_touch_t = 0.0
	h.glide_lift.kicked = false
	h.glide_lift.hang_t = 0.0
	h.shot_down = false
	h.root_t = 0.0
	for k in ["glide", "jump", "dash", "fire"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

## Raises 5x3 blocks `ups` terraces high beside flat open ground (one per call count): {at, n, low, top}.
func _carve(ups: int, count: int) -> Array:
	var out: Array = []
	for k in 6000:
		if out.size() >= count:
			break
		var g := w.random_ground()
		var x0 := int(floor(g.x))
		var z0 := int(floor(g.z))
		var lv := int(w.level[w.idx(x0, z0)])
		var good := true
		for dz in range(-4, 5):
			for dx in range(-5, 8):
				var tx := x0 + dx
				var tz := z0 + dz
				if not w.inb(tx, tz) or w.kind[w.idx(tx, tz)] != World.T_GROUND:
					good = false
					break
				var i := w.idx(tx, tz)
				if int(w.level[i]) != lv or w.stairs.has(i) or w.walls.has(i) or w.sheer.has(i):
					good = false
			if not good:
				break
		if not good:
			continue
		for dz in range(-2, 3):
			for dx in range(1, 4):
				w.level[w.idx(x0 + dx, z0 + dz)] = lv + ups
		var face := Vector2(x0 + 1.0, z0 + 0.5)
		out.append({"at": face - Vector2(1, 0) * (h.r + 0.02), "n": Vector2(1, 0),
			"low": lv * World.LEVEL, "top": (lv + ups) * World.LEVEL, "x0": x0, "z0": z0})
	return out

# ---------------------------------------------------------------- 1. wall kick
## Jump at the wall pushing in; with `kick`, press jump again on the way down (spammed: it must fire once).
## Returns {peak, top, kicks}.
func _attempt(wl: Dictionary, kick: bool, spam := true) -> Dictionary:
	var n: Vector2 = wl["n"]
	var at: Vector2 = (wl["at"] as Vector2) - n * 1.0
	_reset(Vector3(at.x, wl["low"], at.y), true)
	m.step(DT)
	var kicks0 := int(h.stats.get("wall_kicks", 0))
	var peak := -1e9
	var on_top := false
	var left_ground := false
	var presses := 0
	for i in 150:
		h.inp["move"] = n
		var falling := not h.grounded and h.vel.y <= 0.5 and h.lfloat.is_empty()
		var press := kick and i > 6 and falling and (spam or presses == 0)
		presses += 1 if press else 0
		h.inp["jump"] = i == 6 or press
		m.step(DT)
		peak = maxf(peak, h.pos.y)
		left_ground = left_ground or not h.grounded
		if h.grounded and absf(h.pos.y - float(wl["top"])) < 0.1:
			on_top = true
			break
		if left_ground and h.grounded:
			break
	return {"peak": peak - float(wl["low"]), "top": on_top, "kicks": int(h.stats.get("wall_kicks", 0)) - kicks0}

func _kick(w4: Dictionary, w5: Dictionary, w5b: Dictionary) -> void:
	var a4 := _attempt(w4, false)
	var k4 := _attempt(w4, true, false)
	ok(not a4["top"], "jump + mantle alone doesn't reach 4 terraces (3.2m): peak %.2fm" % a4["peak"])
	ok(k4["top"] and k4["kicks"] == 1, "kick + mantle tops 4 terraces (Cinder Steps): %d kick" % k4["kicks"])
	var plain := _attempt(w5, false)
	var kicked := _attempt(w5, true, false)
	var gain: float = kicked["peak"] - plain["peak"]
	ok(kicked["kicks"] == 1 and gain > 0.7 and gain < 1.1,
		"a kick: +%.2fm over a plain jump (%.2fm to %.2fm)" % [gain, plain["peak"], kicked["peak"]])
	var danced := _attempt(w5, true)
	ok(danced["kicks"] >= 3 and not danced["top"] and not h.gliding,
		"spammed: %d kicks, a 5-terrace wall (4.0m) still sheer (peak %.2fm), no glider" % [
			danced["kicks"], danced["peak"]])
	var again := _attempt(w5b, true, false)
	var same := absf(again["peak"] - kicked["peak"]) < 0.15
	ok(again["kicks"] == 1 and same, "the next jump kicks the same: %.2fm" % again["peak"])

## Facing the wall, no keys: Space on every fall for DANCE_S. Ten hops, ten scuffs, the glider never opens.
func _dance(wl: Dictionary) -> void:
	var n: Vector2 = wl["n"]
	var at: Vector2 = (wl["at"] as Vector2) - n * 0.1
	_reset(Vector3(at.x, wl["low"], at.y), true)
	h.inp["aim"] = Vector3(at.x + n.x * 6.0, float(wl["low"]) + 0.9, at.y + n.y * 6.0)
	var kicks0 := int(h.stats.get("wall_kicks", 0))
	var scuffs0 := WallMoves.scuffs
	var opened := false
	var t := 0.0
	while t < DANCE_S:
		var falling := not h.grounded and h.vel.y <= 0.0
		h.inp["jump"] = h.grounded or falling
		m.step(DT)
		t += DT
		opened = opened or h.gliding
	var kicks := int(h.stats.get("wall_kicks", 0)) - kicks0
	ok(kicks >= 10 and not opened, "a wall dance: %d hops in %.0fs facing the wall, no glider" % [kicks, DANCE_S])
	ok(WallMoves.scuffs - scuffs0 == kicks, "every hop scuffs (%d of %d)" % [WallMoves.scuffs - scuffs0, kicks])

## A standing jump at a one-terrace ledge, keys into it: on top.
func _stand_mantle(wl: Dictionary) -> void:
	var n: Vector2 = wl["n"]
	var at: Vector2 = (wl["at"] as Vector2) - n * 0.1
	_reset(Vector3(at.x, wl["low"], at.y), true)
	var on_top := false
	for i in 90:
		h.inp["move"] = n
		h.inp["jump"] = i == 2
		m.step(DT)
		if h.grounded and absf(h.pos.y - float(wl["top"])) < 0.1:
			on_top = true
			break
	ok(on_top, "a standing jump mantles a %.1fm ledge" % (float(wl["top"]) - float(wl["low"])))

# ---------------------------------------------------------------- 2. wall bounce
## Airborne at `speed` against the 4-terrace wall, `deg` off its normal. Returns the velocity after contact.
func _hit(wl: Dictionary, deg: float, speed: float, dash := false, grounded_dash := false) -> Vector2:
	var n: Vector2 = wl["n"]
	var dir := (n * 1.0).rotated(deg_to_rad(deg))
	var at: Vector2 = (wl["at"] as Vector2) - n * 0.4
	var y_off := 0.0 if grounded_dash else 0.5
	_reset(Vector3(at.x, wl["low"] + y_off, at.y), grounded_dash, Vector3(dir.x * speed, 0, dir.y * speed))
	if dash:
		h.roll_t = 0.3
		h.roll_dir = dir
		h.roll_speed = speed
	var out := Vector2.ZERO
	for i in 5:
		m.step(DT)
		out = Vector2(h.vel.x, h.vel.z)
		if dash:
			out = h.roll_dir * h.roll_speed
	return out

func _bounce(wl: Dictionary) -> void:
	var n: Vector2 = wl["n"]
	var ang := _hit(wl, 45.0, 10.0)
	var tan0 := 10.0 * sin(deg_to_rad(45.0))
	var along := absf(ang.dot(Vector2(-n.y, n.x)))
	ok(ang.dot(-n) > 5.0 and along > tan0 * 0.7,
		"a 45 degree hit rebounds: away %.1f, along %.1f m/s, kept %.0f%%" % [ang.dot(-n), along, ang.length() * 10.0])
	var head := _hit(wl, 0.0, 10.0)
	ok(head.dot(-n) < 2.0, "head-on it doesn't bounce (away %.1f m/s)" % head.dot(-n))
	var dash := _hit(wl, 40.0, 20.0, true)
	var flat := _hit(wl, 40.0, 20.0, true, true)
	var flat_away := flat.dot(-n)
	ok(flat_away < 0.0 and h.wall_touch_t <= 0.0, "a ground dash slides as before (away %.1f)" % flat_away)
	var away := dash.dot(-n)
	ok(away > 8.0 and dash.length() > 14.0, "a 40 degree dash reflects: %.1f m/s, away %.1f" % [dash.length(), away])
	var slow := _hit(wl, 45.0, 5.0)
	ok(slow.dot(-n) < 2.0, "a walking-speed jump brushing a wall doesn't ricochet (away %.1f m/s)" % slow.dot(-n))

# ---------------------------------------------------------------- 3. ledges
## Plays `frames` steps (keys by `drive`) and returns {top, mantled}.
func _ledge_try(wl: Dictionary, y_off: float, v: Vector3, drive: Callable) -> Dictionary:
	var n: Vector2 = wl["n"]
	var at: Vector2 = (wl["at"] as Vector2) - n * 0.05
	_reset(Vector3(at.x, wl["low"] + y_off, at.y), false, v)
	h.last_gy = float(wl["low"]) + 6.0      # launched from a much higher place: the ledge is still ahead of you
	h.air_t = 0.8
	var mantled := false
	for i in 90:
		drive.call(i, n)
		m.step(DT)
		mantled = mantled or h.mantling()
		if h.grounded and absf(h.pos.y - float(wl["top"])) < 0.1:
			return {"top": true, "mantled": mantled}
	return {"top": false, "mantled": mantled}

func _ledges(wl: Dictionary) -> void:
	var glide_keys := func(i: int, n: Vector2) -> void:
		h.gliding = i == 0 or h.gliding
		h.inp["move"] = n
		h.inp["glide"] = i < 4
	var glide_nokeys := func(i: int, n: Vector2) -> void:
		h.gliding = i == 0 or h.gliding
		h.vel.x = n.x * 6.0 if i < 6 else h.vel.x
		h.inp["move"] = Vector2.ZERO
		h.inp["glide"] = i < 4
	var fall := func(_i: int, n: Vector2) -> void:
		h.inp["move"] = n
	var along := func(_i: int, n: Vector2) -> void:
		h.inp["move"] = Vector2(-n.y, n.x)
	var away := func(_i: int, n: Vector2) -> void:
		h.inp["move"] = -n
	var r1 := _ledge_try(wl, 0.8, Vector3.ZERO, glide_keys)
	ok(r1["top"], "pushing into a 2-terrace ledge and releasing the glider puts you on top")
	var r2 := _ledge_try(wl, 0.8, Vector3.ZERO, glide_nokeys)
	ok(r2["top"], "gliding into the ledge and letting go with no keys puts you on top")
	var r3 := _ledge_try(wl, 1.0, Vector3(0, -6.0, 0), fall)
	ok(r3["top"], "falling past a 2-terrace ledge while pushing into it puts you on top")
	var r4 := _ledge_try(wl, 1.0, Vector3(0, -6.0, 0), along)
	var r5 := _ledge_try(wl, 1.0, Vector3(0, -6.0, 0), away)
	ok(not r4["mantled"] and not r5["mantled"], "keys along or away from the wall never pull you up it")

# ---------------------------------------------------------------- 4. abyss lift
func _rim() -> Dictionary:
	for k in 6000:
		var g := w.random_ground()
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var open := true
			for dd in [1.6, 2.4, 3.2, 4.0, 5.0, 6.0, 8.0]:
				for s in [-0.8, 0.0, 0.8]:
					if not w.is_void(g.x + d.x * dd + d.y * s, g.z + d.y * dd + d.x * s):
						open = false
			if open and not w.is_void(g.x, g.z):
				return {"at": g, "dir": d}
	return {}

func _lift() -> void:
	var edge := _rim()
	if edge.is_empty():
		ok(false, "no open rim found for the abyss lift")
		return
	var g: Vector3 = edge["at"]
	var d: Vector2 = edge["dir"]
	_reset(Vector3(g.x + d.x * 5.0, g.y - 6.0, g.z + d.y * 5.0), false, Vector3(0, -8.0, 0))
	h.last_gy = g.y
	h.update_lip()
	var lip := h.lip_y
	var peak := -1e9
	var hang := 0
	for i in 150:
		h.inp["jump"] = true
		h.inp["glide"] = true
		m.step(DT)
		peak = maxf(peak, h.pos.y - lip)
		if h.pos.y > lip and absf(h.vel.y) < 1.0 and i < 100:
			hang += 1
	print("WCHECK lift: peak %.2fm over the lip, hang %.2fs" % [peak, hang * DT])
	ok(peak >= LIFT_PEAK_MIN, "the lift floats %.2fm above the lip (want >= %.1fm)" % [peak, LIFT_PEAK_MIN])
	ok(hang * DT >= LIFT_HANG_MIN, "and hangs %.2fs near the top (want >= %.2fs)" % [hang * DT, LIFT_HANG_MIN])

# ---------------------------------------------------------------- 5. guards from review
## One open-kick signature: a single step where vertical speed jumps by several m/s.
func _spring_count(tap: bool) -> int:
	var edge := _rim()
	var g: Vector3 = edge["at"]
	var d: Vector2 = edge["dir"]
	_reset(Vector3(g.x + d.x * 5.0, g.y - 6.0, g.z + d.y * 5.0), false, Vector3(0, -8.0, 0))
	h.last_gy = g.y
	h.update_lip()
	var springs := 0
	var last_vy := h.vel.y
	for i in 40:
		h.inp["jump"] = true
		h.inp["glide"] = (i % 4 < 2) if tap else true
		m.step(DT)
		if h.vel.y - last_vy > 4.0:
			springs += 1
		last_vy = h.vel.y
	return springs

func _guards(low_wall: Dictionary, high_wall: Dictionary) -> void:
	var taps := _spring_count(true)
	ok(taps <= 1, "tap-open, release, tap-open springs once, not each time (%d springs)" % taps)
	ok(h.vel.y <= Hunter.ABYSS_LIFT_CAP + 0.01, "the spring never beats the lift cap (%.1f m/s)" % h.vel.y)
	var edge := _rim()
	var g: Vector3 = edge["at"]
	var d: Vector2 = edge["dir"]
	_reset(Vector3(g.x + d.x * 5.0, g.y - 6.0, g.z + d.y * 5.0), false, Vector3(0, -8.0, 0))
	h.last_gy = g.y
	h.update_lip()
	h.shot_down = true
	var top_vy := -99.0
	for i in 10:
		h.inp["jump"] = i % 2 == 0
		h.inp["glide"] = true
		m.step(DT)
		top_vy = maxf(top_vy, h.vel.y)
	ok(top_vy < 1.0 and not h.gliding, "a shot-down glider gets no spring and doesn't open (best %.1f m/s)" % top_vy)
	_stunned(low_wall)
	_one_kick(high_wall)
	_blocked(low_wall)

func _stunned(wl: Dictionary) -> void:
	for mode in ["stun", "root"]:
		var fall := func(_i: int, n: Vector2) -> void:
			h.inp["move"] = n
			if mode == "stun":
				h.stun_t = 1.0
			else:
				h.root_t = 1.0
		var r := _ledge_try(wl, 1.0, Vector3(0, -6.0, 0), fall)
		ok(not r["mantled"], "a %s player falling against a 2-terrace ledge doesn't grab it" % mode)

## A push-off and then a climb kick both go (item 149: no once-per-airtime); a kick folds a held glide.
func _one_kick(wl: Dictionary) -> void:
	var n: Vector2 = wl["n"]
	var at: Vector2 = (wl["at"] as Vector2) - n * 0.05
	_reset(Vector3(at.x, wl["low"] + 1.0, at.y), false, Vector3(0, 0.0, 0))
	h.wall_touch_t = 0.2
	h.wall_n = -n
	h.inp["move"] = -n
	h.inp["jump"] = true
	m.step(DT)
	var pushed := h.vel.dot(Vector3(-n.x, 0, -n.y))
	h.wall_touch_t = 0.2
	h.inp["move"] = n
	var vy0 := h.vel.y
	h.inp["jump"] = true
	m.step(DT)
	ok(pushed > 5.0 and h.vel.y > vy0 + 0.5,
		"a push-off (%.1f m/s) then a climb kick (vy %.1f to %.1f)" % [pushed, vy0, h.vel.y])
	_reset(Vector3(at.x, wl["low"] + 1.0, at.y), false, Vector3.ZERO)
	h.wall_touch_t = 0.2
	h.wall_n = -n
	h.gliding = true
	h.inp["move"] = n
	h.inp["glide"] = true
	h.inp["jump"] = true
	m.step(DT)
	h.inp["jump"] = false
	var v1 := h.vel.y
	m.step(DT)
	m.step(DT)
	var arc := h.vel.y < v1 - Hunter.H_GRAV * DT * 1.5
	ok(not h.gliding and arc, "a kick folds the glider while you rise (vy %.1f to %.1f)" % [v1, h.vel.y])

## Ledge tiles that are blocked (rocks, trees) are never mantled onto.
func _blocked(wl: Dictionary) -> void:
	for dz in range(-2, 3):
		for dx in range(1, 4):
			w.kind[w.idx(int(wl["x0"]) + dx, int(wl["z0"]) + dz)] = World.T_BLOCK
	var fall := func(_i: int, n: Vector2) -> void:
		h.inp["move"] = n
	var r := _ledge_try(wl, 1.0, Vector3(0, -6.0, 0), fall)
	ok(not r["mantled"], "a blocked ledge tile is never mantled onto")
