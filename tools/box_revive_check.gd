extends RefCounted
## --box-revive-check: box revives and revive beacons (docs/decisions/0018, owner items 101 / 101b).
##  1. A box revive takes BoxRevive.time_for (7.5 s the first time, from content/rules/revive.json);
##     the teammate comes back at the box with their Boki; the box hums while it's channelled.
##  2. While channelling a hit does Hunter.CONSUME_VULN times the damage (the tonic's multiplier) and
##     breaks it; holding on does nothing until interact is let go and held again.
##  3. Walking breaks it; fire is held off while channelling.
##  4. The second box revive of the same Hunter is slower (the diminishing curve).
##  5. A beacon brings back every dead teammate at once; while it's lit every player is told
##     (toast + map/world marker state) and its hum carries beacon_hear_m; "bcn" events from another
##     game light it, put it out and use it.
##  6. A bot walks to a dead teammate's box and brings them back with the new timing; with the soul
##     gone it lights a beacon instead.
##  7. It reads from afar (BoxReviveFx): a tether from the reviver to the soul in their side colour and a
##     core in the soul that grows with the progress, both gone on an interrupt; the soul rises on
##     completion; a remote teammate's "revive" hold at the box drives the same fx online.
## Never touches the save.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("RVCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		m.step(Match.DT)
		t += Match.DT

func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(at)
	h.vel = Vector3.ZERO
	# the Boki comes along: left behind, a heavy one walks through its Hunter to the heel and shoves them off
	if h.kin != null and h.kin.state == "active":
		h.kin.teleport(at + Vector3(1.0, 0, 0.7))

func _calm(h: Hunter) -> void:
	h.inv_t = 0.0
	h.armor = 0.0
	h.shield = 0.0
	h.kin_shield = 0.0
	h.hp = h.max_hp

## Open, flat ground with room round it, away from the beacons.
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := true
		for dx in range(-8, 9, 2):
			for dz in range(-8, 9, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		if flat and m.beacons.all(func(bc): return g.distance_to(bc["pos"]) > 12.0):
			return g
	return m.world.random_ground()

## Holds interact at a box until the owner is back or the time runs out; returns the seconds taken.
func _channel(c: Hunter, b: Hunter, cap: float) -> float:
	c.inp["interact"] = true
	var t0 := m.time
	while b.out and m.time - t0 < cap:
		_run(Match.DT)
	c.inp["interact"] = false
	_run(Match.DT * 2.0)
	return m.time - t0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.biomes = null          # no map hazards: a spore pod's cloud by the box would break every channel
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	var mine: Array = m.hunters.filter(func(x): return x.team == m.player.team)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	var a: Hunter = mine[0]
	var b: Hunter = mine[1]
	var c: Hunter = mine[2]
	var home := _roomy()
	for h in m.hunters:
		if h.team != a.team: _spot(h, m.world.random_ground())
	_spot(foe, home + Vector3(30, 0, 0))
	_spot(a, home + Vector3(-6, 0, 0))
	_spot(c, home)
	ok(m.beacons.size() >= 3, "several beacons on the map (%d)" % m.beacons.size())
	_box_revive(b, c)
	_hits(b, c, foe)
	_moves(b, c)
	_remote(b, c)
	_beacon(a, b, c, foe)
	_bot(b, c, home)
	print("BOX REVIVE CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _box_revive(b: Hunter, c: Hunter) -> void:
	var home := c.pos
	_spot(b, home + Vector3(3, 0, 0))
	m.eliminate(b, null, "finished")
	var bx := Life.box_of(m, b)
	ok(b.out and not bx.is_empty() and Life.soul_here(m, bx), "a fallen teammate leaves a box with their soul in it")
	ok(absf(float(BoxRevive.rules()["box_revive_s"]) - 7.5) < 0.01 and absf(BoxRevive.time_for(b) - 7.5) < 0.01,
		"a box revive is a 7.5 s channel the first time (%.2fs)" % BoxRevive.time_for(b))
	var stand := float(Life.R["box_revive_hp"])
	ok(stand == float(Life.R["revive_hp"]) and stand >= 0.12 and stand <= 0.35,
		"revived Hunters stand up with %d%% (same as a Wisp revive; per-tick heal band 12-35%%)" % int(stand * 100.0))
	var ring: Node = (bx["node"] as Node).get_node_or_null("OwnerRing")
	ok(ring != null and Life.owner_col(m, bx) == m.mate_col(b), "an ally box wears its owner's squad colour")
	_spot(c, bx["pos"] + Vector3(0.4, 0, 0))
	var t0 := m.time
	c.inp["interact"] = true
	_run(BoxRevive.time_for(b) * 0.5)
	var hum := String(bx.get("hum_key", ""))
	ok(c.box_reviving() and hum != "" and Sfx.loop_on(hum), "mid-channel: kneeling over the box, and it hums")
	var prog := float(bx.get("rev_prog", 0.0))
	ok(absf(prog - 0.5) < 0.05, "the progress ring reads half way (%.2f)" % prog)
	_reads(bx, c, prog, "mid-channel")
	c.inp["fire"] = true
	_run(Match.DT)
	ok(not c.inp["fire"] and c.box_reviving(), "no firing while channelling, and the channel goes on")
	_channel(c, b, 10.0)
	var took := m.time - t0 - Match.DT * 2.0
	ok(not b.out and absf(took - 7.5) < 0.15, "the teammate is back after %.2fs (want 7.5s)" % took)
	ok(b.pos.distance_to(bx["pos"]) < 3.0, "back at their box (%.1fm away)" % b.pos.distance_to(bx["pos"]))
	var k: Kin = b.kin
	ok(k != null and not k.dead and k.state == "active" and k.flat_dist(b) < 3.0, "their Boki is back at their side")
	ok(not Sfx.loop_on(hum), "the hum stops once it's done")
	ok(_cleared(bx), "the tether and core are gone once it's done")
	ok(m.get_node_or_null("SoulRise") != null, "the soul rises off the box on completion")

func _hits(b: Hunter, c: Hunter, foe: Hunter) -> void:
	var second := BoxRevive.time_for(b)
	ok(absf(second - 7.5 / 0.75) < 0.05, "the second box revive of a Hunter is slower (%.2fs)" % second)
	_calm(c)
	var h0 := c.hp
	c.hurt(10.0, foe, {"src": "abil"})
	var plain := h0 - c.hp
	_spot(b, c.pos + Vector3(2.5, 0, 0))
	m.eliminate(b, null, "finished")
	var bx := Life.box_of(m, b)
	_spot(c, bx["pos"] + Vector3(0.4, 0, 0))
	_calm(c)
	c.inp["interact"] = true
	_run(1.5)
	ok(c.box_reviving() and c.box_t > 1.0, "channelling again")
	var h1 := c.hp
	c.hurt(10.0, foe, {"src": "abil"})
	var while_rev := h1 - c.hp
	ok(plain > 0.0 and absf(while_rev / plain - Hunter.CONSUME_VULN) < 0.02,
		"a hit while channelling does %.2fx (the tonic's %.2fx)" % [while_rev / maxf(plain, 0.001),
		Hunter.CONSUME_VULN])
	_run(Match.DT)
	ok(c.box_t == 0.0 and b.out, "and the hit breaks the channel")
	_run(0.2)
	ok(_cleared(bx), "the tether and core clear on the interrupt")
	_run(1.0)
	ok(c.box_t == 0.0 and not c.box_reviving(), "holding on does nothing until interact is pressed again")
	c.inp["interact"] = false
	_run(Match.DT * 2.0)
	var need := BoxRevive.time_for(b)
	var took := _channel(c, b, 15.0) - Match.DT * 2.0
	ok(not b.out and absf(took - need) < 0.15,
		"pressed again it starts over and takes the full %.1fs (%.2fs)" % [need, took])

func _moves(b: Hunter, c: Hunter) -> void:
	_spot(b, c.pos + Vector3(2.5, 0, 0))
	m.eliminate(b, null, "finished")
	var bx := Life.box_of(m, b)
	_spot(c, bx["pos"] + Vector3(0.4, 0, 0))
	c.inp["interact"] = true
	_run(1.0)
	ok(c.box_reviving(), "channelling a third time")
	c.inp["move"] = Vector2(1, 0)
	_run(Match.DT * 2.0)
	ok(c.box_t == 0.0 and not c.box_reviving() and b.out, "walking breaks the channel")
	c.inp["move"] = Vector2.ZERO
	c.inp["interact"] = false
	_run(Match.DT * 2.0)

## The tether runs from the reviver to the soul in their side colour; the core is sized by the progress.
func _reads(bx: Dictionary, by: Hunter, prog: float, when: String) -> void:
	var tether := bx.get("tether_node") as Node3D
	var soul := (bx["node"] as Node3D).get_node("Soul") as Node3D
	var core := soul.get_node_or_null("Core") as MeshInstance3D
	var line := tether.get_node("Line") as MeshInstance3D if tether else null
	var col: Color = (line.material_override as ShaderMaterial).get_shader_parameter("color") if line else Color.BLACK
	var reach := tether.position.distance_to(soul.global_position) if tether else 0.0
	ok(line != null and absf(tether.scale.z - reach) < 0.05 and tether.position.distance_to(by.pos) < 1.2
		and Color(col, 1.0).is_equal_approx(SideColor.of(m, by)),
		"%s: a tether from %s to the soul in their side colour (%.2f m)" % [when, by.pname, reach])
	var want := lerpf(BoxReviveFx.CORE_MIN, 1.0, prog)
	ok(core != null and core.visible and absf(core.scale.x - want) < 0.02,
		"%s: the soul's core fills with the progress (%.2f, want %.2f)" % [when, core.scale.x if core else 0.0, want])

func _cleared(bx: Dictionary) -> bool:
	var core := (bx["node"] as Node3D).get_node("Soul").get_node_or_null("Core") as Node3D
	return not bx.has("tether_node") and (core == null or not core.visible)

## Online: a remote teammate's channel only arrives as the "revive" hold in their flags.
func _remote(b: Hunter, c: Hunter) -> void:
	var bx := Life.box_of(m, b)
	_spot(c, bx["pos"] + Vector3(0.4, 0, 0))
	c.remote = true
	var t := 0.0
	var need := BoxRevive.time_for(b) * 0.4
	while t < need:
		c.set_hold("revive", 0.3)
		_run(Match.DT)
		t += Match.DT
	var prog := float(bx.get("rev_prog", 0.0))
	ok(absf(prog - 0.4) < 0.05 and bx.get("rev_by") == c, "remote: the synced hold times the revive (%.2f)" % prog)
	_reads(bx, c, prog, "remote")
	_run(0.5)
	ok(_cleared(bx) and b.out, "remote: tether and core clear when the hold stops")
	c.remote = false

func _beacon(a: Hunter, b: Hunter, c: Hunter, foe: Hunter) -> void:
	m.eliminate(c, null, "finished")
	ok(b.out and c.out and not a.out, "two of the squad are dead")
	var bc: Dictionary = m.beacons[0]
	var i := 0
	var key := "beacon0"
	# another game's Hunter lights it, then steps off: the notice comes and goes here too
	Beacons.net_in(m, ["bcn", i, foe.team, "lit"])
	ok(bc["lit"] and Beacons.lit(m).has(bc) and Sfx.loop_on(key), "a \"bcn\" lit event lights it here, hum and all")
	Beacons.net_in(m, ["bcn", i, foe.team, "out"])
	ok(not bc["lit"] and not Sfx.loop_on(key), "and \"out\" puts it out")
	# every player is told: a teammate's view and a rival's
	for viewer in [a, foe]:
		m.player = viewer
		m.hud.msgs.clear()
		_spot(a, bc["pos"])
		_run(Match.DT * 2.0)
		var told: bool = m.hud.msgs.texts().any(func(t): return t.contains("eacon"))
		var side := "ally" if viewer.team == a.team else "rival"
		ok(bc["lit"] and told, "%s (%s) gets the beacon notice" % [viewer.pname, side])
		_spot(a, bc["pos"] + Vector3(12, 0, 0))
		_run(Match.DT * 2.0)
	m.player = a
	ok(not bc["lit"], "stepping off puts it out")
	_spot(a, bc["pos"])
	_run(Match.DT * 3.0)
	var reach := float(Sfx.loops.get(key, {}).get("reach", 0.0))
	ok(Sfx.loop_on(key) and absf(reach - float(BoxRevive.rules()["beacon_hear_m"])) < 0.1,
		"while it's lit its hum carries %.0fm" % reach)
	ok(m.pings.any(func(p): return p["pos"] == bc["pos"]), "and it's marked on everyone's map")
	var t0 := m.time
	while (b.out or c.out) and m.time - t0 < Beacons.time_s() + 2.0:
		_run(Match.DT)
	var took := m.time - t0
	ok(not b.out and not c.out and absf(took - Beacons.time_s()) < 0.3,
		"the beacon brings back both dead teammates at once after %.1fs (want %.1fs)" % [took, Beacons.time_s()])
	ok(bc["used"] and not bc["lit"] and not Sfx.loop_on(key), "single use, and quiet again")
	ok(b.sick_t > 0.0 and c.sick_t > 0.0, "with resurrection sickness")
	# a "used" event from another game brings back the dead Hunters this game owns
	var bc2: Dictionary = m.beacons[1]
	m.eliminate(b, null, "finished")
	Beacons.net_in(m, ["bcn", 1, b.team, "used"])
	ok(not b.out and bc2["used"], "a \"used\" event brings back this game's dead teammates")

func _bot(b: Hunter, c: Hunter, home: Vector3) -> void:
	for h in m.hunters:
		if h.team != b.team:
			var far := m.world.random_ground()
			for k in 200:
				if far.distance_to(home) > 70.0: break
				far = m.world.random_ground()
			_spot(h, far)
	_calm(c)
	_spot(b, home)
	_spot(c, home + Vector3(6, 0, 2))
	_run(0.5)
	m.eliminate(b, null, "finished")
	c.ctrl = "bot"
	c.ai = m.bot_brain.new_mind(m.rng, 0.6, m.bot_cfg)
	var t0 := m.time
	while b.out and m.time - t0 < 30.0:
		_run(Match.DT)
	ok(not b.out, "a bot walks to the box and brings its teammate back (%.1fs incl. the walk)" % (m.time - t0))
	# the soul has left the box: the bot heads for a beacon instead
	var unused: Array = m.beacons.filter(func(bc): return not bc["used"])
	_spot(c, unused[0]["pos"] + Vector3(8, 0, 0))
	_spot(b, c.pos)
	_run(0.3)
	m.eliminate(b, null, "finished")
	Life.box_of(m, b)["soul_until"] = 0.0
	t0 = m.time
	while b.out and m.time - t0 < 40.0:
		_run(Match.DT)
	c.ctrl = "idle"
	ok(not b.out and b.sick_t > 0.0,
		"with the soul gone a bot lights a beacon instead (%.1fs incl. the walk)" % (m.time - t0))
