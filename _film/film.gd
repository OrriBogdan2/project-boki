extends Node3D
## Round-2 Sparkle film (copied from Tenzo r2; adds --facey= and --clips=) (main scene of a tiny render project, so jobq can run it on the GPU worker):
## user args: OUTDIR TAG:GLB,GLB;TAG:GLB,... [--n=20] [--px=1024]. GLB paths relative to the project.
## Same match look as round 1 (tools/film.gd): Look.environment tier-0 params, Look.lights sun fff1dc -55/-35, terrain shader
## ground, match camera pitch 57 deg at 32.2 m (narrow lens = native crop). Views: game, eye, knee, face.
const LookS = preload("res://scripts/core/look.gd")
var out := ""
var px := 1024
var n := 20
var facey := 1.62
var clips_only := ""
var views := ["game", "eye", "knee", "face"]
var skel: Skeleton3D = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = ProjectSettings.globalize_path("res://" + a[0]) if not a[0].begins_with("/") else a[0]
	for x in a:
		if x.begins_with("--n="): n = int(x.substr(4))
		if x.begins_with("--px="): px = int(x.substr(5))
		if x.begins_with("--facey="): facey = float(x.substr(8))
		if x.begins_with("--clips="): clips_only = x.substr(8)
		if x.begins_with("--views="): views = Array(x.substr(8).split(","))
	get_window().size = Vector2i(px * 3 / 4, px)
	get_viewport().size = Vector2i(px * 3 / 4, px)
	_run.call_deferred(a[1].split(";"))

func _cam(cam: Camera3D, view: String) -> void:
	var yaw := deg_to_rad(20.0)
	match view:
		"game":
			var pit := deg_to_rad(57.0); var d := 32.2
			cam.position = Vector3(d * cos(pit) * sin(yaw), d * sin(pit) + 0.6, d * cos(pit) * cos(yaw))
			cam.fov = rad_to_deg(2.0 * atan(1.05 / d)); cam.look_at(Vector3(0, 0.6, 0))
		"eye":
			cam.position = Vector3(9.0 * sin(yaw), 1.0, 9.0 * cos(yaw))
			cam.fov = rad_to_deg(2.0 * atan(1.15 / 9.0)); cam.look_at(Vector3(0, 0.95, 0))
		"knee":
			cam.position = Vector3(7.0 * sin(yaw), 0.45, 7.0 * cos(yaw))
			cam.fov = rad_to_deg(2.0 * atan(1.2 / 7.0)); cam.look_at(Vector3(0, 0.95, 0))
		"faceT", "hipsT":
			var bn := "Head" if view == "faceT" else "Hips"
			var t := Vector3(0, facey if view == "faceT" else 0.9, 0)
			if skel and skel.find_bone(bn) >= 0:
				t = skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bn)).origin
				if view == "faceT": t.y += 0.09
			var dd := 3.0
			cam.position = t + Vector3(dd * sin(yaw), 0.05, dd * cos(yaw))
			cam.fov = rad_to_deg(2.0 * atan((0.22 if view == "faceT" else 0.42) / dd)); cam.look_at(t)
		"face":
			cam.position = Vector3(3.0 * sin(yaw), facey + 0.04, 3.0 * cos(yaw))
			cam.fov = rad_to_deg(2.0 * atan(0.30 / 3.0)); cam.look_at(Vector3(0, facey, 0))

func _run(sets: PackedStringArray) -> void:
	var T := {"sky": Color("10131f"), "ambient": Color("b9c4e6"), "sun": Color("fff1dc"), "clouds": [Color(0.06, 0.07, 0.13), Color(0.22, 0.24, 0.38)]}
	var sky: Color = T["sky"]; var amb: Color = T["ambient"]; var cl: Array = T["clouds"]
	var env := WorldEnvironment.new()
	env.environment = LookS.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35), "horizon": (cl[1] as Color).lerp(T["sun"], 0.5).lightened(0.15),
		"below": cl[0], "ambient": amb, "ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": T["sun"]})
	add_child(env)
	var sun := LookS.lights(self, T["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		for j in 40:
			var x0 := -40.0 + i * 2.0; var z0 := -40.0 + j * 2.0
			for p in [Vector3(x0, 0, z0), Vector3(x0 + 2, 0, z0), Vector3(x0 + 2, 0, z0 + 2), Vector3(x0, 0, z0), Vector3(x0 + 2, 0, z0 + 2), Vector3(x0, 0, z0 + 2)]:
				st.set_color(Color("5f8d45")); st.set_normal(Vector3.UP); st.add_vertex(p)
	var ground := MeshInstance3D.new(); ground.mesh = st.commit()
	var tm := ShaderMaterial.new(); tm.shader = load("res://shaders/terrain.gdshader"); ground.material_override = tm
	add_child(ground)
	var cam := Camera3D.new(); add_child(cam); cam.make_current()
	print("FILM_RENDERER ", RenderingServer.get_current_rendering_driver_name(), " ", RenderingServer.get_video_adapter_name())
	for s in sets:
		var tag := s.get_slice(":", 0)
		for rel in s.get_slice(":", 1).split(","):
			var doc := GLTFDocument.new(); var gs := GLTFState.new()
			var err := doc.append_from_file(ProjectSettings.globalize_path("res://" + rel), gs)
			if err != OK: print("LOAD FAIL ", rel, " ", err); continue
			var model: Node3D = doc.generate_scene(gs)
			add_child(model)
			var aps := model.find_children("*", "AnimationPlayer", true, false)
			if aps.is_empty():  # static pick (v95 current glb): one still per view
				for view in ["game", "eye", "knee", "face"]:
					_cam(cam, view)
					var sdir := "%s/%s/still/%s" % [out, tag, view]
					DirAccess.make_dir_recursive_absolute(sdir)
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_jpg("%s/f000.jpg" % sdir, 0.92)
				model.queue_free(); await get_tree().process_frame
				continue
			var ap: AnimationPlayer = aps[0]
			var sks := model.find_children("*", "Skeleton3D", true, false)
			skel = sks[0] if not sks.is_empty() else null
			for clip in ap.get_animation_list():
				var an := ap.get_animation(clip); var L := an.length
				var cname := clip.get_slice("|", 1) if clip.contains("|") else clip
				if clips_only != "" and not (cname in clips_only.split(",")): continue
				if rel.contains("_walk"): cname = "walk"
				elif rel.contains("_run"): cname = "run"
				for view in views:
					var dir := "%s/%s/%s/%s" % [out, tag, cname, view]
					DirAccess.make_dir_recursive_absolute(dir)
					ap.play(clip)
					for f in n:
						ap.seek(L * f / float(n), true)
						await get_tree().process_frame
						_cam(cam, view)
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_jpg("%s/f%03d.jpg" % [dir, f], 0.92)
			model.queue_free(); await get_tree().process_frame
	print("FILM_DONE")
	get_tree().quit()
