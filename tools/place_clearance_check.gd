extends RefCounted
## --place-clearance-check: building placement keeps walkable clearance. A fence ring round a Boki (or round
## you), or a pocket in a corner, turns the ghost blocked and names who it would shut in; a ring with a one
## tile gap, or a single piece well clear of everyone, is fine; and a Boki that loads into a pocket (an old
## save) is set on open ground. Never touches the real save.

const PEN := 2          # tiles from the middle of the test ring to its fence (a 5x5 ring)

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("PLACECLEAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _save() -> void:
	var d := Save.fresh()
	for nm in ["Mossbun", "Pip"]:
		d["roster"].append(Save.new_kin("zapple", nm))
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d

## The middle of a 5x5 block of open ground at least `from` tiles from the landing (nothing standing in it).
func _open_block(hb: HomeBuild, from: Vector3) -> Vector2i:
	var w: World = hb.h.world
	var best := Vector2i(-1, -1)
	var best_d := INF
	for z in range(PEN, w.h - PEN):
		for x in range(PEN, w.w - PEN):
			var c := Vector2i(x, z)
			var d := Vector2(x + 0.5 - from.x, z + 0.5 - from.z).length()
			if d < 8.0 or d >= best_d:
				continue
			if _block_free(hb, c):
				best = c
				best_d = d
	return best

func _block_free(hb: HomeBuild, c: Vector2i) -> bool:
	for dz in range(-PEN, PEN + 1):
		for dx in range(-PEN, PEN + 1):
			if hb.cell_reason(c + Vector2i(dx, dz)) != "":
				return false
	return true

func _ring(c: Vector2i, gap := false) -> Array:
	var out: Array = []
	for dz in range(-PEN, PEN + 1):
		for dx in range(-PEN, PEN + 1):
			if (absi(dx) == PEN or absi(dz) == PEN) and not (gap and dx == 0 and dz == PEN):
				out.append(c + Vector2i(dx, dz))
	return out

## Puts the held fence's ghost on `cells`; the ghost's verdict is hb.ghost_ok / hb.why.
func _ghost(hb: HomeBuild, cells: Array) -> void:
	hb.cells = cells
	hb._check_cells()

func _stand(home, c: Vector2i) -> void:
	var k: Dictionary = home.kins[0]
	k["pos"] = Vector3(c.x + 0.5, 0, c.y + 0.5)
	(k["node"] as Node3D).position = k["pos"]

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_save()
	var home = await main._hb_home()
	var hb: HomeBuild = home.hb
	hb.toggle()
	var c := _open_block(hb, PlaceClearance.start(home))
	ok(c.x >= 0 and home.kins.size() >= 2, "a clear 5x5 of meadow to test on (%s) and two Boki out" % str(c))
	if c.x < 0:
		print("PLACECLEAR done %d fail" % bad)
		main.get_tree().quit(1)
		return
	hb.take("fence")
	var name0: String = home.kins[0]["rec"]["name"]
	var name1: String = home.kins[1]["rec"]["name"]
	home.ppos = PlaceClearance.start(home)
	_stand(home, c)
	var rest := Vector3(c.x + 9.5, 0, c.y + 0.5)
	home.kins[1]["pos"] = rest      # the other Boki stays out in the open, away from the ring
	# 1. a ring of fence round a Boki shuts it in
	_ghost(hb, _ring(c))
	var shut := "This would shut %s in" % name0
	ok(not hb.ghost_ok and hb.why == shut, "a fence ring round %s turns the ghost blocked: \"%s\"" % [name0, hb.why])
	# 2. the same ring with a one tile gap is a legal tight path
	_ghost(hb, _ring(c, true))
	ok(hb.ghost_ok and hb.why == "", "the ring with a one tile gap is fine (the way out stays open): \"%s\"" % hb.why)
	# 3. a pocket in a corner: the fence fills the open ground round a Boki standing in an island corner
	var corner := _corner(hb)
	ok(corner.x >= 0, "an island corner to test on (%s)" % str(corner))
	_stand(home, corner)
	var pocket: Array = _open_neighbours(hb, corner)
	_ghost(hb, pocket)
	ok(not pocket.is_empty() and not hb.ghost_ok and hb.why == shut,
		"closing the corner pocket round %s is refused: \"%s\" (%d tiles)" % [name0, hb.why, pocket.size()])
	var gap := _way_out(hb, corner, pocket)
	pocket.erase(gap)
	_ghost(hb, pocket)
	ok(hb.ghost_ok, "leaving the pocket tile that opens outward unfenced is allowed")
	# 4. a single piece well clear of everyone is fine, and the player is protected too
	_stand(home, c)
	_ghost(hb, [c + Vector2i(PEN, PEN)])
	ok(hb.ghost_ok, "one fence piece away from everyone is allowed")
	home.ppos = Vector3(c.x + 0.5, 0, c.y + 1.5)
	_stand(home, Vector2i(c.x + 9, c.y))
	_ghost(hb, _ring(c))
	ok(not hb.ghost_ok and hb.why == "This would shut you in", "a ring round you is refused: \"%s\"" % hb.why)
	home.ppos = PlaceClearance.start(home)
	# 5. a Boki that loads inside a pocket (an old save) is set on open ground
	for t in _ring(c):
		home.world.set_block_rect(t.x, t.y, t.x, t.y)
	hb.refresh_grid()
	hb._reach_cache.clear()
	_stand(home, c)
	var seen: PackedByteArray = hb._reach([], [])
	ok(not hb._hit(seen, home.kins[0]["pos"]), "%s now sits sealed in a pocket" % name0)
	var moved := PlaceClearance.free_trapped(home)
	seen = hb._reach([], [])
	var now: Vector3 = home.kins[0]["pos"]
	var near := now.distance_to(Vector3(c.x + 0.5, 0, c.y + 0.5)) < 8.0
	var freed := moved == 1 and hb._hit(seen, now) and near
	ok(freed, "loading sets %s out on open ground nearby (moved %d)" % [name0, moved])
	ok(home.kins[1]["pos"] == rest and name1 != "", "the Boki that was already out is left where it was")
	home.queue_free()
	print("PLACECLEAR done %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A ground tile whose 3x3 holds at least three tiles of non-ground (an island corner), and none standing on.
func _corner(hb: HomeBuild) -> Vector2i:
	var w: World = hb.h.world
	for z in range(1, w.h - 1):
		for x in range(1, w.w - 1):
			var c := Vector2i(x, z)
			if w.island[w.idx(x, z)] != 0 or w.kind[w.idx(x, z)] != World.T_GROUND or hb.cell_reason(c) != "":
				continue
			var solid := 0
			var open := _open_neighbours(hb, c).size()
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if w.kind[w.idx(x + dx, z + dz)] != World.T_GROUND:
						solid += 1
			if solid >= 3 and open >= 2 and open <= 4 and open == 8 - solid:
				return c
	return Vector2i(-1, -1)

## The pocket tile that opens onto the ground outside the 3x3 round c (the way out).
func _way_out(hb: HomeBuild, c: Vector2i, pocket: Array) -> Vector2i:
	for t in pocket:
		if absi(t.x - c.x) + absi(t.y - c.y) != 1:
			continue    # a gap on the diagonal between two fences is too tight to walk through
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + dv
			if maxi(absi(n.x - c.x), absi(n.y - c.y)) >= 2 and hb.cell_reason(n) == "":
				return t
	return Vector2i(-1, -1)

## The 3x3 tiles round c a fence could stand on.
func _open_neighbours(hb: HomeBuild, c: Vector2i) -> Array:
	var out: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var t := c + Vector2i(dx, dz)
			if (dx != 0 or dz != 0) and hb.cell_reason(t) == "":
				out.append(t)
	return out
