class_name LoadoutPanel
extends Node
## The body of the in-match inventory window (I): what you wear, the
## utility belt, your perks and the backpack, every slot labelled with its key. Point at a thing for a
## hover card (InvText: gear is compared with what you wear). Press, hold and move a thing onto another slot
## (SlotDrag: mouse, or hold A on the pad) to wear it, swap the gloves or two belt slots, or take it off into
## the pack; or point and press Enter to wear or take off and Delete to drop it on the ground. The logic is
## Pack; Hud only places the window.

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const TILE_H := 48.0
const BADGE := 30.0
const HEAD_H := 20.0       # the key-pill row of a tile: as tall with or without a key, so the names line up
const ROW_H := 30.0        # one backpack line: a full pack fits a 720p window without scrolling
const ROW_BTN := 62.0

var _m: Match
var _p: Hunter
var _on_change: Callable
var _tip: InvTip
var _drag: SlotDrag
var _hover := {}           # {kind: "pack" or "worn", i: index} of the thing pointed at, for the keys
var _worn_tiles: Array = []
var _pack_rows: Array = []

## Fills `v`, the column of the item window `pc`, with the loadout. Returns [scroll, rows] for the
## backpack list so the window can be fitted to the screen. `on_change` rebuilds the window.
static func fill(m: Match, pc: PanelContainer, v: VBoxContainer, on_change: Callable) -> Array:
	var lp := LoadoutPanel.new()
	lp._m = m
	lp._p = m.player
	lp._on_change = on_change
	lp._tip = InvTip.new(pc)
	pc.add_child(lp)
	lp.add_child(lp._tip)
	lp._drag = SlotDrag.attach(lp, lp._move)
	return lp._fill(v)

func _fill(v: VBoxContainer) -> Array:
	var worn := UI.hbox(6)
	for slot in Gear.SLOTS.size():
		worn.add_child(_worn_tile(slot))
	v.add_child(worn)
	var belt := UI.hbox(6)
	for k in UtilityBelt.SLOTS:
		belt.add_child(_belt_tile(k))
	v.add_child(belt)
	if not _p.perks.is_empty():
		var perks := UI.hbox(8)
		var cap := UI.label("Perks", 12, MUTED, UI.caps)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		perks.add_child(cap)
		var badges := _perk_badges()
		badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		perks.add_child(badges)
		v.add_child(perks)
	v.add_child(UI.label("Carrying home  ·  %d of %d" % [_p.pack.size(), _p.pack_cap], 12, MUTED, UI.caps))
	return _pack_list(v)

## Shows the hover card of a thing without the pointer (the screenshot tool): kind "worn" or "pack".
func hover_demo(kind: String, i: int) -> void:
	var tiles: Array = _worn_tiles if kind == "worn" else _pack_rows
	if i < tiles.size():
		_tip.show_for(tiles[i], _lines(kind, i))

# ------------------------------------------------------------------ the slots
func _worn_tile(slot: int) -> PanelContainer:
	var g: Dictionary = _p.gear[slot]
	var caption := Gloves.key_cap(slot) if slot < 2 else ""
	var title: String = "Glove" if slot < 2 else Gear.WORN_NAMES[slot]
	var t: PanelContainer
	if g.is_empty():
		t = _tile(caption, title, "", MUTED, "empty")
		_drag.add(t, {"inv": "worn", "i": slot})
	else:
		var it := Loot.gear(String(g["id"]), int(g["rar"]))
		t = _tile(caption, title, Loot.icon_of(it), Loot.col_of(it), String(Gear.ALL[it["id"]]["name"]))
		_drag.add(t, {"inv": "worn", "i": slot}, Loot.name_of(it), Loot.col_of(it))
	_tip.attach(t, func(): return _lines("worn", slot), func(): _hover = {"kind": "worn", "i": slot},
		func(): _hover = {})
	_worn_tiles.append(t)
	return t

func _belt_tile(k: int) -> PanelContainer:
	var s: Dictionary = _p.belt[k]
	var key := Settings.key_cap(UtilityBelt.KEYS[k])
	var t: PanelContainer
	if s.is_empty():
		t = _tile(key, "", "", MUTED, "empty")
		_drag.add(t, {"inv": "belt", "i": k})
	else:
		var id := String(s["id"])
		t = _tile(key, "", UtilityBelt.icon_of(id), UtilityBelt.col_of(id), UtilityBelt.name_of(id), int(s["n"]))
		_drag.add(t, {"inv": "belt", "i": k}, UtilityBelt.name_of(id), UtilityBelt.col_of(id))
	_tip.attach(t, func(): return BeltHud.tip(_p, k))
	return t

## A slot: the key it answers to and what it is, then the icon and the name of what is in it, and how
## many for a stack (`count` > 0), kept apart from the name so a long name never hides it.
func _tile(key: String, slot_name: String, icon: String, col: Color, item_name: String, count := 0) -> PanelContainer:
	var t := PanelContainer.new()
	var filled := icon != ""
	t.add_theme_stylebox_override("panel", UI.frame(Color(col, 0.1 if filled else 0.04), 9,
			Color(col, 0.65 if filled else 0.3), 2, 5, 5))
	t.custom_minimum_size = Vector2(10.0, TILE_H)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UI.vbox(2)
	t.add_child(v)
	var head := UI.hbox(4)
	head.custom_minimum_size.y = HEAD_H
	if key != "":
		head.add_child(_key_pill(key))
	var caption := UI.label(slot_name, 11, MUTED, UI.caps)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(caption)
	if icon != "":
		head.add_child(Icons.Glyph.new(icon, col, 16.0))
	v.add_child(head)
	var nm := UI.label(item_name, 12, col if icon != "" else Color(MUTED, 0.7), UI.semi)
	nm.clip_text = true
	nm.custom_minimum_size.x = 10.0
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := UI.hbox(4)
	line.add_child(nm)
	if count > 0:
		line.add_child(UI.label("x%d" % count, 12, INK, UI.big))
	v.add_child(line)
	return t

func _key_pill(key: String) -> Control:
	var pill := UI.card(Color(1, 1, 1, 0.16), 3, 5)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UI.label(key, 11, INK, UI.big))
	return pill

func _perk_badges() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	var seen: Array = []
	for pk in _p.perks:
		if seen.has(pk):
			continue
		seen.append(pk)
		var pd: Dictionary = Data.PERKS[pk]
		var n := _p.perk_n(pk)
		var b := UI.card(Color(pd["col"], 0.12), 4, 8)
		b.custom_minimum_size = Vector2(BADGE, BADGE)
		var row := UI.hbox(3)
		row.add_child(Icons.Glyph.new(String(pd["icon"]), pd["col"], 16.0))
		if n > 1:
			row.add_child(UI.label("x%d" % n, 12, INK, UI.big))
		b.add_child(row)
		_tip.attach(b, func(): return InvText.perk(String(pk), n))
		flow.add_child(b)
	return flow

# ------------------------------------------------------------------ the backpack list
func _pack_list(v: VBoxContainer) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := UI.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	v.add_child(sc)
	if _p.pack.is_empty():
		rows.add_child(UI.label("Nothing yet. Gear and treasure you pick up go here.", 13, MUTED))
	for i in _p.pack.size():
		rows.add_child(_pack_row(i))
	var room := _p.pack_cap - _p.pack.size()
	if room > 0:
		var empty := UI.card(Color(1, 1, 1, 0.03), 6, 9)
		empty.custom_minimum_size.y = ROW_H - 4.0
		empty.add_child(UI.label("%d empty slot%s" % [room, "" if room == 1 else "s"], 12, Color(MUTED, 0.6)))
		_drag.add(empty, {"inv": "pack", "i": -1})
		rows.add_child(empty)
	return [sc, rows]

## One line: icon, plain name, worth, Wear (gear only) and Drop. What it does is on the hover card.
func _pack_row(i: int) -> PanelContainer:
	var it: Dictionary = _p.pack[i]
	var col := Loot.col_of(it)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UI.frame(Color(col, 0.09), 7, Color(col, 0.5), 1, 8, 2))
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var line := UI.hbox(6)
	row.add_child(line)
	line.add_child(Icons.Glyph.new(Loot.icon_of(it), col, 18.0))
	var nm := UI.label(Loot.name_of(it), 13, col, UI.semi)
	nm.clip_text = true
	nm.custom_minimum_size.x = 10.0
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(nm)
	line.add_child(Icons.Glyph.new("gem", Color(LootHold.GOLD, 0.8), 11.0))
	var worth := UI.label("%d" % Loot.value(it), 12, LootHold.GOLD, UI.big)
	worth.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(worth)
	if String(it.get("t", "")) == "gear":
		line.add_child(_row_button("Wear", func(): _act(func(): Pack.use_from_pack(_m, _p, i))))
	line.add_child(_row_button("Drop", func(): _act(func(): Pack.drop_from_pack(_m, _p, i))))
	_drag.add(row, {"inv": "pack", "i": i}, Loot.name_of(it), Loot.col_of(it))
	_tip.attach(row, func(): return _lines("pack", i), func(): _hover = {"kind": "pack", "i": i}, func(): _hover = {})
	_pack_rows.append(row)
	return row

func _row_button(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, ROW_BTN)
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size.y = ROW_H - 6.0
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:      # theme padding is for full-size buttons
		var box := b.get_theme_stylebox(state).duplicate() as StyleBox
		box.content_margin_top = 1.0
		box.content_margin_bottom = 1.0
		b.add_theme_stylebox_override(state, box)
	return b

# ------------------------------------------------------------------ hover cards and keys
func _lines(kind: String, i: int) -> Array:
	if kind == "worn":
		return InvText.worn(_p, i, "Enter takes it off  ·  Delete drops it")
	var it: Dictionary = _p.pack[i]
	if String(it.get("t", "")) == "gear":
		var lines := InvText.compare(_p, it)
		lines.append(["Enter or drag onto a slot wears it  ·  Delete drops it", MUTED, InvText.SMALL])
		return lines
	return [[Loot.name_of(it), Loot.col_of(it)], [Loot.sub_of(it), InvText.INK],
		["Delete drops it", MUTED, InvText.SMALL]]

func _input(event: InputEvent) -> void:
	if _hover.is_empty() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var i := int(_hover["i"])
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_act(func(): _wear_or_take_off(i))
		KEY_DELETE, KEY_BACKSPACE:
			_act(func(): _drop(i))
		_:
			return
	get_viewport().set_input_as_handled()

func _wear_or_take_off(i: int) -> void:
	if _hover["kind"] == "worn":
		Pack.take_off(_m, _p, i)
	else:
		Pack.use_from_pack(_m, _p, i)

func _drop(i: int) -> void:
	if _hover["kind"] == "worn":
		Pack.drop_worn(_m, _p, i)
	else:
		Pack.drop_from_pack(_m, _p, i)

## Runs a change to what you carry, then rebuilds the window.
func _act(change: Callable) -> void:
	change.call()
	_hover = {}
	_on_change.call()

# ------------------------------------------------------------------ dragging
## A dropped thing (SlotDrag): makes the move and rebuilds, or says why it can't go there.
func _move(from: Dictionary, to: Dictionary) -> String:
	var a := int(from["i"])
	var b := int(to["i"])
	match [from["inv"], to["inv"]]:
		["pack", "worn"]:
			var it: Dictionary = _p.pack[a]
			if String(it.get("t", "")) != "gear":
				return "Only gear is worn"
			var id := String(it["id"])
			if not Pack.fits_slot(id, b):
				return "That goes in the %s slot" % ("Glove" if Gear.is_glove(id) else Gear.slot_name(id))
			_act(func(): Pack.use_from_pack(_m, _p, a, b))
		["worn", "worn"]:
			if a > 1 or b > 1:
				return "Only the gloves swap"
			_act(func(): Pack.swap_gloves(_p))
		["worn", "pack"]:
			if not Pack.room(_p):
				return "Your pack is full"
			_act(func(): Pack.take_off(_m, _p, a))
		["belt", "belt"]:
			_act(func(): UtilityBelt.swap_slots(_p, a, b))
		["pack", "pack"]:
			return ""
		["belt", _]:
			return "Belt items stay on the belt"
		_:
			return "The belt holds only belt items"
	return ""
