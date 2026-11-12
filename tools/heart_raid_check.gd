extends RefCounted
## --heart-raid-check: Heart Raid (scripts/match/heart_raid.gd, content/rules/heart_raid.json), headless.
## Never touches the save.
##   1. the spawn tables: the raid-only Boki are in the raid's wild table and not in the Expedition's.
##   2. an Expedition builds no raid: rival squads, lairs and exits as before, the Heart not held shut.
##   3. whole raids, solo and with a squad of 4 (you on autopilot, bots in the other seats), on the match
##      clock to a result: one squad only, no lairs or exits, the Heart held shut, the first wave on time,
##      waves scaled to the squad, wave monsters under the cap; won or lost, never a stall. A line a minute.
##   4. the win: the boss down opens the Heart's final seat, the squad holds the ring and leaves with the
##      raid's reward (an egg of a raid-only Boki), and the results line says so.
## --heart-raid-check=sim runs only part 3 (and --seed=N picks the raids' seed).

var bad := 0
var first_wave := {}           # squad size -> monsters in wave 1

func ok(cond: bool, what: String) -> void:
	print("HRAID %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var args := Array(OS.get_cmdline_user_args())
	var seed_v := 11
	for a in args:
		if String(a).begins_with("--seed="): seed_v = int(String(a).substr(7))
	var sim_only := args.has("--heart-raid-check=sim")
	if not sim_only:
		_tables()
		await _expedition(main)
	for sq in [1, 4]:
		await _sim(main, sq, seed_v)
	if first_wave.size() == 2:
		ok(int(first_wave[4]) > int(first_wave[1]),
			"a squad of 4 meets a bigger first wave (%d) than a solo (%d)" % [first_wave[4], first_wave[1]])
	if not sim_only:
		await _win(main)
	print("HRAID %s" % ("PASS" if bad == 0 else "FAIL %d" % bad))
	main.get_tree().quit(0 if bad == 0 else 1)

func _match(main: Node, o: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	return m

func _drop(main: Node, m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ 1. the spawn tables
func _tables() -> void:
	var only: Array = Data.KIN.keys().filter(func(k): return String(Data.KIN[k].get("only_in", "")) == HeartRaid.MODE)
	ok(only.size() == 2, "two raid-only Boki: %s" % str(only))
	var exp_t := Data.wild_kin("")
	var raid_t := Data.wild_kin(HeartRaid.MODE)
	ok(only.all(func(k): return raid_t.has(k) and not exp_t.has(k)), "they are in the raid's wild table only")
	ok(raid_t.size() == exp_t.size() + only.size(), "every other common Boki is in both tables")
	ok(only.all(func(k): return Data.common_kin().has(k)),
		"not an ownership lock: still common kin (starters, eggs, trades)")

# ------------------------------------------------------------------ 2. an Expedition is untouched
func _expedition(main: Node) -> void:
	var m := _match(main, {"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true, "heart": true})
	ok(m.heart_raid == null and m.heart != null and not m.heart.locked,
		"an Expedition: no raid, the Heart not held shut")
	ok(m.hunters.any(func(h): return h.team != 0), "an Expedition still has rival squads")
	ok(not m.exits.list.is_empty() and not m.lairs.list.is_empty(), "an Expedition still has its outposts and lairs")
	await _drop(main, m)

# ------------------------------------------------------------------ 3. whole raids
func _sim(main: Node, sq: int, seed_v: int) -> void:
	var o := HeartRaid.opts(sq)
	o.merge({"seed": seed_v, "tier": 0, "autoplay": true, "no_drop": true, "sim_keep": true})
	var tb := Time.get_ticks_msec()
	var m := _match(main, o)
	var rd: HeartRaid = m.heart_raid
	ok(rd != null, "squad %d: the raid is built" % sq)
	if rd == null:
		await _drop(main, m)
		return
	var ours := m.hunters.all(func(h): return h.team == 0)
	ok(m.hunters.size() == sq and ours, "squad %d: one squad of %d, no rivals" % [sq, sq])
	ok(m.lairs.list.is_empty() and m.exits.list.is_empty(), "squad %d: no lairs, no outposts" % sq)
	ok(m.heart.locked and rd.squad_n == sq, "squad %d: the Heart held shut, scaled for %d" % [sq, sq])
	print("HRAID squad %d built in %d ms, Heart at %s" % [sq, Time.get_ticks_msec() - tb, str(m.heart.site.round())])
	var next_log := 60.0
	var cap_hit := 0
	var max_foes := 0
	var max_mobs := 0
	var n_step := 0
	var t_wall := Time.get_ticks_msec()
	var ended_at := -1.0
	while m.time < m.length + 2.0 and (ended_at < 0.0 or m.time < ended_at + 1.5):
		m.step(Match.DT)
		n_step += 1
		if n_step % 120 == 0:
			await main.get_tree().process_frame
		if ended_at < 0.0 and not m.result.is_empty():
			ended_at = m.time
		max_foes = maxi(max_foes, rd.foes.size())
		if rd.foes.size() > int(rd.scale("cap")):
			cap_hit += 1
		if m.time >= next_log:
			next_log += 60.0
			var alive := m.mobs.filter(func(x): return not x.dead).size()
			max_mobs = maxi(max_mobs, alive)
			var up := m.hunters.filter(func(h): return not h.out and not h.extracted and not h.downed).size()
			var fmt := "HRAID squad %d %s %s wave %d foes %d mobs %d up %d/%d you %d hp %d m to the Heart, tide %d m"
			print(fmt % [
				sq,
				_clock(m.time), HeartRaid.P.keys()[rd.phase], rd.wave, rd.foes.size(), alive, up, sq, int(m.player.hp),
				int(m.player.flat_dist(m.heart.site)), int(Heart.tide_r(m))])
	var wall_s := (Time.get_ticks_msec() - t_wall) / 1000.0
	for line in rd.trail:
		print("HRAID squad %d   %s" % [sq, line])
	var w1: Array = rd.trail.filter(func(l): return String(l).contains("wave 1:"))
	var w1_t := float(String(w1[0]).split(" ", false)[0]) if not w1.is_empty() else -1.0
	ok(absf(w1_t - HeartRaid.r("first_wave_s")) <= HeartRaid.THINK_S + 0.05,
		"squad %d: the first wave at %ds" % [sq, int(HeartRaid.r("first_wave_s"))])
	if not w1.is_empty():
		first_wave[sq] = int(String(w1[0]).split(":")[1].split(" ", false)[0])
	ok(cap_hit == 0, "squad %d: wave monsters never over the cap of %d (most at once %d)" % [
		sq, int(rd.scale("cap")), max_foes])
	ok(ended_at >= 0.0, "squad %d: the raid ended with a result (%s at %s)" % [
		sq, str(m.result.get("why", "?")), _clock(ended_at)])
	ok(rd.phase in [HeartRaid.P.WON, HeartRaid.P.LOST], "squad %d: the raid is %s" % [sq, HeartRaid.P.keys()[rd.phase]])
	var sm := rd.summary()
	ok(bool(sm["won"]) == (rd.phase == HeartRaid.P.WON),
		"squad %d: the summary agrees: %s" % [sq, HeartRaid.result_line(sm)])
	print("HRAID squad %d: %s, %d waves, %d wave monsters, most mobs alive %d; %.1f s wall for %s (%.2f ms a step)" % [
		sq, HeartRaid.P.keys()[rd.phase], rd.wave, rd.sent, max_mobs, wall_s, _clock(m.time),
		wall_s * 1000.0 / maxf(1.0, n_step)])
	await _drop(main, m)

# ------------------------------------------------------------------ 4. the win
func _win(main: Node) -> void:
	var o := HeartRaid.opts(1)
	o.merge({"seed": 23, "tier": 0, "no_drop": true, "god": true, "sim_keep": true})
	var m := _match(main, o)
	var rd: HeartRaid = m.heart_raid
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var p := m.player
	p.ctrl = "idle"
	rd._spawn_boss()
	var b := rd.boss as Boss
	ok(b != null and not b.dormant and rd.phase == HeartRaid.P.BOSS, "the boss rises awake at the Heart")
	var boss_name := String(HeartRaid.rules()["boss"]["name"])
	ok(b != null and String(b.md["name"]) == boss_name, "it is %s" % boss_name)
	p.teleport(m.world.free_spot_near(m.heart.site + Vector3(-4, 0, 0), [], 1.0, 0.45, 4.0))
	ok(m.lairs.boss_for(p) == b, "standing by it, the HUD's boss bar shows it")
	b.hurt(b.max_hp * 10.0, p, {})
	for i in int(1.0 / Match.DT):
		m.step(Match.DT)
	ok(rd.phase == HeartRaid.P.HOLD and m.heart.state == Heart.S.FINAL, "the boss down opens the Heart's final seat")
	p.teleport(m.world.free_spot_near(m.heart.site + Vector3(2.0, 0, 0), [], 1.0, 0.45, 1.5))
	p.vel = Vector3.ZERO
	var need := Heart.r("final_hold_s") + 2.0
	for i in int(need / Match.DT):
		m.step(Match.DT)
		if p.extracted:
			break
	for i in int(1.0 / Match.DT):
		m.step(Match.DT)
	ok(p.extracted and m.heart.state == Heart.S.DONE, "holding the ring takes the squad out")
	ok(rd.phase == HeartRaid.P.WON and bool(rd.summary()["won"]), "the raid is won")
	var hb: Dictionary = m.result.get("heart", {})
	var sp := String((hb.get("egg", {}) as Dictionary).get("sp", ""))
	var only := String(Data.KIN.get(sp, {}).get("only_in", ""))
	ok(only == HeartRaid.MODE, "its reward egg is a raid-only Boki (%s)" % sp)
	ok(int(hb.get("gems", 0)) == int(HeartRaid.reward()["gems"]), "the raid's own reward, not the Expedition's")
	var said := HeartRaid.result_line(rd.summary())
	ok(said.begins_with("Heart Raid won"), "the results line: %s" % said)
	await _drop(main, m)

static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
