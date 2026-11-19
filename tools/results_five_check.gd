extends RefCounted
## --results-five-check: the results screen's first view is at most 5 groups (outcome, kept, Boki, progress,
## next step), and every number and reward is still in the screen, behind "More" when it is not in the first view.
## --results-five-shots --shots-dir=<dir> [--shots-tag=<tag>]: the four screens at 1280x720 (needs a renderer).
## Never touches the save.

const MAX_GROUPS := 5
const STRIP := ["Hunters downed", "Damage", "Time"]
const GEAR := [{"t": "gear", "id": "blink", "rar": 1, "uid": "z2"}]
const HEART := {"egg": {"sp": "zapple"}, "goods": {"heartwood": 2, "starstone": 2}}

var bad := 0
var tree: SceneTree
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RESULTSFIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main_node: Node, mode := "check") -> void:
	main = main_node
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	if mode == "shots":
		await _shots()
	else:
		await _check()
		print("RESULTSFIVE DONE, failures: %d" % bad)
	tree.quit(0 if bad == 0 else 1)

func _base(extra: Dictionary) -> Dictionary:
	var r := {"extracted": false, "why": "test", "caught": [], "seeds": {}, "kin_runs": [], "tier": 0, "time": 400,
		"knocks": 2, "damage": 640, "kills": 17, "taken": 310, "downs": 1, "revives": 1}
	r.merge(extra, true)
	return r

## The four screens: extracted by the Gate with loot, died, the Heart taken, a Ways Out placing.
func _cases() -> Dictionary:
	var kin := Save.new_kin("zapple")
	return {
		"extracted": _base({"extracted": true, "how": "lair", "gems": 140, "seeds": {"sunroot": 1}, "caught": [kin],
			"haul": GEAR.duplicate(true)}),
		"died": _base({"place": 4, "squads": 10, "gems": 0, "lost_kin": []}),
		"heart": _base({"extracted": true, "how": "heart_final", "where": "the Heart", "gems": 150,
			"heart": HEART.merged({"seeds": {}, "gems": 150, "trust": 20.0})}),
		"ways": _base({"place": 3, "squads": 10}),
	}

func _screen(r: Dictionary) -> Control:
	Save.d = Save.fresh()
	Econ.ensure()
	var scr: Control = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(r)
	return scr

func _texts(n: Node, into: Array, only_shown: bool) -> Array:
	if n is Label and (not only_shown or (n as Label).is_visible_in_tree()):
		into.append((n as Label).text)
	for c in n.get_children(): _texts(c, into, only_shown)
	return into

func _has(texts: Array, part: String) -> bool:
	return texts.any(func(t): return String(t).to_upper().contains(part.to_upper()))

## The first-view groups: nodes tagged "results_group" that are showing.
func _groups(scr: Node) -> Array:
	return scr.find_children("*", "", true, false).filter(
			func(n): return n.has_meta("results_group") and (n as CanvasItem).is_visible_in_tree())

func _check() -> void:
	var cases := _cases()
	for id in cases:
		var scr := _screen(cases[id])
		var groups := _groups(scr)
		var names: Array = groups.map(func(n): return String(n.get_meta("results_group")))
		ok(groups.size() <= MAX_GROUPS and names.has("outcome") and names.has("next"),
				"%s: first view has %d groups (%s), at most %d, outcome and next among them"
				% [id, groups.size(), names, MAX_GROUPS])
		var first := _texts(scr, [], true)
		var all := _texts(scr, [], false)
		for tile in STRIP:
			ok(not _has(first, tile) and _has(all, tile), "%s: '%s' is behind More, not gone" % [id, tile])
		for part in ["Damage taken", "Times downed", "Revives", "Kills"]:
			ok(_has(all, part), "%s: '%s' is still in the screen" % [id, part])
		ok(not _has(first, "Details"), "%s: the toggle says More, not Details" % id)
		scr.queue_free()
	await _rewards(cases)

## Every reward a screen showed before is still in it (visible or behind More).
func _rewards(cases: Dictionary) -> void:
	var scr := _screen(cases["extracted"])
	var all := _texts(scr, [], false)
	for part in ["140 gems", "Sunroot", "Blink"]:
		ok(_has(all, part), "extracted: reward '%s' is reachable" % part)
	var first := _texts(scr, [], true)
	for part in ["Brought home", "Gear you"]:
		ok(_has(first, part), "extracted: '%s' stays in the first view" % part)
	scr.queue_free()
	scr = _screen(cases["heart"])
	all = _texts(scr, [], false)
	ok(_has(all, "Heart reward: a Rare Egg, 2 Heartwood, 2 Starstone."), "heart: the reward line is reachable")
	ok(_has(all, "would have paid"), "heart: the other seat's pay is reachable")
	scr.queue_free()
	scr = _screen(cases["died"])
	all = _texts(scr, [], false)
	ok(_has(all, "Your squad placed 4th of 10"), "died: the placing is reachable")
	scr.queue_free()
	scr = _screen(cases["ways"])
	ok(_has(_texts(scr, [], false), "Placement pay: 35 gems"), "ways: the placement pay is reachable")
	var dmg := _damage_tile(scr)
	var t0 := CheckClock.own_msec()
	while dmg != "640" and CheckClock.own_msec() - t0 < 4000:
		await tree.process_frame
		dmg = _damage_tile(scr)
	ok(dmg == "640", "ways: the Damage tile counts up to 640 (%s)" % dmg)
	scr.queue_free()

func _damage_tile(scr: Node) -> String:
	for l in _texts(scr, [], false):
		if String(l).is_valid_int() and int(l) >= 600: return String(l)
	return ""

func _shots() -> void:
	var dir := "shots"
	var tag := "after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
		elif a.begins_with("--shots-tag="): tag = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = Vector2i(1280, 720)
	for k in 240:
		await tree.process_frame     # past the boot's loading screen
	var cases := _cases()
	for id in cases:
		main.show_screen("results", cases[id])
		await _settle()
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("results_%s_%s.png" % [id, tag]))
		if tag == "after":
			_open_more(main)
			for k in 20:
				await tree.process_frame
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("results_%s_more.png" % id))
	print("RESULTSFIVE_SHOTS_DONE")

## Frames for the fade and the count-up, then more while the ink wipe has not cleared (a slow worker).
func _settle() -> void:
	for k in 150:
		await tree.process_frame
	for k in 900:
		if not main.fade.covered and main.fade.rect.color.a < 0.01:
			break
		await tree.process_frame
	for k in 20:
		await tree.process_frame
	await RenderingServer.frame_post_draw

func _open_more(root: Node) -> void:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("More") and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
