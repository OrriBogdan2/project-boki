extends RefCounted
## --mob-reap-check: a long Training Grounds session of dummy kills must not grow `mobs` or the node
## count (docs/BUGHUNT_1111.md item 7): a dead monster is freed once its dissolve has played out, is
## gone from `mobs` and `ents_by_id`, and nothing a hunter or Boki remembers points at it. Never
## touches the save. --minutes=N sets the soak length (default 10, sim time).

const DT := 1.0 / 30.0
const KILL_EVERY_S := 1.0
const SAMPLE_S := 60.0
const FLAT_MOBS := 12  # live + dying monsters at most, at any sample
const NODES_PER_KILL := 8.0  # a leaked body is ~50 nodes; what is left is the perk orbs a Brute or Warden leaves

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("MOBREAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var minutes := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = float(a.substr(10))
	var m := Match.new()
	main.add_child(m)
	(
		m
		. start(
			{
				"training": true,
				"teams": 1,
				"squad": 1,
				"tier": 0,
				"length": 1e9,
				"seed": 4242,
				"no_drop": true,
				"god": true,
			}
		)
	)
	m.set_process(false)
	var first_nodes := -1
	var kills := 0
	var most := 0
	var next_kill := 0.0
	var next_sample := 0.0
	var made_ids: Array = []
	var t := 0.0
	while t < minutes * 60.0:
		m.step(DT)
		for mb in m.mobs:
			mb.render(DT, 1.0)
		t += DT
		if t >= next_kill:
			next_kill = t + KILL_EVERY_S
			for p in m.pickups.duplicate():
				m._collect(m.player, p)  # (the player takes the drops: loot piles are not the leak)
			await main.get_tree().process_frame  # (queue_free runs between frames)
			for mb in m.mobs.filter(func(x): return not x.dead):
				m.player.teleport(mb.pos)  # (stand where it dies)
				mb.hurt(1e6, m.player, {})
				kills += 1
				made_ids.append(mb.get_instance_id())
		if t >= next_sample:
			next_sample = t + SAMPLE_S
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			if first_nodes < 0:
				first_nodes = nodes
			if t > 1.0:
				most = maxi(most, m.mobs.size())  # (t=0 still holds the map's own camps)
			print(
				(
					"MOBREAP t=%ds mobs=%d ids=%d nodes=%d kills=%d"
					% [int(t), m.mobs.size(), m.ents_by_id.size(), nodes, kills]
				)
			)
	var nodes_end := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var freed := made_ids.filter(func(i): return not is_instance_valid(instance_from_id(i))).size()
	print(
		(
			"MOBREAP SUMMARY kills=%d mobs_end=%d max_mobs=%d freed=%d nodes %d -> %d"
			% [kills, m.mobs.size(), most, freed, first_nodes, nodes_end]
		)
	)
	ok(kills >= int(minutes * 10.0), "the soak killed %d monsters" % kills)
	ok(most <= FLAT_MOBS, "mobs stayed flat (max %d)" % most)
	var bodies := m.get_children().filter(func(c): return c is Mob).size()
	ok(bodies <= FLAT_MOBS, "no dead body left in the scene (%d Mob nodes)" % bodies)
	var grew := nodes_end - first_nodes
	ok(float(grew) <= NODES_PER_KILL * kills, "nodes grew %d over %d kills" % [grew, kills])
	ok(freed >= kills - FLAT_MOBS, "dead monsters were freed (%d of %d)" % [freed, kills])
	var stale := 0
	for e in m.ents_by_id.values():
		if not is_instance_valid(e):
			stale += 1
	ok(stale == 0, "ents_by_id holds no freed monsters (%d stale)" % stale)
	for h in m.hunters:
		for e in [h.last_hit_by, h.burn_by, h.ai.get("tgt"), h.ai.get("seen")]:
			if typeof(e) == TYPE_OBJECT and not is_instance_valid(e):
				stale += 1
	ok(stale == 0, "no hunter remembers a freed body (%d stale)" % stale)
	m.queue_free()
	print("MOBREAP DONE, failures: %d" % bad)
	main.get_tree().quit(mini(bad, 1))
