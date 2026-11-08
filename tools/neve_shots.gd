extends RefCounted
## --neve-shots --shots-dir=<dir> [--no-lod]: Neve's Rink Wall and Rimelock in a real Match at the match camera,
## frame by frame: wall_00.. as the wall erupts, slides and widens, then rime_00.. as her body turns to ice,
## the rink builds and the crash comes. Before/after proofs for the owner's playtest notes. Needs a renderer.

const DT := 1.0 / 60.0
const WALL_FRAMES := [0.1, 0.3, 0.6, 1.2, 2.0, 3.0, 3.8]      # s after the E press
const RIME_FRAMES := [0.05, 0.12, 0.25, 0.8, 2.0, 3.3, 3.55, 3.7]  # s after the X press (crash at 3.5)

var main: Node
var out := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a == "--no-lod":
			main.get_viewport().mesh_lod_threshold = 0.0
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("rimewright", 9.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_clear_view(m, P)
	T.ctrl = "idle"
	for f in 20:
		await _step(m, P)
	var cur := P.pos + Vector3(9.0, 0, 0)
	P.inp["aim"] = cur + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = cur.y
	P.inp["sig"] = true
	await _step(m, P)
	P.inp["sig"] = false
	await _shots(m, P, WALL_FRAMES, "wall")
	for f in 60:
		await _step(m, P)
	P.lvl = 6
	P.inp["move"] = Vector2(1, 0)
	for f in 30:
		await _step(m, P)
	P.inp["move"] = Vector2.ZERO
	HunterKeys.ult_pressed(P)
	await _step(m, P)
	await _shots(m, P, RIME_FRAMES, "rime")
	print("NEVE_SHOTS_DONE")
	main.get_tree().quit(0)


## A frame saved at each listed second after the press just made.
func _shots(m: Match, P: Hunter, at: Array, tag: String) -> void:
	var t := DT
	var shot := 0
	for want in at:
		while t < float(want):
			await _step(m, P)
			t += DT
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%02d.png" % [tag, shot]))
		shot += 1


## Trees and rocks hide her on this spot: everything standing above the ground goes for the shot, but the hunters.
func _clear_view(m: Match, P: Hunter) -> void:
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var n := g as GeometryInstance3D
		if P.is_ancestor_of(n):
			continue
		if n.global_transform.origin.y > P.pos.y + 0.4 or n is MultiMeshInstance3D:
			n.visible = false


func _step(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	m.cam.snap(P.pos)
	await main.get_tree().process_frame
