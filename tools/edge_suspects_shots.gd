extends RefCounted
## --edge-suspects --shots-dir=<dir> [--arches=gil,mage,bulwark] [--size=1920x1080] [--zoom=0.55] [--quality=<preset>]
## [--only=base,mask] [--compat]: a Hunter in a real match at the real match camera (MatchCam at a wheel zoom: 0.55 the
## closest, as the website clips film the fights, 1.6 the widest), frozen on one idle and one run frame, drawn once per
## render-path suspect toggled: the ink shell, the occlusion overlay, shadows, MSAA and FXAA, the far look, the atlas,
## the vertex AO, the fog, SSAO and glow; "live" is the ink as before its min_px cut (outline.gdshader), "ink_red" the
## shell in red, "mask" the Hunter's coverage (flat magenta, no ink, no MSAA) for measuring the silhouette.
## <dir>/<arch>/<pose>_<variant>.png; <dir>/<arch>/info.txt: glb, triangles, preset, render scale, adapter, meshes.
## --quality: a Settings preset (very_low, low, medium, high, ultra) instead of the machine's auto pick. --compat: on
## the browser build's renderer, as the website clips record (a child Godot on opengl3; a GPU worker without GL runs it
## on llvmpipe, where auto picks Very Low). Needs a renderer (jobq submit --needs gpu). Never touches the save.

const DT := 1.0 / 60.0
const MAGENTA := Color(1, 0, 1)
const VARIANTS := ["base", "live", "no_ink", "no_occ", "no_shadow", "msaa0", "fxaa", "msaa4", "no_far", "flat_tex",
		"no_vao", "no_fog", "no_post", "ink_red", "mask"]
const GLB_OF := {"mage": "ryzz", "bulwark": "breaker"}     # (the Hunter's art folder, where not its id)
const FAR_KEYS := ["far_fres", "far_spec", "far_aa", "far_clamp", "far_rim_soft", "far_glow", "rim_far", "far_smooth"]

var A
var main: Node
var zoom := 0.55

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var args := OS.get_cmdline_user_args()
	if "--compat" in args and not "--edge-child" in args:
		_child(args)
		return
	var out := ""
	var arches: Array = ["gil", "mage", "bulwark"]
	var only: Array = []
	var size := Vector2i(1280, 720) if "--edge-child" in args else Vector2i(1920, 1080)
	for a in args:
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--arches="): arches = Array(a.substr(9).split(",", false))
		if a.begins_with("--zoom="): zoom = float(a.substr(7))
		if a.begins_with("--only="): only = Array(a.substr(7).split(",", false))
		if a.begins_with("--quality="): Settings.v["quality"] = a.substr(10)
		if a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = size
	main.get_viewport().size = size
	Settings.apply("quality")
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	for arch in arches:
		await _arch(String(arch), out.path_join(String(arch)), only)
	print("EDGE_SUSPECTS_DONE ", arches.size())
	main.get_tree().quit()

## --compat: the browser build's renderer (Compatibility, OpenGL), as the website clips record it (gameplay_media.gd):
## the GPU workers pass job arguments after "--", so the same run goes again as a child Godot on opengl3.
func _child(args: PackedStringArray) -> void:
	var res := "1280x720"
	for a in args:
		if a.begins_with("--size="): res = a.substr(7)
	var cmd := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", "opengl3",
		"--audio-driver", "Dummy", "--position", "30000,30000", "--resolution", res, "--"]
	cmd.append_array(args)
	cmd.append("--edge-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), cmd, out, true)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("EDGE_") or line.contains("ERROR"):
			print(line)
	print("EDGE_CHILD rc=%d" % rc)
	main.get_tree().quit(rc)

func _arch(arch: String, dir: String, only: Array) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var r: Array = A.setup(arch, 11.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	T.teleport(T.pos + Vector3(0, 0, 60))      # (the target off screen: only the Hunter in view)
	P.teleport(P.pos + Vector3(9, 0, 0))       # (off the training ground's loot pile, still on the cleared strip)
	m.set_meta("zoom_hold", zoom)
	m.cam.zoom = zoom
	for f in 120:
		_frame(m, P)
	await main.get_tree().process_frame
	_clean()
	var info := PackedStringArray()
	for pose in ["idle", "run"]:
		P.inp["move"] = Vector2(1, 0) if pose == "run" else Vector2.ZERO
		for f in (36 if pose == "run" else 90):
			_frame(m, P)
		P.inp["move"] = Vector2.ZERO
		var sync := P.model.get_node_or_null("Warden/Sync")
		if sync:
			sync.set_process(false)
		info.append("%s cam_d %.2f fov %.2f" % [pose, m.cam.global_position.distance_to(P.position), m.cam.fov])
		for v in VARIANTS:
			if only.is_empty() or v in only:
				await _shot(P, String(v), dir.path_join("%s_%s.png" % [pose, v]))
		if sync:
			sync.set_process(true)
	var root := main.get_tree().root
	info.append("zoom %.2f quality %s scale3d %.3f root %s msaa %d ssaa %d renderer %s adapter %s" % [zoom,
			Settings.quality(), root.scaling_3d_scale, root.size, root.msaa_3d, root.screen_space_aa,
			RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	info.append("glb %s tris %d" % [_glb(arch), _tris(P.model)])
	for g in P.model.find_children("*", "MeshInstance3D", true, false):
		if (g as MeshInstance3D).is_visible_in_tree():
			info.append("mesh %s shadow %d" % [P.model.get_path_to(g), (g as MeshInstance3D).cast_shadow])
	var f := FileAccess.open(dir.path_join("info.txt"), FileAccess.WRITE)
	f.store_string("\n".join(info) + "\n")
	f.close()
	await A.done(m)

## Nothing over the Hunter: the HUD, name tags, grass and particles hidden (the measure is the model's own edge).
func _clean() -> void:
	for n in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n in main.get_tree().root.find_children("*", "Control", true, false):
		if not n.get_parent() is Control:
			(n as Control).visible = false
	for t in ["MultiMeshInstance3D", "Label3D", "GPUParticles3D", "CPUParticles3D", "Sprite3D"]:
		for n in main.get_tree().root.find_children("*", t, true, false):
			(n as Node3D).visible = false

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	MatchCam.update(m, DT, 1.0)
	var sync := P.model.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
		sync.call("_process", DT)

## One suspect off (or the mask on), three frames drawn, the frame saved, then everything put back.
func _shot(P: Hunter, v: String, path: String) -> void:
	var undo: Array = []      # [object, property or "param:<key>", old value]
	var vp := main.get_viewport()
	var meshes: Array = P.model.find_children("*", "MeshInstance3D", true, false)
	match v:
		"no_ink", "mask":
			for g in WardenMerge.inks(P.model):     # (a body's joined ink copy: WardenMerge.join_inks)
				_put(undo, g, "visible", false)
			for mat in _mats(meshes):
				var nx := (mat as Material).next_pass as ShaderMaterial
				if nx and nx.shader == Models.OUTLINE:
					_put(undo, mat, "next_pass", null)
		"no_occ":
			for mi in meshes:
				_put(undo, mi, "material_overlay", null)
		"no_shadow":
			for l in main.get_tree().root.find_children("*", "Light3D", true, false):
				_put(undo, l, "shadow_enabled", false)
			for mi in meshes:
				_put(undo, mi, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		"no_post":
			for we in main.get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var env := (we as WorldEnvironment).environment
				if env:
					_put(undo, env, "ssao_enabled", false)
					_put(undo, env, "glow_enabled", false)
	if v in ["msaa0", "fxaa", "msaa4", "mask"]:
		_put(undo, vp, "msaa_3d", Viewport.MSAA_4X if v == "msaa4" else Viewport.MSAA_DISABLED)
		_put(undo, vp, "screen_space_aa", Viewport.SCREEN_SPACE_AA_FXAA if v == "fxaa" else
				Viewport.SCREEN_SPACE_AA_DISABLED)
	for mat in _mats(meshes):
		if not mat is ShaderMaterial:
			continue
		match v:
			"no_far":
				for k in FAR_KEYS:
					_param(undo, mat, k, 0.0)
			"flat_tex":
				_param(undo, mat, "use_tex", false)
			"no_vao":
				_param(undo, mat, "vertex_ao", false)
				_param(undo, mat, "use_vertex_color", false)
			"no_fog":
				_param(undo, mat, "no_fog", true)
			"live", "ink_red":     # (the ink as before its min_px cut; ink_red: where that shell lands)
				_param(undo, mat, "min_px", 0.0)
				if v == "ink_red" and mat.get_shader_parameter("ink_mask") != null:
					_param(undo, mat, "color", Color(1, 0, 0))
	if v == "mask":
		var flat := StandardMaterial3D.new()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.albedo_color = MAGENTA
		for mi in meshes:
			if (mi as MeshInstance3D).visible and (mi as MeshInstance3D).cast_shadow != \
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_put(undo, mi, "material_override", flat)
				_put(undo, mi, "material_overlay", null)
	for i in 3:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	undo.reverse()
	for u in undo:
		var o: Object = u[0]
		var key: String = u[1]
		if key.begins_with("param:"):
			(o as ShaderMaterial).set_shader_parameter(key.substr(6), u[2])
		else:
			o.set(key, u[2])

func _put(undo: Array, o: Object, key: String, val: Variant) -> void:
	undo.append([o, key, o.get(key)])
	o.set(key, val)

func _param(undo: Array, mat: ShaderMaterial, key: String, val: Variant) -> void:
	var old: Variant = mat.get_shader_parameter(key)
	if old == null:
		return
	undo.append([mat, "param:" + key, old])
	mat.set_shader_parameter(key, val)

## Every material the Hunter's meshes draw with, and the passes chained after them.
func _mats(meshes: Array) -> Array:
	var out: Array = []
	for mi in meshes:
		var g := mi as MeshInstance3D
		if g.mesh == null:
			continue
		for si in g.mesh.get_surface_count():
			var mat: Material = g.get_active_material(si)
			while mat and not (mat in out):
				out.append(mat)
				mat = mat.next_pass
	return out

func _tris(model: Node) -> int:
	var n := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or not (mi as MeshInstance3D).visible:
			continue
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			var count: int = (idx as PackedInt32Array).size() if idx != null \
					else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			n += count / 3
	return n

func _glb(arch: String) -> String:
	var w: String = GLB_OF.get(arch, arch)
	return "res://art/wardens/%s/%s.glb" % [w, w]
