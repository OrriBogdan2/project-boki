extends RefCounted
## --boki-anim-shots --shots-dir=<dir> --boki=a,b [--tag=after]: side-view strips of a rigged Boki moving through
## the live BokiRig (it reads its own speed, picks the clip and rate), over floor bars 0.4 m apart so a sliding
## foot slides against them: <dir>/<id>_<tag>.png, one row per speed (a home wander, then its match speed).
## For a before strip, run the same tool on the old tree. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const DT := 1.0 / 30.0
const WARM_S := 0.8
const WANDER := 2.4             # m/s: a home wander (home.gd); the second row is the species' match speed
const FRAMES := 8
const FRAME_S := 0.1             # s between the frames of a strip
const PX := 256
const POST_SPACING := 0.4        # m between floor posts
const POST_COUNT := 60

func run(main: Node) -> void:
	var out := ""
	var ids: Array = []
	var tag := "after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--boki="): ids = Array(a.substr(7).split(",", false))
		if a.begins_with("--tag="): tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var shots := Shots.new()
	shots.main = main
	var vp: SubViewport = shots._stage(Vector2i(PX, PX))
	_posts(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 26.0
	for id in ids:
		var ks := KinLib.kin(String(id))
		var speeds := [WANDER, KinLib.stat_value("kin_speed", KinLib.points(ks, {}) if ks else {})]
		var sheet := Image.create(PX * FRAMES, PX * speeds.size(), false, Image.FORMAT_RGBA8)
		for row in speeds.size():
			await _row(vp, cam, String(id), speeds[row], sheet, row)
		sheet.save_png(out.path_join("%s_%s.png" % [id, tag]))
	print("BOKI_ANIM_SHOTS_DONE ", ids.size())
	main.get_tree().quit()

func _posts(vp: SubViewport) -> void:
	var mat := Models.toon(Color("1c2a14"), false)
	for i in POST_COUNT:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.02, 0.04)
		post.mesh = box
		post.material_override = mat
		post.position = Vector3(0, 0.011, -i * POST_SPACING + 2.0)
		vp.add_child(post)

func _row(vp: SubViewport, cam: Camera3D, id: String, v: float, sheet: Image, row: int) -> void:
	var k := Shots.rigged_kin(id)
	vp.add_child(k)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.set_process(false)
	rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	k.position = Vector3.ZERO
	rig._pos_prev = k.global_position
	var steps := int(round(FRAME_S / DT))
	for i in int(WARM_S / DT) + steps * FRAMES:
		k.position.z -= v * DT
		rig._process(DT)
		rig.player.advance(DT)
		cam.position = k.position + Vector3(3.0, 0.45, 0)
		cam.look_at(k.position + Vector3(0, 0.3, 0))
		var f := i - int(WARM_S / DT)
		if f >= 0 and f % steps == steps - 1:
			for n in 3:
				await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, PX, PX), Vector2i((f / steps) * PX, row * PX))
	k.queue_free()
