extends RefCounted
## --hunter-tint-shots --shots-dir=<dir> [--size=1920x1080]: every Hunter's colour as the game shows it, against
## its .glb as authored (the 11-11 "hunters read red" report). Writes at the window size:
## neutral.png (each .glb's own glTF materials, white key, grey ambient: the model as a glTF viewer shows it),
## select.png (the Hunters screen's turntable stage, HunterViewer, one per Hunter) and match.png / match_close.png
## (one of each Hunter in a real match's world and light at the match camera, then closer). Needs a renderer.

const GAP := 1.7              # m between Hunters in a row
const PER_ROW := 7
const ROW_GAP := 3.2          # m between the two rows (match shots)
const STAGE := Vector2(250, 330)   # px: one Hunters-screen stage in the select sheet

var main: Node
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	var px := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			px = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = px
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for id in Arch.ORDER:
		WardenGlb.neutral_rest(id)
	await _neutral()
	await _select()
	await _match()
	print("HUNTER-TINT-SHOTS done ", dir)

## Where the i-th Hunter stands in the two-row lineup (row 0 behind, row 1 in front).
func _spot(i: int, n: int) -> Vector3:
	var row := i / PER_ROW
	var in_row := mini(PER_ROW, n - row * PER_ROW)
	return Vector3((i % PER_ROW - (in_row - 1) * 0.5) * GAP, 0.0, (row - 0.5) * ROW_GAP)

func _grab(file: String, frames := 30) -> void:
	for i in frames:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("HUNTER-TINT-SHOT ", file)

## The .glb files on their own glTF materials: no toon pass, no look, no team.
func _neutral() -> void:
	var stage := Node3D.new()
	main.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.5, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 20, 0)
	stage.add_child(key)
	var n := Arch.ORDER.size()
	for i in n:
		var glb := (load(WardenGlb.path(Arch.ORDER[i])) as PackedScene).instantiate() as Node3D
		stage.add_child(glb)
		glb.position = Vector3(_spot(i, n).x, 2.4 * (1 - i / PER_ROW), 0.0)
		glb.rotation.y = PI
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.position = Vector3(0, 2.0, 9.5)
	cam.current = true
	await _grab("neutral.png")
	stage.queue_free()

## The Hunters screen's stage (HunterViewer: its own light, the Hunter's rim colour), every Hunter at once.
func _select() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = PER_ROW
	bg.add_child(grid)
	for id in Arch.ORDER:
		var v := HunterViewer.make(id, STAGE, Vector2(90, 50), 1)
		v.custom_minimum_size = Vector2(STAGE.x + 10, 0)
		grid.add_child(v)
	await _grab("select.png", 240)
	bg.queue_free()
	await main.get_tree().process_frame

## One of each Hunter in a real match (its world, light and post), at the match camera and closer.
func _match() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "god": true, "length": 1e9})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var c := m.player.pos
	var n := Arch.ORDER.size()
	for i in n:
		var id: String = Arch.ORDER[i]
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[i % 4], Arch.signature(id), "",
				PlayerLook.neutral(), id)
		m.add_child(h)
		var p := c + _spot(i, n) + Vector3(0, 0, 4.0)
		h.global_position = Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
	for h in m.hunters:
		h.visible = false
	m.cam.snap(c + Vector3(0, 0, 4.0))
	await _grab("match.png")
	m.cam.user_zoom = 0.45
	m.cam.snap(c + Vector3(0, 0, 4.0))
	await _grab("match_close.png")
