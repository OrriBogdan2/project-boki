class_name DexFilter
extends RefCounted
## The Field Book's filter bar and the rules behind it: type chips (a two-type Boki matches either),
## a status (seen, caught, owned now) and "thrives in" (a garden zone whose types match, read from
## content/rules/garden_zones.json when that exists). The grid always lists the matches in Field Book
## order, so every legendary stays at the very end. The picks live for the session only: they are
## statics, never written to the save.

const STATUSES := [["", "All"], ["seen", "Seen"], ["caught", "Caught"], ["owned", "Owned now"]]
const CHIP_PX := 28.0       # a type chip's width (its icon is drawn inside); 18 of them fit one row
const COLUMNS := 6          # tiles per row

static var types: Array = []     # the type ids picked (empty = every type)
static var status := ""          # "", "seen", "caught" or "owned"
static var zone := ""            # a garden zone id, "" = anywhere
static var more_open := false    # the "More" row is showing

static func zones() -> Dictionary:
	return Content.rules("garden_zones").get("zones", {})

static func reset() -> void:
	types = []
	status = ""
	zone = ""

static func active() -> bool:
	return not types.is_empty() or status != "" or zone != ""

## A species' one or two types.
static func types_of(spk: String) -> Array:
	var sp: Dictionary = Data.KIN.get(spk, {})
	return [String(sp.get("type", "")), String(sp.get("type2", ""))].filter(func(t): return t != "")

## Species you have right now, in the party, the garden or the Burrow.
static func owned(spk: String) -> bool:
	return (Save.d.get("roster", []) as Array).any(func(r): return String(r.get("species", "")) == spk)

static func matches(spk: String) -> bool:
	var mine := types_of(spk)
	if not types.is_empty() and not mine.any(func(t): return types.has(t)):
		return false
	if zone != "" and not mine.any(func(t): return (zones().get(zone, {}).get("types", []) as Array).has(t)):
		return false
	match status:
		"seen": return FieldBook.form_seen(spk) or FieldBook.form_caught(spk)
		"caught": return FieldBook.form_caught(spk)
		"owned": return owned(spk)
	return true

## The Field Book entries that pass, in Field Book order (legendaries last).
static func species() -> Array:
	return FieldBook.entries().filter(matches)

## The bar and the grid under it; picking anything rebuilds both.
class Browser extends VBoxContainer:
	var _tree: SceneTree
	var _on_open: Callable
	var _bar := UI.vbox(6)
	var _grid := GridContainer.new()

	func _init(tree: SceneTree, on_open: Callable) -> void:
		_tree = tree
		_on_open = on_open
		add_theme_constant_override("separation", 10)
		_grid.columns = DexFilter.COLUMNS
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		add_child(_bar)
		add_child(_grid)
		refresh()

	func refresh() -> void:
		for n in _bar.get_children():
			n.queue_free()
		_bar.add_child(_row())
		if DexFilter.more_open and not DexFilter.zones().is_empty():
			_bar.add_child(_more_row())
		for n in _grid.get_children():
			n.queue_free()
		var hits := DexFilter.species()
		for spk in hits:
			_grid.add_child(DexView.tile(spk, _tree, _on_open))
		if hits.is_empty():
			_bar.add_child(UI.para("No Boki match these filters."))

	## The bar: the seen/caught counts and the status picks, then the type chips, More, Clear and the count.
	func _row() -> Control:
		var col := UI.vbox(8)
		var head := UI.hbox(10)
		var c := DexView.counts()
		head.add_child(UI.chip("eye", "Seen %d" % c.x, UI.INK))
		head.add_child(UI.chip("paw", "Caught %d" % c.y, UI.INK))
		head.add_child(UI.fill())
		for s in DexFilter.STATUSES:
			head.add_child(UI.choice(s[1], DexFilter.status == s[0], _pick_status.bind(s[0])))
		col.add_child(head)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 6)
		var tc := DexView.type_counts()
		for t in DexView.TYPES:
			row.add_child(_type_chip(t, tc.get(t, Vector2i.ZERO)))
		if not DexFilter.zones().is_empty():
			row.add_child(UI.choice("More", DexFilter.more_open or DexFilter.zone != "", _toggle_more))
		if DexFilter.active():
			row.add_child(UI.ghost("Clear", _clear))
		row.add_child(UI.chip("", "%d of %d" % [DexFilter.species().size(), Data.KIN.size()], UI.INK, "Species shown"))
		col.add_child(row)
		return col

	func _type_chip(t: String, seen_caught: Vector2i) -> Button:
		var b := UI.choice("", DexFilter.types.has(t), _toggle_type.bind(t), DexFilter.CHIP_PX)
		b.tooltip_text = "%s: seen %d, caught %d" % [DexView.type_name(t), seen_caught.x, seen_caught.y]
		var middle := CenterContainer.new()
		middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon := DexView.TypeIcon.new(t, 18.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		middle.add_child(icon)
		b.add_child(middle)
		return b

	## "Thrives in": the garden zones, each matching the types its Boki live best in.
	func _more_row() -> Control:
		var row := UI.hbox(8)
		row.add_child(UI.label("Thrives in", UI.T_SMALL, UI.MUTED))
		var zs := DexFilter.zones()
		row.add_child(UI.choice("Anywhere", DexFilter.zone == "", _pick_zone.bind("")))
		for id in zs:
			row.add_child(UI.choice(String(zs[id].get("name", id)), DexFilter.zone == id, _pick_zone.bind(id)))
		return row

	func _toggle_type(t: String) -> void:
		if DexFilter.types.has(t):
			DexFilter.types.erase(t)
		else:
			DexFilter.types.append(t)
		refresh()

	func _pick_status(s: String) -> void:
		DexFilter.status = s
		refresh()

	func _pick_zone(id: String) -> void:
		DexFilter.zone = id
		refresh()

	func _toggle_more() -> void:
		DexFilter.more_open = not DexFilter.more_open
		refresh()

	func _clear() -> void:
		DexFilter.reset()
		refresh()
