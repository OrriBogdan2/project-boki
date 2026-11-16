extends RefCounted
## --dot-soft-shots --shots-dir=<dir> [--dot-hard]: the shared fx_dot particles of three kits (Juggernaut, Archer,
## Claire) landing on the ground, seen from the match camera: <dir>/dots_a.png (just landing) and dots_b.png
## (settling). --dot-hard turns the fade off (soft_m ~ 0), the look before the soft dots, for the before shot.
## Needs a renderer (xvfb or GPU).

const KITS := ["juggernaut", "archer", "rimewright"]
const SPREAD := 2.2           # m between the kits' bursts
const LIFE := 6.0             # s the dots live, so the slow frames of a software renderer still catch them
const FRAMES_A := 3          # drawn frames to the first shot
const FRAMES_B := 6          # ... and to the second

var main: Node
var dir := ""
var hard := false

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if a == "--dot-hard":
			hard = true
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var spot := m.world.random_ground()
	m.player.teleport(spot)
	var ground := m.world.ground_at(spot.x, spot.z)
	FxDot.material().set_shader_parameter("soft_m", 0.001 if hard else 0.15)
	(m.hud as CanvasLayer).visible = false
	m.cam.pitch = deg_to_rad(30.0)
	m.cam.zoom = 0.3
	m.cam.zoom_to = 0.3
	m.cam.snap(m.player.pos)
	for i in KITS.size():
		var pal: Dictionary = HeroVfx.data(KITS[i])["palette"]
		var at := spot + Vector3((i - 1) * SPREAD, 0.0, 0.6)
		var col := Color(String(pal["main"]))
		m.fx.burst(Vector3(at.x, ground + 0.15, at.z), col, 70, 2.4, LIFE, 14.0, 2.4, Vector3.UP, 75.0)
	await _frames(FRAMES_A)
	_take("dots_a")
	await _frames(FRAMES_B)
	_take("dots_b")
	print("DOTSOFTSHOTS %s" % dir)
	main.get_tree().quit(0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _take(file: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
