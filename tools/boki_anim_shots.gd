extends RefCounted
## --boki-anim-shots --shots-dir=<dir> --boki=a,b [--tag=after]: side-view strips of a rigged Boki moving through
## the live BokiRig (it reads its own speed, picks the clip and rate), over floor bars 0.4 m apart so a sliding
## foot slides against them: <dir>/<id>_<tag>.png, one row per speed (a home wander, then its match speed).
## --seam=<clip>[,<clip>] instead (one per --boki id, the last repeats): one row at the garden camera, a frame each
## 1/30 s across the clip's loop wrap, played in place; "setoff": the Boki stands, then sets off at a stroll (the
## idle-to-walk hand-over). <dir>/<id>_<clip>_<tag>.png.
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
const SEAM_FRAMES := 10
const SEAM_PX := 224             # crop around the Boki at the garden camera, of a 1920x1080 view
const STROLL := 1.5              # m/s: the audit's idle-to-walk speed (boki_anim_audit HOME_SPEEDS[0])

func run(main: Node) -> void:
	var out := ""
	var ids: Array = []
	var tag := "after"
	var seams: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seam="): seams = Array(a.substr(7).split(",", false))
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--boki="): ids = Array(a.substr(7).split(",", false))
		if a.begins_with("--tag="): tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var shots := Shots.new()
	shots.main = main
	if not seams.is_empty():
		for i in ids.size():
			var what := String(seams[mini(i, seams.size() - 1)])
			var row: Image = await _seam(shots, String(ids[i]), what)
			row.save_png(out.path_join("%s_%s_%s.png" % [ids[i], what, tag]))
		print("BOKI_ANIM_SHOTS_DONE ", ids.size())
		main.get_tree().quit()
		return
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
	k.position = Vector3.ZERO
	rig._pos_prev = k.global_position
	var steps := int(round(FRAME_S / DT))
	for i in int(WARM_S / DT) + steps * FRAMES:
		k.position.z -= v * DT
		rig._process(DT)
		rig.advance(DT)
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

## One row at the garden camera (Shots' farm close-up): frames DT apart across `what`'s wrap, or the set-off.
func _seam(shots: Shots, id: String, what: String) -> Image:
	var vp: SubViewport = shots._stage(Vector2i(1920, 1080))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = Shots.MATCH_FOV
	var pitch := deg_to_rad(Shots.MATCH_PITCH)
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * Shots.FARM_CLOSE_DIST
	cam.rotation = Vector3(-pitch, 0, 0)
	var k := Shots.rigged_kin(id)
	vp.add_child(k)
	var facing := Basis(Vector3.UP, PI * 0.6)
	k.basis = Basis(Vector3.RIGHT, -Shots.LEAN) * facing * Basis.from_scale(Vector3.ONE * Shots.FARM_BOKI_SCALE)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.set_process(false)
	rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lead := int(WARM_S / DT)
	if what == "setoff":
		rig._pos_prev = k.global_position
	else:
		rig.set_clip(what, 0.0)
		rig.player.seek(rig.player.get_animation(what).length - SEAM_FRAMES / 2 * DT, true)
		lead = 0
	var sheet := Image.create(SEAM_PX * SEAM_FRAMES, SEAM_PX, false, Image.FORMAT_RGBA8)
	for i in lead + SEAM_FRAMES:
		if what == "setoff":
			if i >= lead:
				k.position += facing * Vector3.FORWARD * STROLL * DT
			rig._process(DT)
		rig.player.advance(DT)
		if i < lead:
			continue
		var img: Image = await shots._grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		var mid := Vector2i(cam.unproject_position(k.position + Vector3(0, 0.5 * Shots.FARM_BOKI_SCALE, 0)))
		var at := mid - Vector2i(SEAM_PX, SEAM_PX) / 2
		sheet.blit_rect(img, Rect2i(at, Vector2i(SEAM_PX, SEAM_PX)), Vector2i((i - lead) * SEAM_PX, 0))
	vp.queue_free()
	return sheet
