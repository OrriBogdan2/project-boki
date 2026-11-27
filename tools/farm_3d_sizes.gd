extends RefCounted
## --farm-3d-sizes --shots-dir=<dir> [--view=1920x1080]: the real farm scene with five hunters (Albert is the farm's own
## avatar, Kael, Sparkle, Meeko and Neve are built the way the farm builds its avatar) and four average Boki (the
## starters + Heatherhorn) standing together, HUD, marks and particles hidden. Writes 1_farm_cam.png (the farm's close
## third-person view), 2_overview.png (higher 3/4 over the whole farm), 3_eye.png (eye level, hunters and Boki side by
## side) and heights.json (metres as drawn, per hunter and per Boki). Local render tool for the size sheet.

const FPS := 30
const ISLAND_SEED := 11
const DAY_T := 0.72  # farm clock: golden hour
const DEADLINE_S := 900.0
const ARCHES := ["bulwark", "juggernaut", "mage", "tender", "rimewright"]  # Albert, Kael, Sparkle, Meeko, Neve
const NAMES := ["Albert", "Kael", "Sparkle", "Meeko", "Neve"]
const SPECIES: PackedStringArray = ["cindle", "burrlet", "puddlet", "heatherhorn"]
const BOKI_NAMES := ["Ash", "Moss", "Dew", "Haggis"]
const HUNTER_X := [-5.0, -2.5, 0.0, 2.5, 5.0]  # m across the group (eye and overview shots), Albert far left
const BOKI_X := [-3.75, 1.25, 3.75, -1.25]  # m (cindle, burrlet, puddlet, heatherhorn): in the gaps, a row nearer
const WALK_X := [-2.7, -0.9, 0.9, 2.7]  # m: the four others in the farm-cam shot, Albert walking behind them
const WALK_BOKI_X := [-1.8, 0.0, 1.8, 3.9]
const WALK_AHEAD := 3.8  # m the row stands in front of Albert (farm-cam shot)
const BOKI_FRONT := 2.2  # m the Boki stand nearer the camera than the hunters
const FACE_BOKI := 0.35  # rad: a quarter turn off the camera, so a side view reads
const EYE_FOV := 38.0
const EYE_DIST := 12.5  # m from the group
const EYE_HEIGHT := 1.5  # m above the ground
const OVER_FOV := 45.0
const OVER_BACK := 60.0  # m south of the group
const OVER_UP := 55.0  # m above the ground

var main: Node
var h
var dir := "farm_3d_sizes"
var group := Vector3.ZERO  # ground point the group stands on
var hunters: Array[Node3D] = []
var cam3: Camera3D
var walking := true  # farm-cam shot: Albert is the avatar seen from behind; else the whole group faces the camera


func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
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
	await _wait(1.0)
	_place()
	await _wait(2.5)
	await _shot("1_farm_cam")
	walking = false
	_layout()
	await _wait(1.0)
	_free_camera(group + Vector3(0, OVER_UP, OVER_BACK), group, OVER_FOV)
	await _wait(0.5)
	await _shot("2_overview")
	_free_camera(group + Vector3(2.0, 20.0, 24.0), group + Vector3(0, 0, -2.0), OVER_FOV)
	await _wait(0.5)
	await _shot("2b_overview_near")
	_free_camera(group + Vector3(0, EYE_HEIGHT, EYE_DIST), group + Vector3(0, 1.0, 0), EYE_FOV)
	await _wait(0.5)
	await _shot("3_eye")
	_write_heights()
	main.get_tree().quit()


func _make_save() -> void:
	var d := Save.fresh()
	for i in SPECIES.size():
		var rec := Save.new_kin(SPECIES[i], BOKI_NAMES[i], 700 + i)
		rec["uid"] = "fs%d" % i
		(rec["dna"] as Dictionary)["size"] = 0.0  # an average one of its species
		rec["trust"] = 95.0
		for need in Care.NEEDS:
			rec["needs"][need] = 95.0
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["cls"] = Arch.weight(ARCHES[0])
	d["arch"] = ARCHES[0]
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	HomeLayout.new_fs(d, ISLAND_SEED)
	Save.d = d


## The farm draws you as the Unmasked, so Albert is built here like the other four (as a match builds a hunter) and
## takes the avatar's place and scale.
func _place() -> void:
	group = h.world.free_spot_near(_clear_spot(Vector3(56.0, 0, 29.0)), [], 0.8)
	var old: Node3D = h.player
	for i in ARCHES.size():
		var cls := Arch.weight(ARCHES[i])
		var m: Node3D = Models.hunter(cls, Data.TEAM_COLORS[0], Arch.weapon_for(ARCHES[i], cls, ""), "", {}, ARCHES[i])
		m.scale = old.scale
		h.add_child(m)
		hunters.append(m)
	h.player = hunters[0]
	old.queue_free()
	h.farm_cam.yaw = 0.0
	h.cam.zoom_to = CamWheel.far()
	h.cam.zoom = h.cam.zoom_to
	_layout()


## walking: Albert at the group's spot, facing north as the farm shows him, the others in a row ahead of him facing
## the camera. Otherwise all five in one row and the Boki a step nearer.
func _layout() -> void:
	var xs: Array = WALK_X if walking else HUNTER_X
	var bx: Array = WALK_BOKI_X if walking else BOKI_X
	var ahead := -WALK_AHEAD if walking else 0.0
	var albert := group + Vector3(0, 0, WALK_AHEAD if walking else 0.0)
	if not walking:
		albert = group + Vector3(HUNTER_X[0], 0, 0)
	h.ppos = albert
	h.player.position = albert
	h.pface = 0.0 if walking else PI
	h.cam.snap(albert)
	for i in range(1, ARCHES.size()):
		hunters[i].position = group + Vector3(xs[i - 1 if walking else i], 0, ahead)
	for j in h.kins.size():
		var k: Dictionary = h.kins[j]
		k["pos"] = group + Vector3(bx[j], 0, ahead + BOKI_FRONT)
		k["goal"] = k["pos"]
		k["t"] = 600.0
		(k["node"] as Node3D).position = k["pos"]
		k.erase("job")


func _free_camera(at: Vector3, look: Vector3, fov: float) -> void:
	if cam3 == null:
		cam3 = Camera3D.new()
		h.add_child(cam3)
	cam3.fov = fov
	cam3.near = 0.1
	cam3.far = 400.0
	cam3.position = at
	cam3.look_at_from_position(at, look, Vector3.UP)
	cam3.current = true


func _shot(name: String) -> void:
	await _wait(1.0)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _write_heights() -> void:
	var out := {
		"hunter_scale": hunters[0].global_basis.y.length(),
		"hunters": {},
		"parts": {},
		"boki": {},
		"group": [group.x, group.z]
	}
	for i in hunters.size():
		out["hunters"][NAMES[i]] = _parts(hunters[i])[0][3]
		out["parts"][NAMES[i]] = _parts(hunters[i])
	for j in h.kins.size():
		out["boki"][SPECIES[j]] = _height_m((h.kins[j]["node"] as Node3D).find_child("Rig", true, false))
	var f := FileAccess.open(dir.path_join("heights.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("FARM3D ", JSON.stringify(out))


## Per mesh: [name, parent name, bottom m, top m] above the model's feet, tallest first.
func _parts(model: Node3D) -> Array:
	var rows := []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or _under(mi, "Glider"):
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		rows.append(
			[
				String(mi.name),
				String(mi.get_parent().name),
				snappedf(bb.position.y - model.global_position.y, 0.01),
				snappedf(bb.end.y - model.global_position.y, 0.01)
			]
		)
	rows.sort_custom(func(a, b): return a[3] > b[3])
	return rows.slice(0, 8)


func _under(n: Node, node_name: String) -> bool:
	while n != null:
		if String(n.name) == node_name:
			return true
		n = n.get_parent()
	return false


## Standing height (m) of a model as drawn: its bind-pose box (KinSize.box, so no idle pose moves it) times its world scale.
func _height_m(model: Node3D) -> float:
	return KinSize.box(model).y * model.global_basis.y.length()


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		h.day_t = DAY_T
		for j in h.kins.size():
			h.kins[j]["hop"] = 0.0
			h.kins[j]["joy_t"] = 0.0


## After Home's own pose each frame: everyone faces the camera, the Boki at the non-active farm size, UI and marks gone.
func _hide_marks() -> void:
	if not is_instance_valid(h):
		return
	for i in hunters.size():
		for g in hunters[i].find_children("Glider", "Node3D", true, false):
			(g as Node3D).visible = false  # folded away on the ground, as in play
		if i > 0 or not walking:
			hunters[i].rotation.y = PI
	for j in h.kins.size():
		var n := h.kins[j]["node"] as Node3D
		n.rotation.y = FACE_BOKI * (1.0 if j % 2 == 0 else -1.0)
		n.scale = Vector3.ONE * 0.9 * float(n.get_meta("evo_scale", 1.0)) * h.FARM_BOKI_SCALE
	h.ui.visible = false
	for kind in ["Label3D", "Sprite3D", "GPUParticles3D", "CPUParticles3D"]:
		for n in h.find_children("*", kind, true, false):
			(n as Node3D).visible = false


func _clear_spot(near: Vector3) -> Vector3:
	var best := near
	var best_n := 99999
	for cx in range(int(near.x) - 8, int(near.x) + 9):
		for cz in range(int(near.z) - 8, int(near.z) + 9):
			var n := 0
			for sx in range(cx - 8, cx + 9):
				for sz in range(cz - 6, cz + 9):
					if h.world.is_block(sx + 0.5, sz + 0.5) or h.world.is_void(sx + 0.5, sz + 0.5):
						n += 1
			n = n * 10 + int(Vector2(cx - near.x, cz - near.z).length())
			if n < best_n:
				best_n = n
				best = Vector3(cx + 0.5, 0, cz + 0.5)
	return best
