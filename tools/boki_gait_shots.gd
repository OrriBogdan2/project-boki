extends RefCounted
## --boki-gait-shots --shots-dir=<dir> [--species=a,b,c]: a strip of each species' home walk (top) and match run
## (bottom) from the side, at the playback speed BokiRig.play_scale picks. Lines lie on the ground every 0.25 m and the
## camera follows the Boki: a foot that is down stays on its line. <dir>/gait_<species>.png. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Gait := preload("res://tools/boki_gait_check.gd")
const FRAMES := 6
const DT := 0.12              # s between frames
const CELL := Vector2i(280, 190)
const VIEW := 1.25            # m seen across a frame
const LINE_GAP := 0.25        # m between the lines on the ground

func run(main: Node) -> void:
	var out := ""
	var ids: Array = BokiRig.FRAME.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): ids = Array(a.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	main.fade.reveal(0.01)
	var shots := Shots.new()
	shots.main = main
	var vp := shots._stage(CELL)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW * CELL.y / CELL.x
	for i in 12:
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.008, 3.0)
		line.mesh = box
		line.material_override = Models.toon(Color("23361d"), false)
		line.position = Vector3(i * LINE_GAP - 1.0, 0.004, 0)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vp.add_child(line)
	for id in ids:
		var sheet := Image.create(CELL.x * FRAMES, CELL.y * 2, false, Image.FORMAT_RGBA8)
		var k := Shots.rigged_kin(String(id))
		vp.add_child(k)
		k.rotation.y = -PI * 0.5
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		rig.manual = true
		var points := KinLib.points(KinLib.kin(id), {})
		var speeds := {"walk": Gait.HOME_WALK, "run": KinLib.stat_value("kin_speed", points)}
		for row in 2:
			var clip := "walk" if row == 0 else "run"
			var speed: float = speeds[clip]
			rig.set_clip(clip, 0.0)
			for f in FRAMES:
				var t := f * DT
				k.position.x = speed * t
				var at := t * BokiRig.play_scale(String(id), clip, speed)
				rig.seek(fposmod(at, rig.player.get_animation(clip).length))
				cam.position = Vector3(k.position.x, 0.3, 4.0)
				for n in 3:
					await RenderingServer.frame_post_draw
				var frame := vp.get_texture().get_image()
				frame.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i(f * CELL.x, row * CELL.y))
		sheet.save_png("%s/gait_%s.png" % [out, id])
		k.queue_free()
	print("BOKI_GAIT_SHOTS_DONE")
	main.get_tree().quit()
