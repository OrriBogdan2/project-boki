extends RefCounted
## --belt-hud-check: the six-slot utility belt on the HUD (BeltHud, docs/decisions/0005-equal-footing.md).
##   1. six slots drawn, each with a hover spot, none overlapping and none over another HUD box
##   2. the tonic and the armor kit sit in slots 1 and 2 with their stack counts; 3 to 6 are open
##   3. key caps are Settings.key_cap of util1..util6 (a rebound key shows, never a fixed letter)
##   4. a cooldown shows its seconds, a drink in progress fills its slot, Twin Gate's open gates ring
##      its slot with a countdown to the second press, then "swap" alone; the second press closes them
## Runs a real match with the real HUD and reads BeltHud.shown / Hud.slot_text. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BELTHUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 4107, "no_drop": true})
	await _frames(3)
	var P: Hunter = m.player
	var hud = m.hud
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "tonic", 5)
	UtilityBelt.grant(P, "armor_kit", 3)
	UtilityBelt.grant(P, "twin_gate", 2)
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	var was := InputMap.action_get_events("util4")
	InputMap.action_erase_events("util4")
	InputMap.action_add_event("util4", f)
	await _frames(12)
	_slots(hud)
	_items(P)
	_keys()
	await _live(m, P, hud)
	InputMap.action_erase_events("util4")
	for e in was: InputMap.action_add_event("util4", e)
	print("BELTHUD DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _spots(hud, k: int) -> Array:
	return hud.hover_spots.filter(func(x): return String(x[1]) == UtilityBelt.KEYS[k])

func _slots(hud) -> void:
	var rects: Array = []
	for k in UtilityBelt.SLOTS:
		var s := _spots(hud, k)
		if s.size() == 1: rects.append(s[0][0])
	ok(UtilityBelt.SLOTS == 6 and rects.size() == 6, "six belt slots drawn, one hover spot each (%d)" % rects.size())
	var clear := true
	for h in hud.hover_spots:
		if UtilityBelt.KEYS.has(String(h[1])): continue
		for r in rects:
			if (r as Rect2).intersects(h[0]): clear = false
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			if (rects[a] as Rect2).intersects(rects[b]): clear = false
	ok(clear, "the belt overlaps no slot, card or other HUD box")
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	var left := 1e9
	for r in rects: left = minf(left, (r as Rect2).position.x)
	ok(rects.size() == 6 and (rects[0] as Rect2).end.x <= size.x and left > size.x * 0.4,
		"the belt stays on the right of the screen (%dpx wide, from x %d)" % [int(size.x), int(left)])

func _items(P: Hunter) -> void:
	var sh := BeltHud.shown
	ok(String(sh[0]["id"]) == "tonic" and int(sh[0]["n"]) == 5, "slot 1 holds the tonic, 5 in the stack")
	ok(String(sh[1]["id"]) == "armor_kit" and int(sh[1]["n"]) == 3, "slot 2 holds the armor kit, 3 in the stack")
	var open := true
	for k in range(2, 6):
		if k == UtilityBelt.slot_of(P, "twin_gate"): continue
		open = open and String(sh[k]["id"]) == ""
	ok(open, "the slots without an item draw as open")
	var tg := UtilityBelt.slot_of(P, "twin_gate")
	ok(tg == 2 and int(sh[tg]["n"]) == 2, "a gadget lands in the first open slot (3) with its count")

func _keys() -> void:
	var good := true
	for k in UtilityBelt.SLOTS:
		good = good and String(BeltHud.shown[k]["key"]) == Settings.key_cap(UtilityBelt.KEYS[k])
	ok(good, "every slot's key cap is Settings.key_cap of its action")
	ok(BeltHud.shown[3]["key"] == "F" and BeltHud.shown[0]["key"] == Settings.key_cap("util1"),
		"util4 rebound to F: slot 4 shows F, slot 1 still shows %s" % Settings.key_cap("util1"))

func _live(m: Match, P: Hunter, hud) -> void:
	var tg := UtilityBelt.slot_of(P, "twin_gate")
	P.belt[tg]["cd"] = 2.4
	P.hp = P.max_hp - 40.0
	ok(UtilityBelt.use_id(P, "tonic"), "a tonic starts")
	m.step(Match.DT * 15)
	await _frames(12)
	ok(float(BeltHud.shown[0]["fill"]) > 0.0 and float(BeltHud.shown[0]["fill"]) < 1.0,
		"a drink in progress fills slot 1 (%.2f)" % float(BeltHud.shown[0]["fill"]))
	ok(float(BeltHud.shown[1]["fill"]) == 0.0, "...and only slot 1")
	ok(String(hud.slot_text.get(UtilityBelt.KEYS[tg], "")) == HudSlot.cd_text(float(P.belt[tg]["cd"])),
		"a cooling slot shows its seconds ('%s')" % String(hud.slot_text.get(UtilityBelt.KEYS[tg], "")))
	ok(float(BeltHud.shown[tg]["recast"]) < 0.0, "Twin Gate shows no recast cue before its gates open")
	P.belt[tg]["cd"] = 0.0
	P.hp = P.max_hp
	P.drink_t = 0.0
	UtilityBelt.use_id(P, "twin_gate")
	await _frames(12)
	var left := UtilityMore.gate_wait(P)
	ok(left > 6.0 and left <= 8.0 and float(BeltHud.shown[tg]["recast"]) > 0.0,
		"Twin Gate's slot counts down to its second press while the gates are open (%.1f s)" % left)
	m.get_meta("gate_%d" % P.get_instance_id())["t0"] -= 8.0
	await _frames(12)
	ok(float(BeltHud.shown[tg]["recast"]) == 0.0, "once armed, Twin Gate's pill reads '%s' alone" % BeltHud.RECAST_MARK)
	var n := int(P.belt[tg]["n"])
	UtilityBelt.use_id(P, "twin_gate")
	await _frames(12)
	ok(float(BeltHud.shown[tg]["recast"]) < 0.0 and int(P.belt[tg]["n"]) == n,
		"the second press swaps and closes the gates: the cue goes, no charge spent")
