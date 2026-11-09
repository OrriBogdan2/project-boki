extends RefCounted
## --claire-skate-shots --shots-dir=<dir>: Claire skating in a real Match at the match camera: the frost trail her kit
## lays behind the blades, a curve so it shows, frames skate_00..; the ART-1 fidelity proof. Needs a renderer.
## close_stand.png and close_run.png: the close-up from behind her shoulder (her scarf tails hanging, then streaming).

const DT := 1.0 / 60.0
const CLOSE_BACK := 1.6        # m the close-up stands behind her
const CLOSE_SIDE := 1.1        # m off to her right
const CLOSE_UP := 1.5          # m up
const CLOSE_LOOK := 1.05       # m up the point it looks at

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
	HeroVfx.of(m)          # (a real Match makes it in warm_up)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var tree := main.get_tree()
	_clear_view(m, P)
	for f in 20:
		await _step(m, P, tree)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join("stand.png"))
	await _close(main, m, P, out.path_join("close_stand.png"))
	P.inp["move"] = Vector2(1, 0)
	for f in 40:           # plain strokes first: the match look with no skate after-image over her
		await _step(m, P, tree)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join("strokes.png"))
	await _close(main, m, P, out.path_join("close_run.png"))
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

## One frame from a camera behind her right shoulder, then the match camera again.
func _close(main: Node, m: Match, P: Hunter, path: String) -> void:
	var c := Camera3D.new()
	c.fov = 40.0
	m.add_child(c)
	var b := P.model.global_basis.orthonormalized()
	var at := P.model.global_position
	c.look_at_from_position(at + b.z * CLOSE_BACK + b.x * CLOSE_SIDE + Vector3.UP * CLOSE_UP,
			at + Vector3.UP * CLOSE_LOOK)
	c.make_current()
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(path)
	m.cam.make_current()
	c.queue_free()

func _step(m: Match, P: Hunter, tree: SceneTree) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	m.cam.snap(P.pos)
	await tree.process_frame
