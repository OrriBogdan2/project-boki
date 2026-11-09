extends RefCounted
## --minimap-check: the minimap shows only what's needed now (MapDetail).
##   1. the default icon kinds are the six the owner asked for (you, squad, Boki, exit, Blight, ping)
##   2. every other kind waits for a hold (Tab or the map key), or for its own reason to matter
##   3. the draw code gates only kinds MapDetail lists, and every detail kind is gated somewhere
##   4. in a match: the nearest exit and an awake lair matter, a far exit and a dormant lair do not
## Never touches the save.

const EXPECT_DEFAULT := ["you", "squad", "boki", "exit", "blight", "ping"]
const GATED_FILES := ["res://scripts/ui/hud.gd", "res://scripts/ui/revive_hud.gd"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MINIMAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_kinds()
	_source()
	await _match(main)
	print("MINIMAP CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kinds() -> void:
	var same: bool = EXPECT_DEFAULT.all(func(k): return k in MapDetail.DEFAULT)
	var names := ", ".join(MapDetail.DEFAULT)
	var count: int = MapDetail.DEFAULT.size()
	ok(same and count == EXPECT_DEFAULT.size(), "default icon kinds: %s (%d)" % [names, count])
	ok(MapDetail.DETAIL.all(func(k): return not k in MapDetail.DEFAULT), "no kind is both default and detail")
	ok(MapDetail.DEFAULT.all(func(k): return MapDetail.shows(k, false)), "default kinds show without a hold")
	ok(MapDetail.DETAIL.all(func(k): return not MapDetail.shows(k, false)), "detail kinds hide without a hold")
	ok(MapDetail.DETAIL.all(func(k): return MapDetail.shows(k, true)), "detail kinds show on a hold")
	ok(MapDetail.DETAIL.all(func(k): return MapDetail.shows(k, false, true)), "detail kinds show once they matter")
	for action in ["scores", "map"]:
		Input.action_press(action)
		ok(MapDetail.holding(), "holding %s counts as a hold" % action)
		Input.action_release(action)
	ok(not MapDetail.holding(), "no key held: no hold")

func _source() -> void:
	var used := {}
	var re := RegEx.create_from_string("MapDetail\\.shows\\(([^\\n]*?), hold")
	var qs := RegEx.create_from_string("\"(\\w+)\"")
	for f in GATED_FILES:
		for line in FileAccess.get_file_as_string(f).split("\n"):
			var hit := re.search(line)
			if hit == null:
				continue
			for q in qs.search_all(hit.get_string(1)):
				used[q.get_string(1)] = true
	var known: Array = MapDetail.DEFAULT + MapDetail.DETAIL
	var listed: bool = used.keys().all(func(k): return k in known)
	ok(listed, "the draw code gates only listed kinds (%s)" % ", ".join(used.keys()))
	ok(MapDetail.DETAIL.all(func(k): return used.has(k)), "every detail kind is gated by the draw code")

func _match(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var near := MapDetail.nearest_exit(m)
	ok(not near.is_empty() and MapDetail.exit_matters(m, near), "the nearest exit matters")
	var mine: Dictionary = m.exits.active_for(m.player.team)
	var far: Array = m.exits.list.filter(func(x): return not is_same(x, near) and not is_same(x, mine))
	ok(far.is_empty() or not MapDetail.exit_matters(m, far[0]), "a far exit waits for a hold")
	if m.lairs and not m.lairs.list.is_empty():
		var L: Dictionary = m.lairs.list[0]
		L["state"] = "dormant"
		ok(not MapDetail.lair_matters(m, L), "a dormant lair waits for a hold")
		L["state"] = "awake"
		ok(MapDetail.lair_matters(m, L), "an awake lair shows by itself")
