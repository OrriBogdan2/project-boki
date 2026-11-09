extends RefCounted
## --hudref-check: the overhead plates and the bottom bar read like the reference HUD (hero-ref/HUD.md).
##   1. segments follow max health (HudStyle.seg_step: 25 each, doubling past 12)
##   2. the chip holds after a hit, then drains to the new health; the frame flashes on the hit
##   3. armour (a strip under health) and shields (past the end of health) are drawn
##   4. a downed hunter shows the downed plate and a status word replaces a slowed rival's name
##   5. an ability cooling down shows its countdown on the slot
##   6. key caps come from Settings.key_cap, one Merge slot, an X tile for the hunter ultimate
## Runs the --hudref-demo=plates scene headless (real frames, the real HUD) and reads what
## HudPlate.shown / Hud.slot_text say was drawn. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HUDREF %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func frames_until(m: Match, t: float) -> void:
	var guard := 0
	while m.time < t and guard < 20000:
		await main.get_tree().process_frame
		guard += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	# ---------------------------------------------------------------- 1. segments follow max health
	var counts := [HudStyle.seg_count(100.0), HudStyle.seg_count(145.0), HudStyle.seg_count(300.0)]
	ok(counts == [4, 6, 12], "25 health a segment: 100 -> 4, 145 -> 6, 300 -> 12 (%s)" % str(counts))
	ok(HudStyle.seg_count(600.0) == 12 and HudStyle.seg_step(600.0) == 50.0,
		"a huge pool doubles the segment size instead of crowding (600 -> 12 of 50)")
	var m := Match.new()
	main.add_child(m)
	var opts := HudRefDemo.opts("--hudref-demo=plates")
	opts.merge({"tier": 0, "length": 1e9, "seed": 5, "arch": "thief", "cls": Arch.weight("thief"),
		"weapon": Arch.signature("thief")})
	m.start(opts)
	var hud = m.hud
	await frames_until(m, 1.0)
	var P: Hunter = m.player
	var foes: Array = m.hunters.filter(func(x): return x != P)
	ok(hud != null and foes.size() >= 5, "a match with the HUD and five rivals in a row (%d)" % foes.size())
	if foes.size() < 5:
		return _done()
	var full: Hunter = foes[0]
	var sh: Dictionary = hud.plates.shown.get(full.nid, {})
	ok(int(sh.get("segs", -1)) == HudStyle.seg_count(full.max_hp),
		"the drawn plate has one segment per 25 health (%s for %d)" % [str(sh.get("segs")), int(full.max_hp)])
	full.max_hp = 300.0
	full.hp = 300.0
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(int(_shown(hud, full).get("segs", -1)) == 12, "max health raised to 300: the plate redraws with 12 segments")
	# ---------------------------------------------------------------- 2. the chip holds, then drains
	var hp := HudPlate.new()
	var dt := 1.0 / 60.0
	hp.tick(dt)
	hp.chip_of(full, 1.0, dt)
	hp.tick(dt)
	var c0 := hp.chip_of(full, 0.6, dt)
	ok(absf(c0 - 1.0) < 0.001 and hp.flash_of(full) > 0.5,
		"a hit: the lost chunk stays as a chip (%.2f) and the frame flashes" % c0)
	var t := 0.0
	var held := true
	while t < HudPlate.CHIP_HOLD - 0.05:
		hp.tick(dt)
		var cc := hp.chip_of(full, 0.6, dt)
		t += dt
		if cc < 0.999: held = false
	ok(held, "the chip holds for %.2fs after the hit" % HudPlate.CHIP_HOLD)
	var drained_at := -1.0
	while t < 2.0:
		hp.tick(dt)
		var cc := hp.chip_of(full, 0.6, dt)
		t += dt
		if cc <= 0.6001 and drained_at < 0.0: drained_at = t
	ok(drained_at > HudPlate.CHIP_HOLD and drained_at < HudPlate.CHIP_HOLD + 0.6,
		"... then drains to the new health quickly (gone at %.2fs)" % drained_at)
	hp.tick(dt)
	hp.chip_of(full, 0.9, dt)
	ok(absf(hp.chip_of(full, 0.9, dt) - 0.9) < 0.001, "a heal pulls the chip up with it (no chip above health)")
	# the real plate of the rival hit just before the picture shows its chip
	await frames_until(m, HudRefDemo.HIT_AT + 0.1)
	var hit: Hunter = foes[1]
	var hs: Dictionary = hud.plates.shown.get(hit.nid, {})
	var hit_frac := hit.hp / hit.max_hp
	var hit_chip := float(hs.get("chip", 0.0))
	ok(hit.hp < hit.max_hp and hit_chip > hit_frac + 0.05,
		"the rival hit at %.1fs shows a chip on their plate (%.2f over %.2f)" % [HudRefDemo.HIT_AT, hit_chip, hit_frac])
	await frames_until(m, HudRefDemo.HIT_AT + HudPlate.CHIP_HOLD + 1.0)
	hit_chip = float(_shown(hud, hit).get("chip", 1.0))
	ok(absf(hit_chip - hit.hp / hit.max_hp) < 0.01, "... and a second later it has drained (%.2f)" % hit_chip)
	# ---------------------------------------------------------------- 3. armour and shield
	var arm: Hunter = foes[2]
	var as_: Dictionary = hud.plates.shown.get(arm.nid, {})
	ok(arm.armor > 0.5 and bool(as_.get("armor", false)), "an armoured rival's plate draws the armour strip")
	ok(arm.shield > 0.0 and bool(as_.get("shield", false)) and HudPlate.shield_frac(arm) > 0.0,
		"a shielded rival's plate draws the shield past their health (%.2f of the bar)" % HudPlate.shield_frac(arm))
	arm.armor = 0.0
	await main.get_tree().process_frame
	ok(float(_state(hud, arm).get("brk", 0.0)) > 0.0, "armour hitting zero cracks the strip")
	# ---------------------------------------------------------------- 4. downed, and status words
	var dn: Hunter = foes[4]
	var ds: Dictionary = hud.plates.shown.get(dn.nid, {})
	var down_word := String(ds.get("word", ""))
	ok(dn.downed and bool(ds.get("downed", false)) and down_word.begins_with("DOWN"),
		"a downed rival shows the downed plate ('%s')" % down_word)
	var sl: Hunter = foes[3]
	sl.reveal_t = 3.0       # seen however the headless camera faces
	var sw := ""
	for i in 60:            # vision refreshes every 0.05s and line of sight can lag a few frames headless
		await main.get_tree().process_frame
		sw = String(_shown(hud, sl).get("word", ""))
		if sw == "SLOWED":
			break
	var why := "slow %.2f, unseen %s, drawn %s" % [sl.slow_t, sl.unseen, not _shown(hud, sl).is_empty()]
	ok(sw == "SLOWED", "a slowed rival's plate says SLOWED over the bar ('%s', %s)" % [sw, why])
	m.knock(foes[0], P, {})
	await main.get_tree().process_frame
	ok(float(_state(hud, foes[0]).get("burst", 0.0)) > 0.0, "going down pops the knock burst over them")
	# ---------------------------------------------------------------- 4b. everyone's level, rivals included
	var lv_ok := true
	var seen := 0
	for f in foes:
		var fh: Hunter = f
		if fh.unseen or fh.out:
			continue     # hidden in grass, or eliminated: no plate for anyone, by design
		seen += 1
		var fs := _shown(hud, fh)
		if fs.is_empty() or int(fs.get("lvl", -1)) != fh.lvl:
			lv_ok = false
			print("  level not shown for %s: shown %d, is %d" % [fh.pname, int(fs.get("lvl", -1)), fh.lvl])
	ok(lv_ok and seen >= 5, "every visible plate (%d), rivals and the downed included, shows the level" % seen)
	# a hunter from another machine: their level comes in the snapshot, the badge updates and pulses
	var R: Hunter = foes[2]
	R.lvl = 9
	var row: Array = m._ser(R)
	R.lvl = 4
	R.remote = true
	await main.get_tree().process_frame
	ok(int(_shown(hud, R).get("lvl", -1)) == 4, "a remote rival's plate shows level 4")
	m._net_apply(R, row)
	ok(R.lvl == 9, "their snapshot carries the run level (now %d)" % R.lvl)
	await main.get_tree().process_frame
	var rs := _shown(hud, R)
	var lvl_pop := float(rs.get("lvl_pop", 0.0))
	ok(int(rs.get("lvl", -1)) == 9 and lvl_pop > 0.0, "the plate updates to 9 and the badge pulses (%.2fs)" % lvl_pop)
	await frames_until(m, m.time + HudPlate.LVL_POP_T + 0.2)
	ok(float(_shown(hud, R).get("lvl_pop", 1.0)) == 0.0, "... and the pulse settles")
	# ---------------------------------------------------------------- 4c. plate height per hunter
	var arch_was := P.arch
	P.arch = "gunslinger"
	var no_offset := not Arch.def(P.arch).has("plate_offset")
	ok(no_offset and HudPlate.plate_offset(P) == HudPlate.PLATE_OFFSET and HudPlate.PLATE_OFFSET == 2.35,
		"an archetype without plate_offset puts the plate at the 2.35 m fallback (%.2f)" % HudPlate.plate_offset(P))
	P.arch = ""
	ok(HudPlate.plate_offset(P) == HudPlate.PLATE_OFFSET, "a hunter with no archetype falls back too")
	P.arch = arch_was
	# ---------------------------------------------------------------- 5. cooldown text
	P.slot_lv["kin"] = 1
	P.ak.cd["e"] = 6.4
	await hud.panels.draw      # the slots are drawn on HudPanels, REDRAW_HZ times a second
	await main.get_tree().process_frame
	var ei := P.slot_info("k1")
	var txt := String(hud.slot_text.get("k1", ""))
	ok(txt != "" and txt == HudSlot.cd_text(float(ei["cd"])),
		"E cooling down shows its seconds on the slot ('%s' for %.2fs)" % [txt, float(ei["cd"])])
	ok(HudSlot.cd_text(0.42) == "0.4" and HudSlot.cd_text(3.2) == "4", "whole seconds, tenths under one second")
	ok(hud.hover_spots.any(func(x): return String(x[1]) == "vitals"), "the bottom-left vitals block is drawn")
	await _check_keys(P)
	await _check_gear_reveal(P)
	_done()

## 6. Every key cap on the ability bar comes from Settings.key_cap; the Merge shows the Merge key once (on the
## right-side Boki box); every hunter has an X tile with a lock until level 6 and a cooldown after a cast.
func _check_keys(P: Hunter) -> void:
	var hud = P.m.hud
	var all_x := Arch.ids().all(func(id): return Arch.def(id).has("x"))
	ok(all_x, "every hunter has a hunter ultimate tile (%d)" % Arch.ids().size())
	var actions := {"sec": "secondary", "dash": "dash", "k1": "signature", "x": "hunter_ult", "r": "ultimate",
		"throw": "throw", "base": "base", "gear0": "gear1", "gear1": "gear2"}
	P.lvl = 1
	HudSlot.shown_keys.clear()
	await hud.panels.draw      # the slots are drawn on HudPanels, REDRAW_HZ times a second
	await main.get_tree().process_frame
	var x_key := String(HudSlot.shown_keys.get("x", ""))
	ok(bool(P.slot_info("x")["locked"]) and x_key == Settings.key_cap("hunter_ult"),
		"level 1: the ultimate tile is drawn locked, with the hunter ultimate key '%s'" % x_key)
	var wrong := []
	for id in HudSlot.shown_keys:
		if actions.has(id) and String(HudSlot.shown_keys[id]) != Settings.key_cap(actions[id]):
			wrong.append(id)
	var drawn: Array = HudSlot.shown_keys.keys()
	var said := "every key cap on the bar is its action's Settings.key_cap (%s, wrong: %s)" % [drawn, wrong]
	ok(wrong.is_empty() and drawn.size() >= 4, said)
	var merge_key := String(HudSlot.shown_keys.get("r", ""))
	ok(merge_key == Settings.key_cap("ultimate") and merge_key != Settings.key_cap("hunter_ult"),
		"the Merge shows the Merge key '%s', not '%s'" % [merge_key, Settings.key_cap("hunter_ult")])
	var merge_slots: Array = hud.hover_spots.filter(func(x): return String(x[1]) == "r")
	ok(merge_slots.size() == 1, "one Merge slot only (the Boki box on the right)")
	P.lvl = int(Hunter.ULT_AT[0])
	P.ak.cd["x"] = 12.3
	await hud.panels.draw
	await main.get_tree().process_frame
	var xt := String(hud.slot_text.get("x", ""))
	ok(not bool(P.slot_info("x")["locked"]) and xt == HudSlot.cd_text(float(P.ak.cd["x"])),
		"level %d: the X tile shows its cooldown ('%s')" % [P.lvl, xt])
	P.ak.cd["x"] = 0.0

## 7. Empty gear slots and belt slots stay hidden: only filled ones are drawn; holding the info key shows all
## the gear slots and one plain line per item.
func _check_gear_reveal(P: Hunter) -> void:
	var hud = P.m.hud
	P.gear = Gear.empty_slots()
	P.belt = UtilityBelt.empty()
	await hud.panels.draw
	await main.get_tree().process_frame
	var spots := func(prefix: String) -> int:
		return hud.hover_spots.filter(func(x): return String(x[1]).begins_with(prefix)).size()
	ok(spots.call("gslot:") == 0 and spots.call("util") == 0, "a new hunter: no gear slots and no belt slots drawn")
	var armor: String = Gear.ids_for(2)[0]
	P.gear[2] = {"id": armor, "rar": 0}
	var tonic: String = UtilityBelt.stock_ids()[0]
	P.belt[1] = {"id": tonic, "n": 1}
	await hud.panels.draw
	await main.get_tree().process_frame
	ok(GearPanel.shown(P) == [2] and spots.call("gslot:") == 1, "one armor piece: only the armor slot is drawn")
	ok(spots.call("util") == 1, "one belt item: only its slot is drawn, with its key")
	Input.action_press("scores")
	var held := GearPanel.shown(P).size() == Gear.SLOTS.size()
	var line := GearPanel._card_line(P, 2)
	var empty_line := GearPanel._card_line(P, 0)
	Input.action_release("scores")
	ok(held and line.contains(Gear.desc_of(armor, 0)) and empty_line == "Glove 1: empty",
		"holding the info key: every gear slot and a plain line per item ('%s' / '%s')" % [line, empty_line])
	P.gear = Gear.empty_slots()
	P.belt = UtilityBelt.empty()

## What the last frame drew on this hunter's plate (HudPlate.shown), or {} if nothing.
func _shown(hud, h: Hunter) -> Dictionary:
	return hud.plates.shown.get(h.nid, {})

## The plate's animation state (chip, crack, burst ...) for this hunter.
func _state(hud, h: Hunter) -> Dictionary:
	return hud.plates.st.get(h.nid, {})

func _done() -> void:
	print("HUDREF CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
