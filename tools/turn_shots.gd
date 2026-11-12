extends "res://tools/clip_shots.gd"
## --turn-shots --shots-dir=<dir> [--wardens=a,b] [--size=224]: the before/after strip of turning on the spot
## (TurnStep, WardenTurn), <dir>/turn_in_place.jpg. Per Hunter (the slice four unless --wardens) two rows, the step
## layer off (the body spins on its feet) then on: a frame every STEP s while the standing aim swings 180° at the
## body's turn rate and the feet settle, from a fixed camera above the side on the legs; pale marks show where the
## feet stood. Needs a renderer.

const FILM := 1.6             # s filmed from the swing's start (the heaviest step settles by ~1.45 s)
const STEP := 0.2             # s between frames
const DT := 1.0 / 60.0
const MARK_R := 0.08          # m: the ground mark under a foot

var sheet: Image

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["gunslinger", "juggernaut", "archer", "ashwick"]
	frame_px = 224
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		await main.fade.reveal(0.01)       # (the boot logo fades out first)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 32.0
	cam.position = Vector3(1.3, 2.1, 2.0)
	cam.look_at(Vector3(0, 0.5, 0))
	sheet = Image.create(ceili(FILM / STEP) * frame_px, ids.size() * 2 * frame_px, false, Image.FORMAT_RGB8)
	for r in ids.size():
		for step_on in [false, true]:
			await _hunter(String(ids[r]), r * 2 + int(step_on), step_on)
	DirAccess.make_dir_recursive_absolute(out)
	sheet.save_jpg(out.path_join("turn_in_place.jpg"), 0.8)
	print("TURN_SHOTS_DONE ", ids.size())
	tree.quit()

## One row of the sheet: standing 0.6 s, then the 180° swing, a frame every STEP s.
func _hunter(id: String, row: int, step_on: bool) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var feet := clips.turn
	if not step_on:
		clips.turn = null
	var marks := Node3D.new()
	holder.add_child(marks)
	var face := 0.0
	var t := -0.6
	var i := 0
	while i < sheet.get_width() / frame_px:
		if t > 0.0:
			face = minf(face + HunterMove.turn_rate * DT, PI)
		elif t + DT > 0.0 and feet:
			_marks(feet, marks)
		model.rotation.y = face
		anim.update(DT, {"vel": Vector3.ZERO, "face": face, "grounded": true, "fired": 99.0})
		sync.call("_process", DT)
		if t >= i * STEP - 0.0001:
			await RenderingServer.frame_post_draw
			var img := tree.root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * frame_px, row * frame_px))
			i += 1
		t += DT
	model.queue_free()
	marks.queue_free()
	await tree.process_frame

## A pale disc on the ground under each ankle where it stands now.
func _marks(feet: WardenTurn, under: Node3D) -> void:
	for f in 2:
		var at := feet.skel.global_transform * feet.ankle(f)
		var disc := CylinderMesh.new()
		disc.top_radius = MARK_R
		disc.bottom_radius = MARK_R
		disc.height = 0.004
		var mark := MeshInstance3D.new()
		mark.mesh = disc
		mark.material_override = Models.toon(Color("f2e6c4"), false)
		mark.position = Vector3(at.x, 0.002, at.z)
		under.add_child(mark)
