class_name PrizeBoard
extends RefCounted
## The games board's prize lists and the cup state (GardenPrizes), and a Boki card's Cup Ribbon rows.

## Opens the board as a panel: each game's table, first-win item and where the partner stands in its cup.
static func open(h) -> void:
	fill(h._new_panel("Games board", 520.0, true), Save.active_kin())

## One block a game: its prize table in percent, the first-win item, and rec's cup step.
static func fill(v: VBoxContainer, rec: Dictionary) -> void:
	var rounds: Array = GardenPrizes.rules()["cup"]["rounds"]
	for id in GardenPrizes.ids():
		var g := GardenPrizes.game(id)
		v.add_child(UI.section(String(g["name"]), Color(String(g["colour"]))))
		var total := float(GardenPrizes.table_total(id))
		var parts: Array = []
		for e in g["table"]:
			parts.append("%s %d%%" % [GardenPrizes.entry_name(e), roundi(100.0 * float(e["w"]) / total)])
		v.add_child(UI.para(", ".join(parts), 12, UI.MUTED))
		v.add_child(UI.para("First win of the day: %s." % GardenItems.item_name(String(g["first"])), 12, UI.INK))
		v.add_child(UI.para(_cup_line(id, rec, rounds), 12, UI.TEAL))

static func _cup_line(id: String, rec: Dictionary, rounds: Array) -> String:
	var g := GardenPrizes.game(id)
	var prize := GardenItems.item_name(String(g["cup_prize"]))
	if rec.is_empty():
		return "Cup: three wins in a row. Crown: %s and the %s." % [prize, g["ribbon"]]
	if GardenPrizes.crowned_this_week(rec, id, Time.get_unix_time_from_system()):
		return "%s has the Crown this week. The cup opens again next week." % rec["name"]
	var next: Dictionary = rounds[GardenPrizes.stage(rec, id)]
	return "Cup, %s: next the %s round, a rival at %d%% of its stats or more. Crown: %s and the %s." % [
			rec["name"], next["name"], roundi(100.0 * float(next["min_ratio"])), prize, g["ribbon"]]

## A row on the Boki's card for each Cup Ribbon it holds.
static func add_ribbons(parent: Control, rec: Dictionary) -> void:
	for id in GardenPrizes.ids():
		var n := GardenPrizes.ribbon_count(rec, id)
		if n > 0:
			parent.add_child(UI.kv(String(GardenPrizes.game(id)["ribbon"]), "×%d" % n if n > 1 else "worn",
					Color(String(GardenPrizes.game(id)["colour"]))))

## Marks a kin model's body (Models.kin) with a small rosette for each Cup Ribbon it holds, in the game's colour.
static func dress(body: Node3D, rec: Dictionary) -> void:
	var at := 0
	for id in GardenPrizes.ids():
		if GardenPrizes.ribbon_count(rec, id) > 0:
			var c := Color(String(GardenPrizes.game(id)["colour"]))
			var side := -0.2 + 0.2 * at
			Models.part(body, Models.cyl(0.07, 0.07, 0.03, 12), Models.toon(c, true, 0.3),
					Vector3(side, 0.12, -0.3), Vector3.ONE, Vector3(PI / 2, 0, 0), "CupRibbon%d" % at)
			Models.part(body, Models.box(0.05, 0.16, 0.02), Models.toon(c), Vector3(side, -0.02, -0.31),
					Vector3.ONE, Vector3(0, 0, 0.15), "CupRibbonTail%d" % at)
			at += 1
