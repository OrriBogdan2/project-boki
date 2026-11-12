extends RefCounted
## --mantle-check's home vs match part (decision 0022, one movement model): the same ledges, carved
## the same way into the expedition's world and the farm's, climbed by a match Hunter and by the farm
## avatar. Per ledge: the deepest below its lip you catch it (grab reach), a jump at it from a run
## (caught how far below the lip, the rise from the catch to over the lip, jump to standing on top),
## and the float over the top (peak over the lip, speed onto it). Rows print as
## "MCHECK feel <where> <ledge> ..."; measure() returns them for the equality asserts.

const DT := 1.0 / 60.0
const WALLS := [0.8, 1.6, 2.4]     # m: one, two and three terraces
const RIM_DEEPEST := 6.0           # m under an island's rim over the void to look for a catch
const RUN_UP := 1.2                # m from the face the jump-at-it starts

var hm = null          # the farm (Home) when measuring there; null: the match hunter h
var h: Hunter
var w: World
var site := {}         # the carved test site: {x0, z0, lv}

## The rows for the match (home == null) or the farm.
func measure(hunter: Hunter, home, world: World) -> Dictionary:
	h = hunter
	hm = home
	w = world
	site = _flat_site()
	if site.is_empty():
		return {}
	var rows := {}
	for top in WALLS:
		_carve(int(round(top / World.LEVEL)), false)
		var row: Dictionary = await _jump_at(top)
		rows["wall %.1f" % top] = row.merged({"reach": _reach(top - 0.1, false)})
	_carve(0, true)
	rows["rim"] = {"reach": _reach(RIM_DEEPEST, true)}
	_carve(0, false)
	for k in rows:
		var r: Dictionary = rows[k]
		var jump := ""
		if r.has("rise"):
			jump = ", jump: caught %.2fm under, rise %.2fs, on top %.2fs, peak +%.2fm, onto it %.1f m/s" \
				% [r["depth"], r["rise"], r["land"], r["peak"], r["v_top"]]
		print("MCHECK feel %s %s: reach %.1fm%s" % ["home " if hm else "match", k, r["reach"], jump])
	return rows

## Walking off the top of a 1.6 m ledge, and off an island's rim, keys held outward: you drop and
## nothing floats you back up (walking off ledges is always allowed). The body last measured.
func walks_off() -> bool:
	var good := true
	for rim in [false, true]:
		_carve(0 if rim else 2, rim)
		var top := _low() if rim else _top_now()
		var from_x := _face_x() + (1.2 if rim else 2.5)
		_reset(Vector3(from_x, top, float(site["z0"]) + 0.5), true, top)
		for i in 60:
			_step(Vector2(-1, 0), false)
			if _rising(): good = false
		if _pos().y > top - 0.5: good = false
	_carve(0, false)
	return good

# ---------------------------------------------------------------- the site
## 14x9 tiles of open level dry ground: the ledge is a 3x5 block at x0+1..x0+3; the rim case turns
## x0-7..x0 into void, so the face at x0+1 stands over the abyss with flat ground behind it.
func _flat_site() -> Dictionary:
	for k in 4000:
		var g := w.random_ground()
		var x0 := int(floor(g.x))
		var z0 := int(floor(g.z))
		var lv := int(w.level[w.idx(x0, z0)])
		var good := true
		for dz in range(-4, 5):
			for dx in range(-7, 7):
				var tx := x0 + dx
				var tz := z0 + dz
				if not w.inb(tx, tz):
					good = false
					break
				var i := w.idx(tx, tz)
				var wet: bool = hm != null and hm.water.depth(tx + 0.5, tz + 0.5) > 0
				if w.kind[i] != World.T_GROUND or int(w.level[i]) != lv or w.stairs.has(i) or w.walls.has(i) \
						or w.sheer.has(i) or wet or w.occupy(tx + 0.5, tz + 0.5, 0.5, lv * World.LEVEL, false) != 0.0:
					good = false
					break
			if not good: break
		if good:
			return {"x0": x0, "z0": z0, "lv": lv}
	return {}

func _carve(up: int, void_side: bool) -> void:
	var x0: int = site["x0"]
	var z0: int = site["z0"]
	var lv: int = site["lv"]
	for dz in range(-4, 5):
		for dx in range(-7, 7):
			var i := w.idx(x0 + dx, z0 + dz)
			w.kind[i] = World.T_VOID if void_side and dx <= 0 and absi(dz) <= 3 else World.T_GROUND
			w.level[i] = lv + up if dx >= 1 and dx <= 3 and absi(dz) <= 2 else lv

func _face_x() -> float:
	return float(site["x0"]) + 1.0

func _low() -> float:
	return float(site["lv"]) * World.LEVEL

# ---------------------------------------------------------------- the measures
## The deepest under the lip (0.1 m steps) you catch the ledge from, hanging against its face with
## your keys in. Stops at the first depth that misses.
func _reach(deepest: float, rim: bool) -> float:
	var best := 0.0
	var dpt := 0.2
	while dpt <= deepest + 0.001:
		var top := _low() if rim else _top_now()
		_reset(Vector3(_face_x() - _r() - 0.1, top - dpt, float(site["z0"]) + 0.5), false, top if rim else _low())
		var caught := false
		for i in 18:     # 0.3 s
			_step(Vector2(1, 0), false)
			if _rising():
				caught = true
				break
		if not caught: break
		best = dpt
		dpt += 0.1
	return snappedf(best, 0.1)

## A jump at the ledge from a run (at run speed already), keys held in. A ledge you jump clean
## over has no rise (rise 0).
func _jump_at(top: float) -> Dictionary:
	var lip := _low() + top
	_reset(Vector3(_face_x() - _r() - RUN_UP, _low(), float(site["z0"]) + 0.5), true, _low())
	var run := float(HunterMove.of(h.arch if hm == null else String(Save.d.get("arch", "")))["speed"])
	if hm == null: h.vel.x = run
	else: hm.pvel.x = run
	var t := 0.0
	var t_catch := -1.0
	var t_top := -1.0
	var t_land := -1.0
	var depth := 0.0
	var peak := 0.0
	var v_top := 0.0
	for i in 150:
		await _step(Vector2(1, 0), i == 2)
		t += DT
		var p := _pos()
		if t_catch < 0.0 and t_top < 0.0 and _rising():
			t_catch = t
			depth = lip - p.y
		if t_top < 0.0 and p.y >= lip and p.x > _face_x() - _r() - 0.05:
			t_top = t
			v_top = _hvel().length()
		if t_top >= 0.0: peak = maxf(peak, p.y - lip)
		if t_top >= 0.0 and _grounded() and absf(p.y - lip) < 0.05:
			t_land = t - 2.0 * DT
			break
	return {"depth": snappedf(depth, 0.01), "rise": snappedf(t_top - t_catch, 0.01) if t_catch >= 0.0 else 0.0,
		"land": snappedf(t_land, 0.01), "peak": snappedf(peak, 0.01), "v_top": snappedf(v_top, 0.1)}

func _top_now() -> float:
	return w.ground_at(_face_x() + 0.5, float(site["z0"]) + 0.5)

# ---------------------------------------------------------------- one body, match or farm
func _r() -> float:
	return h.r if hm == null else hm._body_r()

func _reset(at: Vector3, grounded: bool, last_gy: float) -> void:
	if hm == null:
		h.teleport(at)
		h.grounded = grounded
		h.vel = Vector3.ZERO
		h.pad = {}
		h.grap = {}
		h.grap_cd = 0.0
		h.mantle_cd = 0.0
		h.roll_t = 0.0
		h.lfloat = {}
		h.gliding = false
		h.knock_t = 0.0
		h.fly_t = 0.0
		h.stun_t = 0.0
		h.kb_t = -9.0
		h.dropping = false
		h.last_gy = last_gy
		h.air_t = 0.0 if grounded else 0.3
		h.glide_off_t = 9.0
		h.carry.forget()
		for k in ["glide", "jump", "dash", "fire"]: h.inp[k] = false
		h.inp["move"] = Vector2.ZERO
		return
	hm.ppos = Vector3(at.x, 0, at.z)
	hm.py = at.y
	hm.pvy = 0.0
	hm.pvel = Vector3.ZERO
	hm.lfl = {}
	hm.gliding = false
	hm.dash_t = 0.0
	hm.last_gy = last_gy
	hm.ledge_cd = 0.0
	hm.air_t = 0.0 if grounded else 0.3
	hm.mcarry.forget()
	hm.safe_at = Vector3(at.x - 3.0, 0, at.z)
	_press(Vector2.ZERO, false)

func _step(keys: Vector2, jump: bool) -> void:
	if hm == null:
		h.inp["move"] = keys
		h.inp["jump"] = jump
		h.m.step(DT)
		return
	# (a press counts as just pressed for the rest of its frame, even released: a frame passes either side)
	if jump: await hm.get_tree().process_frame
	_press(keys, jump)
	hm._move_player(DT)
	if jump:
		Input.action_release("jump")
		await hm.get_tree().process_frame

func _press(dir: Vector2, jump: bool) -> void:
	for a in ["left", "right", "up", "down", "jump", "glide"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)
	if dir.y > 0.1: Input.action_press("down", dir.y)
	if dir.y < -0.1: Input.action_press("up", -dir.y)
	if jump: Input.action_press("jump")

func _pos() -> Vector3:
	return h.pos if hm == null else Vector3(hm.ppos.x, hm.py, hm.ppos.z)

func _hvel() -> Vector2:
	return Vector2(h.vel.x, h.vel.z) if hm == null else Vector2(hm.pvel.x, hm.pvel.z)

func _rising() -> bool:
	return h.mantling() if hm == null else not hm.lfl.is_empty()

func _grounded() -> bool:
	if hm == null:
		return h.grounded
	return hm.pvy == 0.0 and absf(hm.py - w.ground_at(hm.ppos.x, hm.ppos.z)) < 0.01
