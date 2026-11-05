extends "res://tools/combo51_shots.gd"
## --ostra-orb-shots --shots-dir=<dir>: owner item 60's screenshots in a live Arena match (xvfb with a renderer):
## a quick orb next to a full-charge orb, and a full orb passing a wall. <dir>/captions.txt gets "file: caption".

func run(main_node: Node) -> void:
	main = main_node
	who = "ostra"
	hero_name = "ostra"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _pair()
	await _wall_shot()
	_write_captions()
	print("OSTRAORBSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _last_orb() -> Vector3:
	for i in range(m.shots.size() - 1, -1, -1):
		if m.shots[i]["by"] == P:
			return m.shots[i]["pos"] + Vector3(0, 0.3, 0)
	return P.position + Vector3(2.5, 1.0, 0)

func _fire_after(wait: float) -> Callable:
	return func(t: float):
		var K: OstraKit = P.ak
		if t < DT:
			K.last_shot_t = m.time - wait
		P.inp["fire"] = t >= 0.1 and t < 0.1 + DT * 1.5

## A quick orb (just fired) beside a full-charge orb (waited the whole window), a moment after leaving his hand:
## the two close-ups of the orb in flight, joined side by side.
func _pair() -> void:
	var names := ["quick", "full"]
	for i in 2:
		await _reset(14.0)
		_aim(home + Vector3(14.0, 0, 0))
		var wait := 0.0 if i == 0 else 3.0
		await _go(0.5, _fire_after(wait), [[0.3, "full", "orb_" + String(names[i]), "orb", _last_orb]], 5.0)
	var a := Image.load_from_file(dir.path_join("ostra_orb_quick_close.png"))
	var b := Image.load_from_file(dir.path_join("ostra_orb_full_close.png"))
	var out := Image.create(a.get_width() + b.get_width() + 4, a.get_height(), false, a.get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + 4, 0))
	out.save_png(dir.path_join("ostra_orb_pair.png"))
	lines.append("ostra|ostra_orb_pair.png|Ostra's LMB (item 60): left, a quick orb fired right after the last; right, the orb after waiting the full 1.4s (bigger, brighter, faster)")

## A full orb passing a wall between him and the dummy.
func _wall_shot() -> void:
	await _reset(11.0)
	var W = m.world
	var cells: Array = []
	for z in range(-3, 4):
		var i: int = W.idx(int(floor(home.x + 5.5)), int(floor(home.z + z)))
		cells.append([i, W.kind[i]])
		W.kind[i] = World.T_BLOCK
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 2.4, 7.0)
	slab.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.4)
	slab.material_override = mat
	main.add_child(slab)
	slab.global_position = Vector3(floor(home.x + 5.5) + 0.5, home.y + 1.2, floor(home.z) + 0.5)
	_aim(home + Vector3(11.0, 0, 0))
	var caption := "A full-charge orb passing through the wall between him and the dummy (item 60)"
	await _go(0.7, _fire_after(3.0), [[0.35, "full", "wall_pass", caption, _last_orb]], 5.0)
	slab.queue_free()
	for c in cells:
		W.kind[int(c[0])] = int(c[1])
