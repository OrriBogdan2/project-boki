extends RefCounted
## --boki-anim-shots --shots-dir=<dir> --boki=a,b [--tag=after] [--old-rate]: side-view strips of a rigged Boki's
## walk and run through its real locomotion (the audit's drive), seen from the side with posts standing on the floor
## so a sliding foot slides against them: <dir>/<id>_<tag>.png, one row per speed. --old-rate plays the clip rate
## BokiRig had before GAIT (speed over 1.5 and 2.9 m/s, at most 1.6x), for the before strip. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Audit := preload("res://tools/boki_anim_audit.gd")
const DT := 1.0 / 30.0
const WARM_S := 0.8
const SPEEDS := [2.4, 6.5]       # m/s: a home wander, a match Boki
const FRAMES := 8
const FRAME_S := 0.1             # s between the frames of a strip
const PX := 256
const POST_SPACING := 0.4        # m between floor posts
const POST_COUNT := 60

func run(main: Node) -> void:
	var out := ""
	var ids: Array = []
	var tag := "after"
	var old_rate := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--boki="): ids = Array(a.substr(7).split(",", false))
		if a.begins_with("--tag="): tag = a.substr(6)
		if a == "--old-rate": old_rate = true
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
		var sheet := Image.create(PX * FRAMES, PX * SPEEDS.size(), false, Image.FORMAT_RGBA8)
		for row in SPEEDS.size():
			await _row(vp, cam, String(id), SPEEDS[row], old_rate, sheet, row)
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

func _row(vp: SubViewport, cam: Camera3D, id: String, v: float, old_rate: bool, sheet: Image, row: int) -> void:
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
		if old_rate:
			Audit.old_rate_scale(rig)
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
