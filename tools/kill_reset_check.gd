extends RefCounted
## --kill-reset-check: the takedown reset (DashReset). A hunter who knocks or kills an enemy hunter has
## every dash charge and the long-dash cooldown back at once and heals 5% of max health (never past
## max); killing a mob changes nothing; a bot gets it too but only the local hunter gets the cue (the
## CombatBus.dash_reset_cue event, the Shift icon pop and the sound); a knock on a teammate counts for
## nothing; the hero-specific resets (DashReset.cue) fire the same event; the cue variants all exist and
## the setting picks between them. Never touches the save.

var bad := 0
var cues: Array = []

func ok(cond: bool, what: String) -> void:
	print("KILLRESET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _spend(h: Hunter) -> void:
	h.dashes = 0.0
	h.ex_cd = 5.0

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip"); d["roster"].append(rec); d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var foes: Array = m.hunters.filter(func(o): return o != P and o.team != P.team)
	ok(foes.size() >= 2, "a match with at least two rival hunters (%d)" % foes.size())
	for o in m.hunters:
		if o != P: o.ctrl = "idle"
	var far := m.world.random_ground()
	for o in m.hunters:
		if o != P: o.teleport(far)
	CombatBus.dash_reset_cue.connect(func(h, src): cues.append([h, src]))
	var f1: Hunter = foes[0]
	var f2: Hunter = foes[1]

	# (a) a knock: every dash charge, the long-dash cooldown, +5% health, and the cue for the local hunter
	P.max_hp = 200.0; P.hp = 100.0
	P.lvl = Hunter.XP_TO.size()      # (at the level cap: a takedown's XP can't level you, so quiet growth stays out of the numbers)
	_spend(P)
	m.knock(f1, P, {})
	ok(f1.downed, "(a) the rival is down")
	ok(P.dashes >= P.max_dashes() - 0.001 and P.max_dashes() >= 1.0, "(a) the knock brings back every dash charge (%.2f / %.2f)" % [P.dashes, P.max_dashes()])
	ok(P.ex_cd == 0.0, "(a) the long-dash cooldown is cleared")
	ok(absf(P.hp - (100.0 + 200.0 * DashReset.HEAL)) < 0.01, "(a) +5%% of max health (%.1f, want 110)" % P.hp)
	ok(cues.size() == 1 and cues[0][0] == P and cues[0][1] == "takedown", "(a) the reset cue event fired once for the local hunter (%d)" % cues.size())

	# (b) the heal never passes max health
	P.hp = P.max_hp - 3.0
	_spend(P)
	m.knock(f2, P, {})
	ok(is_equal_approx(P.hp, P.max_hp) and P.dashes >= P.max_dashes() - 0.001, "(b) near full health the heal stops at max (%.1f / %.1f)" % [P.hp, P.max_hp])

	# (c) finishing the downed rival is a kill: the reset again
	P.hp = 100.0; _spend(P)
	var n0 := cues.size()
	m.eliminate(f1, P, "shot", true)
	ok(f1.out and P.kills >= 1, "(c) the kill is credited")
	ok(P.dashes >= P.max_dashes() - 0.001 and absf(P.hp - 110.0) < 0.01 and cues.size() == n0 + 1, "(c) a kill resets and heals too (dashes %.2f, hp %.1f)" % [P.dashes, P.hp])

	# (d) a mob kill does nothing
	var mob := m.spawn_mob("skitter", P.pos + Vector3(3, 0, 0))
	P.hp = 100.0; _spend(P)
	n0 = cues.size()
	mob.hurt(mob.max_hp * 10.0, P, {"src": "test"})
	for i in 5: m.step(Match.DT)
	ok(mob.dead, "(d) the mob is dead")
	ok(P.dashes < 0.5 and P.ex_cd > 4.0 and P.hp < 101.0 and cues.size() == n0, "(d) killing a mob does not reset or heal (dashes %.2f, ex_cd %.1f, hp %.1f)" % [P.dashes, P.ex_cd, P.hp])

	# (e) a bot's takedown resets it, but no cue (not the local hunter)
	var bot: Hunter = null
	for o in m.hunters:
		if o != P and not o.out and not o.downed and o.team != P.team and o != f1 and o != f2 and bot == null:
			bot = o
	if bot == null: bot = foes[2] if foes.size() > 2 else null
	if bot != null:
		var victim: Hunter = P
		var team2: Array = m.hunters.filter(func(o): return o != bot and o != P and o.team != bot.team and not o.downed and not o.out)
		if not team2.is_empty(): victim = team2[0]
		bot.hp = bot.max_hp * 0.5; _spend(bot)
		var bhp := bot.hp
		n0 = cues.size()
		DashReset.takedown(bot, victim)
		ok(bot.dashes >= bot.max_dashes() - 0.001 and bot.hp > bhp and cues.size() == n0, "(e) a bot's takedown resets its dash and heals, with no cue (%d)" % (cues.size() - n0))
	else:
		ok(false, "(e) no bot to test")

	# (f) a teammate or yourself counts for nothing
	_spend(P); P.hp = 100.0; n0 = cues.size()
	DashReset.takedown(P, P)
	ok(P.dashes < 0.5 and cues.size() == n0, "(f) no reset for a takedown on yourself")

	# (g) the hero resets give the same cue
	n0 = cues.size()
	DashReset.cue(P)
	ok(cues.size() == n0 + 1 and cues[-1][1] == "hero", "(g) a hero-specific reset fires the same event")
	DashReset.cue(bot if bot != null else f2)
	ok(cues.size() == n0 + 1, "(g) and only for the local hunter")

	# (h) the variants: three streams, the setting picks one, default a
	ok(Settings.DEFAULTS["reset_cue"] == "a", "(h) the default variant is a")
	var all_there := true
	for v in Sfx.RESET_CUES:
		if not Sfx.has("reset_" + v): all_there = false
	ok(all_there and Sfx.RESET_CUES.size() == 3, "(h) reset_a, reset_b and reset_c are loaded")
	var secs := {}
	for v in Sfx.RESET_CUES:
		var st: AudioStream = Sfx.streams["reset_" + v]
		secs[v] = st.get_length()
	ok(secs.values().all(func(s): return s >= 0.4 and s <= 0.65), "(h) each is 0.4 to 0.65 s long (%s)" % str(secs))
	var hud_pop := false
	if m.hud:
		m.hud.ability_feedback("dash", "reset")
		hud_pop = String(m.hud.slot_fx.get("dash", {}).get("kind", "")) == "reset"
	ok(hud_pop, "(h) the HUD holds the Shift pop")

	m.queue_free()
	print("KILLRESET DONE, failures: %d" % bad)
	main.get_tree().quit()
