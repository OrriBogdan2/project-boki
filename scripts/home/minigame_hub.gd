class_name MinigameHub
extends RefCounted
## The title's "Play with your Boki": the garden opens straight into a picker of the minigames this
## base has (the Dash, Stump Shove, Seek, Spark Volley), each with its one-line rule and best Boki.
## It needs no farm tutorial step and never touches tutorial state, so skipping the tutorial stays
## lossless. The list is content/rules/minigames.json: a game is listed once for each open zone it stands
## in, with the zone, from data alone, so the picker also works from the hub (where no game is placed;
## a garden past its first day lands there). In the zone shown it is listed when Home holds it and its
## fixture is placed. Picking one calls the game's use(), or travels to its zone first.
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

## Every game in every open zone it stands in, in the file's order: {id, name, rule, zone, game}. In the
## zone the garden shows, game is the live object (its fixture is placed); in the others, and in the hub,
## it is null and picking it travels there (start).
static func listed(home: Node) -> Array:
	var out: Array = []
	var here := _here(home)
	for g in rules()["games"]:
		for zone in GardenZones.ids():
			var obj: Variant = null
			if zone == here:
				obj = home.get(String(g["member"]))
				if obj == null or not is_instance_valid(obj.get(String(g["node"]))):     # its post is placed
					continue
			elif not (FarmUnlocks.base_mode() and GardenZones.is_open(zone) and _stands(g, zone)):
				continue
			out.append({"id": g["id"], "name": g["name"], "rule": g["rule"], "zone": zone, "game": obj})
	return out

## The zone the home shows ("" the start zone, "hub" the hub, which holds no game).
static func _here(home: Node) -> String:
	var zone: Variant = home.get("zone")
	return GardenZones.start() if zone == null or zone == "" else String(zone)

## Does the game stand in zone: an entry of its own for it, or a Training post there (the classic island
## always has one; a farm-start island, the zones' kind, only once placed).
static func _stands(g: Dictionary, zone: String) -> bool:
	if g.has("own") and Content.rules(String(g["own"][0]))[String(g["own"][1])].has(zone):
		return true
	var d := {"layout": Save.d.get("layout")}
	if zone != GardenZones.start():
		d = {"layout": ZoneLayout.layout(zone)} if ZoneLayout.built(zone) else {}
	return not HomeLayout.fs(d) or not HomeLayout.fixtures(d, "yard").is_empty()

## Opens the picker on the Home screen (home is the Home scene, built and showing).
static func open(home) -> void:
	var v: VBoxContainer = home._new_panel(TITLE, 560.0)
	var games := listed(home)
	var sub := "Pick a game to play with your Boki."
	if games.is_empty():
		sub = "No garden games here yet: they stand by the Training post."
	UI.subtitle(v, sub)
	for g in games:
		v.add_child(_card(home, g))

static func _card(home, g: Dictionary) -> Control:
	var card := UI.tile_card(true, func(): start(home, g), 12)
	card.name = "Game_%s_%s" % [g["id"], g["zone"]]
	var col := UI.vbox(2)
	card.add_child(col)
	col.add_child(UI.label("%s · %s" % [g["name"], GardenZones.info(String(g["zone"])).get("name", "")], 18))
	col.add_child(UI.label(String(g["rule"]), 13, UI.MUTED))
	col.add_child(UI.label(summary(String(g["id"])), 12, UI.GOLD))
	return card

## Closes the picker and starts the game; one in another zone travels there and opens the picker on arrival.
static func start(home, g: Dictionary) -> void:
	home._close_panel()
	if g["game"] == null:
		home.hway.hop(String(g["zone"]), true)
	else:
		g["game"].use()
