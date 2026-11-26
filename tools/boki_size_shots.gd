extends "res://tools/vv_shots.gd"
## --boki-size-shots --shots-dir=<dir> [--view=3840x2160]: the hero and one average-size Vespyx, Mycroll, Prismander and
## Heatherhorn side by side on flat ground at the match camera's closest zoom, the Boki idling. Writes <dir>/game.png
## (the real frame with the HUD), <dir>/size.png (the same frame, HUD hidden), <dir>/eye.png (a camera on the ground,
## HUD hidden) and <dir>/size.json: per one its player name, foot px, its world box in cm (w, h, d), its data cm, and
## what it covers at the game camera: bbox px (w, h) and the area px of its silhouette (convex hull of the mesh).

const SPECIES := ["cindle", "burrlet", "puddlet", "heatherhorn"]
const GAP := 2.2
const EYE_FOV := 40.0  # degrees: the eye-level camera's vertical lens
const EYE_DIST := 10.0  # m from the row
const EYE_HEIGHT := 0.35  # m above the ground: a Boki's own eye height
const STAGGER := 1.3  # m every second Boki stands nearer the camera, so the name plates do not overlap
const FACE := Vector3(0.8, 0, 0.6)  # the way they face: three quarters on to the camera, not away from it


func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(3840, 2160)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--view="):
			view = Vector2i(int(arg.get_slice("x", 0).substr(7)), int(arg.get_slice("x", 1)))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = view
	extra_opts = {"arena": false, "training": false}  # a real expedition frame, not the practice drill
	await _setup()
	m.cam.user_zoom = CamWheel.near(true)
	T.teleport(home + Vector3(-30, 0, 30))
	var ks: Array = []
	for i in SPECIES.size():
		var rec := Save.new_kin(String(SPECIES[i]), "", 7)
		(rec["dna"] as Dictionary)["size"] = 0.0
		var k := m.spawn_wild(rec, home + Vector3(GAP * (i + 1), 0, STAGGER * (i % 2)))
		k.speed = 0.0  # stays where it stands, idling
		ks.append(k)
	cam_at = home + Vector3(GAP * 2.0, 0, 0)
	var turn := func(_t: float) -> void:
		for k in ks:
			k.face = atan2(-FACE.x, -FACE.z)
			k.render(DT, 1.0)  # (the match's own render pass is off here)
			k.ring.visible = false  # the type cue's quad would count in the covered area
	await _go(1.0, turn, [], 3.0)
	for k in ks:
		k.teleport(k.home)
	await _go(0.5, turn, [], 3.0)
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("game.png"))
	_hide_ui()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("size.png"))
	var cam := main.get_viewport().get_camera_3d()
	var out := {"size": [img.get_width(), img.get_height()], "rows": []}
	out["rows"].append(_row(HeroTitle.base_name(String(P.arch)), P, cam, 0.0))
	for k in ks:
		out["rows"].append(
			_row(
				KinLib.kin(String(k.species)).display_name,
				k,
				cam,
				float(Unique.base_size(k.species)["cm"]),
				String(k.species)
			)
		)
	var nodes: Array = [P] + ks
	var eye_feet: Array = await _eye_level(Vector3(home.x + GAP * 2.0, home.y, home.z), nodes)
	for i in nodes.size():
		out["rows"][i]["eye_foot"] = [eye_feet[i].x, eye_feet[i].y]
	var f := FileAccess.open(dir.path_join("size.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("BOKISIZE ", JSON.stringify(out))
	main.get_tree().quit(0)


func _row(player: String, node: Node3D, cam: Camera3D, data_cm: float, species := "") -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var pts := PackedVector2Array()
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or not mi.mesh is ArrayMesh:
			continue
		for v in mi.mesh.get_faces():
			var w := mi.global_transform * v
			lo = lo.min(w)
			hi = hi.max(w)
			pts.append(cam.unproject_position(w))
	var hull := Geometry2D.convex_hull(pts)
	var area := 0.0
	for i in hull.size() - 1:
		area += hull[i].x * hull[i + 1].y - hull[i + 1].x * hull[i].y
	var foot := cam.unproject_position(node.global_position)
	var box := (hi - lo) * 100.0
	var bbox := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bbox = bbox.expand(p)
	return {
		"who": player,
		"species": species,
		"foot": [foot.x, foot.y],
		"box_cm": [box.x, box.y, box.z],
		"data_cm": data_cm,
		"px": [bbox.size.x, bbox.size.y],
		"area_px": absf(area) * 0.5,
		"face_deg": rad_to_deg(float(node.get("face"))),
	}


## A camera at a Boki's own height facing the row from the front, the HUD hidden, the grass hidden.
func _eye_level(row_mid: Vector3, nodes: Array) -> Array:
	var eye := Camera3D.new()
	main.add_child(eye)
	eye.fov = EYE_FOV
	eye.global_position = row_mid + Vector3(0, EYE_HEIGHT, EYE_DIST)
	eye.look_at(row_mid + Vector3(0, EYE_HEIGHT, 0))
	eye.make_current()
	for n in main.find_children("*", "MultiMeshInstance3D", true, false):  # (tall grass would hide the row)
		if n.name.begins_with("Grass") or n.name.begins_with("Bushes") or n.name.begins_with("Flowers"):
			(n as Node3D).visible = false
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("eye.png"))
	return nodes.map(func(n: Node3D) -> Vector2: return eye.unproject_position(n.global_position))


## Every 2D layer and top-level control off, so the frame is the world alone.
func _hide_ui() -> void:
	for n in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n in main.get_children():
		if n is Control:
			(n as Control).visible = false
