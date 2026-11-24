extends RefCounted
## --geo-shots --geo-dir=res://<dir> --shots-dir=<dir>: renders the posed hunter frames tools/anim/geo_check.py
## --dump-shots wrote (<name>.json meta + <name>.bin: float32 positions and normals, uint32 triangles, one group byte
## per triangle: 0 body, 1 the part that clips, 2 the part it sinks into, drawn see-through)
## as <shots-dir>/<name>_close.png (the clip point close up) and <name>_full.png, on the real GPU. Needs a renderer.

const SIZE := 520
const CLOSE_DIST := 1.0
const FULL_DIST := 3.4
var tree: SceneTree
var holder: Node3D
var cam: Camera3D

func run(main: Node) -> void:
	tree = main.get_tree()
	var dir := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--geo-dir="): dir = a.substr(10)
		if a.begins_with("--shots-dir="): out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(SIZE, SIZE)
	main.get_viewport().size = Vector2i(SIZE, SIZE)
	_stage(main)
	for k in 30:
		await tree.process_frame
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			await _shot(dir, f.get_basename(), out)
	print("GEO_SHOTS_DONE")
	tree.quit()


func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.93, 0.93, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	holder.add_child(sun)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()


func _shot(dir: String, name: String, out: String) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [dir, name]))
	var fa := FileAccess.open("%s/%s.bin" % [dir, name], FileAccess.READ)
	var nv := int(meta["nv"])
	var nt := int(meta["nt"])
	var pos := fa.get_buffer(nv * 12).to_float32_array()
	var nrm := fa.get_buffer(nv * 12).to_float32_array()
	var tris := fa.get_buffer(nt * 12).to_int32_array()
	var group := fa.get_buffer(nt)
	var idx: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for t in nt:
		idx[group[t]].append_array(tris.slice(t * 3, t * 3 + 3))
	var mesh := ArrayMesh.new()
	var colors := [Color(0.72, 0.72, 0.74), Color(0.9, 0.12, 0.1), Color(0.15, 0.35, 0.95, 0.4)]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for v in nv:
		verts.append(Vector3(pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]))
		norms.append(Vector3(nrm[v * 3], nrm[v * 3 + 1], nrm[v * 3 + 2]))
	for g in 3:
		if idx[g].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_INDEX] = idx[g]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[g]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.9
		if g == 2:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var body := MeshInstance3D.new()
	body.mesh = mesh
	holder.add_child(body)
	var at: Array = meta["at"]
	var centre := Vector3(at[0], at[1], at[2])
	var view: Array = meta["view"]
	var dirv := Vector3(view[0], view[1], view[2]).normalized()
	cam.fov = 35.0
	cam.position = centre + dirv * CLOSE_DIST
	cam.look_at(centre)
	await _grab("%s/%s_close.png" % [out, name])
	var mid := Vector3(centre.x, float(meta["height"]) * 0.5, centre.z)
	cam.fov = 30.0
	cam.position = mid + dirv * FULL_DIST * float(meta["height"]) / 1.8
	cam.look_at(mid)
	await _grab("%s/%s_full.png" % [out, name])
	body.queue_free()


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
