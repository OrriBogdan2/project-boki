extends RefCounted
## --wisp-follow-shots --shots-dir=<dir> [--tag=<name>]: one strip per move of a riding Boki wisp beside a real
## cliff, in a live match under a renderer (jobq submit --needs gpu), so a before and an after tree can be laid
## side by side. --wisp-follow-check's moves on the first straight lane under a cliff the map has (the check's
## own wall is tiles only, never drawn): Vex's dash, chained dash and glide dive, Sparkle's Wirerun. Each strip
## is eight frames, two rows of four, left to right (<tag>_<move>.jpg); captions.txt says what each shows.

const CHECK := preload("res://tools/wisp_follow_check.gd")
const DT := 1.0 / 60.0
const LANE := 16               # tiles of flat lane needed along the cliff
const CLIFF := 3               # terraces the cliff stands above the lane at least
const ZOOM := 0.3              # of the match view's distance: close enough to see the wisp's body
const CROP := 0.6              # share of the view's middle kept in each frame (the Hunter, the wisp, the cliff)
const CELL := Vector2i(480, 270)   # px of each frame in a strip
const RUNS := [["gunslinger", ["dash", "chain", "dive"]], ["mage", ["wirerun"]]]
## The steps each move's frames are taken on (the press steps are --wisp-follow-check's).
const FRAMES := {
	"dash": [18, 21, 23, 25, 28, 32, 38, 48],
	"chain": [20, 24, 28, 32, 36, 40, 46, 56],
	"dive": [112, 117, 121, 124, 126, 128, 132, 140],
	"wirerun": [30, 52, 56, 58, 60, 62, 66, 76],
}
const SAYS := {
	"dash": "Vex runs along the cliff and dashes on step 20",
	"chain": "Vex dashes along the cliff, then chains a second dash on and into it",
	"dive": "Vex glide-dives at 32.5 m/s and lands at the cliff's foot",
	"wirerun": "Sparkle holds a full Wirerun charge, then streaks 40 m/s along the cliff",
}

var main: Node
var dir := ""
var tag := "shot"
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--tag="):
			tag = String(a).substr(6)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var bad := 0
	for r in RUNS:
		var c = CHECK.new()
		if not await _setup(c, String(r[0])):
			print("WFSHOTS no lane under a cliff on this map")
			bad += 1
			continue
		for mv in r[1]:
			await _strip(c, String(mv))
		c.m.queue_free()
		await main.get_tree().process_frame
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("WFSHOTS %d strips in %s" % [lines.size(), dir])
	main.get_tree().quit(1 if bad > 0 else 0)

## A live match (a full generated map: the training arena has no cliff) for one Hunter carrying a cindle wisp,
## put on the lane.
func _setup(c, arch: String) -> bool:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 1109, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch), "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	c.m = m
	c.h = m.player
	c.h.set_arch(arch)
	c.h.unlock_all()
	c.k = c.h.kin
	if not _lane(c):
		return false
	for other in m.hunters:
		if other != c.h:
			other.ctrl = "idle"
			other.teleport(m.world.free_spot_near(c.lane + Vector3(60, 0, 60), [], 1.0, 0.4, 30.0))
	if m.hud:
		m.hud.visible = false       # the Hunter, the wisp and the cliff, without the panels over them
	m.cam.zoom = ZOOM
	m.cam.yaw = atan2(-c.side.x, -c.side.y)         # looking at the cliff's face
	c.reset(c.lane, true)
	c.h.render(0.0, 1.0)
	c.k.render(0.0, 1.0)            # (its follow takes the shoulder of the Hunter standing)
	c.stand = c._shoulder_y() - c.h.position.y
	return true

## The first lane of LANE flat tiles with a cliff CLIFF terraces up (or rocks) all along one side and flat
## ground two tiles out on the other; walls to the north first, so the view looks straight at them.
func _lane(c) -> bool:
	var world: World = c.m.world
	for side in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		for ahead in [Vector2i(-side.y, side.x), Vector2i(side.y, -side.x)]:
			for z in world.h:
				for x in world.w:
					if _fits(world, Vector2i(x, z), ahead, side):
						var t0 := Vector2(x + 0.5, z + 0.5)
						var lv: float = world.ground_at(t0.x, t0.y)
						var body_r: float = c.h.r
						var to_face: Vector2 = Vector2(side) * (0.5 - body_r - CHECK.HUG)
						c.lane = Vector3(t0.x + to_face.x, lv, t0.y + to_face.y)
						c.ahead = Vector2(ahead)
						c.side = Vector2(side)
						print("WFSHOTS lane at %s, running %s, cliff %s" % [c.lane, ahead, side])
						return true
	return false

## Is there a lane from tile t0 running `ahead` with the cliff on `side` (see _lane)?
func _fits(world: World, t0: Vector2i, ahead: Vector2i, side: Vector2i) -> bool:
	var level := -1
	for j in LANE:
		var tile: Vector2i = t0 + ahead * j
		for out in 3:
			var ground: Vector2i = tile - side * out
			if not world.inb(ground.x, ground.y):
				return false
			var i: int = world.idx(ground.x, ground.y)
			if world.kind[i] != World.T_GROUND or world.stairs.has(i):
				return false
			if level < 0:
				level = int(world.level[i])
			if int(world.level[i]) != level:
				return false
		var cliff: Vector2i = tile + side
		if not world.inb(cliff.x, cliff.y):
			return false
		var ci: int = world.idx(cliff.x, cliff.y)
		var tall: bool = world.kind[ci] == World.T_GROUND and int(world.level[ci]) >= level + CLIFF
		if world.kind[ci] != World.T_BLOCK and not tall:
			return false
	return true

## One move from its start, the frames on FRAMES[mv] laid into one strip.
func _strip(c, mv: String) -> void:
	var m: Match = c.m
	c.reset(c.move_start(mv), mv != "dive")
	var want: Array = FRAMES[mv]
	var strip := Image.create(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGB8)
	var chained := -1
	var n := 0
	for i in int(want[-1]) + 1:
		chained = c.press(mv, i, chained)
		m.step(DT)
		c.h.render(DT, 1.0)
		c.k.render(DT, 1.0)
		m.cam.snap(c.h.position)
		await main.get_tree().process_frame
		if i in want:
			var view := main.get_viewport().get_texture().get_image()
			var keep := Vector2i(Vector2(view.get_size()) * CROP)
			var img := view.get_region(Rect2i((view.get_size() - keep) / 2, keep))
			img.convert(Image.FORMAT_RGB8)
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			var row := 1 if n >= 4 else 0
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(n % 4 * CELL.x, row * CELL.y))
			n += 1
	var file := "%s_%s.jpg" % [tag, mv]
	strip.save_jpg(dir.path_join(file), 0.88)
	lines.append("%s: %s (steps %s, 60 a second)" % [file, SAYS[mv], str(want)])
