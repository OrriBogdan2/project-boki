extends RefCounted
## --kill-reset-check: the takedown refresh (DashReset, decision 0022). A hunter who knocks or kills an
## enemy hunter has their dash and the long-dash cooldown back at once and heals 5% of max health (never
## past max); a teammate who hit the victim in the last 4 s refreshes too (no heal, the softer "assist"
## cue), a stale or idle teammate doesn't; a 2-charge dash gains exactly one charge; a hero whose dash
## data opts out gets nothing; killing a mob changes nothing; a bot gets it too but only the local hunter
## gets the cue (ResetCue: the CombatBus.reset_cue event, the Shift flash and the sound); a knock on a
## teammate counts for nothing; the hero-specific resets fire the same event and flash the HUD slots
## content/rules/reset_cue.json names, a teammate's reset is silent; every ResetCue.play path in scripts/
## is in the rules and every rules path is used; the cue variants all exist and the setting picks between
## them. Never touches the save.

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
	m.start({"teams": 4, "squad": 3, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": false})
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
	CombatBus.reset_cue.connect(func(h, src): cues.append([h, src]))
	var f1: Hunter = foes[0]
	var f2: Hunter = foes[1]
	var mates: Array = m.hunters.filter(func(o): return o != P and o.team == P.team)
	ok(mates.size() >= 2 and foes.size() >= 6, "a squad of three (%d mates, %d rivals)" % [mates.size(), foes.size()])

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
		var bwant := 1.0 if bot.max_dashes() > 1.0 else bot.max_dashes()     # from empty: +1 charge, or the one
		ok(is_equal_approx(bot.dashes, bwant) and bot.hp > bhp and cues.size() == n0,
				"(e) a bot's takedown refreshes its dash (%.2f, want %.2f) and heals, with no cue (%d)"
				% [bot.dashes, bwant, cues.size() - n0])
	else:
		ok(false, "(e) no bot to test")

	# (f) a teammate or yourself counts for nothing
	_spend(P); P.hp = 100.0; n0 = cues.size()
	DashReset.takedown(P, P)
	ok(P.dashes < 0.5 and cues.size() == n0, "(f) no reset for a takedown on yourself")

	# (g) the hero resets give the same cue, on the HUD slots the rules name; a teammate's or rival's is silent
	n0 = cues.size()
	if m.hud: m.hud.slot_fx.clear()
	ResetCue.play(P, "ashwick_knock_ram")
	ResetCue.play(P, "ashwick_knock_e")
	ok(cues.size() == n0 + 2 and cues[-1][1] == "ashwick_knock_e", "(g) a hero-specific reset fires the same event")
	var flashed: Array = []
	if m.hud: flashed = m.hud.slot_fx.keys().filter(func(id): return m.hud.slot_fx[id]["kind"] == "reset")
	flashed.sort()
	ok(flashed == ["dash", "k1"], "(g) each flashes its own HUD slot (Shift and E: %s)" % str(flashed))
	ResetCue.play(mates[0], "takedown")
	ResetCue.play(bot if bot != null else f2, "takedown")
	ok(cues.size() == n0 + 2, "(g) and only for the local hunter")
	_paths_match()

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

	_assists(m, P, mates, foes)
	m.queue_free()
	print("KILLRESET DONE, failures: %d" % bad)
	main.get_tree().quit()

## (g) every literal ResetCue.play path in scripts/ is a rules path, and every rules path is played somewhere.
func _paths_match() -> void:
	var used := {"takedown": true, "assist": true}      # DashReset passes these two through a variable
	var stray: Array = []
	var re := RegEx.create_from_string("ResetCue\\.play\\([^,]+, \"([a-z0-9_]+)\"\\)")
	for path in _gd_files("res://scripts"):
		for hit in re.search_all(FileAccess.get_file_as_string(path)):
			used[hit.get_string(1)] = true
			if ResetCue.slots(hit.get_string(1)).is_empty(): stray.append(hit.get_string(1))
	var unused: Array = ResetCue.rules()["paths"].keys().filter(func(k): return not used.has(k))
	ok(used.size() >= 16 and stray.is_empty() and unused.is_empty(),
			"(g) the reset paths in code and in reset_cue.json match (%d; not in the rules %s, never played %s)"
			% [used.size(), stray, unused])

func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + "/" + d))
	return out

## (i)-(l) the assist rule, the one-charge rule for multi-charge dashes and the per-hero opt-out.
func _assists(m: Match, P: Hunter, mates: Array, foes: Array) -> void:
	var helper: Hunter = mates[0]
	var stale: Hunter = mates[1]
	var v: Hunter = foes[-1]
	for h in [P, helper, stale]: _spend(h)
	P.hp = 100.0
	v.hurt(1.0, helper, {"src": "test"})
	v.hurt(1.0, stale, {"src": "test"})
	v.hit_by[stale.get_instance_id()] = m.time - DashReset.ASSIST_WINDOW - 1.0
	m.knock(v, P, {})
	var want := helper.max_dashes() if helper.max_dashes() <= 1.0 else 1.0
	ok(v.downed and P.dashes >= P.max_dashes() - 0.001 and P.ex_cd == 0.0,
			"(i) the knocker refreshes (%.2f)" % P.dashes)
	ok(is_equal_approx(helper.dashes, want) and helper.ex_cd == 0.0,
			"(i) the teammate who hit the victim refreshes (%.2f, want %.2f)" % [helper.dashes, want])
	ok(stale.dashes < 0.01 and stale.ex_cd > 4.0,
			"(i) a teammate whose hit is older than the window does not (%.2f)" % stale.dashes)

	# (j) the local hunter as the assister: the softer cue, no heal
	var v2: Hunter = foes[-2]
	_spend(P)
	P.hp = 100.0
	v2.hurt(1.0, P, {"src": "test"})
	var n0 := cues.size()
	m.knock(v2, helper, {})
	ok(P.dashes > 0.99 and is_equal_approx(P.hp, 100.0),
			"(j) an assist refreshes the local hunter, no heal (%.2f, hp %.1f)" % [P.dashes, P.hp])
	ok(cues.size() == n0 + 1 and cues[-1][1] == "assist", "(j) with the assist cue (%s)" % str(cues.slice(n0)))

	# (k) a 2-charge dash gains exactly one charge
	if P.max_dashes() < 2.0: P.perks.append("secondwind")
	var v3: Hunter = foes[-3]
	_spend(P)
	P.dashes = 0.3
	m.knock(v3, P, {})
	ok(P.max_dashes() >= 2.0 and is_equal_approx(P.dashes, 1.3),
			"(k) a %d-charge dash gains one charge (0.3 -> %.2f)" % [int(P.max_dashes()), P.dashes])

	# (l) a hero whose dash data opts out gets nothing
	var dd: Dictionary = P.ak.dash_def() if P.ak else {}
	ok(P.ak != null, "(l) the local hunter has a kit")
	dd["knock_refresh"] = false
	_spend(P)
	m.knock(foes[-4], P, {})
	dd.erase("knock_refresh")
	ok(P.dashes < 0.01 and P.ex_cd > 4.0, "(l) knock_refresh: false opts out (%.2f)" % P.dashes)
