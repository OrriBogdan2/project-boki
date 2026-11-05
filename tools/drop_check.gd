extends RefCounted
## --drop-check: the opening drop (docs/decisions/0012) and the spawns.
##   1. planning: the map is up, pings (yours and the bots'), the match clock waits
##   2. the squad comet: a squadmate can't jump before the leader; the leader's jump takes the squad
##      into the comet, which holds together while the jumpmaster steers; the lead passes in the air;
##      a break-away frees only that player (and they can't get back in); the burst lands everyone
##      still in it on solid ground, spread out, together; the Boki leaps off on landing
##   3. a solo drop: the ship's height, 21-25 s from the ship to the ground untouched, the dive faster
##      than the float, the glider opening by itself DEPLOY_H over the ground
##   4. bots: every bot rider has picked whether and where to break off, one that does leaves the
##      comet for a spot of its own, and every bot comet lands on solid ground
##   5. Net: boarding, a break-away, the burst and the dive flag round trip through the handlers
##   6. on the ground: squad pings, the spawn candidates, rare kin, scouting

const BAND := Vector2(21.0, 25.0)      # s: ship to ground, untouched (item 107: the 18-22 s drop, only slightly longer)

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _match(opts: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start(opts)
	m.set_process(false)
	return m

func _run(m: Match, secs: float, until: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		if until.is_valid() and until.call():
			break
		m.step(Match.DT)
		t += Match.DT
	return t

## Ride the ship until it is over the middle of the map.
func _ride_to_middle(m: Match) -> void:
	var mid := Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)
	_run(m, 60.0, func():
		return Vector2(m.ship_pos().x - mid.x, m.ship_pos().z - mid.z).length() < 26.0 or not m.player.riding)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	seed(4101)
	var m := _match({"teams": 3, "squad": 3, "tier": 0, "seed": 4101})
	_planning(m)
	_comet(m)
	_bots(m)
	_ground(m)
	m.over = true
	m.queue_free()
	_solo()
	_net()
	print("DCHECK DONE, failures: %d" % bad)
	print("DCHECK ", "PASS" if bad == 0 else "FAIL")
	main.get_tree().quit()

# ------------------------------------------------------------------ 1. planning
func _planning(m: Match) -> void:
	var P: Hunter = m.player
	var D: DropSquad = m.skydrop
	var you_lead := D.leader(P.team) == P
	ok(
		D.planning and absf(D.plan_t - DropSquad.PLAN_T) < 0.01 and P.riding and you_lead and m.hud.map_open(),
		"planning: %.1fs, aboard=%s, you lead=%s, map open=%s" % [D.plan_t, P.riding, you_lead, m.hud.map_open()]
	)
	var target: Vector3 = m.world.spawns[0]
	var sp: SpawnPlan = m.spawn_plan
	if sp and not sp.active_of("vault").is_empty(): target = sp.active_of("vault")[0]["pos"]
	m.hud.full_map.ping_at(target)
	var mine := m.my_ping()
	ok(
		not mine.is_empty() and Vector2(mine["pos"].x - target.x, mine["pos"].z - target.z).length() < 0.6,
		"a ping on the map"
	)
	var steps := 0
	var t0 := m.time
	while D.planning and steps < 2000:
		m.step(Match.DT)
		steps += 1
	var bot_pings := m.pings.filter(func(q): return q.has("by") and (q["by"] as Hunter).ctrl == "bot").size()
	ok(
		absf(steps * Match.DT - DropSquad.PLAN_T) < 0.1 and m.time == t0,
		"planning lasted %.2fs, the match clock waited" % (steps * Match.DT)
	)
	ok(bot_pings >= 1, "bots pinged (%d)" % bot_pings)

# ------------------------------------------------------------------ 2. the comet
func _comet(m: Match) -> void:
	var P: Hunter = m.player
	var D: DropSquad = m.skydrop
	var C: DropComet = D.comet
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var f0: Hunter = mates[0]
	m.ship_jump(f0)
	ok(f0.riding, "a squadmate can't jump before the leader")
	_ride_to_middle(m)
	m.ship_jump(P)
	var in_comet: Array = mates.filter(func(x): return x.comet_lead == P and x.dropping)
	ok(
		C.leads(P) and in_comet.size() == mates.size(),
		"the leader's jump takes the squad into the comet (%d of %d)" % [in_comet.size(), mates.size()]
	)
	ok(mates.all(func(x): return x.ai.has("break_y")), "every bot rider picked whether to break off")
	for f in mates:
		f.ai["break_y"] = -1.0       # (bot break-offs are part 4)
	ok(
		Match.SHIP_Y >= m.world.w * 0.55 and P.pos.y > 120.0,
		"the drop starts high: %.0fm over a %dm map" % [P.pos.y, m.world.w]
	)
	# the jumpmaster steers (a turn, then a dive): the comet holds together
	var sdir := Vector2((m.ship["dir"] as Vector3).x, (m.ship["dir"] as Vector3).z).normalized()
	var worst := 0.0
	var t := 0.0
	var y0 := P.pos.y
	while t < 3.0 and P.dropping:
		P.inp["move"] = sdir.rotated(1.2) if t < 1.5 else P.fall_dir
		m.step(Match.DT)
		t += Match.DT
		for f in mates:
			worst = maxf(worst, f.pos.distance_to(P.pos))
	ok(
		worst < DropFx.COMET_R and mates.all(func(x): return x.comet_lead == P),
		"the comet holds together while steered (riders within %.2fm)" % worst
	)
	ok(
		P.fall_dir.dot(sdir) < 0.8 and y0 - P.pos.y > 25.0,
		"the jumpmaster turned (heading %.2f off the ship line) and dove %.0fm"
			% [P.fall_dir.angle_to(sdir), y0 - P.pos.y]
	)
	# pass the lead in the air
	var passed := D.pass_lead(P)
	var L2: Hunter = D.leader(P.team)
	_run(m, 0.5)
	ok(passed and C.leads(L2) and P.comet_lead == L2 and mates.all(func(x): return x == L2 or x.comet_lead == L2),
		"the lead passes in the air: %s steers, you ride" % L2.pname)
	# break away: only you leave
	var others: Array = mates.filter(func(x): return x != L2)
	var sep := D.separate(P)
	_run(m, 0.6)
	ok(
		sep and P.comet_lead == null and P.drop_solo and P.dropping and not C.has(P),
		"a break-away: you freefall on your own"
	)
	ok(
		others.all(func(x): return x.comet_lead == L2) and C.leads(L2),
		"and only you: %d still ride with %s" % [others.size(), L2.pname]
	)
	C.board(L2, P)
	ok(P.comet_lead == null, "no getting back in")
	# down: the comet bursts and its squad lands together, each on their own solid spot
	var squad: Array = [L2] + others
	var burst_at := Vector3.INF
	var landed_at := {}
	var kin_was := "-"
	var kin_after := "-"
	t = 0.0
	var in_air := func(x): return x.team == P.team and (x.dropping or x.drop_glide or not x.grounded)
	while t < 40.0 and m.hunters.any(in_air):
		P.inp["move"] = Vector2.ZERO
		SkyFall.assist(m, P)
		if burst_at == Vector3.INF and not C.comets.has(L2.team):
			burst_at = L2.pos
		var up := not P.grounded
		if up and P.kin:
			kin_was = P.kin.state
		m.step(Match.DT)
		t += Match.DT
		if up and P.grounded and P.kin:
			kin_after = P.kin.state
		for x in squad:
			if x.grounded and not landed_at.has(x):
				landed_at[x] = x.pos
	var spots: Array = squad.map(func(x): return landed_at.get(x, x.pos))
	var near := 99.0
	var far := 0.0
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var d := Vector2(spots[i].x - spots[j].x, spots[i].z - spots[j].z).length()
			near = minf(near, d)
			far = maxf(far, d)
	var burst_h := SkyFall.height_over(m.world, burst_at)
	var burst := D.events.any(func(e): return String(e).begins_with("burst"))
	ok(
		burst and burst_h < DropComet.BURST_H + 1.0 and not m.world.is_void(burst_at.x, burst_at.z),
		"the comet burst near the ground (%.1fm up), over solid ground" % burst_h
	)
	ok(squad.all(func(x): return x.grounded and not x.out and not x.downed and not m.world.is_void(x.pos.x, x.pos.z)),
		"the burst lands everyone on solid ground: %s" % str(squad.map(func(x): return [x.pname, x.grounded, x.out])))
	ok(near >= 1.5 and far <= 9.0, "together and spread out: %.1f-%.1fm apart" % [near, far])
	ok(not P.dropping and P.grounded, "you landed solo too (after %.1fs)" % t)
	ok(
		P.kin == null or (kin_was == "shoulder" and kin_after != "shoulder"),
		"your Boki rode down on you (%s) and leapt off as you landed (%s)" % [kin_was, kin_after]
	)

# ------------------------------------------------------------------ 4. bots
func _bots(m: Match) -> void:
	var P: Hunter = m.player
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team)
	var D: DropSquad = m.skydrop
	ok(rivals.all(func(x): return not x.riding), "every rival squad jumped")
	ok(
		D.events.any(func(e): return String(e).begins_with("jump") and not String(e).ends_with("+0")),
		"rival bot leaders took their squads in comets"
	)
	var picked := rivals.filter(func(x): return x.ai.has("break_y")).size()
	ok(picked >= 2, "bot riders picked break-off heights (%d)" % picked)

## A bot comet on its own, with one rider set to break off: it leaves for a spot of its own.
func _bot_break(m2: Match) -> void:
	var D: DropSquad = m2.skydrop
	var C: DropComet = D.comet
	var squad: Array = m2.hunters.filter(func(x): return x.team != m2.player.team and x.team == m2.hunters[-1].team)
	var lead: Hunter = D.leader(squad[0].team)
	_run(m2, 60.0, func(): return not lead.riding)
	m2.ship_jump(lead)
	var rs: Array = C.riders(lead.team)
	ok(rs.size() == squad.size() - 1, "a bot jumpmaster's squad rides its comet (%d)" % rs.size())
	if rs.is_empty():
		return
	var leaver: Hunter = rs[0]
	leaver.ai["break_y"] = lead.pos.y - 12.0
	for r in rs.slice(1):
		r.ai["break_y"] = -1.0
	_run(m2, 4.0, func(): return leaver.comet_lead == null)
	var own: Vector3 = leaver.ai.get("land", Vector3.ZERO)
	var squad_spot: Vector3 = lead.ai.get("land", lead.pos)
	ok(
		leaver.comet_lead == null and leaver.dropping and leaver.drop_solo,
		"a bot breaks off at its height (%.0fm)" % leaver.pos.y
	)
	ok(Vector2(own.x - squad_spot.x, own.z - squad_spot.z).length() > 10.0, "and heads for a spot of its own")
	_run(m2, 40.0, func(): return squad.all(func(x): return x.grounded and not x.drop_glide))
	ok(squad.all(func(x): return x.grounded and not x.out and not m2.world.is_void(x.pos.x, x.pos.z)),
		"the bot squad lands on solid ground: %s" % str(squad.map(func(x): return [x.pname, x.grounded, x.out])))

# ------------------------------------------------------------------ 3. solo
func _solo() -> void:
	var m := _match({"teams": 3, "squad": 3, "tier": 0, "seed": 4102, "no_plan": true})
	_bot_break(m)
	m.queue_free()
	m = _match({"teams": 2, "squad": 1, "tier": 0, "seed": 4103, "no_plan": true})
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P:
			o.riding = false
			o.ctrl = "idle"
			o.teleport(m.world.spawns[-1])
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	_ride_to_middle(m)
	var from := m.ship_pos()
	var dir := Vector2((m.ship["dir"] as Vector3).x, (m.ship["dir"] as Vector3).z)
	var float_r := _solo_drop(m, P, from, dir, false)
	# a dive at a spot on solid ground ahead, in a dive's reach
	var spot := SkyFall.nearest_land(m, from + Vector3(dir.x, 0, dir.y).normalized() * 50.0)
	var dive_r := _solo_drop(m, P, from, Vector2(spot.x - from.x, spot.z - from.z), true)
	ok(
		float_r["t"] >= BAND.x and float_r["t"] <= BAND.y,
		"untouched, ship to ground in %.1fs (target %d-%ds; dove the whole way: %.1fs)"
			% [float_r["t"], BAND.x, BAND.y, dive_r["t"]]
	)
	ok(
		dive_r["vy"] > float_r["vy"] + 5.0 and dive_r["hs"] > float_r["hs"] and dive_r["t"] < float_r["t"] - 3.0,
		"the dive is faster: falls %.1f vs %.1f m/s, across %.1f vs %.1f m/s"
			% [dive_r["vy"], float_r["vy"], dive_r["hs"], float_r["hs"]]
	)
	ok(
		absf(float_r["deploy"] - SkyFall.DEPLOY_H) < 1.0 and absf(dive_r["deploy"] - SkyFall.DEPLOY_H) < 1.5,
		"the glider opens by itself %.1fm / %.1fm over the ground (DEPLOY_H %.0f)"
			% [float_r["deploy"], dive_r["deploy"], SkyFall.DEPLOY_H]
	)
	ok(float_r["kick"] and dive_r["kick"], "a landing kick both times")
	m.queue_free()

## Off the ship at `from` along `dir`, diving or not (the player's own assist over the abyss); after the
## glider opens, steer for the ground under where it opened. Returns the timings.
func _solo_drop(m: Match, P: Hunter, from: Vector3, dir: Vector2, dive: bool) -> Dictionary:
	if P.out or P.downed:
		Life.bring_back(m, P, from, 1.0, false)
	P.riding = false
	P.drop_glide = false
	P.teleport(from + Vector3(0, -1.5, 0))
	SkyFall.start(P, dir)
	var r := {"t": 0.0, "vy": 0.0, "hs": 0.0, "deploy": -1.0, "kick": false}
	var aim := Vector3.INF
	var t := 0.0
	while t < 45.0 and not P.grounded:
		if P.dropping:
			P.inp["move"] = P.fall_dir if dive else Vector2.ZERO
			if not dive:
				SkyFall.assist(m, P)
		elif aim != Vector3.INF:
			var to := Vector2(aim.x - P.pos.x, aim.z - P.pos.z)
			P.inp["move"] = to.normalized() if to.length() > 0.8 else Vector2.ZERO
		var was := P.dropping
		m.step(Match.DT)
		t += Match.DT
		if P.dropping and t > 4.0 and t < 6.0:
			r["vy"] = maxf(r["vy"], -P.vel.y)
			r["hs"] = maxf(r["hs"], Vector2(P.vel.x, P.vel.z).length())
		if was and not P.dropping and r["deploy"] < 0.0:
			r["deploy"] = SkyFall.height_over(m.world, P.pos)
			aim = P.pos if not m.world.is_void(P.pos.x, P.pos.z) else SkyFall.nearest_land(m, P.pos)
	r["t"] = t
	r["kick"] = P.squash > 0.2
	P.inp["move"] = Vector2.ZERO
	return r

# ------------------------------------------------------------------ 5. Net
func _net() -> void:
	var m := _match({"teams": 2, "squad": 3, "tier": 0, "seed": 4104, "no_plan": true})
	var P: Hunter = m.player
	var D: DropSquad = m.skydrop
	var C: DropComet = D.comet
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var R: Hunter = mates[0]
	var B: Hunter = mates[1]
	_ride_to_middle(m)
	m.ship_jump(P)
	# R's own game boards R into P's comet: the event it sends ...
	Net.out_events.clear()
	m.net_on = true
	C.leave(R)
	R.drop_solo = false
	C.board(P, R)
	var sent: Array = Net.out_events.duplicate(true)
	m.net_on = false
	ok(sent.has(["comet", P.nid, R.nid]), "boarding sends 'comet' (%s)" % str(sent))
	# ... read in this game, where R is someone else's
	C.leave(R)
	R.drop_solo = false
	R.remote = true
	for e in sent:
		m._net_ev(e, "")
	ok(R.comet_lead == P and C.riders(P.team).has(R), "a 'comet' from another game seats them in the comet")
	# the dive flag in the hunter snapshot
	P.inp["move"] = P.fall_dir
	m.step(Match.DT)
	var snap := m._ser(P)
	R.diving = false
	R.dropping = false
	m._net_apply(R, snap)
	ok(P.diving and R.diving and R.dropping, "the snapshot carries the freefall and the dive")
	R.dropping = true
	R.comet_lead = P
	# a break-away from R's game
	m._net_ev(["dsep", R.nid], "")
	ok(
		R.comet_lead == null and R.drop_solo and C.riders(P.team).has(B) and not C.riders(P.team).has(R),
		"'dsep' frees only them"
	)
	# the burst from the jumpmaster's game: B (local here) lands on its spot round the sent ground point
	R.remote = false
	P.remote = true
	var ground := m.world.free_spot_near(m.world.spawns[0], [], 1.0, 0.5, 8.0)
	var sent_burst: Array = ["cburst", P.nid, ground.x, ground.y, ground.z]
	m._net_ev(sent_burst, "")
	var spots: Array = C.spots(ground, 2)
	ok(B.comet_lead == null and not B.pad.is_empty() and (B.pad["to"] as Vector3).distance_to(spots[1]) < 0.01,
		"a 'cburst' flings the riders in this game onto their spots")
	# and the burst this game sends
	P.remote = false
	C.board(P, B)
	Net.out_events.clear()
	m.net_on = true
	C.burst(P.team, ground)
	var sent2: Array = Net.out_events.duplicate(true)
	m.net_on = false
	ok(sent2.any(func(e): return e[0] == "cburst" and e[1] == P.nid), "a burst sends 'cburst'")
	m.over = true
	m.queue_free()

# ------------------------------------------------------------------ 6. the ground
func _ground(m: Match) -> void:
	var P: Hunter = m.player
	var D: DropSquad = m.skydrop
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var bot: Hunter = mates[1] if mates.size() > 1 else mates[0]
	var base_spot := m.world.free_spot_near(m.world.spawns[0], [], 1.0, 0.5, 8.0)
	for x in [P, bot]:
		if x.out or x.downed:
			Life.bring_back(m, x, base_spot + (Vector3(2.0, 0, 0) if x == bot else Vector3.ZERO), 1.0, false)
		if m.world.is_void(x.pos.x, x.pos.z) or x.pos.y < m.world.ground_at(x.pos.x, x.pos.z) - 1.0:
			x.teleport(base_spot + (Vector3(2.0, 0, 0) if x == bot else Vector3.ZERO))
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o.team != P.team:
			o.ctrl = "idle"
			o.teleport(m.world.spawns[-1])      # (no fights in the way)
	var ev0 := D.events.size()
	var spot := bot.pos
	for k in 40:
		var near := bot.pos + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		var q := m.world.free_spot_near(near, [], 1.0, 0.5, 6.0)
		var same_island := m.world.island_of(q.x, q.z) == m.world.island_of(bot.pos.x, bot.pos.z)
		var in_band := bot.flat_dist(q) > 6.0 and bot.flat_dist(q) < 9.0
		if same_island and in_band and m.world.los(bot.pos, q, bot.pos.y + 1.0):
			spot = q
			break
	spot.y = m.world.ground_at(spot.x, spot.z)
	m.squad_ping(P, spot)
	var d0 := bot.flat_dist(spot)
	var went := false
	var closest := d0
	var t := 0.0
	while t < 6.0:
		m.step(Match.DT)
		t += Match.DT
		if mates.any(func(x): return String(x.ai.get("goal_kind", "")) == "ping"): went = true
		closest = minf(closest, mates.map(func(x): return x.flat_dist(spot)).min())
	var replies: Array = D.events.slice(ev0).filter(func(e): return String(e).begins_with("reply"))
	ok(went and closest <= 4.0 and replies.any(func(r): return String(r).ends_with("omw")),
		"a ground ping: a squad bot headed there (%.1fm -> %.1fm), replies %s" % [d0, closest, str(replies)])
	m.unping(P)
	ok(m.my_ping().is_empty() and not bot.ai.has("ping_goal"), "right click takes the ping down")
	_spawns(m)

func _spawns(m: Match) -> void:
	var P: Hunter = m.player
	var sp: SpawnPlan = m.spawn_plan
	var layout := World.load_layout(World.layout_for_tier(0))
	var subsets := {}
	for sd in [4101, 4102, 4103]:
		var plan := SpawnPlan.new(m)
		plan.build(layout)
		plan.roll(sd)
		subsets[sd] = plan.active_ids()
	ok(subsets[4101] == sp.active_ids(), "the same seed rolls the same spawns")
	ok(not (subsets[4101] == subsets[4102] and subsets[4102] == subsets[4103]), "seeds roll different spawns")
	var gm := Match.new()
	gm.world = World.new()
	gm.world.generate(9, World.BIG_SIZE, World.BIG_ISLANDS)
	var g1 := SpawnPlan.new(gm)
	g1.build({})
	var g2 := SpawnPlan.new(gm)
	g2.build({})
	var gpos: Array = g1.cands.map(func(cc): return cc["pos"])
	var same := gpos == g2.cands.map(func(cc): return cc["pos"])
	ok(g1.count_of("rare_kin") >= 3 and g1.count_of("vault") >= 2 and g1.count_of("cache") >= 4 and same,
		"a generated map's spawn candidates")
	gm.world.free()
	gm.free()
	var rare: Array = m.kins.filter(func(k): return k.has_meta("rare"))
	var live: Array = sp.active_of("rare_kin")
	var stray := 0
	for k in rare:
		if not live.any(func(cnd): return Vector2(k.home.x - cnd["pos"].x, k.home.z - cnd["pos"].z).length() < 3.0):
			stray += 1
	var at_dead := 0
	for cnd in sp.of("rare_kin"):
		if not cnd["active"]:
			var at: Vector3 = cnd["pos"]
			at_dead += rare.filter(func(k): return Vector2(k.home.x - at.x, k.home.z - at.z).length() < 3.0).size()
	ok(rare.size() == live.size() and stray == 0 and at_dead == 0,
		"rare kin: %d for %d live points, %d strays, %d at points not rolled"
			% [rare.size(), live.size(), stray, at_dead])
	var hidden: Array = sp.cands.filter(func(cc):
		return not sp.cats[cc["cat"]].get("announce", false) and not cc["active"])
	if not hidden.is_empty():
		var hc: Dictionary = hidden[0]
		var before := sp.state_for(hc, P.team)
		if P.out or P.downed: Life.bring_back(m, P, hc["pos"], 1.0, false)
		P.teleport(hc["pos"] + Vector3(1.5, 0, 0))
		for i in 30:
			m.step(Match.DT)
		ok(
			before == "unknown" and sp.state_for(hc, P.team) == "empty",
			"scouting: %s -> %s" % [before, sp.state_for(hc, P.team)]
		)
