extends RefCounted
## --ability-bar-check: the ability bar tells the truth about the kits that got charges or a separate
## airborne slot in the parity work. For Kael (dash charges, the Meteor Drop's own slot while airborne),
## Cinder (dash charges, a second Cinder Shot charge at rank 3), Neve (Ice Spear's two charges) and
## Grimble (two barges, the air pounce's own timer) it reads the kit's charges and timers and asserts
## the drawn bar shows the same: a pip per charge, the recharging pip's fill, the next charge's countdown
## beside a ready one, and the airborne slot's own timer. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("ABILITYBAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _drawn(hud) -> void:
	await hud.panels.draw
	await main.get_tree().process_frame

func _near(a: Array, b: Array) -> bool:
	return a.size() == b.size() and range(a.size()).all(func(i): return absf(float(a[i]) - float(b[i])) < 0.02)

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
	for kit in ["juggernaut", "ashwick", "rimewright", "dredge"]:
		await _kit(m, P, kit)
	print("ABILITY BAR CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _pick(m: Match, P: Hunter, kit: String, rank: int) -> void:
	P.reclass(Arch.weight(kit), kit, Arch.signature(kit))
	P.unlock_all()
	for s in ["sec", "dash"]:
		P.slot_lv[s] = rank
	P.grounded = true
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.ak.cd["rmb"] = 0.0
	P.ak.ch_rmb = float(P.ak.rmb_charges())
	HudSlot.shown_pips.erase("sec")

func _kit(m: Match, P: Hunter, kit: String) -> void:
	var hid: int = m.hud.get_instance_id()
	for rank in [1, 2, 3]:
		_pick(m, P, kit, rank)
		var tag := "%s rank %d" % [kit, rank]
		await _dash(m, P, hid, tag)
		await _rmb(m, P, tag)
	_pick(m, P, kit, 3)
	await _airborne(m, P, hid, kit)

## Dash: a pip per charge (kit + rank), one ready and the next at 45%, the countdown of the next.
func _dash(m: Match, P: Hunter, hid: int, tag: String) -> void:
	var cap := int(P.max_dashes())
	P.dashes = float(cap) - 0.55 if cap > 1 else 1.0
	await _drawn(m.hud)
	var sh: Dictionary = DashSlot.shown.get(hid, {})
	var want: Array = []
	for i in cap:
		want.append(clampf(P.dashes - i, 0.0, 1.0))
	var text := HudSlot.cd_text((1.0 - fposmod(P.dashes, 1.0)) * P.dash_regen()) if cap > 1 else ""
	ok(_near(sh.get("pips", []), want) and sh.get("text", "") == text,
		"%s: dash %d pips %s, next charge in '%s'" % [tag, cap, sh.get("pips"), sh.get("text")])

## RMB: pips exist exactly when the kit holds more than one charge; the recharging one fills, and a
## ready charge shows the next one's countdown.
func _rmb(m: Match, P: Hunter, tag: String) -> void:
	var mx := P.ak.rmb_charges()
	if mx > 1:
		P.ak.ch_rmb = float(mx - 1)
		P.ak.cd["rmb"] = 0.25 * float(P.ak.rmb_def().get("cooldown", 6.0)) * P.ak.cd_k("sec")
	await _drawn(m.hud)
	var pips: Array = HudSlot.shown_pips.get("sec", [])
	if mx <= 1:
		ok(pips.is_empty(), "%s: one RMB charge, no pips" % tag)
		return
	var want: Array = []
	for i in mx:
		want.append(clampf(float(mx - 1) + 0.75 - i, 0.0, 1.0))
	var left: float = float(P.ak.cd["rmb"])
	ok(_near(pips, want) and m.hud.slot_text.get("sec", "") == HudSlot.cd_text(left),
		"%s: RMB %d charges, pips %s, next in '%s' (%.1fs)" % [tag, mx, pips, m.hud.slot_text.get("sec", ""), left])
	P.ak.ch_rmb = 0.0
	await _drawn(m.hud)
	var first: Array = HudSlot.shown_pips["sec"]
	ok(absf(float(first[0]) - 0.75) < 0.02 and first.slice(1).all(func(f): return f == 0.0) and m.hud.slot_text.get("sec", "") == HudSlot.cd_text(left),
		"%s: RMB none ready, first pip at 75%%, countdown %.1fs" % [tag, left])

## The contextual slot's own timer while airborne: Kael's Meteor Drop on the RMB slot, Grimble's air
## pounce beside the dash; on the ground neither is spelled out.
func _airborne(m: Match, P: Hunter, hid: int, kit: String) -> void:
	if kit == "juggernaut":
		P.ak.cd["air"] = 3.0
		P.ak.cd["rmb"] = 0.0
		P.ak.ch_rmb = 1.0
		P.grounded = false
		await _drawn(m.hud)
		ok(m.hud.slot_text.get("sec", "") == HudSlot.cd_text(3.0), "Kael airborne: the RMB slot counts the Meteor Drop's own 3 s ('%s')" % m.hud.slot_text.get("sec", ""))
		P.ak.cd["air"] = 0.0
		P.ak.cd["rmb"] = 5.0
		P.ak.ch_rmb = 0.0
		await _drawn(m.hud)
		ok(m.hud.slot_text.get("sec", "") == "", "Kael airborne: Meteor Drop ready while the Smash rests, slot shows no countdown")
		P.grounded = true
		await _drawn(m.hud)
		ok(m.hud.slot_text.get("sec", "") == HudSlot.cd_text(5.0), "Kael on the ground: the Smash's own 5 s again")
	elif kit == "dredge":
		var full: float = P.ak.long_dash_cd()
		P.ex_cd = full * 0.5
		P.grounded = false
		await _drawn(m.hud)
		var sh: Dictionary = DashSlot.shown[hid]
		ok(absf(float(sh["air"]) - 0.5) < 0.01 and sh["air_text"] == HudSlot.cd_text(full * 0.5),
			"Grimble airborne: the air pounce half back, its own '%s' of %.1f s (rank 3)" % [sh["air_text"], full])
		P.grounded = true
		await _drawn(m.hud)
		ok(DashSlot.shown[hid]["air_text"] == "", "Grimble on the ground: no air countdown")
