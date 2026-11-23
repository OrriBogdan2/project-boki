extends RefCounted
## --perch-check: every high perch (an island with "perch": true) can be reached by gliding its
## updraft chain. For each perch: start on the nearest non-perch ground to the chain's first column,
## jump, glide into the short column, then the tall one, then onto the perch. Reports who made it and
## how high. Perches only exist on Skyreach (the Hollow Crown has none), so the check runs there.
## The chain is the map's own updrafts beside the perch, lowest top first (tools/make_skyreach.py puts a
## short column off the Heart's rim and a tall one beside each perch), so it follows the map when the
## perches move. A map with no perches, or a perch with no updraft beside it, fails.
## Prints "PERCH <id>: made it|FAILED ..." and "PERCHCHECK done, N of M reached, failures: F".

const MAP := "skyreach"
const CHAIN_R := 18.0     # m from the perch's point of interest: the updrafts that belong to it
const SECS := 14.0

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var pm := Match.new()
	main.add_child(pm)
	var opts := {"teams": 2, "squad": 1, "tier": 0, "seed": 31, "no_drop": true, "length": 1e9, "autoplay": true}
	opts["map"] = MAP
	pm.start(opts)
	pm.set_process(false)
	for mb in pm.mobs: mb.queue_free()
	pm.mobs.clear()
	var ph: Hunter = pm.hunters[0]
	for o in pm.hunters:
		o.ctrl = "idle"
		if o != ph: o.teleport(pm.world.spawns[-1])
	ph.ctrl = "local"
	var w: World = pm.world
	var ok := 0
	var total := 0
	for pi in w.islands.size():
		if not w.islands[pi].get("perch", false): continue
		total += 1
		if _reach(pm, ph, pi): ok += 1
	var fails := total - ok + (1 if total == 0 else 0)
	print("PERCHCHECK done, %d of %d reached, failures: %d" % [ok, total, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## The updraft columns beside perch `pi`, lowest top first, as ground positions.
func _chain(w: World, pi: int) -> Array:
	var goal := w._poi(pi)
	var ups := w.updrafts.filter(func(u): return Vector2(u["pos"].x - goal.x, u["pos"].z - goal.z).length() < CHAIN_R)
	ups.sort_custom(func(a, b): return float(a["top"]) < float(b["top"]))
	return ups.map(func(u): return Vector2(u["pos"].x, u["pos"].z))

## Glide `ph` up perch `pi`'s chain; true when it stands on the perch within SECS.
func _reach(pm: Match, ph: Hunter, pi: int) -> bool:
	var w: World = pm.world
	var pid := String(w.islands[pi].get("id", pi))
	var steps := _chain(w, pi)
	var goal := w._poi(pi)
	if steps.is_empty():
		print("PERCH %s: FAILED, no updraft within %.0fm of the perch" % [pid, CHAIN_R])
		return false
	var u1: Vector2 = steps[0]
	# the nearest ground to the first column that isn't a perch
	var start := Vector3.INF
	var bd := 1e9
	for z in range(int(u1.y) - 10, int(u1.y) + 11):
		for x in range(int(u1.x) - 10, int(u1.x) + 11):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND: continue
			if w.islands[w.island_of(x, z)].get("perch", false): continue
			var d := Vector2(x + 0.5, z + 0.5).distance_to(u1)
			if d < bd:
				bd = d
				start = Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5)
	ph.teleport(start)
	ph.vel = Vector3.ZERO
	ph.grounded = true
	ph.glide_fuel = 1.0
	ph.pad = {}
	var stage := 0
	var t := 0.0
	var top_y := 0.0
	var made := false
	while t < SECS:
		var tgt: Vector2 = steps[stage] if stage < steps.size() else Vector2(goal.x, goal.z)
		var to := tgt - Vector2(ph.pos.x, ph.pos.z)
		ph.inp["move"] = to.normalized() if to.length() > 0.4 else Vector2.ZERO
		ph.inp["jump"] = t < 0.1 or (ph.grounded and w.island_of(ph.pos.x, ph.pos.z) != pi)
		ph.inp["glide"] = t > 0.25
		pm.step(Match.DT)
		t += Match.DT
		top_y = maxf(top_y, ph.pos.y)
		var up: Dictionary = w.updraft_at(ph.pos)
		if stage < steps.size() and not up.is_empty() and ph.pos.y > float(up["top"]) - 0.6:
			stage += 1
		if ph.grounded and w.island_of(ph.pos.x, ph.pos.z) == pi:
			made = true
			break
		if ph.out: break
	var how := "made it" if made else "FAILED"
	var info := [pid, how, t, top_y, goal.y, steps.size()]
	print("PERCH %s: %s in %.1fs, highest %.1fm (perch top %.1fm, %d columns)" % info)
	ph.out = false
	ph.hp = ph.max_hp
	return made
