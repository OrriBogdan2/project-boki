extends RefCounted
## --sable-hair-shots --shots-dir=<dir> [--size=1920x1080]: Sable at the match camera and closer, in a real match's
## world and light, under each hair-colour pick in HAIRS (the 11-11 "Sable has pink hair" report): her approved
## hair is white, whatever the player picked. Writes hair_<pick>.png and hair_<pick>_close.png. Needs a renderer.

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
		h.rotation.y = PI
		m.cam.user_zoom = 1.0
		m.cam.snap(c)
		await _grab("hair_%d.png" % pick)
		m.cam.user_zoom = 0.3
		m.cam.snap(c)
		await _grab("hair_%d_close.png" % pick)
		h.queue_free()
	print("SABLE-HAIR-SHOTS done ", dir)

func _grab(file: String) -> void:
	for i in 30:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("SABLE-HAIR-SHOT ", file)
