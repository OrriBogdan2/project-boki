class_name AbilityCard
extends PanelContainer
## The one card that says what an ability does: name, key cap, cooldown and range, one plain sentence, and
## for a two-step ability "Press <key> again to ...". Every number is read from content/archetypes, never typed
## again here: the slot's "cooldown" (the dash's "cd"), the path its "card_range" names, its "again" phrase.
## Shown on hover over the Hunter pick's kit rows, the Relic screen's clips and (Tab held) the HUD's ability row.
##
##   AbilityCard.hover(control, "thief", "e")           # a floating card while the mouse is on `control`
##   AbilityCard.make("thief", "e", p.slot_info("e"))    # the card itself; `live` (optional) from the kit's slot_info

const WIDTH := 300.0         # px
const GAP := 14.0            # px between the card and what it describes
const PAD := Vector2(14, 10) # px, inside the frame
## The slots with a cooldown in their data ("dash" keeps its recharge in "cd", the rest in "cooldown").
const TIMED := ["dash", "rmb", "e", "x"]

var facts: Dictionary = {}

## What the card shows for one ability: name, icon, colour, key, cooldown (-1 for none), range (-1 for none) and
## its label, the one sentence, and the "again" phrase ("" for a one-press ability). `live` is the kit's slot_info
## when a hunter is in play: its name and cooldown (at the current rank) replace the data's.
static func facts_for(arch: String, slot: String, live := {}) -> Dictionary:
	var info := HunterViewer.slot_info(arch, slot)
	var sd: Dictionary = Arch.def(arch).get(slot, {})
	var out := {"name": String(info["name"]), "icon": String(info["icon"]), "col": info["col"],
		"key": HunterViewer.key_for(slot), "cooldown": -1.0, "range": -1.0, "range_label": "Range",
		"line": AbilityClip.line_for(arch, slot), "again": String(sd.get("again", ""))}
	if slot in TIMED:
		out["cooldown"] = float(sd.get("cd" if slot == "dash" else "cooldown", -1.0))
		var path := String(sd.get("card_range", ""))
		if path != "":
			out["range"] = _at(sd, path)
			out["range_label"] = "Radius" if path.ends_with("radius") else "Range"
	if not live.is_empty():
		out["name"] = String(live["name"])
		out["cooldown"] = float(live["cd_max"])
	return out

## The number a dotted path ("pin.range") names in an ability's data.
static func _at(sd: Dictionary, path: String) -> float:
	var node: Variant = sd
	for part in path.split("."):
		node = (node as Dictionary).get(part, 0.0)
	return float(node)

## The numbers line: "Cooldown 9.5s  ·  Range 14m".
static func numbers(f: Dictionary) -> String:
	var parts: Array = []
	if float(f["cooldown"]) > 0.0:
		parts.append("Cooldown %ss" % KinText.n(float(f["cooldown"])))
	if float(f["range"]) > 0.0:
		parts.append("%s %sm" % [f["range_label"], KinText.n(float(f["range"]))])
	return "  ·  ".join(parts)

## "Press E again to pop the seed", or "" for a one-press ability.
static func again_line(f: Dictionary) -> String:
	return "Press %s again to %s." % [f["key"], f["again"]] if String(f["again"]) != "" else ""

static func make(arch: String, slot: String, live := {}) -> AbilityCard:
	var card := AbilityCard.new()
	card.facts = facts_for(arch, slot, live)
	return card

func _ready() -> void:
	var col: Color = facts["col"]
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UI.frame(UI.SURFACE, UI.R_CARD, Color(col, 0.6), 2, PAD.x, PAD.y))
	var v := UI.vbox(5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.IconDot.new(String(facts["icon"]), col, 26.0))
	var nm := UI.label(String(facts["name"]), 18, col, UI.big)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if facts["key"] != "auto":
		head.add_child(UI.keycap(String(facts["key"]), 12))
	v.add_child(head)
	for text in [numbers(facts), String(facts["line"]), again_line(facts)]:
		if text != "":
			var ln := UI.para(text, 13, UI.INK if text == facts["line"] else Color(col.lightened(0.3), 0.95))
			ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(ln)

## Puts the card up beside `ctl` while the mouse is on it, with the data's own numbers (the menus).
static func hover(ctl: Control, arch: String, slot: String) -> void:
	var shown: Array = []
	ctl.set_meta("card_slot", slot)      # (so a check can find the controls that show a card)
	ctl.mouse_entered.connect(func():
		var card := make(arch, slot)
		card.top_level = true
		card.modulate.a = 0.0
		ctl.add_child(card)
		shown.append(card)
		await ctl.get_tree().process_frame      # (the card has its size after one layout pass)
		if is_instance_valid(card):
			card.position = HudTip.place(ctl.get_global_rect(), card.size, ctl.get_viewport_rect().size)
			card.modulate.a = 1.0)
	ctl.mouse_exited.connect(func():
		for card in shown:
			if is_instance_valid(card):
				(card as Node).queue_free()
		shown.clear())

## The HUD's ability row slots (hover ids) and the kit slot each one shows.
const HUD_SLOTS := {"dash": "dash", "sec": "rmb", "k1": "e", "x": "x"}

## While Tab is held and the mouse is on an ability of the row, shows its card above it (the kit's live name and
## cooldown) and returns true; otherwise drops it. Called every frame from the HUD's hover pass.
static func on_hud(host: Control, id: String, anchor: Rect2, p: Hunter) -> bool:
	var card: AbilityCard = host.get_meta("ability_card") if host.has_meta("ability_card") else null
	if p.ak == null or not HUD_SLOTS.has(id) or not Input.is_action_pressed("scores"):
		if card != null:
			card.queue_free()
			host.remove_meta("ability_card")
		return false
	if card == null or card.get_meta("slot") != id:
		if card != null:
			card.queue_free()
		card = make(p.arch, String(HUD_SLOTS[id]), p.slot_info(id))
		card.set_meta("slot", id)
		host.set_meta("ability_card", card)
		host.add_child(card)
	card.position = HudTip.place(anchor, card.size, host.size)
	return true
