class_name ZoneCards
extends RefCounted
## The Waystone's destination cards (briefs/design/GARDEN.md 10.5): one per zone, plus the hub when
## you're in a zone, read at a glance. An open zone's card has a band of its colour, up to six of its
## Boki as pictures with today's mood face (happy, content, sulky), and its game with your best Boki
## at it (MinigameHub.best). A locked one is grey with one line on what it still needs; with both keys
## in hand its button reads "Wake it" (HubWaystone.attune);
## "Locked" is refused with a knock (HubWaystone.hop).
## The same cards answer "Move to..." for a Boki (move_to): Send, or why it can't go there.

const CARD_W := 150.0       # px, one card's width
const JOY_HAPPY := 60.0     # joy at or over this reads "happy" on the card
const JOY_LOW := 30.0       # joy under this reads "sulky"
const FACES := 6            # Boki pictures on an open card at most (3 a row); the rest read "+N more"
const FACE_PX := 36.0       # px, one Boki picture
const MOOD_PX := 14.0       # px, the mood face on its corner
const BAND_H := 6.0         # px, the zone's colour band across the card's top
const MOOD_COL := {"happy": UI.GOOD, "content": UI.GOLD, "sulky": UI.BAD}

static func open(h, here: String) -> void:
	var v: VBoxContainer = h._new_panel("The Waystone", 900.0)
	v.add_child(UI.label("Where to?", 14, UI.MUTED))
	var row := UI.hbox(8)
	row.name = "Cards"
	v.add_child(row)
	if here != GardenZones.HUB:
		var about := UI.para("The Waystone, the portal and the way to every zone.")
		row.add_child(_card("The hub", Color("c9c2b2"), [about], func(): h.hway.hop(GardenZones.HUB), "Go", true))
	for id in GardenZones.ids():
		var z := GardenZones.info(id)
		if GardenZones.is_open(id):
			var lines := _open_lines(id, h.get_tree())
			row.add_child(_card(String(z["name"]), Color(String(z["colour"])), lines, func(): h.hway.hop(id),
					"You are here" if id == here else "Go", id != here))
		else:
			var lines: Array = [UI.para(lock_line(id), 12, UI.MUTED)]
			if here == GardenZones.HUB and h.hhints != null:
				lines.append_array(HubFirstVisit.card_line(id))
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
		var lines: Array = _open_lines(id, h.get_tree()) if GardenZones.is_open(id) else []
		if why != "":
			lines.append(UI.para(why, 12, UI.MUTED))
		var col := Color(String(z["colour"])) if GardenZones.is_open(id) else UI.FAINT
		var go := func():
			h._close_panel()
			h.hway.send(k, id)
		row.add_child(_card(String(z["name"]), col, lines, go, "Send" if why == "" else "Can't", why == ""))

## A locked zone's one line: what it still needs, in plain words.
static func lock_line(id: String) -> String:
	var keys := GardenZones.keys_for(id)
	var types: Array = GardenZones.info(id)["types"].map(func(t): return String(t).capitalize())
	var food := "feed a Boki %s or %s meals" % [", ".join(types.slice(0, -1)), types[-1]]
	if keys["seed"] and keys["lean"]:
		return "Ready to wake."
	if keys["seed"]:
		return food[0].to_upper() + food.substr(1) + "."
	var seed := "Find its Wayseed in a run's lair or at the trader"
	return seed + "." if keys["lean"] else seed + ", and " + food + "."

## An open zone's card body: its Boki with their moods, who woke it, today's game and your best at it.
static func _open_lines(id: String, tree: SceneTree) -> Array:
	var out: Array = []
	var res := GardenZones.residents(id)
	if res.is_empty():
		out.append(UI.para("Nobody lives here yet.", 12, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	for rec in res.slice(0, FACES):
		grid.add_child(_face(rec, tree))
	if not res.is_empty():
		out.append(grid)
	if res.size() > FACES:
		out.append(UI.para("+%d more" % (res.size() - FACES), 12, UI.MUTED))
	var founder := GardenZones.founder(id)
	if not founder.is_empty():
		out.append(UI.para("Woken by %s" % founder["name"], 12, UI.MUTED))
	var z := GardenZones.info(id)
	out.append(UI.para("Today: " + String(z["game"]), 12, UI.INK))
	var top := MinigameHub.best(String(z["play"]))
	out.append(UI.para("Not played yet" if top.is_empty() else "Your best: %s" % top["name"], 12, UI.GOLD))
	return out

## One Boki on a card: its picture with today's mood face on the corner; its name and mood on hover.
static func _face(rec: Dictionary, tree: SceneTree) -> Control:
	var mood := _mood(rec)
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(FACE_PX, FACE_PX)
	cell.tooltip_text = "%s, %s" % [rec["name"], mood]
	cell.add_child(KinPortrait.view(rec, tree, FACE_PX))
	var icon := Icons.Glyph.new(mood, MOOD_COL[mood], MOOD_PX)
	icon.name = "Mood"
	icon.position = Vector2(FACE_PX - MOOD_PX, FACE_PX - MOOD_PX)
	cell.add_child(icon)
	return cell

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
	var band := ColorRect.new()
	band.name = "Band"
	band.color = col
	band.custom_minimum_size.y = BAND_H
	v.add_child(band)
	v.add_child(UI.label(title, 15, col))
	for l in lines:
		if l is Label:
			(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var b := UI.button(btn, go, CARD_W - 28.0)
	b.disabled = not can
	v.add_child(b)
	return c
