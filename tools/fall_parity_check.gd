extends RefCounted
## --fall-parity-check (docs/decisions/0060): one movement profile in every mode, as the owner asked 11-11.
## The same drops, jump and flight run in the tutorial, an expedition, the Training Area (match) and the farm:
##   a straight fall from 3 m and from 10 m ends where it started (no horizontal drift, before or after landing)
##   a fall with the keys held lands at the speed it had in the air, then stops like a let-go from a run
##   a running jump keeps its run speed in the air and on landing (never gains), and every mode has the same arc
##   walking down a flight (one terrace over a tile) keeps your feet on it: no air steps, a let-go stops as on
##   flat ground
##   (match modes) the view's height settles as you land: no on-screen drift forward after a landing
## Prints "FCHECK ok|FAIL ..." and "FCHECK DONE, failures: N".

const DT := 1.0 / 60.0
const MODES := {
	"tutorial": {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "no_drop": true},
	"expedition": {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true},
	"training": {"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242,
		"no_drop": true},
}
const STILL_TOL := 0.02     # m of horizontal drift a straight fall may show
const SPEED_TOL := 0.01     # m/s a landing or a jump may differ from the speed it carried
const SLIDE_TOL := 0.05     # m a stop after a landing or on a flight may slide past a flat let-go
const VIEW_TOL := 0.1       # m (ground-equivalent) the view may drift after a 10 m landing (it was ~0.7)
const LANE := Rect2i(-6, -2, 11, 5)     # tiles round the drop spot the runs cross (the held fall starts 5.3 m back)

var bad := 0
var arcs := {}              # mode -> [air steps, apex m] of the running jump

func ok(cond: bool, what: String) -> void:
	print("FCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## The first spot (scanning out from the map's middle) with flat, open ground over LANE round it.
func _flat_spot(w: World) -> Vector3:
	var c := Vector2i(w.w / 2, w.h / 2)
	for ring in range(0, maxi(w.w, w.h) / 2):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var g := Vector3(c.x + dx + 0.5, 0, c.y + dz + 0.5)
				if _flat_round(w, g):
					g.y = w.ground_at(g.x, g.z)
					return g
	return Vector3.INF

func _flat_round(w: World, g: Vector3) -> bool:
	if g.x < 8 or g.z < 4 or g.x > w.w - 8 or g.z > w.h - 4:
		return false
	var y := w.ground_at(g.x, g.z)
	if y <= World.VOID + 1.0:
		return false
	for dx in range(LANE.position.x, LANE.end.x):
		for dz in range(LANE.position.y, LANE.end.y):
			var q := Vector2(g.x + dx, g.z + dz)
			if absf(w.ground_at(q.x, q.y) - y) > 0.001 or w.stairs.has(w.idx(int(floor(q.x)), int(floor(q.y)))):
				return false
			# a block (a prop's footprint) beside the lane would push a falling body out of its side at its top
			for bz in range(int(floor(q.y)) - 1, int(floor(q.y)) + 2):
				for bx in range(int(floor(q.x)) - 1, int(floor(q.x)) + 2):
					if w.inb(bx, bz) and w.kind[w.idx(bx, bz)] == World.T_BLOCK:
						return false
			if w.occupy(q.x, q.y, 0.45, y, false) != 0.0:
				return false
	return true

## Lays a test flight on the flat spot: the tile at +1 rises one terrace toward +x onto a plateau at +2..+4,
## three tiles wide. Returns the tiles' old [index, level] to put back.
func _lay_flight(w: World, at: Vector3) -> Array:
	var old := []
	for s in range(-1, 2):
		for k in range(1, 5):
			var i := w.idx(int(floor(at.x)) + k, int(floor(at.z)) + s)
			old.append([i, w.level[i]])
			if k == 1: w.stairs[i] = Vector2i(1, 0)
			else: w.level[i] += 1
	return old

func _unlay(w: World, old: Array) -> void:
	for e in old:
		w.stairs.erase(e[0])
		w.level[e[0]] = e[1]

# ---------------------------------------------------------------- the match modes (one Hunter._physics)
var m: Match
var h: Hunter

func _reset(at: Vector3, v: Vector3, standing: bool) -> void:
	# a mode that respawns mobs (the Training Area) must not walk one into the faller: it nudges its position
	if is_instance_valid(m):
		for mb in m.mobs:
			if is_instance_valid(mb): mb.queue_free()
		m.mobs.clear()
	h.teleport(at)
	h.vel = v
	h.grounded = standing
	h.air_peak = at.y
	h.glide_off_t = 9.0
	for k in ["pad", "lfloat", "grap"]:
		h.set(k, {})
	for k in ["roll_t", "fly_t", "knock_t", "stun_t", "coyote", "jump_buf"]:
		h.set(k, 0.0)
	for k in ["gliding", "dropping", "diving"]:
		h.set(k, false)
	h.inp["move"] = Vector2.ZERO
	for k in ["glide", "glide_btn", "jump"]:
		h.inp[k] = false
	MantleCarry.forget(h)
	m.cam.snap(h.pos)

func _hv() -> float:
	return Vector2(h.vel.x, h.vel.z).length()

func _flat() -> Vector2:
	return Vector2(h.pos.x, h.pos.z)

## Steps the match (and the view, as Match._process would) until 0.6 s after touchdown. Returns
## [landed, max air speed, landing speed, flat metres after touchdown, view drift after touchdown (m)].
func _fall(release_on_land: bool) -> Array:
	var air_max := 0.0
	var land_v := -1.0
	var land_at := Vector2.ZERO
	var after := 0
	var sy0 := 0.0
	for i in 600:
		var was := h.grounded
		m.step(Match.DT)
		m.cam.follow(h.render_pos(1.0), Match.DT, false, HunterMove.stand_y(h))
		if land_v < 0.0 and not h.grounded:
			air_max = maxf(air_max, _hv())
		if land_v < 0.0 and h.grounded and not was:
			land_v = _hv()
			land_at = _flat()
			sy0 = _screen_y()
			if release_on_land: h.inp["move"] = Vector2.ZERO
		elif land_v >= 0.0:
			after += 1
			if after >= 36: break
	var drift := (_screen_y() - sy0) * m.cam.dist * m.cam.dist_mul * m.cam.zoom / sin(m.cam.pitch)
	return [land_v >= 0.0, air_max, land_v, _flat().distance_to(land_at), absf(drift)]

## Where the hunter sits on screen (tan of its angle above the view's axis).
func _screen_y() -> float:
	var rel := h.pos - m.cam.position
	var b := m.cam.global_transform.basis
	return rel.dot(b.y) / -rel.dot(b.z)

func _match_mode(main: Node, mode: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start(MODES[mode].duplicate())
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	h = m.player if m.player else m.hunters[0]
	h.set_arch("")
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(m.world.random_ground() + Vector3(0, 0, 0))
	h.ctrl = "local"
	m.opts["god"] = true
	var at := _flat_spot(m.world)
	ok(at != Vector3.INF, "%s: a flat open spot to drop on" % mode)
	if at == Vector3.INF:
		m.queue_free()
		return
	var run := h.base_speed
	for up in [3.0, 10.0]:
		_reset(at + Vector3(0, up, 0), Vector3.ZERO, false)
		var start := _flat()
		var r := _fall(false)
		ok(r[0] and _flat().distance_to(start) < STILL_TOL,
			"%s: a straight fall from %d m lands where it started (%.3f m)" % [mode, up, _flat().distance_to(start)])
		if up == 10.0:
			ok(r[4] < VIEW_TOL,
				"%s: the view settles on landing from 10 m (drifts %.2f m after touchdown)" % [mode, r[4]])
		_reset(at + Vector3(-run * sqrt(2.0 * up / Hunter.H_GRAV), up, 0), Vector3(run, 0, 0), false)
		h.inp["move"] = Vector2(1, 0)
		r = _fall(true)
		ok(r[0] and r[2] <= r[1] + SPEED_TOL and r[3] <= HunterMove.slide(r[2]) + SLIDE_TOL,
			"%s: a %d m fall keys held lands at its air speed (%.2f -> %.2f m/s) and stops in %.2f m (a let-go: %.2f)"
			% [mode, up, r[1], r[2], r[3], HunterMove.slide(r[2])])
	_jump(mode, at, run)
	_flight(mode, at, run)
	m.queue_free()
	await main.get_tree().process_frame

func _jump(mode: String, at: Vector3, run: float) -> void:
	_reset(at + Vector3(-3.5, 0, 0), Vector3.ZERO, true)
	h.inp["move"] = Vector2(1, 0)
	for i in 20: m.step(Match.DT)
	var ground_v := _hv()
	h.inp["jump"] = true
	var y0 := h.pos.y
	var apex := 0.0
	var steps := 0
	var air_max := 0.0
	var land_v := -1.0
	for i in 120:
		m.step(Match.DT)
		h.inp["jump"] = false
		if h.grounded:
			land_v = _hv()
			break
		steps += 1
		apex = maxf(apex, h.pos.y - y0)
		air_max = maxf(air_max, _hv())
	arcs[mode] = [steps, apex]
	ok(land_v >= 0.0 and air_max <= ground_v + SPEED_TOL and land_v <= ground_v + SPEED_TOL,
		"%s: a running jump keeps its speed (ground %.2f, air max %.2f, landing %.2f m/s; %d steps, apex %.2f m)"
		% [mode, ground_v, air_max, land_v, steps, apex])

## Down the test flight from its plateau, letting go on the flight: no air steps, a flat let-go's stop.
func _flight(mode: String, at: Vector3, run: float) -> void:
	var old := _lay_flight(m.world, at)
	_reset(Vector3(at.x + 3.5, at.y + World.LEVEL, at.z), Vector3.ZERO, true)
	h.inp["move"] = Vector2(-1, 0)
	var airs := 0
	var let_go := Vector2.INF
	for i in 120:
		m.step(Match.DT)
		if not h.grounded: airs += 1
		if let_go == Vector2.INF and h.pos.x < at.x + 1.5:
			let_go = _flat()
			h.inp["move"] = Vector2.ZERO
	var slid := _flat().distance_to(let_go) if let_go != Vector2.INF else 99.0
	_unlay(m.world, old)
	ok(airs == 0 and slid <= HunterMove.slide(run) + SLIDE_TOL,
		"%s: down a flight the feet stay on it (%d air steps) and a let-go stops in %.2f m (flat: %.2f)"
		% [mode, airs, slid, HunterMove.slide(run)])

# ---------------------------------------------------------------- the farm (Home._move_player)
func _press(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)

func _farm(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(pk)
	Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Save.d["arch"] = ""
	Econ.ensure()
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	while hm.building:
		await main.get_tree().process_frame
	hm.set_process(false)
	var w: World = hm.world
	var at := _flat_spot(w)
	ok(at != Vector3.INF, "farm: a flat open spot to drop on")
	if at == Vector3.INF:
		hm.queue_free()
		return
	var run := float(HunterMove.of("")["speed"])
	var put := func(p: Vector3, v: Vector3, up: float) -> void:
		hm.ppos = Vector3(p.x, 0, p.z)
		hm.py = p.y + up
		hm.pvy = 0.0
		hm.pvel = v
		hm.gliding = false
		hm.dash_t = 0.0
		hm.lfl = {}
	var flat := func() -> Vector2: return Vector2(hm.ppos.x, hm.ppos.z)
	for up in [3.0, 10.0]:
		put.call(at, Vector3.ZERO, up)
		_press(Vector2.ZERO)
		var start: Vector2 = flat.call()
		for i in 120: hm._move_player(DT)
		ok(hm.py <= at.y + 0.001 and (flat.call() as Vector2).distance_to(start) < STILL_TOL,
			"farm: a straight fall from %d m lands where it started (%.3f m)"
			% [up, (flat.call() as Vector2).distance_to(start)])
	# the running jump: run, then one real Space press
	put.call(at + Vector3(-3.5, 0, 0), Vector3.ZERO, 0.0)
	_press(Vector2(1, 0))
	for i in 20:
		hm._move_player(DT)
		await main.get_tree().process_frame
	var ground_v := Vector2(hm.pvel.x, hm.pvel.z).length()
	Input.action_press("jump")
	var y0: float = hm.py
	var apex := 0.0
	var steps := 0
	var air_max := 0.0
	var land_v := -1.0
	for i in 120:
		hm._move_player(DT)
		if i == 0: Input.action_release("jump")
		if hm.py <= hm._ground_h(hm.ppos.x, hm.ppos.z) + 0.001 and hm.pvy <= 0.0 and i > 0:
			land_v = Vector2(hm.pvel.x, hm.pvel.z).length()
			break
		steps += 1
		apex = maxf(apex, hm.py - y0)
		air_max = maxf(air_max, Vector2(hm.pvel.x, hm.pvel.z).length())
		await main.get_tree().process_frame
	arcs["farm"] = [steps, apex]
	ok(land_v >= 0.0 and air_max <= ground_v + SPEED_TOL and land_v <= ground_v + SPEED_TOL,
		"farm: a running jump keeps its speed (ground %.2f, air max %.2f, landing %.2f m/s; %d steps, apex %.2f m)"
		% [ground_v, air_max, land_v, steps, apex])
	# down the test flight
	var old := _lay_flight(w, at)
	put.call(Vector3(at.x + 3.5, at.y + World.LEVEL, at.z), Vector3.ZERO, 0.0)
	_press(Vector2(-1, 0))
	var airs := 0
	var let_go := Vector2.INF
	for i in 120:
		hm._move_player(DT)
		if hm.py > hm._ground_h(hm.ppos.x, hm.ppos.z) + 0.001: airs += 1
		if let_go == Vector2.INF and hm.ppos.x < at.x + 1.5:
			let_go = flat.call()
			_press(Vector2.ZERO)
	var slid: float = (flat.call() as Vector2).distance_to(let_go) if let_go != Vector2.INF else 99.0
	_unlay(w, old)
	_press(Vector2.ZERO)
	ok(airs == 0 and slid <= HunterMove.slide(run) + SLIDE_TOL,
		"farm: down a flight the feet stay on it (%d air steps) and a let-go stops in %.2f m (flat: %.2f)"
		% [airs, slid, HunterMove.slide(run)])
	hm.queue_free()

func run(main: Node) -> void:
	for mode in MODES:
		await _match_mode(main, mode)
	await _farm(main)
	var ref: Array = arcs.get("expedition", [])
	for mode in arcs:
		var a: Array = arcs[mode]
		ok(not ref.is_empty() and absi(int(a[0]) - int(ref[0])) <= 1 and absf(float(a[1]) - float(ref[1])) < 0.02,
			"the same jump arc: %s %d steps, apex %.2f m (expedition %d, %.2f)" % [mode, a[0], a[1], ref[0], ref[1]])
	print("FCHECK DONE, failures: ", bad)
	main.get_tree().quit()
