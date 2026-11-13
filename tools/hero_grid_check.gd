extends RefCounted
## --hero-grid-check [--shots-dir=<dir>]: the Relics screen's tile grid at 1280x720 and 1920x1080. Every Hunter has a
## tile in the canonical order (Arch.ORDER, Gil included) reading "<Name>" with "the <Title>" smaller under it; no
## tile label is clipped, ellipsed or wider than its tile, a title wraps to at most two lines, and the whole grid
## shows without scrolling (the right column and Mastery may still scroll).
## With --shots-dir: relics_<W>x<H>.png (needs a real renderer: jobq submit --needs gpu).

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MAX_LINES := 2          # a name or title may wrap to this many lines

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HEROGRID %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): shots = String(a).substr(12)
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()      # every Hunter open, so the order is the canonical one
	Save.d = d
	main.show_screen("home", {})
	var guard := 0
	while guard < 600 and (main.current == null or main.current.get("player") == null):
		guard += 1
		await tree.create_timer(0.1).timeout
	var hm: Node = main.current
	for i in 90: await tree.process_frame
	for win in SIZES:
		tree.root.size = win
		for i in 10: await tree.process_frame
		HomeClasses.open(hm)
		for i in 20: await tree.process_frame
		_size_rows(hm, win)
		if shots != "": tree.root.get_texture().get_image().save_png("%s/relics_%dx%d.png" % [shots, win.x, win.y])
		hm._close_panel()
	hm.queue_free()
	print("HEROGRID CHECK DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

func _size_rows(hm: Node, win: Vector2i) -> void:
	var at := "%dx%d" % [win.x, win.y]
	var grid: GridContainer = hm.get_meta("hero_grid")
	var archs: Array = grid.get_children().map(func(c): return String(c.get_meta("arch", "")))
	ok(archs == Arch.ORDER, "%s: a tile per Hunter in the canonical order (%s)" % [at, str(archs)])
	var labels := 0
	for tile in grid.get_children():
		for l in _labels(tile):
			labels += 1
			_label_row(l as Label, "%s: tile '%s' label '%s'" % [at, tile.get_meta("arch"), l.text])
			var inside: bool = tile.get_global_rect().grow(0.5).encloses(l.get_global_rect())
			ok(inside, "%s: tile '%s' label '%s' stays inside the tile" % [at, tile.get_meta("arch"), l.text])
	ok(labels >= archs.size() * 2, "%s: every tile has a name and a title label (%d)" % [at, labels])
	var sc: Node = grid
	while sc != null and not sc is ScrollContainer:
		sc = sc.get_parent()
	var seen: Rect2 = (sc as ScrollContainer).get_global_rect()
	var last: Rect2 = grid.get_children().back().get_global_rect()
	ok(seen.encloses(last), "%s: the grid shows without scrolling (bottom %.0f of %.0f)" % [at, last.end.y, seen.end.y])

## One label: not clipped or ellipsed, its widest word fits, at most MAX_LINES lines.
func _label_row(lab: Label, what: String) -> void:
	var font := lab.get_theme_font("font")
	var px := lab.get_theme_font_size("font_size")
	var widest := 0.0
	for w in lab.text.split(" "):
		widest = maxf(widest, font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var plain: bool = not lab.clip_text and lab.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
	ok(plain, what + " is not clipped or ellipsed")
	var fits: bool = widest <= lab.size.x + 0.5 and lab.get_line_count() <= MAX_LINES
	ok(fits, what + " fits (%d lines, widest word %.0f of %.0f px)" % [lab.get_line_count(), widest, lab.size.x])

func _labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label: out.append(c)
		out.append_array(_labels(c))
	return out
