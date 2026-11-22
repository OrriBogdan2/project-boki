extends RefCounted
## --kill-reset-check: the takedown refresh (DashReset, decision 0022). A hunter who knocks or kills an
## enemy hunter has their dash and the long-dash cooldown back at once and heals 5% of max health (never
## past max); a teammate who hit the victim in the last 4 s refreshes too (no heal, the softer "assist"
## cue), a stale or idle teammate doesn't; a 2-charge dash gains exactly one charge; a hero whose dash
## data opts out gets nothing; killing a mob changes nothing; a bot gets it too but only the local hunter
## gets the cue (the CombatBus.dash_reset_cue event, the Shift icon pop and the sound); a knock on a teammate counts for
## nothing; the hero-specific resets (DashReset.cue) fire the same event; the cue variants all exist and
## the setting picks between them. A knock you land or take is a short freeze with no slow-mo and no
## full-screen flash (docs/DASHES_AND_ABILITY_FEEL.md §5.4, knock moment). Never touches the save.

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
	var p: Hunter = m.player
	var foes: Array = m.hunters.filter(func(o): return o != p and o.team != p.team)
	ok(foes.size() >= 2, "a match with at least two rival hunters (%d)" % foes.size())
	for o in m.hunters:
		if o != p: o.ctrl = "idle"
	var far := m.world.random_ground()
	for o in m.hunters:
		if o != p: o.teleport(far)
	CombatBus.dash_reset_cue.connect(func(h, src): cues.append([h, src]))
	var f1: Hunter = foes[0]
	var f2: Hunter = foes[1]
	var mates: Array = m.hunters.filter(func(o): return o != p and o.team == p.team)
	ok(mates.size() >= 2 and foes.size() >= 6, "a squad of three (%d mates, %d rivals)" % [mates.size(), foes.size()])

	# (a) a knock: every dash charge, the long-dash cooldown, +5% health, and the cue for the local hunter
	p.max_hp = 200.0; p.hp = 100.0
	p.lvl = Hunter.XP_TO.size()      # (at the level cap: a takedown's XP can't level you, so quiet growth stays out of the numbers)
	_spend(p)
	m.knock(f1, p, {})
	ok(f1.downed, "(a) the rival is down")
	ok(p.dashes >= p.max_dashes() - 0.001 and p.max_dashes() >= 1.0, "(a) the knock brings back every dash charge (%.2f / %.2f)" % [p.dashes, p.max_dashes()])
	ok(p.ex_cd == 0.0, "(a) the long-dash cooldown is cleared")
	ok(absf(p.hp - (100.0 + 200.0 * DashReset.HEAL)) < 0.01, "(a) +5%% of max health (%.1f, want 110)" % p.hp)
	ok(cues.size() == 1 and cues[0][0] == p and cues[0][1] == "takedown", "(a) the reset cue event fired once for the local hunter (%d)" % cues.size())
	_knock_beat(m, "(a) a knock you land", true)

	# (b) the heal never passes max health
	p.hp = p.max_hp - 3.0
	_spend(p)
	m.knock(f2, p, {})
	ok(is_equal_approx(p.hp, p.max_hp) and p.dashes >= p.max_dashes() - 0.001, "(b) near full health the heal stops at max (%.1f / %.1f)" % [p.hp, p.max_hp])

	# (c) finishing the downed rival is a kill: the reset again
	p.hp = 100.0; _spend(p)
	var n0 := cues.size()
	m.eliminate(f1, p, "shot", true)
	ok(f1.out and p.kills >= 1, "(c) the kill is credited")
	ok(p.dashes >= p.max_dashes() - 0.001 and absf(p.hp - 110.0) < 0.01 and cues.size() == n0 + 1, "(c) a kill resets and heals too (dashes %.2f, hp %.1f)" % [p.dashes, p.hp])

	# (d) a mob kill does nothing
	var mob := m.spawn_mob("skitter", p.pos + Vector3(3, 0, 0))
	p.hp = 100.0; _spend(p)
	n0 = cues.size()
	mob.hurt(mob.max_hp * 10.0, p, {"src": "test"})
	for i in 5: m.step(Match.DT)
	ok(mob.dead, "(d) the mob is dead")
	ok(p.dashes < 0.5 and p.ex_cd > 4.0 and p.hp < 101.0 and cues.size() == n0, "(d) killing a mob does not reset or heal (dashes %.2f, ex_cd %.1f, hp %.1f)" % [p.dashes, p.ex_cd, p.hp])

	# (e) a bot's takedown resets it, but no cue (not the local hunter)
	var bot: Hunter = null
	for o in m.hunters:
		if o != p and not o.out and not o.downed and o.team != p.team and o != f1 and o != f2 and bot == null:
			bot = o
	if bot == null: bot = foes[2] if foes.size() > 2 else null
	if bot != null:
		var victim: Hunter = p
		var team2: Array = m.hunters.filter(func(o): return o != bot and o != p and o.team != bot.team and not o.downed and not o.out)
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
	_spend(p); p.hp = 100.0; n0 = cues.size()
	DashReset.takedown(p, p)
	ok(p.dashes < 0.5 and cues.size() == n0, "(f) no reset for a takedown on yourself")

	# (g) the hero resets give the same cue
	n0 = cues.size()
	DashReset.cue(p)
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

	_assists(m, p, mates, foes)
	m.queue_free()
	print("KILLRESET DONE, failures: %d" % bad)
	main.get_tree().quit()

## (i)-(l) the assist rule, the one-charge rule for multi-charge dashes and the per-hero opt-out.
func _assists(m: Match, p: Hunter, mates: Array, foes: Array) -> void:
	var helper: Hunter = mates[0]
	var stale: Hunter = mates[1]
	var v: Hunter = foes[-1]
	for h in [p, helper, stale]: _spend(h)
	p.hp = 100.0
	v.hurt(1.0, helper, {"src": "test"})
	v.hurt(1.0, stale, {"src": "test"})
	v.hit_by[stale.get_instance_id()] = m.time - DashReset.ASSIST_WINDOW - 1.0
	m.knock(v, p, {})
	var want := helper.max_dashes() if helper.max_dashes() <= 1.0 else 1.0
	ok(v.downed and p.dashes >= p.max_dashes() - 0.001 and p.ex_cd == 0.0,
			"(i) the knocker refreshes (%.2f)" % p.dashes)
	ok(is_equal_approx(helper.dashes, want) and helper.ex_cd == 0.0,
			"(i) the teammate who hit the victim refreshes (%.2f, want %.2f)" % [helper.dashes, want])
	ok(stale.dashes < 0.01 and stale.ex_cd > 4.0,
			"(i) a teammate whose hit is older than the window does not (%.2f)" % stale.dashes)

	# (j) the local hunter as the assister: the softer cue, no heal
	var v2: Hunter = foes[-2]
	_spend(p)
	p.hp = 100.0
	v2.hurt(1.0, p, {"src": "test"})
	var n0 := cues.size()
	m.knock(v2, helper, {})
	ok(p.dashes > 0.99 and is_equal_approx(p.hp, 100.0),
			"(j) an assist refreshes the local hunter, no heal (%.2f, hp %.1f)" % [p.dashes, p.hp])
	ok(cues.size() == n0 + 1 and cues[-1][1] == "assist", "(j) with the assist cue (%s)" % str(cues.slice(n0)))

	# (k) a 2-charge dash gains exactly one charge (the kit's dash.charges set to 2 for it)
	var dd: Dictionary = p.ak.dash_def() if p.ak else {}
	var had: Variant = dd.get("charges")
	dd["charges"] = 2
	var v3: Hunter = foes[-3]
	_spend(p)
	p.dashes = 0.3
	m.knock(v3, p, {})
	ok(p.max_dashes() >= 2.0 and is_equal_approx(p.dashes, 1.3),
			"(k) a %d-charge dash gains one charge (0.3 -> %.2f)" % [int(p.max_dashes()), p.dashes])
	_second_wind(m, p, foes[-5])
	if had == null: dd.erase("charges")
	else: dd["charges"] = had

	# (l) a hero whose dash data opts out gets nothing
	ok(p.ak != null, "(l) the local hunter has a kit")
	dd["knock_refresh"] = false
	_spend(p)
	m.knock(foes[-4], p, {})
	dd.erase("knock_refresh")
	ok(p.dashes < 0.01 and p.ex_cd > 4.0, "(l) knock_refresh: false opts out (%.2f)" % p.dashes)

	# (m) being knocked: no slow-mo, no full-screen flash either
	if m.hud: m.hud.flash_t = 0.0      # (c)'s kill flash; that one stays, only knocks lost theirs
	m.hitstop = 0.0
	m.knock(p, foes[-5], {})
	ok(p.downed, "(m) the local hunter is down")
	_knock_beat(m, "(m) being knocked", false)

## (n) Second Wind: a hit taking `P` from 30% health or more to under it refills every dash charge, once per
## 45 s; a hit that stays above, or one inside the 45 s, does nothing. Without the perk nothing happens.
func _second_wind(_m: Match, p: Hunter, foe: Hunter) -> void:
	var line := p.max_hp * DashReset.SECOND_WIND_HP
	var drop := func() -> void:
		_spend(p)
		p.hp = line + 1.0
		p.hurt(30.0, foe, {"src": "test"})
	drop.call()
	ok(p.dashes < 0.01, "(n) no Second Wind perk: the drop under 30%% gives nothing (%.2f)" % p.dashes)
	p.perks.append("secondwind")
	p.second_wind_at = -INF
	_spend(p)
	p.hp = p.max_hp
	p.hurt(5.0, foe, {"src": "test"})
	ok(p.dashes < 0.01, "(n) a hit that stays over 30%% gives nothing (%.2f)" % p.dashes)
	drop.call()
	ok(p.hp < line and is_equal_approx(p.dashes, p.max_dashes()) and p.ex_cd == 0.0,
			"(n) Second Wind: under 30%% (hp %.0f) refills all %d charges (%.2f)" % [p.hp, p.max_dashes(), p.dashes])
	drop.call()
	ok(p.dashes < 0.01, "(n) a second drop inside 45 s gives nothing (%.2f)" % p.dashes)
	p.second_wind_at -= DashReset.SECOND_WIND_CD
	drop.call()
	ok(is_equal_approx(p.dashes, p.max_dashes()), "(n) 45 s later it fires again (%.2f)" % p.dashes)
	p.perks.erase("secondwind")
	p.hp = p.max_hp

## A knock is a short freeze and the confirm, never slow motion or a full-screen flash (one rhythm
## offline and online); the knocker also gets the short freeze. Clears the freeze after.
func _knock_beat(m: Match, what: String, freeze: bool) -> void:
	if freeze:
		ok(m.hitstop > 0.0, "%s: the short freeze (%.3f s)" % [what, m.hitstop])
	ok(m.slowmo == 0.0 and (m.hud == null or m.hud.flash_t == 0.0),
			"%s: no slow-mo (%.2f) and no screen flash" % [what, m.slowmo])
	m.hitstop = 0.0
