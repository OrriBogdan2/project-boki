extends RefCounted
## --interact-pick-check: when several things are in reach of F, one rule picks (InteractPick):
##  a teammate to revive first, then the target nearest the cursor, then the one nearest the body;
##  the pick holds for a moment (and while F is held) so the prompt does not flicker; the prompt
##  names the target and the key. Overlapping cases are built in a real match. Never touches the save.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("IPICK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _chest(at: Vector3) -> Dictionary:
	var c := {"pos": at, "open": false, "prog": 0.0, "free": true}
	m.chests.append(c)
	return c

func _pick(cursor: Variant, want := false) -> Dictionary:
	m.player.inp["interact"] = want
	m.player.inp["aim"] = cursor if cursor != null else m.player.pos
	m._update_interact(Match.DT)
	return m.interact

func _tick(sec: float) -> void:
	for i in int(sec / Match.DT):
		m.time += Match.DT
		m._update_interact(Match.DT)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.chests.clear()
	m.boxes.clear()
	m.wpicks.clear()
	m.shrines.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != m.player: h.teleport(m.player.pos + Vector3(60, 0, 0))
	var p := m.player
	var g := p.pos
	var key := Settings.key_cap("interact")
	var near := _chest(g + Vector3(0.6, 0, 0))      # nearest the body
	var far := _chest(g + Vector3(-1.2, 0, 0))      # still in reach (< 1.6 m), further from the body
	_tick(1.0)
	ok(is_same(_pick(null)["chest"], near), "no cursor: the target nearest the body")
	_tick(0.4)
	var it := _pick(g + Vector3(-1.2, 0, 0))
	ok(is_same(it["chest"], far), "cursor on the far one: it takes over")
	ok(is_same(_pick(g + Vector3(0.6, 0, 0))["chest"], far), "cursor back at once: the pick holds (hysteresis)")
	_tick(0.4)
	ok(is_same(_pick(g + Vector3(0.6, 0, 0))["chest"], near), "cursor on the near one, after the hold: it takes over")
	it = _pick(g + Vector3(-1.2, 0, 0))
	_tick(0.4)
	it = _pick(g + Vector3(-1.2, 0, 0))
	var shown := String(it["label"])
	ok(shown.contains(key) and shown.contains("Chest"), "the prompt names the target and the key: '%s'" % shown)
	_tick(0.4)
	ok(is_same(_pick(g + Vector3(0.6, 0, 0), true)["chest"], far), "F held: the target never changes mid-hold")
	_pick(null)
	_tick(0.4)
	ok(is_same(_pick(g + Vector3(0.6, 0, 0))["chest"], near), "F let go and cursor on the near one: it takes over")
	_tick(0.4)
	ok(is_same(_pick(g + Vector3(30, 0, 30))["chest"], near), "cursor far from both: nearest the body")
	# a flicker: the cursor jitters between the two every frame, the prompt must not follow it
	var flips := 0
	var last: Variant = null
	for i in 20:
		var cur := g + Vector3(-1.2 if i % 2 == 0 else 0.6, 0, 0)
		var c = _pick(cur)["chest"]
		if last != null and not is_same(c, last): flips += 1
		last = c
		m.time += Match.DT
	ok(flips <= 1, "a jittering cursor barely flickers the prompt (%d flips in 20 frames, 19 without the hold)" % flips)
	# a downed teammate beats a chest right under the cursor
	var mate: Hunter = m.hunters.filter(func(x): return x.team == p.team and x != p)[0]
	mate.teleport(g + Vector3(1.0, 0, 0))
	mate.downed = true
	_tick(0.4)
	it = _pick(g + Vector3(0.6, 0, 0))
	ok(it["kind"] == "revive" and is_same(it["ent"], mate), "a teammate to revive beats the target under the cursor")
	ok(String(it["label"]).contains(mate.pname), "the revive prompt names the teammate")
	mate.downed = false
	mate.teleport(g + Vector3(60, 0, 0))
	# a deathbox of a teammate whose soul is here is a revive too
	var box := {"pos": g + Vector3(0.2, 0, 0), "owner": mate, "empty": true}
	var rev := {"kind": "boxrev", "box": box, "label": "Hold %s to bring %s back" % [key, mate.pname]}
	var opn := {"kind": "chest", "chest": near, "label": "Hold %s to open" % key}
	var cs := [InteractPick.cand(rev, box["pos"], box, mate.pname, true)]
	cs.append(InteractPick.cand(opn, near["pos"], near, "Chest"))
	var pk := InteractPick.new()
	ok(pk.pick(p, cs, near["pos"], false, 0.0)["kind"] == "boxrev", "pick(): a box revive beats a chest at the cursor")
	# an info line (a closed dock) never beats something you can do
	var info := InteractPick.cand({"kind": "exit", "x": {}, "label": "This dock has closed"}, g, "dock", "")
	ok(pk.pick(p, [info, cs[1]], null, false, 10.0)["kind"] == "chest", "pick(): an info line comes last")
	ok(pk.pick(p, [info], null, false, 20.0)["kind"] == "exit", "pick(): an info line alone still shows")
	# standing between two near-equal targets: a small step does not swap them, a real one does
	var ca := {"kind": "chest", "label": "A %s" % key}
	var cb := {"kind": "chest", "label": "B %s" % key}
	var pm := InteractPick.new()
	var two := func(da: float, db: float) -> Array:
		var a := InteractPick.cand(ca, g + Vector3(da, 0, 0), "a", "A")
		return [a, InteractPick.cand(cb, g + Vector3(0, 0, db), "b", "B")]
	ok(is_same(pm.pick(p, two.call(0.9, 1.0), null, false, 40.0), ca), "pick(): nearest the body first")
	ok(is_same(pm.pick(p, two.call(1.0, 0.85), null, false, 45.0), ca), "pick(): 0.15 m nearer is not enough")
	ok(is_same(pm.pick(p, two.call(1.2, 0.6), null, false, 50.0), cb), "pick(): a clearly nearer one does")
	ok(pk.pick(p, [], null, false, 30.0).is_empty(), "pick(): nothing in reach, nothing shown")
	print("INTERACT-PICK-CHECK: %s" % ("PASS" if bad == 0 else "%d FAIL" % bad))
	Save.no_write = false
	main.get_tree().quit(0 if bad == 0 else 1)
