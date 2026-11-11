extends RefCounted
## --inventory-check: the in-match inventory. Gear compares with what you wear (only the changed numbers,
## better or worse); equip into a chosen slot, take off, swap gloves and drop to the ground move the right
## things and keep stats right; the window labels every slot with its key, shows the hover card, takes a
## press-and-hold drag (mouse and pad), the Enter and Delete keys, and sits beside an open deathbox. Never
## touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("INVENTORY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var p: Hunter = m.player
	var q: Hunter = m.hunters.filter(func(x): return x != p)[0]
	_dress(p)
	_compare(p)
	_moves(m, p)
	await _window(main, m, p, q)
	print("INVENTORY CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _dress(p: Hunter) -> void:
	p.gear = [{"id": "power_core", "rar": 2}, {"id": "frost", "rar": 1}, {"id": "quilted_coat", "rar": 1},
		{"id": "boots", "rar": 1}]
	p.refresh_gear()
	p.pack_cap = 6
	p.pack = []

func _compare(p: Hunter) -> void:
	var vest := Loot.gear("vest", 3)
	var ch := GearCompare.changes(vest, p.gear[2])
	ok(ch == [["+28 armor", true], ["-22 health", false]], "vest vs your coat: only the changed numbers, %s" % [ch])
	ok(GearCompare.changes(vest, {"id": "vest", "rar": 3}).is_empty(), "the same piece changes nothing")
	var core := GearCompare.changes(Loot.gear("power_core", 3), p.gear[0])
	ok(core == [["+4% damage", true]], "a better rarity of your glove: %s" % [core])
	var blink := GearCompare.changes(Loot.gear("blink", 2), p.gear[1])
	ok(blink.has(["-7s cooldown", true]) and blink.has(["-4% faster abilities", false]),
		"glove: cooldown and a lost stat: %s" % [blink])
	ok(GearCompare.changes(vest, {}).size() == 1, "into an empty slot every stat is new")
	var lines := InvText.compare(p, vest)
	ok(lines.any(func(l): return l[0] == "+28 armor" and l[1] == InvText.GOOD)
		and lines.any(func(l): return l[0] == "-22 health" and l[1] == InvText.BAD),
		"the card colours them green and red")

func _moves(m: Match, p: Hunter) -> void:
	p.pack = [Loot.gear("blink", 2), Loot.gear("vest", 3)]
	Pack.use_from_pack(m, p, 0, 1)
	ok(p.gear[1]["id"] == "blink" and p.gear[0]["id"] == "power_core", "equip into the chosen glove slot")
	ok(p.pack.size() == 2 and p.pack.any(func(it): return it["id"] == "frost"),
		"the glove it replaced goes to the pack")
	var vi := p.pack.find_custom(func(it): return it["id"] == "vest")
	Pack.use_from_pack(m, p, vi, 0)
	ok(p.gear[2]["id"] == "vest" and p.gear[0]["id"] == "power_core",
		"armor dragged to a glove slot still goes on as armor")
	ok(p.max_armor >= 40.0, "armor stat follows the swap (%.0f)" % p.max_armor)
	var g0: Dictionary = p.gear[0]
	var g1: Dictionary = p.gear[1]
	p.gear_cd[0] = 5.0
	Pack.swap_gloves(p)
	var swapped: bool = p.gear[0] == g1 and p.gear[1] == g0
	ok(swapped and p.gear_cd[1] == 5.0 and p.gear_cd[0] == 0.0, "gloves swap, cooldowns with them")
	var armor_before := p.max_armor
	var packed := p.pack.size()
	ok(Pack.take_off(m, p, 2) and p.gear[2].is_empty() and p.pack.size() == packed + 1,
		"take off: slot empty, piece in the pack")
	ok(p.max_armor < armor_before, "armor stat drops when the piece comes off")
	p.pack_cap = p.pack.size()
	ok(not Pack.take_off(m, p, 3) and not (p.gear[3] as Dictionary).is_empty(), "no room: nothing comes off")
	var ground := m.wpicks.size()
	Pack.drop_worn(m, p, 3)
	ok(p.gear[3].is_empty() and m.wpicks.size() == ground + 1, "drop a worn piece: it lies on the ground")
	var held := p.pack.size()
	Pack.drop_from_pack(m, p, 0)
	ok(p.pack.size() == held - 1 and m.wpicks.size() == ground + 2, "drop from the pack: it lies on the ground")

func _window(main: Node, m: Match, p: Hunter, q: Hunter) -> void:
	_dress(p)
	p.pack = [Loot.gear("vest", 3), Loot.valuable("kin_idol")]
	UtilityBelt.grant(p, "medkit", 2)
	m.hud.toggle_pack()
	await _frames(main, 4)
	var pc: PanelContainer = m.hud.pack_panel
	ok(pc != null and is_instance_valid(pc), "the inventory window opens")
	await _frames(main, 3)
	var view := pc.get_viewport_rect()
	print("INVENTORY window %s in view %s" % [pc.get_global_rect(), view])
	ok(view.encloses(pc.get_global_rect()), "the window sits fully on screen")
	var caps := _texts(pc)
	var keys: Array = [Gloves.key_cap(0), Gloves.key_cap(1)]
	for k in UtilityBelt.KEYS:
		keys.append(Settings.key_cap(k))
	ok(keys.all(func(k): return caps.has(k)), "every glove and utility slot shows its key: %s" % [keys])
	ok(caps.has("Armor") and caps.has("Boots") and caps.has("Glove"), "the other slots are named")
	var lp: LoadoutPanel = pc.find_children("*", "LoadoutPanel", true, false)[0]
	lp.hover_demo("pack", 0)
	await _frames(main, 2)
	var tip: InvTip = pc.find_children("*", "InvTip", true, false)[0]
	ok(_texts(tip).has("+28 armor") and _texts(tip).has("-22 health"), "pointing at the vest shows the compare card")
	await _drags(main, m, p, lp)
	lp = await _reopen(main, m)
	lp._hover = {"kind": "worn", "i": 2}
	lp._input(_key(KEY_DELETE))
	ok(p.gear[2].is_empty(), "Delete on a worn piece drops it")
	lp = await _reopen(main, m)
	lp._hover = {"kind": "pack", "i": 0}
	var first: Dictionary = p.pack[0]
	lp._input(_key(KEY_ENTER))
	var worn_id := String(p.gear[Gear.slot_of(String(first["id"]))].get("id", ""))
	ok(worn_id == String(first["id"]), "Enter on a pack piece wears it")
	m.hud.close_pack()
	await _beside(main, m, p, q)

func _beside(main: Node, m: Match, p: Hunter, q: Hunter) -> void:
	var bx: Dictionary = load("res://tools/loot_full_check.gd").make_box(q, p.pos, [Loot.valuable("old_coin")])
	bx["gear"] = [{"id": "skylark_boots", "rar": 2}]
	m.boxes.append(bx)
	m.hud.open_loot(bx)
	await _frames(main, 4)
	var loot: PanelContainer = m.hud.loot_panel
	var inv: PanelContainer = m.hud.pack_panel
	ok(m.hud.pack_open() and loot.get_global_rect().end.x <= inv.get_global_rect().position.x + 1.0,
		"looting: your inventory opens at the right, the box side by side to its left")
	m.hud.close_loot()
	ok(not m.hud.pack_open(), "closing the box closes it again")

## Press, hold and move (SlotDrag) with real input: the mouse drags armor on, a refused drop snaps back
## with a hint, a still hold swaps the gloves, the pad holds A to swap two belt slots, a tap moves nothing.
func _drags(main: Node, m: Match, p: Hunter, lp: LoadoutPanel) -> void:
	var vp := main.get_viewport()
	await _mouse_drag(main, _slot(lp, "pack", 0), _slot(lp, "worn", 2))
	ok(p.gear[2]["id"] == "vest" and p.pack.any(func(it): return it.get("id", "") == "quilted_coat"),
		"mouse: press, move and release the vest on the armor slot wears it")
	lp = await _reopen(main, m)
	var idol := p.pack.find_custom(func(it): return it.get("id", "") == "kin_idol")
	var before := str(p.pack) + str(p.gear)
	await _mouse_drag(main, _slot(lp, "pack", idol), _slot(lp, "worn", 0))
	var hints := lp.find_children("drag_hint", "", true, false)
	ok(str(p.pack) + str(p.gear) == before and hints.size() == 1 and _texts(hints[0]).has("Only gear is worn"),
		"treasure on a glove slot: nothing moves, it snaps back with a hint")
	var row := _slot(lp, "pack", 0)
	var list := row.get_parent().get_parent() as ScrollContainer
	var below := Vector2(_mid(row).x, SlotDrag._rect(list).end.y + 4.0)
	ok(SlotDrag._unclipped(row, _mid(row)) and not SlotDrag._unclipped(row, below),
		"a point the pack list scrolls out of view picks up nothing")
	var g0: Dictionary = p.gear[0]
	var g1: Dictionary = p.gear[1]
	_mouse(vp, true, _mid(_slot(lp, "worn", 0)))
	await main.get_tree().create_timer(SlotDrag.HOLD_S + 0.1).timeout
	ok(lp._drag.carrying(), "mouse: holding still picks it up")
	_mouse(vp, false, _mid(_slot(lp, "worn", 1)))
	ok(p.gear[0] == g1 and p.gear[1] == g0, "released on the other glove: the gloves swap")
	lp = await _reopen(main, m)
	var k := UtilityBelt.slot_of(p, "medkit")
	var to := (k + 1) % UtilityBelt.SLOTS
	var other: Dictionary = p.belt[to]
	_slot(lp, "belt", k).grab_focus()
	_pad(vp, true)
	_pad(vp, false)
	await _frames(main, 2)
	ok(UtilityBelt.slot_of(p, "medkit") == k and not lp._drag.carrying(), "pad: a tap of A moves nothing")
	_pad(vp, true)
	await main.get_tree().create_timer(SlotDrag.HOLD_S + 0.1).timeout
	_slot(lp, "belt", to).grab_focus()
	_pad(vp, false)
	ok(UtilityBelt.slot_of(p, "medkit") == to and p.belt[k] == other, "pad: hold A, move, release swaps two belt slots")

## The control the drag knows as slot {inv, i}.
func _slot(lp: LoadoutPanel, inv: String, i: int) -> Control:
	for c in lp._drag._slots:
		var key: Dictionary = lp._drag._slots[c]["key"]
		if is_instance_valid(c) and key["inv"] == inv and int(key["i"]) == i:
			return c
	return null

func _mid(c: Control) -> Vector2:
	return SlotDrag._rect(c).get_center()

func _mouse_drag(main: Node, from: Control, to: Control) -> void:
	var vp := main.get_viewport()
	_mouse(vp, true, _mid(from))
	var mv := InputEventMouseMotion.new()
	mv.position = _mid(to)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(mv, true)
	await _frames(main, 1)
	_mouse(vp, false, _mid(to))
	await _frames(main, 1)

func _mouse(vp: Viewport, down: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	vp.push_input(ev, true)

func _pad(vp: Viewport, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = down
	vp.push_input(ev, true)

func _reopen(main: Node, m: Match) -> LoadoutPanel:
	m.hud.close_pack()
	m.hud.toggle_pack()
	await _frames(main, 3)
	return m.hud.pack_panel.find_children("*", "LoadoutPanel", true, false)[0]

func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _texts(root: Node) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out

func _frames(main: Node, k: int) -> void:
	for i in k:
		await main.get_tree().process_frame
