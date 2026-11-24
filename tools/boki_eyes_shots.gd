extends RefCounted
## --boki-eyes-shots --shots-dir=<dir> [--species=a,b] [--px=480]: does each rigged Boki's coat carry its own eyes?
## Per species, as the game builds it (idle at 0.5 s, neutral): <dir>/<id>_off.png, a front close-up of its head with
## the species' own face (the overlay only for the ones in content/rules/boki_eyes.json), <id>_on.png the same with the
## overlay forced on (BokiRig.face_overlay), and <id>_game.png, a crop at the match camera (the species' own face).
## <dir>/eyes.tsv: id, Face tris, coat tris. --turn: also <id>_turn_<n>.png, the whole Boki with no overlay from 4 sides
## (front, its right, back, its left), for a coat whose head close-up misses the face.
## Needs a renderer (a GPU worker: jobq submit --needs gpu).

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
const CLOSE_FOV := 18.0  # deg
const CLOSE_PITCH := deg_to_rad(8.0)  # the close camera a little above the face
const CLOSE_MARGIN := 1.15  # the frame on the head's bounds
const HEAD_BONE := "head"  # every Boki rig has one
const GAME_RES := Vector2i(1920, 1080)
const GAME_CROP := 96  # px of the 1080p match frame kept round the Boki
const GAME_ENLARGE := 3  # nearest-neighbour, so the game's pixels stay readable
const TURN_YAWS := [PI, PI * 1.5, 0.0, PI * 0.5]  # PI faces the camera
const TURN_PITCH := deg_to_rad(20.0)
const GAME_YAW := PI * 0.8  # its front three-quarters, as boki_rig_shots' match.png

var main: Node
var out := ""
var px := 480
var only: Array = []
var turn := false


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--px="):
			px = int(a.substr(5))
		if a.begins_with("--species="):
			only = Array(a.substr(10).split(","))
		if a == "--turn":
			turn = true
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var tsv := ["id\tface_tris\tcoat_tris"]
	for id in only if not only.is_empty() else Rig.SPECIES_LIST:
		BokiRig.face_overlay = true
		tsv.append("%s\t%d\t%d" % [id, _face_tris(String(id)), _coat_tris(String(id))])
		await _close(String(id))
		await _game(String(id))
		if turn:
			await _turn(String(id))
	var f := FileAccess.open(out.path_join("eyes.tsv"), FileAccess.WRITE)
	f.store_string("\n".join(tsv) + "\n")
	f.close()
	print("BOKI_EYES_SHOTS_DONE")
	main.get_tree().quit()


## A front close-up on the coat's head (its vertices on the head bone, as posed), with the overlay on and off.
func _close(id: String) -> void:
	for on in [true, false]:
		BokiRig.face_overlay = on
		var vp := _stage(Vector2i(px, px), false)
		var k := _posed(vp, id, PI)
		var box := _head_box(k.get_node("Body/Flex/BokiRig") as BokiRig)
		if not box.has_volume():  # a body weighted to other bones (Threadwyrm's lobes): the whole Boki
			box = k.global_transform * Shots._box(k)
		var mid := box.get_center()
		var size := maxf(box.size.x, box.size.y) * CLOSE_MARGIN
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.fov = CLOSE_FOV
		cam.near = 0.02
		var dist := size * 0.5 / tan(deg_to_rad(CLOSE_FOV) * 0.5) + box.size.z * 0.5
		cam.position = mid + Vector3(0, sin(CLOSE_PITCH), cos(CLOSE_PITCH)) * dist
		cam.look_at(mid)
		cam.make_current()
		await _save(vp, "%s_%s.png" % [id, "on" if on else "off"])


## The whole Boki, no overlay, from each of TURN_YAWS.
func _turn(id: String) -> void:
	BokiRig.face_overlay = false
	for n in TURN_YAWS.size():
		var vp := _stage(Vector2i(px, px), false)
		var k := _posed(vp, id, TURN_YAWS[n])
		var box := k.global_transform * Shots._box(k)
		var size := box.size.length() * CLOSE_MARGIN
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.fov = CLOSE_FOV
		cam.near = 0.02
		var dist := size * 0.5 / tan(deg_to_rad(CLOSE_FOV) * 0.5)
		cam.position = box.get_center() + Vector3(0, sin(TURN_PITCH), cos(TURN_PITCH)) * dist
		cam.look_at(box.get_center())
		cam.make_current()
		await _save(vp, "%s_turn_%d.png" % [id, n])


## At the match camera, leaned like the game (boki_rig_shots' match.png), cropped round it and enlarged.
func _game(id: String) -> void:
	var vp := _stage(GAME_RES, true)
	var k := _posed(vp, id, GAME_YAW)
	k.basis = Basis(Vector3.RIGHT, -Shots.LEAN) * Basis(Vector3.UP, GAME_YAW)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = Shots.MATCH_FOV
	var pitch := deg_to_rad(Shots.MATCH_PITCH)
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * Shots.MATCH_DIST
	cam.rotation = Vector3(-pitch, 0, 0)
	cam.make_current()
	var img: Image = await _grab(vp)
	var c := Vector2i(cam.unproject_position(Vector3(0, 0.3, 0))) - Vector2i(GAME_CROP, GAME_CROP) / 2
	var crop := img.get_region(Rect2i(c, Vector2i(GAME_CROP, GAME_CROP)))
	crop.resize(GAME_CROP * GAME_ENLARGE, GAME_CROP * GAME_ENLARGE, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("%s_game.png" % id))
	vp.queue_free()


## World bounds of the coat's vertices that mostly follow the head bone, moved from the rest pose to the held frame.
static func _head_box(rig: BokiRig) -> AABB:
	var skel := rig.skeleton()
	var head := skel.find_bone(HEAD_BONE)
	var to_skel := skel.global_transform.affine_inverse()
	var rest := skel.get_bone_global_rest(head).affine_inverse()
	var lift := skel.global_transform * skel.get_bone_global_pose(head) * rest
	var pts := PackedVector3Array()
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst == rig.face or inst.skin == null:
			continue
		var into := to_skel * inst.global_transform
		for si in inst.mesh.get_surface_count():
			var arr := inst.mesh.surface_get_arrays(si)
			var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var bones := arr[Mesh.ARRAY_BONES] as PackedInt32Array
			var weights := arr[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			var per := bones.size() / verts.size()
			for v in verts.size():
				var top := 0
				for j in per:
					if weights[v * per + j] > weights[v * per + top]:
						top = j
				if _bind_bone(inst.skin, skel, bones[v * per + top]) == head:
					pts.append(lift * (into * verts[v]))
	if pts.is_empty():
		return AABB()
	var box := AABB(pts[0], Vector3.ZERO)
	for q in pts:
		box = box.expand(q)
	return box


static func _bind_bone(skin: Skin, skel: Skeleton3D, bind: int) -> int:
	var b := skin.get_bind_bone(bind)
	return b if b >= 0 else skel.find_bone(skin.get_bind_name(bind))


## The species standing in its idle, neutral face, turned `yaw` (PI faces the camera on +z).
func _posed(vp: SubViewport, id: String, yaw: float) -> Node3D:
	var k := Shots.rigged_kin(id)
	vp.add_child(k)
	k.rotation.y = yaw
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	rig.set_face("neutral")
	rig.seek(0.5)
	rig.set_process(false)  # held on that frame, so the two close-ups differ only by the face
	return k


func _face_tris(id: String) -> int:
	var k := Shots.rigged_kin(id)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var n := _tris(rig.face.mesh) if rig.face else 0
	k.free()
	return n


func _coat_tris(id: String) -> int:
	var k := Shots.rigged_kin(id)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var n := 0
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		if mi != rig.face:
			n += _tris((mi as MeshInstance3D).mesh)
	k.free()
	return n


static func _tris(mesh: Mesh) -> int:
	var n := 0
	for si in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


## boki_rig_shots' stage: its sky, sun and (with `ground`) grass.
func _stage(size: Vector2i, ground: bool) -> SubViewport:
	var s := Shots.new()
	s.main = main
	return s._stage(size, ground)


func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(vp: SubViewport, file: String) -> void:
	var img: Image = await _grab(vp)
	img.save_png(out.path_join(file))
	vp.queue_free()
