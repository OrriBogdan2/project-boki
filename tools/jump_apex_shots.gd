extends RefCounted
## --jump-apex-shots --shots-dir=<dir> [--size=640]: Kael in a live training match at the top of a standing jump,
## once at the old 6.8 m/s lift-off and once at Hunter.JUMP_V (the source's 7.5), filmed side-on from one fixed
## camera so the two heights compare: <dir>/apex_6.8.png, <dir>/apex_7.5.png. Prints one JUMP_APEX_SHOT line each
## (lift-off, apex height). Needs a renderer.

const OLD_JUMP_V := 6.8  # m/s: the lift-off before 11-26
const CAM_DIST := 9.0  # m: side-on, level with the jump's middle
const CAM_FOV := 24.0  # degrees

var tree: SceneTree


func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	var px := 640
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	DirAccess.make_dir_recursive_absolute(out)
	var m := Match.new()
	main.add_child(m)
	var arch := "juggernaut"
	m.start(
		{
			"training": true,
			"teams": 1,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 77,
			"no_drop": true,
			"cls": Arch.weight(arch),
			"arch": arch,
			"weapon": Arch.signature(arch)
		}
	)
	m.set_process(false)
	m.hud.visible = false
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	h.set_arch(arch)
	var home := h.pos
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.make_current()
	cam.fov = CAM_FOV
	cam.global_position = home + Vector3(CAM_DIST, 1.4, 0)
	cam.look_at(home + Vector3(0, 1.4, 0))
	for v in [OLD_JUMP_V, Hunter.JUMP_V]:
		h.teleport(home)
		h.vel = Vector3.ZERO
		h.inp["aim"] = home + Vector3(0, 0.9, -8)
		for i in 40:
			_step(m, h)
		h.vel.y = v
		h.grounded = false
		while h.vel.y > 0.0:
			_step(m, h)
		await RenderingServer.frame_post_draw
		print("JUMP_APEX_SHOT lift-off %.1f m/s apex %.2f m" % [v, h.pos.y - home.y])
		tree.root.get_texture().get_image().save_png(out.path_join("apex_%.1f.png" % v))
	print("JUMP_APEX_SHOTS_DONE")
	tree.quit()


func _step(m: Match, h: Hunter) -> void:
	m.step(Match.DT)
	h.render(Match.DT, 1.0)
