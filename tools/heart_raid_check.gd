extends RefCounted
## --heart-raid-check: Heart Raid (scripts/match/heart_raid.gd, content/rules/heart_raid.json), headless.
## Never touches the save.
##   1. the raid's Boki (BokiModes + stand-ins): Normal only commons, Hard adds rares, Nightmare very rares;
##      each stand-in has its raid line's rarity; an Expedition's wild pool is BokiModes' own.
##   2. an Expedition builds no raid: rival squads, lairs and exits as before, the Heart not held shut.
##   3. whole raids (you on autopilot, bots in the other seats): solo Normal and a squad of 4 on each
##      difficulty, on the match clock to a result: one squad only, no lairs or exits, the Heart held shut,
##      waves on their fixed clock, each marked warn_s before at its fixed gates and coming out there (the
##      same gates every raid), waves scaled to the squad and difficulty, under the cap; won or lost, never a
##      stall. A line a minute.
##   4. the boss: Nightmare's has one more attack (the Colossus's rockfall, telegraphed), Normal's not.
##   5. the win: the boss down opens the Heart's final seat, the squad holds the ring and leaves with the
##      raid's reward (an egg of the raid's Boki at its difficulty), and the results line says so.
## --heart-raid-check=sim runs only part 3 (and --seed=N picks the raids' seed).

const SIMS := [[1, "normal"], [4, "normal"], [4, "hard"], [4, "nightmare"]]
const NEAR_GATE := 3.5        # m: a wave monster comes out this close to its marked gate (spread + clear spot)

var bad := 0
var first_wave := {}           # "squad difficulty" -> monsters in wave 1
var gates_seen := {}           # "squad difficulty" -> wave 1's marked gate spots

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
	for sim in SIMS:
		await _sim(main, sim[0], sim[1], seed_v)
	if first_wave.size() == SIMS.size():
		var w: Array = SIMS.map(func(x): return int(first_wave["%d %s" % x]))
		ok(w[1] > w[0], "a squad of 4 meets a bigger first wave (%d) than a solo (%d)" % [w[1], w[0]])
		ok(w[3] > w[2] and w[2] > w[1], "Hard and Nightmare send bigger waves: %s" % str(w))
		var spots: Array = gates_seen.values()
		ok(spots.all(func(x): return x == spots[0]), "every raid marks the same gates for wave 1 %s" % str(spots[0]))
	if not sim_only:
		await _boss_extra(main)
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

# ------------------------------------------------------------------ 1. the raid's Boki
func _tables() -> void:
	var tiers := {}
	for d in HeartRaid.difficulties():
		var pool := HeartRaid.boki(d)
		var got := {}
		for sp in pool:
			got[String(BokiModes.of(sp)["rarity"])] = true
		tiers[d] = got.keys()
		print("HRAID %s Boki: %s" % [d, str(pool)])
	ok(tiers["normal"] == ["common"], "Normal: the raid's commons only %s" % str(tiers["normal"]))
	ok(tiers["hard"].size() == 2 and not tiers["hard"].has("very_rare"), "Hard: + rares %s" % str(tiers["hard"]))
	ok(tiers["nightmare"].size() == 3, "Nightmare: + very rares %s" % str(tiers["nightmare"]))
	var lines: Dictionary = BokiModes.rules()["lines"]
	var stand: Dictionary = HeartRaid.rules()["stand_ins"]
	var off: Array = stand.keys().filter(func(l): return not l.begins_with("_") and (
		lines[l]["mode"] != HeartRaid.MODE or lines[l]["rarity"] != BokiModes.of(String(stand[l]))["rarity"]))
	ok(off.is_empty(), "each stand-in has its raid line's rarity %s" % str(off))
	ok(HeartRaid.site_pool({}, "wild") == BokiModes.site_pool("expedition", "wild"),
		"an Expedition's wild spots draw BokiModes' Expedition pool")
	ok(HeartRaid.site_pool(HeartRaid.opts(1, "hard"), "wild") == HeartRaid.boki("hard"),
		"a raid's wild spots draw the raid's Boki at its difficulty")

# ------------------------------------------------------------------ 2. an Expedition is untouched
func _expedition(main: Node) -> void:
	var m := _match(main, {"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true, "heart": true})
	ok(m.heart_raid == null and m.heart != null and not m.heart.locked,
		"an Expedition: no raid, the Heart not held shut")
	ok(m.hunters.any(func(h): return h.team != 0), "an Expedition still has rival squads")
	ok(not m.exits.list.is_empty() and not m.lairs.list.is_empty(), "an Expedition still has its outposts and lairs")
	await _drop(main, m)

# ------------------------------------------------------------------ 3. whole raids
func _sim(main: Node, sq: int, diff: String, seed_v: int) -> void:
	var tag := "%d %s" % [sq, diff]
	var o := HeartRaid.opts(sq, diff)
	o.merge({"seed": seed_v, "tier": 0, "autoplay": true, "no_drop": true, "sim_keep": true})
	var tb := Time.get_ticks_msec()
	var m := _match(main, o)
	var rd: HeartRaid = m.heart_raid
	ok(rd != null, "squad %s: the raid is built" % tag)
	if rd == null:
		await _drop(main, m)
		return
	var ours := m.hunters.all(func(h): return h.team == 0)
	ok(m.hunters.size() == sq and ours, "squad %s: one squad of %d, no rivals" % [tag, sq])
	ok(m.lairs.list.is_empty() and m.exits.list.is_empty(), "squad %s: no lairs, no outposts" % tag)
	ok(m.heart.locked and rd.squad_n == sq and rd.difficulty == diff,
		"squad %s: the Heart held shut, scaled for %d at %s" % [tag, sq, diff])
	print("HRAID squad %s built in %d ms, Heart at %s" % [tag, Time.get_ticks_msec() - tb, str(m.heart.site.round())])
	var next_log := 60.0
	var cap_hit := 0
	var max_foes := 0
	var max_mobs := 0
	var n_step := 0
	var t_wall := Time.get_ticks_msec()
	var ended_at := -1.0
	var marked_at := {}          # wave index -> session time its gates were marked
	var late: Array = []         # "wave: what" for a wave that broke the clarity rule
	var sent_n := 0
	while m.time < m.length + 2.0 and (ended_at < 0.0 or m.time < ended_at + 1.5):
		m.step(Match.DT)
		n_step += 1
		if n_step % 120 == 0:
			await main.get_tree().process_frame
		if ended_at < 0.0 and not m.result.is_empty():
			ended_at = m.time
		if not marked_at.has(rd.gates.marked_wave):
			marked_at[rd.gates.marked_wave] = m.sess_time()
			if rd.gates.marked_wave == 0:
				gates_seen[tag] = rd.gates.marks.map(func(mk): return mk["at"].round())
		if rd.wave > sent_n:
			sent_n = rd.wave
			_wave_out(rd, marked_at, late)
		max_foes = maxi(max_foes, rd.foes.size())
		if rd.foes.size() > int(rd.scale("cap")):
			cap_hit += 1
		if m.time >= next_log:
			next_log += 60.0
			var alive := m.mobs.filter(func(x): return not x.dead).size()
			max_mobs = maxi(max_mobs, alive)
			var up := m.hunters.filter(func(h): return not h.out and not h.extracted and not h.downed).size()
			var fmt := "HRAID squad %s %s %s wave %d foes %d mobs %d up %d/%d you %d hp %d m to the Heart, tide %d m"
			print(fmt % [
				tag,
				_clock(m.time), HeartRaid.P.keys()[rd.phase], rd.wave, rd.foes.size(), alive, up, sq, int(m.player.hp),
				int(m.player.flat_dist(m.heart.site)), int(Heart.tide_r(m))])
	var wall_s := (Time.get_ticks_msec() - t_wall) / 1000.0
	for line in rd.trail:
		print("HRAID squad %s   %s" % [tag, line])
	var w1: Array = rd.trail.filter(func(l): return String(l).contains("wave 1:"))
	var w1_t := float(String(w1[0]).split(" ", false)[0]) if not w1.is_empty() else -1.0
	ok(absf(w1_t - HeartRaid.r("first_wave_s")) <= HeartRaid.THINK_S + 0.05,
		"squad %s: the first wave at %ds" % [tag, int(HeartRaid.r("first_wave_s"))])
	if not w1.is_empty():
		first_wave[tag] = int(String(w1[0]).split(":")[1].split(" ", false)[0])
	ok(late.is_empty() and sent_n > 0, "squad %s: %d waves on the clock, marked %ds before, out of their gates %s" % [
		tag, sent_n, int(HeartRaid.r("warn_s")), str(late)])
	ok(cap_hit == 0, "squad %s: wave monsters never over the cap of %d (most at once %d)" % [
		tag, int(rd.scale("cap")), max_foes])
	ok(ended_at >= 0.0, "squad %s: the raid ended with a result (%s at %s)" % [
		tag, str(m.result.get("why", "?")), _clock(ended_at)])
	var ended := rd.phase in [HeartRaid.P.WON, HeartRaid.P.LOST]
	ok(ended, "squad %s: the raid is %s" % [tag, HeartRaid.P.keys()[rd.phase]])
	var sm := rd.summary()
	ok(bool(sm["won"]) == (rd.phase == HeartRaid.P.WON),
		"squad %s: the summary agrees: %s" % [tag, HeartRaid.result_line(sm)])
	print("HRAID squad %s: %s, %d waves, %d wave monsters, most mobs alive %d; %.1f s wall for %s (%.2f ms a step)" % [
		tag, HeartRaid.P.keys()[rd.phase], rd.wave, rd.sent, max_mobs, wall_s, _clock(m.time),
		wall_s * 1000.0 / maxf(1.0, n_step)])
	await _drop(main, m)

## The wave just sent: on its fixed time, marked warn_s before, and every monster of it out of a marked gate.
func _wave_out(rd: HeartRaid, marked_at: Dictionary, late: Array) -> void:
	var i := rd.wave - 1
	var due := HeartRaid.r("first_wave_s") + i * HeartRaid.r("wave_every_s")
	var t := rd.m.sess_time()
	var warned := t - float(marked_at.get(i, t))
	if absf(t - due) > HeartRaid.THINK_S + 0.05:
		late.append("%d: out at %.1f, due %.1f" % [i + 1, t, due])
	if warned < HeartRaid.r("warn_s") - HeartRaid.THINK_S - 0.05:
		late.append("%d: marked only %.1f s before" % [i + 1, warned])
	var at: Array = rd.gates.marks.map(func(mk): return mk["at"])
	for mb in rd.foes:
		if mb.has_meta("hr_seen"):
			continue
		mb.set_meta("hr_seen", true)
		var near: bool = at.any(func(p): return Vector2(p.x - mb.pos.x, p.z - mb.pos.z).length() < NEAR_GATE)
		if not near:
			late.append("%d: a %s out at %s, off its gates" % [i + 1, mb.mkind, str(mb.pos.round())])

# ------------------------------------------------------------------ 4. the boss's extra attack
func _boss_extra(main: Node) -> void:
	for diff in ["normal", "nightmare"]:
		var o := HeartRaid.opts(4, diff)
		o.merge({"seed": 23, "tier": 0, "no_drop": true, "sim_keep": true})
		var m := _match(main, o)
		var rd: HeartRaid = m.heart_raid
		rd._spawn_boss()
		var b := rd.boss as Boss
		var has := b.attacks().has("rockfall")
		ok(has == (diff == "nightmare"), "%s: the boss's attacks %s" % [diff, str(b.attacks())])
		if diff == "nightmare":
			b._atk_rockfall()
			ok(b.teles.size() >= 4, "Nightmare's rockfall marks its circles first (%d)" % b.teles.size())
			var k := float(HeartRaid.rules()["difficulty"][diff]["dmg"])
			ok(is_equal_approx(b.dmg_mult, k * (1.0 + (float(m.T.get("mob", 1.0)) - 1.0) * 0.6)),
				"Nightmare's boss hits %.2fx" % k)
		await _drop(main, m)

# ------------------------------------------------------------------ 5. the win
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
	ok(HeartRaid.boki(rd.difficulty).has(sp), "its reward egg is one of the raid's %s Boki (%s)" % [rd.difficulty, sp])
	ok(int(hb.get("gems", 0)) == int(HeartRaid.reward()["gems"]), "the raid's own reward, not the Expedition's")
	var said := HeartRaid.result_line(rd.summary())
	ok(said.begins_with("Heart Raid (Normal) won"), "the results line: %s" % said)
	await _drop(main, m)

static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
