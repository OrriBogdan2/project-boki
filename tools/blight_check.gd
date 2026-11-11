extends RefCounted
## --blight-check: the Blight (scripts/match/blight.gd, blight_dir.gd). Its strength curve (weak
## early and on the outer islands, stronger with time, the core and night), where Wardens stand,
## the grace period after landing, noise drawing Skitters in, a level-1 hunter beating or
## outrunning an early Skitter, a Warden's light and shriek (a warning early, Skitters later),
## Skitters going for bots and bots fighting back, idle ones burrowing away, and the network
## snapshot of a Blight. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BLIGHT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(m: Match, secs: float, each := Callable()) -> void:
	for i in int(secs / Match.DT):
		if each.is_valid(): each.call()
		m.step(Match.DT)

func _match(main: Node, seed_v: int, raid := "clear", extra := {}) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true, "raid": raid}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)
	return m

## Everyone but the player stands still far away, camp monsters are cleared, and the Blight the
## test doesn't place is gone, so each part tests one thing.
func _quiet(m: Match, keep_wardens := false) -> void:
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	for mb in m.mobs:
		if mb is Blight and keep_wardens and mb.mkind == "bl_warden":
			continue
		if mb is Blight:
			(mb as Blight).burrow()
		else:
			mb.dead = true; mb.visible = false
	m.player.ctrl = "idle"

func _open_spot(m: Match, near: Vector3, r := 9.0) -> Vector3:
	return m.world.free_spot_near(near, [], 1.0, 0.5, r)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_curve(main)
	_spawns(main)
	_noise_and_fights(main)
	_warden(main)
	_bots(main)
	_tide(main)
	print("BLIGHT DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

# ------------------------------------------------------------------ 1. the strength curve
func _curve(main: Node) -> void:
	var m := _match(main, 7101, "clear")
	var B: BlightDir = m.blight
	ok(B != null, "a real expedition has the Blight")
	if B == null:
		m.queue_free(); return
	var w := m.world
	# an island of each danger
	var isl := {}
	for ii in w.islands.size():
		var dg := int((w.islands[ii] as Dictionary).get("danger", -1))
		if dg >= 0 and not isl.has(dg):
			isl[dg] = ii
	ok(isl.has(0) and isl.has(2), "the map has outer (danger 0) and core (danger 2) islands")
	var p_out: Vector3 = B._rand_ground(int(isl.get(0, 0)))
	var p_core: Vector3 = B._rand_ground(int(isl.get(2, 0)))
	var team: int = m.player.team
	B.land_at[team] = m.time
	var l0_out := B.level(p_out, team); var l0_core := B.level(p_core, team)
	B.land_at[team] = m.time - 120.0
	var l2 := B.level(p_core, team)
	B.land_at[team] = m.time - 600.0
	var l10_out := B.level(p_out, team); var l10_core := B.level(p_core, team)
	print("BLIGHT levels: landing outer %.2f core %.2f, 2 min core %.2f, 10 min outer %.2f core %.2f" % [l0_out, l0_core, l2, l10_out, l10_core])
	ok(l0_out < l0_core and l10_out < l10_core, "outer islands are safer than the core")
	ok(l0_core < l2 and l2 < l10_core, "it ramps with the squad's time on the islands")
	ok(l0_core <= 0.2, "at landing it's weak everywhere (core %.2f)" % l0_core)
	# per squad: a squad that just landed gets the soft start while another is ten minutes in
	var other := (team + 1) % 3
	B.land_at[other] = m.time
	ok(B.level(p_core, other) < B.level(p_core, team) * 0.3, "per squad: a late squad starts soft (%.2f vs %.2f)" % [B.level(p_core, other), B.level(p_core, team)])
	# early numbers: die fast, hit soft
	var sk: Dictionary = Data.MOBS["bl_skitter"]
	var e_hp := float(sk["hp"]) * BlightDir.hp_k(l0_core)
	var e_dmg := float(sk["dmg"]) * BlightDir.dmg_k(l0_core)
	var late_hp := float(sk["hp"]) * BlightDir.hp_k(l10_core)
	var late_dmg := float(sk["dmg"]) * BlightDir.dmg_k(l10_core)
	print("BLIGHT skitter early %.1f hp / %.1f a bite, late core %.1f hp / %.1f a bite" % [e_hp, e_dmg, late_hp, late_dmg])
	ok(e_hp <= 18.0 and e_dmg <= 4.5, "an early Skitter dies fast and bites soft")
	ok(late_hp >= e_hp * 2.0 and late_dmg >= e_dmg * 2.0, "a late one is the real thing")
	var wd: Dictionary = Data.MOBS["bl_warden"]
	ok(float(wd["dmg"]) * BlightDir.dmg_k(l0_core) <= 7.0, "an early Warden's bolt is soft (%.1f)" % (float(wd["dmg"]) * BlightDir.dmg_k(l0_core)))
	m.queue_free()
	# the raid condition: night is worse than a clear evening, at the same spot and time
	var mn := _match(main, 7101, "night")
	var Bn: BlightDir = mn.blight
	Bn.land_at[mn.player.team] = mn.time - 300.0
	B = null
	var mc := _match(main, 7101, "clear")
	var Bc: BlightDir = mc.blight
	Bc.land_at[mc.player.team] = mc.time - 300.0
	var pn: Vector3 = Bn._rand_ground(int(isl.get(1, 0)))
	print("BLIGHT raid: night %.2f vs clear %.2f at 5 min" % [Bn.level(pn, mn.player.team), Bc.level(pn, mc.player.team)])
	ok(Bn.level(pn, mn.player.team) > Bc.level(pn, mc.player.team), "night makes the Blight stronger")
	mn.queue_free(); mc.queue_free()

# ------------------------------------------------------------------ 2. where they are
func _spawns(main: Node) -> void:
	var m := _match(main, 7102, "clear")
	var B: BlightDir = m.blight
	var w := m.world
	var per := {0: [0, 0], 1: [0, 0], 2: [0, 0]}
	for ii in w.islands.size():
		var dg := clampi(int((w.islands[ii] as Dictionary).get("danger", 0)), 0, 2)
		per[dg][1] += 1
	for b in B.wardens:
		var dg := clampi(int((w.islands[w.island_of(b.pos.x, b.pos.z)] as Dictionary).get("danger", 0)), 0, 2)
		per[dg][0] += 1
	var avg := func(d): return float(per[d][0]) / maxf(1.0, float(per[d][1]))
	print("BLIGHT wardens %d: per island outer %.2f mid %.2f core %.2f" % [B.wardens.size(), avg.call(0), avg.call(1), avg.call(2)])
	ok(B.wardens.size() >= 3, "Wardens stand on the islands from the start")
	ok(avg.call(0) < avg.call(2), "fewer Wardens on the outer islands than in the core")
	ok(B.skitters_alive() == 0, "no Skitters at the start")
	var bad_spot := 0
	for b in B.wardens:
		for c in w.camp_spots:
			if b.flat_dist(c["pos"]) < 8.0: bad_spot += 1
		if m.lairs and not m.lairs.lair_of(b.pos, 3.0).is_empty(): bad_spot += 1
	ok(bad_spot == 0, "Wardens stand clear of camps and lairs")
	# the grace period: nothing comes for a squad in its first GRACE seconds, even if it's loud
	_quiet(m)
	var P := m.player
	B.land_at.clear()
	var n0 := B.spawned
	_run(m, 2.0)
	_run(m, BlightDir.GRACE - 6.0, func():
		if int(m.time * 60.0) % 30 == 0: m.note_sound(P, P.pos, "shot"))
	ok(B.spawned == n0, "nothing claws out of the ground in the first %ds after landing (%d spawned)" % [int(BlightDir.GRACE), B.spawned - n0])
	# after it, noise brings them: a loud squad draws a Skitter
	var t_end := m.time + 40.0
	while m.time < t_end and B.spawned == n0:
		if int(m.time * 60.0) % 20 == 0: m.note_sound(P, P.pos, "shot")
		P.hp = P.max_hp
		m.step(Match.DT)
	var first: Array = B.alive().filter(func(x): return x.mkind == "bl_skitter")
	print("BLIGHT after the grace period a loud squad drew %d Skitter(s) at t=%.1f (heat %.2f)" % [B.spawned - n0, m.time, float(B.heat.get(P.team, 0.0))])
	ok(B.spawned > n0, "noise after the grace period draws Skitters")
	ok(B.spawned - n0 <= 2, "early on that's one or two, not a swarm")
	if not first.is_empty():
		var f: Blight = first[0]
		ok(f.flat_dist(P) > 10.0, "they claw out of the ground away from you (%.1f tiles)" % f.flat_dist(P))
		ok(not m.sees(P.team, f.pos) or f.flat_dist(P) > 12.0, "... out of your sight")
	m.queue_free()

# ------------------------------------------------------------------ 3. noise, a fight, a chase
func _noise_and_fights(main: Node) -> void:
	var m := _match(main, 7103, "clear")
	var B: BlightDir = m.blight
	_quiet(m)
	var P := m.player
	var base := _open_spot(m, m.world.spawns[0])
	P.teleport(base)
	B.land_at[P.team] = m.time - 50.0        # a minute in: early
	var l := B.level(P.pos, P.team)
	# noise: a Skitter 13 tiles off hears a shot and comes to look; one 40 off doesn't
	var near_s := B.spawn("bl_skitter", _open_spot(m, base + Vector3(13, 0, 0), 4.0), l)
	var far_s := B.spawn("bl_skitter", _open_spot(m, base + Vector3(-40, 0, 6), 10.0), l)
	near_s.post = near_s.pos; far_s.post = far_s.pos
	var d0 := near_s.flat_dist(P)
	m.note_sound(P, P.pos + Vector3(1, 0, 0), "shot")
	ok(near_s.heard != Vector3.INF, "a Skitter in earshot heard the shot")
	ok(far_s.heard == Vector3.INF, "one far off didn't")
	P.crouch = true
	_run(m, 1.5)
	print("BLIGHT the Skitter came %.1f -> %.1f tiles (state %s)" % [d0, near_s.flat_dist(P), near_s.st])
	ok(near_s.flat_dist(P) < d0 - 3.0, "it came toward the noise")
	far_s.burrow()
	# an early Skitter against a level-1 hunter: you win, and it barely scratches you
	P.crouch = false
	P.hp = P.max_hp; P.armor = P.max_armor
	near_s.teleport(P.pos + Vector3(3.5, 0, 0))
	near_s.tgt = P; near_s.st = "chase"
	ok(P.lvl <= 1, "the hunter is level %d" % P.lvl)
	var t := 0.0
	while t < 8.0 and not near_s.dead:
		P.inp["aim"] = near_s.pos + Vector3(0, 0.5, 0)
		P.inp["aim_y"] = near_s.pos.y + 0.5
		P.inp["fire"] = true
		m.step(Match.DT); t += Match.DT
	P.inp["fire"] = false
	var lost := (P.max_hp - P.hp) + (P.max_armor - P.armor)
	print("BLIGHT level-1 hunter vs an early Skitter: dead=%s after %.1fs, the hunter lost %.0f health+armor" % [near_s.dead, t, lost])
	ok(near_s.dead, "a level-1 hunter kills an early Skitter")
	ok(lost < P.max_hp * 0.25, "and keeps most of their health")
	# fleeing: an early Skitter can't keep up with a running hunter and gives up
	P.hp = P.max_hp; P.armor = P.max_armor
	var runner := B.spawn("bl_skitter", _open_spot(m, P.pos + Vector3(2.5, 0, 0), 3.0), l)
	runner.tgt = P; runner.st = "chase"; runner.chase_from = runner.pos
	# run along open ground away from it
	var away := (Vector2(P.pos.x, P.pos.z) - Vector2(runner.pos.x, runner.pos.z)).normalized()
	t = 0.0
	var hp0 := P.hp + P.armor
	while t < 9.0 and runner.tgt != null:
		var mv := away
		# steer round the edge: if the way ahead is open sky, turn along the island
		var ahead := P.pos + Vector3(mv.x, 0, mv.y) * 2.0
		if m.world.is_void(ahead.x, ahead.z) or m.world.is_block(ahead.x, ahead.z):
			away = away.rotated(0.9); mv = away
		P.inp["move"] = mv
		P.inp["aim"] = P.pos + Vector3(mv.x, 0.9, mv.y) * 3.0
		m.step(Match.DT); t += Match.DT
	P.inp["move"] = Vector2.ZERO
	print("BLIGHT fleeing an early Skitter: it gave up after %.1fs (target %s, %.1f tiles), the hunter lost %.0f" % [t, str(runner.tgt), runner.flat_dist(P), hp0 - P.hp - P.armor])
	ok(runner.tgt == null or runner.flat_dist(P) > 8.0, "a level-1 hunter can outrun an early Skitter")
	ok(hp0 - P.hp - P.armor < P.max_hp * 0.3, "... without losing much")
	# idle ones far from everyone burrow away (if the chase above ended with the Skitter off an edge,
	# a fresh one stands in: this tests the burrowing, not where the chase went)
	if runner.dead:
		runner = B.spawn("bl_skitter", _open_spot(m, P.pos + Vector3(2.5, 0, 0), 3.0), l)
	runner.tgt = null; runner.st = "idle"; runner.heard = Vector3.INF
	runner.idle_t = 25.0
	P.teleport(_open_spot(m, P.pos + Vector3(0, 0, 0)))
	var far_spot := _open_spot(m, m.world.spawns[-1], 10.0)
	runner.teleport(far_spot)
	for o in m.hunters:
		if o.flat_dist(runner) < 32.0: o.teleport(base)
	if P.flat_dist(runner) < 32.0:
		ok(true, "(burrow: the spots are too close on this map, skipped)")
	else:
		B._despawn_tick()
		if not runner.gone:
			print("BLIGHT burrow dead=%s gone=%s far_spot %s " % [runner.dead, runner.gone, str(far_spot)] + ": runner at %s st %s heard %s idle %.1f, hunters %s" % [str(runner.pos), runner.st, str(runner.heard), runner.idle_t, str(m.hunters.filter(func(o): return not o.out).map(func(o): return snappedf(o.flat_dist(runner), 0.1)))])
		ok(runner.dead and runner.gone, "an idle Skitter far from everyone burrows away")
	# the network: a Blight's snapshot carries its light, alert and strength, and builds a Blight
	var wd := B.spawn("bl_warden", _open_spot(m, base + Vector3(-6, 0, 0), 4.0), 0.5)
	wd.cone_a = 1.25; wd.spot = 0.4
	var it: Array = m._ser(wd)
	ok(it.size() >= 21 and is_equal_approx(float(it[17]), 1.25) and String(it[9]) == "bl_warden", "a Warden's snapshot carries its light and state (%d fields)" % it.size())
	var it2 := it.duplicate()
	it2[1] = "mnet1"; it2[17] = -0.5
	var made: Ent = m._net_make(it2)
	if made: m._net_apply(made, it2)
	ok(made is Blight and absf((made as Blight).cone_a + 0.5) < 0.01 and (made as Blight).cone != null, "a remote Warden is built from the snapshot, light and all")
	ok(Net.VERSION != "0.4.0", "the network version moved on (%s)" % Net.VERSION)
	m.queue_free()

# ------------------------------------------------------------------ 4. a Warden's light
func _warden(main: Node) -> void:
	var m := _match(main, 7104, "clear")
	var B: BlightDir = m.blight
	_quiet(m)
	var P := m.player
	var base := _open_spot(m, m.world.spawns[1 % m.world.spawns.size()])
	P.teleport(base)
	B.land_at[P.team] = m.time - 40.0
	var wspot := _open_spot(m, base + Vector3(5.5, 0, 0), 3.0)
	var W := B.spawn("bl_warden", wspot, B.level(wspot, P.team))
	W.post = W.pos
	W.sweep_amp = 0.0          # (the light holds where the test points it)
	# pointing away: you aren't spotted
	W.sweep0 = atan2(base.x - W.pos.x, base.z - W.pos.z) + PI
	_run(m, 0.6, func(): W.sweep0 = atan2(P.pos.x - W.pos.x, P.pos.z - W.pos.z) + PI)
	ok(W.spot <= 0.01 and B.shrieks == 0, "out of the light, nothing happens")
	# a crouched hunter at the edge of the light stays unseen (crouching shortens its reach)
	var n_sk := B.skitters_alive()
	var t := 0.0
	var spotted_t := -1.0
	while t < 4.0 and B.shrieks == 0:
		W.sweep0 = atan2(P.pos.x - W.pos.x, P.pos.z - W.pos.z)
		W.cone_a = W.sweep0
		m.step(Match.DT); t += Match.DT
		if W.spot > 0.0 and spotted_t < 0.0: spotted_t = t
	print("BLIGHT Warden (lvl %.2f): shrieked after %.2fs in its light (%d shriek)" % [W.lvl, t, B.shrieks])
	ok(B.shrieks == 1, "standing in a Warden's light makes it shriek")
	ok(t > 0.6, "... after a moment to get out (%.2fs)" % t)
	ok(P.reveal_t > 0.0, "the light lights you up for everyone")
	ok(B.skitters_alive() == n_sk, "early on the shriek is only a warning: no Skitters came out of it")
	# a nearby idle Skitter heard the shriek
	# late in a squad's run, a shriek brings Skitters out of the ground round the Warden
	B.land_at[P.team] = m.time - 600.0
	W.set_level(B.level(W.pos, P.team))
	W.shriek_cd = 0.0
	var sh0 := B.skitters_alive()
	W.shriek(P)
	print("BLIGHT a late shriek (lvl %.2f) brought %d Skitters" % [W.lvl, B.skitters_alive() - sh0])
	ok(B.skitters_alive() > sh0, "late on, a shriek brings Skitters")
	# crouching just past the shortened reach: not spotted
	for b in B.alive():
		if b != W: (b as Blight).burrow()
	W.st = "idle"; W.tgt = null; W.spot = 0.0; W.shriek_cd = 0.0
	var sh1 := B.shrieks
	var side := Vector2(P.pos.x - W.pos.x, P.pos.z - W.pos.z).normalized()
	var cpos := W.pos + Vector3(side.x, 0, side.y) * (W.cone_len() * 0.8)
	if not m.world.is_void(cpos.x, cpos.z) and not m.world.is_block(cpos.x, cpos.z):
		P.teleport(Vector3(cpos.x, m.world.ground_at(cpos.x, cpos.z), cpos.z))
		P.crouch = true
		_run(m, 1.5, func():
			P.crouch = true; P.inp["crouch"] = true
			W.sweep0 = atan2(P.pos.x - W.pos.x, P.pos.z - W.pos.z); W.cone_a = W.sweep0)
		ok(B.shrieks == sh1 and W.spot < 0.05, "sneaking at the edge of the light keeps you unseen")
		P.crouch = false; P.inp["crouch"] = false
	m.queue_free()

# ------------------------------------------------------------------ 5. bots
func _bots(main: Node) -> void:
	var m := _match(main, 7105, "clear")
	var B: BlightDir = m.blight
	_quiet(m)
	var P := m.player
	var bot: Hunter = null
	for o in m.hunters:
		if o.ctrl == "idle" and o != P and o.team != P.team:
			bot = o; break
	ok(bot != null, "found a bot")
	if bot == null:
		m.queue_free(); return
	bot.ctrl = "bot"
	var base := _open_spot(m, m.world.spawns[2 % m.world.spawns.size()])
	bot.teleport(base)
	P.teleport(_open_spot(m, m.world.spawns[-1]))
	B.land_at[bot.team] = m.time - 80.0
	var l := B.level(base, bot.team)
	var s1 := B.spawn("bl_skitter", _open_spot(m, base + Vector3(4, 0, 1), 3.0), l)
	var s2 := B.spawn("bl_skitter", _open_spot(m, base + Vector3(4, 0, -1), 3.0), l)
	for s in [s1, s2]:
		s.hear(bot.pos, 10.0)
	var targeted := false
	var t := 0.0
	var hp0 := bot.hp + bot.armor
	while t < 15.0 and not (s1.dead and s2.dead):
		m.step(Match.DT); t += Match.DT
		if s1.tgt == bot or s2.tgt == bot: targeted = true
	print("BLIGHT a bot vs two early Skitters: %.1fs, skitters dead %s/%s, bot lost %.0f, bot out %s downed %s" % [t, s1.dead, s2.dead, hp0 - bot.hp - bot.armor, bot.out, bot.downed])
	ok(targeted, "Skitters go for bots too")
	ok(s1.dead or s2.dead, "the bot fights back")
	ok(not bot.out and not bot.downed, "and isn't knocked by early Blight")
	# a hurt bot with nothing to drink backs away from the Blight
	bot.hp = bot.max_hp * 0.2; bot.tonics = 0
	var s3 := B.spawn("bl_skitter", _open_spot(m, bot.pos + Vector3(5, 0, 0), 3.0), l)
	s3.cd = 99.0
	var fl: Vector3 = Bot.new()._blight_flee(m, bot)
	ok(fl != Vector3.INF and Vector2(fl.x - s3.pos.x, fl.z - s3.pos.z).length() > s3.flat_dist(bot), "a hurt bot picks a spot away from the Blight")
	m.queue_free()

# ------------------------------------------------------------------ 6. the tide's damage
## The source's death circle per stage, flat, scaled by our medium health over theirs (heart.json).
const TIDE_SRC := [3.0, 6.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0, 450.0]

func _tide(main: Node) -> void:
	var m := _match(main, 7105, "clear", {"heart": true})
	_quiet(m)
	var H: Heart = m.heart
	var rl := Heart.rules()
	var k := float(Data.CLASSES["medium"]["hp"]) / float(rl["tide_src_hp"])
	var t0 := float(rl["tide_start_s"])
	var close := float(rl["tide_close_s"])
	m.time = t0 - 1.0 - m.sess_t0
	ok(Heart.tide_stage(m) == -1, "no tide stage before the tide starts")
	var stages_ok := true
	for st in Heart.TIDE_STAGES:
		m.time = t0 + close * (st + 0.5) / Heart.TIDE_STAGES - m.sess_t0
		var want: float = TIDE_SRC[st] * k
		stages_ok = stages_ok and Heart.tide_stage(m) == st and is_equal_approx(Heart.tide_dmg(st), want)
		var ttk := ""
		for c in ["light", "medium", "heavy"]:
			var ticks := ceili(float(Data.CLASSES[c]["hp"]) / Heart.tide_dmg(st))
			ttk += " %s %ds" % [c, ticks * int(rl["tide_tick_s"])]
		var from := t0 + close * st / Heart.TIDE_STAGES
		print("BLIGHT tide stage %d from %.0fs: %.2f a tick (source %.0f), full health dies in%s"
			% [st, from, Heart.tide_dmg(st), TIDE_SRC[st], ttk])
	ok(stages_ok, "the close runs the source's 11 stages, each at its damage scaled by health")
	m.time = t0 + close * 3.0 - m.sess_t0
	ok(Heart.tide_stage(m) == Heart.TIDE_STAGES - 1, "the last stage holds once the ring is closed")
	# a live tick: stage 2, the player outside the ring loses the stage's damage, the armor stays
	m.time = t0 + close * 2.5 / Heart.TIDE_STAGES - m.sess_t0
	var P: Hunter = m.player
	var far := H.site + Vector3(Heart.tide_r(m) + 20.0, 0, 0)
	P.teleport(m.world.free_spot_near(far, [], 1.0, 0.45, 15.0))
	var outside := Vector2(P.pos.x - H.site.x, P.pos.z - H.site.z).length() > Heart.tide_r(m)
	var hp0 := P.hp
	var ar0 := P.armor
	_run(m, float(rl["tide_tick_s"]) * 2.0 + 0.1)
	var lost := hp0 - P.hp
	print("BLIGHT tide live: outside %s, lost %.2f health in two ticks, armor %.0f -> %.0f"
		% [outside, lost, ar0, P.armor])
	var two_ticks := absf(lost - Heart.tide_dmg(2) * 2.0) < 0.5
	ok(outside and two_ticks and P.armor == ar0, "outside the ring: the stage's damage a tick, past armor")
	P.teleport(m.world.free_spot_near(H.site, [], 1.0, 0.45, 6.0))
	hp0 = P.hp
	_run(m, float(rl["tide_tick_s"]) * 2.0 + 0.1)
	ok(P.hp >= hp0, "inside the ring the tide doesn't hurt")
	m.queue_free()
