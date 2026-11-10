extends RefCounted
## --heart-check: the Heart's early seat (scripts/match/heart.gd, content/rules/heart.json, docs/decisions/0023
## and 0051). The site and Gate, the Blight's tide (ring shrinks, stronger and sooner outside it), the Heart asleep
## until wake_s, the Heartspark charging and becoming ready, taking it by holding interact, the carrier's slow and
## reveal, dropping on down, the Gate opening only for the carrier, the minor bundle, no second Heartspark, the
## other exits unchanged (a carrier leaving by skiff drops it), the home half of the major bundle, and the "ht"
## requests. The squad take, the final seat and the state order: --heart-seats-check. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HEART %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Steps the match with no monsters about (over minutes they would end the idle rivals, and one squad
## left opens the final seat early).
func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		if i % 30 == 0:
			_calm(m)
		m.step(Match.DT)

func _calm(m: Match) -> void:
	for mb in m.mobs:
		if mb is Blight:
			(mb as Blight).burrow()
		else:
			mb.dead = true
			mb.visible = false

func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true,
		"heart": true, "god": true})
	m.set_process(false)
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	_calm(m)
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
	ok(gd > 8.0 and gd < float(rl["gate_dist"]) * H.ways_scale + 6.0,
		"the Gate is near the Heart but not on it (%.0f m)" % gd)
	var m2 := _match(main, 7302)
	ok(m2.heart.site == H.site and m2.heart.gate != H.gate,
		"the Heart keeps the map's site; another match seeds another Gate")
	m2.queue_free()
	var p: Hunter = m.player
	# ---- the tide
	ok(Heart.tide_r(m) == 0.0, "no tide before it starts")
	m.time = 5000.0
	ok(is_equal_approx(Heart.tide_r(m), float(rl["tide_r1"]) * H.ways_scale),
		"the tide has closed to its smallest ring")
	m.time = float(rl["tide_start_s"]) + float(rl["tide_close_s"]) * 0.5 - m.sess_t0
	var half := Heart.tide_r(m)
	ok(half < float(rl["tide_r0"]) * H.ways_scale and half > float(rl["tide_r1"]) * H.ways_scale,
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
	m.time = 0.0
	# ---- asleep, then charging
	_run(m, 1.0)
	ok(H.state == Heart.S.ASLEEP and H.charge == 0.0, "the Heart sleeps before it wakes")
	m.time = float(rl["wake_s"]) - m.sess_t0
	m.step(Match.DT)
	ok(H.state == Heart.S.CHARGING, "a Heartspark starts charging when the Heart wakes")
	_run(m, float(rl["charge_s"]) * 0.5)
	ok(H.state == Heart.S.CHARGING and H.charge > 0.0, "still charging halfway")
	_put(m, p, H.site + Vector3(3, 0, 0))
	_hold_f(m, p, 3.0)
	ok(H.carrier == null, "an uncharged Heartspark can't be taken")
	_run(m, float(rl["charge_s"]) * 0.5 + 1.0)
	ok(H.state == Heart.S.READY, "the Heartspark is charged")
	# ---- taking it
	_put(m, p, H.site + Vector3(6, 0, 0))
	_hold_f(m, p, 3.0)
	ok(H.carrier == null, "too far from the Heart: nothing")
	_put(m, p, H.site + Vector3(1.5, 0, 1.0))
	_hold_f(m, p, float(rl["pickup_hold_s"]) * 0.5)
	ok(H.carrier == null, "a short hold doesn't take it")
	_hold_f(m, p, float(rl["pickup_hold_s"]) + 0.3)
	ok(H.state == Heart.S.CARRIED and H.carrier == p, "holding interact takes the Heartspark")
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
	ok(H.state == Heart.S.READY and H.carrier == null, "a downed carrier drops it")
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
	ok(String(m.result.get("how", "")) == Heart.HOW_EARLY, "...by the Heart Gate (the early seat)")
	var minor: Dictionary = rl["reward"]["minor"]
	var hb: Dictionary = m.result.get("heart", {})
	ok(not hb.is_empty() and (hb["egg"] as Dictionary).is_empty(), "the minor bundle has no egg")
	ok(int(p.seeds.get("emberberry", 0)) == seeds0 + int((minor["seeds"] as Dictionary)["emberberry"]),
		"...evolution foods")
	ok(p.gems == gems0 + int(minor["gems"]), "...gems (%d)" % int(minor["gems"]))
	ok(hb.get("goods", {}).has("heartwood"), "...heartwood")
	ok(kin0 == null or kin0.trust > trust0, "...bond/trust with the Boki")
	ok(H.carrier == null and H.early_team == p.team, "the early seat is used")
	_run(m, float(rl["charge_s"]) + 5.0)
	ok(not H.spark_live() and H.charge == float(rl["charge_s"]), "no second Heartspark: the cooldown loop is gone")
	# ---- a carrier leaving by another exit drops it
	var m3 := _match(main, 7303)
	var H3: Heart = m3.heart
	m3.time = float(rl["wake_s"]) - m3.sess_t0
	_run(m3, float(rl["charge_s"]) + 0.5)
	var q: Hunter = m3.player
	_put(m3, q, H3.site + Vector3(1, 0, 1))
	H3._pick(q)
	ok(H3.carrier == q, "(setup) q carries")
	m3._extract(q, "skiff", "test")
	ok(H3.state == Heart.S.READY and H3.carrier == null and H3.early_team < 0,
		"a carrier leaving by skiff leaves the Heartspark behind, no reward")
	ok(m3.result.get("heart", {}).is_empty(), "...and the skiff result has no Heart bundle")
	# ---- the home half (the major bundle: egg and materials)
	var major: Dictionary = H3.pay(m3.hunters[1], Heart.HOW_FINAL)
	var egg_sp := String(major["egg"].get("sp", ""))
	ok(Data.is_rare(egg_sp), "the major bundle has a rare egg (%s)" % egg_sp)
	ok(major["goods"].has("starstone"), "...and starstone")
	Incubator.ensure()
	var eggs0 := Incubator.count()
	var out := {}
	Heart.settle({"extracted": true, "heart": major}, out)
	ok(Incubator.count() == eggs0 + 1, "the rare egg reaches the incubator")
	ok(int(Save.d["goods"].get("heartwood", 0)) >= 1 and int(Save.d["goods"].get("starstone", 0)) >= 1,
		"the materials reach the stash")
	ok(out.has("heart"), "and the results screen's data carries the bundle")
	# ---- online requests (offline game: this one is the host)
	var m4 := _match(main, 7304)
	var H4: Heart = m4.heart
	m4.time = float(rl["wake_s"]) - m4.sess_t0
	_run(m4, float(rl["charge_s"]) + 0.5)
	H4.net_in(["ht", "pick", m4.player.nid])
	ok(H4.carrier == m4.player and H4.state == Heart.S.CARRIED, "the host takes a pick request")
	H4.net_in(["ht", "drop", m4.player.nid, H4.site.x + 2.0, H4.site.y, H4.site.z])
	ok(H4.state == Heart.S.READY and H4.carrier == null, "...and a drop request")
	H4.net_in(["ht", "pick", m4.player.nid])
	_put(m4, m4.player, H4.gate)
	H4.net_in(["ht", "done", m4.player.nid])
	ok(H4.early_team == m4.player.team and m4.player.extracted, "...and a delivery")
	for mm in [m, m3, m4]:
		mm.queue_free()
	print("HEART DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
