extends RefCounted
## --look-at-shots --shots-dir=<dir>: the head's look-at layer (WardenLookAt) before and after, for review. One
## strip per Hunter (look_at_<name>.png): the cursor swings SWING degrees across the camera and the body turns to it
## as in a match; the columns are the frames in FRAMES after the swing (60 Hz). Top row: no look-at (the head turns
## with the body, as a block). Bottom row: the layer on (the head is on the aim first, the body catches up).
## captions.txt gets one line per file. Needs a renderer.

const DT := 1.0 / 60.0
const HUNTERS := {"gunslinger": "Vex", "archer": "Lace", "juggernaut": "Kael", "mage": "Sparkle"}
const FRAMES := [0, 1, 2, 4, 6, 8]     # frames after the cursor's swing, one column each
const SWING := deg_to_rad(150.0)       # rad: the swing, centred on the camera
const SETTLE := 90                     # frames standing before it
const GAP := 2.2                       # m between the columns
const CAM_TILT := 0.3                  # rad: the camera looks down this much, so a head's turn reads
const CAM_FOV := 30.0                  # degrees

var holder: Node3D
var cam: Camera3D
var tree: SceneTree
var out := ""
var caps: Array = []
var shown: Array = []          # the row's models

func run(main: Node) -> void:
	tree = main.get_tree()
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)      # the boot splash stays up until it is gone (else the first strip is the logo)
	_stage(main)
	for id in HUNTERS:
		var rows: Array = []
		for looking in [false, true]:
			_row(String(id), looking)
			rows.append(await _grab())
			_clear()
		var file := "look_at_%s.png" % String(HUNTERS[id]).to_lower()
		_stack(rows).save_png(out.path_join(file))
		caps.append("%s: %s, a %d degree cursor swing; columns: frames %s after it (60 Hz); top: before (no "
				% [file, HUNTERS[id], roundi(rad_to_deg(SWING)), str(FRAMES)] + "look-at), bottom: after")
	var f := FileAccess.open(out.path_join("captions.txt"), FileAccess.WRITE)
	f.store_string("\n".join(caps) + "\n")
	f.close()
	print("LOOK_AT_SHOTS %d in %s" % [caps.size(), out])
	tree.quit()

func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 60)
	ground.mesh = plane
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
	var span := (FRAMES.size() - 1) * GAP + 2.8
	cam.fov = CAM_FOV
	var half_w := atan(tan(deg_to_rad(CAM_FOV * 0.5)) * 16.0 / 9.0)
	var dist := span * 0.5 / tan(half_w)
	cam.position = Vector3(0, 1.1 + dist * sin(CAM_TILT), dist * cos(CAM_TILT))
	cam.rotation = Vector3(-CAM_TILT, 0, 0)

## One Hunter per column, each stepped to its column's frame of the swing.
func _row(id: String, looking: bool) -> void:
	for i in FRAMES.size():
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", {}, id)
		h.set_meta("anim_seed", 7)
		h.position = Vector3((i - (FRAMES.size() - 1) * 0.5) * GAP, 0, 0)
		holder.add_child(h)
		shown.append(h)
		var sync := h.get_node_or_null("Warden/Sync") as WardenGlb.Sync
		if sync:
			sync.set_process(false)
		var anim := HunterAnim.new(h)
		var face := PI - SWING * 0.5       # (PI: toward the camera)
		for f in SETTLE:
			_pose(h, anim, sync, face, face, looking)
		for f in int(FRAMES[i]):
			face = rotate_toward(face, PI + SWING * 0.5, HunterMove.turn_rate * DT)
			_pose(h, anim, sync, face, PI + SWING * 0.5, looking)

func _pose(h: Node3D, anim: HunterAnim, sync: WardenGlb.Sync, face: float, aim_yaw: float, looking: bool) -> void:
	var s := {"fired": 99.0, "face": face, "grounded": true}
	if looking:
		s[WardenLookAt.LOOK] = Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	h.rotation.y = face
	anim.update(DT, s)
	if sync:
		sync._process(DT)

func _clear() -> void:
	for h in shown:
		(h as Node3D).queue_free()
	shown.clear()

## The row on screen, cut to the Hunters' height.
func _grab() -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var top := maxi(int(cam.unproject_position(Vector3(0, 2.9, 0)).y), 0)
	var bottom := mini(int(cam.unproject_position(Vector3(0, -0.12, 0.6)).y), img.get_height())
	return img.get_region(Rect2i(0, top, img.get_width(), bottom - top))

func _stack(imgs: Array) -> Image:
	var first: Image = imgs[0]
	var all := Image.create(first.get_width(), first.get_height() * imgs.size(), false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var img: Image = imgs[i]
		all.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, first.get_height() * i))
	return all
