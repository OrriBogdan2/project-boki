class_name LootWindow
extends PanelContainer
## The deathbox loot window: one panel, two columns. Left, what is in the box, grouped by kind, each
## thing one line in its rarity colour with an UPGRADE mark where it beats what you wear and one button.
## Right, you: what you wear (marked WORN, in place) and then your backpack. Point at a thing for its
## card (gear is compared with what you wear). Interact takes everything worth having (better gear goes
## on), Enter takes the thing pointed at, Esc closes. With a full backpack a clicked thing is held and
## each of your backpack things gets a Swap. The logic is Life, Pack and LootFull; Hud opens and closes it.

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const GOOD := Color("8fe0a0")
const COL_W := 380.0        # px, width of each column
const ROW_H := 40.0         # px, every row is one line this tall
const ICON := 22.0          # px, item glyphs
## px of screen height kept clear of the window's lists: the top counters, the bottom-right weapon and
## belt cluster and the window's own header, column titles and footer.
const RESERVED_H := 420.0
## The box column's groups: [title, row keys]. Backpack things that are gear count as Gear.
const GROUPS := [["Gear", ["gear", "backpack"]], ["Treasure", ["gems", "seeds", "pack"]],
	["Supplies", ["belt", "chest_keys"]], ["Boki", ["caught"]]]

var _m: Match
var _b: Dictionary
var _on_close: Callable
var _held := -1             # box backpack index of a clicked thing that has no room, or -1
var _sig := ""
var _tip: InvTip
var _hover := Callable()    # what Enter does: takes the box thing pointed at

static func make(m: Match, b: Dictionary, on_close: Callable) -> LootWindow:
	var w := LootWindow.new()
	w._m = m
	w._b = b
	w._on_close = on_close
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.add_theme_stylebox_override("panel", UI.frame(Color(0.06, 0.065, 0.1, 0.95), 14,
		Color(Life.box_color(b), 0.8), 2, 14, 12))
	# centred a little above the middle (_fill sets the offsets to its size)
	w.anchor_left = 0.5
	w.anchor_right = 0.5
	w.anchor_top = 0.46
	w.anchor_bottom = 0.46
	return w

func _ready() -> void:
	_fill()

## Rebuilds when what is in the box or on you changed (Hud calls it every frame while it is open).
func tick() -> void:
	if _state() != _sig:
		_fill()

func _state() -> String:
	var p: Hunter = _m.player
	var rows := Life.box_items(_m, p, _b).map(func(it): return [it["name"], it["upgrade"]])
	return str(rows) + str(p.gear) + str(p.pack.map(func(it): return it.get("uid", it.get("id", "")))) \
		+ str(p.pack_cap) + str(_held)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			_on_close.call()
		KEY_ENTER, KEY_KP_ENTER:
			if not _hover.is_valid():
				return
			_hover.call()
		_:
			return
	get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ building
func _fill() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_hover = Callable()
	_sig = _state()
	_tip = InvTip.new(self)
	add_child(_tip)
	var p: Hunter = _m.player
	var items: Array = Life.box_items(_m, p, _b)
	if _held >= 0 and not items.any(func(it): return it["key"] == "pack" and int(it["i"]) == _held):
		_held = -1
	var v := UI.vbox(10)
	add_child(v)
	var o: Hunter = _b["owner"]
	v.add_child(_head("Your deathbox" if o == p else "%s's deathbox" % o.pname))
	var cols := UI.hbox(16)
	v.add_child(cols)
	var box_list := _box_list(items)
	var you_list := _you_list(p)
	cols.add_child(_column("In the box", null, box_list))
	cols.add_child(_column(_you_title(items), _pack_count(p), you_list))
	v.add_child(_foot())
	# both lists are in the tree now, so their rows can be measured: one height for both, scrolling past cap
	var cap := maxf(ROW_H * 3.0, get_viewport_rect().size.y - RESERVED_H)
	var list_h := minf(cap, maxf(box_list.get_combined_minimum_size().y, you_list.get_combined_minimum_size().y))
	for list in [box_list, you_list]:
		(list.get_parent() as Control).custom_minimum_size.y = list_h
	var sz := get_combined_minimum_size()
	offset_left = -sz.x * 0.5
	offset_right = sz.x * 0.5
	offset_top = -sz.y * 0.5
	offset_bottom = sz.y * 0.5

func _head(title: String) -> HBoxContainer:
	var head := UI.hbox(8)
	head.add_child(Icons.Glyph.new("gem", Life.box_color(_b), 18.0))
	var t := UI.title(title, 22, INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var cl := UI.button("✕", _on_close, 36)
	cl.flat = true
	cl.focus_mode = Control.FOCUS_NONE
	head.add_child(cl)
	return head

## A column: its title (and a counter on the right), then its list in a scroll box (_fill sets its height).
func _column(title: String, counter: Control, list: VBoxContainer) -> VBoxContainer:
	var col := UI.vbox(6)
	col.custom_minimum_size.x = COL_W
	var head := UI.hbox(6)
	var held := _held >= 0 and counter != null
	var t := UI.label(title, 12, LootFull.FULL_COL if held else MUTED, UI.caps)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	head.add_child(t)
	if counter:
		head.add_child(counter)
	col.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.x = COL_W
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	col.add_child(sc)
	return col

func _foot() -> HBoxContainer:
	var foot := UI.hbox(10)
	var all := UI.primary("Take all  (%s)" % Settings.key_cap("interact"), _take_all, 200)
	all.focus_mode = Control.FOCUS_NONE
	all.tooltip_text = "Better gear goes on, the rest into your backpack while there is room"
	foot.add_child(all)
	var hint := UI.label("Point at a thing to compare  ·  Enter takes it  ·  Esc closes", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	return foot

# ------------------------------------------------------------------ the box column
func _box_list(items: Array) -> VBoxContainer:
	var list := UI.vbox(4)
	if items.is_empty():
		list.add_child(UI.label("Empty.", 14, MUTED))
	for g in GROUPS.size():
		var rows: Array = items.filter(func(it): return _group_of(it) == g)
		if rows.is_empty():
			continue
		rows = rows.filter(func(it): return it["upgrade"]) + rows.filter(func(it): return not it["upgrade"])
		list.add_child(UI.label(String(GROUPS[g][0]), 11, MUTED, UI.caps))
		for it in rows:
			list.add_child(_box_row(it))
	return list

func _group_of(it: Dictionary) -> int:
	var key := String(it["key"])
	if key == "pack" and String((_b["pack"][int(it["i"])] as Dictionary).get("t", "")) == "gear":
		return 0
	for g in GROUPS.size():
		if key in GROUPS[g][1]:
			return g
	return GROUPS.size() - 1

func _box_row(it: Dictionary) -> PanelContainer:
	var p: Hunter = _m.player
	var fit := LootFull.fits(p, it, _b)
	var held := String(it["key"]) == "pack" and int(it["i"]) == _held
	var wears := String(it["key"]) == "gear" or bool(it.get("wear", false))
	var up := wears and bool(it["upgrade"])
	var verb := "Take"
	if held:
		verb = "Cancel"
	elif wears:
		verb = "Wear"
	elif not fit and not LootFull.holdable(it):
		verb = "Full"
	var on_take := func(): take(it)
	var rp := _row(String(it["icon"]), it["col"], String(it["name"]), "UPGRADE" if up else "", GOOD, verb, on_take, up)
	if held or not fit:
		LootHold.mark_full(rp)
	var gear_it := InvText.box_gear(_b, it)
	var lines := func(): return InvText.compare(p, gear_it) if not gear_it.is_empty() \
		else [[String(it["name"]), it["col"]], [String(it["sub"]), INK]]
	_tip.attach(rp, lines, func(): _hover = on_take, func(): _hover = Callable())
	return rp

## A click on a box row's button (public: the checks and screenshots press rows). A thing with no room
## is held; pressing the held one again lets it go.
func take(it: Dictionary) -> void:
	var p: Hunter = _m.player
	if p == null:
		return
	if String(it["key"]) == "pack" and int(it["i"]) == _held:
		_held = -1
	elif not LootFull.click(_m, p, _b, it) and LootFull.holdable(it):
		_held = int(it["i"])
	_fill()

func _take_all() -> void:
	if _m.player == null:
		return
	if LootFull.smart(_m, _m.player, _b) > 0 or _b.get("empty", false):
		_on_close.call()

# ------------------------------------------------------------------ your column
func _you_title(items: Array) -> String:
	if _held < 0:
		return "You"
	for it in items:
		if it["key"] == "pack" and int(it["i"]) == _held:
			return "No room for %s: swap one" % it["name"]
	return "You"

func _pack_count(p: Hunter) -> Label:
	var full: bool = p.pack.size() >= p.pack_cap
	var l := UI.label("Backpack %d/%d" % [p.pack.size(), p.pack_cap], 12, LootFull.FULL_COL if full else MUTED, UI.semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

## What you wear (marked WORN) and then your backpack, in one list.
func _you_list(p: Hunter) -> VBoxContainer:
	var list := UI.vbox(4)
	for slot in Gear.SLOTS.size():
		var g: Dictionary = p.gear[slot]
		if g.is_empty():
			continue
		var it := Loot.gear(String(g["id"]), int(g["rar"]))
		var rp := _row(Loot.icon_of(it), Loot.col_of(it), Loot.name_of(it), "WORN", INK, "", Callable(), false)
		_tip.attach(rp, func(): return InvText.worn(p, slot, "Worn now"))
		list.add_child(rp)
	for i in p.pack.size():
		var it: Dictionary = p.pack[i]
		var swap := func(): _swap(i)
		var rp := _row(Loot.icon_of(it), Loot.col_of(it), Loot.name_of(it), "", INK,
			"Swap" if _held >= 0 else "", swap, true)
		var lines := func(): return InvText.compare(p, it) if String(it.get("t", "")) == "gear" \
			else [[Loot.name_of(it), Loot.col_of(it)], [Loot.sub_of(it), INK], ["Worth %d" % Loot.value(it), MUTED]]
		_tip.attach(rp, lines)
		list.add_child(rp)
	var room := p.pack_cap - p.pack.size()
	if room > 0:
		list.add_child(UI.label("%d free backpack slot%s" % [room, "" if room == 1 else "s"], 12, Color(MUTED, 0.7)))
	return list

func _swap(mine: int) -> void:
	if _m.player and LootFull.swap_held(_m, _m.player, _b, _held, mine):
		_held = -1
		if _b.get("empty", false):
			_on_close.call()
			return
	_fill()

# ------------------------------------------------------------------ one row
## One line: icon, name in its colour, an optional tag, an optional button. A row with a button is
## clickable as a whole.
func _row(icon: String, col: Color, item_name: String, tag: String, tag_col: Color, verb: String, cb: Callable,
		primary: bool) -> PanelContainer:
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", LootHold.row_box(col, 3))
	rp.custom_minimum_size.y = ROW_H
	rp.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := UI.hbox(8)
	rp.add_child(row)
	var glyph := Icons.Glyph.new(icon, col, ICON)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var nm := UI.label(item_name, 15, col, UI.semi)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.custom_minimum_size.x = 10.0
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	if tag != "":
		var tl := UI.label(tag, 11, tag_col, UI.caps)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tl)
	if verb != "":
		var b: Button = UI.primary(verb, cb, 76) if primary else UI.button(verb, cb, 76)
		b.focus_mode = Control.FOCUS_NONE       # Space jumps: a focused button would take things by itself
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		LootHold.row_click(rp, cb)
	return rp
