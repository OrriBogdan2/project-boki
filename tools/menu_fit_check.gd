extends RefCounted
## --menu-fit-check [--shots-dir=<dir>]: every Esc-menu page and Settings tab at 1280x720, 1920x1080 and a
## 2560x1080 ultrawide, with Text size 100% and 150% (and the biggest Interface size). Fails on
##   1. the page's panel leaving the window,
##   2. a control outside its panel (inside a scroll list only sideways: it scrolls up and down),
##   3. text cut off (a one-line label or button wider than its box, wrapped text taller than its box),
##   4. two controls overlapping.
## With --shots-dir (needs a real window: xvfb-run -a godot --rendering-driver opengl3) each state is saved as a png.
## Never touches the real save.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]
const TEXTS := [1.0, 1.5]  # Text size setting: 100% and 150%
const BIG_UI := 1.1  # the largest Interface size (Settings.UI_SCALE_MAX), once at 1280x720
const SLACK := 1.5  # px: rounding
const OVERLAP := 3.0  # px: two controls may share this much of an edge
const POP_FRAMES := 120  # frames a page gets to finish its pop-in

var bad := 0
var main: Node
var tree: SceneTree
var shots := ""
var box: Control  # the confirm box over the page, while one is open


func ok(cond: bool, what: String) -> void:
	if not cond:
		print("MENUFIT FAIL ", what)
		bad += 1


func run(mn: Node) -> void:
	main = mn
	tree = mn.get_tree()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(shots)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	Save.d = d
	var states := 0
	Game.goto("home")
	for _i in 20:
		await tree.process_frame
	var match_node := Match.new()
	main.add_child(match_node)
	await match_node.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	match_node.set_process(false)
	var home: Node = main.current
	for text_size: float in TEXTS:
		Settings.v["text_size"] = text_size
		UI.set_text_size(text_size)
		for sz: Vector2i in SIZES:
			for ui in [1.0, BIG_UI] if sz == SIZES[0] else [1.0]:
				Settings.v["ui_scale"] = ui
				main.get_window().size = sz
				Settings._apply_ui_scale()
				for _i in 3:
					await tree.process_frame
				for pg in _pages():
					main.current = match_node if pg["where"] == "match" else home
					Overlay.ctx = pg["where"]
					Overlay.close()
					Overlay.tab = "Main"
					Overlay.search = ""
					Overlay.more_tabs = false
					await tree.process_frame
					(pg["open"] as Callable).call()
					await _settle()
					var tag := "%dx%d text %d%% ui %d%% %s" % [sz.x, sz.y, text_size * 100, ui * 100, pg["name"]]
					_audit(tag)
					if is_instance_valid(box):
						box.free()
					states += 1
					if shots != "":
						var png := tag.replace(" ", "_").replace("%", "").replace(":", "")
						tree.root.get_texture().get_image().save_png(shots.path_join(png + ".png"))
	Overlay.close()
	main.current = home
	match_node.queue_free()
	print("MENUFIT %s: %d states, %d failed" % ["PASS" if bad == 0 else "FAIL", states, bad])
	tree.quit(1 if bad > 0 else 0)


## [{name, where, open}]: each Esc page, in the places that differ (home, a match), then every Settings tab.
func _pages() -> Array:
	var list: Array = []
	for where in ["home", "match"]:
		list.append({"name": where + ":pause", "where": where, "open": Overlay.open_pause.bind(where)})
		list.append({"name": where + ":more", "where": where, "open": Overlay.open_more})
	list.append({"name": "controls", "where": "home", "open": Overlay.open_controls})
	list.append({"name": "help", "where": "home", "open": Overlay.open_words})
	list.append({"name": "saves", "where": "home", "open": Overlay.open_saves})
	list.append({"name": "inventory", "where": "home", "open": Overlay.open_inventory})
	list.append({"name": "match:practice", "where": "match", "open": _open_practice})
	list.append({"name": "match:leave-box", "where": "match", "open": _open_leave_box})
	for t in Overlay.SETTINGS_TABS:
		list.append({"name": "settings:" + String(t), "where": "home", "open": _open_tab.bind(t)})
	list.append({"name": "settings:search", "where": "home", "open": _open_search})
	return list


func _open_tab(t: String) -> void:
	Overlay.tab = t
	Overlay.open_settings()


func _open_search() -> void:
	Overlay.search = "e"
	Overlay.open_settings()


func _open_practice() -> void:
	Overlay.open_practice((main.current as Match).player)


func _open_leave_box() -> void:
	Overlay.open_pause("match")
	box = UI.confirm(Overlay.root, "Leave the match?", "You lose what you carry.", "Leave", Overlay.close)


## Until the page's pop-in has finished (its scale is 1) and the layout is sized.
func _settle() -> void:
	for _i in 4:
		await tree.process_frame
	for _i in POP_FRAMES:
		var shell := _panel()
		if shell == null or (shell.scale - Vector2.ONE).length() < 0.001 and shell.modulate.a > 0.999:
			break
		await tree.process_frame
	for _i in 4:
		await tree.process_frame


func _shell() -> Control:
	var n := Overlay.host.get_child_count()
	return Overlay.host.get_child(n - 1) as Control if n > 0 else null


## A confirm box sits on Overlay.root, over the page: it is the panel to test then.
func _panel() -> Control:
	return box.get_child(1).get_child(0) as Control if is_instance_valid(box) else _shell()


func _audit(tag: String) -> void:
	var panel := _panel()
	if panel == null:
		ok(false, tag + ": no page opened")
		return
	var view := panel.get_viewport().get_visible_rect()
	var pr := panel.get_global_rect()
	ok(view.grow(SLACK).encloses(pr), "%s: panel %s leaves the window %s" % [tag, pr, view])
	var leaves: Array[Control] = []
	for c in panel.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and _is_leaf(ctl) and ctl.get_global_rect().size.x > 0.0:
			leaves.append(ctl)
	for ctl in leaves:
		_audit_one(tag, panel, pr, ctl)
	_audit_overlaps(tag, leaves)


func _is_leaf(c: Control) -> bool:
	return c is BaseButton or c is Label or c is Range or c is LineEdit or c is RichTextLabel or c is TextureRect


## The scroll list a control sits in, if any.
func _scroller(c: Control, panel: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p != null and p != panel.get_parent():
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


func _audit_one(tag: String, panel: Control, pr: Rect2, c: Control) -> void:
	var r := c.get_global_rect()
	var what := "%s '%s' %s" % [c.get_class(), _text_of(c).left(30), c.name]
	var sc := _scroller(c, panel)
	if sc == null:
		ok(pr.grow(SLACK).encloses(r), "%s: %s at %s is outside its panel %s" % [tag, what, r, pr])
	else:
		var sr := sc.get_global_rect()
		ok(
			r.position.x >= sr.position.x - SLACK and r.end.x <= sr.end.x + SLACK,
			"%s: %s at %s sticks out sideways from its list %s" % [tag, what, r, sr]
		)
	var cut := _text_cut(c)
	ok(cut == "", "%s: %s text cut off: %s" % [tag, what, cut])


func _text_of(c: Control) -> String:
	if c is Button:
		return (c as Button).text
	if c is Label:
		return (c as Label).text
	return ""


## "" when the text fits its box; else what is wrong.
func _text_cut(c: Control) -> String:
	var txt := _text_of(c)
	if txt == "":
		return ""
	var font := c.get_theme_font("font")
	var fsize := c.get_theme_font_size("font_size")
	if c is Label:
		var lab := c as Label
		if lab.autowrap_mode != TextServer.AUTOWRAP_OFF:
			var lines := lab.get_line_count()
			var need := lines * lab.get_line_height() + (lines - 1) * lab.get_theme_constant("line_spacing")
			return "wrapped text needs %d px, box is %d" % [need, lab.size.y] if need > lab.size.y + SLACK else ""
		var w := font.get_string_size(txt, lab.horizontal_alignment, -1, fsize).x
		return "needs %d px, box is %d" % [w, lab.size.x] if w > lab.size.x + SLACK else ""
	var b := c as Button
	var style := b.get_theme_stylebox("normal")
	var inner := b.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	var tw := font.get_string_size(txt, b.alignment, -1, fsize).x
	if b.icon != null:
		tw += b.icon.get_width() + b.get_theme_constant("h_separation")
	return "needs %d px, box is %d" % [tw, inner] if tw > inner + SLACK else ""


func _audit_overlaps(tag: String, leaves: Array[Control]) -> void:
	var seen: Array[Rect2] = []
	for c in leaves:
		seen.append(_seen_rect(c))
	for i in leaves.size():
		var a := leaves[i]
		if a is TextureRect:
			continue
		for j in range(i + 1, leaves.size()):
			var b := leaves[j]
			if b is TextureRect or a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var x := seen[i].intersection(seen[j])
			if x.size.x > OVERLAP and x.size.y > OVERLAP:
				ok(
					false,
					(
						"%s: %s '%s' overlaps %s '%s' by %s"
						% [tag, a.get_class(), _text_of(a).left(20), b.get_class(), _text_of(b).left(20), x.size]
					)
				)


## The part of a control that can be seen: what a scroll list around it does not cut off.
func _seen_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null and p != Overlay.root:
		if p is ScrollContainer:
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r
