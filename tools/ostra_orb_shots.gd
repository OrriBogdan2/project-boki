extends "res://tools/vv_shots.gd"
## --ostra-orb-shots --shots-dir=<dir>: items 60 and 117's review shots in a live Arena match (xvfb with a renderer),
## on the Ryzz/Vex shot rig. Strips crop round the orb (or Motley, for the glow) at gameplay zoom;
## <dir>/MANIFEST_ostra.txt gets one line per file. The rock row is a real blocking row with a box drawn on it.

const ROW_X := 4.0           # m east of Ostra: the rock row
const ORB_CROP := Vector2i(200, 150)       # px round the orb per strip frame (scaled 2x)

var K: OstraKit

func run(main_node: Node) -> void:
	main = main_node
	who = "ostra"
	hero_name = "ostra"
	tag = "kits/ostra"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	K = P.ak
	await _quick_vs_full()
	await _glow()
	await _impacts()
	_rock_row()
	await _through_wall()
	var f := FileAccess.open(dir.path_join("MANIFEST_ostra.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("OSTRAORBSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _orb_at() -> Vector3:
	var mine: Array = m.shots.filter(func(s): return s["by"] == P)
	return (mine[-1]["pos"] as Vector3) if not mine.is_empty() else P.position + Vector3(0, 0.9, 0)

## Strips crop round `focus`; "full" stays the rig's whole view plus close-up.
func _take(kind: String, file: String, caption: String, focus: Callable) -> void:
	if kind == "full":
		super._take(kind, file, caption, focus)
		return
	var img := main.get_viewport().get_texture().get_image()
	var crop := _crop(img, focus.call(), ORB_CROP, 2.0)
	var strip_file := "%s_%s.png" % [hero_name, kind]
	if not strips.has(strip_file):
		strips[strip_file] = []
		lines.append("%s/%s|%s|%s" % [hero_name, tag, strip_file, caption])
	(strips[strip_file] as Array).append(crop)
	_save_strip(strip_file)

## Fires one orb `wait` s after the last and plays on for `secs`, taking `marks`.
func _shot(wait: float, secs: float, marks: Array, each := Callable()) -> void:
	var shots0 := P.shot_n
	K.last_shot_t = m.time - wait
	K._set_charge(K.wait_charge())
	P.fire_cd = 0.0
	var tick := func(_t):
		P.inp["fire"] = P.shot_n == shots0
		if each.is_valid(): each.call()
	await _go(secs, tick, marks, 3.0)
	P.inp["fire"] = false

func _quick_vs_full() -> void:
	var file := "orb_quick_vs_full"
	var cap := "The same moment after the shot: a quick orb (0.6s wait), halfway (1.0s), full (1.4s, x1.9 size and hit)"
	await _reset(11.0, 3.0)
	_aim(home + Vector3(8.0, 0, 0))
	for w in [0.6, 1.0, 1.4]:
		await _shot(w, 0.5, [[0.14, file, file, cap, _orb_at]])
	await _reset(11.0, 3.0)
	_aim(home + Vector3(8.0, 0, 0))
	await _shot(1.4, 0.5, [[0.14, "full", "orb_full", "A full orb at gameplay zoom", _orb_at]])
	await _reset(11.0, 3.0)
	_aim(home + Vector3(8.0, 0, 0))
	await _shot(0.6, 0.5, [[0.14, "full", "orb_quick", "A quick orb at gameplay zoom", _orb_at]])
	for w in [0.6, 1.4]:
		await _reset(11.0, 3.0)
		_aim(home + Vector3(8.0, 0, 0))
		var px := [0.0]
		var shots0 := P.shot_n
		await _shot(w, 0.3, [], func(): px[0] = maxf(px[0], _orb_px() if P.shot_n > shots0 else 0.0))
		print("ORBPX wait %.1f: %.1f px wide at the match camera" % [w, px[0]])

## The orb's drawn width at the match camera, in screen pixels.
func _orb_px() -> float:
	var at := _orb_at()
	var cam := main.get_viewport().get_camera_3d()
	var mine: Array = m.shots.filter(func(s): return s["by"] == P)
	var r := float(mine[-1]["r"]) if not mine.is_empty() else 0.0
	return cam.unproject_position(at + cam.global_transform.basis.x * r).distance_to(cam.unproject_position(at)) * 2.0

## Quick and full on a dummy, a moment after the hit: the impact grows with the charge too.
func _impacts() -> void:
	var file := "orb_impact"
	var cap := "The impact on the dummy, three frames from the hit: a quick orb, then a full one"
	for row in [[0.6, 30.0], [1.4, 42.0]]:
		await _reset(5.0)
		_aim(T.position)
		var hit_t := (5.0 - float(T.r) - 0.6) / float(row[1])
		var marks: Array = []
		for after in [0.0, 0.03, 0.06]:
			marks.append([hit_t + after, file, file, cap, _on_target])
		await _shot(float(row[0]), 0.5, marks)

func _hand_at() -> Vector3:
	return K.hand_pos(true)

## The glow at his hand from a shot to full, about 0.2 s apart.
func _glow() -> void:
	var file := "orb_glow"
	var cap := "The charge glow at his hand from 0.7s after a shot to full (last frame, after the chime)"
	await _reset(11.0, 3.0)
	_aim(home + Vector3(8.0, 0, 0))
	K.last_shot_t = m.time
	var marks: Array = []
	for t in [0.7, 0.9, 1.1, 1.3, 1.45]:
		marks.append([t, file, file, cap, _hand_at])
	await _go(1.5, Callable(), marks, 3.0)

func _rock_row() -> void:
	var W = m.world
	var wx := int(floor(home.x + ROW_X))
	var mesh := MeshInstance3D.new()
	mesh.mesh = Models.box(1.0, 1.4, 7.0)
	mesh.material_override = Models.toon(Color("6b5a4e"), false, 0.0)
	m.add_child(mesh)
	mesh.global_position = Vector3(wx + 0.5, home.y + 0.7, home.z)
	for dz in range(-3, 4):
		W.kind[W.idx(wx, int(floor(home.z)) + dz)] = World.T_BLOCK

func _through_wall() -> void:
	for row in [["wall_full", 1.4, "A full orb"], ["wall_quick", 0.6, "A quick orb"]]:
		var file: String = row[0]
		var cap := "%s through the rock row, then on to the dummy: before, inside, past it" % row[2]
		await _reset(8.0)
		_aim(home + Vector3(8.0, 0, 0))
		var speed := float(K.base_wpn["speed"]) * (1.4 if float(row[1]) >= 1.4 else 1.0)
		var marks: Array = []
		for dist in [2.0, 3.6, 5.2, 6.2]:
			marks.append([(dist - 0.6) / speed, file, file, cap, _orb_at])
		marks.append([3.0 / speed, "full", file + "_view", cap, _orb_at])
		await _shot(float(row[1]), 0.5, marks)
