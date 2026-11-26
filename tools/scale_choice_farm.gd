extends RefCounted
## --scale-choice-farm --shots-dir=<dir> [--view=2560x1440]: camera A of the scale-choice sheet. The farm's own default
## third-person view (zoom = CamWheel.far(), the wheel's start; golden hour), Sparkle (mage) standing on the farm with one
## average Vespyx, Mycroll, Prismander, Crofthorn in a row 2.4 m in front of her, HUD and marks hidden. Per column
## (v5, v5 x1.5, v5 x2.0) writes <dir>/A_<col>.png and A_heights.json.

const FPS := 30
const ISLAND_SEED := 11
const DAY_T := 0.72
const DEADLINE_S := 900.0
const COLS := [["v5", 1.0], ["x15", 1.5], ["x20", 2.0]]

var main: Node
var h
var dir := "scale_choice_farm"
var species: PackedStringArray = ["cindle", "burrlet", "puddlet", "heatherhorn"]
var names := ["Ash", "Moss", "Dew", "Haggis"]
var face_yaw := 0.0
var fits: Array = []
var mult := 1.0

func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(2560, 1440)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="): dir = arg.substr(12)
		if arg.begins_with("--view="):
			view = Vector2i(int(arg.get_slice("x", 0).substr(7)), int(arg.get_slice("x", 1)))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = view
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	seed(ISLAND_SEED)
	_make_save()
	main.get_tree().create_timer(DEADLINE_S).timeout.connect(main.get_tree().quit.bind(1))
	h = load("res://scripts/home/home.gd").new()
	h.set("zone", "")
	main.add_child(h)
	main.set("current", h)
	for i in 3:
		await main.get_tree().process_frame
	while h.building:
		await main.get_tree().process_frame
	Settings.set_v("tips", false)
	h._close_panel()
	h.ui.visible = false
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	h.day_t = DAY_T
	RenderingServer.frame_pre_draw.connect(_hide_marks)
	# the farm draws you as the Unmasked: swap in Sparkle (mage), built as a match builds her
	var old: Node3D = h.player
	var sp: Node3D = Models.hunter(Arch.weight("mage"), Data.TEAM_COLORS[0], Arch.weapon_for("mage", Arch.weight("mage"), ""), "", {}, "mage")
	sp.scale = old.scale
	h.add_child(sp)
	h.player = sp
	old.queue_free()
	await _wait(1.0)
	var spot := _clear_spot(Vector3(56.0, 0, 29.0))
	var cd := Vector2(0.0, 1.0)  # toward the camera (south)
	_front(spot)
	h.player.visible = true
	face_yaw = PI
	_row(spot, cd, [Vector2(3.6, -2.4), Vector2(1.4, -2.4), Vector2(-1.4, -2.4), Vector2(-3.6, -2.4)])
	await _wait(2.5)
	for k in h.kins:
		fits.append(float((k["node"] as Node3D).get_meta("fit", 1.0)))
	var out := {"cols": {}}
	for c in COLS:
		mult = float(c[1])
		await _wait(1.0)
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("A_%s.png" % c[0]))
		var cam := main.get_viewport().get_camera_3d()
		var rows := {"hunter": _stands(h.player), "foot_px": {}}
		var p := cam.unproject_position(h.player.global_position)
		rows["foot_px"]["hunter"] = [p.x, p.y]
		for j in h.kins.size():
			var n := h.kins[j]["node"] as Node3D
			rows[species[j]] = _stands(n)
			var q := cam.unproject_position(n.global_position)
			rows["foot_px"][species[j]] = [q.x, q.y]
		out["cols"][c[0]] = rows
		print("SCFARM ", c[0], " ", JSON.stringify(rows))
	var f := FileAccess.open(dir.path_join("A_heights.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	main.get_tree().quit()

## Visible mesh height (cm) of a node, ground to top.
func _stands(node: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		lo = minf(lo, b.position.y)
		hi = maxf(hi, b.end.y)
	return (hi - lo) * 100.0

func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		h.day_t = DAY_T
		for j in h.kins.size():
			var n := h.kins[j]["node"] as Node3D
			n.rotation.y = face_yaw + [0.3, -0.2, 0.2, -0.3][j]
			if not fits.is_empty():
				n.set_meta("fit", fits[j] * mult)
			h.kins[j]["hop"] = 0.0
			h.kins[j]["joy_t"] = 0.0

func _make_save() -> void:
	var d := Save.fresh()
	for i in species.size():
		var rec := Save.new_kin(species[i], names[i], 700 + i)
		rec["uid"] = "ks%d" % i
		rec["trust"] = 95.0
		for need in Care.NEEDS:
			rec["needs"][need] = 95.0
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["cls"] = Arch.weight("mage")
	d["arch"] = "mage"
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	HomeLayout.new_fs(d, ISLAND_SEED)
	Save.d = d


func _hide_marks() -> void:
	if not is_instance_valid(h):
		return
	h.ui.visible = false
	for l in h.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	for sp in h.find_children("*", "Sprite3D", true, false):
		(sp as Sprite3D).visible = false
	for pt in h.find_children("*", "GPUParticles3D", true, false):
		(pt as GPUParticles3D).visible = false
	for pt in h.find_children("*", "CPUParticles3D", true, false):
		(pt as CPUParticles3D).visible = false


func _front(at: Vector3) -> void:
	at = h.world.free_spot_near(at, [], 0.8)
	h.ppos = at
	h.player.position = at
	h.pface = 0.0  # faces north (-z), the way the camera (south of her, yaw 0) looks
	h.player.rotation.y = 0.0
	h.farm_cam.yaw = 0.0
	h.cam.zoom_to = CamWheel.far()
	h.cam.zoom = h.cam.zoom_to
	h.cam.snap(at)

func _row(at: Vector3, cam_dir: Vector2, rel: Array) -> void:
	var fwd := cam_dir.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	for i in rel.size():
		var r: Vector2 = rel[i]
		var o := side * r.x + fwd * r.y
		var k: Dictionary = h.kins[i]
		k["pos"] = h.world.free_spot_near(at + Vector3(o.x, 0, o.y), [], 0.8)
		k["goal"] = k["pos"]
		k["t"] = 600.0
		(k["node"] as Node3D).position = k["pos"]
		k.erase("job")


func _clear_spot(near: Vector3) -> Vector3:
	var best := near
	var best_n := 99999
	for cx in range(int(near.x) - 8, int(near.x) + 9):
		for cz in range(int(near.z) - 8, int(near.z) + 9):
			var n := 0
			for sx in range(cx - 6, cx + 7):
				for sz in range(cz - 6, cz + 9):
					if h.world.is_block(sx + 0.5, sz + 0.5) or h.world.is_void(sx + 0.5, sz + 0.5):
						n += 1
			n = n * 10 + int(Vector2(cx - near.x, cz - near.z).length())
			if n < best_n:
				best_n = n
				best = Vector3(cx + 0.5, 0, cz + 0.5)
	return best

