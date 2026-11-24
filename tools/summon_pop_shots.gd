extends RefCounted
## --summon-pop-shots --shots-dir=<dir>: the summon pop's type-coloured light (BokiWispPop), one row per type
## (ember, tempest teal, bloom), frames at u = 0, .15, .3, .4, .55, .75 of a burst, on a plain ground. Writes
## <dir>/<type>_<n>.png and key.json; tools/summon_pop_strip.py joins them into one sheet. Needs a renderer.

const US := [0.0, 0.15, 0.3, 0.4, 0.55, 0.75]
const TYPES := ["ember", "tempest", "bloom"]

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var vp := SubViewport.new()  # its own world: Main's splash and menus stay out of the frames
	vp.size = Vector2i(480, 360)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.4, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, -0.1, 1.5)
	cam.look_at(Vector3(0, -0.2, 0))
	cam.current = true
	var seen := {}
	for id in Data.KIN:
		var t := DexView.type_of(String(id))
		if TYPES.has(t) and not seen.has(t):
			seen[t] = String(id)
	var key := {}
	for t in TYPES:
		var pop := BokiWispPop.new(String(seen[t]), {})
		pop.stand = Vector3(0, -0.6, 0)
		root.add_child(pop)
		key[t] = {"species": seen[t], "type_col": DexView.type_col(t).to_html(false), "rim": []}
		for i in US.size():
			pop.pose(US[i], true)
			(pop.wisp.get_node("Trail") as CPUParticles3D).emitting = false
			for f in 3:
				await main.get_tree().process_frame
			vp.get_texture().get_image().save_png(dir.path_join("%s_%d.png" % [t, i]))
			key[t]["rim"].append(pop.glow_at(US[i], true).to_html(false))
		pop.queue_free()
	var f := FileAccess.open(dir.path_join("key.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"us": US, "order": TYPES, "types": key}))
	f.close()
	print("SUMMONPOPSHOTS %d frames in %s" % [TYPES.size() * US.size(), dir])
	main.get_tree().quit(0)
