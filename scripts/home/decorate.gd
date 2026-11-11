class_name Decorate
extends RefCounted
## Decorate mode inside the house: the same catalog bar, ghost, key hints and piece menu as the farm's build mode
## (BuildCatalog, BuildKeys, BuildMenu, Placement), working on the room's furniture. The room (Interior) keeps the
## furniture list and the tile grid; this holds what is in your hand.

const CATS := ["Beds & seats", "Tables & shelves", "Rugs", "Decor", "Useful"]
const FILL_GOOD := Color(0.45, 1.0, 0.55, 0.42)
const FILL_BAD := Color(1.0, 0.4, 0.35, 0.5)
const UNDO_CAP := 30

var room                              # the Interior this decorates
var active := false
var held := {}                        # {id, r, from (index into the room's decor, or -1 for a new piece)}
var cat := CATS[0]
var sweep := false                    # the quick put-away mode: a click stores the piece it lands on
var bar: BuildCatalog = null
var keys: BuildKeys = null
var menu: BuildMenu = null
var ghost: Node3D = null
var footprint: Node3D = null
var ghost_ok := false
var ghost_cell := Vector2i.ZERO
var undo: Array = []
var debug_m := Vector2.INF            # tooling: where the "mouse" is, for screenshots
var _glowing: Node3D = null
var _foot_sig := ""

func _init(interior) -> void:
	room = interior

# ------------------------------------------------------------------ on / off
func toggle() -> void:
	if not room.visit.is_empty():
		return
	active = not active
	room.decorating = active
	if active:
		room._close_panel()
		room.prompt_box.visible = false
		Placement.build_view(room.cam, true)
		_open_ui()
		Sfx.play("ui_open", null, -8.0)
	else:
		_drop_held()
		_close_menu()
		_light(null)
		Placement.build_view(room.cam, false)
		for part in [bar, keys]:
			if is_instance_valid(part): part.queue_free()
		bar = null
		keys = null
		sweep = false
		Save.save_game()
	room._deco_button_text()

func _open_ui() -> void:
	bar = BuildCatalog.new()
	bar.tabs_fn = func() -> Array: return CATS + [BuildCatalog.STORAGE]
	bar.current_fn = func() -> String: return cat
	bar.pick_fn = func(tab: String) -> void:
		cat = tab
		refresh()
	bar.entries_fn = _entries
	bar.undo_fn = undo_last
	bar.undo_off_fn = func() -> bool: return undo.is_empty()
	bar.done_fn = toggle
	bar.sweep_fn = _set_sweep
	bar.sweep_on_fn = func() -> bool: return sweep
	room.root_ui.add_child(bar)
	keys = BuildKeys.new()
	keys.above = bar
	room.root_ui.add_child(keys)
	refresh()

func refresh() -> void:
	if not active:
		return
	bar.refresh()
	room._deco_button_text()
	_update_keys()

func _set_sweep(on: bool) -> void:
	sweep = on
	refresh()

# ------------------------------------------------------------------ the catalog
func stored(id: String) -> int:
	return int(Save.d["furniture"].get(id, 0))

func _entries(tab: String) -> Array:
	var out: Array = []
	for id in Data.FURN:
		var count := stored(id)
		if String(Data.FURN[id]["cat"]) == tab or (tab == BuildCatalog.STORAGE and count > 0):
			out.append(_entry(id, count))
	return out

func _entry(id: String, count: int) -> Dictionary:
	var price := int(Data.FURN[id]["price"])
	var piece_id := id
	var is_held: bool = held.get("id", "") == id and int(held.get("from", -1)) < 0
	var cannot_afford: bool = count == 0 and int(Save.d["gems"]) < price
	var cost := {}
	if count == 0:
		cost = {"gems": price}
	return {"id": id, "name": String(Data.FURN[id]["name"]), "owned": count,
		"note": "from storage" if count > 0 else "", "cost": cost,
		"cb": func(): take(piece_id), "on": is_held, "off": cannot_afford,
		"model": func() -> Node3D: return room._make_piece(piece_id, 0)}

## Takes a new piece into the hand: one from storage, or one to buy as it is put down.
func take(id: String) -> void:
	_drop_held()
	if stored(id) == 0 and int(Save.d["gems"]) < int(Data.FURN[id]["price"]):
		room._toast("You need %d gems for that" % int(Data.FURN[id]["price"]))
		return
	held = {"id": id, "r": 0, "from": -1}
	_make_ghost()
	refresh()

# ------------------------------------------------------------------ the hand
func _make_ghost() -> void:
	_clear_ghost()
	if held.is_empty():
		return
	ghost = room._make_piece(held["id"], int(held["r"]))
	for mesh in ghost.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).transparency = 0.35
	for light in ghost.find_children("*", "Light3D", true, false):
		light.queue_free()
	room.add_child(ghost)
	footprint = Node3D.new()
	room.add_child(footprint)
	_foot_sig = ""

func _clear_ghost() -> void:
	for node in [ghost, footprint]:
		if is_instance_valid(node): node.queue_free()
	ghost = null
	footprint = null

func _drop_held() -> void:
	if held.is_empty():
		return
	if int(held["from"]) >= 0 and room.nodes.size() > int(held["from"]):
		room.nodes[int(held["from"])].visible = true
	held = {}
	_clear_ghost()

func cancel_held() -> void:
	_drop_held()
	refresh()

func can_rotate() -> bool:
	return not held.is_empty()

func rotate_held() -> void:
	if held.is_empty():
		return
	held["r"] = (int(held["r"]) + 1) % 4
	Sfx.play("click", null, -6.0, 0.1, 1.3)

func _mouse_cell() -> Vector2:
	if debug_m != Vector2.INF:
		return debug_m
	var p: Vector3 = room.cam.mouse_on_plane(0.0)
	return Vector2(p.x, p.z)

## Every frame: the ghost follows the cursor, snapped to the grid, tinted green or red.
func tick(delta: float) -> void:
	if not active:
		return
	if held.is_empty():
		_update_keys()
		return
	var id := String(held["id"])
	var turn := int(held["r"])
	var fp: Vector2i = room.footprint(id, turn)
	var m := _mouse_cell()
	ghost_cell = Vector2i(int(round(m.x - fp.x * 0.5)), int(round(m.y - fp.y * 0.5)))
	ghost_ok = room._fits(id, ghost_cell.x, ghost_cell.y, turn, int(held["from"]))
	room._place_node(ghost, id, ghost_cell.x, ghost_cell.y, turn)
	ghost.position.y = 0.04
	Placement.turn_toward(ghost, -turn * PI * 0.5, delta)
	_draw_footprint(fp)
	_update_keys()

func _draw_footprint(fp: Vector2i) -> void:
	var sig := "%s|%s|%s" % [ghost_cell, fp, ghost_ok]
	if sig == _foot_sig:
		return
	_foot_sig = sig
	for old in footprint.get_children():
		old.queue_free()
	var cells: Array = []
	for dz in fp.y:
		for dx in fp.x:
			cells.append(Vector2i(ghost_cell.x + dx, ghost_cell.y + dz))
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = FILL_GOOD if ghost_ok else FILL_BAD
	var tile := PlaneMesh.new()
	tile.size = Vector2(0.92, 0.92)
	for c in cells:
		var mesh := MeshInstance3D.new()
		mesh.mesh = tile
		mesh.material_override = fill
		mesh.position = Vector3(c.x + 0.5, 0.03, c.y + 0.5)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		footprint.add_child(mesh)
	FarmBuildUi.outline(footprint, cells, ghost_ok)
	FarmBuildUi.note(footprint, cells, "")

# ------------------------------------------------------------------ putting down
## A click on the floor with a piece in hand: places it, then leaves decorate mode unless Shift keeps it in hand.
func click_place(keep_in_hand := false) -> bool:
	var piece := held.duplicate()
	if not place():
		return false
	if keep_in_hand and int(piece["from"]) < 0:
		take(String(piece["id"]))
	elif Placement.leaves_build_mode(false, keep_in_hand):
		toggle()
		room._toast(Placement.placed_text())
	return true

func place() -> bool:
	if held.is_empty():
		return false
	if not ghost_ok:
		Sfx.play("ui_deny", null, -12.0)
		room._toast(String(room.why))
		return false
	var id := String(held["id"])
	var from := int(held["from"])
	if from < 0 and stored(id) == 0 and int(Save.d["gems"]) < int(Data.FURN[id]["price"]):
		room._toast("You need %d gems for that" % int(Data.FURN[id]["price"]))
		return false
	_snap()
	var entry := {"id": id, "x": ghost_cell.x, "z": ghost_cell.y, "r": int(held["r"])}
	if from >= 0:
		room.decor[from] = entry
	else:
		_spend(id)
		room.decor.append(entry)
	held = {}
	_clear_ghost()
	room._rebuild_decor()
	Sfx.play("build", null, -6.0)
	room.fx.dust(room.nodes[-1].position, 6)
	Save.save_game()
	refresh()
	return true

## A piece from storage comes out of it; otherwise it is paid for.
func _spend(id: String) -> void:
	if stored(id) > 0:
		Save.d["furniture"][id] = stored(id) - 1
	else:
		Save.d["gems"] = int(Save.d["gems"]) - int(Data.FURN[id]["price"])
		Sfx.play("pickup")
	room._refresh_gems()

# ------------------------------------------------------------------ taking away
## X: the piece in hand goes into storage (a new one just goes back).
func store_held() -> void:
	if held.is_empty():
		return
	var from := int(held["from"])
	if from >= 0:
		_drop_held()
		store_placed(from)
	else:
		cancel_held()

func store_placed(index: int) -> void:
	_snap()
	var id := String(room.decor[index]["id"])
	room.decor.remove_at(index)
	Save.d["furniture"][id] = stored(id) + 1
	room._rebuild_decor()
	Sfx.play("pickup", null, -6.0)
	room._toast("%s put in storage" % Data.FURN[id]["name"])
	Save.save_game()
	refresh()

func pick_up(index: int) -> void:
	_close_menu()
	_drop_held()
	var e: Dictionary = room.decor[index]
	held = {"id": e["id"], "r": int(e.get("r", 0)), "from": index}
	room.nodes[index].visible = false
	Sfx.play("click")
	_make_ghost()
	refresh()

## Turns a placed piece a quarter turn about its middle, with the turn shown, if it fits that way.
func rotate_placed(index: int) -> void:
	var e: Dictionary = room.decor[index]
	var id := String(e["id"])
	var turn := (int(e.get("r", 0)) + 1) % 4
	var old_fp: Vector2i = room.footprint(id, int(e.get("r", 0)))
	var new_fp: Vector2i = room.footprint(id, turn)
	var nx := int(round(float(e["x"]) + old_fp.x * 0.5 - new_fp.x * 0.5))
	var nz := int(round(float(e["z"]) + old_fp.y * 0.5 - new_fp.y * 0.5))
	if not room._fits(id, nx, nz, turn, index):
		room._toast(String(room.why))
		return
	_snap()
	var old_yaw: float = room.nodes[index].rotation.y
	room.decor[index] = {"id": id, "x": nx, "z": nz, "r": turn}
	room._rebuild_decor()
	Placement.spin_from(room.nodes[index], old_yaw)
	Sfx.play("click", null, -6.0, 0.1, 1.3)
	Save.save_game()

# ------------------------------------------------------------------ the piece menu
func open_menu(index: int) -> void:
	_close_menu()
	var entries: Array = [
		{"label": "Move", "key": "", "cb": func(): pick_up(index)},
		{"label": "Rotate", "key": Settings.key_cap("rotate"), "cb": func(): rotate_placed(index)},
		{"label": "Store", "key": Settings.key_cap("store"), "cb": func(): store_placed(index)},
	]
	var title := String(Data.FURN[room.decor[index]["id"]]["name"])
	menu = BuildMenu.open(room.root_ui, room.get_viewport().get_mouse_position(), title, entries, [], "", Callable(),
		BuildKeys.blocked_rects(bar, keys.avoid))

func _close_menu() -> void:
	if is_instance_valid(menu):
		menu.close()
	menu = null

## The index of the piece standing on a tile (rugs and cushions too), or -1.
func piece_at(c: Vector2i) -> int:
	if room.occ.has(c):
		return int(room.occ[c])
	for i in room.decor.size():
		var fp: Vector2i = room.footprint(room.decor[i]["id"], int(room.decor[i].get("r", 0)))
		if Rect2i(int(room.decor[i]["x"]), int(room.decor[i]["z"]), fp.x, fp.y).has_point(c):
			return i
	return -1

func _piece_under_mouse() -> int:
	var m := _mouse_cell()
	return piece_at(Vector2i(int(floor(m.x)), int(floor(m.y))))

# ------------------------------------------------------------------ undo
func _snap() -> void:
	undo.append({"decor": room.decor.duplicate(true), "furniture": Save.d["furniture"].duplicate(),
		"gems": int(Save.d["gems"])})
	if undo.size() > UNDO_CAP:
		undo.pop_front()

func undo_last() -> bool:
	if undo.is_empty():
		room._toast("Nothing to undo")
		return false
	_drop_held()
	var state: Dictionary = undo.pop_back()
	room.decor.assign(state["decor"])
	Save.d["furniture"] = state["furniture"]
	Save.d["gems"] = int(state["gems"])
	room._rebuild_decor()
	room._refresh_gems()
	Sfx.play("whoosh", null, -8.0)
	Save.save_game()
	refresh()
	return true

# ------------------------------------------------------------------ keys and the hint
func _light(piece: Node3D) -> void:
	if _glowing == piece:
		return
	Placement.unglow(_glowing)
	_glowing = piece
	if piece != null:
		Placement.glow(piece)

func _update_keys() -> void:
	if keys == null:
		return
	var state := {"sweep": sweep}
	var text := "Pick something from the bar, or click a piece in the room to move it."
	if held.is_empty():
		var index := _piece_under_mouse()
		_light(room.nodes[index] if index >= 0 else null)
		if index >= 0:
			state["over"] = String(Data.FURN[room.decor[index]["id"]]["name"])
			text = "Click the %s for Move, Rotate and Store" % String(state["over"]).to_lower()
	else:
		var name_text := String(Data.FURN[held["id"]]["name"])
		_light(room.nodes[room.blocker] if not ghost_ok and room.blocker >= 0 else null)
		state.merge({"held": true, "item": name_text, "can_rotate": true, "can_store": true,
			"ok": ghost_ok, "reason": room.why})
		text = "%s: click to put it down  ·  Hold %s to place more" % [name_text, Settings.key_cap("keep_placing")]
		if not ghost_ok:
			text = "%s: %s" % [name_text, room.why]
	keys.show_state(state)
	if bar.hint.text != text:
		bar.hint.text = text
	bar.hint.add_theme_color_override("font_color", UI.INK if ghost_ok or held.is_empty() else Color("ffb0a0"))

# ------------------------------------------------------------------ input
## Decorate mode's keys and clicks. True if it used the event.
func input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu"):
		if is_instance_valid(menu): _close_menu()
		elif not held.is_empty(): cancel_held()
		elif sweep: _set_sweep(false)
		else: toggle()
		return true
	if event.is_action_pressed("build"):
		toggle()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if event.is_action_pressed("undo") and (key.ctrl_pressed or key.meta_pressed):
			undo_last()
			return true
		if event.is_action_pressed("store"):
			_store_key()
			return true
	if event.is_action_pressed("rotate"):
		var index := _piece_under_mouse()
		if not held.is_empty(): rotate_held()
		elif index >= 0: rotate_placed(index)
		return true
	if event is InputEventMouseButton and event.pressed:
		return _click(event as InputEventMouseButton)
	return false

func _store_key() -> void:
	var index := _piece_under_mouse()
	if not held.is_empty():
		store_held()
	elif index >= 0:
		store_placed(index)

func _click(mb: InputEventMouseButton) -> bool:
	bar.blur()
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		rotate_held()
		return true
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not held.is_empty():
		click_place(Input.is_action_pressed("keep_placing"))
		return true
	var index := _piece_under_mouse()
	if index < 0:
		return true
	if sweep:
		store_placed(index)
	else:
		open_menu(index)
	return true
