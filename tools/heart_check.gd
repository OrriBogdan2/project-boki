extends RefCounted
## --heart-check: the Heart's two seats (scripts/match/heart.gd, content/rules/heart.json, docs/decisions/0023
## and 0051). Never touches the save.
##   1. the site and Gate, the Blight's tide and its wall, the Heart asleep until wake_s, the Heartspark
##      charging, taking it, the carrier's slow and reveal, dropping on down, the Gate only for the carrier, the
##      minor bundle, no second Heartspark, a carrier leaving by uplink drops it, the major bundle at home, "ht"
##      requests.
##   2. the Gate takes the carrier's squad within gate_take_r (a downed mate too), not a mate farther off.
##   3. the final seat: a squad alone fills the ring, a standing rival stalls it, an empty ring drains, full
##      takes that squad with major pay and the islands fall end_after_final_s later.
##   4. the last squad standing: FINAL at once, filling rush_k faster.
##   5. the Heart opening over a spark still charging or carried (the carrier can still take the early seat).
##   6. Net: the host's "ht" events through JSON into a client game mirror the state and take its own Hunters.
## Every edge in Heart.NEXT is taken at least once over the run, and none is ever refused but the one on purpose.

var bad := 0
var rl: Dictionary
var edges := {}  # "FROM>TO" -> times taken, over every match of the run


func ok(cond: bool, what: String) -> void:
	print("HEART %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


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


func _match(main: Node, seed_v: int, squad := 1) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 3,
			"squad": squad,
			"tier": 0,
			"length": 1e9,
			"seed": seed_v,
			"no_drop": true,
			"heart": true,
			"god": true
		}
	)
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
	_calm(m)
	return m


## Notes the edges this match's Heart took, then frees it.
func _free(m: Match) -> void:
	for line in m.heart.trail:
		var e := String(line).split(" ", false)[1]
		if e != "refused":
			edges[e] = int(edges.get(e, 0)) + 1
	m.queue_free()


func _put(m: Match, h: Hunter, p: Vector3) -> void:
	h.teleport(m.world.free_spot_near(p, [], 1.0, 0.45, 6.0))
	h.vel = Vector3.ZERO


func _hold_f(m: Match, h: Hunter, secs: float) -> void:
	h.inp["interact"] = true
	_run(m, secs)
	h.inp["interact"] = false
	m.step(Match.DT)


## Into the Heart ring, k-th spot round it.
func _ring(m: Match, h: Hunter, k: int) -> void:
	var a := TAU * k / 6.0
	h.teleport(m.world.free_spot_near(m.heart.site + Vector3(cos(a), 0, sin(a)) * 2.5, [], 1.0, 0.45, 1.5))
	h.vel = Vector3.ZERO


func _squad(m: Match, team: int) -> Array:
	return m.hunters.filter(func(h): return h.team == team)


## Somewhere on solid ground well away from the Heart, its ring and its Gate.
func _far(m: Match, h: Hunter) -> void:
	var p := m.world.random_ground()
	while p.distance_to(m.heart.site) < 30.0 or p.distance_to(m.heart.gate) < 20.0:
		p = m.world.random_ground()
	h.teleport(p)
	h.vel = Vector3.ZERO


## Runs a match's clock to this session time.
func _to(m: Match, t: float) -> void:
	m.time = t - m.sess_t0
	m.step(Match.DT)


## Wakes the Heart and charges its Heartspark.
func _charged(m: Match) -> void:
	_to(m, float(rl["wake_s"]))
	_run(m, float(rl["charge_s"]) + 0.5)


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	rl = Heart.rules()
	# the tide's damage (--blight-check) would end the idle Hunters over the minutes this check skips through
	rl["tide_dmg"] = [[0, 0.0], [10, 0.0]]
	_early_seat(main)
	_gate_squad(main)
	_final(main)
	_rush(main)
	_late(main)
	_net(main)
	var missing := []
	for from in Heart.NEXT:
		for to in Heart.NEXT[from]:
			var e := "%s>%s" % [Heart.S.keys()[from], Heart.S.keys()[to]]
			if not edges.has(e):
				missing.append(e)
	ok(missing.is_empty(), "every state edge was taken (%d kinds; missing: %s)" % [edges.size(), ", ".join(missing)])
	print("HEART DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


# ------------------------------------------------------------------ 1. the early seat, one Hunter a squad
func _early_seat(main: Node) -> void:
	var m := _match(main, 7301)
	var H: Heart = m.heart
	ok(H != null and H.site != Vector3.INF, "a real expedition has a Heart site")
	if H == null:
		return
	var w := m.world
	ok(
		not w.is_void(H.site.x, H.site.z) and not w.is_void(H.gate.x, H.gate.z),
		"the Heart and the Gate stand on ground"
	)
	var gd := Vector2(H.gate.x - H.site.x, H.gate.z - H.site.z).length()
	ok(
		gd > 8.0 and gd < float(rl["gate_dist"]) * H.ways_scale + 6.0,
		"the Gate is near the Heart but not on it (%.0f m)" % gd
	)
	var m2 := _match(main, 7302)
	ok(
		m2.heart.site == H.site and m2.heart.gate != H.gate,
		"the Heart keeps the map's site; another match seeds another Gate"
	)
	var p: Hunter = m.player
	# ---- the tide
	ok(
		is_equal_approx(Heart.tide_r(m), H.start_r) and H.start_r < float(rl["tide_r0"]) * H.ways_scale,
		"the tide starts already in, on the map's play space (%.0f m)" % H.start_r
	)
	m.time = 5000.0
	ok(
		is_equal_approx(Heart.tide_r(m), float(rl["tide_r1"]) * H.ways_scale),
		"the tide has closed to its smallest ring"
	)
	m.time = float(rl["tide_start_s"]) + float(rl["tide_close_s"]) * 0.5 - m.sess_t0
	var half := Heart.tide_r(m)
	ok(
		half < float(rl["tide_r0"]) * H.ways_scale and half > float(rl["tide_r1"]) * H.ways_scale,
		"halfway the ring is between its two sizes (%.0f m)" % half
	)
	var far := H.site + Vector3(half + 60.0, 0, 0)
	ok(
		Heart.tide_boost(m, H.site) == 0.0 and Heart.tide_boost(m, far) > 0.0,
		"the Blight is stronger outside the ring, not inside"
	)
	var edge := H.site + Vector3(half + 60.0, 0, 0)
	var with_tide: float = m.blight.level_here(edge)
	var t_keep := m.time
	var r_keep := H.start_r
	m.time = 0.0  # (the closing ring's first radius, and no play space inside it: edge is in the ring)
	H.start_r = INF
	var without: float = m.blight.level_here(edge)
	m.time = t_keep
	H.start_r = r_keep
	ok(
		with_tide > without or with_tide >= BlightDir.LVL_MAX - 1.0e-4,
		"BlightDir reads the tide (%.2f vs %.2f at the same spot)" % [with_tide, without]
	)
	ok(
		Heart.tide_heat(m, far) > 0.0 and Heart.tide_heat(m, H.site) == 0.0,
		"squads outside the ring heat the Blight sooner"
	)
	# ---- the wall in the world and the next ring on the maps (on m2: a step mid-tide wakes its Heart)
	var W: Heart = m2.heart
	m2.time = m.time
	m2.step(Match.DT)
	ok(
		W.wall.wall.visible and is_equal_approx(W.wall.wall.scale.x, Heart.tide_r(m2)),
		"the Blight wall stands on the ring (%.0f m)" % W.wall.wall.scale.x
	)
	ok(
		Heart.next_r(m2) < Heart.tide_r(m2) and Heart.next_r(m2) > float(rl["tide_r1"]) * W.ways_scale,
		"the next ring is smaller than the ring now (%.0f m)" % Heart.next_r(m2)
	)
	var embers := W.wall.embers
	var rich := float(Settings.q("fx")) > BlightWall.RICH_FX
	ok(
		(embers != null) == rich and (embers == null or embers.amount <= BlightWall.EMBERS),
		"embers only on presets that can afford them, inside the budget"
	)
	m2.time = 0.0
	m2.step(Match.DT)
	var on_space := is_equal_approx(W.wall.wall.scale.x, W.start_r) and is_equal_approx(Heart.next_r(m2), W.start_r)
	ok(
		W.wall.wall.visible and on_space,
		"before the close: the wall stands on the play space, and that is the next ring too"
	)
	_free(m2)
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
	ok(
		is_equal_approx(float(p.get_meta("heart_slow", 0.0)), float(rl["carrier_slow"])),
		"the carrier is slowed by %.0f%%" % (float(rl["carrier_slow"]) * 100.0)
	)
	p.set_meta("heart_slow", 0.0)
	var k0 := p._chase_mod(Vector2(1, 0))
	p.set_meta("heart_slow", float(rl["carrier_slow"]))
	ok(
		is_equal_approx(p._chase_mod(Vector2(1, 0)), k0 * (1.0 - float(rl["carrier_slow"]))),
		"that slow is in the move speed"
	)
	m.step(Match.DT)
	ok(p.reveal_t > 0.0, "the carrier is revealed")
	# ---- dropping it
	p.downed = true
	m.step(Match.DT)
	ok(H.state == Heart.S.READY and H.carrier == null, "a downed carrier drops it")
	ok(Vector2(H.spark_pos.x - p.pos.x, H.spark_pos.z - p.pos.z).length() < 9.0, "...where they fell")
	ok(float(p.get_meta("heart_slow", 0.0)) == 0.0, "and the slow is gone")
	p.downed = false
	p.out = false  # (the step above eliminated the test Hunter: bring them back)
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
	# ---- uplink unchanged: a non-carrier leaves as before, a carrier leaving by uplink drops it
	var c1 := rival
	m._extract(c1, "uplink", "test")
	ok(c1.extracted and H.carrier == p, "a rival leaving by uplink is unchanged and the carrier keeps it")
	# ---- leaving through the Gate
	_hold_f(m, p, float(rl["gate_hold_s"]) * 0.4)
	ok(not p.extracted, "a short hold at the Gate isn't enough")
	var seeds0 := int(p.seeds.get("emberberry", 0))
	var gems0 := p.gems
	var trust0 := 0.0
	var kin0: Kin = p.kin
	if kin0:
		trust0 = kin0.trust
	_hold_f(m, p, float(rl["gate_hold_s"]) + 0.3)
	ok(p.extracted, "holding at the Gate extracts the carrier")
	ok(String(m.result.get("how", "")) == Heart.HOW_EARLY, "...by the Heart Gate (the early seat)")
	var minor: Dictionary = rl["reward"]["minor"]
	var hb: Dictionary = m.result.get("heart", {})
	ok(not hb.is_empty() and (hb["egg"] as Dictionary).is_empty(), "the minor bundle has no egg")
	ok(
		int(p.seeds.get("emberberry", 0)) == seeds0 + int((minor["seeds"] as Dictionary)["emberberry"]),
		"...evolution foods"
	)
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
	m3._extract(q, "uplink", "test")
	ok(
		H3.state == Heart.S.READY and H3.carrier == null and H3.early_team < 0,
		"a carrier leaving by uplink leaves the Heartspark behind, no reward"
	)
	ok(m3.result.get("heart", {}).is_empty(), "...and the uplink result has no Heart bundle")
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
	ok(
		int(Save.d["goods"].get("heartwood", 0)) >= 1 and int(Save.d["goods"].get("starstone", 0)) >= 1,
		"the materials reach the stash"
	)
	ok(out.has("heart"), "and the results screen's data carries the bundle")
	_reward_gap(H3, m3.hunters[1], hb, major)
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
		_free(mm)


# ------------------------------------------------------------------ 2. the Gate takes the squad, and the state order
## The early exit paid the minor set, the end exit pays the major set, and the gap between them is the rules'
## (0051 names no ratio; heart.json: gems 40 vs 150, so the gap is the egg and a 3x-4x bundle).
func _reward_gap(h: Heart, who: Hunter, early_paid: Dictionary, final_paid: Dictionary) -> void:
	var rw: Dictionary = Heart.rules()["reward"]
	var minor: Dictionary = rw["minor"]
	var major: Dictionary = rw["major"]
	ok(
		(
			early_paid["goods"] == minor["goods"]
			and early_paid["seeds"] == minor["seeds"]
			and int(early_paid["gems"]) == int(minor["gems"])
		),
		"an early Heart exit paid exactly the minor set"
	)
	ok(
		(
			final_paid["goods"] == major["goods"]
			and final_paid["seeds"] == major["seeds"]
			and int(final_paid["gems"]) == int(major["gems"])
		),
		"the end exit pays exactly the major set"
	)
	var ratio := float(major["gems"]) / float(minor["gems"])
	ok(ratio >= 3.0 and ratio <= 5.0, "the gem gap is %.2fx (3x to 5x; 0051 leaves the ratio open)" % ratio)
	ok(not bool(minor["egg"]) and bool(major["egg"]), "only the end exit carries the Rare Egg")
	var g0 := who.gems
	h.pay(who, Heart.HOW_FINAL)
	ok(who.gems - g0 == int(major["gems"]), "the end exit's gems land on the Hunter")


func _gate_squad(main: Node) -> void:
	var m := _match(main, 8101, 2)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_charged(m)
	var p: Hunter = m.player
	var mates := _squad(m, p.team)
	var near: Hunter = mates[1] if mates[0] == p else mates[0]
	_put(m, p, H.site + Vector3(1, 0, 0))
	H._pick(p)
	ok(H.carrier == p, "(setup) the player carries the Heartspark")
	_put(m, p, H.gate)
	_put(m, near, H.gate + Vector3(float(rl["gate_take_r"]) - 2.5, 0, 0))
	m.knock(near, null, {})
	var gems0 := p.gems
	H._gate_done(p)
	ok(p.extracted and String(m.result.get("how", "")) == Heart.HOW_EARLY, "the carrier leaves by the Gate")
	ok(near.extracted, "a downed squadmate %.1f m from the Gate leaves too" % near.flat_dist(H.gate))
	ok(p.gems == gems0 + int(rl["reward"]["minor"]["gems"]), "minor pay")
	ok(H.state == Heart.S.WAITING and H.early_team == p.team, "the early seat is used: WAITING")
	var m2 := _match(main, 8102, 2)
	var H2: Heart = m2.heart
	for h in m2.hunters:
		_far(m2, h)
	_charged(m2)
	var p2: Hunter = m2.player
	var mates2 := _squad(m2, p2.team)
	var far2: Hunter = mates2[1] if mates2[0] == p2 else mates2[0]
	_put(m2, p2, H2.site + Vector3(1, 0, 0))
	H2._pick(p2)
	_put(m2, p2, H2.gate)
	# toward the Heart: the Gate stands near its island's rim, so a step straight out can be over the void
	var inward := (H2.site - H2.gate).normalized()
	_put(m2, far2, H2.gate + inward * (float(rl["gate_take_r"]) + 4.0))
	H2._gate_done(p2)
	ok(
		p2.extracted and not far2.extracted and far2.flat_dist(H2.gate) > float(rl["gate_take_r"]),
		"a squadmate %.1f m from the Gate stays in the match" % far2.flat_dist(H2.gate)
	)
	_free(m2)
	# the rest of the order on the first match: WAITING > FINAL at final_s > DONE when the ring fills
	var rival: Hunter = m.hunters.filter(func(h): return h.team != p.team)[0]
	_to(m, float(rl["final_s"]) + 0.1)
	ok(H.state == Heart.S.FINAL, "the Heart opens at %.0f s" % float(rl["final_s"]))
	_ring(m, rival, 0)
	_run(m, float(rl["final_hold_s"]) + 1.0)
	ok(H.state == Heart.S.DONE and rival.extracted, "a lone Hunter fills the ring: DONE")
	var order := H.trail.map(func(l): return String(l).split(" ", false)[1])
	var want := ["ASLEEP>CHARGING", "CHARGING>READY", "READY>CARRIED", "CARRIED>WAITING", "WAITING>FINAL", "FINAL>DONE"]
	ok(order == want, "state order %s" % ", ".join(order))
	ok(
		not H.go(Heart.S.CHARGING, "test") and H.state == Heart.S.DONE and H.refused == 1,
		"an edge the table lacks is refused, not applied"
	)
	_free(m)


# ------------------------------------------------------------------ 3. the final seat
func _final(main: Node) -> void:
	var m := _match(main, 8103, 2)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_charged(m)
	_to(m, float(rl["final_s"]) + 0.1)
	ok(H.state == Heart.S.FINAL, "at %.0f s the final seat opens" % float(rl["final_s"]))
	ok(H.spark_live() and H.early_team < 0, "an unused early seat stays open in FINAL")
	var a: Array = _squad(m, 0)
	var b: Array = _squad(m, 1)
	for h in a:
		_ring(m, h, a.find(h))
	ok(a.all(func(h): return H.in_ring(h)), "(setup) the squad stands in the ring")
	_run(m, 3.0)
	var two := H.final_prog
	ok(H.final_team == 0 and two > 0.0, "a squad alone in the ring fills it (%.0f%% in 3 s)" % (two * 100.0))
	var one_rate := 3.0 / float(rl["final_hold_s"])
	ok(two > one_rate * 1.2, "two of them fill it faster than one (Exits.crew_rate)")
	_ring(m, b[0], 2)
	ok(H.in_ring(b[0]), "(setup) a rival steps in")
	for i in 8:  # (held in place: the squad's Boki knock a rival about)
		_ring(m, b[0], 2)
		_run(m, 0.25)
	ok(absf(H.final_prog - two) < 0.01, "a standing rival in the ring stalls it")
	m.knock(b[0], null, {})
	_ring(m, b[0], 2)
	_run(m, 1.0)
	ok(H.final_prog > two, "a downed rival doesn't")
	_far(m, b[0])
	for h in a:
		_far(m, h)
	var held := H.final_prog
	_run(m, 1.0)
	ok(H.final_prog < held and H.final_team == 0, "an empty ring drains")
	for h in a:
		h.downed = false  # (the rival's Boki may have knocked one while it stood in the ring)
		h.hp = h.max_hp
		_ring(m, h, a.find(h))
	ok(a.all(func(h): return H.in_ring(h) and not h.downed), "(setup) the squad stands in the ring again")
	_run(m, float(rl["final_hold_s"]) * (1.0 - H.final_prog) / Exits.crew_rate(2) - 0.5)
	m.knock(a[1], null, {})
	_run(m, 2.0)
	ok(H.state == Heart.S.DONE, "full: the final seat fires")
	ok(a.all(func(h): return h.extracted), "the squad in the ring leaves, the downed one too")
	ok(not b[0].extracted and not b[1].extracted, "the rival squad stays")
	ok(String(m.result.get("how", "")) == Heart.HOW_FINAL or m.player.team != 0, "...by the Heart ring")
	var after := float(rl["end_after_final_s"])
	ok(m.length <= m.time + after + 0.01, "the islands fall %.0f s later" % after)
	ok(H.refused == 0, "no refused edges")
	_free(m)


# ------------------------------------------------------------------ 4. the last squad standing
func _rush(main: Node) -> void:
	var m := _match(main, 8104, 2)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_to(m, 30.0)
	ok(H.state == Heart.S.ASLEEP, "(setup) early in the match the Heart sleeps")
	for h in m.hunters:
		if h.team != 0:
			h.out = true
	m._check_last()
	ok(H.state == Heart.S.FINAL and H.rush, "the last squad: the final seat opens at once")
	var a: Array = _squad(m, 0)
	_ring(m, a[0], 0)
	_run(m, 2.0)
	var want := 2.0 / float(rl["final_hold_s"]) * float(rl["rush_k"])
	ok(absf(H.final_prog - want) < 0.05, "...and fills %.0fx faster (%.2f)" % [float(rl["rush_k"]), H.final_prog])
	ok(H.refused == 0, "no refused edges")
	_free(m)


# ------------------------------------------------------------------ 5. the Heart opens over a live spark
func _late(main: Node) -> void:
	var m := _match(main, 8106)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_to(m, float(rl["wake_s"]) + 1.0)
	ok(H.state == Heart.S.CHARGING, "(setup) the Heartspark is charging")
	for h in m.hunters:
		if h.team != 0:
			h.out = true
	m._check_last()
	ok(H.state == Heart.S.FINAL and H.rush, "the last squad while it charges: FINAL at once")
	_free(m)
	m = _match(main, 8107, 2)
	H = m.heart
	for h in m.hunters:
		_far(m, h)
	_charged(m)
	var p: Hunter = m.player
	_put(m, p, H.site + Vector3(1, 0, 0))
	H._pick(p)
	_to(m, float(rl["final_s"]) + 0.1)
	ok(H.state == Heart.S.FINAL and H.carrier == p, "the Heart opens on a carried spark: FINAL, still carried")
	_put(m, p, H.gate)
	H._gate_done(p)
	ok(
		p.extracted and H.early_team == p.team and H.state == Heart.S.FINAL,
		"...the carrier still takes the early seat, and the final stays open"
	)
	ok(H.refused == 0, "no refused edges")
	_free(m)


# ------------------------------------------------------------------ 6. Net round trip
func _net(main: Node) -> void:
	var host := _match(main, 8105, 2)
	var cli := _match(main, 8105, 2)
	var H: Heart = host.heart
	var C: Heart = cli.heart
	cli.net_on = true
	cli.is_host = false
	host.net_on = true
	Net.out_events.clear()
	for mm in [host, cli]:
		for h in mm.hunters:
			_far(mm, h)
			h.max_hp = 5000.0  # the charge runs 75 s with them parked at random spots
			h.hp = 5000.0
	_charged(host)
	cli.time = host.time
	var p: Hunter = host.player
	_put(host, p, H.site + Vector3(1, 0, 0))
	H._pick(p)
	_put(host, p, H.gate)
	var cp: Hunter = cli.ents_by_id.get(p.nid, null) as Hunter
	ok(cp != null, "(setup) the client has the same Hunter")
	_put(cli, cp, C.gate)
	H._gate_done(p)
	var evs: Array = Net.out_events.filter(func(e): return e[0] == "ht")
	ok(evs.any(func(e): return e[1] == "take" and e[2] == Heart.HOW_EARLY), "the host sends the seat it fired")
	for e in evs:
		C.net_in(JSON.parse_string(JSON.stringify(e)))
	ok(C.state == Heart.S.WAITING and C.early_team == p.team, "the client mirrors WAITING and the squad")
	ok(cp.extracted and String(cli.result.get("how", "")) == Heart.HOW_EARLY, "the client takes its own Hunter")
	ok(C.charge == H.charge and C.spark_pos.is_equal_approx(H.spark_pos), "charge and spark place match")
	var sent := Net.out_events.size()
	C.act("pick", cp)
	ok(Net.out_events.size() == sent + 1 and Net.out_events[-1][1] == "pick", "a client asks the host to pick")
	for mm in [host, cli]:
		mm.net_on = false
		_free(mm)
	Net.out_events.clear()
