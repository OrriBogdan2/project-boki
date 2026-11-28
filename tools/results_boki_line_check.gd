extends RefCounted
## --results-boki-line-check: the results screen has one line per Boki you carried (lead, second) with its XP
## and bond as the save applied them, and a stolen wisp you carried says "going home". No new first-view group.
## --results-boki-line-shots --shots-dir=<dir>: the screen at 1280x720 (needs a renderer). Never touches the save.

var bad := 0
var tree: SceneTree
var main: Node


func ok(cond: bool, what: String) -> void:
	print("RESULTSBOKI %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node, mode := "check") -> void:
	main = main_node
	tree = main.get_tree()
	Save.no_write = true
	if mode == "shots":
		await _shots()
	else:
		_check()
		print("RESULTSBOKI DONE, failures: %d" % bad)
	tree.quit(0 if bad == 0 else 1)


## A fresh save with a lead and a second Boki, and a won match that carried one stolen wisp.
func _setup() -> Dictionary:
	Save.d = Save.fresh()
	Econ.ensure()
	var a := Save.new_kin("zapple", "Pip")
	var b := Save.new_kin("zapple", "Fizz")
	for k in [a, b]:
		Save.d["roster"].append(k)
		Save.register(k)
	Save.d["active"] = a["uid"]
	a["trust"] = 40.0
	b["trust"] = 40.0
	var wisp := Save.new_kin("zapple", "Wren")
	var runs := [
		{"uid": a["uid"], "events": [], "trust": 40.0, "stats": {}},
		{"uid": b["uid"], "events": [], "trust": 40.0, "stats": {}}
	]
	return {
		"a": a,
		"b": b,
		"r":
		{
			"extracted": true,
			"why": "test",
			"caught": [],
			"seeds": {},
			"kin_runs": runs,
			"tier": 0,
			"time": 400,
			"knocks": 2,
			"damage": 640,
			"kills": 5,
			"taken": 100,
			"downs": 0,
			"revives": 0,
			"wisps_home": [wisp]
		}
	}


func _texts(n: Node, into: Array) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		into.append((n as Label).text)
	for c in n.get_children():
		_texts(c, into)
	return into


## {stat: points gained} between two stat blocks, in the order the results line lists them.
func _grew(was: Dictionary, now: Dictionary) -> Dictionary:
	var out := {}
	for stat in PlayStyle.rules()["stat"].values():
		if int(now[stat]) > int(was[stat]):
			out[stat] = int(now[stat]) - int(was[stat])
	return out


## All the XP a Boki has earned: the levels behind it plus the pool toward the next.
func _total_xp(k: Dictionary) -> int:
	var n := int(k.get("xp", 0))
	for lv in range(1, int(k["level"])):
		n += Game.xp_need(lv)
	return n


func _check() -> void:
	var t := _setup()
	var a: Dictionary = t["a"]
	var b: Dictionary = t["b"]
	var before := [_total_xp(a), _total_xp(b)]
	var s := Game.apply_result((t["r"] as Dictionary).duplicate(true))
	var gains: Array = s["kin_gains"]
	ok(gains.size() == 2, "the two carried Boki each have a gain (%d)" % gains.size())
	for i in mini(2, gains.size()):
		var k: Dictionary = [a, b][i]
		var xp := _total_xp(k) - int(before[i])
		ok(int(gains[i]["xp"]) == xp, "%s: XP shown = XP the save gained (%d)" % [k["name"], xp])
		ok(
			is_equal_approx(float(gains[i]["bond"]), float(k["trust"]) - 40.0),
			"%s: bond shown = trust the save gained" % k["name"]
		)
	ok(float(gains[0]["bond"]) > 0.0, "a won run raised the lead's bond")
	ok(int(gains[0]["xp"]) > int(gains[1]["xp"]), "the second Boki gets the smaller share")
	t = _setup()
	before = [_total_xp(t["a"]), _total_xp(t["b"])]
	var stats0 := [t["a"]["stats"].duplicate(), t["b"]["stats"].duplicate()]
	var scr: Control = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(t["r"])
	var shown := _texts(scr, [])
	for i in 2:
		var k: Dictionary = [t["a"], t["b"]][i]
		var grew := _grew(stats0[i], k["stats"])
		var gain := ResultsBokiLines.gain_text(_total_xp(k) - int(before[i]), float(k["trust"]) - 40.0, grew)
		var line := "%s  %s" % [k["name"], gain]
		ok(shown.has(line), "the screen shows '%s'" % line)
		ok(not grew.is_empty(), "%s: the run it got out of grew a stat (%s)" % [k["name"], grew])
	ok(shown.has("Wren  going home"), "a carried stolen wisp reads 'going home'")
	var groups := scr.find_children("*", "", true, false).filter(
		func(n): return n.has_meta("results_group") and (n as CanvasItem).is_visible_in_tree()
	)
	ok(groups.size() <= 5, "still at most 5 first-view groups (%d)" % groups.size())
	scr.queue_free()
	var tiny := ResultsBokiLines.gain_text(30, 0.2)
	var loss := ResultsBokiLines.gain_text(30, -2.4)
	ok(tiny == "+30 XP, bond unchanged" and loss == "+30 XP, bond down 2", "a tiny change reads unchanged, a loss down")


func _shots() -> void:
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = Vector2i(1280, 720)
	for k in 240:
		await tree.process_frame
	var t := _setup()
	main.show_screen("results", t["r"])
	for k in 150:
		await tree.process_frame
	for k in 900:
		if not main.fade.covered and main.fade.rect.color.a < 0.01:
			break
		await tree.process_frame
	for k in 40:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("results_boki_line_1280x720.png"))
	print("RESULTSBOKI_SHOTS_DONE")
