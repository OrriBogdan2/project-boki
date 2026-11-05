extends RefCounted
## --claire-skate-shots --shots-dir=<dir>: Claire skating in a real Match at the match camera: the frost trail her kit
## lays behind the blades, a curve so it shows, frames skate_00..; the ART-1 fidelity proof. Needs a renderer.

const DT := 1.0 / 60.0

func run(main: Node) -> void:
	var out := ""
	var arch := "rimewright"      # (--arch=<id>: another Hero on the same spot, to compare the live look)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--arch="):
			arch = a.substr(7)
		if a == "--no-lod":
			main.get_viewport().mesh_lod_threshold = 0.0
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup(arch, 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var tree := main.get_tree()
	_clear_view(m, P)
	for f in 20:
		await _step(m, P, tree)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join("stand.png"))
	P.inp["move"] = Vector2(1, 0)
	for f in 40:           # plain strokes first: the match look with no skate after-image over her
		await _step(m, P, tree)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join("strokes.png"))
	P.dashes = 1.0
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	var shot := 0
	for f in 90:
		P.inp["move"] = Vector2(1, 0).rotated(f * 0.03)
		await _step(m, P, tree)
		if f % 15 == 14:
			await RenderingServer.frame_post_draw
			var img := main.get_viewport().get_texture().get_image()
			img.save_png(out.path_join("skate_%02d.png" % shot))
			shot += 1
	print("CLAIRE_SKATE_SHOTS_DONE ", shot)
	tree.quit(0)

## Trees and rocks hide her on this spot: everything standing above the ground goes for the shot, but the hunters.
func _clear_view(m: Match, P: Hunter) -> void:
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var n := g as GeometryInstance3D
		if P.is_ancestor_of(n) or n.global_transform.origin.y > P.pos.y + 0.4 or n is MultiMeshInstance3D:
			if not P.is_ancestor_of(n):
				n.visible = false

func _step(m: Match, P: Hunter, tree: SceneTree) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	m.cam.snap(P.pos)
	await tree.process_frame
