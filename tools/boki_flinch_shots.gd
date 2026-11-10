extends RefCounted
## --boki-flinch-shots --shots-dir=<dir> [--px=384]: a strip per species of a Boki taking a big hit from the side
## (KinFlinch): rest, then AT seconds after the hit. <dir>/flinch_<species>.png and flinch_all.png. Needs a renderer.

const SPECIES := ["cindle", "zapple", "wisplet", "zephyrak", "basaltoad", "puddlet"]
const AT := [-0.05, 0.05, 0.1, 0.2, 0.3, 0.6]       # s from the hit, left to right
const STEP := 1.0 / 60.0
const BIG := 0.35

var main: Node
var out := "/tmp/boki_flinch"
var px := 384

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	Save.no_write = true
	var all := Image.create(px * AT.size(), px * SPECIES.size(), false, Image.FORMAT_RGBA8)
	for i in SPECIES.size():
		var strip: Image = await _species(String(SPECIES[i]))
		strip.save_png(out.path_join("flinch_%s.png" % SPECIES[i]))
		all.blit_rect(strip, Rect2i(0, 0, strip.get_width(), px), Vector2i(0, i * px))
	all.save_png(out.path_join("flinch_all.png"))
	print("BOKI_FLINCH_SHOTS_DONE")
	main.get_tree().quit()

func _species(id: String) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	vp.add_child(env)
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"),
		"horizon": Color("ffd2a8"), "stars": 0.0})
	Look.lights(vp, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 24.0
	cam.position = Vector3(0, 0.95, 4.2)
	cam.look_at(Vector3(0, 0.45, 0))
	var k := Models.kin(id, {})
	vp.add_child(k)
	var pup: KinPuppet
	for c in k.get_children():
		if c is KinPuppet:
			pup = c
	var rig := k.get_node_or_null("Body/Flex/BokiRig") as BokiRig
	pup.set_process(false)
	if rig:
		rig.set_process(false)
	var strip := Image.create(px * AT.size(), px, false, Image.FORMAT_RGBA8)
	var hit := false
	var t0 := -0.6                     # s since the hit; starts before it, to settle into the idle
	for i in AT.size():
		var want: float = AT[i]
		while t0 < want:
			if not hit and t0 >= 0.0:
				hit = true
				KinFlinch.hit(k, Vector3(1, 0, 0), BIG, KinLib.kin(id).mass)
			_step(pup, rig)
			t0 += STEP
		for f in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
	vp.queue_free()
	return strip

func _step(pup: KinPuppet, rig: BokiRig) -> void:
	pup._process(STEP)
	if rig:
		rig.player.advance(STEP)
		rig._process(STEP)
