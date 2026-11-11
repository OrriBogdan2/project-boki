extends RefCounted
## --wisp-shots --shots-dir=<dir> [--wisp-heroes=<id>,<id>]: review frames for the downed Wisp (docs/decisions/0019), in
## a live match under xvfb with a renderer. The player is knocked, drifts, then is revived:
##   wisp_0_hero      standing, before the knock
##   wisp_1_fall      the hit and fall to the floor, mid-way
##   wisp_2_puff      the puff: the hero gone, the Wisp swelling out
##   wisp_3_idle      the Wisp floating low with a steady glow, the hero gone
##   wisp_4_moving    the Wisp hanging back behind the moving hunter, leaning back
##   wisp_5_settle    the hunter stopped, the Wisp still catching up
##   wisp_6_mate      a teammate's Wisp beside the player's
##   wisp_7_revive_a  the revive: the Wisp brightens, the hero small and low, getting up
##   wisp_8_revive_b  the hero growing back as it stands up
##   wisp_9_hero      the hero back at full size
## --wisp-heroes: each of those Heroes instead gets strip_<id>.jpg, cropped round the hero, one frame every STRIP_DT:
## the top row from the knock through the fall, the puff and the Wisp swelling out, the bottom row the revive.
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const STRIP_DT := 0.05     # s between strip frames
const FALL_CELLS := 13     # the knock to +0.6 s: the fall (the puff at HunterWisp.FALL_T) and the pop-in
const RISE_CELLS := 11     # the revive to +0.5 s: the rise and the hero settling
const CELL := 240          # px: a strip frame in the sheet
const CROP := 0.5          # of the screen height: the square cropped round the hero for a strip frame
const STRIP_ZOOM := 0.6    # the camera in closer for the strips, so the pose reads

var main: Node
var m: Match
var P: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = []
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--wisp-heroes="):
			heroes = String(a).substr(14).split(",")
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	if heroes.is_empty():
		await _review()
	for id in heroes:
		await _strip(String(id))
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("WISPSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _review() -> void:
	await _go(0.4)
	_take("wisp_0_hero", "The hero standing, before the knock")
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	m.knock(P, foe, {})
	P.down_hp = 1e6
	await _go(0.15)
	_take("wisp_1_fall", "The hit and fall: the hero going down on its death clip, still on screen")
	await _go(0.23)
	_take("wisp_2_puff", "The puff: the hero gone, ring and burst, the Wisp swelling out where it lay")
	await _go(0.5)
	_take("wisp_3_idle", "The Wisp idling low: round outline, team rim, white core, steady glow, the hero hidden")
	await _go(0.5, Vector3(0.05, 0, 0.03))
	_take("wisp_4_moving", "The Wisp hangs back behind the moving hunter and leans back, slow and heavy")
	await _go(0.2)
	_take("wisp_5_settle", "The hunter stopped: the Wisp is still settling back over the hunter")
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	mate.teleport(P.pos + Vector3(2.0, 0, 0.0))
	m.knock(mate, foe, {})
	await _go(0.7)
	_take("wisp_6_mate", "A teammate's Wisp beside yours (the default look, tinted by team)")
	m.revive_hunter(P, null)
	await _go(0.08)
	_take("wisp_7_revive_a", "Revive: the Wisp brightens, the hero back small and low, squashed, getting up")
	await _go(0.12)
	_take("wisp_8_revive_b", "The hero growing back as it stands up, the Wisp fading")
	await _go(0.6)
	_take("wisp_9_hero", "The hero back at full size, no Wisp")

## One Hero's fall and revive, frame by frame, in one image.
func _strip(id: String) -> void:
	P.reclass(Arch.weight(id), id)
	P.hp = P.max_hp
	m.cam.zoom_to = STRIP_ZOOM
	m.cam.zoom = STRIP_ZOOM
	await _go(0.6)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var sheet := Image.create(CELL * FALL_CELLS, CELL * 2, false, Image.FORMAT_RGB8)
	m.knock(P, foe, {})
	P.down_hp = 1e6
	for i in FALL_CELLS:
		_cell(sheet, i, 0)
		await _go(STRIP_DT)
	await _go(0.5)
	m.revive_hunter(P, null)
	for i in RISE_CELLS:
		_cell(sheet, i, 1)
		await _go(STRIP_DT)
	var file := "strip_%s.jpg" % id
	sheet.save_jpg(dir.path_join(file), 0.9)
	var rows := "top, the knock to +%.2f s (the puff at +%.2f s); bottom, the revive to +%.2f s" % [
			STRIP_DT * (FALL_CELLS - 1), HunterWisp.FALL_T, STRIP_DT * (RISE_CELLS - 1)]
	lines.append("%s: %s, every %.2f s: %s" % [file, id, STRIP_DT, rows])

## The frame on screen now, cropped round the hero's middle (through the model: it leans to the camera), into the
## sheet at column i of row.
func _cell(sheet: Image, i: int, row: int) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var side := int(img.get_height() * CROP)
	var vp := main.get_viewport()
	var at := vp.get_camera_3d().unproject_position(P.model.to_global(Vector3(0, 0.7, 0))) * Vector2(img.get_size()) \
			/ vp.get_visible_rect().size
	var crop := img.get_region(Rect2i(int(at.x) - side / 2, int(at.y) - side / 2, side, side))
	crop.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(crop, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, row * CELL))

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var spot := _flat_spot()
	P.teleport(spot)
	var away := m.world.random_ground()
	for k in 500:
		if away.distance_to(spot) > 45.0:
			break
		away = m.world.random_ground()
	for h in m.hunters:
		if h != P:
			h.teleport(m.world.free_spot_near(away, [], 1.0, 0.4, 8.0))

## Ground flat for 3 m round and 6 m toward the camera, so no bank hides the hero (seed 77's first spot sits behind
## one).
func _flat_spot() -> Vector3:
	for k in 300:
		var at := m.world.random_ground()
		var flat := true
		for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(0, 6)]:
			flat = flat and absf(m.world.ground_at(at.x + d.x, at.z + d.y) - at.y) < 0.15
		if flat:
			return at
	return m.world.random_ground()

func _go(secs: float, drift := Vector3.ZERO) -> void:
	for i in roundi(secs / DT):
		m.step(DT)
		P.pos += drift
		P.prev = P.pos
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
