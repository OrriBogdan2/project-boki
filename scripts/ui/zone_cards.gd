class_name ZoneCards
extends RefCounted
## The Waystone's destination cards (briefs/design/GARDEN.md 10.5): one per zone, plus the hub when
## you're in a zone. An open zone's card has its colour, who lives there and how they feel, and
## today's game. A locked one is grey and lists its two keys as ticks, and where to get each; with both
## in hand its button reads "Wake it" (HubWaystone.attune); "Locked" is refused with a knock (HubWaystone.hop).
## The same cards answer "Move to..." for a Boki (move_to): Send, or why it can't go there.

const CARD_W := 150.0       # px, one card's width
const JOY_HAPPY := 60.0     # joy at or over this reads "happy" on the card
const JOY_LOW := 30.0       # joy under this reads "sulky"

static func open(h, here: String) -> void:
	var v: VBoxContainer = h._new_panel("The Waystone", 900.0)
	v.add_child(UI.label("Where to?", 14, UI.MUTED))
	var row := UI.hbox(8)
	v.add_child(row)
	if here != GardenZones.HUB:
		var about := UI.para("The Waystone, the portal and the way to every zone.")
		row.add_child(_card("The hub", Color("c9c2b2"), [about], func(): h.hway.hop(GardenZones.HUB), "Go", true))
	for id in GardenZones.ids():
		var z := GardenZones.info(id)
		if GardenZones.is_open(id):
			row.add_child(_card(String(z["name"]), Color(String(z["colour"])), _open_lines(id), func(): h.hway.hop(id),
					"You are here" if id == here else "Go", id != here))
		else:
			var lines: Array = key_lines(id).map(func(t): return UI.para(t, 12, UI.MUTED))
			lines.append(UI.para("Wayseed: " + String(GardenZones.rules()["wayseed_from"]), 11, UI.FAINT))
			var keys := GardenZones.keys_for(id)
			var ready: bool = keys["seed"] and keys["lean"]
			var pick := func(): h.hway.hop(id)     # refused: the knock and what it still needs
			if ready:
				pick = func(): h.hway.attune(id)
			row.add_child(_card(String(z["name"]), UI.FAINT, lines, pick, "Wake it" if ready else "Locked", true))

## The hub's games board: which game each zone hosts and whether it is open, this week's Dash twist and
## the showcase wall's winners.
static func board(h) -> void:
	var v: VBoxContainer = h._new_panel("Games board", 420.0)
	for id in GardenZones.ids():
		var z := GardenZones.info(id)
		var open := GardenZones.is_open(id)
		var row := UI.hbox(10)
		row.add_child(UI.label(String(z["name"]), 15, Color(String(z["colour"])) if open else UI.FAINT))
		row.add_child(UI.label(String(z["game"]), 13, UI.INK) if open else UI.label("asleep", 13, UI.MUTED))
		v.add_child(row)
	var tw := BaseRace.twist()
	v.add_child(UI.label("This week: %s. %s" % [tw["name"], tw["note"]], 14, UI.GOLD))
	var wall: Array = Save.d.get("showcase", [])
	v.add_child(UI.label("Showcase wall: no Dash winners yet" if wall.is_empty() else "Showcase wall:", 13, UI.MUTED))
	for e in wall:
		v.add_child(UI.label("%s, %s (%s)" % [e["name"], e["date"], e["twist"]], 13, UI.INK))

## "Move to..." on a Boki's card: only for one out in this zone, not your partner, with another zone open.
static func add_move_link(h, row: Control, rec: Dictionary) -> void:
	var k: Dictionary = h._kin_entry(rec)
	if h.hway == null or h.life == null or k.is_empty() or GardenZones.is_partner(rec):
		return
	if GardenZones.ids().any(func(id): return id != GardenZones.zone_of(rec) and GardenZones.is_open(id)):
		row.add_child(UI.ghost("Move to...", func(): move_to(h, k), 0, "paw"))

## Where a Boki could move: a card per zone, Send on the ones it can go to, the reason on the rest.
## Sending closes the panel and it walks to the return pad (HubWaystone.send).
static func move_to(h, k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	var v: VBoxContainer = h._new_panel("Move %s to..." % rec["name"], 900.0)
	var row := UI.hbox(8)
	v.add_child(row)
	for id in GardenZones.ids():
		var z := GardenZones.info(id)
		var why := GardenZones.why_not(rec, id)
		var lines: Array = _open_lines(id) if GardenZones.is_open(id) else []
		if why != "":
			lines.append(UI.para(why, 12, UI.MUTED))
		var col := Color(String(z["colour"])) if GardenZones.is_open(id) else UI.FAINT
		var go := func():
			h._close_panel()
			h.hway.send(k, id)
		row.add_child(_card(String(z["name"]), col, lines, go, "Send" if why == "" else "Can't", why == ""))

## A locked zone's two keys, ticked when you have them.
static func key_lines(id: String) -> Array:
	var keys := GardenZones.keys_for(id)
	var types: Array = GardenZones.info(id)["types"].map(func(t): return String(t).capitalize())
	return ["%s A Wayseed of %s" % [_tick(keys["seed"]), GardenZones.info(id)["name"]],
		"%s A Boki leaning %s" % [_tick(keys["lean"]), ", ".join(types.slice(0, -1)) + " or " + types[-1]]]

static func _tick(have: bool) -> String:
	return "[x]" if have else "[ ]"

static func _open_lines(id: String) -> Array:
	var out: Array = []
	var res := GardenZones.residents(id)
	if res.is_empty():
		out.append(UI.para("Nobody lives here yet.", 12, UI.MUTED))
	for rec in res:
		out.append(UI.para("%s, %s" % [rec["name"], _mood(rec)], 12, UI.MUTED))
	var founder := GardenZones.founder(id)
	if not founder.is_empty():
		out.append(UI.para("Woken by %s" % founder["name"], 12, UI.MUTED))
	out.append(UI.para("Today: " + String(GardenZones.info(id)["game"]), 12, UI.INK))
	return out

static func _mood(rec: Dictionary) -> String:
	var joy := Care.need(rec, "joy")
	if joy >= JOY_HAPPY:
		return "happy"
	return "sulky" if joy < JOY_LOW else "content"

static func _card(title: String, col: Color, lines: Array, go: Callable, btn: String, can: bool) -> Control:
	var c := UI.card()
	c.custom_minimum_size.x = CARD_W
	var v := UI.vbox(6)
	c.add_child(v)
	v.add_child(UI.label(title, 15, col))
	for l in lines:
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var b := UI.button(btn, go, CARD_W - 28.0)
	b.disabled = not can
	v.add_child(b)
	return c
