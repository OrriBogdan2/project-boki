extends RefCounted
## --farm-climb-check: the grassy ridges a farm-start island grows (HomeLayout.fs_plan "cliff", two
## terraces, 1.6 m) can be climbed and never shut anyone in. On a seeded sample of islands that have one:
##   - every ridge tile left standing is ground you can stand on (not a wall tile);
##   - a sample of its faces is topped by a running jump into it, head-on, as a player plays it;
##   - from the top you walk off it back onto the meadow;
##   - every tile of open meadow can be reached by a Boki from the landing (nothing is shut in);
##   - the Clear the wild brush levels a ridge tile.
## --shots-dir=<dir>: instead, frames for a short clip (<dir>/f0000.png ..., 30 fps; needs a renderer): a
## crop patch held near and then by the water (the drop and "+growth"), then a climb onto a ridge and off.
## Never touches the save.

const DT := 1.0 / 60.0
const SEEDS := 4               # islands in the sample (the first seeds from 1 up whose plan has a ridge)
const MAX_FACES := 12          # ridge faces tried per island, spread along the ridge
const RUN_UP := 1.1            # m from the face the run starts
const RIDGE_H := 1.65          # m: a ridge tile is ground no higher than two terraces (1.6 m)
const JUMP_AT := 6            # frame of the run-up the jump is pressed on (0.1 s in)
const TRIAL_S := 2.0           # s a climb may take
const WALK_OFF_S := 0.7        # s walking off the top (about 3 m: off the ridge, short of anything else)

var bad := 0
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("FCLIMB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var seeds: Array = []
	var s := 1
	while seeds.size() < SEEDS and s < 400:
		if HomeLayout.fs_plan(s, HomeLayout.fs_scale(s)).any(func(f): return f["kind"] == "cliff"): seeds.append(s)
		s += 1
	ok(seeds.size() == SEEDS, "found %d islands with a ridge: %s" % [seeds.size(), str(seeds)])
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): shots = String(a).substr(12)
	if shots != "":
		await _media(main, _clip_seed(), shots)
		seeds = []
	for sd in seeds:
		await _island(main, int(sd))
	print("FCLIMB DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

## The clip's island: the first seed with a ridge and wild water both (the drop shows).
func _clip_seed() -> int:
	for sd in range(1, 400):
		var kinds: Array = HomeLayout.fs_plan(sd, HomeLayout.fs_scale(sd)).map(func(f): return f["kind"])
		if "cliff" in kinds and ("pond" in kinds or "stream" in kinds): return sd
	return 1

func _island(main: Node, seed: int) -> void:
	var hm = await _load(main, seed)
	var w: World = hm.world
	var hb: HomeBuild = hm.hb
	var ridge: Array = hb.cliff_t.keys()
	var walls := ridge.filter(func(i): return w.kind[i] != World.T_GROUND or w.level[i] * World.LEVEL > RIDGE_H)
	ok(not ridge.is_empty() and walls.is_empty(),
		"seed %d: all %d ridge tiles are ground 1.6 m up, none a wall (%d walls)" % [seed, ridge.size(), walls.size()])
	var faces := _faces(w, hb, ridge)
	var topped := 0
	var missed: Array = []
	for f in faces:
		if await _climb(hm, f): topped += 1
		else: missed.append(f["tile"])
	ok(not faces.is_empty() and missed.is_empty(),
		"seed %d: a running jump tops every face tried (%d of %d; missed at %s)"
			% [seed, topped, faces.size(), str(missed)])
	if not faces.is_empty():
		ok(await _walk_off(hm, faces[0]), "seed %d: from the top you walk off it back onto the meadow" % seed)
	var shut := _shut_in(w, hb)
	ok(shut.is_empty(),
		"seed %d: a Boki reaches every open tile from the landing (%d shut in: %s)"
			% [seed, shut.size(), str(shut.slice(0, 6))])
	var t0: int = ridge[0]
	var c0 := Vector2i(t0 % w.w, t0 / w.w)
	ok(hb._brush_ok(c0, "wild") and hb.clear_wild(c0) and w.level[t0] == 0 and not hb.cliff_t.has(t0),
		"seed %d: Clear the wild levels a ridge tile" % seed)
	hm.queue_free()
	await tree.process_frame

## Ridge faces with open meadow in front: {tile, n (from the meadow into the ridge), at (run-up start)}.
func _faces(w: World, hb: HomeBuild, ridge: Array) -> Array:
	var out: Array = []
	for i in ridge:
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = Vector2i(i % w.w, i / w.w) - dv
			var at := Vector2(c.x + 0.5, c.y + 0.5) - Vector2(dv) * (RUN_UP - 0.5)
			if not _open(w, hb, at) or not _open(w, hb, Vector2(c.x + 0.5, c.y + 0.5)):
				continue
			out.append({"tile": Vector2i(i % w.w, i / w.w), "n": Vector2(dv), "at": at})
			break
	var step := maxi(1, out.size() / MAX_FACES)
	var picked: Array = []
	for j in range(0, out.size(), step):
		picked.append(out[j])
	return picked.slice(0, MAX_FACES)

## Open meadow a player can stand on at (x, z): level 0, no wall, no water, no wild.
func _open(w: World, hb: HomeBuild, p: Vector2) -> bool:
	var ix := int(floor(p.x))
	var iz := int(floor(p.y))
	if not w.inb(ix, iz): return false
	var i := w.idx(ix, iz)
	var flat := w.kind[i] == World.T_GROUND and w.level[i] == 0 and not hb.wild_t.has(i)
	return flat and w.occupy(p.x, p.y, 0.38, 0.0, true) == 0.0

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

## A running jump at the face, letting go of the keys once you are over the top (as you would to stop
## on a ridge two tiles thick): true once you stand on it.
func _climb(hm, f: Dictionary) -> bool:
	_place(hm, f["at"])
	await tree.process_frame
	var over := false
	for fr in int(TRIAL_S / DT):
		var g: float = hm.world.ground_at(hm.ppos.x, hm.ppos.z)
		over = over or (g >= RIDGE_H - 0.1 and hm.py >= g)
		_press(Vector2.ZERO if over else f["n"])
		if fr == JUMP_AT: Input.action_press("jump")
		hm._move_player(DT)
		if fr == JUMP_AT:
			Input.action_release("jump")
			await tree.process_frame      # (a press stays "just pressed" until a frame passes)
		g = hm.world.ground_at(hm.ppos.x, hm.ppos.z)
		if g >= RIDGE_H - 0.1 and is_equal_approx(hm.py, g) and hm.pvy == 0.0:
			return true
	return false

## Standing on the ridge just past the face, walking back out the way you came lands you on the meadow.
func _walk_off(hm, f: Dictionary) -> bool:
	var t: Vector2i = f["tile"]
	_place(hm, Vector2(t.x + 0.5, t.y + 0.5))
	hm.py = hm.world.ground_at(hm.ppos.x, hm.ppos.z)
	for fr in int(WALK_OFF_S / DT):
		_press(-(f["n"] as Vector2))
		hm._move_player(DT)
	_press(Vector2.ZERO)
	return hm.py < 0.05 and hm.world.level[hm.world.idx(int(floor(hm.ppos.x)), int(floor(hm.ppos.z)))] == 0

## Open meadow tiles on the main island a Boki can't walk to from the landing (on the kin grid).
func _shut_in(w: World, hb: HomeBuild) -> Array:
	var start := w.idx(int(HomeLayout.LANDING.x), int(HomeLayout.LANDING.z))
	var seen := {start: true}
	var q: Array = [start]
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		for dv in [1, -1, w.w, -w.w]:
			var j: int = i + dv
			if j < 0 or j >= w.kind.size() or seen.has(j) or hb._solid_tile(w, j): continue
			seen[j] = true
			q.append(j)
	var out: Array = []
	for i in w.kind.size():
		if w.island[i] == 0 and not hb._solid_tile(w, i) and not seen.has(i): out.append(Vector2i(i % w.w, i / w.w))
	return out

## A fresh save on the farm-start island of this seed, its Home loaded and paused (steps are driven here).
func _load(main: Node, seed: int):
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, seed)
	Save.d = d
	var hm = await main._hb_home()
	for i in 10: await tree.process_frame
	hm.set_process(false)
	return hm

# ------------------------------------------------------------------ the clip
var _frame := 0

## One 30 fps step of the Home (its own _process: the player, camera and build mode), rendered and saved
## as the next PNG.
func _grab(hm, dir: String) -> void:
	hm._process(1.0 / 30.0)
	await tree.process_frame
	tree.root.get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [dir, _frame])
	_frame += 1

func _media(main: Node, seed: int, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var hm = await _load(main, seed)
	if main.get("fade"): main.fade.reveal(0.05)
	var w: World = hm.world
	var hb: HomeBuild = hm.hb
	# 1. a crop patch slid toward the island's water: nothing over it, then the drop and "+growth"
	var wc := FarmWater.nearest(Save.d, Vector2(HomeLayout.LANDING.x, HomeLayout.LANDING.z))
	if wc.x >= 0:
		var sz := HomeLayout.size_of("crop_patch", 0)
		var from := Vector2(wc.x + 9.0, wc.y + 0.5)
		var to := Vector2(wc.x + 2.0 + sz.x * 0.5, wc.y + 0.5)
		_place(hm, to + Vector2(-1.0, 3.5))
		hb.toggle()
		hb.take("crop_patch")
		for fr in 130:
			hb.debug_m = from.lerp(to, clampf(fr / 80.0, 0.0, 1.0))
			await _grab(hm, dir)
		hb.debug_m = Vector2.INF
		hb.toggle()
	# 2. a running jump onto a ridge, a stop on top, then off the far side
	var faces := _faces(w, hb, hb.cliff_t.keys())
	if not faces.is_empty():
		var f: Dictionary = faces[faces.size() / 2]
		var n: Vector2 = f["n"]
		_place(hm, (f["at"] as Vector2) - n * 2.0)
		var over := false
		var top_t := 0
		for fr in 150:
			var g: float = w.ground_at(hm.ppos.x, hm.ppos.z)
			over = over or (g >= RIDGE_H - 0.1 and hm.py >= g)
			if over: top_t += 1
			_press(n if not over or top_t > 30 else Vector2.ZERO)
			if fr == 18: Input.action_press("jump")
			if fr == 20: Input.action_release("jump")
			await _grab(hm, dir)
		_press(Vector2.ZERO)
	print("FCLIMB frames %d in %s" % [_frame, dir])
