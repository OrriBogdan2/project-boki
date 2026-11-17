extends Node3D
## scratch (not committed): 4-view turntable of one monster. -- --kind=K --out=DIR [--pose=P] [--glb]
var kind := ""; var out := ""; var pose := "rest"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="): kind = a.substr(7)
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--pose="): pose = a.substr(7)
	call_deferred("_go")

func _go() -> void:
	var root3 := Node3D.new(); add_child(root3)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("d8dde4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("b8c0d0"); env.environment.ambient_light_energy = 0.6
	root3.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -35, 0); sun.light_energy = 1.1; root3.add_child(sun)
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	var k := Models.mob(kind)
	root3.add_child(k)
	_pose(k.get_node("Body"))
	var ab := _aabb(k)
	var h := maxf(ab.size.y, maxf(ab.size.x, ab.size.z))
	var cam := Camera3D.new(); cam.fov = 30.0; root3.add_child(cam)
	var c := ab.get_center()
	var yaws := {"front": 0.0, "tq": 0.6, "side": PI / 2, "back": PI}
	for nm in yaws:
		k.rotation.y = PI + float(yaws[nm])
		var d := h * 2.3
		cam.position = c + Vector3(0, h * 0.35, d)
		cam.look_at(c)
		cam.make_current()
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [out, kind, pose, nm])
	var mg = k.get_node_or_null("MobGlb"); if mg: print("LINKS ", mg._links.size(), " ", mg._skel.get_bone_pose(2), " ", (k.get_node("Body/Leg0-1") as Node3D).rotation)
	print("TURN_DONE ", kind, " ", ab)
	get_tree().quit()

func _pose(b: Node3D) -> void:
	if pose == "rest": return
	var w := 1.0 if pose == "windup" else 0.0
	var s := 0.5 if pose == "walk" else 0.0
	match kind:
		"brute", "warden":
			var t := b.get_node_or_null("Torso") as Node3D
			if b.get_node_or_null("LegL"): (b.get_node("LegL") as Node3D).rotation.x = s - w * 0.3
			if b.get_node_or_null("LegR"): (b.get_node("LegR") as Node3D).rotation.x = -s + w * 0.2
			if t:
				for a in ["ArmL", "ArmR"]:
					var arm := t.get_node_or_null(a) as Node3D
					if arm: arm.rotation.x = w * 2.7 + (s * 0.6 if a == "ArmL" else -s * 0.6) * -1.0
		"sentinel":
			var cr := b.get_node_or_null("Crystal") as Node3D
			if cr:
				cr.position.y += 0.25 * w; cr.scale = Vector3.ONE * (1.0 + 0.12 * w)
				cr.rotation.x = -0.2 * w + 0.2 * s; cr.rotation.y = 0.9 * s + 1.2 * w
		"skitter":
			for i in 3:
				for sx in [-1, 1]:
					var lg := b.get_node_or_null("Leg%d%d" % [i, sx]) as Node3D
					if lg:
						var ph := (PI if (i % 2 == 0) == (sx > 0) else 0.0) + 0.8
						lg.rotation.y = sin(ph) * 0.45 * float(s > 0); lg.rotation.z = maxf(0.0, cos(ph)) * 0.35 * sx * float(s > 0) - w * 0.3 * sx
			for jn in ["JawL", "JawR"]:
				var j := b.get_node_or_null(jn) as Node3D
				if j: j.rotation.y = (0.25 + w * 1.1) * (1.0 if jn == "JawL" else -1.0)

func _aabb(n: Node3D) -> AABB:
	var ab := AABB(); var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is VisualInstance3D and (c as Node3D).is_visible_in_tree() and not (c is Label3D):
			var g := (c as VisualInstance3D).global_transform * (c as VisualInstance3D).get_aabb()
			ab = g if first else ab.merge(g); first = false
		for ch in c.get_children(): stack.append(ch)
	return ab
