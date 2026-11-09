extends RefCounted
## --heart-check: the Heart loop (scripts/match/heart.gd, content/rules/heart.json, docs/decisions/0023).
## The site and Gate, the Blight's tide (ring shrinks, stronger and sooner outside it), the Heartspark
## charging and becoming ready, taking it by holding interact, the carrier's slow and reveal, dropping on
## down, the Gate taking only the carrier, the reward bundle, the cooldown and the next charge, the normal
## exits unchanged (a carrier leaving by skiff drops it), the home half of the reward, and the "ht" events.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HEART %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)

func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true,
		"heart": true, "god": true})
	m.set_process(false)
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	for mb in m.mobs:
		if mb is Blight:
			(mb as Blight).burrow()
		else:
			mb.dead = true
			mb.visible = false
	m.player.ctrl = "idle"
	return m

func _put(m: Match, h: Hunter, p: Vector3) -> void:
	h.teleport(m.world.free_spot_near(p, [], 1.0, 0.45, 6.0))
	h.vel = Vector3.ZERO

func _hold_f(m: Match, h: Hunter, secs: float) -> void:
	h.inp["interact"] = true
	_run(m, secs)
	h.inp["interact"] = false
	m.step(Match.DT)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var rl: Dictionary = Heart.rules()
	var m := _match(main, 7301)
	var H: Heart = m.heart
	ok(H != null and H.site != Vector3.INF, "a real expedition has a Heart site")
	if H == null:
		main.get_tree().quit(1)
		return
	var w := m.world
	ok(not w.is_void(H.site.x, H.site.z) and not w.is_void(H.gate.x, H.gate.z),
		"the Heart and the Gate stand on ground")
	var gd := Vector2(H.gate.x - H.site.x, H.gate.z - H.site.z).length()
	ok(gd > 8.0 and gd < float(rl["gate_dist"]) + 6.0, "the Gate is near the Heart but not on it (%.0f m)" % gd)
	var m2 := _match(main, 7302)
	ok(m2.heart.site != H.site or m2.heart.gate != H.gate, "another match can pick another site")
	m2.queue_free()
	var p: Hunter = m.player
	# ---- the tide
	ok(Heart.tide_r(m) == 0.0, "no tide before it starts")
	m.time = 5000.0
	ok(is_equal_approx(Heart.tide_r(m), float(rl["tide_r1"])), "the tide has closed to its smallest ring")
	m.time = float(rl["tide_start_s"]) + float(rl["tide_close_s"]) * 0.5 - m.sess_t0
	var half := Heart.tide_r(m)
	ok(half < float(rl["tide_r0"]) and half > float(rl["tide_r1"]),
		"halfway the ring is between its two sizes (%.0f m)" % half)
	var far := H.site + Vector3(half + 60.0, 0, 0)
	ok(Heart.tide_boost(m, H.site) == 0.0 and Heart.tide_boost(m, far) > 0.0,
		"the Blight is stronger outside the ring, not inside")
	var edge := H.site + Vector3(half + 60.0, 0, 0)
	var with_tide: float = m.blight.level_here(edge)
	var t_keep := m.time
	m.time = 0.0          # (tide not started)
	var without: float = m.blight.level_here(edge)
	m.time = t_keep
	ok(with_tide > without or with_tide >= BlightDir.LVL_MAX - 1.0e-4,
		"BlightDir reads the tide (%.2f vs %.2f at the same spot)" % [with_tide, without])
	ok(Heart.tide_heat(m, far) > 0.0 and Heart.tide_heat(m, H.site) == 0.0,
		"squads outside the ring heat the Blight sooner")
	# ---- the wall in the world and the next ring on the maps
	m.step(Match.DT)
	ok(H.wall.wall.visible and is_equal_approx(H.wall.wall.scale.x, Heart.tide_r(m)),
		"the Blight wall stands on the ring (%.0f m)" % H.wall.wall.scale.x)
	ok(Heart.next_r(m) < Heart.tide_r(m) and Heart.next_r(m) > float(rl["tide_r1"]),
		"the next ring is smaller than the ring now (%.0f m)" % Heart.next_r(m))
	var embers := H.wall.embers
	var rich := float(Settings.q("fx")) > BlightWall.RICH_FX
	ok((embers != null) == rich and (embers == null or embers.amount <= BlightWall.EMBERS),
		"embers only on presets that can afford them, inside the budget")
	m.time = 0.0
	m.step(Match.DT)
	ok(not H.wall.wall.visible and is_equal_approx(Heart.next_r(m), float(rl["tide_r0"])),
		"before the tide: no wall, and the first ring is the next ring")
	# ---- charging
	ok(H.state == "charging", "a Heartspark starts charging")
	_run(m, float(rl["charge_s"]) * 0.5)
	ok(H.state == "charging" and H.charge > 0.0, "still charging halfway")
	_put(m, p, H.site + Vector3(3, 0, 0))
	_hold_f(m, p, 3.0)
	ok(H.carrier == null, "an uncharged Heartspark can't be taken")
	_run(m, float(rl["charge_s"]) * 0.5 + 1.0)
	ok(H.state == "ready", "the Heartspark is charged")
	# ---- taking it
	_put(m, p, H.site + Vector3(6, 0, 0))
	_hold_f(m, p, 3.0)
	ok(H.carrier == null, "too far from the Heart: nothing")
	_put(m, p, H.site + Vector3(1.5, 0, 1.0))
	_hold_f(m, p, float(rl["pickup_hold_s"]) * 0.5)
	ok(H.carrier == null, "a short hold doesn't take it")
	_hold_f(m, p, float(rl["pickup_hold_s"]) + 0.3)
	ok(H.state == "carried" and H.carrier == p, "holding interact takes the Heartspark")
	ok(is_equal_approx(float(p.get_meta("heart_slow", 0.0)), float(rl["carrier_slow"])),
		"the carrier is slowed by %.0f%%" % (float(rl["carrier_slow"]) * 100.0))
	p.set_meta("heart_slow", 0.0)
	var k0 := p._chase_mod(Vector2(1, 0))
	p.set_meta("heart_slow", float(rl["carrier_slow"]))
	ok(is_equal_approx(p._chase_mod(Vector2(1, 0)), k0 * (1.0 - float(rl["carrier_slow"]))),
		"that slow is in the move speed")
	m.step(Match.DT)
	ok(p.reveal_t > 0.0, "the carrier is revealed")
	# ---- dropping it
	p.downed = true
	m.step(Match.DT)
	ok(H.state == "ready" and H.carrier == null, "a downed carrier drops it")
	ok(Vector2(H.spark_pos.x - p.pos.x, H.spark_pos.z - p.pos.z).length() < 9.0, "...where they fell")
	ok(float(p.get_meta("heart_slow", 0.0)) == 0.0, "and the slow is gone")
	p.downed = false
	p.out = false      # (the step above eliminated the test Hunter: bring them back)
	p.hp = p.max_hp
	# ---- the Gate takes only the carrier
	_put(m, p, H.spark_pos + Vector3(1, 0, 0))
	_hold_f(m, p, float(rl["pickup_hold_s"]) + 0.3)
	ok(H.carrier == p, "picked up again from where it fell")
	var rival: Hunter = null
	for o in m.hunters:
		if o != p and o.team != p.team:
			rival = o
			break
	_put(m, rival, H.gate)
	var it := H.interact_for(rival)
	ok(not it.has("act"), "the Gate offers a rival nothing")
	_put(m, p, H.gate)
	it = H.interact_for(p)
	ok(String(it.get("act", "")) == "leave", "the Gate offers the carrier a way out")
	# ---- skiff/uplink unchanged: a non-carrier leaves as before, a carrier leaving by skiff drops it
	var c1 := rival
	m._extract(c1, "skiff", "test")
	ok(c1.extracted and H.carrier == p, "a rival leaving by skiff is unchanged and the carrier keeps it")
	# ---- leaving through the Gate
	_hold_f(m, p, float(rl["gate_hold_s"]) * 0.4)
	ok(not p.extracted, "a short hold at the Gate isn't enough")
	var seeds0 := int(p.seeds.get("emberberry", 0))
	var gems0 := p.gems
	var trust0 := 0.0
	var kin0: Kin = p.kin
	if kin0: trust0 = kin0.trust
	_hold_f(m, p, float(rl["gate_hold_s"]) + 0.3)
	ok(p.extracted, "holding at the Gate extracts the carrier")
	ok(String(m.result.get("how", "")) == "heart", "...by the Heart Gate")
	var hb: Dictionary = m.result.get("heart", {})
	ok(not hb.is_empty() and Data.is_rare(String(hb["egg"]["sp"])),
		"the bundle has a rare egg (%s)" % String(hb.get("egg", {}).get("sp", "")))
	ok(int(p.seeds.get("emberberry", 0)) == seeds0 + int((rl["reward"]["seeds"] as Dictionary)["emberberry"]),
		"...evolution foods")
	ok(p.gems == gems0 + int(rl["reward"]["gems"]), "...gems")
	ok(hb.get("goods", {}).has("heartwood") and hb.get("goods", {}).has("starstone"), "...rare evolution materials")
	ok(kin0 == null or kin0.trust > trust0, "...bond/trust with the Boki")
	ok(H.state == "cooling" and H.deliveries == 1 and H.carrier == null, "the Heart cools after a delivery")
	ok(is_equal_approx(H.cool, float(rl["cool_s"])) or H.cool > float(rl["cool_s"]) - 2.0,
		"...for %.0f s" % float(rl["cool_s"]))
	# ---- the next Heartspark
	var m3 := _match(main, 7303)
	var H3: Heart = m3.heart
	H3.state = "cooling"
	H3.cool = 2.0
	_run(m3, 2.5)
	ok(H3.state == "charging" and H3.charge < 1.0, "after the cooldown a new Heartspark charges")
	# ---- a carrier leaving by a normal exit drops it
	H3.state = "ready"
	H3.spark_pos = H3.site
	var q: Hunter = m3.player
	_put(m3, q, H3.site + Vector3(1, 0, 1))
	H3._pick(q)
	ok(H3.carrier == q, "(setup) q carries")
	m3._extract(q, "skiff", "test")
	ok(H3.state == "ready" and H3.carrier == null and H3.deliveries == 0,
		"a carrier leaving by skiff leaves the Heartspark behind, no reward")
	ok(m3.result.get("heart", {}).is_empty(), "...and the skiff result has no Heart bundle")
	# ---- the home half
	Incubator.ensure()
	var eggs0 := Incubator.count()
	var out := {}
	Heart.settle({"extracted": true, "heart": hb}, out)
	ok(Incubator.count() == eggs0 + 1, "the rare egg reaches the incubator")
	ok(int(Save.d["goods"].get("heartwood", 0)) >= 1 and int(Save.d["goods"].get("starstone", 0)) >= 1,
		"the materials reach the stash")
	ok(out.has("heart"), "and the results screen's data carries the bundle")
	# ---- online events (offline game: this one is the host)
	var m4 := _match(main, 7304)
	var H4: Heart = m4.heart
	H4.state = "ready"
	H4.spark_pos = H4.site
	H4.net_in(["ht", "pick", m4.player.nid])
	ok(H4.carrier == m4.player and H4.state == "carried", "the host takes a pick request")
	H4.net_in(["ht", "drop", m4.player.nid, H4.site.x + 2.0, H4.site.y, H4.site.z])
	ok(H4.state == "ready" and H4.carrier == null, "...and a drop request")
	H4.state = "carried"
	H4.carrier = m4.player
	H4.net_in(["ht", "done", m4.player.nid])
	ok(H4.state == "cooling" and H4.deliveries == 1, "...and a delivery")
	for mm in [m, m3, m4]:
		mm.queue_free()
	print("HEART DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
