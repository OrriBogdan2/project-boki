extends RefCounted
## --drop-merge-check: fewer, bigger drops (DropMerge). Part 1: a cluster of gem and seed drops becomes
## one pile of each kind with the same totals, a far drop and other kinds stay apart, a pile is bigger the
## more it holds and never past the cap, picking it up gives exactly the total, and a collected gem node
## is reused by the next drop. Part 2 is an audit: 30 bots for 5 and 10 minutes, what lies on the ground
## (pickups, gear/loot pickups, deathboxes). Never touches the save.

var main: Node
var fails := 0

func ok(what: String, cond: bool, info := "") -> void:
	print("DROPMERGE %-64s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await _piles()
	await _audit()
	print("DROPMERGE DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _match(teams: int, squad: int, seed_: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": teams, "squad": squad, "tier": 0, "length": 1e9, "seed": seed_, "no_drop": true})
	m.set_process(false)
	return m

func _total(m: Match, kind: String, key := "") -> int:
	var t := 0
	for p in m.pickups:
		if p["kind"] == kind and p["key"] == key:
			t += int(p["v"])
	return t

func _piles() -> void:
	var m := await _match(1, 1, 31)
	var P: Hunter = m.player
	m.pickups.clear()
	var base := Vector3(P.pos.x + 30.0, P.pos.y + 5.0, P.pos.z)      # away from the player: nothing is grabbed
	var gem_sum := 0
	for i in 40:
		var v := 3 + i % 7
		gem_sum += v
		m.drop("gem", base + Vector3(float(i % 5) * 0.4, 0, float(i % 3) * 0.4), v)
	var far := base + Vector3(20.0, 0, 0)
	m.drop("gem", far, 5)
	for i in 10:
		m.drop("seed", base, 1, "emberberry")
	m.drop("seed", base, 4, "tidebloom")
	for i in 3:
		m.drop("tonic", base, 1)
	ok("40 gem drops in a cluster + 1 far + seeds + tonics: 7 pickups", m.pickups.size() == 7, "%d" % m.pickups.size())
	ok("gem totals equal: dropped %d + 5 far" % gem_sum, _total(m, "gem") == gem_sum + 5, "%d" % _total(m, "gem"))
	ok("seed totals equal per kind (10 emberberry, 4 tidebloom)",
		_total(m, "seed", "emberberry") == 10 and _total(m, "seed", "tidebloom") == 4)
	var pile: Dictionary = {}
	var lone: Dictionary = {}
	for p in m.pickups:
		if p["kind"] == "gem":
			if int(p["v"]) == gem_sum: pile = p
			else: lone = p
	var big: float = (pile["node"] as Node3D).scale.x
	ok("the pile is bigger than a lone gem and never past the cap",
		big > (lone["node"] as Node3D).scale.x and big <= DropMerge.MAX_SIZE + 0.001)
	# picking up: exactly the total (no Scavenger perk here), and the node goes to the pool
	var node: Node3D = pile["node"]
	var g0 := P.gems
	m._collect(P, pile)
	var want := int(round(float(gem_sum) * PerkOrbs.gem_mult(P)))
	ok("collecting the pile gives exactly the total", P.gems - g0 == want, "%d" % (P.gems - g0))
	ok("its node is hidden in the pool, not freed",
		is_instance_valid(node) and not node.visible and (m.get_meta("gem_pool") as Array).has(node))
	m.drop("gem", far + Vector3(50, 0, 0), 3)
	var reuse: Node3D = m.pickups[-1]["node"]
	ok("the next gem drop reuses that node, visible and normal size",
		reuse == node and node.visible and is_equal_approx(node.scale.x, 1.0))
	m.queue_free()

func _audit() -> void:
	var m := await _match(15, 2, 41)
	var bots := m.hunters.size() - 1
	for minute in [5, 10]:
		while m.time < minute * 60.0:
			m.step(Match.DT)
		var gems := 0
		for p in m.pickups:
			if p["kind"] == "gem":
				gems += int(p["v"])
		print("DROPMERGE audit %2d min, %d bots+you: pickups %d (gem value %d), gear/loot %d, deathboxes %d" % [
			minute, bots, m.pickups.size(), gems, m.wpicks.size(), m.boxes.size()])
	ok("the 30-bot match ran 10 minutes", m.time >= 600.0)
	m.queue_free()
