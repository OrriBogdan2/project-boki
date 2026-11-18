extends Node3D
## scratch (never committed): one monster posed by MobAnim's own tables.  -- --kind=K --out=DIR --shots=state:phase:view,...
var kind := ""; var out := ""; var shots := "idle:0:front"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="): kind = a.substr(7)
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--shots="): shots = a.substr(8)
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
	var body := k.get_node("Body")
	for i in 3: await get_tree().process_frame
	var ab := _aabb(k)
	var h := maxf(ab.size.y, maxf(ab.size.x, ab.size.z))
	var c := ab.get_center()
	var cam := Camera3D.new(); cam.fov = 30.0; root3.add_child(cam)
	var yaws := {"front": 0.0, "tq": 0.6, "side": PI / 2, "back": PI}
	var d := MobAnim.table(kind)
	var nodes: Array = []; var rr: Array = []; var rp: Array = []
	for nm in d["slots"]:
		var n := MobAnim.pivot(body, String(nm)); nodes.append(n)
		rr.append(n.rotation if n else Vector3.ZERO); rp.append(n.position if n else Vector3.ZERO)
	for sh in shots.split(","):
		var p := sh.split(":")
		var st := MobAnim.STATES.find(p[0]); var ph := float(p[1]); var view := p[2]
		var acc := PackedFloat32Array(); acc.resize(nodes.size() * MobAnim.STRIDE)
		for tr in d["states"][st]:
			var q: float = ph + float(tr[3])
			q = fposmod(q, 1.0) if MobAnim.LOOPS[st] and q != 1.0 else minf(q, 1.0)
			var x := q * MobAnim.SAMPLES; var i := mini(int(x), MobAnim.SAMPLES - 1)
			var cv: PackedFloat32Array = tr[2]; var v := cv[i] + (cv[i + 1] - cv[i]) * (x - i)
			var tg: PackedInt32Array = tr[0]; var sg: PackedFloat32Array = tr[1]
			for j in tg.size(): acc[tg[j]] += v * sg[j]
		for j in nodes.size():
			var n: Node3D = nodes[j]
			if n == null: continue
			var b := j * MobAnim.STRIDE
			n.rotation = rr[j] + Vector3(acc[b], acc[b + 1], acc[b + 2])
			n.position = rp[j] + Vector3(acc[b + 3], acc[b + 4], acc[b + 5])
			n.scale = Vector3(1.0 + acc[b + 6], 1.0 + acc[b + 7], 1.0 + acc[b + 8])
		k.rotation.y = PI + float(yaws.get(view, 0.0))
		cam.position = c + Vector3(0, h * 0.35, h * 2.3); cam.look_at(c); cam.make_current()
		for i in 5: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [out, kind, p[0] + p[1].replace(".", ""), view])
	print("TURN_DONE ", kind, " ", ab)
	get_tree().quit()

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
