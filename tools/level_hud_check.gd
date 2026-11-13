extends RefCounted
## --level-hud-check: the run level reads at a glance and a level-up is one clear moment. The XP tracker
## (HudVitals.xp_row) shows the level number and a bar that fills toward the next level, with a pop when
## XP lands (once per gain) and a gold pulse while a skill point can be ranked. A level-up turns the
## number gold, plays its own sound (audio/level_up.wav, tools/gen_sfx_ui.py) and opens LevelUpCue: a gold
## column over your hero and a short card over the vitals saying what improved, gone in under 3 s.
## No toast in the message lane and no screen wash. R shows locked (a padlock and "6") until level 6, and
## can't be cast or ranked before then. Never touches the save.

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
	# ---------------------------------------------------------------- 2. XP bar follows the level's progress
	P.lvl = 1; P.xp = 0.0; P.skill_pts = 1
	for s in Hunter.SLOTS: P.slot_lv[s] = 0
	hud.xp_seen = -1.0
	hud.xp_shown = -1.0
	hud.xp_pop = 0.0
	ok(HudVitals.xp_step(hud, P, 10.0) == 0.0 and hud.xp_pop <= 0.0, "level 1, no XP: the bar is empty, no pop")
	P.gain_xp((float(Hunter.XP_TO[1]) - float(Hunter.XP_TO[0])) * 0.5)
	ok(P.lvl == 1 and absf(P.xp_frac() - 0.5) < 0.02, "half way to level 2: half full (%.2f)" % P.xp_frac())
	var fr := HudVitals.xp_step(hud, P, 0.0)
	ok(hud.xp_pop > 0.0 and fr < 0.5, "XP landing pops once, the bar starts to fill (%.2f)" % fr)
	hud.xp_pop = 0.0
	fr = HudVitals.xp_step(hud, P, 10.0)
	ok(absf(fr - 0.5) < 0.02 and hud.xp_pop <= 0.0, "settled at half (%.2f), no pop without new XP" % fr)
	P.gain_xp(7.0)
	HudVitals.xp_step(hud, P, 0.0)
	ok(hud.xp_pop > 0.0, "a second gain pops again")
	hud.xp_pop = 0.0
	fr = HudVitals.xp_step(hud, P, 10.0)
	ok(absf(fr - P.xp_frac()) < 0.005, "the bar matches xp_frac after a second gain (%.3f)" % fr)
	# ---------------------------------------------------------------- 3. a level-up: pop, sound, the card
	var ups0 := P.level_ups
	var last0: int = int(Sfx.last_played.get("level_up", -1000))
	hud.flash_t = 0.0; hud.lvl_pop = 0.0
	hud.msgs.clear()
	P.gain_xp(float(Hunter.XP_TO[1]) - P.xp + 1.0)
	var cue: LevelUpCue = hud.lvl_cue
	ok(P.lvl == 2 and P.level_ups == ups0 + 1, "level 2 reached: the level-up moment plays once")
	ok(hud.lvl_pop > 0.0, "the level number pops gold (%.2f)" % hud.lvl_pop)
	ok(int(Sfx.last_played.get("level_up", -1000)) > last0, "the level-up sound plays")
	ok(cue.t == LevelUpCue.LIFE and cue.lines[0] == "LEVEL 2", "the level-up card opens: %s" % str(cue.lines))
	var grew := String(cue.lines[1])
	ok(grew.contains("+6% health") and grew.contains("+5% ability power"), "it says what grew: '%s'" % grew)
	ok(String(cue.lines[2]).contains("2 points to spend"), "and what there is to spend: '%s'" % cue.lines[2])
	ok(LevelUpCue.LIFE <= 3.0 and LevelUpCue.BODY <= 1.0, "it is brief: card %.1f s, column %.1f s" % [LevelUpCue.LIFE, LevelUpCue.BODY])
	ok(hud.flash_t <= 0.0, "no screen wash")
	ok(hud.msgs.texts().is_empty(), "no toast in the message lane (%s)" % str(hud.msgs.texts()))
	HudVitals.xp_step(hud, P, 0.0)
	var lt := HudVitals.lvl_text(P)
	ok(hud.xp_pop > 0.0 and lt == "2", "the level text is '%s' and the gain popped" % lt)
	fr = HudVitals.xp_step(hud, P, 10.0)
	ok(absf(fr - P.xp_frac()) < 0.005 and P.lvl == 2, "after a level-up the bar shows the new fraction (%.2f)" % fr)
	# two levels in one go: each counts
	P.gain_xp(float(Hunter.XP_TO[3]) - P.xp + 1.0)
	ok(P.lvl == 4 and P.level_ups == ups0 + 3 and cue.lines[0] == "LEVEL 4",
		"a big XP grant over two levels plays it for each (%d), the card shows the last" % (P.level_ups - ups0))
	# a bot levelling up makes no noise on your screen
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var bu := B.level_ups
	cue.t = 0.0
	B.gain_xp(500.0)
	ok(B.level_ups == bu and B.lvl > 1 and cue.t == 0.0, "a rival levelling up (to %d) shows you nothing" % B.lvl)
	# ---------------------------------------------------------------- 4. R locked until level 6
	P.lvl = 5; P.xp = float(Hunter.XP_TO[4]); P.skill_pts = 2
	ok(not P.can_level("ult") and int(P.slot_lv["ult"]) == 0, "level 5: R can't be unlocked yet")
	P.ult = 1.0
	P.ak.use_r()
	ok(P.ak.r_t <= 0.0 and float(P.ak.cd["r"]) <= 0.0, "pressing R at level 5 casts nothing")
	ok(hud.r_lock_text(P) == "LV %d" % int(Hunter.ULT_AT[0]), "the R slot says when it opens: '%s'" % hud.r_lock_text(P))
	P.gain_xp(float(Hunter.XP_TO[5]) - P.xp + 1.0)
	ok(P.lvl == 6 and P.can_level("ult") and hud.r_lock_text(P) == "UNLOCK", "level 6: R is ready to unlock ('%s')" % hud.r_lock_text(P))
	ok(String(cue.lines[2]).contains("ultimate open"), "the level 6 card says the ultimate opened: '%s'" % cue.lines[2])
	P.level_slot("ult")
	ok(int(P.slot_lv["ult"]) == 1 and hud.r_lock_text(P) == "", "unlocked: no lock on R any more")
	print("LEVEL HUD CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
