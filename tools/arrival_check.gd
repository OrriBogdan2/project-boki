extends RefCounted
## --arrival-check: the first minutes' declutter (briefs/UI_DECLUTTER_PLAN.md, sections 4 and 5).
##   1. results: three big numbers, no armor tile, the rest behind "Details", the way home on screen
##   2. the arrival queue: modals open one at a time, in order, and wait while something else is open
##   3. the top bar's counters show from the first time you have some (old saves see them all)
##   4. the key row: each hint goes after 3 uses; whistle and build wait for the tutorial's end

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("ARRIVAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

class Host extends Node:
	var panel_open := ""
	var building_now := false

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _results()
	await _queue()
	_chips()
	_keys()
	print("ARRIVAL DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _texts(root: Node, visible_only: bool) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		if not visible_only or (l as Label).is_visible_in_tree():
			out.append((l as Label).text)
	return out

func _results() -> void:
	var rec := Save.new_kin("zapple", "Pip")
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	Save.d["name"] = "Vex"
	var scr := Control.new()
	scr.set_script(load("res://scripts/ui/results.gd"))
	main.add_child(scr)
	scr.show_result({"extracted": true, "gems": 42, "knocks": 3, "damage": 512, "taken": 388, "kills": 1, "downs": 1,
			"revives": 2, "armor_tier": 3, "time": 201.0, "kin_trust": 57.0, "vault_gems": 9})
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var shown := _texts(scr, true)
	var three := "KNOCKS" in shown and "DAMAGE" in shown and "TIME" in shown
	ok("Vex made it out" in shown and three, "results: the hunter's name in the headline and three numbers")
	ok(not ("ARMOR" in _texts(scr, false)), "results: no armor tile")
	ok(not ("Damage taken" in shown) and not ("Your vault kept 9 of the gems you dropped." in shown),
			"results: the small numbers and notes are hidden")
	var toggle: Button = null
	var home_btn: Button = null
	for b in scr.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Details"): toggle = b
		if (b as Button).text == "Back to the farm": home_btn = b
	ok(toggle != null and home_btn != null and home_btn.is_visible_in_tree(),
			"results: a Details toggle and the way home on screen")
	if toggle:
		toggle.pressed.emit()
		ok("Damage taken" in _texts(scr, true), "results: Details shows them")
	scr.queue_free()

func _queue() -> void:
	var host := Host.new()
	main.add_child(host)
	var q := ArrivalQueue.new(host)
	var order: Array = []
	var open := func(id: String) -> void:
		order.append(id)
		host.panel_open = id
	q.add(open.bind("welcome"))
	q.add(open.bind("evolved"))
	q.add(open.bind("away"))
	ok(order == ["welcome"], "queue: the first modal opens, the others wait")
	host.panel_open = ""
	q.pump()
	ok(order == ["welcome", "evolved"], "queue: closing one opens the next, never two")
	host.panel_open = ""
	host.building_now = true      # an evolution playing
	q.pump()
	ok(order.size() == 2, "queue: nothing opens while something plays")
	host.building_now = false
	await main.get_tree().create_timer(ArrivalQueue.RETRY_S + 0.2).timeout
	ok(order == ["welcome", "evolved", "away"], "queue: it opens by itself when that is over, in order")
	host.queue_free()

func _chips() -> void:
	Save.d["tutorial"] = {"hatched": true}      # a new player: the welcome not seen yet
	Save.d["items"] = {}
	Save.d["crops"] = {}
	var any := TopChips.shows("wood", 0) or TopChips.shows("tonic", 0) or TopChips.shows("crops", 0)
	ok(not any, "chips: a new player sees none of the counters")
	ok(TopChips.shows("wood", 2) and not TopChips.shows("stone", 0), "chips: each counter shows once you have some")
	ok(TopChips.shows("wood", 0), "chips: and stays when it is spent")
	Save.d["tutorial"] = {"hatched": true, "home": true}      # a save that had seen the farm before
	ok(TopChips.shows("coals", 0) and TopChips.shows("tonic", 0), "chips: an old save sees them all")

func _keys() -> void:
	Save.d["tutorial"] = {"home": true, "day1_done": true}      # tutorial over
	var box := PanelContainer.new()
	var hints := FarmKeyHints.new(box)
	ok(hints.row.get_child_count() == FarmKeyHints.KEYS.size(), "keys: every key shows once the tutorial is over")
	Save.d["tutorial"]["key_uses"] = {"walk": FarmKeyHints.USES, "menu": FarmKeyHints.USES - 1}
	ok(hints._wanted() == 0b111110, "keys: a key used 3 times goes (walk), one used twice stays (menu)")
	hints.tick()
	ok(hints.row.get_child_count() == FarmKeyHints.KEYS.size() - 1, "keys: the row rebuilds without it")
	box.free()
