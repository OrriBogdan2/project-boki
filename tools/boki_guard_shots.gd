extends RefCounted
## --boki-guard-shots --shots-dir=<dir>: a big Boki (Gravadillo) on the Return order guarding its hunter while
## he runs, jumps and glides (owner 11-08, docs/decisions/0022): frames guard_000.. at the match camera, for a
## clip. It stays at his side, never under or in him, and curls up on his back while he glides. Needs a renderer.

const DT := 1.0 / 60.0
const EVERY := 3                 # frames between saved shots (20 fps clip)

var out := ""
var n := 0

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("juggernaut", 30.0, "pebbit")
	var m: Match = r[0]
	var P: Hunter = r[1]
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var k: Kin = P.kin
	k.cmd = "follow"
	k.state = "active"
	k.teleport(P.pos + Vector3(-1.5, 0, 1.5))
	KinCommand.order(P, "return")
	var tree := main.get_tree()
	m.cam.user_zoom = 0.6
	_clear_view(m, P)
	for f in 90:
		await _step(m, P, tree, false)
	for f in 240:
		P.inp["move"] = Vector2(1, 0).rotated(f * 0.012)
		if f in [60, 150]:
			P.do_jump()
		await _step(m, P, tree, true)
	P.teleport(P.pos + Vector3(0, 3.5, 0))
	P.grounded = false
	for f in 120:
		P.gliding = true
		P.inp["move"] = Vector2(1, 0)
		await _step(m, P, tree, true)
	for f in 90:
		P.inp["move"] = Vector2(1, 0.4).normalized()
		await _step(m, P, tree, true)
	print("BOKI_GUARD_SHOTS_DONE ", n)
	tree.quit(0)

## Trees and rocks hide the pair: everything standing above the ground goes for the clip, but the bodies.
func _clear_view(m: Match, P: Hunter) -> void:
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		var body := P.is_ancestor_of(gi) or P.kin.is_ancestor_of(gi)
		if not body and (gi.global_transform.origin.y > P.pos.y + 0.4 or gi is MultiMeshInstance3D):
			gi.visible = false

func _step(m: Match, P: Hunter, tree: SceneTree, keep: bool) -> void:
	m.step(DT)
	for h in m.hunters:
		h.render(DT, 1.0)
	for k in m.kins:
		k.render(DT, 1.0)
	m.cam.snap(P.pos)
	await tree.process_frame
	if Engine.get_process_frames() % 30 == 0:
		var gk := P.kin as Kin
		print("GUARD beside %s, %.2f m from him, feet %+.2f m" % [gk.beside, P.flat_dist(gk), gk.seen_pos().y - P.pos.y])
	if keep and Engine.get_process_frames() % EVERY == 0:
		await RenderingServer.frame_post_draw
		tree.root.get_viewport().get_texture().get_image().save_png(out.path_join("guard_%03d.png" % n))
		n += 1
