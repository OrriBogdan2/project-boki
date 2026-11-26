extends RefCounted
## --minigame-hub-check: "Play with Your Boki", the garden's minigame picker (scripts/home/minigame_hub.gd).
## The title no longer lists it (the title enters the world); the picker stays in the garden.
##   1. the registry (content/rules/minigames.json) names each game once, with a member and a rule line
##   2. results: nothing played reads "No games yet"; wins make the best Boki, the latest the last
##   3. the title has no entry, with a save or without
##   4. a save that has skipped the farm tutorial: home {play_hub} (the garden waystone) loads the home
##      straight into the picker,
##      and the tutorial flags are exactly as they were
##   6. the garden games for real (base_mode on, three Boki, the Training post): the picker lists all
##      five, and from the hub (where none is placed) every game of every open zone, a pick there
##      travelling to its zone; each pick starts that game (and it is put back); a whole Stump Shove bout ends on its
##      card and the winner becomes the picker's best Boki
##   7. the hub's games board: the Dash and the Fetch Cup are one button each, and a press lands in the start
##      zone with that game running (no picker, no walk)
##   5. every game has a card (name, rule, result line), locked when this base lacks it; a pick on an open
##      one closes the picker and starts it; a stand-in game proves the start path where the base has none
## Never touches the real save.

const SETTLE_FRAMES := 900       # frames to wait at most for the home to build and open the picker

var bad := 0
var main: Node
var started := false

## A game that only notes it was started.
class Stub extends RefCounted:
	var main_check
	var post: Node3D = null
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
	await _garden()
	await _board()
	print("MINIGAMEHUB DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _registry() -> void:
	var seen := {}
	var good := true
	for g in MinigameHub.rules()["games"]:
		var filled := [g["name"], g["member"], g["node"], g["rule"]].all(func(t): return String(t) != "")
		good = good and filled and not seen.has(g["id"])
		seen[g["id"]] = true
	var what := "registry: five games, each with an id, name, member, node and rule (%s)" % [seen.keys()]
	ok(good and seen.size() == 5, what)

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
		var old: Node = main.screen_node()
		main.show_screen("title", {})
		for i in 120:      # (under the fade the old title stays the screen for a while)
			await main.get_tree().process_frame
			if main.screen_node() != old and i >= 6:
				break
		var labels: Array = main.screen_node().menu_labels()
		var how := "with a save" if with_save else "without a Boki"
		ok(not labels.has(MinigameHub.TITLE) and not labels.is_empty(), "title: no entry %s (%s)" % [how, labels])

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
	ok(home != null and home.get("panel_open") == MinigameHub.TITLE, "picker: the home opens on 'Play with Your Boki'")
	var tut: Dictionary = Save.d["tutorial"]
	var ft: Dictionary = tut.get("ft", {})
	var flags := [ft.get("did", {}).is_empty(), not ft.get("done", false)]
	flags.append_array([not ft.get("skipped", false), not tut.get("home", false)])
	var same: bool = flags.all(func(f): return f)
	ok(same, "picker: no farm tutorial step done, skipped or finished (skipping stays lossless)")
	if home == null:
		return
	var games := MinigameHub.listed(home)
	print("MINIGAMEHUB open on this base: %s" % [games.filter(func(g): return g["open"]).map(func(g): return g["id"])])
	ok(games.size() == 5, "picker: every game has a card, open or locked (%d)" % games.size())
	for g in games:
		var card: Node = home.panel_host.find_child("Game_%s_%s" % [g["id"], g["zone"]], true, false)
		ok(card != null, "%s: has a card" % g["id"])
		var lines := [g["rule"], MinigameHub.summary(String(g["id"]))]
		ok(lines.all(func(t): return t != ""), "%s: a rule line and a result line" % g["id"])
		if not g["open"]:
			continue
		MinigameHub.start(home, g)
		ok(home.panel_open == "", "%s: a pick closes the picker and opens the game" % g["id"])
		MinigameHub.open(home)
	home._close_panel()
	var stub := Stub.new()
	stub.main_check = self
	var fake := FakeHome.new()
	fake.hrace = stub
	ok(MinigameHub.listed(fake).all(func(g): return not g["open"]), "list: a game whose post isn't placed is locked")
	stub.post = Node3D.new()
	var shown := MinigameHub.listed(fake)
	var open_ids: Array = shown.filter(func(g): return g["open"]).map(func(g): return g["id"])
	var only: bool = shown.size() == 5 and open_ids == ["race"] and shown[0]["game"] == stub
	ok(only, "list: a game the home holds is open, the rest locked")
	MinigameHub.open(home)
	MinigameHub.start(home, shown[0])
	ok(started and home.panel_open == "", "start: the picker closes and the game's use() runs")
	stub.post.free()
	fake.free()

const STARTED := {"race": "run", "shove": "run", "volley": "run"}

## A garden save past its first day with three rested Boki and the base on (what lands in the hub).
func _base_save() -> Dictionary:
	var d := Save.fresh()
	for i in 3:
		var k := Save.new_kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i])
		k["level"] = 5
		Care.ensure(k)
		k["needs"]["energy"] = 90.0
		d["roster"].append(k)
		if i == 0:
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}     # a normal landing would be the hub
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	return d

func _garden() -> void:
	var d := _base_save()
	var rules: Dictionary = FarmUnlocks.rules()
	var old: Node = main.screen_node()
	main.show_screen("home", {"play_hub": true})
	var home: Node = null
	for f in SETTLE_FRAMES:
		await main.get_tree().process_frame
		home = main.screen_node()
		if home != old and home != null and home.get("panel_open") == MinigameHub.TITLE:
			break
	ok(home != old and home.get("panel_open") == MinigameHub.TITLE, "garden: the picker opens on the base")
	ok(home.zone == "", "garden: the picker lands in the start zone, not the hub (the games stand there)")
	var games := MinigameHub.listed(home)
	var ids: Array = games.filter(func(g): return g["open"]).map(func(g): return g["id"])
	ok(ids == ["race", "shove", "seek", "volley", "fetch"], "garden: all five games are open (%s)" % [ids])
	for g in games:
		for k in home.kins:
			k.erase("indoors")
		MinigameHub.open(home)
		MinigameHub.start(home, g)
		var game: Object = g["game"]
		var on: bool = game.state == BaseSeek.S.CARRY if g["id"] == "seek" else game.get(STARTED[g["id"]]) != null
		ok(on and home.panel_open == "", "garden: picking %s starts it" % g["name"])
		if g["id"] == "seek":
			game.go(BaseSeek.S.IDLE)
		elif on:
			game._end(false)
	var sh: Object = home.hshove
	if sh != null:
		for k in home.kins:
			k.erase("indoors")
			k["busy"] = false
		Save.d["tutorial"]["first_shove"] = true      # past the practice bout (FirstRound, --tut-first-games-check)
		sh.use()
		var t := 0.0
		while sh.run != null and t < float(BaseShove.rules()["max_s"]) + 5.0:
			sh.tick(0.1)
			t += 0.1
		var best: String = MinigameHub.summary("shove")
		ok(sh.run == null and best.begins_with("Best "), "garden: a finished bout reaches the picker (%s)" % best)
	await _hub(d)
	rules["base_mode"] = false

## A garden past its first day lands in the hub, where no game is placed: the picker still lists every game
## of every open zone with its zone, and a pick in another zone travels there.
func _hub(d: Dictionary) -> void:
	d["zones"]["cinderstep"] = {"open": true}
	d["zones"]["hushwood"] = {"open": true}
	var old: Node = main.screen_node()
	main.show_screen("home", {"play_hub": true, "zone": GardenZones.HUB})
	var home: Node = null
	for f in SETTLE_FRAMES:
		await main.get_tree().process_frame
		home = main.screen_node()
		if home != old and home != null and home.get("panel_open") == MinigameHub.TITLE:
			break
	ok(home != old and home.get("panel_open") == MinigameHub.TITLE, "hub: the picker opens on the hub")
	var games := MinigameHub.listed(home)
	var pairs: Array = games.map(func(g): return "%s@%s" % [g["id"], g["zone"]])
	var want := ["race@bramblebank", "shove@bramblebank", "shove@cinderstep", "shove@hushwood", "seek@bramblebank",
		"seek@hushwood", "volley@bramblebank", "volley@hushwood", "race@hushwood"]
	pairs.sort()
	want.sort()
	ok(pairs == want, "hub: every game of every open zone is listed with its zone (%s)" % [pairs])
	var card: Node = home.panel_host.find_child("Game_shove_cinderstep", true, false)
	ok(card != null, "hub: the Cinderstep Stump Shove has a card")
	var far: Dictionary = games.filter(func(g): return g["zone"] == "cinderstep")[0]
	MinigameHub.start(home, far)
	ok(home.hway.hopping == "cinderstep" and home.hway.picker_after, "hub: a pick in another zone travels there")

## The hub's games board lists the Dash and the Fetch Cup as one button each; a press travels to the start zone
## and the game is running on arrival, no picker and no walk to its post.
func _board() -> void:
	_base_save()
	var old: Node = main.screen_node()
	main.show_screen("home", {"zone": GardenZones.HUB})
	var home: Node = null
	for f in SETTLE_FRAMES:
		await main.get_tree().process_frame
		home = main.screen_node()
		var built: bool = home != old and home != null and home.get("panel_host") != null and home.get("hway") != null
		if built and home.hway.board != null:
			break
	ZoneCards.board(home)
	var names := {"race": "The Dash", "fetch": "Fetch Cup"}
	for id in names:
		var b := _button(home.panel_host, "%s · Bramblebank" % names[id])
		ok(b != null, "board: %s is one button on the hub's games board" % names[id])
	home._close_panel()
	var pick := MinigameHub.listed(home).filter(func(g): return g["id"] == "fetch" and g["zone"] == GardenZones.start())
	MinigameHub.start(home, pick[0])
	var queued: bool = home.hway.hopping == GardenZones.start() and MinigameHub.queued == "fetch"
	ok(queued, "board: a press on Fetch Cup travels with it queued")
	home.hway.hopping = ""
	old = home
	main.show_screen("home", {"zone": GardenZones.start(), "play_hub": true})
	for f in SETTLE_FRAMES:
		await main.get_tree().process_frame
		home = main.screen_node()
		if home != old and home != null and home.get("hfetch") != null and home.hfetch.mat != null:
			break
	var played: bool = home.hfetch.run != null
	var ran := "board: on arrival the Fetch Cup is running, no picker"
	ok(home.panel_open == "" and MinigameHub.queued == "" and played, ran)
	if home.hfetch.run != null:
		home.hfetch._end(false)

func _button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null
