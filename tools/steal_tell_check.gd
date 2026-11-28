extends RefCounted
## --steal-tell-check: the steal window's look (StealTell, docs/HUD.md "Steal window"). A lair boss at
## or under content/rules/steal_window.json "at" of its health opens the window: its bar fill turns
## gold, and the STEAL mark is for squads with a Hunter within KillXp.SHARE_R of it. Other monsters
## never open it. A prize monster (StealReel) cries once at the line and reels on the first drop under
## it. Never touches the save.

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("STEALTELL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var pc: Hunter = m.player
	var cc: Hunter = m.hunters.filter(func(x): return x.team == pc.team and x != pc)[0]
	var q1: Hunter = m.hunters.filter(func(x): return x.team != pc.team)[0]
	var rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/steal_window.json"))
	var at := StealTell.at()
	ok(
		rules is Dictionary and is_equal_approx(at, float(rules["at"])) and is_equal_approx(at, 0.25),
		"the window opens at %.2f of max health, read from content/rules/steal_window.json" % StealTell.at()
	)
	var fx: Dictionary = m.lairs.list[0]
	m.lairs.activate(fx)
	for g in fx["guards"]:
		if is_instance_valid(g):
			g.dead = true
	m.lairs.open(fx, q1, "dial")
	_spot(pc, fx["c"] - Vector3(fx["out"].x, 0, fx["out"].y) * 3.0)
	m.step(Match.DT)
	var b: Boss = fx["boss_mob"]
	if b.buried:
		b._clear_attack()
	var red := Color("ff6a5a")
	# 1. the line: above it shut, on it open, dead shut
	b.hp = b.max_hp
	ok(
		not StealTell.open(b) and StealTell.fill(b, red, 1.0) == red,
		"a full-health boss: no window, the bar keeps its red"
	)
	b.hp = b.max_hp * (StealTell.at() + 0.01)
	ok(not StealTell.open(b), "just over the line (%.0f of %.0f): still shut" % [b.hp, b.max_hp])
	b.hp = b.max_hp * StealTell.at()
	var lo := StealTell.fill(b, red, 0.0)
	var hi := StealTell.fill(b, red, 0.125)
	ok(StealTell.open(b), "on the line: open")
	ok(
		lo != red and absf(lo.h - red.h) > 0.08 and absf(lo.h - Color("e0b0ff").h) > 0.2 and hi != lo,
		(
			"open, the fill is gold (hue %.2f, red %.2f) and pulses (%s -> %s)"
			% [lo.h, red.h, lo.to_html(false), hi.to_html(false)]
		)
	)
	b.dead = true
	ok(not StealTell.open(b), "a dead boss: shut")
	b.dead = false
	# 2. other monsters never open it
	var sk := m.spawn_mob("skitter", fx["c"])
	sk.hp = sk.max_hp * 0.05
	ok(not StealTell.open(sk), "a skitter at 5% health: no window (lair bosses only)")
	m.mobs.erase(sk)
	sk.queue_free()
	# 3. the mark's audience: squads with a Hunter within the kill-share radius
	var out := Vector3(fx["out"].x, 0, fx["out"].y)
	var far: Vector3 = b.pos + out * (KillXp.SHARE_R + 30.0)
	for i in m.hunters.size():
		_spot(m.hunters[i], far + Vector3(i * 1.5, 0, 0))
	ok(
		not StealTell.near(m, b, pc.team) and not StealTell.near(m, b, q1.team),
		"nobody within %.0f m: no squad sees the mark" % KillXp.SHARE_R
	)
	_spot(cc, b.pos + out * (KillXp.SHARE_R - 2.0))
	ok(
		StealTell.near(m, b, pc.team) and not StealTell.near(m, b, q1.team),
		(
			"a squadmate at %.1f m: our squad sees it, the rival squad (%.0f m off) doesn't"
			% [cc.flat_dist(b), q1.flat_dist(b)]
		)
	)
	_spot(cc, b.pos + out * (KillXp.SHARE_R + 2.0))
	ok(not StealTell.near(m, b, pc.team), "the squadmate steps to %.1f m: gone" % cc.flat_dist(b))
	_spot(q1, b.pos - out * 10.0)
	ok(StealTell.near(m, b, q1.team), "a rival at %.1f m: the rival squad sees it too" % q1.flat_dist(b))
	q1.out = true
	ok(not StealTell.near(m, b, q1.team), "a Hunter out of the match doesn't count")
	q1.out = false
	# 4. the reel: the first drop under the line stands a prize monster open for the reel time, at normal damage
	b.stagger_t = 0.0
	b.win_reeled = false
	b.hp = b.max_hp * 0.6
	b.hurt(50.0, pc, {"src": "shot"})
	ok(b.stagger_t <= 0.0 and not b.win_reeled, "a hit that stays above the line: no reel")
	b.hp = b.max_hp * StealTell.at() + 10.0
	b.hurt(50.0, pc, {"src": "shot"})
	ok(
		b.win_reeled and is_equal_approx(b.stagger_t, StealReel.reel_time()) and b.stagger_mult == 1.0,
		"the first hit under the line reels it %.1f s at normal damage (x%.1f)" % [b.stagger_t, b.stagger_mult]
	)
	b.stagger_t = 0.0
	b.hurt(50.0, pc, {"src": "shot"})
	ok(b.stagger_t <= 0.0, "the next hit in the window doesn't reel it again")
	StealReel.tick(b)
	ok(b.win_cried, "it has cried out for the window")
	b.hp = b.max_hp
	StealReel.tick(b)
	ok(not b.win_cried and not b.win_reeled, "healed above the line: the cry and the reel rearm")
	sk = m.spawn_mob("skitter", fx["c"])
	sk.hp = sk.max_hp * 0.2
	sk.hurt(1.0, pc, {"src": "shot"})
	ok(sk.stagger_t <= 0.0 and not StealReel.open(sk), "a skitter in the same band: no reel (not a prize monster)")
	m.mobs.erase(sk)
	sk.queue_free()
	_last_hit_tell(b, pc, q1, red)
	print("STEALTELL done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## 5. The last-hit tell: the line, the body pulse, the bar's leading squad and its "bat" field.
func _last_hit_tell(b: Boss, pc: Hunter, q1: Hunter, red: Color) -> void:
	var rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/steal_window.json"))
	ok(
		is_equal_approx(StealTell.tell_at(), float(rules["tell_at"])) and StealTell.tell_at() == 0.15,
		"the tell line is %.2f, from content/rules" % StealTell.tell_at()
	)
	b.dead = false
	b.damage_by.clear()
	b.hp = b.max_hp * (StealTell.tell_at() + 0.01)
	StealReel.tick(b)
	ok(not StealTell.tell(b) and b.wash == 0.0, "just over the tell line: no body pulse")
	b.hp = b.max_hp * StealTell.tell_at()
	StealReel.tick(b)
	var w0 := StealTell.wash(b, 0.0)
	var w1 := StealTell.wash(b, 0.125)
	ok(StealTell.tell(b) and b.wash > 0.0 and w0 != w1, "on the line: the body pulses (wash %.2f -> %.2f)" % [w0, w1])
	ok(StealTell.fill(b, red, 1.0) != red, "the bar fill is off its red")
	var ck := m.spawn_mob("brute", b.pos)
	ck.hp = ck.max_hp * 0.1
	StealReel.tick(ck)
	ok(
		StealTell.tell(ck) and ck.wash > 0.0 and StealTell.fill(ck, red, 1.0) != red,
		"a camp chief (brute) at 10%: the same tell"
	)
	ck.dead = true
	ok(not StealTell.tell(ck), "a dead chief: none")
	m.mobs.erase(ck)
	ck.queue_free()
	var sk := m.spawn_mob("skitter", b.pos)
	sk.hp = sk.max_hp * 0.05
	ok(not StealTell.tell(sk), "a skitter at 5%: no tell")
	m.mobs.erase(sk)
	sk.queue_free()
	# the leading squad: most damage wins, and a copy takes the host's word when it has no tally
	b.damage_by = {pc.team: 40.0, q1.team: 90.0}
	ok(b.lead() == q1.team, "the squad with the most damage (team %d, 90 vs 40) leads" % b.lead())
	Net.out_events.clear()
	m.net_on = true
	BossNet.watch(b)
	m.net_on = false
	var ev: Array = Net.out_events.back() if not Net.out_events.is_empty() else []
	ok(
		ev.size() == 8 and ev[0] == "bat" and int(ev[7]) == q1.team,
		"the host's bat event ends with the leader (%s)" % [ev]
	)
	Net.out_events.clear()
	var copy := BossNet.make(m, "bt_copy", b.mkind, b.pos)
	m.ents_by_id["bt_copy"] = copy
	ev[1] = "bt_copy"
	BossNet.net_in(m, ev)
	ok(
		copy.damage_by.is_empty() and copy.lead() == q1.team,
		"a remote copy reads the leader off the event (team %d)" % copy.lead()
	)
	m.ents_by_id.erase("bt_copy")
	copy.free()
