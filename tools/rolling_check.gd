extends RefCounted
## --rolling-check: rolling 30-minute sessions (scripts/match/rolling.gd, docs/ROADMAP.md §0.6).
## The wave schedule and the join cut-off, joining part-way through (the clock, who's already out
## there, the wide map), drop waves arriving on schedule over the quiet side, the level floor on
## landing, catch-up XP, bounties (posted, shown, claimed), the soft landing (fresh-lander grace and
## the Blight's per-squad ramp), cleared camps coming back, the session ending for everyone at 30:00,
## and the default fixed-length match being untouched. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ROLLING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var part := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rolling-part="): part = a.substr(15)
	if part in ["", "plan"]:
		_static()
		_schedule()
	if part in ["", "session"]:
		_session(main)
	if part in ["", "default"]:
		_default_match(main)
	print("ROLLING DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

# ------------------------------------------------------------------ 1. the numbers
func _static() -> void:
	var want := {0.0: 1, 239.0: 1, 240.0: 2, 600.0: 3, 959.0: 4, 960.0: 5, 1500.0: 5, 1799.0: 5}
	var got := {}
	for t in want: got[t] = Rolling.floor_at(float(t))
	ok(want.keys().all(func(t): return got[t] == want[t]), "level floor = min(5, 1 + minutes/4): %s" % str(got))
	# the fixed format (owner 11-08): every session brings Data.SQUADS trios in all, spread over its waves
	var sum_ok := true; var size_ok := true; var share := Vector2i(99, 0)
	for sd in range(1, 21):
		var r := _plan_only(sd, {"squad": 1, "join_wave": 0})
		var sum := 0
		for w in r.waves:
			sum += int(w["n"])
			share = Vector2i(mini(share.x, int(w["n"])), maxi(share.y, int(w["n"])))
		if sum != Data.SQUADS: sum_ok = false
		if r.size != Data.SQUAD_SIZE: size_ok = false
	ok(sum_ok, "every session brings %d squads in all (20 seeds; %d-%d a wave)" % [Data.SQUADS, share.x, share.y])
	ok(size_ok, "squads are always trios, whatever squad size is asked for")

# ------------------------------------------------------------------ 2. the plan: waves and the cut-off
func _plan_only(seed_v: int, o: Dictionary) -> Rolling:
	var fm := Match.new()
	fm.seed_val = seed_v
	var r := Rolling.new(fm)
	r.plan(o)
	fm.free()
	return r

func _schedule() -> void:
	var gaps_ok := true; var cut_ok := true; var first_ok := true; var n_min := 99; var n_max := 0
	var joins := {}
	for sd in range(1, 41):
		var r := _plan_only(sd, {"squad": 3})
		var ws: Array = r.waves
		n_min = mini(n_min, ws.size()); n_max = maxi(n_max, ws.size())
		first_ok = first_ok and absf(float(ws[0]["t"])) < 0.01
		for i in range(1, ws.size()):
			var g := float(ws[i]["t"]) - float(ws[i - 1]["t"])
			if g < Rolling.GAP.x - 0.01 or g > Rolling.GAP.y + 0.01: gaps_ok = false
		if float(ws[-1]["t"]) > Rolling.SESSION - Rolling.CUTOFF + 0.01: cut_ok = false
		# the wave after the last would have been inside the last 8 minutes
		if float(ws[-1]["t"]) + Rolling.GAP.y <= Rolling.SESSION - Rolling.CUTOFF: cut_ok = false
		joins[r.join_i] = int(joins.get(r.join_i, 0)) + 1
	ok(first_ok, "the session opens with a wave at 0:00")
	ok(gaps_ok, "waves come every %d-%d s" % [int(Rolling.GAP.x), int(Rolling.GAP.y)])
	ok(cut_ok, "no wave in the last %d minutes (last wave by %s)" % [int(Rolling.CUTOFF / 60.0), Rolling.fmt(Rolling.SESSION - Rolling.CUTOFF)])
	ok(n_min >= 7 and n_max <= 12, "%d-%d waves a session" % [n_min, n_max])
	ok(joins.size() >= 5, "you're put in a random wave, not one you pick (40 sessions joined %d different waves)" % joins.size())
	var late := _plan_only(5, {"squad": 3, "join_wave": 99})
	ok(int(late.waves[late.join_i]["n"]) > 0 and late.waves_left() == 0, "joining the last wave that flies: nobody comes after you")
	var at := _plan_only(5, {"squad": 3, "join_at": 700.0})
	ok(float(at.waves[at.join_i]["t"]) <= 700.0 and (at.join_i == at.waves.size() - 1 or float(at.waves[at.join_i + 1]["t"]) > 700.0), "join_at picks the wave that's leaving then (%s)" % Rolling.fmt(at.t0))
	# who's out there when you join: some of the session's earlier squads, never more than its 10x3
	var pops: Array = []
	for sd in range(1, 21):
		var r2 := _plan_only(sd, {"squad": 3, "join_wave": 6})
		pops.append(r2._model_alive_at(r2.t0))
	pops.sort()
	ok(int(pops[pops.size() / 2]) >= 6 and int(pops[-1]) <= Data.MATCH_PLAYERS, "joining around 15:00 there are ~%d hunters already out (range %d-%d)" % [int(pops[pops.size() / 2]), int(pops[0]), int(pops[-1])])

# ------------------------------------------------------------------ 3. a session joined part-way through
func _session(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"rolling": true, "join_wave": 4, "squad": 3, "tier": 0, "seed": 31, "autoplay": true, "plan_t": 0.5, "bot_diff": "medium", "sim_keep": true})
	m.set_process(false)
	var R: Rolling = m.rolling
	ok(R != null, "opts rolling makes a rolling session")
	if R == null:
		m.queue_free(); return
	var t0 := float(R.waves[4]["t"])
	ok(absf(m.sess_t0 - t0) < 0.01 and absf(m.sess_time() - t0) < 0.01, "the session clock starts at your wave (%s), the match clock at 0" % Rolling.fmt(t0))
	ok(absf(m.length - (Rolling.SESSION - t0)) < 0.01, "the match lasts what's left of the session (%s)" % Rolling.fmt(m.length))
	ok(m.world.w == World.BIG_SIZE + WideLayout.WIDE_PAD * 2 and m.world.layout_id.ends_with("_wide"), "rolling sessions use the wide map (%d tiles, %d islands)" % [m.world.w, m.world.islands.size()])
	var ring := m.world.islands.filter(func(I): return String(I.get("id", "")).begins_with("o_"))
	ok(ring.size() == 8 and ring.all(func(I): return int(I.get("danger", 9)) == 0 and (I["cells"] as Array).size() > 400), "eight calm outer islands on the ring")
	var ring_links := m.world.links.filter(func(L): return String(m.world.islands[int(L["from"])].get("id", "")).begins_with("o_"))
	ok(ring_links.size() >= 16, "every ring island has a bridge and a wind road (%d links out)" % ring_links.size())
	var pre: Array = m.hunters.filter(func(h): return h.has_meta("landed_t") and float(h.get_meta("landed_t")) < 0.0)
	ok(pre.size() >= 8, "%d hunters were already out there when you joined" % pre.size())
	var lv_ok := true; var lv_sum := 0
	for h in pre:
		var landed := t0 + float(h.get_meta("landed_t"))
		if h.lvl < Rolling.floor_at(landed) or h.riding or h.dropping: lv_ok = false
		lv_sum += h.lvl
	ok(lv_ok, "they're on the ground, at least at the floor for when they landed (mean level %.1f)" % (float(lv_sum) / maxf(1.0, pre.size())))
	# Boki start state (Net 0.10.0): everyone, early arrivals included, has one active Boki walking beside them
	var kin_ok := true; var kin_n := 0
	for h in m.hunters:
		var k = h.kin
		if k == null: continue      # (no Boki in this save)
		kin_n += 1
		if k.state == "shoulder" or k.state == "wild" or k.owner_h != h or k.cmd != "follow":
			kin_ok = false; print("ROLLING kin start: %s riding=%s %s/%s" % [h.pname, h.riding, k.state, k.cmd])
	ok(kin_ok and kin_n >= 8, "late joiners and the earlier arrivals start with their active Boki following, none on a shoulder (%d Boki)" % kin_n)
	var mine: Array = m.hunters.filter(func(h): return h.riding)
	ok(m.player.riding and mine.size() == int(R.waves[4]["n"]) * 3 and int(R.waves[4]["n"]) >= 1, "your wave: you and %d others on the skyship (%d squads)" % [mine.size() - 1, int(R.waves[4]["n"])])
	var open_chests := m.chests.filter(func(c): return c["open"]).size()
	ok(open_chests > 0, "the map is picked over: %d of %d chests already open" % [open_chests, m.chests.size()])
	if m.blight:
		var bl_ok := pre.all(func(h): return m.blight.land_at.has(h.team) and float(m.blight.land_at[h.team]) < 0.0)
		ok(bl_ok, "the Blight knows when the earlier squads landed (its ramp is per squad)")
	# land
	var t := 0.0
	while (m.player.riding or m.player.dropping) and t < 90.0:
		m.step(Match.DT); t += Match.DT
	ok(not m.player.riding and not m.player.dropping, "you land (%.0f s after setting off)" % t)
	var fl := Rolling.floor_at(m.sess_time())
	var spent := 0
	for k in m.player.slot_lv: spent += int(m.player.slot_lv[k])
	ok(m.player.lvl >= fl and fl >= 2, "you land at the level floor for %s: level %d (floor %d)" % [Rolling.fmt(m.sess_time()), m.player.lvl, fl])
	ok(m.player.skill_pts == 0 and spent == m.player.lvl, "the floor's points are spent: abilities open (%s)" % str(m.player.slot_lv))
	ok(Bot.fresh(m, m.player), "soft landing: bots leave a fresh lander be")
	if m.blight:
		var team := m.player.team
		var here := m.player.pos
		ok(m.blight.squad_time(team) < 10.0 and m.blight.level(here, team) < m.blight.level_here(here) - 0.05,
			"soft landing: the Blight ramps from YOUR landing (squad %.0f s in, strength %.2f vs %.2f map-wide at %s)" % [m.blight.squad_time(team), m.blight.level(here, team), m.blight.level_here(here), Rolling.fmt(m.sess_time())])
	# ---- the next wave, on schedule (the clock skipped ahead to just before it)
	var nw: Dictionary = R.next_wave()
	ok(not nw.is_empty() and int(nw["i"]) == 5, "the next wave is wave 5 at %s" % Rolling.fmt(float(nw.get("t", 0.0))))
	var before := m.hunters.size()
	m.time = float(nw["t"]) - m.sess_t0 - 0.5
	_run(m, 0.4)
	ok(String(nw["state"]) == "planned" and m.ships.is_empty(), "nothing launches before its time")
	_run(m, 0.3)
	ok(String(nw["state"]) == "flying" and m.ships.size() == 1, "the wave sets off on time (%s)" % Rolling.fmt(m.sess_time()))
	var newc: Array = m.hunters.slice(before)
	ok(newc.size() == int(nw["n"]) * 3 and newc.all(func(h): return h.riding and is_same(m.ship_of(h), m.ships[0])), "%d squads (%d hunters) aboard its own skyship" % [int(nw["n"]), newc.size()])
	ok(m.skydrop.leader(newc[0].team) == newc[0], "each wave squad has a drop leader")
	# the wave comes down where it's quiet: compare its landing spots with the map's spawn spots
	var crowd := func(p: Vector3) -> float:
		var c := 0.0
		for h in m.hunters:
			if h.out or h.extracted or h.riding or h.dropping: continue
			var d := Vector2(h.pos.x - p.x, h.pos.z - p.z).length()
			if d < 30.0: c += 1.0
		return c
	var lands: Array = newc.map(func(h): return h.ai.get("land", h.pos))
	var mean_w := 0.0
	for p in lands: mean_w += float(crowd.call(p))
	mean_w /= maxf(1.0, lands.size())
	var mean_all := 0.0
	for sp in m.world.spawns: mean_all += float(crowd.call(sp))
	mean_all /= maxf(1.0, m.world.spawns.size())
	ok(mean_w <= mean_all + 0.01, "the wave heads for the quieter side (%.2f hunters within 30 m of its spots vs %.2f on average)" % [mean_w, mean_all])
	var land_t := 0.0
	while newc.any(func(h): return h.riding or h.dropping or (not h.grounded and not h.out)) and land_t < 75.0:
		m.step(Match.DT); land_t += Match.DT
	for _k in 3: m.step(Match.DT)       # (the session's tick sees them down)
	var landed: Array = newc.filter(func(h): return not h.riding and not h.dropping and not h.out)
	ok(landed.size() >= newc.size() - 1, "the wave lands (%d of %d down in %.0f s)" % [landed.size(), newc.size(), land_t])
	var wfl := Rolling.floor_at(m.sess_time())
	ok(landed.all(func(h): return h.lvl >= Rolling.floor_at(float(R.waves[5]["t"])) and h.skill_pts == 0), "they land at the floor (level %s, floor %d)" % [str(landed.map(func(h): return h.lvl)), wfl])
	ok(landed.all(func(h): return m.blight == null or m.blight.squad_time(h.team) < land_t + 1.0), "their Blight ramp starts at their own landing")
	# ---- catch-up XP
	var P := m.player
	R.median = 6.0
	var xs := []
	for lv in [2, 5, 6, 8]:
		P.lvl = lv; P.xp = float(Hunter.XP_TO[lv - 1])
		var x0 := P.xp
		P.gain_xp(20.0)
		xs.append(snappedf(P.xp - x0, 0.1))
	var want_xs := [2, 5, 6, 8].map(func(lv): return snappedf(20.0 * minf(Rolling.CATCHUP_MAX, 1.0 + maxf(0.0, 6.0 - lv) * Rolling.CATCHUP_PER_LV), 0.1))
	ok(xs == want_xs and xs[0] > xs[1] and xs[1] > xs[2] and xs[2] == 20.0 and xs[3] == 20.0, "catch-up XP with the lobby at level 6: x%.2f at level 2, x%.2f at 5, x1 at 6+ (%s)" % [xs[0] / 20.0, xs[1] / 20.0, str(xs)])
	# the median comes from everyone on the ground
	var onmap: Array = m.hunters.filter(func(h): return R.on_map(h))
	for i in onmap.size(): (onmap[i] as Hunter).lvl = 3 + (i % 3)     # 3, 4, 5, 3, 4, 5, ...
	R._update_median()
	ok(R.median >= 3.0 and R.median <= 5.0, "the lobby's median level is %.1f" % R.median)
	# ---- bounties
	var rival: Hunter = null
	for h in onmap:
		if h != P and h.team != P.team and not h.downed: rival = h; break
	ok(rival != null, "a rival on the ground for the bounty test")
	if rival:
		for h in onmap:
			if h.has_meta("bounty"): h.remove_meta("bounty")
		R.bounty_cd.erase(rival.nid)      # (bots fighting in the minutes before may have claimed one off them: that sets a cooldown)
		rival.lvl = int(R.median) + 4
		P.lvl = int(R.median); P.xp = float(Hunter.XP_TO[P.lvl - 1])
		R._update_median()
		R._update_bounties()
		ok(rival.has_meta("bounty") and R.bounty_of(rival) >= Rolling.BOUNTY_GAP, "a hunter %d levels over the median gets a bounty (gap %d)" % [rival.lvl - int(R.median), R.bounty_of(rival)])
		ok(not P.has_meta("bounty"), "nobody at the median has one")
		var picks0 := m.pickups.size(); var w0 := m.wpicks.size(); var claimed0 := int(R.stats["bounties_claimed"])
		var x0 := P.xp
		var gap := R.bounty_of(rival)
		rival.inv_t = 0.0
		P.downed = false; P.hp = P.max_hp     # (the knock reward needs a knocker on their feet; autopilot may have been down)
		m.knock(rival, P, {})
		var want_min := 90.0 + Rolling.GAP_KNOCK_XP * float(rival.lvl - P.lvl) + Rolling.BOUNTY_XP + Rolling.BOUNTY_XP_GAP * gap
		ok(int(R.stats["bounties_claimed"]) == claimed0 + 1 and not rival.has_meta("bounty"), "knocking them claims the bounty")
		ok(P.xp - x0 >= want_min - 0.5, "the bounty pays XP by the gap (+%d, at least %d)" % [int(P.xp - x0), int(want_min)])
		ok(m.pickups.size() >= picks0 + 4 + 2 * gap and m.wpicks.size() > w0, "and loot at their feet (%d gems, %d treasure)" % [m.pickups.size() - picks0, m.wpicks.size() - w0])
		R._update_bounties()
		ok(not rival.has_meta("bounty"), "no new bounty right after one is claimed (%.0f s cooldown)" % Rolling.BOUNTY_CD)
		m.revive_hunter(rival, rival)
	# ---- cleared camps come back
	var cp_i := -1
	for i in R.camps.size():
		var cp: Dictionary = R.camps[i]
		var near := m.hunters.any(func(h): return not h.out and not h.extracted and Vector2(h.pos.x - cp["pos"].x, h.pos.z - cp["pos"].z).length() < 24.0)
		if not near: cp_i = i; break
	ok(R.camps.size() > 0 and cp_i >= 0, "monster camps are tracked (%d)" % R.camps.size())
	if cp_i >= 0:
		var cp2: Dictionary = R.camps[cp_i]
		for mb in cp2["mobs"]: mb.dead = true; mb.hp = 0.0
		cp2["cleared_at"] = m.time - Rolling.CAMP_RESPAWN - 1.0
		var n0 := int(R.stats["camp_respawns"])
		R._camp_respawns()
		ok(int(R.stats["camp_respawns"]) >= n0 + 1 and (cp2["mobs"] as Array).all(func(mb): return not mb.dead), "a cleared camp comes back after %d s with nobody near" % int(Rolling.CAMP_RESPAWN))
	ok(R.next_meteor(0.0) < m.length and R.next_meteor(0.0) > 0.0, "meteor showers keep coming through the session (next at %s)" % Rolling.fmt(m.sess_t0 + R.next_meteor(0.0)))
	# ---- no new squads in the last 8 minutes
	var flying0 := m.ships.size()
	m.time = Rolling.SESSION - Rolling.CUTOFF - m.sess_t0 + 30.0
	_run(m, 1.0)
	var after_cut := 0
	for w in R.waves:
		if int(w["i"]) > R.join_i and String(w["state"]) != "planned" and float(w["t"]) > Rolling.SESSION - Rolling.CUTOFF: after_cut += 1
	ok(after_cut == 0 and R.next_wave().is_empty() and R.waves_left() == 0, "after %s nobody new drops in (%d ships flew)" % [Rolling.fmt(Rolling.SESSION - Rolling.CUTOFF), m.ships.size()])
	ok(m.ships.size() >= flying0, "the waves up to the cut-off launched as the clock passed them")
	# ---- 30:00: the session ends for everyone
	var p_out0 := P.out      # (the autopilot may have been finished off already: then that is the match's result)
	var ext: Hunter = null
	for h in m.hunters:
		if h != P and not h.out and not h.extracted and not h.riding and not h.dropping: ext = h; break
	if ext: m._extract(ext, "skiff", "test")
	m.time = m.length - 0.5
	_run(m, 1.0)
	var still := m.hunters.filter(func(h): return not h.out and not h.extracted)
	ok(still.is_empty(), "at 30:00 everyone still out there is lost (%d left)" % still.size())
	ok(ext == null or (ext.extracted and not ext.out), "whoever got out keeps what they took")
	ok(m.hunters.filter(func(h): return h.out and String(h.get_meta("died_why", "")) == "abyss").size() > 0 and (p_out0 or m.result.get("why", "") in ["abyss", "extracted"]), "the islands take the rest (result: %s)" % String(m.result.get("why", "")))
	ok(absf(m.sess_time() - Rolling.SESSION) < 1.5, "and that's 30:00 on the session clock (%s)" % Rolling.fmt(m.sess_time()))
	m.queue_free()

# ------------------------------------------------------------------ 4. the fixed match is untouched
func _default_match(main: Node) -> void:
	print("ROLLING (the default match)")
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 4, "squad": 1, "tier": 0, "seed": 31, "autoplay": true, "plan_t": 0.5})
	m.set_process(false)
	ok(m.rolling == null and m.ships.is_empty() and m.sess_t0 == 0.0, "without the option it's the fixed match")
	ok(absf(m.length - Data.MATCH["length"] * 1.7) < 0.01 and m.world.w == World.BIG_SIZE and m.world.layout_id == World.layout_for_tier(0), "same length (%.0f s) and map (%d tiles)" % [m.length, m.world.w])
	var dock: Dictionary = {}
	for x in m.exits.list:
		if x["kind"] == "dock": dock = x; break
	ok(dock.is_empty() or absf(float(dock["open_at"]) - m.length * 0.18) < 0.01, "exits open when they always did")
	ok(m.hunters.all(func(h): return h.riding), "everyone boards the one skyship")
	_run(m, 2.0)
	ok(absf(m.sess_time() - m.time) < 0.001, "the session clock is the match clock")
	m.queue_free()
