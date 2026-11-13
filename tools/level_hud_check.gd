extends RefCounted
## --level-hud-check: the run level reads at a glance. The portrait carries a big level number with
## an XP ring that fills toward the next level; a level-up pops the badge, washes the screen gold and
## plays its own sound (audio/level_up.wav, made by tools/gen_sfx_ui.py); R shows locked (a
## padlock and "6") until level 6, and can't be cast or ranked before then. Each level also grows max
## health and ability power quietly (LevelGrowth, as the source does) and nothing else: no weapon
## bonuses. Never touches the save.

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
	m.queue_free()
	await _growth(main, "thief")
	await _growth(main, "juggernaut")
	print("LEVEL HUD CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## ---------------------------------------------------------------- 5. what each level gives
## Level by level: +6% of the class's health and +5% ability power (levels 2-6), half that from 7;
## the weapon and its upgrades never change; the tooltip and a class change agree with the totals.
func _growth(main: Node, arch: String) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 13, "no_drop": true,
		"arch": arch, "cls": Arch.weight(arch), "weapon": Arch.signature(arch)})
	m.set_process(false)
	var P: Hunter = m.player
	var base_hp := float(P.cdat["hp"])
	var dmg0 := float(P.wpn["dmg"])
	var step_ok := true
	var info := ""
	for lvl in range(2, Hunter.XP_TO.size() + 1):
		var hp0 := P.max_hp
		var ap0 := LevelGrowth.ap(P)
		P.gain_xp(float(Hunter.XP_TO[lvl - 1]) - P.xp + 0.5)
		var k := 1.0 if lvl < 7 else 0.5
		if absf((P.max_hp - hp0) - base_hp * 0.06 * k) > 0.05 or absf((LevelGrowth.ap(P) - ap0) - 0.05 * k) > 0.0001:
			step_ok = false
			info += "L%d hp+%.2f ap+%.3f " % [lvl, P.max_hp - hp0, LevelGrowth.ap(P) - ap0]
	var hp_up := P.max_hp / base_hp - 1.0
	var tip := LevelGrowth.tip(P)
	ok(step_ok and P.lvl == 10, "%s: levels 2-6 add 6%% health, 5%% ability power; 7-10 half %s" % [arch, info])
	ok(absf(hp_up - 0.42) < 0.001 and absf(LevelGrowth.ap(P) - 1.35) < 0.0001,
		"%s: by level 10: +%.0f%% health, ability power x%.2f" % [arch, hp_up * 100.0, LevelGrowth.ap(P)])
	ok(P.perks.is_empty() and is_equal_approx(float(P.wpn["dmg"]), dmg0),
		"%s: levels give no weapon bonus (no perks, damage unchanged)" % arch)
	ok(P.skill_pts == 10, "%s: one skill point a level (%d)" % [arch, P.skill_pts])
	ok(tip.contains("+42% max health") and tip.contains("+35% ability power"),
		"%s: the level badge tooltip shows the totals (%s)" % [arch, tip])
	P.reclass(P.cls, P.arch)
	ok(absf(P.max_hp - (base_hp * 1.42 + P.kin_hp_added)) < 0.5,
		"%s: a class change keeps the levels' health (%.1f)" % [arch, P.max_hp])
	m.queue_free()
