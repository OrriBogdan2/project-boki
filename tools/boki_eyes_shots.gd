extends RefCounted
## --boki-eyes-shots --shots-dir=<dir> [--species=a,b] [--px=640]: does each rigged Boki's coat carry its own eyes?
## Per species, as the game builds it (idle, neutral): <dir>/<id>_off.png, the front of the whole Boki with the face
## overlay off (BokiRig.face_overlay, the default), <id>_on.png the same with it on, and <id>_game.png, a crop at
## the match camera (overlay off). <dir>/eyes.tsv: id, Face tris dropped, coat tris. Needs a renderer (GPU worker).

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
const CLOSE_FOV := 18.0  # deg
const CLOSE_PITCH := deg_to_rad(8.0)  # the close camera a little above the middle
const CLOSE_MARGIN := 1.08  # the frame on the Boki's bounds
const GAME_RES := Vector2i(1920, 1080)
const GAME_CROP := 96  # px of the 1080p match frame kept round the Boki
const GAME_ENLARGE := 3  # nearest-neighbour, so the game's pixels stay readable
const GAME_YAW := PI * 0.8  # its front three-quarters, as boki_rig_shots' match.png

var main: Node
var out := ""
var px := 640
var only: Array = []


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--px="):
			px = int(a.substr(5))
		if a.begins_with("--species="):
			only = Array(a.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var tsv := ["id\tface_tris\tcoat_tris"]
	for id in only if not only.is_empty() else Rig.SPECIES_LIST:
		BokiRig.face_overlay = true
		tsv.append("%s\t%d\t%d" % [id, _face_tris(String(id)), _coat_tris(String(id))])
		await _close(String(id), "on")
		BokiRig.face_overlay = false
		await _close(String(id), "off")
		await _game(String(id))
	var f := FileAccess.open(out.path_join("eyes.tsv"), FileAccess.WRITE)
	f.store_string("\n".join(tsv) + "\n")
	f.close()
	print("BOKI_EYES_SHOTS_DONE")
	main.get_tree().quit()


## A front view of the whole Boki, framed on its bounds (FRAME's "head" is not its eyes on every species).
func _close(id: String, tag: String) -> void:
	var vp := _stage(Vector2i(px, px), false)
	var k := _posed(vp, id, PI)
	var box := k.global_transform * Shots._box(k)
	var mid := box.get_center()
	var size := maxf(box.size.x, box.size.y) * CLOSE_MARGIN
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = CLOSE_FOV
	cam.near = 0.05
	var dist := size * 0.5 / tan(deg_to_rad(CLOSE_FOV) * 0.5) + box.size.z
	cam.position = mid + Vector3(0, sin(CLOSE_PITCH), cos(CLOSE_PITCH)) * dist
	cam.look_at(mid)
	cam.make_current()
	await _save(vp, "%s_%s.png" % [id, tag])


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


## The species standing in its idle, neutral face, turned `yaw` (PI faces the camera on +z).
func _posed(vp: SubViewport, id: String, yaw: float) -> Node3D:
	var k := Shots.rigged_kin(id)
	vp.add_child(k)
	k.rotation.y = yaw
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	rig.set_face("neutral")
	rig.seek(0.5)
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
