extends Node3D
## Every monster side by side under the match's light, the brutes and skitters shown mid-stride and
## mid-windup so their joints can be checked. Run with -- --mob-gallery (or open
## tests/mob_gallery.tscn and press F6). --mob-close: a closer camera on the common monsters;
## --mob-dress: a row per biome, each monster wearing that biome's back dressing;
## --mob-far: from the match camera's height. Use with --shot / --frames. --art1 shows the old ones.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var T: Dictionary = Data.TIERS[0]
	var env := WorldEnvironment.new()
	var sky: Color = T["sky"]; var amb: Color = T["ambient"]; var cl: Array = T["clouds"]
	env.environment = Look.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35), "horizon": (cl[1] as Color).lerp(T["sun"], 0.5).lightened(0.15),
		"below": cl[0], "ambient": amb, "ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": T["sun"]})
	add_child(env)
	var sun := Look.lights(self, T["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	var ids: Array = []
	for k in Data.MOBS:
		if not Data.MOBS[k].get("boss", false) and not Data.MOBS[k].get("ward", false):
			ids.append(k)
	for a in args:
		if a.begins_with("--mob-only="):
			ids = Array(a.substr(11).split(","))
	var rows: Array = [""]
	if "--mob-dress" in args:
		rows = Flora.STYLES
	var t0 := Time.get_ticks_usec()
	var tris := 0; var draws := 0
	for ri in rows.size():
		var ground := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(ids.size() * 2.6 + 8, 3.6 if rows.size() > 1 else 12.0)
		ground.mesh = pm
		var gm := StandardMaterial3D.new()
		var stn: String = rows[ri] if rows[ri] != "" else "meadow"
		gm.albedo_color = Color(String(World.load_biome(stn).get("colors", {}).get("top", "7a9a5a")))
		gm.roughness = 1.0
		ground.material_override = gm
		ground.position = Vector3(0, 0, ri * 3.6)
		add_child(ground)
		for i in ids.size():
			var kind := String(ids[i])
			var k := Models.mob(kind)
			k.position = Vector3((i - (ids.size() - 1) * 0.5) * 2.6, 0, ri * 3.6)
			k.rotation.y = PI + 0.5
			add_child(k)
			if rows[ri] != "" and k.has_meta("sculpted"):
				MobModels.dress(k, rows[ri])
			var b: Node3D = k.get_node("Body")
			if kind == "brute" and b.has_node("LegL"):
				(b.get_node("LegL") as Node3D).rotation.x = 0.4
				(b.get_node("LegR") as Node3D).rotation.x = -0.4
				(b.get_node("Torso/ArmL") as Node3D).rotation.x = -0.3
				(b.get_node("Torso/ArmR") as Node3D).rotation.x = 0.3
			elif kind == "warden":
				for a in ["ArmL", "ArmR"]:
					var arm := b.get_node_or_null("Torso/" + a) as Node3D
					if arm: arm.rotation.x = 2.4
			elif kind == "skitter":
				for j in 3:
					for sx in [-1, 1]:
						var lg := b.get_node_or_null("Leg%d%d" % [j, sx]) as Node3D
						if lg: lg.rotation.y = (0.4 if (j % 2 == 0) == (sx > 0) else -0.4)
			if ri == 0:
				var st := _stats(k)
				tris += st[0]; draws += st[1]
				print("MOB %-9s tris %6d meshes %3d" % [kind, st[0], st[1]])
				var l := Label3D.new()
				l.text = kind
				l.font_size = 40; l.pixel_size = 0.005
				l.position = k.position + Vector3(0, 0.05, 1.3)
				l.rotation.x = -PI / 2
				add_child(l)
	print("MOB built in %.1f ms: %d tris, %d mesh instances" % [(Time.get_ticks_usec() - t0) / 1000.0, tris, draws])
	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	var c := Vector3(0, 0, (rows.size() - 1) * 1.8)
	if "--mob-far" in args:
		cam.position = c + Vector3(0, 30, 20)
	elif "--mob-close" in args:
		c = Vector3(0, 0, 0)
		cam.position = c + Vector3(0, 3.2 + ids.size() * 1.0, 4.5 + ids.size() * 2.2)
	else:
		cam.position = c + Vector3(0, 9.0 + rows.size() * 3.0, 12.0 + rows.size() * 2.0)
	cam.look_at(c + Vector3(0, 0.9, 0))
	cam.make_current()

func _stats(n: Node) -> Array:
	var tris := 0; var draws := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mesh: Mesh = (c as MeshInstance3D).mesh
			draws += 1
			for si in mesh.get_surface_count():
				var a := mesh.surface_get_arrays(si)
				var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += ix.size() / 3 if ix.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		for ch in c.get_children(): stack.append(ch)
	return [tris, draws]
