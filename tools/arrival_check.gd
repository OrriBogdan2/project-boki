extends RefCounted
## --arrival-check: the first minutes' declutter (briefs/UI_DECLUTTER_PLAN.md, sections 4 and 5).
## (The results screen's first view is --results-first-check.)
##   1. the arrival queue: modals open one at a time, in order, and wait while something else is open
##   2. the top bar's counters show from the first time you have some (old saves see them all)
##   3. the key row: each hint goes after 3 uses; whistle and build wait for the tutorial's end

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("ARRIVAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

class Host extends Node:
	var panel_open := ""
	var building_now := false
	var panel_host := Control.new()      # the queue waits for it (a home builds it late)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _queue()
	_chips()
	_keys()
	print("ARRIVAL DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

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
