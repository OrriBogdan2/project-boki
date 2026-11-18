extends RefCounted
## scratch (never committed): --mob-r2-shots --shots-dir=<dir> --variants=kind:label:res_path,... [--size=WxH]
## Real-GPU in-game renders of candidate mob models vs live. A label with an empty path is the live model.
## Per variant: (1) studio poses from MobAnim's own tables (game toon shader + region repaint), and
## (2) the mob spawned in a real match, seen by the match camera at the closest wheel zoom, cropped.

const SHOTS := "idle:0:front,idle:0:tq,idle:0:side,idle:0:back,walk:0.25:tq,windup:1:tq,windup:1:front,strike:0.15:tq"
const CROP := 720

var main: Node
var dir := "user://mob_r2_shots"
var variants: Array = []

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--shots-dir="):
			dir = s.substr(12)
		elif s.begins_with("--variants="):
			for v in s.substr(11).split(","):
				variants.append(v.split(":"))
		elif s.begins_with("--size="):
			var wh := s.substr(7).split("x")
			main.get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	print("MOBR2 renderer ", RenderingServer.get_video_adapter_name())
	if not OS.get_cmdline_user_args().has("--match-only"):
		for v in variants:
			_use(v)
			await _studio(String(v[0]), String(v[1]))
	print("MOBR2 window ", main.get_viewport().get_visible_rect().size, " ", DisplayServer.window_get_size())
	await _in_match()
	print("MOBR2 DONE")
	main.get_tree().quit()

## Points MobGlb's scene cache for the kind at the variant's glb (live: the shipped one).
func _use(v: Array) -> void:
	var kind := String(v[0])
	var path: String = "res://" + String(v[2]) if v.size() > 2 and String(v[2]) != "" else MobGlb.PATH % [kind, kind]
	MobGlb._scenes[kind] = load(path)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _studio(kind: String, label: String) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(720, 720)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(sv)
	var root3 := Node3D.new()
	sv.add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d8dde4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b8c0d0")
	env.environment.ambient_light_energy = 0.6
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	root3.add_child(sun)
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	var k := Models.mob(kind)
	root3.add_child(k)
	var body := k.get_node("Body")
	await _frames(3)
	var ab := _aabb(k)
	var h := maxf(ab.size.y, maxf(ab.size.x, ab.size.z))
	var c := ab.get_center()
	var cam := Camera3D.new()
	cam.fov = 30.0
	root3.add_child(cam)
	var yaws := {"front": 0.0, "tq": 0.6, "side": PI / 2, "back": PI}
	var d := MobAnim.table(kind)
	var nodes: Array = []
	var rr: Array = []
	var rp: Array = []
	for nm in d["slots"]:
		var n := MobAnim.pivot(body, String(nm))
		nodes.append(n)
		rr.append(n.rotation if n else Vector3.ZERO)
		rp.append(n.position if n else Vector3.ZERO)
	for sh in SHOTS.split(","):
		var p := sh.split(":")
		var st := MobAnim.STATES.find(p[0])
		var ph := float(p[1])
		var view := p[2]
		var acc := PackedFloat32Array()
		acc.resize(nodes.size() * MobAnim.STRIDE)
		for tr in d["states"][st]:
			var q: float = ph + float(tr[3])
			q = fposmod(q, 1.0) if MobAnim.LOOPS[st] and q != 1.0 else minf(q, 1.0)
			var x := q * MobAnim.SAMPLES
			var i := mini(int(x), MobAnim.SAMPLES - 1)
			var cv: PackedFloat32Array = tr[2]
			var val := cv[i] + (cv[i + 1] - cv[i]) * (x - i)
			var tg: PackedInt32Array = tr[0]
			var sg: PackedFloat32Array = tr[1]
			for j in tg.size():
				acc[tg[j]] += val * sg[j]
		for j in nodes.size():
			var n: Node3D = nodes[j]
			if n == null:
				continue
			var b := j * MobAnim.STRIDE
			n.rotation = rr[j] + Vector3(acc[b], acc[b + 1], acc[b + 2])
			n.position = rp[j] + Vector3(acc[b + 3], acc[b + 4], acc[b + 5])
			n.scale = Vector3(1.0 + acc[b + 6], 1.0 + acc[b + 7], 1.0 + acc[b + 8])
		k.rotation.y = PI + float(yaws.get(view, 0.0))
		cam.position = c + Vector3(0, h * 0.35, h * 2.3)
		cam.look_at(c)
		cam.make_current()
		await _frames(5)
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		img.save_png(dir.path_join("%s_%s_%s_%s.png" % [kind, label, p[0] + p[1].replace(".", ""), view]))
	sv.queue_free()
	await _frames(2)
	print("MOBR2 studio ", kind, " ", label)

func _in_match() -> void:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	m.hud.visible = false
	m.cam.user_zoom = CamWheel.near()
	var P: Hunter = m.player
	m.cam.focus = P.pos
	await _frames(90)
	for v in variants:
		_use(v)
		var kind := String(v[0])
		var ad := P.aim_dir().normalized()
		var mb := m.spawn_mob(kind, P.pos + Vector3(ad.x, 0, ad.y) * 3.2)
		print("MOBR2 aim ", ad)
		mb.face = PI - 0.45  # toward the camera, three-quarter
		m.mobs.erase(mb)  # out of Match's loops: no AI (a bomber would blow itself up on the player); posed here instead
		for f in 60:
			mb.render(1.0 / 60.0, 1.0)
			await main.get_tree().process_frame
		print("MOBR2 at ", mb.pos, " player ", P.pos, " vis ", mb.visible, " dead ", mb.dead, " hp ", mb.hp, " parentvis ", m.is_visible_in_tree(), " time ", m.time)
		var img := main.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var c := Vector2i(m.cam.unproject_position(mb.pos + Vector3(0, 0.8, 0)))
		var x := clampi(c.x - CROP / 2, 0, img.get_width() - CROP)
		var y := clampi(c.y - CROP / 2, 0, img.get_height() - CROP)
		img.get_region(Rect2i(x, y, CROP, CROP)).save_png(dir.path_join("%s_%s_match.png" % [kind, String(v[1])]))
		if OS.get_cmdline_user_args().has("--full"):
			img.save_png(dir.path_join("%s_%s_full.png" % [kind, String(v[1])]))
		m.ents_by_id.erase(mb.nid)
		mb.queue_free()
		await _frames(10)
		print("MOBR2 match ", kind, " ", v[1])

func _aabb(n: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is VisualInstance3D and (c as Node3D).is_visible_in_tree() and not (c is Label3D):
			var g := (c as VisualInstance3D).global_transform * (c as VisualInstance3D).get_aabb()
			ab = g if first else ab.merge(g)
			first = false
		for ch in c.get_children():
			stack.append(ch)
	return ab
