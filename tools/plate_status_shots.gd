extends "res://tools/vv_shots.gd"
## --plate-status-shots --shots-dir=<dir>: the plate status row (HudPlate.row) at 1280x720 at the match camera. Needs
## a renderer (jobq submit --needs gpu). Sable faces three rivals: one stunned, rooted, Grounded and Dazed with her
## Marks on (four shown: stun, root, Ground, Marks), one with her Marks and a Slow, one Grounded alone. A full frame
## as the statuses go on and one a second later (the rings shrunk), plate_status_<when>.png, and a 2x crop of each
## rival's plate and row side by side, plate_status_close_<when>.png.

const CROP := Vector2i(300, 72)          # px round a plate and its row, from LEFT_OF/ABOVE the plate's anchor
const LEFT_OF := 70                      # px of the crop left of the anchor (the row runs right of the plate)
const ABOVE := 28                        # px of the crop above the anchor (the name or status word)
const SPOTS := [Vector3(6, 0, -1.5), Vector3(10, 0, 1.0), Vector3(6, 0, 3.8)]   # m from home, under the arena card
const NAMES := ["Brask", "Ivo", "Wren"]

var rivals: Array = []

func run(main_node: Node) -> void:
	main = main_node
	who = "thief"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	rivals = [T]
	for i in range(1, SPOTS.size()):
		rivals.append(m.make_hunter("R%d" % i, 5, "medium", NAMES[i], "idle", {}, home, {"arch": "none"}))
	T.pname = NAMES[0]
	for i in rivals.size():
		var r: Hunter = rivals[i]
		r.teleport(home + SPOTS[i])
		r.reveal_t = 1e6
	_put_on()
	await _go(0.1)
	_grab("fresh")
	await _go(1.0)
	_grab("later")
	print("PLATESTATUSSHOTS 4 in %s" % dir)
	main.get_tree().quit(0)

## Keeps the three rivals in place; anyone else stays parked far off.
func _park_others() -> void:
	for x in m.hunters:
		if x != P and not rivals.has(x) and x.flat_dist(P) < 26.0:
			x.teleport(home + Vector3(-30, 0, 30))
			x.vel = Vector3.ZERO

func _put_on() -> void:
	var K := P.ak as ThiefKit
	var a: Hunter = rivals[0]
	a.stun_t = 2.5
	a.root_t = 2.0
	KitStatus.apply(a, "gnd", 3.0, 0.0, false, "shots")
	KitStatus.apply(a, "rat", 3.0, 0.0, false)
	K.add_mark(a, 3, true)
	var b: Hunter = rivals[1]
	K.add_mark(b, 2, true)
	b.slow_k = 0.3
	b.slow_t = 3.0
	KitStatus.apply(rivals[2], "gnd", 3.0, 0.0, false, "shots")

func _grab(when: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("plate_status_%s.png" % when))
	var file := "plate_status_close_%s.png" % when
	strips[file] = []
	var rows: Array = []
	for r in rivals:
		(strips[file] as Array).append(_plate_crop(img, r))
		var row: Array = (m.hud.plates.shown.get(r.nid, {}) as Dictionary).get("row", [])
		rows.append(row.map(func(it): return "%s %.1f/%.1f" % [it["icon"], it["left"], it["total"]]))
	_save_strip(file)
	print("PLATESTATUSSHOT %s %dx%d rows %s" % [when, img.get_width(), img.get_height(), rows])

func _plate_crop(img: Image, r: Hunter) -> Image:
	var cam := main.get_viewport().get_camera_3d()
	var anchor := r.position + m.cam.char_lean() * Vector3(0, HudPlate.plate_offset(r), 0)   # as Hud._head
	var sp := cam.unproject_position(anchor)
	var x := clampi(int(sp.x) - LEFT_OF, 0, img.get_width() - CROP.x)
	var y := clampi(int(sp.y) - ABOVE, 0, img.get_height() - CROP.y)
	var crop := img.get_region(Rect2i(Vector2i(x, y), CROP))
	crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_BILINEAR)
	return crop
