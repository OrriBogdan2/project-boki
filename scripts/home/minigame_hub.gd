class_name MinigameHub
extends RefCounted
## The title's "Play with your Boki": the garden opens straight into a picker of the minigames this
## base has (the Dash, Stump Shove, Seek, Spark Volley), each with its one-line rule and best Boki.
## It needs no farm tutorial step and never touches tutorial state, so skipping the tutorial stays
## lossless. The list is content/rules/minigames.json; a game is listed only when Home holds it in
## the member named there and its fixture ("node") is placed, so a base without a game, or without
## the Training post the fixtures stand by, shows it locked (Home.get returns null for a variable it
## lacks). Picking an open one closes the picker and calls the game's use(); the picker lands in the
## start zone, where the games stand (the hub has none).
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

## Every game, in the file's order: {id, name, rule, game, open}; game is the live object and open
## is true only when this base has it with its post placed (else game is null and the card is locked).
static func listed(home: Node) -> Array:
	var out: Array = []
	for g in rules()["games"]:
		var obj: Variant = home.get(String(g["member"]))
		var open: bool = obj != null and is_instance_valid(obj.get(String(g["node"])))
		out.append({"id": g["id"], "name": g["name"], "rule": g["rule"], "game": obj if open else null, "open": open})
	return out

## Opens the picker on the Home screen (home is the Home scene, built and showing).
static func open(home) -> void:
	var v: VBoxContainer = home._new_panel(TITLE, 560.0)
	var games := listed(home)
	var sub := "Pick a game to play with your Boki."
	if not games.any(func(g): return g["open"]):
		sub = "No garden games are open here yet: they stand by the Training post."
	UI.subtitle(v, sub)
	for g in games:
		v.add_child(_card(home, g))

static func _card(home, g: Dictionary) -> Control:
	var open: bool = g["open"]
	var card := UI.tile_card(open, (func(): start(home, g)) if open else Callable(), 12)
	card.name = "Game_" + String(g["id"])
	var col := UI.vbox(2)
	card.add_child(col)
	col.add_child(UI.label(String(g["name"]), 18))
	col.add_child(UI.label(String(g["rule"]), 13, UI.MUTED))
	if open:
		col.add_child(UI.label(summary(String(g["id"])), 12, UI.GOLD))
	else:
		col.add_child(UI.label("Locked: it stands by the Training post", 12, UI.MUTED))
	return card

## Closes the picker and starts the game.
static func start(home, g: Dictionary) -> void:
	home._close_panel()
	g["game"].use()
