extends "res://tools/vv_shots.gd"
## --boki-world-shots --shots-dir=<dir> [--species=a,b,c] [--tag=name]: a real expedition match (tier 0, the
## default map, two teams) with a wild Boki of each listed species placed beside the hero at match zoom. Writes
## <dir>/world_<species>.png (crop round the Boki), <dir>/world_sheet.png (all of them) and <dir>/world_report.txt:
## the model each Boki really loaded (BokiRig present, its .glb path) and how many wild Boki of each species the
## match's own spawn plan placed. Needs a renderer (jobq submit --needs gpu).

const CROP_PX := Vector2i(380, 300)
const ZOOM := 1.6
const COLS := 4

var species: Array = [
	"casquebill", "duskapi", "glaciyak", "heatherhorn", "kilnbadger", "moonloris", "velvorm", "tuatrune"
]


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--species="):
			species = Array(arg.substr(10).split(","))
		if arg == "--face":
			face = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var rep := PackedStringArray()
	var natural := {}
	for k in m.kins:
		natural[k.species] = int(natural.get(k.species, 0)) + 1
	rep.append("wild Boki at match start: %d, species: %s" % [m.kins.size(), JSON.stringify(natural)])
	var crops: Array[Image] = []
	for sp in species:
		var rec := Save.new_kin(String(sp), "", m.kin_seed("world_shot"))
		var k: Kin = m.spawn_wild(rec, P.pos + Vector3(3.5, 0, 0))
		await _go(0.6)
		var rig := k.find_child("BokiRig", true, false)
		rep.append(
			"%s: rigged=%s glb=%s" % [sp, rig != null, BokiRig.PATH % [sp, sp] if rig != null else "primitive body"]
		)
		var img := main.get_viewport().get_texture().get_image()
		var c := _crop(img, k.position + Vector3(0, 0.45, 0), CROP_PX, ZOOM)
		c.save_png(dir.path_join("world_%s.png" % sp))
		if face:
			await _face_shots(k, String(sp))
		crops.append(c)
		m.kins.erase(k)
		k.queue_free()
	if not crops.is_empty():
		var w := crops[0].get_width()
		var h := crops[0].get_height()
		var rows := int((crops.size() + COLS - 1) / float(COLS))
		var sheet := Image.create(w * mini(COLS, crops.size()), h * rows, false, Image.FORMAT_RGB8)
		for i in crops.size():
			var at := Vector2i((i % COLS) * w, (int(i / float(COLS))) * h)
			sheet.blit_rect(crops[i], Rect2i(Vector2i.ZERO, crops[i].get_size()), at)
		sheet.save_png(dir.path_join("world_sheet.png"))
	var f := FileAccess.open(dir.path_join("world_report.txt"), FileAccess.WRITE)
	f.store_string("\n".join(rep) + "\n")
	f.close()
	print("BOKIWORLD ", "\n".join(rep))
	main.get_tree().quit(0)


var face := false


## LOCAL REVIEW ONLY (boki-face-polish-1124, not committed): eye-level views through a SubViewport on the match's
## own world (same lights, sky, ground; no HUD). front close, 3/4 close, eye-level whole body.
func _face_shots(k: Node, sp: String) -> void:
	var fm: MeshInstance3D = k.find_child("Face", true, false)
	var body: MeshInstance3D = k.find_child("Body", true, false)
	if fm == null or body == null:
		print("BOKIFACE %s: no Face/Body" % sp)
		return
	var c := fm.global_transform * fm.get_aabb().get_center()
	var bb := body.global_transform * body.get_aabb()
	var fwd := -(body.global_basis.z.normalized())
	fwd.y = 0
	fwd = fwd.normalized()
	var face_r := maxf(fm.get_aabb().size.length() * body.global_basis.get_scale().x, 0.05)
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	main.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.near = 0.01
	vp.add_child(cam)
	cam.current = true
	var views := {
		"front": [c + fwd * face_r * 3.2, c],
		"q": [c + (fwd.rotated(Vector3.UP, 0.6)) * face_r * 3.2 + Vector3(0, face_r * 0.3, 0), c],
		"body": [c + fwd.rotated(Vector3.UP, 0.35) * bb.size.length() * 2.0, bb.get_center()],
	}
	for v in views:
		cam.global_position = views[v][0]
		cam.look_at(views[v][1], Vector3.UP)
		for i in 4:
			await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(dir.path_join("face_%s_%s.png" % [sp, v]))
	print("BOKIFACE %s: eye %s fwd %s r %.3f" % [sp, c, fwd, face_r])
	vp.queue_free()


func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = P.pos
