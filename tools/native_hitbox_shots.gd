extends "res://tools/native_hitbox_check.gd"
## --native-hitbox-shots --shots-dir=<dir> (needs a renderer): each Hunter on Meshy's own skeleton idles inside its
## hurtbox, a translucent cylinder of the hit ring's radius (hit_r + Match.HIT_SLACK) and hit_h's height, seen from
## the front and the side at one scale (an orthographic view, a line every 0.5 m). Writes <dir>/<arch>_front.png and
## <arch>_side.png, and prints the NATIVE_HITBOX rows.

const VIEW := Vector2i(480, 560)
const SPAN := 3.0  # m: the height each view shows (a line every 0.5 m)
const MID_Y := 1.2  # m: the height the view centres on
const SETTLE := 20  # frames: the clip settles on idle

var cam: Camera3D


func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = VIEW
	main.get_viewport().size = VIEW
	holder = Node3D.new()
	main.add_child(holder)
	_stage()
	for a in Arch.ids():
		if not WardenNative.on(a):
			continue
		var m := await stand(main, a)
		m.rotation.y = PI  # (the model faces -Z: PI turns it to the front camera)
		var r := measure(m, a)
		print(row(a, r))
		var box := _hurtbox(r.ring, r.hit_h)
		for k in SETTLE:
			await main.get_tree().process_frame
		for view in ["front", "side"]:
			cam.position = Vector3(0, MID_Y, 8) if view == "front" else Vector3(8, MID_Y, 0)
			cam.rotation = Vector3.ZERO if view == "front" else Vector3(0, PI * 0.5, 0)
			await RenderingServer.frame_post_draw
			main.get_tree().root.get_texture().get_image().save_png(dir.path_join("%s_%s.png" % [a, view]))
		box.queue_free()
		m.queue_free()
	print("NATIVEHITBOX SHOTS DONE")
	main.get_tree().quit()


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SPAN
	holder.add_child(cam)
	cam.make_current()
	_rulers()


## A line every 0.5 m, on the wall behind the Hunter and on the one at its side.
func _rulers() -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in 8:
		var y := 0.5 * i
		im.surface_add_vertex(Vector3(-3, y, -3))
		im.surface_add_vertex(Vector3(3, y, -3))
		im.surface_add_vertex(Vector3(-3, y, -3))
		im.surface_add_vertex(Vector3(-3, y, 3))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	holder.add_child(mi)


## The hurtbox as a translucent cylinder standing on the ground.
func _hurtbox(radius: float, height: float) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.position.y = height * 0.5
	holder.add_child(mi)
	return mi
