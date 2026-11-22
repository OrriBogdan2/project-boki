extends RefCounted
## --vex-dash-check: Vex's Slipstep is one dash with one cooldown, not a charge dash. Her
## max_dashes() is 1, the Second Wind perk gives her nothing, the dash slot draws no charge pips, and a
## kill still refills her dash. Other hunters keep their charges. Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("VEXDASH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
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
			"arch": "gunslinger",
			"cls": Arch.weight("gunslinger"),
			"weapon": Arch.signature("gunslinger")
		}
	)
	m.set_process(false)
	var vex: Hunter = m.player
	vex.ctrl = "local"
	for o in m.hunters:
		if o != vex:
			o.ctrl = "idle"
			o.teleport(vex.pos + Vector3(40, 0, 40))
	ok(vex.max_dashes() == 1.0, "Vex max_dashes() is %s" % vex.max_dashes())
	vex.perks.append("secondwind")
	ok(vex.max_dashes() == 1.0, "Second Wind leaves Vex at %s" % vex.max_dashes())
	ok(not vex.perk_open("secondwind"), "Second Wind is not offered to Vex")
	vex.perks.clear()
	vex.unlock_all()
	vex.dashes = 0.0
	await main.get_tree().process_frame
	var info := vex.slot_info("dash")
	ok(int(info["max_charges"]) == 0, "Vex dash slot reports max_charges %s" % info["max_charges"])
	vex.dashes = 1.0
	await m.hud.panels.draw
	var hid: int = m.hud.get_instance_id()
	var sh: Dictionary = DashSlot.shown.get(hid, {})
	ok((sh.get("pips", [1]) as Array).is_empty(), "Vex dash slot draws pips %s" % [sh.get("pips")])
	vex.dashes = 0.0
	vex.ex_cd = 5.0
	DashReset.takedown(vex, m.hunters[1])
	ok(
		vex.dashes == 1.0 and vex.ex_cd == 0.0,
		"a takedown refills Vex's dash (%s, long cd %s)" % [vex.dashes, vex.ex_cd]
	)
	for kit in ["dredge"]:
		vex.reclass(Arch.weight(kit), kit, Arch.signature(kit))
		ok(vex.max_dashes() >= 2.0, "%s keeps its charges (%s)" % [kit, vex.max_dashes()])
	print("VEX DASH CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
