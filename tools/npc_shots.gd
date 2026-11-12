extends RefCounted
## --npc-shots --shots-dir=<dir> (a renderer; reruns itself at --fixed-fps 15): frames of the two rigged NPCs at the
## game camera, for a clip (ffmpeg -framerate 15 -i <dir>/f%04d.png). First Pell on the tutorial course (the landing,
## then blinking to the next stops while the course drives itself), then Hob on a new farm (he calls you over and
## waves, the camera swings to him, you walk up and he talks and points at the stall), then a close-up of the two
## on a lawn (idle, talk, wave, then Hob's hammer and Pell's walk). Frames f0000.png on.

const PELL_FRAMES := 165       # ~11 s at 15 fps
const HOB_FRAMES := 150        # ~10 s
const CLOSE_FRAMES := 150      # ~10 s

var main: Node
var dir := "/tmp/npc_shots"
var n := 0

func run(main_node: Node) -> void:
	main = main_node
	if not OS.get_cmdline_user_args().has("--npc-child"):
		_rerun()
		return
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_tree().root.size = Vector2i(1280, 720)
	await _pell()
	await _hob()
	await _closeup()
	print("NPCSHOTS %d frames in %s" % [n, dir])
	main.get_tree().quit(0)

func _pell() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	m.tut.ack()
	for i in PELL_FRAMES:
		if i > 30:      # (a moment at the landing first: Pell waves)
			TutorialDrive.drive(m)
		for s in 4:
			m.step(Match.DT)
		m.cam.snap(m.player.pos)
		await _frame()
	m.queue_free()
	await main.get_tree().process_frame

func _hob() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	d["tutorial"]["home"] = true
	ClassUnlock.choose_starters(["gunslinger"])
	Game.apply_result({"arch": "gunslinger", "extracted": true, "why": "extracted", "knocks": 0, "kills": 0,
			"gems": 0, "seeds": {}, "stats": {}, "lvl": 1, "caught": [], "kin_runs": [], "tonics": 0, "tutorial": true})
	var home = await main._hb_home()
	home._close_panel()
	var talk_at := -1
	for i in HOB_FRAMES + 60:
		var hob: FarmHob = home.hob
		if talk_at < 0 and i >= 75 and hob and hob.chat.intro_t < 0.0:      # walk up and talk
			talk_at = i
			home.ppos = hob.node.position + Vector3(1.2, 0, 1.2)
			home.player.position = home.ppos
			home._use(hob.find(Vector2(home.ppos.x, home.ppos.z)))
		if talk_at > 0 and i - talk_at in [20, 22, 24, 26] and hob.chat.box:
			hob.chat.box.advance()
		if talk_at > 0 and i - talk_at > 55:
			break
		await _frame()

## Both NPCs on a lawn in a world of their own, the camera drifting round: idle, talk, wave, then the extras.
func _closeup() -> void:
	main.get_tree().root.size = Vector2i(1280, 720)
	for c in main.get_children():
		c.queue_free()
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	main.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("86b0d8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a9b3d0")
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	vp.add_child(sun)
	var lawn := MeshInstance3D.new()
	lawn.mesh = CylinderMesh.new()
	(lawn.mesh as CylinderMesh).top_radius = 5.0
	(lawn.mesh as CylinderMesh).bottom_radius = 5.0
	(lawn.mesh as CylinderMesh).height = 0.2
	lawn.position.y = -0.1
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("6fa04a")
	lawn.material_override = grass
	vp.add_child(lawn)
	var hob := NpcModel.new("hob")
	hob.position.x = -0.9
	var pell := NpcModel.new("pell")
	pell.position.x = 0.9
	vp.add_child(hob)
	vp.add_child(pell)
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	for i in CLOSE_FRAMES:
		var a := deg_to_rad(sin(i / float(CLOSE_FRAMES) * TAU) * 28.0)
		var at := Vector3(0, 0.95, 0)
		cam.transform = Transform3D(Basis(), Vector3(sin(a) * 6.0, 2.6, -cos(a) * 6.0)).looking_at(at)
		var seg := i / (CLOSE_FRAMES / 4)
		hob.pose = ["idle", "talk", "wave", "hammer"][mini(seg, 3)]
		pell.pose = ["idle", "talk", "wave", "walk"][mini(seg, 3)]
		await main.get_tree().process_frame
		vp.get_texture().get_image().save_png(dir.path_join("f%04d.png" % n))
		n += 1

## The GPU workers (jobq) pass only the arguments after "--", so this runs itself again as a child Godot with an
## even 15 fps clock (the clips play on the frame's delta) and a 1280x720 window (as gameplay_media does).
func _rerun() -> void:
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", "opengl3",
		"--audio-driver", "Dummy", "--resolution", "1280x720", "--fixed-fps", "15", "--"]
	args.append_array(OS.get_cmdline_user_args())
	args.append("--npc-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("NPCSHOTS") or line.contains("ERROR"):
			print(line)
	print("NPCSHOTS child rc=%d" % rc)
	main.get_tree().quit(rc)

func _frame() -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("f%04d.png" % n))
	n += 1
