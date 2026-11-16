extends RefCounted
## --hud-safe-shots --size=WxH --shots-dir=<dir>: the real match HUD, the pause menu and the settings menu
## at one window size (GPU, under xvfb with a renderer), each saved twice: plain, and with the HudStyle safe
## margin outlined in magenta so a block over the line shows. Prints how many menu controls leave the margin.

const GUIDE := Color(1.0, 0.2, 0.9)
const LINE := 2.0      # px, the outline

var main: Node
var dir := "hud_safe_shots"

func _grab(label: String) -> void:
	for i in 12:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var path := dir.path_join("%dx%d_%s" % [img.get_width(), img.get_height(), label])
	img.save_png(path + ".png")
	var safe := HudStyle.safe_rect(Vector2(img.get_size()))
	var h := Vector2(safe.size.x, LINE)
	var v := Vector2(LINE, safe.size.y)
	var edges := [Rect2(safe.position, h), Rect2(safe.end - h, h), Rect2(safe.position, v), Rect2(safe.end - v, v)]
	for edge: Rect2 in edges:
		img.fill_rect(Rect2i(edge), GUIDE)
	img.save_png(path + "_guide.png")
	print("HUDSAFE-SHOT ", path)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	var opts := {"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true}
	opts.merge({"heart": true, "god": true, "length": 1e9})
	await m.start(opts)
	m.set_process(false)
	if main.fade != null:
		await main.fade.reveal(0.01)
	await main.get_tree().create_timer(0.5).timeout      # let the window settle at its size
	for i in 30:
		m.step(Match.DT)
		await main.get_tree().process_frame
	await _grab("hud")
	for which in [["pause"], ["settings", "Video"]]:
		Overlay.shot_demo(PackedStringArray(which))
		await main.get_tree().create_timer(0.6).timeout
		await _grab(String(which[0]))
		var bad := _outside(Overlay.host, HudStyle.safe_rect(Overlay.host.get_viewport_rect().size))
		print("HUDSAFE %s controls outside the safe margin: %d %s" % [which[0], bad.size(), bad.slice(0, 3)])
		Overlay.close()
	main.get_tree().quit()

func _outside(node: Node, safe: Rect2) -> Array:
	var bad: Array = []
	for c in node.find_children("*", "PanelContainer", true, false):
		if c.is_visible_in_tree() and not safe.grow(1.0).encloses((c as Control).get_global_rect()):
			bad.append("%s at %s" % [c.get_class(), (c as Control).get_global_rect()])
	return bad
