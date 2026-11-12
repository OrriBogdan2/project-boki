extends RefCounted
## --loco-dir-shots --shots-dir=<dir> [--wardens=a,b] [--states=walk,run,crouch_walk] [--tag=<text>]: the footage for
## --loco-dir-check (docs/art/LOCO_DIR.md). Per Hunter and state, eight copies in a 4 x 2 grid move in the eight
## directions of the check off a facing toward the camera (a front 3/4 view), each on its own checker floor that
## scrolls under it at the ground speed, so a planted foot that slides or steps the wrong way shows against the squares.
## <dir>/<arch>_<state>/f000.png... at 30 fps, SECONDS long, after a WARM_S start. Needs a renderer.

const CHECK := preload("res://tools/loco_dir_check.gd")
const DT := 1.0 / 30.0
const WARM_S := 0.6          # s moving before the first frame (the start shows in the first frames)
const SECONDS := 2.0         # s filmed
const CELL := 2.2            # m between copies for a Hunter of model scale 1
const ORDER := ["fl", "f", "fr", "r", "l", "bl", "b", "br"]     # grid order, row by row: the way each one walks
const PX := Vector2i(960, 520)
const SQUARE := 0.25         # m: a checker square

var tree: SceneTree
var cam: Camera3D

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	var only: Array = Arch.ORDER
	var states := ["walk", "crouch_walk"]
	var tag := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): only = Array(a.substr(10).split(",", false))
		if a.begins_with("--states="): states = Array(a.substr(9).split(",", false))
		if a.begins_with("--tag="): tag = a.substr(6)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = PX
	main.get_viewport().size = PX
	for id in only:
		if not WardenClips.data(WardenGlb.art(String(id))).has("loco") or id in CHECK.FLAT:
			continue
		for st in states:
			await _film(main, String(id), String(st), out, tag)
	print("LOCO_DIR_SHOTS_DONE")
	tree.quit()

func _film(main: Node, id: String, st: String, out: String, tag: String) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()     # (no fog or sky: plain, so the squares read)
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("30343c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8ccd8")
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ck := 1.0 if st.begins_with("crouch") else 0.0
	var top := float(HunterMove.of(id)["speed"])
	var walk := float(WardenClips.data(WardenGlb.art(id))["loco"].get("walk_speed", 2.2))
	var spd := top * CHECK.CROUCH_K if ck > 0.0 else (walk + top) / 2.0 if st == "run" else walk
	var copies: Array = []     # [model, HunterAnim, sync, velocity, floor material]
	var gap := CELL
	for i in ORDER.size():
		var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		m.set_meta("anim_seed", 1)
		holder.add_child(m)
		gap = CELL * maxf(m.get_node("Warden").global_transform.basis.get_scale().y, 1.0)
		m.position = Vector3((i % 4 - 1.5) * gap, 0.0, (i / 4 - 0.5) * gap)
		var ring := m.get_node_or_null("TeamRing") as Node3D
		if ring:
			ring.visible = false
		var vel := Vector3(-sin(deg_to_rad(CHECK.DIRS[ORDER[i]])), 0.0, -cos(deg_to_rad(CHECK.DIRS[ORDER[i]]))) * spd
		var label := Label3D.new()
		label.text = ORDER[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.no_depth_test = true
		label.outline_size = 24
		label.position = m.position + Vector3(0.38 * gap, 0.05, -0.38 * gap)
		holder.add_child(label)
		copies.append([m, HunterAnim.new(m), null, vel, _floor(holder, m.position, gap)])
	var title := Label3D.new()
	title.text = "%s  %s  %.1f m/s  %s" % [id, st, spd, tag]
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.font_size = 80
	title.no_depth_test = true
	title.outline_size = 24
	title.position = Vector3(0.0, 0.1, 1.35 * gap)
	holder.add_child(title)
	for k in 5:
		await tree.process_frame
	for c in copies:
		c[2] = (c[0] as Node3D).get_node("Warden/Sync")
		(c[2] as Node).set_process(false)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6 * gap
	cam.position = Vector3(-1.6 * gap, 6.0 * gap, -4.5 * gap)     # (in front of them, to their right: a 3/4 view)
	cam.look_at(Vector3(0, 0.25 * gap, 0))
	cam.make_current()
	var dir := out.path_join("%s_%s" % [id, st])
	DirAccess.make_dir_recursive_absolute(dir)
	for k in int((WARM_S + SECONDS) / DT):
		for c in copies:
			var vel: Vector3 = c[3] if k > 6 else Vector3.ZERO      # (six still frames, then the start)
			(c[1] as HunterAnim).update(DT, {"vel": vel, "face": 0.0, "grounded": true, "crouch": ck, "fired": 99.0})
			(c[2] as Node).call("_process", DT)
			var mat: StandardMaterial3D = c[4]
			mat.uv1_offset += Vector3(vel.x, vel.z, 0.0) * DT / (2.0 * SQUARE)
		if k >= int(WARM_S / DT) - 18:     # (the last 18 warm frames: the start is filmed too)
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png(dir.path_join("f%03d.png" % (k - int(WARM_S / DT) + 18)))
		else:
			await tree.process_frame
	holder.queue_free()
	await tree.process_frame

## A checker floor under one copy; its uv1_offset scrolls with the ground.
func _floor(holder: Node3D, at: Vector3, side: float) -> StandardMaterial3D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color("5f8a4a"))
	img.set_pixel(1, 1, Color("5f8a4a"))
	img.set_pixel(1, 0, Color("e8e2c8"))
	img.set_pixel(0, 1, Color("e8e2c8"))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(side / (2.0 * SQUARE), side / (2.0 * SQUARE), 1.0)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(side * 0.95, side * 0.95)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = at + Vector3(0, -0.01, 0)
	holder.add_child(mi)
	return mat
