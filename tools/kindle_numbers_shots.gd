extends RefCounted
## --kindle-numbers-shots --shots-dir=<dir>: Meeko (Pip the Tender) holds LMB on a rival dummy at match zoom and
## the area round the target is saved as the Kindle stack builds (docs/heroes/tender.md footage gap 9):
##   plain_1..3   the stack tint switched off (her Kindle max raised so the tint stays near 0): the old numbers
##   warm_1..3    the shipped numbers: warmer and a little bigger per stack
## <dir>/captions.txt names each file.

const DT := 1.0 / 60.0
const AT := [0.5, 1.3, 2.2]       # s of held fire at each shot
const PLAIN_MAX := 1000           # a Kindle max this high leaves num_warm at about 0

var main: Node
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.current:
		main.current.queue_free()      # (the title screen Main opened)
		main.current = null
		for i in 2:
			await main.get_tree().process_frame
	await _pass(dir, "plain", PLAIN_MAX)
	await _pass(dir, "warm", 0)
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("KINDLENUMBERSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _pass(dir: String, tag: String, max_override: int) -> void:
	var sc = load("res://tools/support_check.gd").new()
	sc.main = main
	var r: Array = sc.setup("tender", 5.0)
	var m: Match = r[0]
	main.current = m
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	var was = K.res_def().get("max", 5)
	if max_override > 0:
		K.res_def()["max"] = max_override
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.inp["fire"] = true
	var t := 0.0
	for i in AT.size():
		while t < AT[i]:
			sc.aim_at(P, T.pos)
			for mb in m.mobs:
				mb.queue_free()
			m.mobs.clear()
			m.step(DT)
			m.cam.snap(P.pos)
			P.render(DT, 1.0)
			t += DT
			await main.get_tree().process_frame
		await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		var at := Vector2i(m.cam.unproject_position(T.pos + Vector3(0, 1.2, 0)))
		var box := Rect2i(at - Vector2i(160, 130), Vector2i(320, 220))
		var crop := img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.save_png(dir.path_join("%s_%d.png" % [tag, i + 1]))
		lines.append("%s_%d.png: %.1f s of held LMB, Kindle %d on the target" % [tag, i + 1, t, K.kindle_on(T)])
	K.res_def()["max"] = was
	m.queue_free()
	await main.get_tree().process_frame
