extends RefCounted
## --roster-shots --shots-dir=<dir> [--px=2400]: <dir>/lineup.png, the 50 Boki as the game builds them, in a grid:
## the modelled ones first (rigged), then the placeholders. Prints the counts. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const COLS := 10
const GAP := 2.3          # metres between the grid cells
const ROW_GAP := 2.9

func run(main: Node) -> void:
	var out := ""
	var width := 2400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): width = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var ids: Array = Data.KIN.keys()
	ids.sort()
	var modelled: Array = ids.filter(func(i): return BokiRig.has(i))
	var placeholder: Array = ids.filter(func(i): return not BokiRig.has(i))
	var order := modelled + placeholder
	var rows := ceili(order.size() / float(COLS))
	var shots := Shots.new()
	shots.main = main
	var vp := shots._stage(Vector2i(width, int(width * rows * ROW_GAP / (COLS * GAP))))
	for i in order.size():
		var k := Models.kin(order[i], Save.new_kin(order[i]))
		k.position = Vector3((i % COLS - (COLS - 1) * 0.5) * GAP, 0, (i / COLS - (rows - 1) * 0.5) * ROW_GAP)
		k.rotation.y = 0.0
		vp.add_child(k)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 44.0
	cam.far = 400.0
	cam.position = Vector3(0, 9.0, rows * ROW_GAP * 0.5 + 15.0)
	cam.look_at(Vector3(0, 0.0, 1.5))
	for k in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join("lineup.png"))
	print("ROSTER_SHOTS modelled %d, placeholder %d" % [modelled.size(), placeholder.size()])
	main.get_tree().quit()
