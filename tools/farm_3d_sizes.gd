extends RefCounted
## --farm-3d-sizes --shots-dir=<dir> [--view=1920x1080] [--albert-k=1.08]: the real farm scene with five hunters (Albert
## is the farm's own avatar; Kael, Sparkle, Meeko and Cinder are built as a match builds a hunter) at their match size
## (own model size x Hunter.VIS_SCALE x body.match_k: the reference's height) and the four Boki, all idle, HUD, marks
## and particles hidden. Writes 1_farm_cam.png (the farm's close third-person view), 2_eye_row.png (eye level, one row),
## 3_mid.png and heights.json (metres as drawn: crown and with extras, per hunter and per Boki). Needs a renderer for
## the stills.

const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
const NOT_BODY := [
	"Glider", "TeamRing", "Companion", "prop_", "Gun", "Shield", "Halo", "hammer", "Bloom", "Shell", "Aura"
]
const FPS := 30
const ISLAND_SEED := 11
const DAY_T := 0.72  # farm clock: golden hour
const DEADLINE_S := 900.0
const ARCHES := ["bulwark", "juggernaut", "mage", "tender", "ashwick"]  # Albert, Kael, Sparkle, Meeko, Cinder
const NAMES := ["Albert", "Kael", "Sparkle", "Meeko", "Cinder"]
const SPECIES: PackedStringArray = ["cindle", "burrlet", "puddlet", "heatherhorn"]
const BOKI_NAMES := ["Ash", "Moss", "Dew", "Haggis"]
const ROW_STEP := 1.45  # m between neighbours in the one row of nine (eye shot): hunters and Boki alternate
const ROW_ORDER := ["h0", "b0", "h1", "b1", "h2", "b2", "h3", "b3", "h4"]  # Albert at the end nearest the 3/4 camera
const HUNTER_X := [-5.0, -2.5, 0.0, 2.5, 5.0]  # m across the group (mid shot back row), Albert far left
const BOKI_X := [-3.75, 1.25, 3.75, -1.25]  # m (cindle, burrlet, puddlet, heatherhorn): in the gaps, a row nearer
const WALK_X := [-4.2, -2.1, 2.1, 4.2]  # m: the four others in the farm-cam shot, level with Albert, two a side
const WALK_BOKI_X := [-3.1, -1.0, 1.0, 3.1]  # m: the Boki between and ahead of them
const WALK_AHEAD := 1.0  # m the others stand in front of Albert (farm-cam shot)
const WALK_BOKI_AHEAD := 2.6  # m the Boki stand in front of the hunters (farm-cam shot)
const BOKI_FRONT := 2.2  # m the Boki stand nearer the camera than the hunters
const FACE_BOKI := 0.18  # rad: a small turn either side of the camera, so it is not stiff but the face reads
const CLEAR_HALF_W := 6.0  # m either side of the camera-to-group line that scenery is hidden in
const CLEAR_ROW_W := 8.0  # m either side of the group that scenery is hidden in, front to back CLEAR_ROW_D
const CLEAR_ROW_D := 3.0
const EYE_FOV := 40.0
const EYE_DIST := 15.0  # m from the row's middle
const EYE_YAW := 0.5  # rad: the 3/4 view, the camera swung round to Albert's end of the row
const EYE_HEIGHT := 1.4  # m above the ground
const MID_FOV := 40.0
const MID_BACK := 11.0  # m from the group
const MID_UP := 4.5  # m above the ground

var main: Node
var h
var dir := "farm_3d_sizes"
var group := Vector3.ZERO  # ground point the group stands on
var hunters: Array[Node3D] = []
var cam3: Camera3D
var walking := true  # farm-cam shot: Albert is the avatar seen from behind; else the whole group faces the camera
var layout := "farm"  # farm | row | mid
var anims: Array = []  # one HunterAnim per hunter (Albert's is the farm's own, h.p_anim)
var cam_at := Vector3.ZERO  # the free camera's position: everyone turns to it
var scales: Array[Vector3] = []  # each hunter's drawn scale: its own model size x a match's VIS_SCALE x match_k
var albert_k := 1.0  # --albert-k=<x>: Albert's extra size in this tool only (game data unchanged)
var cam_side := 1.0  # +1: the eye camera swings to +x, Albert at +x end of the row; -1 the other way


func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--albert-k="):
			albert_k = float(arg.substr(11))
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
	if DisplayServer.get_name() == "headless":
		_write_heights()
		main.get_tree().quit()
		return
	_log("1_farm_cam")
	await _shot("1_farm_cam")
	_log("after 1")
	layout = "row"
	_layout()
	var mid := group + Vector3(0, 0, 0)
	cam_at = mid + Vector3(sin(EYE_YAW) * EYE_DIST * cam_side, EYE_HEIGHT, cos(EYE_YAW) * EYE_DIST)
	_free_camera(cam_at, mid + Vector3(0, 1.0, 0), EYE_FOV)
	await _wait(1.5)
	_log("2_eye_row")
	await _shot("2_eye_row")
	_log("after 2")
	layout = "mid"
	_layout()
	cam_at = group + Vector3(0.0, MID_UP, MID_BACK)
	_free_camera(cam_at, group + Vector3(0, 0.9, 1.0), MID_FOV)
	await _wait(1.5)
	_log("3_mid")
	await _shot("3_mid")
	_log("after 3")
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
## takes the avatar's place and scale. Each of the four gets a HunterAnim, so it idles as it does in play.
func _place() -> void:
	group = h.world.free_spot_near(_clear_spot(Vector3(56.0, 0, 29.0)), [], 0.8)
	var old: Node3D = h.player
	for i in ARCHES.size():
		var cls := Arch.weight(ARCHES[i])
		var m: Node3D = Models.hunter(
			cls, Data.TEAM_COLORS[0], Arch.signature(ARCHES[i]), "", Unmasked.mask_look(), ARCHES[i]
		)
		m.scale *= Hunter.VIS_SCALE * Arch.match_k(ARCHES[i])  # as a match draws it: the reference's height
		if i == 0:
			m.scale *= albert_k  # --albert-k=<x>: the owner's "Albert tallest" look, this tool only
		scales.append(m.scale)
		h.add_child(m)
		hunters.append(m)
		anims.append(null if i == 0 else HunterAnim.new(m))
	h.player = hunters[0]
	hunters[0].set_meta("pop", scales[0])  # Home sets the avatar's scale back to this when the camera settings apply
	old.queue_free()
	h.farm_cam.yaw = 0.0
	_layout()


## farm: Albert at the group's spot facing north as the farm shows him, the other four in a row ahead of him facing the
## camera. row: all nine in one line, hunters and Boki alternating, Albert at the camera's end. mid: the hunters in a
## back row, Boki a row nearer, Albert a step in front.
func _layout() -> void:
	var spots := {}  # node -> ground position
	var albert := group
	match layout:
		"farm":
			albert = group + Vector3(0, 0, WALK_AHEAD)
			for i in range(1, 5):
				spots[i] = group + Vector3(WALK_X[i - 1], 0, 0)
			for j in 4:
				spots[10 + j] = group + Vector3(WALK_BOKI_X[j], 0, -WALK_BOKI_AHEAD)
		"row":
			for slot in ROW_ORDER.size():
				var x := (4 - slot) * ROW_STEP * cam_side
				var id := String(ROW_ORDER[slot])
				var n := int(id.substr(1))
				if id.begins_with("h"):
					spots[n] = group + Vector3(x, 0, 0)
				else:
					spots[10 + n] = group + Vector3(x, 0, 0.2)
			albert = spots[0]
		"mid":
			albert = group + Vector3(HUNTER_X[0], 0, 1.2)
			for i in range(1, 5):
				spots[i] = group + Vector3(HUNTER_X[i], 0, 0)
			for j in 4:
				spots[10 + j] = group + Vector3(BOKI_X[j], 0, BOKI_FRONT)
	h.ppos = albert
	h.player.position = albert
	h.pface = 0.0 if layout == "farm" else PI
	h.cam.snap(albert)
	for i in range(1, 5):
		hunters[i].position = spots[i]
	for j in h.kins.size():
		var k: Dictionary = h.kins[j]
		k["pos"] = spots[10 + j]
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
	_clear_foreground()
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	_write_labels(name, img.get_size())


## Hides the trees, bushes and rocks (the farm draws them as multimeshes) that stand among the group or in the
## corridor between the camera and it, so no trunk covers anyone. The ground, water and characters stay.
func _clear_foreground() -> void:
	var cam := main.get_viewport().get_camera_3d()
	var from := Vector2(cam.global_position.x, cam.global_position.z)
	var line := Vector2(group.x, group.z) - from
	for n in h.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var id := String(mmi.name)
		if not (id.begins_with("tree") or id.begins_with("bush") or id.begins_with("rock")):
			continue
		for i in mmi.multimesh.instance_count:
			var at := mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
			if _in_the_way(Vector2(at.x, at.z), from, line):
				mmi.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), at))


func _in_the_way(centre: Vector2, from: Vector2, line: Vector2) -> bool:
	if absf(centre.x - group.x) < CLEAR_ROW_W and absf(centre.y - group.z) < CLEAR_ROW_D:
		return true  # standing among them
	var at := centre - from
	var t := at.dot(line) / line.length_squared()
	return t > 0.0 and t < 0.95 and absf(at.cross(line)) / line.length() < CLEAR_HALF_W


## <name>.json: where each character's feet are on the still, in px, for the sheet's name labels.
func _write_labels(shot: String, size: Vector2i) -> void:
	var cam := main.get_viewport().get_camera_3d()
	var px := {}
	for i in hunters.size():
		px[NAMES[i]] = _on_still(cam, hunters[i].global_position, size)
	for j in h.kins.size():
		px[KinLib.kin(SPECIES[j]).display_name] = _on_still(cam, (h.kins[j]["node"] as Node3D).global_position, size)
	var f := FileAccess.open(dir.path_join(shot + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(px))
	f.close()


## A world point in px on the saved still. Through the camera's own matrices, not unproject_position: on the GPU box
## that answered in a 1280x720 space while the still was 1920x1080, so every name tag sat 2/3 of the way to the corner.
func _on_still(cam: Camera3D, at: Vector3, size: Vector2i) -> Array:
	var v := cam.get_camera_transform().affine_inverse() * at
	var c := cam.get_camera_projection() * Vector4(v.x, v.y, v.z, 1.0)
	return [(c.x / c.w * 0.5 + 0.5) * size.x, (0.5 - c.y / c.w * 0.5) * size.y]


func _write_heights() -> void:
	var out := {"hunters": {}, "boki": {}, "group": [group.x, group.z], "albert_k": albert_k}
	for i in hunters.size():
		var m := hunters[i]
		var lean := m.basis
		m.basis = Basis.from_scale(m.scale)  # upright: the camera's lean tips the model and shortens it on screen
		var pts := _body_points(m)
		var hi := 0.0
		for wp in pts:
			hi = maxf(hi, wp.y)
		var k := Hunter.VIS_SCALE * Arch.match_k(ARCHES[i]) * (albert_k if i == 0 else 1.0)
		var crown := HunterCrown.crown(m, pts, k, hi) - m.global_position.y
		m.basis = lean
		out["hunters"][NAMES[i]] = {
			"body": snappedf(crown, 0.01), "full": snappedf(hi - m.global_position.y, 0.01), "scale": m.scale.y
		}
	for j in h.kins.size():
		var n := h.kins[j]["node"] as Node3D
		out["boki"][SPECIES[j]] = {"body": _top(n, false), "full": _top(n, true)}
	var f := FileAccess.open(dir.path_join("heights.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("FARM3D ", JSON.stringify(out))


## Height (m above the model's feet, as drawn) of the top of a Boki's meshes: its "Body" mesh only, or (`anything`)
## every visible mesh that is not a prop, ring or pet (ears and tufts in).
func _top(model: Node3D, anything: bool) -> float:
	var top := 0.0
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if (
			mi.mesh == null
			or not mi.is_visible_in_tree()
			or (anything and _skip(mi))
			or (not anything and mi.name != "Body")
		):
			continue
		top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y - model.global_position.y)
	return snappedf(top, 0.01)


## The posed vertices of a hunter's body meshes (a skinned mesh's real pose, not its bind box), no weapon or pet.
func _body_points(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _skip(mi):
			continue
		if mi.skin:
			out.append_array(WARDEN_SKIN.points(mi))
		else:
			for c in 8:
				out.append(mi.global_transform * mi.get_aabb().get_endpoint(c))
	return out


func _skip(mi: Node) -> bool:
	var n := mi
	while n != null:
		for bad in NOT_BODY:
			if String(n.name).contains(bad):
				return true
		n = n.get_parent()
	return false


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		h.day_t = DAY_T
		h.pvel = Vector3.ZERO
		h.dash_t = 0.0
		for j in h.kins.size():
			h.kins[j]["hop"] = 0.0
			h.kins[j]["joy_t"] = 0.0
		_pose_hunters(1.0 / FPS)


## The camera everyone turns to: the free camera, or in the farm shot the farm's own.
func _eye() -> Vector3:
	return h.cam.global_position if layout == "farm" else cam_at


func _face_to(p: Vector3) -> float:
	var e := _eye()
	return atan2(-(e.x - p.x), -(e.z - p.z))


## Idle for the four that are not the farm's avatar (Albert's own HunterAnim runs in Home), all turned to the camera.
func _pose_hunters(d: float) -> void:
	for i in range(1, hunters.size()):
		var face := _face_to(hunters[i].position)
		hunters[i].basis = h.cam.char_basis(face, scales[i])
		anims[i].update(d, {"vel": Vector3.ZERO, "face": face, "grounded": true, "idle_break": true})
	if layout != "farm":
		h.pface = _face_to(hunters[0].position)


## After Home's own pose each frame: everyone faces the camera, the Boki at the non-active farm size, UI and marks gone.
func _hide_marks() -> void:
	if not is_instance_valid(h) or hunters.is_empty():
		return
	for i in hunters.size():
		for g in hunters[i].find_children("Glider", "Node3D", true, false):
			(g as Node3D).visible = false  # folded away on the ground, as in play
		if i > 0 or layout != "farm":
			hunters[i].rotation.y = _face_to(hunters[i].position)
	for j in h.kins.size():
		var n := h.kins[j]["node"] as Node3D
		n.rotation.y = _face_to(n.position) + FACE_BOKI * (1.0 if j % 2 == 0 else -1.0)
		n.scale = Vector3.ONE * 0.9 * float(n.get_meta("evo_scale", 1.0)) * h.FARM_BOKI_SCALE
	h.ui.visible = false
	for ring in h.find_children("TeamRing", "MeshInstance3D", true, false):
		(ring as Node3D).visible = false  # the orange discs under the hunters' feet
	for kind in ["Label3D", "Sprite3D", "GPUParticles3D", "CPUParticles3D"]:
		for n in h.find_children("*", kind, true, false):
			(n as Node3D).visible = false


## The ground point with the fewest trees, rocks, buildings and edges in the box the shots look at (the group, the
## ground behind it for the camera's background and the ground in front of it for the camera), over the whole island.
func _clear_spot(near: Vector3) -> Vector3:
	var best := near
	var best_n := 999999
	var wd = h.world
	var objs: Array[Vector2] = []  # buildings, signs, fences, the portal and the farm's named spots
	for c in h.get_children():
		if (
			c is Node3D
			and not c is Camera3D
			and not c is Light3D
			and (c as Node3D).position.length() > 1.0
			and c.get_child_count() > 0
		):
			objs.append(Vector2((c as Node3D).position.x, (c as Node3D).position.z))
	for key in h.spots:
		var sp: Vector3 = h.spots[key]
		if sp.x > -100.0:
			objs.append(Vector2(sp.x, sp.z))
	for cx in range(14, int(wd.w) - 14, 2):
		for cz in range(14, int(wd.h) - 14, 2):
			var n := 0
			for sx in range(cx - 10, cx + 11):
				for sz in range(cz - 10, cz + 17):
					var dz := sz - cz
					var bad: bool = (
						wd.is_block(sx + 0.5, sz + 0.5) or wd.occupy(sx + 0.5, sz + 0.5, 0.9, 0.0, true) != 0.0
					)
					var off: bool = wd.is_void(sx + 0.5, sz + 0.5)
					if dz >= -3 and dz <= 4 and absi(sx - cx) <= 8:
						n += 30 if bad or off else 0  # where the characters stand
					elif dz < -3:
						n += 4 if bad else 0  # the background: trees there only clutter
					elif dz > 4:
						n += (6 if bad else 0)  # where the cameras stand
						n += 1 if off else 0
			for o in objs:
				if o.x > cx - 12.0 and o.x < cx + 12.0 and o.y > cz - 10.0 and o.y < cz + 17.0:
					n += 40
			var sides := [0, 0]
			for si in 2:
				var sg := 1.0 if si == 0 else -1.0
				var c0 := Vector3(cx + 0.5, 0, cz + 0.5)
				var cams := [
					c0 + Vector3(sin(EYE_YAW) * EYE_DIST * sg, 0, cos(EYE_YAW) * EYE_DIST), c0 + Vector3(0, 0, MID_BACK)
				]
				for cm in cams:
					for tx in [-5.8, 0.0, 5.8]:
						var tg := c0 + Vector3(tx, 0, 0)
						for t in range(1, 24):
							var q: Vector3 = cm.lerp(tg, t / 24.0)
							if wd.is_block(q.x, q.z) or wd.occupy(q.x, q.z, 0.8, 0.0, true) != 0.0:
								sides[si] += 6
							for o in objs:
								if Vector2(o.x - q.x, o.y - q.z).length() < 1.6:
									sides[si] += 6
			n += mini(sides[0], sides[1])
			var side := 1.0 if sides[0] <= sides[1] else -1.0
			n = n * 10 + int(Vector2(cx - near.x, cz - near.z).length() * 0.1)
			if n < best_n:
				best_n = n
				best = Vector3(cx + 0.5, 0, cz + 0.5)
				cam_side = side
	if "--map" in OS.get_cmdline_user_args():
		for z in range(0, int(wd.h)):
			var line := ""
			for x in range(0, int(wd.w)):
				var c := "."
				if wd.is_void(x + 0.5, z + 0.5):
					c = " "
				elif wd.is_block(x + 0.5, z + 0.5):
					c = "#"
				elif wd.occupy(x + 0.5, z + 0.5, 0.9, 0.0, true) != 0.0:
					c = "o"
				for o in objs:
					if int(o.x) == x and int(o.y) == z:
						c = "@"
				line += c
			print("MAP%02d %s" % [z, line])
	print("FARM3D clear spot ", best, " score ", best_n / 10)
	return best


func _log(tag: String) -> void:
	var rows := []
	for i in hunters.size():
		rows.append(
			"%s %.1f,%.1f" % [NAMES[i], hunters[i].global_position.x - group.x, hunters[i].global_position.z - group.z]
		)
	print("FARM3D ", tag, " ppos ", h.ppos - group, " ", "; ".join(rows))
