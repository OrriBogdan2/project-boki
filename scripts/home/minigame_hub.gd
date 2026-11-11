class_name MinigameHub
extends RefCounted
## The title's "Play with your Boki": the garden opens straight into a picker of the minigames this
## base has (the Dash, Stump Shove, Seek, Spark Volley), each with its one-line rule and best Boki.
## A game that stands in other zones (garden_zones.json "games") is listed as places to go: a trip to
## the first open one, locked while they all sleep.
## It needs no farm tutorial step and never touches tutorial state, so skipping the tutorial stays
## lossless. The list is content/rules/minigames.json; a game is listed only when Home holds it in
## the member named there and its fixture ("node") is placed, so a base without a game, or without
## the Training post the fixtures stand by, simply doesn't show it (Home.get returns null for a
## variable it lacks). Picking one closes the picker and calls the game's use().
## Results: Save.d["game_board"] = {game id: {"last": name, "wins": {name: count}}}; older saves
## start with {}, so there is no migration.

const TITLE := "Play with your Boki"

static func rules() -> Dictionary:
	return Content.rules("minigames")

## Records a finished game: the winning Boki's name.
static func record(game: String, who: String) -> void:
	var all: Dictionary = Save.d.get_or_add("game_board", {})     # a hand-built save may lack it
	if not all.has(game):
		all[game] = {"last": "", "wins": {}}
	var rec: Dictionary = all[game]
	rec["last"] = who
	rec["wins"][who] = int(rec["wins"].get(who, 0)) + 1

## "No games yet", or "Best Pip, 3 wins · last Rue".
static func summary(game: String) -> String:
	var rec: Dictionary = Save.d.get("game_board", {}).get(game, {})
	var wins: Dictionary = rec.get("wins", {})
	if wins.is_empty():
		return "No games yet"
	var best := ""
	for n in wins:
		if best == "" or int(wins[n]) > int(wins[best]):
			best = String(n)
	var count := int(wins[best])
	return "Best %s, %d %s · last %s" % [best, count, "win" if count == 1 else "wins", rec["last"]]

## The games this base has, in the file's order: {id, name, rule, game} with game the live object.
static func listed(home: Node) -> Array:
	var out: Array = []
	for g in rules()["games"]:
		var obj: Variant = home.get(String(g["member"]))
		if obj != null and is_instance_valid(obj.get(String(g["node"]))):     # its post is placed
			out.append({"id": g["id"], "name": g["name"], "rule": g["rule"], "game": obj})
	return out

## The games this zone doesn't hold, each as places to go: {id, name, rule, zones, open} with zones every
## other zone of garden_zones.json "games" that has it (open ones first) and open whether one is awake.
static func elsewhere(home: Node) -> Array:
	var here := listed(home).map(func(g): return g["id"])
	var out: Array = []
	for g in rules()["games"]:
		var id := String(g["id"])
		var zs: Array = GardenZones.ids().filter(
			func(z): return z != GardenZones.here and id in GardenZones.info(z)["games"])
		if id in here or zs.is_empty():
			continue
		zs.sort_custom(func(a, b): return GardenZones.is_open(a) and not GardenZones.is_open(b))
		out.append({"id": id, "name": g["name"], "rule": g["rule"], "zones": zs,
			"open": GardenZones.is_open(zs[0])})
	return out

## Opens the picker on the Home screen (home is the Home scene, built and showing).
static func open(home) -> void:
	var v: VBoxContainer = home._new_panel(TITLE, 560.0)
	var games := listed(home)
	var sub := "Pick a game to play with your Boki."
	if games.is_empty():
		sub = "None of the garden games stand here: pick where to play."
	UI.subtitle(v, sub)
	for g in games:
		v.add_child(_card(home, g))
	for g in elsewhere(home):
		v.add_child(_place_card(home, g))

static func _card(home, g: Dictionary) -> Control:
	var card := UI.tile_card(true, func(): start(home, g), 12)
	card.name = "Game_" + String(g["id"])
	var col := UI.vbox(2)
	card.add_child(col)
	col.add_child(UI.label(String(g["name"]), 18))
	col.add_child(UI.label(String(g["rule"]), 13, UI.MUTED))
	col.add_child(UI.label(summary(String(g["id"])), 12, UI.GOLD))
	return card

## A game that stands in other zones: a trip to the first awake one, or locked while they all sleep.
static func _place_card(home, g: Dictionary) -> Control:
	var names: Array = g["zones"].map(func(z):
		return String(GardenZones.info(z)["name"]) + ("" if GardenZones.is_open(z) else " (locked)"))
	var on: bool = g["open"]
	var card := UI.tile_card(on, func(): home.hway.hop(g["zones"][0]), 12)
	card.name = "Game_" + String(g["id"])
	var col := UI.vbox(2)
	card.add_child(col)
	col.add_child(UI.label(String(g["name"]), 18, UI.INK if on else UI.FAINT))
	col.add_child(UI.label(String(g["rule"]), 13, UI.MUTED))
	var where := ("Play it in " if on else "Locked, asleep: ") + ", ".join(names)
	col.add_child(UI.label(where, 12, UI.GOLD if on else UI.FAINT))
	return card

## Closes the picker and starts the game.
static func start(home, g: Dictionary) -> void:
	home._close_panel()
	g["game"].use()
