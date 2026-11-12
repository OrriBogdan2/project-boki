extends RefCounted
## --level-hud-check: the run level reads at a glance. The portrait carries a big level number with
## an XP ring that fills toward the next level; a level-up pops the badge, washes the screen gold and
## plays its own sound (audio/level_up.wav, made by tools/gen_sfx_ui.py); R shows locked (a
## padlock and "6") until level 6, and can't be cast or ranked before then. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LEVELHUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P: o.ctrl = "idle"; o.teleport(m.world.spawns[-1])
	P.ctrl = "local"      # (the level-up moment is the local player's)
	P.inp["move"] = Vector2.ZERO
	var hud = m.hud
	ok(hud != null and P.ak != null, "a match with a HUD and an archetype (%s)" % P.arch)
	# ---------------------------------------------------------------- 1. the sound exists and is its own
	ok(Sfx.streams.has("level_up") and ResourceLoader.exists("res://audio/level_up.wav"), "the level-up sound is loaded (audio/level_up.wav)")
	# ---------------------------------------------------------------- 2. XP ring follows the level's progress
	P.lvl = 1; P.xp = 0.0; P.skill_pts = 1
	for s in Hunter.SLOTS: P.slot_lv[s] = 0
	ok(P.xp_frac() == 0.0, "level 1, no XP: the ring is empty")
	P.gain_xp((float(Hunter.XP_TO[1]) - float(Hunter.XP_TO[0])) * 0.5)
	ok(P.lvl == 1 and absf(P.xp_frac() - 0.5) < 0.02, "half way to level 2: the ring is half full (%.2f)" % P.xp_frac())
	# ---------------------------------------------------------------- 3. a level-up: pop, gold flash, sound
	var ups0 := P.level_ups
	var last0: int = int(Sfx.last_played.get("level_up", -1000))
	hud.flash_t = 0.0; hud.lvl_pop = 0.0
	P.gain_xp(float(Hunter.XP_TO[1]) - P.xp + 1.0)
	ok(P.lvl == 2 and P.level_ups == ups0 + 1, "level 2 reached: the level-up moment plays once")
	ok(hud.lvl_pop > 0.0, "the portrait's badge pops (%.2f)" % hud.lvl_pop)
	ok(hud.flash_t > 0.5 and hud.flash_col.g > hud.flash_col.b and hud.flash_col.a > 0.05, "the screen washes gold (%s)" % str(hud.flash_col))
	ok(int(Sfx.last_played.get("level_up", -1000)) > last0, "the level-up sound plays")
	# two levels in one go: each counts
	P.gain_xp(float(Hunter.XP_TO[3]) - P.xp + 1.0)
	ok(P.lvl == 4 and P.level_ups == ups0 + 3, "a big XP grant over two levels plays it for each (%d)" % (P.level_ups - ups0))
	# a bot levelling up makes no noise on your screen
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var bu := B.level_ups
	B.gain_xp(500.0)
	ok(B.level_ups == bu and B.lvl > 1, "a rival levelling up (to %d) doesn't flash your screen" % B.lvl)
	# ---------------------------------------------------------------- 4. R locked until level 6
	P.lvl = 5; P.xp = float(Hunter.XP_TO[4]); P.skill_pts = 2
	ok(not P.can_level("ult") and int(P.slot_lv["ult"]) == 0, "level 5: R can't be unlocked yet")
	P.ult = 1.0
	P.ak.use_r()
	ok(P.ak.r_t <= 0.0 and float(P.ak.cd["r"]) <= 0.0, "pressing R at level 5 casts nothing")
	ok(hud.r_lock_text(P) == "LV %d" % int(Hunter.ULT_AT[0]), "the R slot says when it opens: '%s'" % hud.r_lock_text(P))
	P.gain_xp(float(Hunter.XP_TO[5]) - P.xp + 1.0)
	ok(P.lvl == 6 and P.can_level("ult") and hud.r_lock_text(P) == "UNLOCK", "level 6: R is ready to unlock ('%s')" % hud.r_lock_text(P))
	P.level_slot("ult")
	ok(int(P.slot_lv["ult"]) == 1 and hud.r_lock_text(P) == "", "unlocked: no lock on R any more")
	print("LEVEL HUD CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
