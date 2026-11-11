extends RefCounted
## --kin-downed-shots --shots-dir=<dir> [--species=a,b,c|all]: before/after strips of a knocked-out Boki, through the
## real match render path (Kin.render, KinPuppet, BokiRig). One row per species in <dir>/strip.png, left to right:
## standing, 0.1 s, 0.3 s, 1.5 s after going down, then 0.1 s and 0.3 s after the revive. Needs a renderer.

const STEP := 1.0 / 60.0
const TILE := 200                        # px per frame in the strip
const CROP := 260                        # px of the screen around the Boki that a frame shows
const AT := [0.0, 0.1, 0.3, 1.5]         # s after the knock-out
const UP := [0.1, 0.3]                   # s after the revive
const SPECIES := ["cindle", "zapple", "hivara", "zephyrak", "glomwort", "basaltoad"]

var main: Node
var m: Match
var out := ""

func run(main_node: Node) -> void:
	main = main_node
	var list: Array = SPECIES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="):
			list = BokiRig.FRAME.keys() if a.substr(10) == "all" else Array(a.substr(10).split(","))
	if out.is_relative_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	var sheet := Image.create(TILE * (AT.size() + UP.size()), TILE * list.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for i in list.size():
		await _row(String(list[i]), sheet, i)
	sheet.save_png(out.path_join("strip.png"))
	print("KIN_DOWNED_SHOTS_DONE")
	main.get_tree().quit()

func _row(species: String, sheet: Image, row: int) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "total": 1, "tier": 1, "length": 1e9, "seed": 4242,
		"no_drop": true, "raid": "clear", "blight": false, "demo_kin": species, "demo_kin_lv": "8:95", "cls": "medium"})
	m.set_process(false)
	if m.hud:
		m.hud.visible = false
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var k: Kin = m.player.kin
	print("KIN_DOWNED_SHOTS row ", species, " shows ", k.species)
	var at := m.player.pos + Vector3(4.0, 0.0, 0.0)
	k.state = "active"
	k.cmd = "follow"
	m.cam.zoom = 0.35
	m.cam.zoom_to = 0.35
	var col := 0
	await _wait(k, at, 0.6)
	await _tile(k, at, sheet, row, col)
	col += 1
	KinDowned.begin(k, false)
	k.down_t = 1e6
	k.down_total = 1e6
	var t := 0.0
	for s in AT:
		if s == 0.0:
			continue
		await _wait(k, at, s - t)
		t = s
		await _tile(k, at, sheet, row, col)
		col += 1
	KinDowned.rescue(k)
	k.state = "active"        # stays where it is for the strip (in the game it hops to its owner)
	t = 0.0
	for s in UP:
		await _wait(k, at, s - t)
		t = s
		await _tile(k, at, sheet, row, col)
		col += 1

## Steps `secs` of the match, the Boki held where it is, the puppet and rig posed on the same clock.
func _wait(k: Kin, at: Vector3, secs: float) -> void:
	for i in int(round(secs / STEP)):
		m.step(STEP)
		k.teleport(at)
		k.vel = Vector3.ZERO
		k.render(STEP, 1.0)
		for n in k.model.get_children():
			if n is KinPuppet:
				n.set_process(false)
				n._process(STEP)
		var rig := k.model.find_child("BokiRig", true, false) as BokiRig
		if rig:
			rig.set_process(false)
			rig._process(STEP)
	m.cam.snap(k.pos)
	await main.get_tree().process_frame
	await main.get_tree().process_frame

func _tile(k: Kin, _at: Vector3, sheet: Image, row: int, col: int) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var c := m.cam.unproject_position(k.pos + Vector3(0, 0.3, 0))
	var box := Rect2i(Vector2i(c) - Vector2i(CROP, CROP) / 2, Vector2i(CROP, CROP))
	box = box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var tile := Image.create(CROP, CROP, false, Image.FORMAT_RGBA8)
	tile.blit_rect(img, box, Vector2i.ZERO)
	tile.resize(TILE, TILE, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(col * TILE, row * TILE))
