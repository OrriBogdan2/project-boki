class_name GameResultCard
extends RefCounted
## The one result card the garden games end on (Tumble, Echo Steps, Show Ring, Relay Cup, Glint Fishing): the
## game, the placing or score, the prize lines, and for each Boki the joy and the stats it gained, with the same
## stat icons the home glint shows (StatGlint.ICON). Same place and size for every game; one click closes it.
## `snap` the Boki before the game pays out, then `open` after it: the card shows the difference.

const SIZE := Vector2(460, 320)        # px: fixed, so every game's card looks the same (fits 1280x720)
const TOP_PX := 90.0                   # px from the top of the screen
const MAX_BOKI := 3                    # rows of Boki that fit (a Relay Cup team)
const MAX_PRIZE := 3                   # prize lines that fit (gems, the prize, the cup step)
const ICON_PX := 18.0                  # px: a stat icon
const NAME_PX := 120.0                 # px: the Boki name column
const JOY_COL := Color("ff8fb0")       # the joy figure

## What each Boki is now: [{"rec", "joy", "stats"}], to compare against after the payout.
static func snap(recs: Array) -> Array:
	var out: Array = []
	for rec in recs:
		Care.ensure(rec)
		out.append({"rec": rec, "joy": float(rec["needs"]["joy"]), "stats": rec.get("stats", {}).duplicate()})
	return out

## Shows the card on the home screen. `d`: {game, place, prize: [[text, colour]], before: snap()}.
static func open(home, d: Dictionary) -> PanelContainer:
	var card := UI.card(Color(0.06, 0.07, 0.1, 0.92), 14, 14)
	card.name = "GameResultCard"
	card.custom_minimum_size = SIZE
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = TOP_PX
	card.clip_contents = true
	card.gui_input.connect(_on_input.bind(card))
	var rows := UI.vbox(6)
	card.add_child(rows)
	rows.add_child(UI.label(String(d["game"]), UI.T_SMALL, UI.MUTED))
	rows.add_child(UI.label(String(d["place"]), 20, UI.ACCENT_HI))
	var prize: Array = d["prize"]
	for p in prize.slice(0, MAX_PRIZE):
		rows.add_child(UI.label(p[0], 14, p[1]))
	var before: Array = d["before"]
	for b in before.slice(0, MAX_BOKI):
		rows.add_child(_boki_row(b))
	var hint := UI.label("Click to close", UI.T_SMALL, UI.MUTED)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rows.add_child(hint)
	home.root_ui.add_child(card)
	return card

static func _boki_row(b: Dictionary) -> HBoxContainer:
	var rec: Dictionary = b["rec"]
	var row := UI.hbox(8)
	var who := UI.label(String(rec["name"]), 14, UI.INK)
	who.custom_minimum_size.x = NAME_PX
	who.clip_text = true
	row.add_child(who)
	var joy := roundi(float(rec["needs"]["joy"]) - float(b["joy"]))
	row.add_child(UI.label("Joy %+d" % joy, 14, JOY_COL if joy > 0 else UI.MUTED))
	for s in StatGlint.ICON:
		var rise := int(rec.get("stats", {}).get(s, 0)) - int(b["stats"].get(s, 0))
		if rise > 0:
			var col: Color = Care.STATS[s]["col"]
			row.add_child(Icons.Glyph.new(StatGlint.ICON[s], col, ICON_PX))
			row.add_child(UI.label("+%d" % rise, 14, col))
	return row

static func _on_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card.accept_event()
		card.queue_free()
