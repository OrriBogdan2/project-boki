extends RefCounted
## --hazard-moves-shots --shots-dir=<dir>: every Hunter on the Hollow Crown's hazard ground at the match camera
## (HazardMoves): swimming across Deep Water and running on an Ice Sheet without footing, with a Boki that counters
## neither. Per kind one sheet <dir>/<kind>.jpg, the 12 Hunters in OWN order (4 a row, a crop round the hunter), and
## one full frame <dir>/<kind>_full.jpg of the first. Needs a renderer (jobq --needs gpu). Never writes the save.

const STEP := 1.0 / 60.0
const RUN_S := 1.4                # s moving before the still
const LANE := 10.0                # m of the area's ground the run has ahead of it
const CELL := Vector2i(320, 240)  # px per Hunter on a sheet
const CROP := Vector2i(360, 270)  # px cut round the screen's middle before scaling to a cell
const COLS := 4
const ARCHS := ["archer", "thief", "tender", "gunslinger", "ashwick", "mage", "dolm", "rimewright", "dredge",
	"bulwark", "ostra", "juggernaut"]

var main: Node
var dir := "shots"
var m: Match
var P: Hunter
var tz: TerrainHazards

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = Vector2i(1280, 720)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": "cindle",
		"demo_kin_lv": "12:95"})
	m.set_process(false)
	P = m.player
	tz = TerrainHazards.of(m)
	for kind in ["deep_water", "ice"]:
		await _sheet(kind)
	print("HAZARD_MOVES_SHOTS_DONE in %s" % dir)
	main.get_tree().quit(0)

func _sheet(kind: String) -> void:
	var sheet := Image.create(CELL.x * COLS, CELL.y * ceili(ARCHS.size() / float(COLS)), false, Image.FORMAT_RGB8)
	for i in ARCHS.size():
		var img := await _still(kind, String(ARCHS[i]))
		if img == null:
			continue      # (headless: a dry run walks it without saving)
		if i == 0:
			img.save_jpg(dir.path_join("%s_full.jpg" % kind), 0.88)
		var cut := img.get_region(Rect2i((img.get_size() - CROP) / 2, CROP))
		cut.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		cut.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(cut, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLS * CELL.x, i / COLS * CELL.y))
	sheet.save_jpg(dir.path_join("%s.jpg" % kind), 0.88)
	print("HAZARD_MOVES_SHOTS %s" % kind)

## One Hunter running RUN_S along a lane of the kind's biggest area, then the frame.
func _still(kind: String, arch: String) -> Image:
	P.reclass(Arch.weight(arch), arch)
	P.perks.clear()
	var A: Dictionary = {}
	for a in tz.areas:
		if a["kind"] == kind and (A.is_empty() or a["cells"].size() > A["cells"].size()): A = a
	var c: Vector3 = A["centre"]
	var lane := _lane(A)
	var start: Vector2 = lane[0]
	var along: Vector2 = lane[1]
	P.teleport(Vector3(start.x, c.y, start.y))
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	tz.state.clear()
	P.inp["move"] = along
	var t := 0.0
	while t < RUN_S:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(STEP)
		m.step(STEP)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(STEP * 2.0, 1.0)
		t += STEP * 2.0
		await main.get_tree().process_frame
	P.inp["move"] = Vector2.ZERO
	await main.get_tree().process_frame
	print("HAZARD_MOVES_SHOTS %s %s move %d" % [kind, arch, HazardMoves.of(P)])
	return main.get_viewport().get_texture().get_image()

## [start, direction] of the lane nearest the area's middle that stays on its ground for LANE m (big fields have
## fords and islets of dry ground through them).
func _lane(A: Dictionary) -> Array:
	var c: Vector3 = A["centre"]
	var cells: Array = (A["cells"] as Array).duplicate()
	cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return Vector2(p).distance_squared_to(Vector2(c.x, c.z)) < Vector2(q).distance_squared_to(Vector2(c.x, c.z)))
	for q: Vector2i in cells:
		var at := Vector2(q.x + 0.5, q.y + 0.5)
		for d: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
			var clear := true
			for k in int(LANE * 2.0) + 1:
				var p := at + d * (k * 0.5)
				clear = clear and tz.area_at(Vector3(p.x, c.y, p.y)) >= 0
			if clear:
				return [at, d]
	return [Vector2(c.x, c.z), Vector2(1, 0)]
