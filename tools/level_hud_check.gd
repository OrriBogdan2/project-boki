extends RefCounted
## --level-hud-check: the run level reads at a glance. The XP tracker (HudVitals.xp_row) shows the
## level number and a bar that fills toward the next level, with a pop when XP lands (once per gain)
## and a gold pulse while a skill point can be ranked; a level-up pops the number, washes the screen gold and
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
	var p: Hunter = m.player
	for o in m.hunters:
		if o != p: o.ctrl = "idle"; o.teleport(m.world.spawns[-1])
	p.ctrl = "local"      # (the level-up moment is the local player's)
	p.inp["move"] = Vector2.ZERO
	var hud = m.hud
	ok(hud != null and p.ak != null, "a match with a HUD and an archetype (%s)" % p.arch)
	# ---------------------------------------------------------------- 1. the sound exists and is its own
	ok(Sfx.streams.has("level_up") and ResourceLoader.exists("res://audio/level_up.wav"), "the level-up sound is loaded (audio/level_up.wav)")
	# ---------------------------------------------------------------- 2. XP bar follows the level's progress
	p.lvl = 1; p.xp = 0.0; p.skill_pts = 1
	for s in Hunter.SLOTS: p.slot_lv[s] = 0
	hud.xp_seen = -1.0
	hud.xp_shown = -1.0
	hud.xp_pop = 0.0
	ok(HudVitals.xp_step(hud, p, 10.0) == 0.0 and hud.xp_pop <= 0.0, "level 1, no XP: the bar is empty, no pop")
	p.gain_xp((float(Hunter.XP_TO[1]) - float(Hunter.XP_TO[0])) * 0.5)
	ok(p.lvl == 1 and absf(p.xp_frac() - 0.5) < 0.02, "half way to level 2: half full (%.2f)" % p.xp_frac())
	var fr := HudVitals.xp_step(hud, p, 0.0)
	ok(hud.xp_pop > 0.0 and fr < 0.5, "XP landing pops once, the bar starts to fill (%.2f)" % fr)
	hud.xp_pop = 0.0
	fr = HudVitals.xp_step(hud, p, 10.0)
	ok(absf(fr - 0.5) < 0.02 and hud.xp_pop <= 0.0, "settled at half (%.2f), no pop without new XP" % fr)
	p.gain_xp(7.0)
	HudVitals.xp_step(hud, p, 0.0)
	ok(hud.xp_pop > 0.0, "a second gain pops again")
	hud.xp_pop = 0.0
	fr = HudVitals.xp_step(hud, p, 10.0)
	ok(absf(fr - p.xp_frac()) < 0.005, "the bar matches xp_frac after a second gain (%.3f)" % fr)
	# ---------------------------------------------------------------- 3. a level-up: pop, gold flash, sound
	var ups0 := p.level_ups
	var last0: int = int(Sfx.last_played.get("level_up", -1000))
	hud.flash_t = 0.0; hud.lvl_pop = 0.0
	p.gain_xp(float(Hunter.XP_TO[1]) - p.xp + 1.0)
	ok(p.lvl == 2 and p.level_ups == ups0 + 1, "level 2 reached: the level-up moment plays once")
	ok(hud.lvl_pop > 0.0, "the portrait's badge pops (%.2f)" % hud.lvl_pop)
	ok(hud.flash_t > 0.5 and hud.flash_col.g > hud.flash_col.b and hud.flash_col.a > 0.05, "the screen washes gold (%s)" % str(hud.flash_col))
	ok(int(Sfx.last_played.get("level_up", -1000)) > last0, "the level-up sound plays")
	HudVitals.xp_step(hud, p, 0.0)
	var lt := HudVitals.lvl_text(p)
	ok(hud.xp_pop > 0.0 and lt == "2", "the level text is '%s' and the gain popped" % lt)
	fr = HudVitals.xp_step(hud, p, 10.0)
	ok(absf(fr - p.xp_frac()) < 0.005 and p.lvl == 2, "after a level-up the bar shows the new fraction (%.2f)" % fr)
	# two levels in one go: each counts
	p.gain_xp(float(Hunter.XP_TO[3]) - p.xp + 1.0)
	ok(p.lvl == 4 and p.level_ups == ups0 + 3, "a big XP grant over two levels plays it for each (%d)" % (p.level_ups - ups0))
	# a bot levelling up makes no noise on your screen
	var b_v: Hunter = m.hunters.filter(func(x): return x != p)[0]
	var bu := b_v.level_ups
	b_v.gain_xp(500.0)
	ok(b_v.level_ups == bu and b_v.lvl > 1, "a rival levelling up (to %d) doesn't flash your screen" % b_v.lvl)
	# ---------------------------------------------------------------- 4. R locked until level 6
	p.lvl = 5; p.xp = float(Hunter.XP_TO[4]); p.skill_pts = 2
	ok(not p.can_level("ult") and int(p.slot_lv["ult"]) == 0, "level 5: R can't be unlocked yet")
	p.ult = 1.0
	p.ak.use_r()
	ok(p.ak.r_t <= 0.0 and float(p.ak.cd["r"]) <= 0.0, "pressing R at level 5 casts nothing")
	ok(hud.r_lock_text(p) == "LV %d" % int(Hunter.ULT_AT[0]), "the R slot says when it opens: '%s'" % hud.r_lock_text(p))
	p.gain_xp(float(Hunter.XP_TO[5]) - p.xp + 1.0)
	ok(p.lvl == 6 and p.can_level("ult") and hud.r_lock_text(p) == HudSlot.POINT_TAG, "level 6: R is ready to unlock ('%s')" % hud.r_lock_text(p))
	p.level_slot("ult")
	ok(int(p.slot_lv["ult"]) == 1 and hud.r_lock_text(p) == "", "unlocked: no lock on R any more")
	# ---------------------------------------------------------------- 5. no XP for time or for damage
	p.lvl = 1
	p.xp = 0.0
	p.armor_xp = 0.0
	p.armor_tier = 0
	for i in 1800:
		m.step(1.0 / 30.0)
	ok(p.xp == 0.0 and p.lvl == 1, "60 s standing still gives no XP (%.1f)" % p.xp)
	b_v.downed = false
	b_v.hp = b_v.max_hp
	m.on_damage(b_v, p, 30.0, {})
	if not m.mobs.is_empty():
		m.on_damage(m.mobs[0], p, 30.0, {})
	ok(p.xp == 0.0 and p.lvl == 1, "a damage-only fight gives no XP (%.1f)" % p.xp)
	ok(p.armor_xp >= 30.0, "damage to a Hunter still builds armour (%.1f)" % p.armor_xp)
	# ---------------------------------------------------------------- 6. the new point's chime follows the level-up's
	RankMarks.watch(hud)
	var heard := str(RankSfx.heard)
	p.gain_xp(float(Hunter.XP_TO[p.lvl]) - p.xp + 1.0)
	RankMarks.watch(hud)
	var after := RankSfx.ready_at - float(m.time)
	ok(is_equal_approx(after, RankSfx.READY_DELAY) and str(RankSfx.heard) == heard,
		"level %d: the point's chime waits %.1f s, so the level-up chime plays alone" % [p.lvl, after])
	RankSfx.ready_at = -1.0
	b_v.gain_xp(float(Hunter.XP_TO[b_v.lvl]) - b_v.xp + 1.0)
	RankMarks.watch(hud)
	ok(RankSfx.ready_at < 0.0 and str(RankSfx.heard) == heard, "a rival's level-up and ranks make no rank sound")
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
	var p: Hunter = m.player
	var base_hp := float(p.cdat["hp"])
	var dmg0 := float(p.wpn["dmg"])
	var step_ok := true
	var info := ""
	for lvl in range(2, Hunter.XP_TO.size() + 1):
		var hp0 := p.max_hp
		var ap0 := LevelGrowth.ap(p)
		p.gain_xp(float(Hunter.XP_TO[lvl - 1]) - p.xp + 0.5)
		var k := 1.0 if lvl < 7 else 0.5
		if absf((p.max_hp - hp0) - base_hp * 0.06 * k) > 0.05 or absf((LevelGrowth.ap(p) - ap0) - 0.05 * k) > 0.0001:
			step_ok = false
			info += "L%d hp+%.2f ap+%.3f " % [lvl, p.max_hp - hp0, LevelGrowth.ap(p) - ap0]
	var hp_up := p.max_hp / base_hp - 1.0
	var tip := LevelGrowth.tip(p)
	ok(step_ok and p.lvl == 10, "%s: levels 2-6 add 6%% health, 5%% ability power; 7-10 half %s" % [arch, info])
	ok(absf(hp_up - 0.42) < 0.001 and absf(LevelGrowth.ap(p) - 1.35) < 0.0001,
		"%s: by level 10: +%.0f%% health, ability power x%.2f" % [arch, hp_up * 100.0, LevelGrowth.ap(p)])
	ok(p.perks.is_empty() and is_equal_approx(float(p.wpn["dmg"]), dmg0),
		"%s: levels give no weapon bonus (no perks, damage unchanged)" % arch)
	ok(p.skill_pts == 10, "%s: one skill point a level (%d)" % [arch, p.skill_pts])
	ok(tip.contains("+42% max health") and tip.contains("+35% ability power"),
		"%s: the level badge tooltip shows the totals (%s)" % [arch, tip])
	p.reclass(p.cls, p.arch)
	ok(absf(p.max_hp - (base_hp * 1.42 + p.kin_hp_added)) < 0.5,
		"%s: a class change keeps the levels' health (%.1f)" % [arch, p.max_hp])
	m.queue_free()
