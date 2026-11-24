extends RefCounted
## --ability-bar-check: the ability bar tells the truth about the kits that got charges or a separate
## airborne slot in the parity work. For Kael (dash charges, the Meteor Drop's own slot while airborne),
## Cinder (dash charges, a second Cinder Shot charge at rank 3), Neve (Ice Spear's two charges) and
## Grimble (two barges, the air pounce's own timer) it reads the kit's charges and timers and asserts
## the drawn bar shows the same: a pip per charge, the recharging pip's fill, the next charge's countdown
## beside a ready one, and the airborne slot's own timer. Never touches the save.

## Charges per rank [1, 2, 3] as the parity table sets them (KIT_PARITY "Charges vs the source"): dash, then RMB.
## Tenzo (dolm) gets a second dash at rank 3; kits without a source row keep their class count.
const COUNTS := {
	"juggernaut": [[2, 3, 3], [1, 1, 1]],
	"bulwark": [[1, 1, 1], [1, 1, 1]],
	"dredge": [[3, 3, 3], [1, 1, 1]],
	"ashwick": [[2, 2, 2], [1, 1, 2]],
	"rimewright": [[1, 1, 1], [2, 2, 2]],
	"gunslinger": [[1, 1, 1], [1, 1, 1]],
	"archer": [[1, 1, 1], [1, 1, 1]],
	"dolm": [[1, 1, 2], [1, 1, 1]],
	"gil": [[1, 1, 1], [2, 2, 2]],
	"mage": [[1, 1, 1], [1, 1, 1]],
	"ostra": [[1, 1, 1], [1, 1, 1]],
	"tender": [[1, 1, 1], [1, 1, 1]],
	"thief": [[1, 1, 1], [1, 1, 1]],
}

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
	await m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 12,
			"no_drop": true,
			"arch": "thief",
			"cls": Arch.weight("thief"),
			"weapon": Arch.signature("thief")
		}
	)
	m.set_process(false)
	var p: Hunter = m.player
	p.ctrl = "local"
	for o in m.hunters:
		if o != p:
			o.ctrl = "idle"
			o.teleport(p.pos + Vector3(40, 0, 40))
	for kit in ["juggernaut", "ashwick", "rimewright", "dredge"]:
		await _kit(m, p, kit)
	for kit in COUNTS:
		await _counts(m, p, kit)
	await _rebound(m, p)
	m.free()
	await _rebound_tutorial()
	print("ABILITY BAR CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _pick(_m: Match, p: Hunter, kit: String, rank: int) -> void:
	p.reclass(Arch.weight(kit), kit, Arch.signature(kit))
	p.unlock_all()
	for s in ["sec", "dash"]:
		p.slot_lv[s] = rank
	p.grounded = true
	p.dashes = p.max_dashes()
	p.ex_cd = 0.0
	p.ak.cd["rmb"] = 0.0
	p.ak.ch_rmb = float(p.ak.rmb_charges())
	HudSlot.shown_pips.erase("sec")


func _kit(m: Match, p: Hunter, kit: String) -> void:
	var hid: int = m.hud.get_instance_id()
	for rank in [1, 2, 3]:
		_pick(m, p, kit, rank)
		var tag := "%s rank %d" % [kit, rank]
		await _dash(m, p, hid, tag)
		await _rmb(m, p, tag)
	_pick(m, p, kit, 3)
	await _airborne(m, p, hid, kit)


## Dash: a disc per charge (kit + rank; none for one charge), one ready and the next at 45%, the countdown of the next.
func _dash(m: Match, p: Hunter, hid: int, tag: String) -> void:
	var cap := int(p.max_dashes())
	p.dashes = float(cap) - 0.55 if cap > 1 else 1.0
	await _drawn(m.hud)
	var sh: Dictionary = DashSlot.shown.get(hid, {})
	var want: Array = []
	for i in cap if cap > 1 else 0:  # a one-charge dash draws no charge discs (the source)
		want.append(clampf(p.dashes - i, 0.0, 1.0))
	var text := HudSlot.cd_text((1.0 - fposmod(p.dashes, 1.0)) * p.dash_regen()) if cap > 1 else ""
	ok(
		_near(sh.get("pips", []), want) and sh.get("text", "") == text,
		"%s: dash %d pips %s, next charge in '%s'" % [tag, cap, sh.get("pips"), sh.get("text")]
	)


## RMB: pips exist exactly when the kit holds more than one charge; the recharging one fills, and a
## ready charge shows the next one's countdown.
func _rmb(m: Match, p: Hunter, tag: String) -> void:
	var mx := p.ak.rmb_charges()
	if mx > 1:
		p.ak.ch_rmb = float(mx - 1)
		p.ak.cd["rmb"] = 0.25 * float(p.ak.rmb_def().get("cooldown", 6.0)) * p.ak.cd_k("sec")
	await _drawn(m.hud)
	var pips: Array = HudSlot.shown_pips.get("sec", [])
	if mx <= 1:
		ok(pips.is_empty(), "%s: one RMB charge, no pips" % tag)
		return
	var want: Array = []
	for i in mx:
		want.append(clampf(float(mx - 1) + 0.75 - i, 0.0, 1.0))
	var left: float = float(p.ak.cd["rmb"])
	ok(
		_near(pips, want) and m.hud.slot_text.get("sec", "") == HudSlot.cd_text(left),
		"%s: RMB %d charges, pips %s, next in '%s' (%.1fs)" % [tag, mx, pips, m.hud.slot_text.get("sec", ""), left]
	)
	p.ak.ch_rmb = 0.0
	await _drawn(m.hud)
	var first: Array = HudSlot.shown_pips["sec"]
	var rest_empty: bool = first.slice(1).all(func(f): return f == 0.0)
	ok(
		absf(float(first[0]) - 0.75) < 0.02 and rest_empty and m.hud.slot_text.get("sec", "") == HudSlot.cd_text(left),
		"%s: RMB none ready, first pip at 75%%, countdown %.1fs" % [tag, left]
	)


## The contextual slot's own timer while airborne: Kael's Meteor Drop on the RMB slot, Grimble's air
## pounce beside the dash; on the ground neither is spelled out.
func _airborne(m: Match, p: Hunter, hid: int, kit: String) -> void:
	if kit == "juggernaut":
		p.ak.cd["air"] = 3.0
		p.ak.cd["rmb"] = 0.0
		p.ak.ch_rmb = 1.0
		p.grounded = false
		await _drawn(m.hud)
		var txt: String = m.hud.slot_text.get("sec", "")
		ok(txt == HudSlot.cd_text(3.0), "Kael airborne: the RMB slot counts the Meteor Drop's own 3 s ('%s')" % txt)
		p.ak.cd["air"] = 0.0
		p.ak.cd["rmb"] = 5.0
		p.ak.ch_rmb = 0.0
		await _drawn(m.hud)
		txt = m.hud.slot_text.get("sec", "")
		ok(txt == "", "Kael airborne: Meteor Drop ready while the Smash rests, slot shows no countdown")
		p.grounded = true
		await _drawn(m.hud)
		txt = m.hud.slot_text.get("sec", "")
		ok(txt == HudSlot.cd_text(5.0), "Kael on the ground: the Smash's own 5 s again")
	elif kit == "dredge":
		var full: float = p.ak.long_dash_cd()
		p.ex_cd = full * 0.5
		p.grounded = false
		await _drawn(m.hud)
		var sh: Dictionary = DashSlot.shown[hid]
		ok(
			absf(float(sh["air"]) - 0.5) < 0.01 and sh["air_text"] == HudSlot.cd_text(full * 0.5),
			"Grimble airborne: the air pounce half back, its own '%s' of %.1f s (rank 3)" % [sh["air_text"], full]
		)
		p.grounded = true
		await _drawn(m.hud)
		ok(DashSlot.shown[hid]["air_text"] == "", "Grimble on the ground: no air countdown")


## E is the "signature" action (bar slot k1) and R the "hunter_ult" action (bar slot x; "ultimate" is the
## Fusion key on slot r): E goes to mouse 4 ("M4"), R to N. The bar's pills and tooltips must follow.
func _rebound(m: Match, p: Hunter) -> void:
	_pick(m, p, "juggernaut", 3)
	p.lvl = int(Hunter.ULT_AT[0])
	var m4 := InputEventMouseButton.new()
	m4.button_index = MOUSE_BUTTON_XBUTTON1
	var n := InputEventKey.new()
	n.physical_keycode = KEY_N
	Settings.rebind("signature", m4, 0)
	Settings.rebind("hunter_ult", n, 0)
	ok(
		Settings.key_cap("signature") == "M4" and Settings.key_cap("hunter_ult") == "N",
		"rebind: E is '%s', R is '%s'" % [Settings.key_cap("signature"), Settings.key_cap("hunter_ult")]
	)
	HudSlot.shown_keys.clear()
	await _drawn(m.hud)
	await _drawn(m.hud)
	var bar: Dictionary = HudSlot.shown_keys
	ok(bar.get("k1", "") == "M4", "rebind: the E slot on the bar shows '%s'" % bar.get("k1", ""))
	ok(bar.get("x", "") == "N", "rebind: the R slot on the bar shows '%s'" % bar.get("x", ""))
	var fuse: String = bar.get("r", "")
	ok(fuse != "N" and fuse != "M4", "rebind: the Fusion slot keeps its own key ('%s')" % fuse)
	for id in ["k1", "x"]:
		var want := "M4" if id == "k1" else "N"
		var head := String(m.hud.hover.tip_lines(id, p)[1][0])
		ok(head.contains("  ·  %s" % want), "rebind: the %s tooltip names '%s' ('%s')" % [id, want, head])
	for id in ["sec", "dash"]:
		var tip: String = String(m.hud.hover.tip_lines(id, p)[1][0])
		var own := not tip.contains("  ·  M4  ·  ") and not tip.contains("  ·  N  ·  ")
		ok(own, "rebind: the %s tooltip keeps its own key" % id)


## The tutorial's strip cap and every %E line say the new E key; no step still names "E" as a key.
func _rebound_tutorial() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var tu: Tutorial = m.tut
	var seen := 0
	var stale := RegEx.create_from_string("(?i)\\b(?:press|hold|tap|use|with)\\s+E\\b|\\(E\\)")
	var off: Array = []
	for i in Tutorial.steps().size():
		tu.step = i
		tu._words()
		var sid: String = tu.id()
		if Tutorial.KEYS.get(sid, "") == "signature":
			seen += 1
			if tu.key_cap != "M4":
				off.append("%s cap %s" % [sid, tu.key_cap])
		var raw := String(Tutorial.steps()[i][1]) + String(Content.rules("tutorial")["alt"].get(sid, ""))
		if raw.contains("%E") and not (tu.text + tu.detail).contains("M4"):
			off.append("%s line lacks M4" % sid)
		if stale.search(tu.text + " " + tu.detail + " " + tu.scout_hint()) != null:
			off.append("%s names E" % sid)
	ok(seen > 0 and off.is_empty(), "rebind: the tutorial shows M4 on %d E steps, no hard-coded E" % seen + str(off))
	m.free()


## Every kit, every rank: the dash and RMB show the parity table's charge count, a spent charge draws the same
## on all of them (an empty disc, the recharging one filling), and a rank that adds a charge adds a disc.
func _counts(m: Match, p: Hunter, kit: String) -> void:
	var hid: int = m.hud.get_instance_id()
	var want: Array = COUNTS[kit]
	for rank in [1, 2, 3]:
		_pick(m, p, kit, rank)
		var tag := "%s rank %d" % [kit, rank]
		var dash_n: int = want[0][rank - 1]
		var rmb_n: int = want[1][rank - 1]
		ok(
			int(p.max_dashes()) == dash_n and p.ak.rmb_charges() == rmb_n,
			(
				"%s: kit holds %d dash, %d RMB charges (table %d, %d)"
				% [tag, int(p.max_dashes()), p.ak.rmb_charges(), dash_n, rmb_n]
			)
		)
		await _dash(m, p, hid, tag)
		await _rmb(m, p, tag)
		await _spent_dash(m, p, hid, tag)


## A dash with every charge spent and the next at 30%: one dark disc per charge, the first filling, the countdown
## on the first (nothing for a one-charge dash, which draws no discs).
func _spent_dash(m: Match, p: Hunter, hid: int, tag: String) -> void:
	var cap := int(p.max_dashes())
	p.dashes = 0.3
	await _drawn(m.hud)
	var sh: Dictionary = DashSlot.shown.get(hid, {})
	var pips: Array = sh.get("pips", [])
	var rest_empty: bool = pips.slice(1).all(func(f): return f == 0.0)
	var text := HudSlot.cd_text(0.7 * p.dash_regen())
	if cap <= 1:
		ok(pips.is_empty(), "%s: one dash charge spent, no discs" % tag)
	else:
		ok(
			pips.size() == cap and absf(float(pips[0]) - 0.3) < 0.02 and rest_empty and sh.get("text", "") == text,
			"%s: dash all spent, %d discs, first at 30%%, countdown '%s'" % [tag, cap, sh.get("text")]
		)
