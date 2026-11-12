extends RefCounted
## --farm-climb-blocks-check: every placed block on the farm is climbable (HomeLayout.CLIMB_TOP / "top"), through
## the one step-up and mantle the farm already has, and a Boki never ends up stuck on one.
##   - one of each kind (fence, wall, hedge, bench, chest, tree, pillar, workbench, house) is topped by a running
##     jump head-on, and from the top you walk off it back onto the meadow;
##   - every tile the layout blocks stands you at its top (buildings and decorations alike);
##   - after placing a wall across its way a Boki still gets to the far side (the grid is rebuilt), round it,
##     and never stands on a block;
##   - a Boki set down on a block (dropped from its top, or there when the layout changed) is moved off it.
## Never touches the save.

const DT := 1.0 / 60.0
const RUN_UP := 1.1            # m from the face the run starts
const JUMP_AT := 6             # frame of the run-up the jump is pressed on (0.1 s in)
const TRIAL_S := 2.0           # s a climb may take
const WALK_OFF_S := 0.8        # s walking off the top
const KINDS := ["fence", "stone_wall", "hedge", "bench", "storage_chest", "tree", "pillar", "workbench", "house"]
const SPOT := Vector2i(30, 30)  # tile the blocks are tried from (open meadow on every seed's island)
const WALK_S := 20.0           # s a Boki may take to walk round a wall
const BOKI_SPEED := 2.4        # m/s, a wandering Boki's pace (Home._move_kin)

var bad := 0
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("FCLIMBBLK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var d := Save.fresh()
	for nm in ["Pip", "Pop"]:
		var k := Save.new_kin("zapple", nm)
		k["starter"] = true
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, 1)
	Save.d = d
	var hm = await main._hb_home()
	for i in 10: await tree.process_frame
	hm.set_process(false)
	var c := _open_spot(hm)
	ok(c.x >= 0, "an open 9x9 patch of meadow to place on (%s)" % str(c))
	for id in KINDS:
		await _kind(hm, String(id), c)
	_all_blocked(hm)
	await _boki(hm, c)
	hm.queue_free()
	await tree.process_frame
	print("FCLIMBBLK DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

## The first tile whose 9x9 around it is open meadow a player and a Boki can stand on.
func _open_spot(hm) -> Vector2i:
	var w: World = hm.world
	for z in range(SPOT.y, w.h - 6):
		for x in range(SPOT.x, w.w - 6):
			var clear := true
			for dz in range(-4, 5):
				for dx in range(-4, 5):
					var i := w.idx(x + dx, z + dz)
					var flat: bool = w.kind[i] == World.T_GROUND and w.level[i] == 0
					clear = clear and flat and not hm.hb.wild_t.has(i) and not hm.hb.occ.has(i)
			if clear: return Vector2i(x, z)
	return Vector2i(-1, -1)

func _put(hm, id: String, at: Vector2i) -> Dictionary:
	var lay: Dictionary = HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(lay), "id": id, "x": at.x, "z": at.y, "r": 0}
	(lay["deco"] as Array).append(e)
	hm.hb.apply()
	return e

func _stands_at(w: World, t: Vector2i, top: float) -> bool:
	return w.is_stand_block(t.x + 0.5, t.y + 0.5) and is_equal_approx(w.ground_at(t.x + 0.5, t.y + 0.5), top)

func _clear_deco(hm) -> void:
	(HomeLayout.of(Save.d)["deco"] as Array).clear()
	hm.hb.apply()

func _kind(hm, id: String, c: Vector2i) -> void:
	var w: World = hm.world
	var e := _put(hm, id, c)
	var cells := HomeLayout.deco_cells(e)
	var top := w.level[w.idx(c.x, c.y)] * World.LEVEL + HomeLayout.top_of(id)
	var stands := cells.all(func(t): return _stands_at(w, t, top))
	ok(stands, "%s: its %d tile(s) stand you at %.1f m" % [id, cells.size(), top])
	var at := Vector2(c.x - RUN_UP + 0.5 - 0.5, c.y + 0.5)      # heading east into the west face
	ok(await _climb(hm, at, top), "%s: a running jump tops it (%.1f m)" % [id, top])
	ok(await _walk_off(hm, Vector2(c.x + 0.5, c.y + 0.5)), "%s: from the top you walk off onto the meadow" % id)
	_clear_deco(hm)

func _press(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)
	if dir.y > 0.1: Input.action_press("down", dir.y)
	if dir.y < -0.1: Input.action_press("up", -dir.y)

func _place(hm, at: Vector2) -> void:
	hm.ppos = Vector3(at.x, 0, at.y)
	hm.py = 0.0
	hm.pvy = 0.0
	hm.pvel = Vector3.ZERO
	hm.dash_t = 0.0
	hm.lfl = {}
	hm.climb = {}
	hm.gliding = false

## A running jump east at the face: true once you stand on the top (keys let go as you get over it).
func _climb(hm, at: Vector2, top: float) -> bool:
	_place(hm, at)
	await tree.process_frame
	var up := false
	for fr in int(TRIAL_S / DT):
		_press(Vector2.ZERO if up else Vector2.RIGHT)
		if fr == JUMP_AT: Input.action_press("jump")
		hm._move_player(DT)
		if fr == JUMP_AT:
			Input.action_release("jump")
			await tree.process_frame      # (a press stays "just pressed" until a frame passes)
		up = hm.py >= top - 0.05 and hm.world.is_stand_block(hm.ppos.x, hm.ppos.z)      # (over it, even if one tile)
		if up: break
	_press(Vector2.ZERO)
	return up

## Standing on the block at `at`, walking west off it lands you on level ground.
func _walk_off(hm, at: Vector2) -> bool:
	_place(hm, at)
	hm.py = hm.world.ground_at(at.x, at.y)
	for fr in int(WALK_OFF_S / DT):
		_press(Vector2.LEFT)
		hm._move_player(DT)
	_press(Vector2.ZERO)
	return hm.py < 0.05 and not hm.world.is_block(hm.ppos.x, hm.ppos.z)

## Every tile the layout blocks (buildings included) is climbable ground, none a bare 3 m wall.
func _all_blocked(hm) -> void:
	var w: World = hm.world
	var lay: Dictionary = HomeLayout.of(Save.d)
	var wall := 0
	for i in hm.hb.blocked:
		if not w.block_top.has(i) or w.block_top[i] - w.level[i] * World.LEVEL > HomeLayout.CLIMB_TOP + 0.01: wall += 1
	ok(wall == 0, "every blocked tile on the farm (%d) has a climbable top (%d without)" % [hm.hb.blocked.size(), wall])
	ok(lay["deco"] is Array, "layout read")

## A Boki gets round a wall to the far side; one set down on a block is stepped off it.
func _boki(hm, c: Vector2i) -> void:
	var w: World = hm.world
	for z in range(c.y - 3, c.y + 4):
		_put(hm, "stone_wall", Vector2i(c.x, z))
	var kin: Dictionary = hm.kins[0]
	var from := Vector3(c.x - 2.5, 0, c.y + 0.5)
	var goal := Vector3(c.x + 3.5, 0, c.y + 0.5)
	kin["pos"] = from
	kin["vel"] = Vector3.ZERO
	var n := 0
	var on_block := false
	while n < int(WALK_S / DT) and Vector2(kin["pos"].x - goal.x, kin["pos"].z - goal.z).length() > 0.5:
		var pos: Vector3 = kin["pos"]
		var aim: Vector3 = hm.hb.steer(kin, pos, goal)
		var step := Vector2(aim.x - pos.x, aim.z - pos.z).normalized() * BOKI_SPEED * DT
		if w.occupy(pos.x + step.x, pos.z, 0.3, 0.0, true) == 0.0: pos.x += step.x
		if w.occupy(pos.x, pos.z + step.y, 0.3, 0.0, true) == 0.0: pos.z += step.y
		kin["pos"] = pos
		on_block = on_block or w.is_block(pos.x, pos.z)
		n += 1
	ok(Vector2(kin["pos"].x - goal.x, kin["pos"].z - goal.z).length() <= 0.5 and not on_block,
		"a Boki walks round a 7-tile wall to the far side in %.1f s, never on a block" % (n * DT))
	# set down on top: the player drops it from up there
	var top_tile := Vector2(c.x + 0.5, c.y + 0.5)
	hm.ppos = Vector3(top_tile.x, w.ground_at(top_tile.x, top_tile.y), top_tile.y)
	hm.py = hm.ppos.y
	hm.carry.k = hm.kins[1]
	hm.carry.mode = "carry"
	hm.carry.drop()
	var p2: Vector3 = hm.kins[1]["pos"]
	ok(not w.is_block(p2.x, p2.z) and w._fits(p2.x, p2.z, 0.3), "a Boki dropped from a block's top lands down")
	# the layout changes under it
	hm.kins[1]["pos"] = Vector3(top_tile.x, 0, top_tile.y)
	hm.ppos = Vector3(c.x - 3.5, 0, c.y + 0.5)
	hm.unstick()
	p2 = hm.kins[1]["pos"]
	ok(not w.is_block(p2.x, p2.z), "a Boki found on a block when the layout changes is moved off it")
	# the player stays up there
	hm.ppos = Vector3(top_tile.x, w.ground_at(top_tile.x, top_tile.y), top_tile.y)
	hm.py = hm.ppos.y
	hm.unstick()
	ok(w.is_stand_block(hm.ppos.x, hm.ppos.z) and hm.py >= 1.0, "a player up on a block stays up on a layout change")
	_clear_deco(hm)
