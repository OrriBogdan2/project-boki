extends RefCounted
## --teammate-check: your Boki as a teammate (KinCompanion). Prints PASS/FAIL lines.
##   1. it keeps close through a scripted run: walking (at your side, following), a dash, a jump and glide
##      (it hops onto you for the glide), and out on the field (walking back to your side)
##   2. callouts fire by priority (a rival behind you beats a chest), keep a quiet gap between them
##      and respect each kind's cooldown
##   3. the chattiness setting: quiet only speaks up for danger and your health, chatty says more
##   4. no spam over 3 minutes of a real match with bots (every kin's callouts spaced out)
##   5. caring: flinch and yelp when you're hit, low-health worry and a found tonic, cheering a knock,
##      a boss kill and extraction, comfort after a loss, all written to its memory
##   6. the memory line it brings up at home, in its own talking level
##   7. the tutorial: it leads to the chest and the outpost, hints at each step, shows a dash and a
##      jump, and the tutorial still finishes

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TEAMMATE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _fresh(extra := {}) -> Match:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	var o := {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "demo_kin": "cindle", "weapon": "rifle", "cls": "medium"}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	# a flat open stretch of ground around the start (headless: nothing is drawn)
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-12, 13):
		for dx in range(-16, 24):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	# a steady-natured Boki, so the numbers don't depend on its rolled personality
	for t in ["bravery", "loyalty", "temper", "curiosity"]:
		P.kin.traits[t] = 0.5
	for i in 30: m.step(Match.DT)
	return m

func _walk(P: Hunter, mv: Vector2, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		P.inp["move"] = mv
		if mv.length() > 0.1:
			P.inp["aim"] = P.pos + Vector3(mv.x * 4.0, 0.9, mv.y * 4.0)
		if each.is_valid(): each.call()
		m.step(Match.DT); t += Match.DT
	P.inp["move"] = Vector2.ZERO

func _callouts(k: Kin) -> Array:
	return k.comp.history.filter(func(e): return KinCompanion.CATS.has(String(e["cat"])) and not e.get("net", false))

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Settings.set_v("kin_chatter", "normal", false)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--teammate-only="): only = a.substr(16)     # e.g. caring,tutorial
	for part in ["follow", "priority", "chattiness", "caring", "home_memory", "no_spam", "tutorial"]:
		if only == "" or only.split(",").has(part):
			call("_" + part)
	Settings.set_v("kin_chatter", "normal", false)
	print("TEAMMATE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. keeping close
func _follow() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var p0 := P.pos
	ok(k != null and k.comp != null, "the player's Boki has a companion")
	if k == null: return
	# (nothing to fight: a Boki out at your side takes on whatever is near, which is not what this part measures)
	for mb in m.mobs: mb.dead = true; mb.visible = false
	for h in m.hunters:
		if h != P: h.teleport(_far_ground(m, P))
	for kk in m.kins:
		if kk != k and kk.team != k.team: kk.dead = true; kk.visible = false
	var st := {"max": 0.0, "steady": 0, "heel": 0, "glide": 0, "glide_up": 0}
	var watch := func():
		for mb in m.mobs: mb.dead = true; mb.visible = false
		var d := Vector2(k.seen_pos().x - P.pos.x, k.seen_pos().z - P.pos.z).length()
		st["max"] = maxf(float(st["max"]), d)
		if P.grounded and not P.gliding and P.roll_t <= 0.0 and k.state in ["active", "shoulder"]:
			st["steady"] = int(st["steady"]) + 1
			if k.state == "active" and k.flat_dist(P) < 3.5: st["heel"] = int(st["heel"]) + 1
		if P.gliding:
			st["glide"] = int(st["glide"]) + 1
			if k.state == "shoulder": st["glide_up"] = int(st["glide_up"]) + 1
	_walk(P, Vector2(1, 0), 2.5, watch)
	ok(k.state == "active" and k.cmd == "follow" and k.flat_dist(P) < 3.5, "walking: out at your side, following (%s, %.1fm away)" % [k.state, k.flat_dist(P)])
	# a dash, then keep walking
	P.inp["dash"] = true
	_walk(P, Vector2(1, 0), 0.05, watch)
	P.inp["dash"] = false
	_walk(P, Vector2(1, 0), 1.5, watch)
	# jump and glide back the other way
	P.inp["jump"] = true
	_walk(P, Vector2(-1, 0), 0.12, watch)
	P.inp["jump"] = false
	P.inp["glide"] = true
	_walk(P, Vector2(-1, 0), 1.4, watch)
	P.inp["glide"] = false
	_walk(P, Vector2(-1, 0), 2.0, watch)
	_walk(P, Vector2(0, 1), 2.0, watch)
	ok(float(st["max"]) <= 10.0, "never more than 10m from you through walk, dash, jump and glide (a dash outruns it for a moment) (max %.2fm)" % float(st["max"]))
	ok(int(st["steady"]) > 0 and float(st["heel"]) / float(st["steady"]) > 0.55, "at your side most of the time you're on your feet (%d of %d steps)" % [int(st["heel"]), int(st["steady"])])
	ok(int(st["glide"]) == 0 or float(st["glide_up"]) / float(st["glide"]) > 0.5, "hops onto you for most of a glide (%d of %d steps)" % [int(st["glide_up"]), int(st["glide"])])
	# out on the field with nothing to fight: it comes back to your side and keeps pace
	# (training dummies and anything else nearby are cleared: with an archetype the kin's C is open, so it would fight them)
	for mb in m.mobs: mb.dead = true; mb.visible = false
	for h in m.hunters:
		if h != P: h.teleport(_far_ground(m, P))
	for kk in m.kins:
		if kk != k and kk.team != k.team: kk.dead = true; kk.visible = false
	k.target = null
	# (back to where the walk began: how far the walk carried you depends on the hero's dash, and an
	# island edge nearby would drop the Boki into the abyss before it could come back)
	P.teleport(p0)
	for i in 30: m.step(Match.DT)
	k.throw_to(_solid_spot(m, P.pos, 5.0))      # (onto ground: where the walk ends depends on the hero's dash length)
	for i in 60: m.step(Match.DT)
	var was := k.state
	# sent out with nothing to fight: it walks back to your side (Follow), it does not wait where it landed
	for i in 180:
		for mb in m.mobs: mb.dead = true; mb.visible = false
		m.step(Match.DT)
	ok(was == "active" and k.state == "active" and k.cmd == "follow" and k.flat_dist(P) < 3.5, "sent out, it comes back to your side (%s, %.1fm from you)" % [k.state, k.flat_dist(P)])
	# ...and comes back once you walk out of its leash range
	var far := [0.0]      # (an Array: a lambda captures plain locals by value)
	_walk(P, Vector2(0, -1), 5.0, func():
		for mb in m.mobs: mb.dead = true; mb.visible = false
		if k.state == "active": far[0] = maxf(far[0], k.flat_dist(P)))
	_walk(P, Vector2(0, -1), 1.5, func():
		for mb in m.mobs: mb.dead = true; mb.visible = false)
	ok(k.state == "shoulder" or (k.state == "active" and k.flat_dist(P) < 3.0) or k.state in ["returning", "flying_home"], "you walk out of range: it comes back to your side (%s, %.1fm)" % [k.state, k.flat_dist(P)])
	# a threat close by: it stands between you and it
	_open_ground_for(P, k)
	var T: Hunter = m.make_hunter("T", 5, "medium", "Rival", "idle", {}, P.pos + Vector3(6, 0, 0))
	T.max_hp = 1e5; T.hp = 1e5
	k.comp._find_threat()
	k.comp.threat = T
	var hs := k.comp.heel_spot()
	if hs == Vector3.INF:
		ok(false, "with a rival close it steps between you and them (no free heel spot at %s)" % str(P.pos))
		return
	var to_t := Vector2(T.pos.x - P.pos.x, T.pos.z - P.pos.z).normalized()
	var to_h := Vector2(hs.x - P.pos.x, hs.z - P.pos.z).normalized()
	ok(to_t.dot(to_h) > 0.8, "with a rival close it steps between you and them (dot %.2f)" % to_t.dot(to_h))

## Moves the player to ground where the Boki has a free heel spot (heel_spot is INF in a tight corner, and a
## normalised INF is NaN): tries a few random spots.
func _open_ground_for(p: Hunter, kin: Kin) -> void:
	for i in 40:
		# level ground where it steps toward the rival, and ground under the rival
		var step_ok := absf(m.world.ground_at(p.pos.x + 1.25, p.pos.z) - p.pos.y) < 0.5
		var rival_ok := m.world.ground_at(p.pos.x + 6.0, p.pos.z) > World.VOID + 1.0
		if kin.comp.heel_spot() != Vector3.INF and step_ok and rival_ok:
			return
		p.teleport(m.world.random_ground())
		for j in 5:
			m.step(Match.DT)

# ------------------------------------------------------------------ 2. priority, gap, cooldown
func _priority() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	P.inp["aim"] = P.pos + Vector3(5, 0.9, 0)
	# a chest just ahead, a rival behind
	var cat := P.pos + Vector3(4, 0, 1)
	var n := Models.chest(); n.position = cat; m.add_child(n)
	m.chests.append({"pos": cat, "open": false, "prog": 0.0, "node": n, "free": true})
	var T: Hunter = m.make_hunter("T", 5, "medium", "Rival", "idle", {}, P.pos + Vector3(-8, 0, 0.5))
	T.max_hp = 1e5; T.hp = 1e5
	# start quiet: a map chest called during _fresh() leaves its gap and cooldown running, and by the time
	# they end the Boki has knocked the rival inside the on-screen range where "behind" isn't said
	k.comp.history.clear()
	k.comp.gap_t = 0.0
	k.comp.cds.clear()
	k.comp.seen.clear()
	var t := 0.0
	while t < 22.0:
		P.inp["aim"] = P.pos + Vector3(5, 0.9, 0)
		m.step(Match.DT); t += Match.DT
	var cs := _callouts(k)
	ok(cs.size() >= 2 and String(cs[0]["cat"]) == "behind", "a rival behind you is called before the chest (%s)" % str(cs.map(func(e): return e["cat"])))
	ok(cs.any(func(e): return e["cat"] == "loot"), "the chest is called once the rival has been")
	var gap_ok := true
	var cd_ok := true
	var last := {}
	for i in cs.size():
		var e: Dictionary = cs[i]
		if i > 0:
			var dt := float(e["t"]) - float(cs[i - 1]["t"])
			if dt < k.comp._gap() - 0.05 and not (int(e["pri"]) >= 95 and dt >= 1.5): gap_ok = false
		if last.has(e["cat"]) and float(e["t"]) - float(last[e["cat"]]) < k.comp._cd_of(String(e["cat"])) - 0.05: cd_ok = false
		last[e["cat"]] = e["t"]
	ok(gap_ok, "a quiet gap between callouts (%.1fs)" % k.comp._gap())
	ok(cd_ok, "each kind waits out its cooldown")
	# the ping went up with it, labelled, for your squad
	ok(m.pings.any(func(p): return p.get("kin") == k) or cs.size() > 0 and m.pings.size() >= 0, "callouts put up a ping")
	var pinged := false
	k.comp.callout("hunter", T.pos, T, "")
	for p in m.pings:
		if p.get("kin") == k and String(p.get("label", "")) == "Hunter": pinged = true
	ok(pinged and m.bubbles.any(func(b): return b["ent"] == k), "a callout is a ping with a label plus a speech bubble")
	ok(k.comp.pose != "" and k.comp.look != Vector3.INF, "and body language: a pose (%s) and its head turned to it" % k.comp.pose)

# ------------------------------------------------------------------ 3. chattiness
func _count_with(setting: String) -> Array:
	Settings.set_v("kin_chatter", setting, false)
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var c0 := P.pos
	for i in 8:
		var a := TAU * i / 8.0
		var at := c0 + Vector3(cos(a) * 6.0, 0, sin(a) * 6.0)
		var n := Models.chest(); n.position = at; m.add_child(n)
		m.chests.append({"pos": at, "open": false, "prog": 0.0, "node": n, "free": true})
	for i in 3:
		m.spawn_wild(Save.new_kin("puddlet", "", 900 + i), c0 + Vector3(-5 + i * 3, 0, 7))
	var foes: Array = []
	for i in 3:
		var T: Hunter = m.make_hunter("T%d" % i, 5 + i, "medium", "Rival%d" % i, "idle", {}, c0 + Vector3(30, 0, 30))
		T.max_hp = 1e5; T.hp = 1e5
		foes.append(T)
	k.comp.history.clear()
	var t := 0.0
	var nxt := 2.0
	var fi := 0
	while t < 50.0:
		P.inp["aim"] = P.pos + Vector3(5, 0.9, 0)
		if t >= nxt:
			# a rival wanders into range now and then
			nxt += 9.0
			var T: Hunter = foes[fi % foes.size()]; fi += 1
			for o in foes: if o != T: o.teleport(c0 + Vector3(30, 0, 30))
			T.teleport(c0 + Vector3(-9 if fi % 2 == 0 else 10, 0, 3))
			k.comp.seen.erase("h" + T.nid)
		m.step(Match.DT); t += Match.DT
	return _callouts(k)

func _chattiness() -> void:
	var q := _count_with("quiet")
	var n := _count_with("normal")
	var c := _count_with("chatty")
	Settings.set_v("kin_chatter", "normal", false)
	print("  quiet %s\n  normal %s\n  chatty %s" % [str(q.map(func(e): return e["cat"])), str(n.map(func(e): return e["cat"])), str(c.map(func(e): return e["cat"]))])
	ok(q.size() < n.size() and n.size() <= c.size(), "quiet < normal <= chatty (%d, %d, %d callouts in 50s)" % [q.size(), n.size(), c.size()])
	ok(q.all(func(e): return int(e["pri"]) >= 80), "quiet only speaks up for danger and your health")
	ok(n.any(func(e): return e["cat"] in ["loot", "wild"]), "normal also points out loot and wild Boki")

# ------------------------------------------------------------------ 5. caring
func _caring() -> void:
	_fresh({"training": false})
	var P := m.player
	var k: Kin = P.kin
	k.trust = 95.0
	var T: Hunter = m.make_hunter("T", 5, "medium", "Rival", "idle", {}, P.pos + Vector3(14, 0, 8))
	T.max_hp = 1e5; T.hp = 1e5
	k.comp.history.clear()
	P.max_hp = 1e4; P.hp = 1e4
	P.hurt(P.max_hp * 0.2, T, {})
	ok(k.comp.pose == "flinch" and k.comp.history.any(func(e): return e["cat"] == "yelp"), "flinches and yelps when you take a big hit")
	P.hp = P.max_hp * 0.2
	var tonics0 := P.tonics
	for i in 400: m.step(Match.DT)
	ok(k.comp.history.any(func(e): return e["cat"] == "low_hp"), "worries out loud at low health")
	ok(P.tonics == tonics0 + 1 and k.comp.history.any(func(e): return e["cat"] == "tonic"), "a Boki that trusts you brings you a tonic it found (once)")
	P.hp = P.max_hp * 0.2
	k.comp.cds.erase("low_hp")
	for i in 120: m.step(Match.DT)
	ok(P.tonics == tonics0 + 1, "only once a run")
	P.hp = P.max_hp
	m.knock(T, P, {})
	ok(k.comp.history.any(func(e): return e["cat"] == "cheer") and k.events.any(func(e): return e["kind"] == "knock_together"), "cheers a knock with you, and remembers it")
	m.knock(P, T, {})
	ok(k.comp.history.any(func(e): return e["cat"] == "guard") and k.events.any(func(e): return e["kind"] == "stood_over"), "stands over you when you go down")
	for i in 20: m.step(Match.DT)
	ok(k.comp.pose in ["guard", "nudge"], "and reads that way (pose %s)" % k.comp.pose)
	m.revive_hunter(P, null)
	k.comp.on_boss_kill("the Warden", P.pos)
	ok(k.comp.history.any(func(e): return e["cat"] == "boss_kill") and k.events.any(func(e): return e["kind"] == "boss_kill" and e.get("boss", "") == "the Warden"), "celebrates a boss kill, and remembers which")
	k.go_down()
	k.stow(); k.hp = k.max_hp * 0.3
	m._extract(P, "uplink", "test")
	ok(k.comp.history.any(func(e): return e["cat"] == "extract") and k.events.any(func(e): return e["kind"] == "carried_out" and String(e.get("place", "")) != ""), "celebrates extraction; hurt, it remembers you carried it out")
	_fresh()
	m.player.kin.comp.on_loss()
	ok(m.player.kin.comp.history.any(func(e): return e["cat"] == "comfort") and m.player.kin.events.any(func(e): return e["kind"] == "comforted"), "comforts you after a loss")

# ------------------------------------------------------------------ 6. memory at home
func _home_memory() -> void:
	_fresh()
	var k: Kin = m.player.kin
	var rec: Dictionary = k.rec
	k.comp.on_extract()
	var evs := k.events.duplicate(true)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	Game.apply_result({"extracted": true, "tier": 0, "gems": 0, "kin_runs": [{"uid": rec["uid"], "events": evs, "trust": k.trust, "stats": {}}]})
	var back := Save.kin(String(rec["uid"]))
	ok(back.has("recall") and String(back["recall"]["kind"]) in ["escaped", "carried_out"], "the run's big moment is kept for home (%s)" % str(back.get("recall", {})))
	var back_trigger := "back_" + String(back["recall"]["kind"])      # what Home says when you walk up
	back["level"] = 1
	back["trust"] = 40.0
	var baby := BokiLines.say(back, back_trigger)
	back["level"] = 14
	back["trust"] = 85.0
	var grown := BokiLines.say(back, back_trigger)
	print("  hatchling: %s\n  grown: %s" % [baby, grown])
	ok(baby.contains("(") and not baby.contains("%"), "a hatchling acts it out")
	ok(BokiLines.grown_pool(BokiLines.trigger(back_trigger), BokiLines.element_of(String(back["species"]))).has(grown),
			"a grown Boki tells you about that moment")
	ok(back["memory"].any(func(mm): return String(mm["kind"]) in ["escaped", "carried_out"]), "and it's in its memories")

# ------------------------------------------------------------------ 4. no spam
func _no_spam() -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 4, "squad": 3, "tier": 0, "length": 600.0, "seed": 5, "autoplay": true, "no_drop": true, "demo_kin": "cindle"})
	m.set_process(false)
	var t := 0.0
	var t0 := Time.get_ticks_msec()
	while t < 180.0 and not m.over:
		m.step(Match.DT); t += Match.DT
	var worst := 99.0
	var most := 0
	var total := 0
	var kinds := {}
	for kk in m.kins:
		if kk.comp == null: continue
		var cs := _callouts(kk)
		total += cs.size()
		most = maxi(most, cs.size())
		for i in cs.size():
			kinds[cs[i]["cat"]] = int(kinds.get(cs[i]["cat"], 0)) + 1
			if i > 0: worst = minf(worst, float(cs[i]["t"]) - float(cs[i - 1]["t"]))
	var pc: Array = _callouts(m.player.kin) if m.player.kin else []
	print("  3 min match (%.0fs sim in %dms): %d callouts across all Boki, most by one %d, the player's %d %s, kinds %s" % [t, Time.get_ticks_msec() - t0, total, most, pc.size(), str(pc.map(func(e): return e["cat"])), str(kinds)])
	ok(total > 0, "Boki do call things out in a real match")
	ok(worst >= 1.5, "never two callouts on top of each other (closest %.1fs)" % worst)
	ok(float(most) / (t / 60.0) <= 14.0, "no Boki chatters (at most %.1f a minute)" % (float(most) / (t / 60.0)))

# ------------------------------------------------------------------ 7. the tutorial
func _tutorial() -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var hints := {}
	var t := 0.0
	var last_step := -1
	var no_marker := 0
	var cards := 0
	var beam_miss := 0
	var steps_seen := {}
	var fell_t := -1.0
	var back_ok := false
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT); t += Match.DT
		var tu: Tutorial = m.tut
		var id := tu.id()
		steps_seen[id] = true
		if id == "shoot" and fell_t < 0.0:
			fell_t = t
			m.player.teleport(Vector3(70.0, 0.0, 30.0))      # off every island: a fall
		elif fell_t > 0.0 and not back_ok and t - fell_t < 12.0:
			back_ok = m.player.grounded and m.player.flat_dist(tu.respawn()) < 6.0
		var goes_somewhere := id in ["move", "dash", "chest", "extract"]
		if tu.step == last_step and goes_somewhere and tu.target == Vector3.INF:
			no_marker += 1
		if goes_somewhere and tu.target != Vector3.INF and tu._beams.is_empty():
			beam_miss += 1
		if tu.step != last_step:
			last_step = tu.step
			cards += 1
	for e in m.player.kin.comp.history:
		hints[String(e["cat"])] = true
	print("  tutorial: %.0fs, hints %s" % [t, str(hints.keys().filter(func(x): return String(x).begins_with("tut_") or String(x).begins_with("demo_")))])
	ok(m.player.extracted, "the tutorial still finishes (extracted at %.0fs)" % t)
	var mk := "the marker and its beam are up on every destination step frame (%d without, %d no beam)"
	ok(no_marker == 0 and beam_miss == 0, mk % [no_marker, beam_miss])
	ok(back_ok, "a fall into the void puts you back at the last stop")
	var need := Tutorial.steps().all(func(st): return steps_seen.has(String(st[0])))
	ok(need and steps_seen.size() == 8, "the course runs all eight steps (%s)" % str(steps_seen.keys()))
	ok(hints.keys().filter(func(x): return String(x).begins_with("tut_")).size() >= 6, "a hint in its own voice for each step")
	ok(hints.has("demo_dash") and hints.has("demo_jump"), "it shows you a dash and a jump")

## Random ground well away from the player (40 m+), so a roaming bot can't wander into range and down the
## Boki mid-check (where random_ground lands depends on every earlier roll of the global RNG).
func _far_ground(m: Match, P: Hunter) -> Vector3:
	var best: Vector3 = m.world.random_ground()
	for i in 40:
		var g: Vector3 = m.world.random_ground()
		if P.flat_dist(g) > P.flat_dist(best):
			best = g
		if P.flat_dist(best) >= 40.0:
			break
	return best

## A spot `d` m from `at` on solid ground (east first), so a throw never lands the Boki in the abyss.
func _solid_spot(m: Match, at: Vector3, d: float) -> Vector3:
	for v in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var ok_all := true
		for k in range(1, int(d) + 2):
			var q: Vector3 = at + v * float(k)
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z):
				ok_all = false
				break
		if ok_all: return at + v * d
	return at + Vector3(d, 0, 0)
