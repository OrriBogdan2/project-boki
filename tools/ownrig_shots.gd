extends "res://tools/warden_shots.gd"
## --ownrig-shots --shots-dir=<dir> --wardens=mage,dolm [--video=1]: own-rig test glbs (--warden-variant=...) in the game, per state:
## <dir>/<id>/<state>/<view>_<i>.jpg (6 frames; views game, eye, knee, close) and, with --video, <dir>/<id>/vid/<state>_<k>.jpg
## (eye view, 30 fps). Needs a renderer (jobq --needs gpu). Test tool for the own-rig round (not shipped).

const VIEWS := ["game", "eye", "knee", "close"]
const N_SHEET := 6
const FACE := PI * 0.82
var tall_override := 0.0

## A plain glb (a Meshy master) in the same stage and cameras: feet on the ground, uniformly scaled, turned like the hunters (3/4).
func _master_shots(path: String, mscale: float, tall: float, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path, st)
	print("OWNRIG master load ", path, " err ", err)
	var node := doc.generate_scene(st)
	var h := Node3D.new()
	holder.add_child(h)
	h.add_child(node)
	h.scale = Vector3.ONE * mscale
	h.rotation.y = -(PI - FACE)
	await _settle(5, false)
	var lo := 1e9
	for vi in h.find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		if not (v is Light3D):
			lo = minf(lo, (v.global_transform * v.get_aabb()).position.y)
	h.position.y = -lo
	await _settle(10, false)
	print("OWNRIG master top ", _top([h]), " tall ", tall)
	for v in VIEWS:
		var img := await _view(v, h, tall if tall > 0.0 else _top([h]))
		img.save_jpg(dir.path_join("%s_0.jpg" % v), 0.92)

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := "/tmp/ownrig"
	var wardens := ["mage", "dolm"]
	var video := false
	var only := ""
	var master := ""
	var mscale := 1.0
	var mname := "master"
	var tall_ov := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): wardens = Array(a.substr(10).split(","))
		if a == "--video": video = true
		if a.begins_with("--only="): only = a.substr(7)
		if a.begins_with("--master="): master = a.substr(9)
		if a.begins_with("--master-scale="): mscale = float(a.substr(15))
		if a.begins_with("--master-name="): mname = a.substr(14)
		if a.begins_with("--tall="): tall_ov = float(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(1280, 1280)
	_stage(main)
	tall_override = tall_ov
	if master != "":
		await _master_shots(master, mscale, tall_ov, out.path_join(mname))
		print("OWNRIG_SHOTS_DONE")
		tree.quit()
		return
	for id in wardens:
		await _hero_own(String(id), out.path_join(String(id)), video, only)
	print("OWNRIG_SHOTS_DONE")
	tree.quit()

func _states(id: String) -> Array:
	var km := {"mage": "mage_lmb_l", "dolm": "breah_punch", "archer": "arc_draw"}[id] as String
	var km2 := {"mage": "mage_lmb_r", "dolm": "breah_throw", "archer": "arc_loose"}[id] as String
	return [
		["idle", {}, 2.0, false],
		["walk", {"vel": 1.0}, 2.0, false],
		["run", {"vel": 1.0}, 2.0, false],
		["jump", {"air": true}, 1.0, false],
		["attack1", {"kmove": km}, _km_dur(km), true],
		["attack2", {"kmove": km2}, _km_dur(km2), true],
		["crouch_walk", {"crouch": 1.0, "vel": 1.0}, 2.0, false],
		["glide", {"glide": true}, 1.2, false],
	]

func _km_dur(mv: String) -> float:
	var d := HunterAnim.km_def(mv)
	if d.is_empty():
		return 1.0
	var keys: Array = d["keys"]
	return float(keys[keys.size() - 1][0])

func _state_dict(h: Node3D, st: Array, name: String, t: float) -> Dictionary:
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
	var base: Dictionary = st[1]
	if base.has("vel"):
		var sp := {"walk": 2.0, "run": 4.6, "crouch_walk": 1.2}.get(name, 2.0) as float
		s["vel"] = fwd * sp
	if base.has("crouch"):
		s["crouch"] = 1.0
	if base.has("air"):
		s["grounded"] = false
		s["vel"] = fwd * 3.0 + Vector3(0, 4.5 - 9.0 * t, 0)
		s["air_h"] = maxf(0.0, 0.55 * t * 4.5 - 4.5 * t * t) if t < 1.0 else 0.0
	if base.has("glide"):
		s["grounded"] = false
		s["gliding"] = true
		s["vel"] = fwd * 6.0 + Vector3(0, -1.4, 0)
		s["air_h"] = 6.0
	if base.has("kmove"):
		s["kmove"] = base["kmove"]
		s["kmove_t"] = t
	return s

func _hero_own(id: String, dir: String, video: bool, only: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var row := _row(id, 1)
	var h := row[0] as Node3D
	var an := anims[0][0] as HunterAnim
	h.rotation.y = FACE
	await _settle(30, false)
	var tall := 2.0
	await _settle(40)
	tall = maxf(_top(row), 1.6)
	if tall_override > 0.0:
		tall = tall_override
	print("OWNRIG %s height %.3f glb %s" % [id, tall, WardenGlb.path(id)])
	for st in _states(id):
		var nm := String(st[0])
		if only != "" and not (nm in only.split(",")):
			continue
		var dur: float = st[2]
		var frames := int(round(dur * 60.0))
		var one_shot: bool = st[3]
		var sd := dir.path_join(nm)
		DirAccess.make_dir_recursive_absolute(sd)
		# warm up (looping states run in first; a one-shot move starts at t 0)
		var t := 0.0
		if not one_shot:
			for k in 90:
				t += 1.0 / 60.0
				an.update(1.0 / 60.0, _state_dict(h, st, nm, fmod(t, dur) if st[1].has("air") else 0.0))
			t = 0.0
		var sheet_at: Array = []
		for i in N_SHEET:
			sheet_at.append(int(round((i + 0.5) * frames / float(N_SHEET))))
		var vk := 0
		for f in frames:
			t = f / 60.0
			an.update(1.0 / 60.0, _state_dict(h, st, nm, t))
			await tree.process_frame
			if video and f % 2 == 0:
				var vimg := await _view("eye", h, tall)
				DirAccess.make_dir_recursive_absolute(dir.path_join("vid"))
				vimg.save_jpg(dir.path_join("vid").path_join("%s_%03d.jpg" % [nm, vk]), 0.9)
				vk += 1
			if f in sheet_at:
				var si := sheet_at.find(f)
				for v in VIEWS:
					var img := await _view(v, h, tall)
					img.save_jpg(sd.path_join("%s_%d.jpg" % [v, si]), 0.92)
				print("OWNRIG %s %s frame %d/%d" % [id, nm, si, N_SHEET])
	_clear()

func _view(v: String, h: Node3D, tall: float) -> Image:
	var c := h.global_position
	cam.fov = 30.0
	match v:
		"game":
			var p := deg_to_rad(CAM_PITCH)
			cam.fov = CAM_FOV
			cam.position = c + Vector3(0, 1.0, 0) + Vector3(0, sin(p), cos(p)) * CAM_DIST
			cam.rotation = Vector3(-p, 0, 0)
		"eye":
			var d := (tall * 0.58) / tan(deg_to_rad(15.0))
			cam.position = c + Vector3(0, tall * 0.9, d)
			cam.look_at(c + Vector3(0, tall * 0.52, 0))
		"knee":
			var d2 := (tall * 0.6) / tan(deg_to_rad(15.0))
			cam.position = c + Vector3(0, 0.5, d2)
			cam.look_at(c + Vector3(0, tall * 0.5, 0))
		_:
			var d3 := (tall * 0.36) / tan(deg_to_rad(15.0))
			cam.position = c + Vector3(0, tall * 0.8, d3)
			cam.look_at(c + Vector3(0, tall * 0.72, 0))
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var hh := img.get_height()
	if v == "game":
		var a := cam.unproject_position(c + Vector3(-1.4, tall + 0.2, -1.0))
		var b := cam.unproject_position(c + Vector3(1.4, -0.2, 1.4))
		var crop := img.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		return crop
	var cw := int(hh * 0.75)
	return img.get_region(Rect2i((w - cw) / 2, 0, cw, hh))
