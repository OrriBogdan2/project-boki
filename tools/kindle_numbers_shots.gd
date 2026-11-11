extends RefCounted
## --kindle-numbers-shots --shots-dir=<dir>: Meeko (Pip the Tender) holds LMB on a rival dummy at match zoom;
## kn_1, kn_2, kn_3 are the centre of the screen as the Kindle stack builds, so the damage numbers can be
## compared before and after the stack tint (docs/heroes/tender.md footage gap 9). <dir>/captions.txt names each.

const DT := 1.0 / 60.0
const AT := [0.5, 1.3, 2.2]       # s of held fire at each shot

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var sc = load("res://tools/support_check.gd").new()
	sc.main = main
	var r: Array = sc.setup("tender", 5.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	P.inp["fire"] = true
	var lines: Array = []
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
		var sz := img.get_size()
		img.get_region(Rect2i(sz.x / 4, sz.y / 4, sz.x / 2, sz.y / 2)).save_png(dir.path_join("kn_%d.png" % (i + 1)))
		lines.append("kn_%d.png: %.1f s of held LMB, Kindle %d on the target" % [i + 1, t, K.kindle_on(T)])
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("KINDLENUMBERSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)
