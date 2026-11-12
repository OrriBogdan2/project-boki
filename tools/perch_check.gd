extends RefCounted
## --perch-check: for each perch, glide up its updraft chain onto it; reports who made it.

func run(main: Node) -> void:
	# tooling: for each perch, start on the island next to its updraft chain, jump, glide into the
	# short column, then the tall one, then onto the perch. Reports who made it and how high.
	var pm := Match.new()
	main.add_child(pm)
	pm.start({"teams": 2, "squad": 1, "tier": 0, "seed": 31, "no_drop": true, "length": 1e9, "autoplay": true})
	pm.set_process(false)
	for mb in pm.mobs: mb.queue_free()
	pm.mobs.clear()
	var ph: Hunter = pm.hunters[0]
	for o in pm.hunters:
		o.ctrl = "idle"
		if o != ph: o.teleport(pm.world.spawns[-1])
	ph.ctrl = "local"
	var chains := {"spire": [Vector2(127, 93), Vector2(130, 89)], "emberspire": [Vector2(72, 100), Vector2(78, 92)], "eye": [Vector2(124, 124), Vector2(130, 128)], "needle": [Vector2(146, 48), Vector2(139, 43)]}
	var ok := 0
	for pid in chains:
		var pi := -1
		for ii in pm.world.islands.size():
			if String(pm.world.islands[ii].get("id", "")) == pid: pi = ii
		var steps: Array = chains[pid]
		var u1: Vector2 = steps[0]
		# the nearest ground to the first column that isn't a perch
		var start := Vector3.INF; var bd := 1e9
		for z in range(int(u1.y) - 10, int(u1.y) + 11):
			for x in range(int(u1.x) - 10, int(u1.x) + 11):
				if not pm.world.inb(x, z) or pm.world.kind[pm.world.idx(x, z)] != World.T_GROUND: continue
				var isl := pm.world.island_of(x, z)
				if pm.world.islands[isl].get("perch", false): continue
				var d := Vector2(x + 0.5, z + 0.5).distance_to(u1)
				if d < bd: bd = d; start = Vector3(x + 0.5, pm.world.ground_at(x + 0.5, z + 0.5), z + 0.5)
		ph.teleport(start); ph.vel = Vector3.ZERO; ph.grounded = true; ph.glide_fuel = 1.0; ph.pad = {}
		var goal := pm.world._poi(pi)
		var stage := 0; var t := 0.0; var top_y := 0.0; var made := false
		while t < 14.0:
			var tgt: Vector2 = steps[stage] if stage < steps.size() else Vector2(goal.x, goal.z)
			var to := tgt - Vector2(ph.pos.x, ph.pos.z)
			ph.inp["move"] = to.normalized() if to.length() > 0.4 else Vector2.ZERO
			ph.inp["jump"] = t < 0.1 or (ph.grounded and pm.world.island_of(ph.pos.x, ph.pos.z) != pi)
			ph.inp["glide"] = t > 0.25
			pm.step(Match.DT); t += Match.DT
			top_y = maxf(top_y, ph.pos.y)
			var up: Dictionary = pm.world.updraft_at(ph.pos)
			if stage < steps.size() and not up.is_empty() and ph.pos.y > float(up["top"]) - 0.6:
				stage += 1
			if ph.grounded and pm.world.island_of(ph.pos.x, ph.pos.z) == pi:
				made = true; break
			if ph.out: break
		if made: ok += 1
		print("PERCH %s: %s in %.1fs, highest %.1fm (perch top %.1fm)" % [pid, "made it" if made else "FAILED", t, top_y, goal.y])
		ph.out = false; ph.hp = ph.max_hp
	print("PERCHCHECK done, %d of %d reached" % [ok, chains.size()])
	main.get_tree().quit()
