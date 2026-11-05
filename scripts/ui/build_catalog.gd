class_name BuildCatalog
extends PanelContainer
## The bottom catalog bar of build mode (the farm) and decorate mode (the house): category tabs, a search box,
## big item tiles (picture, name, price in have/need colours, how many you own), a Storage tab for what you
## own, and Undo / Done. The owner supplies the tabs and entries through the Callables below.
##
## An entry is a Dictionary: name, cb (clicked), and any of: id (picture cache key), model (Callable that builds
## the 3D piece for the picture), swatch (Color) or glyph (UI icon id) when there is no model, cost (materials,
## coloured by what you have), note (small line), owned (count badge), on (held right now), off (dimmed), tip.

const STORAGE := "Storage"
const TILE := Vector2(124, 112)
const PICTURE := Vector2(72, 52)
const NAV_W := 40.0
const THUMB_PX := 144
const HAVE_COL := Color("a6f0b0")

var tabs_fn: Callable             # () -> Array of tab names
var current_fn: Callable          # () -> the open tab
var pick_fn: Callable             # (tab) -> void
var entries_fn: Callable          # (tab) -> Array of entries
var extras_fn: Callable           # () -> Array of Controls shown beside the search box
var footer_fn: Callable           # (row: HBoxContainer) -> void: more for the hint line
var undo_fn: Callable
var undo_off_fn: Callable
var done_fn: Callable
var sweep_fn: Callable            # (on: bool) -> void: the put-away mode; unset hides the toggle
var sweep_on_fn: Callable         # () -> bool
var left_pad := 16.0
var search_skip: Array = []       # tabs a search does not look into
var hint: Label
var page := 0

var _query := ""
var _tabs_row: HBoxContainer
var _extras_row: HBoxContainer
var _search: LineEdit
var _undo: Button
var _sweep_slot: HBoxContainer
var _tiles: HBoxContainer
var _prev: Button
var _next: Button
var _foot: HBoxContainer
var _thumbs := {}                 # picture key -> SubViewport

func _init() -> void:
	var look := UI.card(Color(0.06, 0.07, 0.1, 0.93), 10, 14)
	add_theme_stylebox_override("panel", look.get_theme_stylebox("panel"))
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_top = -100
	offset_bottom = -12
	offset_right = -16
	var col := UI.vbox(7)
	add_child(col)
	var top := UI.hbox(6)
	col.add_child(top)
	_tabs_row = UI.hbox(5)
	top.add_child(_tabs_row)
	top.add_child(UI.fill())
	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(72, 0)
	_search.text_changed.connect(_on_search)
	_search.gui_input.connect(_on_search_key)
	top.add_child(_search)
	_sweep_slot = UI.hbox(0)
	top.add_child(_sweep_slot)
	_undo = UI.button("Undo", func(): undo_fn.call(), 76)
	top.add_child(_undo)
	top.add_child(UI.primary("Done", func(): done_fn.call(), 80))
	var mid := UI.hbox(8)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)
	_prev = UI.button("‹", func(): _turn_page(-1), NAV_W)
	mid.add_child(_prev)
	_tiles = UI.hbox(8)
	_tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_tiles)
	_next = UI.button("›", func(): _turn_page(1), NAV_W)
	mid.add_child(_next)
	_foot = UI.hbox(16)
	col.add_child(_foot)
	hint = UI.label("", 14, UI.INK)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(hint)
	_extras_row = UI.hbox(6)

## Rebuilds the tabs, the tiles and the buttons from the owner's current state.
func refresh() -> void:
	offset_left = left_pad
	var cur: String = current_fn.call()
	for old in _tabs_row.get_children():
		old.queue_free()
	_tabs_row.add_child(UI.tabs(tabs_fn.call(), cur, _pick))
	for old in _extras_row.get_children():
		old.queue_free()
	if extras_fn.is_valid():
		for ctl in extras_fn.call():
			_extras_row.add_child(ctl)
	_undo.disabled = bool(undo_off_fn.call())
	for old in _sweep_slot.get_children():
		old.queue_free()
	if sweep_fn.is_valid():
		var on := bool(sweep_on_fn.call())
		var toggle := UI.choice("Store", on, func(): sweep_fn.call(not on))
		toggle.tooltip_text = "Click pieces to put them away"
		_sweep_slot.add_child(toggle)
	for old in _foot.get_children():
		if old != hint and old != _extras_row:
			old.queue_free()
	if footer_fn.is_valid():
		footer_fn.call(_foot)
	if _extras_row.get_parent() == _foot:
		_foot.move_child(_extras_row, _foot.get_child_count() - 1)
	else:
		_foot.add_child(_extras_row)
	_fill_tiles()

## Lets go of the search box so keys reach build mode again.
func blur() -> void:
	if _search.has_focus():
		_search.release_focus()

func _pick(tab: String) -> void:
	page = 0
	pick_fn.call(tab)

func _turn_page(by: int) -> void:
	page += by
	_fill_tiles()

func _on_search(text: String) -> void:
	_query = text.strip_edges().to_lower()
	page = 0
	_fill_tiles()

func _on_search_key(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		_search.release_focus()
		accept_event()

func _entries() -> Array:
	var cur: String = current_fn.call()
	if _query == "":
		return entries_fn.call(cur)
	var out: Array = []
	for tab in tabs_fn.call():
		if search_skip.has(tab):
			continue
		for e in entries_fn.call(tab):
			if String(e["name"]).to_lower().contains(_query) and not out.any(func(o): return o["name"] == e["name"]):
				out.append(e)
	return out

func _fill_tiles() -> void:
	for old in _tiles.get_children():
		old.queue_free()
	var entries := _entries()
	var width := get_viewport().get_visible_rect().size.x - left_pad - 16.0 - 28.0 - 2.0 * (NAV_W + 8.0)
	var per_page := maxi(2, int(width / (TILE.x + 8.0)))
	var pages := maxi(1, int(ceil(entries.size() / float(per_page))))
	page = clampi(page, 0, pages - 1)
	_prev.disabled = page == 0
	_next.disabled = page >= pages - 1
	if entries.is_empty():
		_tiles.add_child(UI.label(_empty_text(), 15, UI.MUTED))
		return
	for e in entries.slice(page * per_page, page * per_page + per_page):
		_tiles.add_child(_tile(e))

func _empty_text() -> String:
	if _query != "":
		return "Nothing matches \"%s\"" % _query
	if String(current_fn.call()) == STORAGE:
		return "Storage is empty. Pieces you put away wait here."
	return "Nothing here yet"

func _tile(e: Dictionary) -> Control:
	var cb: Callable = e["cb"]
	var tile := UI.tile_card(bool(e.get("on", false)), cb, 5)
	tile.custom_minimum_size = TILE
	tile.tooltip_text = String(e.get("tip", ""))
	var col := UI.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(e.get("off", false)):
		col.modulate = Color(1, 1, 1, 0.5)
	tile.add_child(col)
	col.add_child(_picture(e))
	var title := UI.label(String(e["name"]), 13, UI.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(title)
	var cost: Dictionary = e.get("cost", {})
	if not cost.is_empty():
		col.add_child(FarmIcon.cost_row(cost, 13, 12))
	var note := String(e.get("note", ""))
	if note != "":
		var line := UI.label(note, 12, UI.MUTED)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.clip_text = true
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(line)
	return tile

func _picture(e: Dictionary) -> Control:
	var pic := Control.new()
	pic.custom_minimum_size = PICTURE
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e.has("model"):
		var view := TextureRect.new()
		view.texture = _thumb(String(e.get("id", e["name"])), e["model"])
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(view)
	elif e.has("swatch"):
		var chip := Panel.new()
		chip.add_theme_stylebox_override("panel", UI.frame(e["swatch"], 8, Color(1, 1, 1, 0.25), 1))
		chip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(chip)
	elif e.has("glyph"):
		var glyph: String = e["glyph"]
		pic.draw.connect(func(): UI.draw_icon(pic, glyph, pic.size * 0.5, 18.0, UI.GOLD))
	var owned := int(e.get("owned", 0))
	if owned > 0:
		var badge := UI.tag("×%d" % owned, UI.GOLD)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		pic.add_child(badge)
	return pic

## The picture of an item: its model, lit and framed from above and the side, drawn once.
func _thumb(key: String, make_model: Callable) -> Texture2D:
	if _thumbs.has(key):
		return (_thumbs[key] as SubViewport).get_texture()
	var view := SubViewport.new()
	view.size = Vector2i(THUMB_PX, int(THUMB_PX * PICTURE.y / PICTURE.x))
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8cde8")
	env.environment.ambient_light_energy = 0.9
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	view.add_child(sun)
	var model: Node3D = make_model.call()
	for light in model.find_children("*", "Light3D", true, false):
		light.queue_free()
	view.add_child(model)
	var boxes: Array = []
	_collect(model, Transform3D.IDENTITY, boxes)
	var box := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE) if boxes.is_empty() else boxes[0] as AABB
	for part in boxes:
		box = box.merge(part)
	var centre := box.get_center()
	var span := sqrt(box.size.x * box.size.x + box.size.z * box.size.z) * 0.62 + box.size.y * 0.85
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(span, 0.8) * 1.18
	view.add_child(cam)
	cam.position = centre + Vector3(1.0, 1.1, 1.6).normalized() * 20.0
	cam.look_at_from_position(cam.position, centre, Vector3.UP)
	add_child(view)
	_thumbs[key] = view
	return view.get_texture()

func _collect(node: Node3D, xf: Transform3D, boxes: Array) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var t := xf * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			boxes.append(t * (child as MeshInstance3D).mesh.get_aabb())
		_collect(child, t, boxes)
