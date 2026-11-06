extends RefCounted
## --dash-slot-check: the dash slot (DashSlot), one component at home and in a match. Checks, with the real
## HUD and the real Home: a pip per charge from the kit and class data for all twelve archetypes (plus the
## air-dash diamond where the kit has one); the recharging pip's fill and the countdown follow the
## recharge timer; a charge returning flashes the slot and ticks (own bar only, not on first sight);
## the key cap comes from Settings.key_cap; an empty press shakes it red; the overhead plates no longer
## carry a dash bar; and the farm draws the very same slot from its own copy of the same numbers, with
## no separate farm-only dash display left. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DASHSLOT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(n := 2) -> void:
	for i in n:
		await main.get_tree().process_frame

## The match HUD draws the slots on HudPanels, REDRAW_HZ times a second: wait for its next draw.
func _drawn(hud) -> void:
	await hud.panels.draw
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	P.ctrl = "local"
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(P.pos + Vector3(40, 0, 40))
	var hud = m.hud
	var hid: int = hud.get_instance_id()
	ok(not ("stam" in hud.plates), "the overhead plates have no dash bar any more")
	ok(DashSlot.PIP_R * 2.0 >= 8.0, "a charge pip is a disc at least 8 px across (%.0f)" % (DashSlot.PIP_R * 2.0))
	await _pips_and_timer(m, P, hid)
	await _flash_and_tick(m, P, hid)
	await _deny(m, P)
	await _home_slot()
	print("DASH SLOT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## 1 + 2: pips == charges for every archetype, the recharging pip and the countdown follow the timer.
func _pips_and_timer(m: Match, P: Hunter, hid: int) -> void:
	for a in Arch.ORDER:
		P.reclass(Arch.weight(a), a, Arch.signature(a))
		P.unlock_all()
		P.dashes = P.max_dashes()
		await _drawn(m.hud)
		var want := int(Content.class_dodge(Arch.weight(a)).charges) + int(P.ak.extra_dashes() if P.ak else 0.0)
		var air := P.ak == null or P.ak.has_long_dash()
		var sh: Dictionary = DashSlot.shown.get(hid, {})
		var pips: Array = sh.get("pips", [])
		ok(pips.size() == want and pips.all(func(f): return f == 1.0) and (float(sh.get("air", -1.0)) >= 0.0) == air,
			"%s: %d pips, all full = %d charges, air dash %s" % [a, pips.size(), want, air])
	P.reclass(Arch.weight("juggernaut"), "juggernaut", Arch.signature("juggernaut"))
	P.unlock_all()
	var regen: float = P.dash_regen()
	for frac in [0.0, 0.3, 0.8]:
		P.dashes = 1.0 + frac
		P.ex_cd = 0.0
		await _drawn(m.hud)
		var sh: Dictionary = DashSlot.shown[hid]
		var pips: Array = sh["pips"]
		var left: float = (1.0 - frac) * regen
		var shape: bool = pips.size() == int(P.max_dashes()) and absf(float(pips[0]) - 1.0) < 0.001
		shape = shape and absf(float(pips[1]) - frac) < 0.001
		ok(shape and sh["text"] == HudSlot.cd_text(left),
			"1 charge + %.0f%%: pips %s, countdown '%s' (%.2fs of %.2fs)" % [frac * 100, pips, sh["text"], left, regen])
	P.dashes = 0.0
	await _drawn(m.hud)
	var sh0: Dictionary = DashSlot.shown[hid]
	var empty: bool = sh0["pips"].all(func(f): return f == 0.0)
	ok(empty and sh0["text"] == HudSlot.cd_text(regen), "0 charges: every pip empty, countdown '%s'" % sh0["text"])
	P.dashes = 0.0
	var d0 := P.dashes
	for i in 60:
		m.step(Match.DT)
	var gained: float = P.dashes - d0
	ok(absf(gained - 1.0 / regen) < 0.01, "the real tick refills the slot's timer (%.3f charge in a second)" % gained)
	P.ex_cd = 5.0
	await _drawn(m.hud)
	var air_back := float(DashSlot.shown[hid]["air"])
	ok(air_back < 0.9, "the air-dash diamond follows its own cooldown (%.2f back)" % air_back)
	P.ex_cd = 0.0

## 3: a returning charge flashes the slot; the tick plays on your own slot only; first sight stays quiet.
func _flash_and_tick(m: Match, P: Hunter, hid: int) -> void:
	var hud = m.hud
	P.dashes = 0.9
	await _drawn(m.hud)
	hud.ready_flash.erase("dash")
	var tick0: int = int(Sfx.last_played.get("click", -1000))
	P.dashes = 1.0
	await _drawn(m.hud)
	var flash := float(hud.ready_flash.get("dash", 0.0))
	ok(flash > 0.1, "a charge returning flashes the slot (%.2fs left)" % flash)
	ok(int(Sfx.last_played.get("click", -1000)) > tick0 or Sfx.streams.is_empty(), "... and ticks softly")
	hud.ready_flash.erase("dash")
	DashSlot._was.erase(hid)
	P.dashes = 2.0
	await _drawn(m.hud)
	ok(not hud.ready_flash.has("dash"), "a slot seen for the first time doesn't flash")

## 4: dash pressed with nothing to spend shakes the slot (red), for every archetype.
func _deny(m: Match, P: Hunter) -> void:
	var denied := 0
	for a in Arch.ORDER:
		P.reclass(Arch.weight(a), a, Arch.signature(a))
		P.unlock_all()
		P.grounded = true
		P.dashes = 0.0
		P.ex_cd = 5.0
		P.stun_t = 0.0
		P.roll_t = 0.0
		P.dash_buf = 0.0
		m.hud.slot_fx.erase("dash")
		P.do_dash()
		if m.hud.slot_fx.get("dash", {}).get("kind", "") == "deny":
			denied += 1
	var all: int = Arch.ORDER.size()
	ok(denied == all, "%d of %d archetypes shake the slot on an empty press" % [denied, all])
	m.queue_free()
	await _frames()

## 5: the farm's slot is the same component fed by the farm's copy of the numbers; the old farm pips are gone.
func _home_slot() -> void:
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"home": true, "day1_done": true}
	Econ.ensure()
	var home = await main._hb_home()
	ok(not ("dash_pips" in home), "the farm's own overhead dash pips are gone")
	home.panel_open = ""
	home._move_player(0.001)
	var slot: HomeDashSlot = home.dash_slot
	ok(slot != null and slot.get_parent() == home.ui, "the farm has the dash slot on its HUD layer")
	if slot == null:
		home.queue_free()
		return
	var hid: int = slot.get_instance_id()
	var dg: Dictionary = home._dodge()
	var cap := int(dg["charges"])
	var regen := float(dg["cd"])
	home.set_process(false)
	home.set_physics_process(false)
	for case in [[float(cap), 0.0], [float(cap - 1) + 0.4, 0.0], [0.0, 3.0]]:
		home.dash_charges = case[0]
		home.ex_cd = case[1]
		await _frames()
		var sh: Dictionary = DashSlot.shown.get(hid, {})
		var pips: Array = sh.get("pips", [])
		var fl := floorf(float(case[0]))
		var left: float = 0.0 if int(fl) >= cap else (1.0 - (float(case[0]) - fl)) * regen
		var right: bool = pips.size() == cap
		for i in pips.size():
			right = right and absf(float(pips[i]) - clampf(float(case[0]) - float(i), 0.0, 1.0)) < 0.001
		ok(right and (left == 0.0 or sh["text"] == HudSlot.cd_text(left)),
			"farm at %.1f charges: pips %s, countdown '%s' (%.2fs)" % [float(case[0]), pips, sh.get("text", ""), left])
		var cap_txt := Settings.key_cap("dash")
		ok(HudSlot.shown_keys.get("dash", "") == cap_txt, "the farm's slot shows the dash key '%s'" % cap_txt)
	home.dash_charges = 0.0
	home.ex_cd = 0.0
	slot.slot_fx.erase("dash")
	home.dash_t = 0.0
	slot.deny()
	ok(slot.slot_fx.get("dash", {}).get("kind", "") == "deny", "an empty press shakes the farm's slot too")
	home.queue_free()
	await _frames()
