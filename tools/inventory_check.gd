extends RefCounted
## --inventory-check: the in-match inventory. Gear compares with what you wear (only the changed numbers,
## better or worse); equip into a chosen slot, take off, swap gloves and drop to the ground move the right
## things and keep stats right; the window labels every slot with its key, shows the hover card, takes a drag
## and the Enter and Delete keys, and sits beside an open deathbox. Never touches the save.

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
	var armor_drag := {"inv": "pack", "i": 0}
	ok(lp._can_drop_worn(Vector2.ZERO, armor_drag, 2) and not lp._can_drop_worn(Vector2.ZERO, armor_drag, 0),
		"dragging armor: it can drop on the armor slot, not on a glove")
	lp._drop_worn(Vector2.ZERO, {"inv": "pack", "i": 0}, 2)
	ok(p.gear[2]["id"] == "vest" and p.pack.any(func(it): return it.get("id", "") == "quilted_coat"),
		"the drop wears it")
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
