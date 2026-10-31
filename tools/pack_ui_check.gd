extends RefCounted
## --pack-ui-check: the backpack windows take real mouse clicks. A live match (processing, so the
## match's own input handling runs too) with a full backpack: a pick-up opens the swap window, and a
## mouse click at each drawn row's Drop button swaps that slot for the new thing; the backpack (I)
## window's Drop and Equip buttons work by click; firing is held while the cursor is over a window;
## Esc still closes them. Never touches the save.

var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("PACKUI %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Every visible, enabled Button under a node whose text is `txt`.
func _buttons(root: Node, txt: String) -> Array:
	var out: Array = []
	if root == null or not is_instance_valid(root):
		return out
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).text == txt and (n as Button).is_visible_in_tree() and not (n as Button).disabled:
			out.append(n)
		for ch in n.get_children(): stack.append(ch)
	out.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	return out

## Where a control's middle is in window pixels (what the OS sends), through the interface scale.
func _screen_mid(c: Control) -> Vector2:
	return main.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size * 0.5))

## A real left click (move there, press, release) through Input, as the OS would send it (`at` in
## window pixels).
func _click(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at; mv.global_position = at
	Input.parse_input_event(mv)
	await _frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at; e.global_position = at
		Input.parse_input_event(e)
		await _frames(2)

func _move(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at; mv.global_position = at
	Input.parse_input_event(mv)
	await _frames(2)

func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down; e.position = at; e.global_position = at
	Input.parse_input_event(e)
	await _frames(2)

## Treasure on the ground at your feet, picked up: with a full pack, the swap window.
func _offer() -> void:
	var at := m.world.free_spot_near(m.player.pos + Vector3(0.7, 0, 0.3), [m.player.pos], 0.5)
	m.spawn_val(Loot.valuable("crown_shard"), Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	Pack.take_ground(m, m.player, m.wpicks[m.wpicks.size() - 1])
	await _frames(4)       # _fit_panel places it over two frames

## Clears loose treasure and dropped things off the ground between rounds.
func _tidy() -> void:
	for w in m.wpicks.duplicate():
		if w.has("val") or (w.get("item", {}) as Dictionary).has("t"): Pack._off_ground(m, w)

## Waits until an item window has been sized and put in its place (_fit_panel takes a few frames).
func _settle(pc: Control) -> void:
	for i in 30:
		await _frames(1)
		if not is_instance_valid(pc) or pc.position.x > -1000.0:
			break
	await _frames(2)

func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k; e.physical_keycode = k; e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)

func _ids(h: Hunter) -> Array:
	return h.pack.map(func(it): return String(it.get("uid", "")))

func _fill(P: Hunter) -> void:
	P.pack_cap = 4
	P.pack = [Loot.valuable("old_coin"), Loot.weapon("smg", 1), Loot.valuable("sky_pearl"), Loot.weapon("shotgun", 2, "venom")]

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["home"] = true
	m = Match.new()
	m.name = "Match"
	main.add_child(m)
	main.current = m
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	await _frames(5)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P: o.ctrl = "idle"; o.teleport(m.world.spawns[-1])
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var hud = m.hud
	# 1. full pack + a pick-up: the swap window; click each row's Drop (a fresh offer each time)
	for slot in 4:
		_fill(P)
		var before: Array = _ids(P)
		var at := m.world.free_spot_near(P.pos + Vector3(0.7, 0, 0.3), [P.pos], 0.5)
		m.spawn_val(Loot.valuable("crown_shard"), Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
		var wp: Dictionary = m.wpicks[m.wpicks.size() - 1]
		Pack.take_ground(m, P, wp)
		await _frames(4)       # _fit_panel places it over two frames
		ok(hud.swap_open(), "slot %d: a full pack opens the swap window" % slot)
		var drops := _buttons(hud.swap_panel, "Drop")
		if drops.size() != 4:
			ok(false, "slot %d: 4 Drop buttons drawn (got %d)" % [slot, drops.size()])
			continue
		var b: Button = drops[slot]
		var c: Vector2 = _screen_mid(b)
		var vr := b.get_viewport_rect()
		ok(vr.has_point(b.get_global_rect().get_center()), "slot %d: the Drop button is on screen at %s" % [slot, str(c)])
		await _click(c)
		ok(not hud.swap_open(), "slot %d: clicking Drop closes the window" % slot)
		var after: Array = _ids(P)
		ok(not after.has(before[slot]) and P.pack.any(func(it): return String(it.get("id", "")) == "crown_shard") and P.pack.size() == 4,
			"slot %d: the click dropped exactly that slot and packed the shard" % slot)
		ok(m.wpicks.any(func(w): return String((w.get("item", {}) as Dictionary).get("uid", "")) == before[slot]), "slot %d: the dropped thing is on the ground" % slot)
		# tidy the dropped thing away so the next round starts clean
		for w in m.wpicks.duplicate():
			if w.has("val") or (w.get("item", {}) as Dictionary).has("t"): Pack._off_ground(m, w)
	# 2. hovering a window holds fire and swaps the crosshair for a pointer drawn over the window;
	# clicking a row (not just its button) drops that one; Leave it and Esc close it
	_fill(P)
	await _offer()
	var lvs := _buttons(hud.swap_panel, "Leave it  (Esc)")
	ok(hud.swap_open() and lvs.size() == 1, "the swap window has a Leave it button (open %s, %d)" % [hud.swap_open(), lvs.size()])
	if hud.swap_open():
		var sp: Control = hud.swap_panel
		var hover: Vector2 = main.get_viewport().get_final_transform() * (sp.get_global_transform_with_canvas() * Vector2(sp.size.x * 0.4, 24.0))    # the title
		await _move(hover)
		await _mouse(hover, true)
		ok(hud.mouse_on_panel() and not bool(P.inp.get("fire", false)), "holding the mouse over the swap window doesn't fire (on panel %s, fire %s)" % [hud.mouse_on_panel(), P.inp.get("fire")])
		await _mouse(hover, false)
		var rows := _buttons(hud.swap_panel, "Drop")
		var before2: Array = _ids(P)
		var rp: Control = (rows[2] as Button).get_parent().get_parent()
		var name_at: Vector2 = main.get_viewport().get_final_transform() * (rp.get_global_transform_with_canvas() * Vector2(60.0, rp.size.y * 0.5))
		await _click(name_at)
		ok(not hud.swap_open() and not _ids(P).has(before2[2]) and P.pack.size() == 4, "clicking a row's name drops that row (open %s)" % hud.swap_open())
		_tidy()
	_fill(P)
	await _offer()
	var n_before := P.pack.size(); var ids_before: Array = _ids(P)
	lvs = _buttons(hud.swap_panel, "Leave it  (Esc)")
	if not lvs.is_empty():
		await _click(_screen_mid(lvs[0]))
		ok(not hud.swap_open() and _ids(P) == ids_before and P.pack.size() == n_before, "Leave it closes the window and keeps the pack as it was")
	_tidy()
	# 3. Esc closes it (the keyboard still works)
	_fill(P)
	await _offer()
	await _key(KEY_ESCAPE)
	ok(not hud.swap_open(), "Esc closes the swap window")
	_tidy()
	# 3b. a deathbox's loot window with a full pack: clicking a row takes it (swapping out the cheapest)
	_fill(P)
	var Q: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var bx := {"owner": Q, "team": Q.team, "pos": P.pos + Vector3(0.6, 0, 0), "gems": 0, "seeds": {}, "caught": [], "tonics": 0, "kits": 0, "soul_until": 0.0,
		"prog": {}, "node": null, "empty": false, "gear": [], "weapon": {}, "pack": [Loot.valuable("crown_shard")]}
	m.boxes.append(bx)
	hud.open_loot(bx)
	await _frames(4)
	var takes := _buttons(hud.loot_panel, "Swap")
	if takes.size() == 1:
		var lrp: Control = (takes[0] as Button).get_parent().get_parent()
		await _click(main.get_viewport().get_final_transform() * (lrp.get_global_transform_with_canvas() * Vector2(60.0, lrp.size.y * 0.5)))
		await _frames(2)
		ok(P.pack.any(func(it): return String(it.get("id", "")) == "crown_shard") and P.pack.size() == 4, "loot window: clicking the shard's row swaps it into the full pack")
	else:
		ok(false, "loot window: one Swap button for the shard (got %d)" % takes.size())
	hud.close_loot()
	m.boxes.erase(bx)
	# 4. the backpack window (I) on a full pack: Drop and Equip by click
	_fill(P)
	await _key(KEY_I)
	await _frames(4)
	ok(hud.pack_open(), "I opens the backpack")
	await _settle(hud.pack_panel)
	var pd := _buttons(hud.pack_panel, "Drop")
	var n0 := P.pack.size()
	if pd.size() == 4:
		var first: String = _ids(P)[1]
		await _click(_screen_mid(pd[1]))
		await _frames(3)
		ok(P.pack.size() == n0 - 1 and not _ids(P).has(first), "backpack: clicking Drop on row 2 drops it (pack %d -> %d)" % [n0, P.pack.size()])
	else:
		ok(false, "backpack: 4 Drop buttons drawn (got %d)" % pd.size())
	await _settle(hud.pack_panel)
	var eq := _buttons(hud.pack_panel, "Equip")
	if not eq.is_empty():
		var w0 := P.wid
		var at: Vector2 = _screen_mid(eq[0])
		await _click(at)
		await _frames(3)
		ok(P.wid != w0, "backpack: clicking Equip swaps the weapon in your hands (%s -> %s, clicked %s, pack %s)" % [w0, P.wid, at, str(P.pack.map(func(it): return Loot.name_of(it)))])
	else:
		ok(false, "backpack: an Equip button is drawn")
	await _key(KEY_ESCAPE)
	ok(not hud.pack_open(), "Esc closes the backpack")
	print("PACKUI CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
