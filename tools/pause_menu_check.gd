extends RefCounted
## --pause-menu-check: the Esc menu (DECISIONS 2026-11-08, "UI is too much for a new player").
##   1. in every place (farm, town, home inside, a match, the Training Grounds, the tutorial, an arena)
##      the front page has at most 4 buttons, with More among them
##   2. every action the menu had before the cut is still on the front page or under More
##   3. every label is one plain line (no line break, at most 22 letters)
##   4. at 1280x720, 1920x1080, 2560x1080 and 3440x1440 both pages sit inside the title-safe margin

var bad := 0
var main: Node
var tree: SceneTree

const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3440, 1440)]
const MAX_FRONT := 4
const MAX_LABEL := 22
const SAFE_FRAC := 0.04      # as the prematch screen's title-safe margin
const SAFE_MIN := 24.0

func ok(cond: bool, what: String) -> void:
	print("PAUSEMENU %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	tree = mn.get_tree()
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	Save.d = d
	# the actions the menu had before the cut (ext/ui-pause-more), by place
	var always: Array = ["Resume", "Settings", "Controls"] + (["Admin tools"] if Overlay.admin_allowed() else []) \
		+ ([] if OS.has_feature("web") else ["Quit game"])
	var home := await _go("home")
	var farm: Array = ["Save and leave", "Inventory", "Save files", "Change your look", "Training Grounds"]
	await _place("farm", "home", always + farm + (["I'm stuck"] if home.has_method("unstick") else []))
	await _fit()
	for p in ["town", "interior"]:
		await _place(p, p, always + ["Save and leave", "Inventory", "Save files"])
	var matches := {
		"training": [{"training": true, "practice": true}, ["Leave", "Change Hunter"]],
		"tutorial": [{"tutorial": true}, ["Skip the tutorial", "Change Hunter"]],
		"arena": [Match.arena_opts("gunslinger"), ["Leave", "Change Hunter"]],
		"match": [{"teams": 2}, ["Leave match"]],
	}
	for area in matches:
		var o: Dictionary = OPTS.duplicate()
		o.merge(matches[area][0], true)
		var m := Match.new()
		main.add_child(m)
		await m.start(o)
		m.set_process(false)
		for i in 5: await tree.process_frame
		var was: Node = main.get("current")
		main.set("current", m)
		await _place(area, "match", always + matches[area][1] + (["I'm stuck"] if m.has_method("unstick") else []))
		main.set("current", was)
		m.queue_free()
		await tree.process_frame
	print("PAUSEMENU DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

func _go(screen: String) -> Node:
	Game.goto(screen)
	for i in 20:
		await tree.process_frame
	return main.current

func _labels() -> Array:
	var btns: Array = Overlay.host.find_children("*", "Button", true, false)
	# (the panel's icon-only close button has no text)
	return btns.map(func(b): return String((b as Button).text)).filter(func(t): return t != "")

func _place(tag: String, where: String, want: Array) -> void:
	Overlay.open_pause(where)
	await tree.process_frame
	var front := _labels()
	ok(front.size() <= MAX_FRONT and front.has("More"),
		"%s: %d buttons up front, More among them %s" % [tag, front.size(), str(front)])
	Overlay.open_more()
	await tree.process_frame
	var more := _labels()
	ok(Overlay.page == "more", "%s: More opens its page" % tag)
	var all := front + more
	var lost := want.filter(func(a): return not all.has(a))
	ok(lost.is_empty(), "%s: every old action is reachable (missing %s)" % [tag, str(lost)])
	var long := all.filter(func(t: String): return t.contains("\n") or t.length() > MAX_LABEL)
	ok(long.is_empty(), "%s: one-line labels (%s)" % [tag, str(long)])
	Overlay.back()
	await tree.process_frame
	ok(Overlay.page == "pause", "%s: Back from More returns to the menu" % tag)
	Overlay.close()
	await tree.process_frame

## Both pages inside the title-safe margin at each window size (the UI scales with the window).
func _fit() -> void:
	var win := main.get_window()
	var was := win.size
	for sz: Vector2i in SIZES:
		win.size = sz
		Settings._apply_ui_scale()
		for pg in ["pause", "more"]:
			Overlay.open_pause("home")
			if pg == "more": Overlay.open_more()
			for i in 3: await tree.process_frame
			var vis := Overlay.host.get_viewport().get_visible_rect()
			var k := tree.root.content_scale_factor
			var m := maxf(SAFE_MIN, sz.y * SAFE_FRAC) / maxf(k, 0.01)
			var safe := vis.grow(-m)
			var r: Rect2 = (Overlay.host.get_child(0) as Control).get_global_rect()
			ok(safe.encloses(r), "%dx%d %s: inside the safe area (panel %s, safe %s)"
				% [sz.x, sz.y, pg, str(r), str(safe)])
			Overlay.close()
			await tree.process_frame
	win.size = was
	Settings._apply_ui_scale()
