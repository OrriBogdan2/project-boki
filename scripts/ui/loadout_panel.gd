class_name LoadoutPanel
extends Node
## The body of the in-match inventory window (I, and beside an open deathbox): what you wear, the
## utility belt, your perks and the backpack, every slot labelled with its key. Point at a thing for a
## hover card (InvText: gear is compared with what you wear). Swap with the mouse by dragging a
## backpack piece onto a slot (or a glove onto the other glove), or point and press Enter to wear or take
## off and Delete to drop it on the ground. The logic is Pack; Hud only places the window.

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const TILE_H := 48.0
const BADGE := 30.0
const HINT := "Point at a thing:  Enter wears or takes it off  ·  Delete drops it  ·  or drag it onto a slot"

var _m: Match
var _p: Hunter
var _on_change: Callable
var _tip: InvTip
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
		v.add_child(UI.label("Perks this run", 12, MUTED, UI.caps))
		v.add_child(_perk_badges())
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
	else:
		var it := Loot.gear(String(g["id"]), int(g["rar"]))
		t = _tile(caption, title, Loot.icon_of(it), Loot.col_of(it), String(Gear.ALL[it["id"]]["name"]))
	t.set_drag_forwarding(_drag_worn.bind(slot, t), _can_drop_worn.bind(slot), _drop_worn.bind(slot))
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
	else:
		var id := String(s["id"])
		t = _tile(key, "", UtilityBelt.icon_of(id), UtilityBelt.col_of(id),
			"%s x%d" % [UtilityBelt.name_of(id), int(s["n"])])
	_tip.attach(t, func(): return BeltHud.tip(_p, k))
	return t

## A slot: the key it answers to and what it is, then the icon and the name of what is in it.
func _tile(key: String, slot_name: String, icon: String, col: Color, item_name: String) -> PanelContainer:
	var t := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.1 if icon != "" else 0.04)
	sb.set_corner_radius_all(9)
	sb.border_color = Color(col, 0.65 if icon != "" else 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(5)
	t.add_theme_stylebox_override("panel", sb)
	t.custom_minimum_size = Vector2(10.0, TILE_H)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UI.vbox(2)
	t.add_child(v)
	var head := UI.hbox(4)
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
	v.add_child(nm)
	return t

func _key_pill(key: String) -> Control:
	var pill := UI.card(Color(1, 1, 1, 0.16), 3, 5)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE      # a drag that starts on the key still drags the slot
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
	var rows := UI.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	v.add_child(sc)
	sc.set_drag_forwarding(Callable(), _can_take_off, _take_off)
	if _p.pack.is_empty():
		rows.add_child(UI.label("Nothing yet. Gear and treasure you pick up go here.", 13, MUTED))
	for i in _p.pack.size():
		rows.add_child(_pack_row(i))
	for k in mini(_p.pack_cap - _p.pack.size(), 3):
		var empty := UI.card(Color(1, 1, 1, 0.03), 6, 9)
		empty.custom_minimum_size.y = 30
		empty.add_child(UI.label("empty slot", 12, Color(MUTED, 0.6)))
		empty.set_drag_forwarding(Callable(), _can_take_off, _take_off)
		rows.add_child(empty)
	return [sc, rows]

func _pack_row(i: int) -> PanelContainer:
	var it: Dictionary = _p.pack[i]
	var buttons: Array = []
	if String(it.get("t", "")) == "gear":
		buttons.append(["Wear", func(): _act(func(): Pack.use_from_pack(_m, _p, i)), true])
	buttons.append(["Drop", func(): _act(func(): Pack.drop_from_pack(_m, _p, i))])
	var row := LootHold.item_row(it, buttons)
	row.set_drag_forwarding(_drag_pack.bind(i, row), _can_take_off, _take_off)
	_tip.attach(row, func(): return _lines("pack", i), func(): _hover = {"kind": "pack", "i": i}, func(): _hover = {})
	_pack_rows.append(row)
	return row

# ------------------------------------------------------------------ hover cards and keys
func _lines(kind: String, i: int) -> Array:
	if kind == "worn":
		return InvText.worn(_p, i, "Enter takes it off  ·  Delete drops it")
	var it: Dictionary = _p.pack[i]
	if String(it.get("t", "")) == "gear":
		var lines := InvText.compare(_p, it)
		lines.append(["Enter wears it  ·  Delete drops it", MUTED, InvText.SMALL])
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
func _drag_pack(_at: Vector2, i: int, row: Control) -> Variant:
	if String((_p.pack[i] as Dictionary).get("t", "")) != "gear":
		return null
	row.set_drag_preview(UI.label(Loot.name_of(_p.pack[i]), 15, Loot.col_of(_p.pack[i]), UI.semi))
	return {"inv": "pack", "i": i}

func _drag_worn(_at: Vector2, slot: int, tile: Control) -> Variant:
	var g: Dictionary = _p.gear[slot]
	if g.is_empty():
		return null
	var it := Loot.gear(String(g["id"]), int(g["rar"]))
	tile.set_drag_preview(UI.label(Loot.name_of(it), 15, Loot.col_of(it), UI.semi))
	return {"inv": "worn", "i": slot}

func _can_drop_worn(_at: Vector2, data: Variant, slot: int) -> bool:
	if not (data is Dictionary) or not data.has("inv"):
		return false
	var from := int(data["i"])
	if data["inv"] == "pack":
		return from < _p.pack.size() and Pack.fits_slot(String(_p.pack[from].get("id", "")), slot)
	return from != slot and from < 2 and slot < 2

func _drop_worn(_at: Vector2, data: Variant, slot: int) -> void:
	var from := int(data["i"])
	if data["inv"] == "pack":
		_act(func(): Pack.use_from_pack(_m, _p, from, slot))
	else:
		_act(func(): Pack.swap_gloves(_p))

func _can_take_off(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("inv", "") == "worn" and Pack.room(_p) \
		and not (_p.gear[int(data["i"])] as Dictionary).is_empty()

func _take_off(_at: Vector2, data: Variant) -> void:
	_act(func(): Pack.take_off(_m, _p, int(data["i"])))
