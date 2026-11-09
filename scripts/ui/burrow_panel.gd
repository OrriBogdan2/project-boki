class_name BurrowPanel
extends RefCounted
## The quick Boki Burrow panel you get when you click the Burrow: who is out on the island and who
## sleeps inside, each with portrait, mood and level. A swap is two clicks (one Boki out, one asleep);
## with room to spare a single click on a sleeper brings it out. The full box (pages, sorting,
## releasing) is one button away (KinBoxView).

const ROW_H := 52.0
const PORTRAIT := 44.0

## The Boki clicked first, waiting for the other side (uid), or "".
static var picked := ""

static func open(h: Node, note := "") -> void:
	KinBox.ensure()
	var v: VBoxContainer = h._new_panel("Boki Burrow", 460, true)
	v.add_theme_constant_override("separation", 8)
	var out := KinBox.farm()
	var asleep := KinBox.boxed()
	var head := UI.label("Out on the island  %d / %d" % [out.size(), KinBox.farm_cap()], 16, UI.GOOD)
	v.add_child(head)
	for rec in out:
		v.add_child(_row(h, rec, true))
	v.add_child(UI.label("Asleep in the Burrow  %d" % asleep.size(), 16, Color("cdb8ff")))
	if asleep.is_empty():
		v.add_child(UI.label("Nobody is asleep.", 13, UI.MUTED))
	for rec in asleep:
		v.add_child(_row(h, rec, false))
	var msg := UI.label(_hint(), 13, UI.MUTED)
	if note != "":
		msg.text = note
		msg.add_theme_color_override("font_color", UI.GOLD)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.name = "Hint"
	v.add_child(msg)
	v.add_child(UI.ghost("All Boki...", func():
		picked = ""
		h._open_burrow()))

static func _hint() -> String:
	var room := KinBox.farm_room()
	if room <= 0:
		return "Click one Boki out and one asleep to swap them."
	return "%d free: click a sleeper to bring it out." % room

static func _row(h: Node, rec: Dictionary, is_out: bool) -> Control:
	var uid := String(rec["uid"])
	var c := PanelContainer.new()
	c.custom_minimum_size.y = ROW_H
	c.name = "Row_" + uid
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var chosen := uid == picked
	var edge := UI.ACCENT if chosen else Color(1, 1, 1, 0.08)
	c.add_theme_stylebox_override("panel", UI.frame(Color(0.13, 0.14, 0.2), UI.R_CTRL, edge, 2 if chosen else 1, 6, 3))
	var row := UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(row)
	var pic := KinPortrait.view(rec, h.get_tree(), PORTRAIT)
	pic.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	row.add_child(pic)
	var col := UI.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var tint: Color = Data.KIN[rec["species"]]["color"].lerp(UI.INK, 0.5)
	col.add_child(UI.label(String(rec["name"]), 15, tint))
	var mood := "%s  ·  level %d" % [Care.condition_name(rec), int(rec.get("level", 1))]
	col.add_child(UI.label(mood, 12, UI.MUTED))
	var why := KinBox.pinned(rec) if is_out else ""
	if why != "":
		row.add_child(Icons.Glyph.new("paw", UI.GOLD, 16.0))
	c.tooltip_text = why
	if why == "":
		c.tooltip_text = "Click, then pick who takes its place" if is_out else "Click to bring it out"
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			click(h, rec))
	return c

## A click on a Boki: pick it, or finish the swap with the one picked on the other side.
static func click(h: Node, rec: Dictionary) -> void:
	var was := Save.kin(picked)
	var is_out := not KinBox.is_boxed(rec)
	if not was.is_empty() and KinBox.is_boxed(was) != KinBox.is_boxed(rec):
		picked = ""
		var out_rec := rec if is_out else was
		var in_rec := was if is_out else rec
		var why := BurrowSwap.swap(h, out_rec, in_rec)
		open(h, why if why != "" else "%s is out, %s is going to sleep" % [in_rec["name"], out_rec["name"]])
	elif not is_out and KinBox.farm_room() > 0:
		picked = ""
		var why := BurrowSwap.swap(h, {}, rec)
		open(h, why if why != "" else "%s is out on the island" % rec["name"])
	else:
		picked = "" if picked == String(rec["uid"]) else String(rec["uid"])
		open(h, KinBox.pinned(rec) if is_out else "")
