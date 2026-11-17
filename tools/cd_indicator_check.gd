extends RefCounted
## --cd-indicator-check: the cooldown and dash indicator shows the real ability state. Per hero, a real dash
## (Shift, ground then air) and a real RMB cast are driven through the match step by step; after every step the
## HUD panels redraw and what the slots show (DashSlot.shown pips and air diamond, Hud.slot_text for RMB) is
## compared with the timers that decide the press (Hunter.dashes, ex_cd; ArchKit.cd, ch_rmb). Then the press
## itself: a slot the bar shows cooling refuses it (no hold, no move, nothing spent). Never touches the save.

const HEROES := ["thief", "juggernaut", "gunslinger", "dolm"]   # dolm and juggernaut have an RMB hold
const STEPS := 150            # match steps watched per ability (2.5 s at 60 Hz)
const PIP_TOL := 0.01         # charges: a pip's fill may differ from Hunter.dashes by this much
const LEFT_S := 4.0           # s of cooldown a slot is given for the refused-press rows

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CDIND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for hero in HEROES:
		var m := Match.new()
		main.add_child(m)
		await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
			"arch": hero, "cls": Arch.weight(hero), "weapon": Arch.signature(hero)})
		m.set_process(false)
		var P: Hunter = m.player
		P.ctrl = "local"
		P.unlock_all()
		for o in m.hunters:
			if o != P:
				o.ctrl = "idle"
				o.teleport(P.pos + Vector3(40, 0, 40))
		await _dash(m, P, hero)
		await _rmb(m, P, hero)
		await _presses(m, P, hero)
		m.queue_free()
		await main.get_tree().process_frame
	print("CD INDICATOR CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## One step of the match, then the panels draw once.
func _frame(m: Match) -> void:
	m.step(Match.DT)
	m.hud.panels.queue_redraw()
	await m.hud.panels.draw

## The dash slot against the dash timers, after every step of a ground dash and an air dash.
func _dash(m: Match, P: Hunter, hero: String) -> void:
	var hid: int = m.hud.get_instance_id()
	for air in [false, true]:
		var tag := "%s %s dash" % [hero, "air" if air else "ground"]
		P.dashes = P.max_dashes()
		P.ex_cd = 0.0
		P.grounded = not air
		P.inp["dash"] = true
		await _frame(m)
		P.inp["dash"] = false
		ok(P.dashes < P.max_dashes() - 0.5 or P.ex_cd > 0.0, "%s: the press spent a charge or the air dash" % tag)
		var off := ""
		for i in STEPS:
			await _frame(m)
			var sh: Dictionary = DashSlot.shown.get(hid, {})
			var shown := 0.0
			for f in sh.get("pips", []):
				shown += float(f)
			if absf(shown - minf(P.dashes, P.max_dashes())) > PIP_TOL and off == "":
				off = "step %d: pips %.3f vs dashes %.3f" % [i, shown, P.dashes]
			var air_back := 1.0 - P.ex_cd / DashSlot.air_cd_of(P)
			if float(sh.get("air", -1.0)) >= 0.0 and absf(float(sh["air"]) - clampf(air_back, 0.0, 1.0)) > PIP_TOL \
					and off == "":
				off = "step %d: air %.3f vs ex_cd %.3f" % [i, float(sh["air"]), P.ex_cd]
		ok(off == "", "%s: the slot follows the timers every step (%s)" % [tag, off if off != "" else "exact"])

## The RMB slot against ArchKit's own cooldown, after every step of a cast and its recharge.
func _rmb(m: Match, P: Hunter, hero: String) -> void:
	var k: ArchKit = P.ak
	P.inp["aim"] = P.pos + Vector3(0, 0, -6)
	k.ch_rmb = float(k.rmb_charges())
	k.cd["rmb"] = 0.0
	P.inp["sec"] = true
	await _frame(m)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	var off := ""
	var spent := false
	for i in STEPS * 3:
		await _frame(m)
		# (a hold casts on its release)
		spent = spent or k.ch_rmb < float(k.rmb_charges()) or float(k.cd["rmb"]) > 0.0
		var info := P.slot_info("sec")
		var txt := String(m.hud.slot_text.get("sec", ""))
		var want := ""
		if not bool(info["ready"]) and float(info["cd"]) > 0.0:
			want = HudSlot.cd_text(float(info["cd"]))
		if txt != want and off == "":
			off = "step %d: shows '%s', timer says '%s' (cd %.2f)" % [i, txt, want, float(info["cd"])]
	ok(spent, "%s RMB: the press spent a charge" % hero)
	var shown := off if off != "" else "exact"
	ok(off == "", "%s RMB: the countdown equals the ability timer every step (%s)" % [hero, shown])

## The bar and the press agree: a slot the bar shows cooling refuses the press and spends nothing.
func _presses(m: Match, P: Hunter, hero: String) -> void:
	var k: ArchKit = P.ak
	P.grounded = true
	for i in STEPS:
		await _frame(m)
	k.ch_rmb = 0.0
	k.cd["rmb"] = LEFT_S
	var anim := k.anim_at
	ok(not bool(P.slot_info("sec")["ready"]), "%s RMB: the bar shows the cooling slot as not ready" % hero)
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	for i in 6:
		await _frame(m)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	ok(not k.rmb_down and k.anim_at == anim and k.ch_rmb < 1.0,
		"%s RMB: a press on the cooling slot is refused (no hold, no move, nothing spent)" % hero)
	P.dashes = 0.0
	P.ex_cd = LEFT_S
	ok(not bool(P.slot_info("dash")["ready"]), "%s dash: the bar shows no charge as not ready" % hero)
	P.do_dash()
	await _frame(m)
	ok(P.roll_t <= 0.0 and P.dashes < 1.0 and P.ex_cd > LEFT_S - 0.2,
		"%s dash: a press with no charge is refused (no roll, nothing spent)" % hero)
