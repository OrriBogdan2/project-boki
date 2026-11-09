extends RefCounted
## --level-vfx-check: a level-up, a rank-up's ready cue and an ability coming ready give one short
## upward body glow in the Hunter's colour and spawn no ground ring or burst (a ground ring means
## gameplay). The Boki's level-up at home (Home._play_evolutions) gets the same, checked in source.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LEVELVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
			"arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	P.ctrl = "local"
	var fx: Fx = m.fx
	var radial0 := fx.radial
	var glows0 := fx.ghosts.size()
	P.gain_xp(float(Hunter.XP_TO[1]) - P.xp + 1.0)
	ok(P.lvl == 2 and fx.radial == radial0 and fx.rings.is_empty(), "a level-up spawns no ring or burst")
	ok(fx.ghosts.size() == glows0 + 1 and float(fx.ghosts[-1]["rise"]) > 0.0, "a level-up gives one upward body glow")
	ok(fx.ghosts[-1]["col"] == Arch.color(P.arch), "the glow is the Hunter's colour")
	var glows1 := fx.ghosts.size()
	P.ak.armed_fx("READY", "")
	ok(fx.radial == radial0 and fx.rings.is_empty(), "an ability coming ready spawns no ring or burst")
	ok(fx.ghosts.size() == glows1 + 1, "an ability coming ready gives one body glow")
	P.ak._charge_full_tick(Color("ff8844"))
	ok(fx.radial == radial0 and fx.rings.is_empty(), "a full charge spawns no ring or burst")
	ok(fx.ghosts.size() == glows1 + 2, "a full charge gives one body glow")
	var rank0 := fx.radial
	P.skill_pts = 1
	P.level_slot("sec")
	ok(fx.radial == rank0 and fx.rings.is_empty(), "ranking an ability up spawns no ring or burst in the world")
	var src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
	var a := src.find("func _play_evolutions")
	var evo := src.substr(a, src.find("# ---- buildings and bridges") - a)
	ok(evo.contains("body_glow("), "the Boki's level-up at home gives one body glow")
	ok(not evo.contains("fx.ring(") and not evo.contains("fx.burst("), "and no ring or burst")
	print("LEVELVFX %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)
