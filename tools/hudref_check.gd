extends RefCounted
## --hudref-check: the overhead plates and the bottom bar read like the reference HUD (hero-ref/HUD.md).
##   1. segments follow max health (HudStyle.seg_step: 17 each, doubling past 12)
##   2. the chip holds after a hit, then drains to the new health; the frame flashes on the hit
##   3. armour (a strip under health) and shields (past the end of health) are drawn
##   4. a downed hunter shows the downed plate and a status word replaces a slowed rival's name
##   5. an ability cooling down shows its countdown on the slot
##   6. key caps come from Settings.key_cap, one Merge slot, an X tile for the hunter ultimate
##   7. a press on cooldown raises one deny (PressDeny: pulse + tick, throttled); a press DashFlow buffers raises none
##   8. knock banners (KnockBanner): a rival you knock shows KNOCK in the red ring (a second one at once
##      counts x2), a teammate going down ALLY KNOCKED in the cyan one; each is gone within 1.5 s
##   9. the ultimate tile's states change at the right times (HunterUltTile: cooling, shine, ready, blocked)
##   9. every drawn HUD block, the tip card and the top strips sit inside the HudStyle safe margin
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
	var counts := [HudStyle.seg_count(124.0), HudStyle.seg_count(145.0), HudStyle.seg_count(193.0)]
	ok(counts == [8, 9, 12], "17 health a segment: the classes' 124 -> 8, 145 -> 9, 193 -> 12 (%s)" % str(counts))
	ok(HudStyle.seg_count(600.0) == 9 and HudStyle.seg_step(600.0) == 68.0,
		"a huge pool doubles the segment size instead of crowding (600 -> 9 of 68)")
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
	full.max_hp = 193.0
	full.hp = 193.0
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(int(_shown(hud, full).get("segs", -1)) == 12, "max health raised to 193: the plate redraws with 12 segments")
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
	var sl: Hunter = foes[3]  # the demo holds the whole CC row on them: the bar's word is the worst, STUNNED
	sl.reveal_t = 3.0       # seen however the headless camera faces
	var sw := ""
	for i in 60:            # vision refreshes every 0.05s and line of sight can lag a few frames headless
		await main.get_tree().process_frame
		sw = String(_shown(hud, sl).get("word", ""))
		if sw == "STUNNED":
			break
	var why := "slow %.2f, unseen %s, drawn %s" % [sl.slow_t, sl.unseen, not _shown(hud, sl).is_empty()]
	var cc_row: Array = HudPlate.statuses(sl).map(func(ic): return String(ic[2]))
	ok(sw == "STUNNED" and "SLOWED" in cc_row,
		"a stunned, slowed rival's plate: STUNNED over the bar, SLOWED in its row ('%s', %s, %s)" % [sw, cc_row, why])
	await _cc_words(m, hud, sl)
	m.knock(foes[0], P, {})
	await main.get_tree().process_frame
	ok(float(_state(hud, foes[0]).get("burst", 0.0)) > 0.0, "going down pops the knock burst over them")
	await _knock_banners(m, hud, P)
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
	# ---------------------------------------------------------------- 4d. each squad row wears its Boki's icon
	var mates: Array = m.hunters.filter(func(x): return x != P and x.team == P.team and x.kin != null)
	await hud.panels.draw
	ok(mates.size() >= 1 and mates.all(func(x): return TeamBoki.shown.has(x.nid)),
		"each of the %d teammates' squad rows draws its Boki icon" % mates.size())
	if mates.size() >= 1:
		var mate: Hunter = mates[0]
		var chip: int = TeamBoki.levels.get(mate.nid, -1)
		ok(chip == mate.lvl, "a squad row carries the teammate's level chip (%d vs %d)" % [chip, mate.lvl])
		mate.downed = false        # (the demo downs one rival)
		mate.kin.hp = mate.kin.max_hp * 0.5
		await hud.panels.draw
		ok(absf(float(TeamBoki.shown[mate.nid]["frac"]) - 0.5) < 0.05 and TeamBoki.shown[mate.nid]["state"] == "",
			"a half-health Boki's icon shows half a bar, untinted (%s)" % str(TeamBoki.shown[mate.nid]))
		mate.kin.state = "downed"      # (the kin's own update would stand it up again before a draw)
		ok(TeamBoki.state_of(mate, mate.kin) == "down", "a downed Boki's icon is tinted down")
		mate.kin.state = "active"
		mate.kin.rest_t = 5.0
		await hud.panels.draw
		ok(TeamBoki.shown[mate.nid]["state"] == "rest", "a resting Boki's icon is tinted resting")
		mate.kin.rest_t = 0.0
		mate.downed = true
		await hud.panels.draw
		ok(TeamBoki.shown[mate.nid]["state"] == "wisp", "a Boki whose owner is a wisp is tinted wisp")
		mate.downed = false
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
	_check_deny(P)
	await _check_ult(P)
	_check_safe(hud)
	_done()

## 9. One screen-edge margin (HudStyle.SAFE_FRAC): every block the HUD registered for hover this frame, the minimap
## and the tip card sit inside HudStyle.safe_rect, at the window size the run has and at 1280x720 / 1920x1080.
func _check_safe(hud) -> void:
	var sz: Vector2 = hud.c.size
	var pad := HudStyle.safe_pad(sz)
	var safe := HudStyle.safe_rect(sz).grow(0.5)
	var out: Array = []
	for spot in hud.hover_spots:
		if not safe.encloses(spot[0]):
			out.append("%s %s" % [spot[1], spot[0]])
	ok(out.is_empty(), "every drawn HUD block is inside the %.0f x %.0f margin (%s)" % [pad.x, pad.y, out.slice(0, 3)])
	ok(hud.mm_bottom - 196.0 >= pad.y - 0.5, "the minimap starts under the top margin")
	for size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var tag := "%dx%d" % [size.x, size.y]
		var s := HudStyle.safe_rect(size)
		var slot := Rect2(s.end - Vector2(20, 20), Vector2(20, 20))      # a slot in the safe corner
		var tip := Rect2(HudTip.place(slot, Vector2(300, 120), size), Vector2(300, 120))
		ok(s.encloses(tip), "%s: the tip card by a corner slot stays in the safe area" % tag)
		var reach: float = hud.HUD_REACH
		var origin: Vector2 = hud._hud_origin(size)
		var vitals := Rect2(origin - Vector2(reach, 0.0), Vector2(HudVitals.BAR_W + 144.0 + reach, 132.0 + reach))
		ok(s.encloses(vitals), "%s: the vitals block sits in the safe area" % tag)
		var strips := minf(WaysOutHud.top_y(size), TutorialStrip.rect(size).position.y)
		ok(strips >= s.position.y, "%s: the top strips start under it" % tag)

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

## 7. A refused press (hero-ref/HUD.md section 2): E on cooldown pulses its slot and ticks once, and a second press
## inside PressDeny.THROTTLE_S adds nothing. E pressed mid-dash on a hero whose row buffers it (Cinder) is held by
## DashFlow and raises nothing, nor while it waits out DashFlow.BUFFER_S past the dash's end. Runs in one frame.
func _check_deny(P: Hunter) -> void:
	var hud = P.m.hud
	PressDeny.last.clear()
	hud.slot_fx.erase("k1")
	P.ak.cd["e"] = 6.0
	var n0 := PressDeny.raised
	P.ak.use_e()
	ok(PressDeny.raised == n0 + 1 and String(hud.slot_fx.get("k1", {}).get("kind", "")) == "deny",
		"E pressed on cooldown: one deny on the k1 slot (%d)" % (PressDeny.raised - n0))
	P.ak.use_e()
	ok(PressDeny.raised == n0 + 1, "pressed again inside %.1fs: still one deny" % PressDeny.THROTTLE_S)
	P.cls = Arch.weight("ashwick")
	P.set_arch("ashwick")
	P.unlock_all()
	var flow := P.ak.flow
	ok(P.ak.id == "ashwick" and String(DashFlow.row_of("ashwick", "e", false)["mode"]) == "buffer",
		"Cinder's ground dash buffers E (its row)")
	PressDeny.last.clear()
	P.ak.cd["e"] = 6.0
	P.move_kind = "dash"
	P.roll_t = 0.3
	P.inp["sig"] = true
	flow.route(Match.DT)
	var held_mid := flow.held.has("e") and not bool(P.inp["sig"])
	P.roll_t = 0.0
	P.stun_t = 0.1           # the dash is over but she can't act yet: the press keeps waiting
	flow.route(Match.DT)
	ok(held_mid and flow.held.has("e") and PressDeny.raised == n0 + 1,
		"E on cooldown pressed mid-dash stays buffered through DashFlow.BUFFER_S and raises no deny")
	P.stun_t = 0.0
	flow.held.clear()

## 9. The ultimate tile reads "ready" at a glance, one look for every hero: the cooldown running out starts the
## shine at once, which settles into the steady lit frame; a stun puts the padlock over it and lifting it goes
## back to ready with no second shine; reaching the unlock level shines too.
func _check_ult(P: Hunter) -> void:
	var hud = P.m.hud
	var m: Match = P.m
	var plain := Arch.ids().filter(func(id):
		var xd: Dictionary = Arch.def(id)["x"]
		return not (xd.has("col") and xd.has("icon")))
	ok(plain.is_empty(),
		"every hero's ultimate has its own ability colour and icon for the tile (missing: %s)" % [plain])
	P.ak.cd["x"] = 0.4
	await _redraw(hud)
	ok(HunterUltTile.state == "cooling", "cooling: the tile is in its cooldown state (%s)" % HunterUltTile.state)
	var guard := 0
	while float(P.ak.cd["x"]) > 0.0 and guard < 600:
		await main.get_tree().process_frame
		guard += 1
	var back_at := m.time
	await _redraw(hud)
	var lag := HunterUltTile.shine_from - back_at
	var redraw_s := 1.0 / HudPanels.REDRAW_HZ
	ok(HunterUltTile.state == "ready" and lag >= -0.05 and lag <= redraw_s + 0.05,
		"the cooldown runs out: ready, and the shine starts on the next redraw (%.3fs after)" % lag)
	ok(HunterUltTile.shine(m.time) > 0.0, "... the shine is playing (%.2f left)" % HunterUltTile.shine(m.time))
	await frames_until(m, HunterUltTile.shine_from + HunterUltTile.SHINE_T + 0.05)
	await _redraw(hud)
	ok(HunterUltTile.state == "ready" and HunterUltTile.shine(m.time) == 0.0,
		"%.1fs later: the steady lit frame, no shine" % HunterUltTile.SHINE_T)
	var shone_at := HunterUltTile.shine_from
	P.stun_t = 3.0
	await _redraw(hud)
	ok(HunterUltTile.state == "blocked" and not bool(P.slot_info("x")["ready"]),
		"stunned with the ultimate off cooldown: the padlock over it, not ready")
	P.stun_t = 0.0
	await _redraw(hud)
	ok(HunterUltTile.state == "ready" and HunterUltTile.shine_from == shone_at,
		"the stun ends: ready again, steady, no second shine")
	P.lvl = 1
	await _redraw(hud)
	ok(HunterUltTile.state == "locked", "below level %d: locked" % int(Hunter.ULT_AT[0]))
	P.lvl = int(Hunter.ULT_AT[0])
	await _redraw(hud)
	ok(HunterUltTile.state == "ready" and HunterUltTile.shine_from > shone_at,
		"reaching the unlock level: ready, with the shine")

## Waits for the next HudPanels redraw (the slots are drawn there, REDRAW_HZ times a second).
func _redraw(hud) -> void:
	await hud.panels.draw
	await main.get_tree().process_frame

## What the last frame drew on this hunter's plate (HudPlate.shown), or {} if nothing.
func _shown(hud, h: Hunter) -> Dictionary:
	return hud.plates.shown.get(h.nid, {})

## One crowd-control effect at a time on a rival (KIT_PARITY "Crowd control"): the plate's word is its own,
## in its own colour, and no two effects share a colour.
func _cc_words(m: Match, hud, h: Hunter) -> void:
	m.remove_meta("hudref_stun")           # (the demo stops holding the whole row on them)
	var cc := {
		"STUNNED": [Color("fff27a"), func(): h.stun_t = 3.0],
		"ROOTED": [Color("8fe0a0"), func(): h.root_t = 3.0],
		"GROUNDED": [KitStatus.GROUND_COL, func(): KitStatus.apply(h, "gnd", 3.0, 0.0, false, "demo")],
		"DAZED": [KitStatus.RATTLE_COL, func(): KitStatus.apply(h, "rat", 3.0, 0.0, false)],
		"SLOWED": [Color("9ae8ff"), func(): h.slow_t = 3.0],
	}
	var cols := {}
	for word in cc:
		h.stun_t = 0.0
		h.root_t = 0.0
		h.slow_t = 0.0
		h.set_meta("gnd_until", 0.0)
		KitStatus.clear_rattled(h)
		h.reveal_t = 3.0
		(cc[word][1] as Callable).call()
		var got := {}
		for i in 60:
			await main.get_tree().process_frame
			got = _shown(hud, h)
			if String(got.get("word", "")) == word:
				break
		var col: Color = got.get("word_col", Color.BLACK)
		var row: Array = HudPlate.statuses(h).map(func(ic): return String(ic[2]))
		var own: bool = String(got.get("word", "")) == word and col.is_equal_approx(cc[word][0])
		ok(own and row == [word],
			"%s alone: plate word %s in its colour, row %s" % [word, got.get("word", ""), row])
		cols[col.to_html()] = true
	ok(cols.size() == cc.size(), "the %d crowd-control words use %d different colours" % [cc.size(), cols.size()])

## The plate's animation state (chip, crack, burst ...) for this hunter.
func _state(hud, h: Hunter) -> Dictionary:
	return hud.plates.st.get(h.nid, {})

## 8. The knock banners: the player knocks a rival, then a rival knocks a teammate.
func _knock_banners(m: Match, hud, P: Hunter) -> void:
	var kb: KnockBanner = hud.knocks
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team and not x.downed and not x.out)
	ok(rivals.size() >= 2, "two rivals up to knock (%d)" % rivals.size())
	if rivals.size() < 2:
		return
	var knocked: Hunter = rivals[0]
	var other: Hunter = rivals[1]
	m.knock(knocked, P, {})
	await main.get_tree().process_frame
	ok(kb.word() == KnockBanner.FOE_WORD and kb.ring_color() == KnockBanner.FOE_RING and kb.who == knocked,
		"you knock a rival: KNOCK in the red ring, their face and name ('%s')" % kb.word())
	kb.knocked(P, other, P)
	ok(kb.count == 2 and kb.who == other, "a second knock within %.1fs: the newest, x%d" % [
		float(KnockBanner.rules()["combo_s"]), kb.count])
	var back := float(KnockBanner.rules()["back_alpha"])
	ok(back >= 0.45 and back <= 0.6 and not Geometry2D.triangulate_polygon(kb._slash).is_empty()
		and not Geometry2D.triangulate_polygon(kb._slash_dark).is_empty(),
		"the slash and pill are see-through (alpha %.2f, 0.45-0.6) and the slash blades are clean shapes" % back)
	await _banner_closes(kb)
	var mates: Array = m.hunters.filter(func(x): return x != P and x.team == P.team and not x.downed)
	ok(not mates.is_empty(), "a teammate to knock (%d)" % mates.size())
	if mates.is_empty():
		return
	var mate: Hunter = mates[0]
	m.knock(mate, other, {})
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(kb.word() == KnockBanner.ALLY_WORD and kb.ring_color() == KnockBanner.ALLY_RING and kb.who == mate
		and kb.count == 1 and kb.modulate.a > 0.0,
		"a teammate down: ALLY KNOCKED in the cyan ring, on screen ('%s', a %.2f)" % [kb.word(), kb.modulate.a])
	ok(not hud.mates.lines.has(mate.nid), "... and no extra line by their squad row (its KNOCKED tag says it)")
	await _banner_closes(kb)

## Waits out the banner on show: it holds past 1 s and is gone by 1.5 s (its own clock, real frames).
func _banner_closes(kb: KnockBanner) -> void:
	var shown_for := 0.0
	var guard := 0
	while kb.word() != "" and guard < 100000:
		shown_for = kb.t
		await main.get_tree().process_frame
		guard += 1
	ok(kb.word() == "" and shown_for >= 1.0 and shown_for <= 1.5,
		"the banner held %.2fs (1-1.5 s) and is gone" % shown_for)

func _done() -> void:
	print("HUDREF CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
