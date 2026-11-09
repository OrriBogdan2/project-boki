extends RefCounted
## --minigame-hub-check: the title's "Play with your Boki" (scripts/home/minigame_hub.gd).
##   1. the registry (content/rules/minigames.json) names each game once, with a member and a rule line
##   2. results: nothing played reads "No games yet"; wins make the best Boki, the latest the last
##   3. the title has the entry with a save, and not without one
##   4. a save that has skipped the farm tutorial: the entry loads the home straight into the picker,
##      and the tutorial flags are exactly as they were
##   5. every game this base lists has a card (name, rule, result line) and a pick closes the picker
##      and starts it; a stand-in game proves the start path where the base has none
## Never touches the real save.

const SETTLE_FRAMES := 900       # frames to wait at most for the home to build and open the picker

var bad := 0
var main: Node
var started := false

## A game that only notes it was started.
class Stub extends RefCounted:
	var main_check
	func use() -> void:
		main_check.started = true

## A home with one game, so the list's own code runs where the base has none.
class FakeHome extends Node:
	var hrace = null

func ok(cond: bool, what: String) -> void:
	print("MINIGAMEHUB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_registry()
	_results()
	await _title()
	await _picker()
	print("MINIGAMEHUB DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _registry() -> void:
	var seen := {}
	var good := true
	for g in MinigameHub.rules()["games"]:
		var filled := [g["name"], g["member"], g["rule"]].all(func(t): return String(t) != "")
		good = good and filled and not seen.has(g["id"])
		seen[g["id"]] = true
	ok(good and seen.size() == 4, "registry: four games, each with an id, name, member and rule (%s)" % [seen.keys()])

func _results() -> void:
	ok(MinigameHub.summary("race") == "No games yet", "results: nothing played reads 'No games yet'")
	MinigameHub.record("race", "Pip")
	MinigameHub.record("race", "Pip")
	MinigameHub.record("race", "Ash")
	var line := "Best Pip, 2 wins · last Ash"
	ok(MinigameHub.summary("race") == line, "results: best is the most wins, last is the latest")
	ok(MinigameHub.summary("seek") == "No games yet", "results: another game keeps its own record")
	Save.d = Save.fresh()

func _title() -> void:
	for with_save in [false, true]:
		Save.d = Save.fresh()
		if with_save:
			var k := Save.new_kin("zapple", "Pip")
			Save.d["roster"].append(k)
			Save.d["active"] = k["uid"]
		main.show_screen("title", {})
		for i in 6:
			await main.get_tree().process_frame
		var labels: Array = main.screen_node().menu_labels()
		var how := "there with a save" if with_save else "absent without a Boki"
		ok(labels.has("Play with your Boki") == with_save, "title: the entry is %s (%s)" % [how, labels])

func _picker() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {}
	Save.d = d
	main.show_screen("home", {"play_hub": true})
	var home: Node = null
	for f in SETTLE_FRAMES:
		await main.get_tree().process_frame
		home = main.screen_node()
		if home != null and home.get("panel_open") == MinigameHub.TITLE:
			break
	ok(home != null and home.get("panel_open") == MinigameHub.TITLE, "picker: the home opens on 'Play with your Boki'")
	var tut: Dictionary = Save.d["tutorial"]
	var ft: Dictionary = tut.get("ft", {})
	var flags := [ft.get("did", {}).is_empty(), not ft.get("done", false)]
	flags.append_array([not ft.get("skipped", false), not tut.get("home", false)])
	var same: bool = flags.all(func(f): return f)
	ok(same, "picker: no farm tutorial step done, skipped or finished (skipping stays lossless)")
	if home == null:
		return
	var games := MinigameHub.listed(home)
	print("MINIGAMEHUB listed on this base: %s" % [games.map(func(g): return g["id"])])
	for g in games:
		var card: Node = home.panel_host.find_child("Game_" + String(g["id"]), true, false)
		ok(card != null, "%s: has a card" % g["id"])
		var lines := [g["rule"], MinigameHub.summary(String(g["id"]))]
		ok(lines.all(func(t): return t != ""), "%s: a rule line and a result line" % g["id"])
		MinigameHub.start(home, g)
		ok(home.panel_open == "", "%s: a pick closes the picker and opens the game" % g["id"])
		MinigameHub.open(home)
	home._close_panel()
	var stub := Stub.new()
	stub.main_check = self
	var fake := FakeHome.new()
	fake.hrace = stub
	var shown := MinigameHub.listed(fake)
	var only: bool = shown.size() == 1 and shown[0]["id"] == "race" and shown[0]["game"] == stub
	ok(only, "list: a game the home holds is listed, the rest are not")
	MinigameHub.open(home)
	MinigameHub.start(home, shown[0])
	ok(started and home.panel_open == "", "start: the picker closes and the game's use() runs")
	fake.free()
