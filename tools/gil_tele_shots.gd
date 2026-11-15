extends RefCounted
## --gil-tele-shots --shots-dir=<dir>: Gil's three telegraphs in a real Match at the gameplay camera (its own
## zoom), one PNG each: rmb_* (a thrown potion's landing circle filling), e_* (the Riptide spout's lane filling
## with its front), x_* (the Tidal Wave lane while he surfs). Before/after proof for the AimKit move (DEBT
## "Two telegraph systems"). Needs a renderer.

const DT := 1.0 / 60.0
const FRAMES := [0.15, 0.4]          # s after each cast

var main: Node
var out := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("gil", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_clear_view(m, P)
	T.ctrl = "idle"
	var cur := P.pos + Vector3(8.0, 0, 0)
	P.inp["aim"] = cur + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = cur.y
	for f in 20:
		await _step(m, P)
	var K = P.ak
	K.bag.append("slime")
	K.press_rmb()
	await _shots(m, P, "rmb")
	for f in 90:
		await _step(m, P)
	K.use_e()
	for f in 30:
		await _step(m, P)
	K.e_recast()
	await _shots(m, P, "e")
	for f in 90:
		await _step(m, P)
	P.lvl = 6
	K.cast_ult()
	await _shots(m, P, "x")
	print("GIL_TELE_SHOTS_DONE")
	main.get_tree().quit(0)


## A frame saved at each of FRAMES after the press just made.
func _shots(m: Match, P: Hunter, tag: String) -> void:
	var t := 0.0
	var shot := 0
	for want in FRAMES:
		while t < float(want):
			await _step(m, P)
			t += DT
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%02d.png" % [tag, shot]))
		shot += 1


## Trees and rocks would hide the ground: everything standing above it goes for the shot, but the hunters.
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
