extends "res://tools/hero_pair_check.gd"
## Motley's orb on real maps (item 117, for --ostra-combo-check): the Arena's stone blocks and dais (also right
## after a swap to him there) and an expedition's ruin walls and cliffs, with real fire input and a body behind
## each one, from point blank and at range.

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEAR := 0.45      # m from the shooter to the obstacle's face, point blank
const FAR := 5.0        # m, at range
const PAST := 2.5       # m from the far face to the dummy

var m: Match
var P: Hunter
var D: Hunter

func arena(main_node: Node) -> void:
	main = main_node
	await _start(Match.arena_opts("ostra"))
	await _lines("arena", ["stone block"])
	var top := _find("raised ground", true)
	ok("arena: the dais has floor to stand on and a top", not top.is_empty())
	if not top.is_empty():
		await _through("arena dais, up onto its top", top, NEAR)
		await _through("arena dais, up onto its top", top, FAR)
	await done(m)
	await _start(Match.arena_opts("gunslinger"))
	m.arena.set_arch("ostra")
	step(m, 0.1)
	await _lines("arena after a swap to him", ["stone block"])
	await done(m)
	await _start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "arch": "ostra",
		"cls": Arch.weight("ostra"), "weapon": Arch.signature("ostra")})
	await _lines("expedition", ["ruin wall"])
	var cliff := _find("raised ground", true)
	ok("expedition: the map has a cliff with a terrace on top", not cliff.is_empty())
	if not cliff.is_empty():
		await _through("expedition cliff, up onto the terrace", cliff, NEAR)
		await _through("expedition cliff, up onto the terrace", cliff, FAR)
	await done(m)

func _lines(where: String, kinds: Array) -> void:
	for kind in kinds:
		var spot := _find(kind, false)
		ok("%s: the map has a %s to shoot through" % [where, kind], not spot.is_empty())
		if not spot.is_empty():
			await _through("%s %s" % [where, kind], spot, NEAR)
			await _through("%s %s" % [where, kind], spot, FAR)

func _start(opts: Dictionary) -> void:
	m = Match.new()
	main.add_child(m)
	await m.start(opts)
	m.set_process(false)
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	if m.arena:
		D = m.arena.dummies[0]["h"]
	else:
		D = m.make_hunter("T", 5, "medium", "Target", "idle", {}, P.pos + Vector3(4.0, 0, 0), {"arch": "none"})
	step(m, 0.2)

## A straight line over one kind of obstacle from open floor: {face, dir, thick, lv, top}. onto: the dummy
## stands on the raised ground itself instead of on the floor behind it.
func _find(kind: String, onto: bool) -> Dictionary:
	var W: World = m.world
	for z in range(10, W.h - 10):
		for x in range(10, W.w - 10):
			for d in SIDES:
				var hit := _line_at(W, Vector2i(x, z), d, kind, onto)
				if not hit.is_empty():
					return hit
	return {}

func _kind_at(W: World, c: Vector2i, lv: int) -> String:
	var i: int = W.idx(c.x, c.y)
	if W.kind[i] == World.T_BLOCK:
		return "ruin wall" if W.walls.has(i) else "stone block"
	if W.kind[i] != World.T_GROUND or W.stairs.has(i) or W.props.has(i) or W.bridge.has(i):
		return "other"
	if int(W.level[i]) == lv + 1:
		return "raised ground"
	return "floor" if int(W.level[i]) == lv else "other"

## FAR + 1 tiles of open floor, then 1-4 tiles of `kind`, then 4 tiles of floor for the dummy.
func _line_at(W: World, a: Vector2i, d: Vector2i, kind: String, onto: bool) -> Dictionary:
	if not W.inb(a.x + d.x * 20, a.y + d.y * 20) or W.kind[W.idx(a.x, a.y)] != World.T_GROUND:
		return {}
	var lv := int(W.level[W.idx(a.x, a.y)])
	var run := int(ceil(FAR)) + 1
	for s in range(1, run + 1):
		if _kind_at(W, a + d * s, lv) != "floor":
			return {}
	var thick := 0
	while thick < 5 and _kind_at(W, a + d * (run + 1 + thick), lv) == kind:
		thick += 1
	var fits := thick >= 3 if onto else thick >= 1 and thick <= 4
	if not fits:
		return {}
	var face := a + d * (run + 1)
	if onto:
		return {"face": face, "dir": d, "thick": 0, "lv": lv, "top": true}
	for s in range(0, 4):
		if _kind_at(W, a + d * (run + 1 + thick + s), lv) != "floor":
			return {}
	return {"face": face, "dir": d, "thick": thick, "lv": lv, "top": false}

## Stands him `gap` m short of the face, the dummy behind it, and fires one charged and one quick orb at it.
func _through(kind: String, spot: Dictionary, gap: float) -> void:
	var dir := Vector2(spot["dir"])
	var face: Vector2i = spot["face"]
	# the near edge of the first obstacle tile
	var edge := Vector2(face) + Vector2(0.5, 0.5) - dir * 0.5
	var y: float = int(spot["lv"]) * World.LEVEL
	var from := edge - dir * (gap + float(P.r))
	var to := edge + dir * (float(spot["thick"]) + PAST)
	var ty: float = m.world.ground_at(to.x, to.y)
	for wait in [1.4, 0.6]:
		P.teleport(Vector3(from.x, y, from.y))
		P.vel = Vector3.ZERO
		D.teleport(Vector3(to.x, ty, to.y))
		D.vel = Vector3.ZERO
		D.hp = D.max_hp
		var before := D.hp + D.armor
		var aim := Vector3(to.x, ty, to.y)
		aim_at(P, aim)
		P.inp["aim_y"] = ty
		var K: OstraKit = P.ak
		K.last_shot_t = m.time - wait
		step(m, 0.03)
		var shots0 := P.shot_n
		P.fire_cd = 0.0
		step(m, 0.05, func():
			P.inp["fire"] = P.shot_n == shots0
			D.teleport(aim))
		P.inp["fire"] = false
		var fired := P.shot_n > shots0
		step(m, 0.8, func(): D.teleport(aim))
		var took := before - (D.hp + D.armor)
		ok(
			"walls: a %s orb from %.1fm: %s" % ["full" if wait > 1.0 else "quick", gap, kind],
			fired and took > 5.0, "took %.1f fired %s from %s to %s y %.1f->%.1f" % [took, fired, from, to, y, ty]
		)
		step(m, 0.1)
