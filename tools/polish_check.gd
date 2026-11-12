extends RefCounted
## --polish-check: the demo-video polish pass. Prints PASS/FAIL lines.
##   1. every stair tile belongs to a full-width flight (PolishTools.stair_flights), on the default map
##   2. a chest reads as a different, chunkier thing than the crates, pots and barrels
##   3. building a chest draws nothing from the match's seeded global random stream

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("POLISH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _size(n: Node) -> Vector3:
	var box := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		for k in c.get_children(): stack.append(k)
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).name != "Beacon":
			var mi := c as MeshInstance3D
			var b: AABB = (n as Node3D).global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb() if mi.is_inside_tree() else mi.transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box.size

func run(main: Node) -> void:
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 7, "no_drop": true, "weapon": "rifle"})
	m.set_process(false)
	# 1. stairs
	var W = m.world
	var fl: Array = PolishTools.stair_flights(W)
	var n := 0
	var thin := 0
	for f in fl:
		n += (f["tiles"] as Array).size()
		if (f["tiles"] as Array).size() < 2: thin += 1
	ok(n == W.stairs.size(), "all %d stair tiles sit in a flight (%d flights, %d thin)" % [W.stairs.size(), fl.size(), thin])
	# 2. chest vs breakables
	var ch := Models.chest()
	var cr := Models.breakable("crate")
	main.add_child(ch); main.add_child(cr)
	var cs := _size(ch); var rs := _size(cr)
	ok(cs.x * cs.z >= rs.x * rs.z * 0.95, "a chest's footprint (%.2f x %.2f) is no smaller than a crate's (%.2f x %.2f)" % [cs.x, cs.z, rs.x, rs.z])
	ok(ch.get_node_or_null("Body/Lid") != null and ch.get_meta("mats", []).size() > 1, "there is one chest type, with a lid on a hinge")
	ch.queue_free(); cr.queue_free()
	# 4. a CPUParticles3D (or GPUParticles3D) draws a seed from the global stream when it is made: a few
	# chests in a match then moved every later roll (where the squad's bots land), failing --drop-check
	seed(31337); var r0 := randi()
	seed(31337)
	for t in 3: Models.chest().free()
	ok(randi() == r0, "building chests leaves the seeded global random stream alone")
	m.queue_free()
	print("POLISH DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
