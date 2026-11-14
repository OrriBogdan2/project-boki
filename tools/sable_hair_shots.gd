extends RefCounted
## --sable-hair-shots --shots-dir=<dir> [--size=1920x1080]: Sable at the match camera and closer, in a real match's
## world and light, under each hair-colour pick in HAIRS (the 11-11 "Sable has pink hair" report): her approved
## hair is white, whatever the player picked. Per pick: hair_<pick>.png (match camera), hair_<pick>_close.png
## (pulled in, dist_mul 0.3), hair_<pick>_head.png (a crop of that around her), hair_<pick>_back.png and
## hair_<pick>_braid.png (the same from behind). hair_7 also writes face.png (from the front at head
## height). Prints the hair and eye colours the model is handed. Needs a renderer; the paint is --warden-glb-check.

const HAIRS := [0, 7, 14]      # PlayerLook hair_col picks: dark brown, pink, lilac

var main: Node
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	var px := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			px = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = px
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "god": true, "length": 1e9})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.visible = false
	var c := m.player.pos + Vector3(0, 0, 4.0)
	for pick in HAIRS:
		var look := PlayerLook.neutral()
		look["hair_col"] = pick
		var h := Models.hunter(Arch.weight("thief"), Data.TEAM_COLORS[0], Arch.signature("thief"), "", look, "thief")
		m.add_child(h)
		h.global_position = Vector3(c.x, m.world.ground_at(c.x, c.z), c.z)
		h.rotation.y = PI       # facing the match camera
		var p := MantleLook.params("thief", look)
		print("SABLE-HAIR pick %d hair %s eyes %s" % [pick, (p["hair_col"] as Color).to_html(false),
			(p["eye_col"] as Color).to_html(false)])
		m.cam.dist_mul = 1.0
		m.cam.snap(c)
		await _grab("hair_%d.png" % pick)
		m.cam.dist_mul = 0.3
		m.cam.snap(c)
		var img := await _grab("hair_%d_close.png" % pick)
		var at := img.get_size() / 2 + Vector2i(0, img.get_height() / 14)   # (the camera leads her a little)
		var half := img.get_height() / 7
		var r := Rect2i(Vector2i(at) - Vector2i(half, half), Vector2i(half * 2, half * 2)).intersection(
				Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(r).save_png(dir.path_join("hair_%d_head.png" % pick))
		h.rotation.y = 0.0      # her back to the camera: the braid
		img = await _grab("hair_%d_back.png" % pick)
		img.get_region(r).save_png(dir.path_join("hair_%d_braid.png" % pick))
		if pick == HAIRS[1]:
			await _face(m, h)
		h.queue_free()
	print("SABLE-HAIR-SHOTS done ", dir)
	main.get_tree().quit()

## Her face from the front at head height, in the match's own world and light (a second camera; the match camera
## looks down on her crown): the eyes stay solid grey-black whatever the eye pick. Writes face.png.
func _face(m: Match, h: Node3D) -> void:
	h.rotation.y = PI
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 30.0
	var head := h.global_position + Vector3(0, 1.45, 0)
	cam.global_position = head + Vector3(0, 0.1, 2.2)
	cam.look_at(head)
	cam.make_current()
	await _grab("face.png")
	cam.queue_free()
	m.cam.make_current()

func _grab(file: String) -> Image:
	for i in 30:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file))
	print("SABLE-HAIR-SHOT ", file)
	return img
