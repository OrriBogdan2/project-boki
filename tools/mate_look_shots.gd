extends RefCounted
## --mate-look-shots --shots-dir=<dir>: F1-F3 on the real match view (GPU, under xvfb). own_view is the normal
## camera, look_1 / look_2 / look_3 hold each key (card with name and health at the top), controls is the
## Settings > Controls list with the three binds.

var main: Node
var m: Match
var dir := ""

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _grab(file: String) -> void:
	await _frames(45)
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % file))
	print("MATELOOK-SHOT ", file)

## Scrolls the open settings list so the section header with this text sits at the top.
func _scroll_to(header: String) -> void:
	for l in main.get_tree().root.find_children("*", "Label", true, false):
		if (l as Label).text != header:
			continue
		var n: Node = l
		while n != null and not (n is ScrollContainer):
			n = n.get_parent()
		if n != null:
			var sc := n as ScrollContainer
			sc.scroll_vertical = int((l as Control).global_position.y - sc.global_position.y) + sc.scroll_vertical
		return

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 4, "tier": 0, "seed": 77, "no_drop": true, "god": true, "length": 1e9})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO   # a leftover walk would carry a mate off an edge
	var mates := m.mate_look.mates()
	var spots := [Vector3(16, 0, 0), Vector3(-14, 0, 12), Vector3(2, 0, -18)]
	for i in 3:
		# a wide search: a spot over the void would drop the mate into the abyss
		(mates[i] as Hunter).teleport(m.world.free_spot_near(m.player.pos + spots[i], [], 1.0, 0.45, 40.0))
	(mates[1] as Hunter).hp = (mates[1] as Hunter).max_hp * 0.55
	await _frames(30)
	for i in 3:
		print("MATELOOK-MATE %d %s out=%s" % [i + 1, (mates[i] as Hunter).pname, (mates[i] as Hunter).out])
	await _grab("own_view")
	for i in 3:
		Input.action_press(MateLook.ACTIONS[i])
		await _grab("look_%d" % (i + 1))
		Input.action_release(MateLook.ACTIONS[i])
	m.paused = true
	Overlay.tab = "Controls"
	Overlay.open_settings()
	await _frames(10)
	_scroll_to("SQUAD AND MAP")
	await _frames(10)
	var sc := main.get_viewport().get_texture().get_image()
	sc.save_png(dir.path_join("controls_top.png"))
	main.get_tree().quit(0)
