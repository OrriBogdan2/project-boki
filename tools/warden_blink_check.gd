extends RefCounted
## --warden-blink-check: the close-up blink (WardenBlink, warden_anim/<art>.json "blink"). Every art/wardens .glb with
## lid bones has a blink; on each Hero that blinks, the lids reach closed and come all the way off again (hidden), a
## double blink shuts twice, the gap is 2-6 s, and with the camera past the far-camera distance there is no blink,
## nothing runs per frame and no lid is drawn.
## --warden-blink-shots --shots-dir=<dir>: a straight-on close-up of each Hero that blinks, open (left) and closed
## (right), blink_<art>.png; each closed frame must differ from its open one. Prints each shot's frame in the model's
## bind space ("frame"), to place the eyes from. Needs a renderer. Never touches the save.

const DT := 1.0 / 60.0
const CLOSE_M := 1.1            # m from the face to the close-up camera
const FAR_M := WardenGlb.FAR_HIDE_D + 0.5
const SHOT_M := 0.26            # m of the bind-space face a shot frames, top to bottom
const SHOT_PX := 200            # pixels the closed frame must change, at least (a lid is ~1000 at 720 p)

var bad := 0
var holder: Node3D
var cam: Camera3D

func ok(cond: bool, what: String) -> void:
	print("BLINK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node, mode := "check") -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
	if mode == "shots":
		await _shots(main)
		return
	_scan()
	for id in WardenGlb.ART:
		if not (WardenClips.data(String(WardenGlb.ART[id])).get("blink", {}) as Dictionary).is_empty():
			_hero(String(id))
	print("WARDEN_BLINK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Every .glb with lid bones blinks.
func _scan() -> void:
	var none: Array = []
	for art_name in DirAccess.get_directories_at(WardenGlb.DIR):
		var p := "%s/%s/%s.glb" % [WardenGlb.DIR, art_name, art_name]
		if not ResourceLoader.exists(p):
			continue
		var glb := (load(p) as PackedScene).instantiate() as Node3D
		var sk := WardenGlb.skeleton(glb)
		var lids: Array = []
		for bi in sk.get_bone_count():
			if sk.get_bone_name(bi).begins_with("lid"):
				lids.append(sk.get_bone_name(bi))
		glb.free()
		var eyes: Array = (WardenClips.data(art_name).get("blink", {}) as Dictionary).get("eyes", [])
		if lids.is_empty():
			none.append(art_name)
		else:
			ok(not eyes.is_empty(), "%s: lid bones %s, %d eyes blink" % [art_name, str(lids), eyes.size()])
	print("BLINK no lid bones (docs/art/wardens/BLINK.md): ", ", ".join(none))

func _model(id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	return m

static func _blink(m: Node3D) -> WardenBlink:
	return WardenGlb.skeleton(m.get_node("Warden")).get_node_or_null("Blink") as WardenBlink

## The model's bind space -> the world, on the head's current pose.
static func _bind_to_world(b: WardenBlink) -> Transform3D:
	return b.skel.global_transform * b.skel.get_bone_global_pose(b.head) * b.unbind

static func _lids_shown(b: WardenBlink) -> int:
	return b.lids.filter(func(d): return (d as Decal).visible).size()

func _hero(id: String) -> void:
	var art_name := String(WardenGlb.ART[id])
	var m := _model(id)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var blink := _blink(m)
	var want: int = (WardenClips.data(art_name)["blink"]["eyes"] as Array).size()
	ok(blink != null and blink.lids.size() == want, "%s: a lid on each of %d eyes" % [art_name, want])
	if blink == null:
		m.free()
		return
	ok(not blink.is_processing() and _lids_shown(blink) == 0 and blink.timer.wait_time >= WardenBlink.EVERY.x \
			and blink.timer.wait_time <= WardenBlink.EVERY.y, "%s: asleep, no lid drawn, next blink in %.1f s" % [
			art_name, blink.timer.wait_time])
	var eye := _bind_to_world(blink) * (blink.eyes[0] as Vector3)
	cam.position = eye + Vector3(0, 0, -FAR_M)
	blink._due()
	ok(not blink.near() and not blink.is_processing() and _lids_shown(blink) == 0,
			"%s: no blink %.1f m away (far camera)" % [art_name, FAR_M])
	cam.position = eye + Vector3(0, 0, -CLOSE_M)
	ok(blink.near(), "%s: near at %.1f m" % [art_name, CLOSE_M])
	for times in [1, 2]:
		blink.start(times)
		var shut := 0
		var was_shut := false
		var frames := 0
		while blink.is_processing() and frames < 120:
			sync._process(DT)
			blink._process(DT)
			frames += 1
			var all_shut := blink.shut_k >= 1.0 and _lids_shown(blink) == want \
					and blink.lids.all(func(d): return is_equal_approx((d as Decal).size.z, blink.eye_size.y))
			if all_shut and not was_shut:
				shut += 1
			was_shut = all_shut
		var open_end := blink.shut_k == 0.0 and _lids_shown(blink) == 0
		var want_t: float = WardenBlink.SHUT_T * times + WardenBlink.GAP_T * (times - 1)
		ok(shut == times and open_end and absf(frames * DT - want_t) < 2.5 * DT,
				"%s: %d blink(s) shut %d times, fully open after %.2f s (want %.2f)" % [art_name, times, shut,
				frames * DT, want_t])
	m.free()

func _shots(main: Node) -> void:
	var tree := main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-30, 160, 0), 40.0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var made := 0
	for id in WardenGlb.ART:
		var art_name := String(WardenGlb.ART[id])
		if (WardenClips.data(art_name).get("blink", {}) as Dictionary).is_empty():
			continue
		var m := _model(id)
		var blink := _blink(m)
		blink.timer.stop()
		for i in 30:
			await tree.process_frame
		Engine.time_scale = 0.0
		# straight at the face, from in front of the eyes (bind space: the face looks along -Z)
		var mid := Vector3.ZERO
		for e in blink.eyes:
			mid += e / blink.eyes.size()
		var w := _bind_to_world(blink)
		cam.look_at_from_position(w * (mid + Vector3(0, 0, -CLOSE_M)), w * mid, w.basis * Vector3.UP)
		cam.size = SHOT_M * w.basis.get_scale().y
		var open_img := await _grab(tree)
		blink.pose(1.0)
		var shut_img := await _grab(tree)
		blink.pose(0.0)
		Engine.time_scale = 1.0
		var px := _changed(open_img, shut_img)
		print("BLINK frame %s: middle %s, %.3f m tall over %d px (the image's right is the model's -X)" % [art_name,
				str(mid), SHOT_M, open_img.get_height()])
		var pair := Image.create(open_img.get_width() * 2, open_img.get_height(), false, Image.FORMAT_RGBA8)
		pair.blit_rect(open_img, Rect2i(Vector2i.ZERO, open_img.get_size()), Vector2i.ZERO)
		pair.blit_rect(shut_img, Rect2i(Vector2i.ZERO, shut_img.get_size()), Vector2i(open_img.get_width(), 0))
		pair.save_png(out.path_join("blink_%s.png" % art_name))
		ok(px >= SHOT_PX, "%s: blink_%s.png (open | closed), %d px change" % [art_name, art_name, px])
		made += 1
		m.free()
	print("WARDEN_BLINK_SHOTS %d in %s, failures: %d" % [made, out, bad])
	tree.quit(1 if bad > 0 else 0)

## How many pixels differ visibly between two frames.
static func _changed(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			if absf(d.r) + absf(d.g) + absf(d.b) > 0.1:
				n += 1
	return n

func _grab(tree: SceneTree) -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
