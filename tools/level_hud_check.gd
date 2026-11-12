extends RefCounted
## --level-hud-check: the run level reads at a glance. A level badge sits by the XP bar that fills
## toward the next level; a level-up pops the badge, washes the screen gold and
## plays its own sound (audio/level_up.wav, made by tools/gen_sfx_ui.py); R shows locked (a
## padlock and "6") until level 6, and can't be cast or ranked before then; the vitals and ability row
## keep the sizes measured from the owner's reference. Never touches the save.

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
	# ---------------------------------------------------------------- 5. the measured layout (scripts/ui/HUD_SPEC.md)
	# reference px (game picture 2000 wide, top at y 108) to layout px: x 0.64, y (y - 108) * 0.64
	var near := func(ours: float, ref_px: float, what: String) -> void:
		ok(absf(ours - ref_px * 0.64) <= 1.5, "%s: %.1f, reference %.1f" % [what, ours, ref_px * 0.64])
	near.call(HudVitals.HP_H, 24.0, "health bar height")
	near.call(HudVitals.HP_Y, 1115.0 - 108.0, "health bar top")
	near.call(HudVitals.SLOT, 57.0, "ability slot size")
	near.call(HudVitals.SLOT + HudVitals.SLOT_GAP, 69.0, "ability slot pitch")
	near.call(HudVitals.SLOT_X, 407.0, "first ability slot x")
	near.call(HudVitals.SLOT_Y, 1127.0 - 108.0, "ability slots top")
	near.call(hud.MM_D, 262.0, "minimap size")
	near.call(HudVitals.XP_Y, 1182.0 - 108.0, "XP bar top")
	ok(RankMarks.NUMERALS[3] == "III", "a rank shows as a numeral on the slot")
	# the weapon between the vitals and the ability row; the bottom-right row; the top-right counters
	near.call(WeaponHud.AT.x, 328.5, "weapon silhouette centre x")
	# the drawn rifle sits 3.5 px under AT (measured by tools/hud_measure.py)
	near.call(WeaponHud.AT.y + 3.5, 1148.0 - 108.0, "weapon silhouette centre y")
	var wpn_l := WeaponHud.AT.x - 0.9 * WeaponHud.ICON_S
	var wpn_r := WeaponHud.AT.x + 0.9 * WeaponHud.ICON_S
	ok(wpn_l > HudVitals.PLATE_X + HudVitals.PLATE_W and wpn_r < HudVitals.SLOT_X,
			"the weapon (x %.0f..%.0f) sits between the vitals plate and the first ability slot" % [wpn_l, wpn_r])
	near.call(BeltHud.SLOT, 41.0, "belt slot size")
	near.call(BeltHud.SLOT + BeltHud.GAP, 45.0, "belt slot pitch")
	near.call(BeltHud.BOTTOM, 1195.0 - 108.0, "bottom-right row's foot")
	near.call(GripHud.W, 55.0, "item card width")
	near.call(GripHud.H, 65.0, "item card height")
	near.call(GripHud.W + GripHud.GAP, 62.0, "item card pitch")
	near.call(ScoreRow.PITCH, 44.3, "top-right counter pitch")
	near.call(ScoreRow.CUR_Y, 144.0 - 108.0, "currency baseline")
	print("LEVEL HUD CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
