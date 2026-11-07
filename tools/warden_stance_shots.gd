extends RefCounted
## --warden-stance-shots --shots-dir=<dir> [--stance-at=<s>]: the 12 Wardens standing in their signature
## stances (WardenStance), for review. lineup_game.png: all 12 side by side at the match camera (the true
## pixels, then enlarged); lineup_close_<n>.png: four at a time close, three-quarter front and side on;
## before_after_<id>.png: a Warden with no stance (left pair) and in it (right pair), three-quarter and side.
## Shot after --stance-at seconds standing (3 by default, before any fidget). captions.txt gets one line
## per file. Needs a renderer.

const GAP := 2.2              # m between Wardens in a row (the heavies' weapons reach wide)
const CLOSE_N := 4            # Wardens per close strip
const GAME_COLS := 6          # the match-camera lineup: two rows of six
const ROW_GAP := 3.0          # m between those rows
const CAM_PITCH := 66.0       # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0
const CAM_FOV := 32.0
const ENLARGE := 2
const YAW_34 := -PI * 0.8     # three-quarter front, the weapon hand toward the camera
const YAW_SIDE := -PI * 0.5   # side on, facing right in the picture
const NAMES := {"gunslinger": "Vex", "rimewright": "Nivi", "dolm": "Kibo", "ashwick": "Cinder", "thief": "Sable",
	"juggernaut": "Kael", "archer": "Ravyl", "mage": "Ryzz", "tender": "Lumi", "bulwark": "Mossy",
	"dredge": "Grimble",
	"ostra": "Motley"}
const BEFORE_AFTER := ["gunslinger", "archer", "juggernaut"]

var holder: Node3D
var cam: Camera3D
var anims: Array = []
var tree: SceneTree
var out := ""
var at := 3.0
var caps: Array = []

func run(main: Node) -> void:
	tree = main.get_tree()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--stance-at="):
			at = float(a.substr(12))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	var ids := Arch.ids()
	await _lineup_game(ids)
	for part in range(0, ids.size(), CLOSE_N):
		await _lineup_close(ids.slice(part, part + CLOSE_N), part / CLOSE_N + 1)
	for id in BEFORE_AFTER:
		await _before_after(id)
	var f := FileAccess.open(out.path_join("captions.txt"), FileAccess.WRITE)
	f.store_string("\n".join(caps) + "\n")
	f.close()
	print("WARDEN_STANCE_SHOTS %d in %s" % [caps.size(), out])
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
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()

## Wardens in rows of `cols` (ids; stance false: with none), turned to yaw, standing for `at` seconds.
func _row(ids: Array, yaws: Array, stance: Array, cols := 0) -> void:
	cols = ids.size() if cols <= 0 else cols
	var rows := ceili(float(ids.size()) / cols)
	for i in ids.size():
		var id := String(ids[i])
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", {}, id)
		h.set_meta("anim_seed", 7)
		h.position = Vector3((i % cols - (cols - 1) * 0.5) * GAP, 0, (i / cols - (rows - 1) * 0.5) * ROW_GAP)
		h.rotation.y = float(yaws[i])
		holder.add_child(h)
		var a := HunterAnim.new(h)
		if not bool(stance[i]):
			a.ws = WardenStance.new("")
		anims.append([a, h])
	var n := int(at * 60.0)
	for k in n:
		for a in anims:
			var face := (a[1] as Node3D).rotation.y
			(a[0] as HunterAnim).update(1.0 / 60.0, {"fired": 99.0, "face": face, "grounded": true})
		if k % 20 == 0:
			await tree.process_frame

func _clear() -> void:
	for a in anims:
		(a[1] as Node3D).queue_free()
	anims.clear()

func _grab() -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _save(img: Image, file: String, caption: String) -> void:
	img.save_png(out.path_join(file))
	caps.append("%s: %s" % [file, caption])

func _names(ids: Array) -> String:
	return ", ".join(ids.map(func(id): return NAMES.get(id, id)))

func _lineup_game(ids: Array) -> void:
	await _row(ids, ids.map(func(_id): return YAW_34), ids.map(func(_id): return true), GAME_COLS)
	var p := deg_to_rad(CAM_PITCH)
	cam.fov = CAM_FOV
	cam.position = Vector3(0, 1.0, 0) + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	var img := await _grab()
	var a := cam.unproject_position((anims[0][1] as Node3D).position + Vector3(-1.7, 2.8, -1.4))
	var b := cam.unproject_position((anims[-1][1] as Node3D).position + Vector3(1.7, -0.2, 1.6))
	var crop := img.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
	var big := crop.duplicate() as Image
	big.resize(crop.get_width() * ENLARGE, crop.get_height() * ENLARGE, Image.INTERPOLATE_NEAREST)
	var both := Image.create(big.get_width(), crop.get_height() + big.get_height() + 8, false, Image.FORMAT_RGBA8)
	both.fill(Color("1c1a24"))
	both.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((both.get_width() - crop.get_width()) / 2, 0))
	both.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(0, crop.get_height() + 8))
	var cam_at := "the match camera (pitch %d, %d m, fov %d)" % [CAM_PITCH, CAM_DIST, CAM_FOV]
	_save(both, "lineup_game.png", "all 12 standing in their stances (two rows of six) at %s, " % cam_at
			+ "the true pixels on top, x%d below; left to right: %s" % [ENLARGE, _names(ids)])
	_clear()

## A few Wardens close: three-quarter front on top, side on below.
func _lineup_close(ids: Array, n: int) -> void:
	var rows: Array = []
	for yaw in [YAW_34, YAW_SIDE]:
		await _row(ids, ids.map(func(_id): return yaw), ids.map(func(_id): return true))
		rows.append(await _close(ids.size()))
		_clear()
	_save(_stack(rows), "lineup_close_%d.png" % n, "close, three-quarter front (top) and side on (bottom), "
			+ "standing %.0f s; left to right: %s" % [at, _names(ids)])

## A Warden with no stance and in it, three-quarter and side.
func _before_after(id: String) -> void:
	var ids := [id, id, id, id]
	await _row(ids, [YAW_34, YAW_SIDE, YAW_34, YAW_SIDE], [false, false, true, true])
	_save(await _close(4), "before_after_%s.png" % NAMES[id], "%s standing %.0f s: no stance (left pair, the old "
			% [NAMES[id], at] + "upright idle) and the signature stance (right pair), three-quarter and side on")
	_clear()

func _close(count: int) -> Image:
	var span := (count - 1) * GAP + 2.8
	cam.fov = 30.0
	var half_w := atan(tan(deg_to_rad(cam.fov * 0.5)) * 16.0 / 9.0)
	cam.position = Vector3(0, 1.1, span * 0.5 / tan(half_w))
	cam.rotation = Vector3(-0.03, 0, 0)
	var img := await _grab()
	var top := maxi(int(cam.unproject_position(Vector3(0, 2.9, 0)).y), 0)
	var bottom := mini(int(cam.unproject_position(Vector3(0, -0.12, 0.6)).y), img.get_height())
	return img.get_region(Rect2i(0, top, img.get_width(), bottom - top))

func _stack(imgs: Array) -> Image:
	var h := 0
	for im in imgs:
		h += (im as Image).get_height()
	var outimg := Image.create((imgs[0] as Image).get_width(), h, false, Image.FORMAT_RGBA8)
	var y := 0
	for im in imgs:
		outimg.blit_rect(im, Rect2i(Vector2i.ZERO, (im as Image).get_size()), Vector2i(0, y))
		y += (im as Image).get_height()
	return outimg
