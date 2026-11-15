extends RefCounted
## --steal-tell-check: the steal window's look (StealTell, docs/HUD.md "Steal window"). A lair boss at
## or under content/rules/steal_window.json "at" of its health opens the window: its bar fill turns
## gold, and the STEAL mark is for squads with a Hunter within KillXp.SHARE_R of it. Other monsters
## never open it, and it changes no damage. Never touches the save.

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
	var P: Hunter = m.player
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/steal_window.json"))
	var at := StealTell.at()
	ok(
		rules is Dictionary and is_equal_approx(at, float(rules["at"])) and is_equal_approx(at, 0.25),
		"the window opens at %.2f of max health, read from content/rules/steal_window.json" % StealTell.at()
	)
	var F: Dictionary = m.lairs.list[0]
	m.lairs.activate(F)
	for g in F["guards"]:
		if is_instance_valid(g):
			g.dead = true
	m.lairs.open(F, Q, "dial")
	_spot(P, F["c"] - Vector3(F["out"].x, 0, F["out"].y) * 3.0)
	m.step(Match.DT)
	var b: Boss = F["boss_mob"]
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
	var sk := m.spawn_mob("skitter", F["c"])
	sk.hp = sk.max_hp * 0.05
	ok(not StealTell.open(sk), "a skitter at 5% health: no window (lair bosses only)")
	m.mobs.erase(sk)
	sk.queue_free()
	# 3. the mark's audience: squads with a Hunter within the kill-share radius
	var out := Vector3(F["out"].x, 0, F["out"].y)
	var far: Vector3 = b.pos + out * (KillXp.SHARE_R + 30.0)
	for i in m.hunters.size():
		_spot(m.hunters[i], far + Vector3(i * 1.5, 0, 0))
	ok(
		not StealTell.near(m, b, P.team) and not StealTell.near(m, b, Q.team),
		"nobody within %.0f m: no squad sees the mark" % KillXp.SHARE_R
	)
	_spot(C, b.pos + out * (KillXp.SHARE_R - 2.0))
	ok(
		StealTell.near(m, b, P.team) and not StealTell.near(m, b, Q.team),
		(
			"a squadmate at %.1f m: our squad sees it, the rival squad (%.0f m off) doesn't"
			% [C.flat_dist(b), Q.flat_dist(b)]
		)
	)
	_spot(C, b.pos + out * (KillXp.SHARE_R + 2.0))
	ok(not StealTell.near(m, b, P.team), "the squadmate steps to %.1f m: gone" % C.flat_dist(b))
	_spot(Q, b.pos - out * 10.0)
	ok(StealTell.near(m, b, Q.team), "a rival at %.1f m: the rival squad sees it too" % Q.flat_dist(b))
	Q.out = true
	ok(not StealTell.near(m, b, Q.team), "a Hunter out of the match doesn't count")
	Q.out = false
	# 4. looks only: a hit in the window does what the same hit does above it
	b.stagger_t = 0.0
	b.hp = b.max_hp * 0.6
	var above := b.hurt(50.0, P, {"src": "shot"})
	b.stagger_t = 0.0
	b.hp = b.max_hp * StealTell.at() * 0.8
	var inside := b.hurt(50.0, P, {"src": "shot"})
	ok(
		above > 0.0 and is_equal_approx(above, inside) and b.stagger_t <= 0.0,
		"the same 50 hit deals %.1f above the line and %.1f in the window, no reel" % [above, inside]
	)
	print("STEALTELL done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
