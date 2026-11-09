extends "res://tools/archetype_check.gd"
## --ttk-check: time to down, every Hunter's LMB into every other Hunter (docs/TTK.md). A training
## dummy takes the defender's base health and armour; the attacker stands 8 m off with the aim dead
## on it and uses the best LMB mode that reaches (hold, taps, or hold-to-charge). An LMB that cannot
## reach 8 m (melee, short guns) is measured again at 80% of its range and marked "near".
## Prints TTK <attacker> <defender> <mode> <metres> <seconds> <hits> rows that tools/ttk_table.py turns into
## the table, and asserts every cell downs the dummy and the dummy's numbers are the Hunter's own.

const FAR := 8.0               # m, the owner's distance
const NEAR_K := 0.8            # fallback: this share of the weapon's range
const CAP := 20.0              # s, a cell that takes longer is called unreachable

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("hero_combo_check", self)      # (kept alive while it awaits, as the combo checks do)
	Save.no_write = true
	Save.d = Save.fresh()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/ttk_source.json"))
	var order: Array = source["order"]
	var probe := setup(order[0], FAR)
	for d in order:
		var h: Hunter = (probe[0] as Match).make_hunter("D", 5, Arch.weight(d), d, "idle", {}, probe[4], {"arch": d})
		var hp := float(Data.CLASSES[Arch.weight(d)]["hp"])
		var armour: float = round(hp * Hunter.ARMOR_DUR)
		var own: bool = h.max_hp == hp and h.max_armor == armour
		var what: String = "%s dummy: base health %d and armour %d are the Hunter's own" % [d, hp, armour]
		ok(what, own, "%s/%s" % [h.max_hp, h.max_armor])
	await done(probe[0])
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--ttk-only="): only = String(arg).substr(11)
	for a in order:
		if only == "" or only == a: await _attacker(a, order, source["hunters"][a])
	print("TTK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _attacker(a: String, order: Array, src: Dictionary) -> void:
	var wd: Dictionary = Data.weapon_stats(Arch.signature(a))
	var modes: Array = ["hold", "tap", "charge"] if wd.has("charge_time") else ["hold", "tap"]
	if src.has("mode"): modes = [src["mode"]]      # the mode the source's LMB figure describes
	var near := minf(FAR, float(wd["range"]) * NEAR_K)      # (a melee weapon's range is its reach)
	# one mode and distance per attacker: the fastest that downs every defender, 8 m first
	var best: Array = []
	var best_sum := INF
	var best_mode := ""
	var dist := FAR
	for pass_dist in [FAR, near]:
		dist = pass_dist
		for mode in modes:
			var rows := await _row(a, order, mode, dist)
			var sum := 0.0
			for x in rows: sum += x[0]
			print("TTKMODE %s %s %.1f m: %.1fs in all" % [a, mode, dist, sum])
			if sum < best_sum or best.is_empty():
				best_sum = sum
				best = rows
				best_mode = mode
		if best_sum < INF or near == FAR: break
	for i in order.size():
		ok("%s into %s: down in %.1fs (%s, %.1f m)" % [a, order[i], best[i][0], best_mode, dist], best[i][0] < INF)
		print("TTK %s %s %s %.1f %.2f %d" % [a, order[i], best_mode, dist, best[i][0], best[i][1]])

## One fresh match (no state left over from another mode) and every defender in turn.
func _row(a: String, order: Array, mode: String, dist: float) -> Array:
	var r := setup(a, FAR)
	var rows: Array = []
	for d in order:
		var hp := float(Data.CLASSES[Arch.weight(d)]["hp"])
		rows.append(_time_to_down(r[0], r[1], r[2], mode, dist, hp, round(hp * Hunter.ARMOR_DUR)))
		if rows[-1][0] == INF: break      # (a mode that misses one defender misses them all)
	while rows.size() < order.size(): rows.append([INF, 0])
	await done(r[0])
	return rows

## [seconds until the dummy is down (INF if still up after CAP), hits that landed on the dummy].
func _time_to_down(m: Match, P: Hunter, T: Hunter, mode: String, dist: float, hp: float, armor: float) -> Array:
	step(m, 1.5, func(): P.inp["fire"] = false)      # rest: magazines refill, combos and cooldowns end
	P.fire_cd = 0.0
	P.warm_t = 0.0
	P.reload_t = 0.0
	T.max_hp = hp
	T.hp = hp
	T.max_armor = armor
	T.armor = armor
	T.downed = false
	var home := P.pos
	var t := 0.0
	var hits := [0]
	var count := func(by: Node, target: Node, _amount: float, _tags: Array): if by == P and target == T: hits[0] += 1
	CombatBus.hit_landed.connect(count)
	while t < CAP and T.hp > 0.0 and not T.downed:
		T.teleport(home + Vector3(dist, 0, 0))
		T.vel = Vector3.ZERO
		aim_at(P, T.pos)
		match mode:
			"tap": P.inp["fire"] = int(t / 0.05) % 2 == 0
			"charge":
				P.inp["fire"] = not (P.inp["fire"] and P.charge_k() >= 1.0)
			_: P.inp["fire"] = true
		P.teleport(home)      # (lunges and recoil would walk the shooter off the mark)
		P.vel = Vector3.ZERO
		m.step(DT)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		t += DT
	P.inp["fire"] = false
	CombatBus.hit_landed.disconnect(count)
	return [t if (T.hp <= 0.0 or T.downed) else INF, hits[0]]
