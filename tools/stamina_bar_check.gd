extends RefCounted
## --stamina-bar-check: the dash bar (StaminaBar). One short segment per dash charge from the kit and
## class data (plus the long dash's where the kit has it) for all twelve archetypes; the recharging
## segment's fill follows the recharge timer; a completed segment flashes (and ticks on your own bar,
## but not on first sight); the long dash's cooldown drives its own segment; pressing dash with nothing
## to spend shakes the bar and flashes it red. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("STAMINABAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	P.ctrl = "local"
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(P.pos + Vector3(40, 0, 40))
	var stam: StaminaBar = m.hud.plates.stam
	ok(stam != null, "the plates own a dash bar")
	# ---------------------------------------------------------------- 1. segments == charges, every archetype
	for a in Arch.ORDER:
		P.reclass(Arch.weight(a), a, Arch.signature(a))
		P.unlock_all()
		var want := int(Content.class_dodge(Arch.weight(a)).charges) + int(P.ak.extra_dashes() if P.ak else 0.0)
		var f := StaminaBar.fills(P)
		var longs := 1 if (P.ak == null or P.ak.has_long_dash()) else 0
		var extra := " + long" if longs else ""
		ok(StaminaBar.shorts(P) == want and f.size() == want + longs,
			"%s: %d dash segments%s = %d charges%s" % [a, StaminaBar.shorts(P), extra, want, extra])
	# ---------------------------------------------------------------- 2. fill follows the recharge timer
	P.reclass(Arch.weight("thief"), "thief", Arch.signature("thief"))
	P.unlock_all()
	var regen := P.dash_regen()
	P.dashes = 0.0
	P.ex_cd = StaminaBar.long_cd(P) * 0.5
	var f0 := StaminaBar.fills(P)
	var long_fill: float = f0[f0.size() - 1]
	ok(float(f0[0]) == 0.0 and absf(long_fill - 0.5) < 0.01, "spent: charge empty, long dash half back")
	for secs in [1.0, 2.5]:
		P.dashes = 0.0
		for i in int(secs / Match.DT):
			P.dashes = minf(P.max_dashes(), P.dashes + Match.DT / P.dash_regen())     # (Hunter's tick)
		var fr: float = float(StaminaBar.fills(P)[0])
		var want_fr: float = secs / regen
		var msg := "%.1fs into %.1fs: %.0f%% full (want %.0f%%)" % [secs, regen, fr * 100.0, want_fr * 100.0]
		ok(absf(fr - want_fr) < 0.02, msg)
	P.dashes = 0.0
	var d0 := P.dashes
	for i in 60:
		m.step(Match.DT)
	var gained := P.dashes - d0
	var full := P.dashes >= P.max_dashes()
	ok(absf(gained - 1.0 / regen) < 0.01 or full, "the real tick refills a second (%.3f)" % gained)
	# ---------------------------------------------------------------- 3. flash and tick on completion
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	stam.st.clear()
	var s := stam.update(P, 1.0, true)
	var fl0: float = (s["flash"] as Array)[0]
	ok(int(s["completes"]) == 0 and fl0 == 0.0, "a full bar seen for the first time doesn't flash")
	P.dashes = 0.0
	stam.update(P, 1.1, true)
	P.dashes = 0.9
	stam.update(P, 1.2, true)
	var tick0: int = int(Sfx.last_played.get("click", -1000))
	P.dashes = 1.0
	s = stam.update(P, 1.3, true)
	var fl1: float = (s["flash"] as Array)[0]
	ok(int(s["completes"]) == 1 and fl1 > 0.15, "the segment completing flashes (%.2fs left)" % fl1)
	ok(int(Sfx.last_played.get("click", -1000)) > tick0 or Sfx.streams.is_empty(), "and ticks softly on your own bar")
	s = stam.update(P, 1.3 + StaminaBar.FLASH_T + 0.05, true)
	ok(float((s["flash"] as Array)[0]) == 0.0, "the flash fades out")
	P.dashes = 0.5
	stam.update(P, 2.0)
	P.dashes = 1.0
	var t1: int = int(Sfx.last_played.get("click", -1000))
	stam.update(P, 2.1, false)
	ok(int(Sfx.last_played.get("click", -1000)) == t1, "a teammate's bar flashes but stays silent")
	# ---------------------------------------------------------------- 4. an empty press shakes and flashes red
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
		stam.st.clear()
		stam.update(P, 3.0)
		var before := int(stam.st[P.nid]["denies"])
		P.do_dash()
		var s2: Dictionary = stam.st[P.nid]
		var hit := int(s2["denies"]) == before + 1 and float(s2["shake"]) > 0.0
		if hit:
			denied += 1
		ok(hit, "%s: dash with no charge shakes the bar" % a)
	ok(denied == Arch.ORDER.size(), "all %d archetypes give the empty-press feedback" % denied)
	print("STAMINA BAR CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
