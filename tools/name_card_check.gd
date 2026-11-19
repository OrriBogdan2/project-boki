extends RefCounted
## --name-card-check [--shots-dir=<dir> --shots-tag=<tag>]: the real "Name your <Boki>" card of the hatch
## screen (HatchScreen, stage "name") at the window's own size. Every wrapping Label on it is at least
## MIN_WRAP_W wide and breaks into a handful of lines (a wrapping Label in a shrinking row once collapsed
## to a column of one letter per line, running off the top of the screen), and the card fits the window.
## With --shots-dir the screen is saved as name_card_<tag>_<w>x<h>.png (run it under xvfb with a renderer,
## --resolution 1920x1080 or 1280x720).

const MIN_WRAP_W := 200.0      # px: a wrapping line narrower than this is a column of fragments
const MAX_WRAP_LINES := 4      # the longest sentence on the card wraps to a few lines at most
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("NAMECARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var dir := ""
	var tag := "after"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--shots-tag="):
			tag = String(a).substr(12)
	Save.d["look"] = Unmasked.default_look()
	Save.d["tutorial"]["intro"] = true      # (no opening card over the screen)
	main.fade.visible = false      # (the boot splash and ink wipes cover the screen)
	main.show_screen("hatch", {})
	await main.get_tree().process_frame
	var hatch: Node = main.current
	hatch.chosen = 0
	hatch.stage = "name"
	hatch._show_name()
	for i in 30:
		await main.get_tree().process_frame
	var win := main.get_viewport().get_visible_rect().size
	var wraps := 0
	for l in _labels(hatch.root_ui):
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF or not l.is_visible_in_tree():
			continue
		wraps += 1
		var lines := l.get_line_count()
		var what := "'%s' %dx%d, %d lines" % [l.text.left(24), l.size.x, l.size.y, lines]
		ok(l.size.x >= MIN_WRAP_W, "wrapping label wide enough: " + what)
		ok(lines <= MAX_WRAP_LINES, "wrapping label not a column: " + what)
	ok(wraps >= 3, "the card's wrapping lines were found (%d)" % wraps)
	var card := _card(hatch.bottom)
	var r := card.get_global_rect()
	ok(r.position.y >= 0.0 and r.end.y <= win.y, "the card fits the window height: %s in %s" % [r, win])
	ok(r.position.x >= 0.0 and r.end.x <= win.x, "the card fits the window width: %s in %s" % [r, win])
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("name_card_%s_%dx%d.png" % [tag, int(win.x), int(win.y)]))
	print("NAMECARD done, bad=%d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _card(box: Node) -> Control:
	return box.get_child(box.get_child_count() - 1) as Control


func _labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out
