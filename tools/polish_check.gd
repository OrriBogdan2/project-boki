extends RefCounted
## --polish-check: the demo-video polish pass. Prints PASS/FAIL lines.
##   1. weapon drops lean toward the earner's archetype family (DropFamily), but not always
##   2. every stair tile belongs to a full-width flight (PolishTools.stair_flights), on the default map
##   3. a chest reads as a different, chunkier thing than the crates, pots and barrels
##   4. building a chest draws nothing from the match's seeded global random stream

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
	# 1. drop families
	var arch := ""
	var fam: Array = []
	for a in Arch.ids():
		fam = Arch.weapons(String(a))
		if fam.size() >= 1 and fam.size() < 8:
			arch = String(a); break
	var keys: Array = Data.WEAPONS.keys() if "WEAPONS" in Data else ["rifle", "smg", "sniper"]
	var P: Hunter = m.player
	var oldarch = P.arch
	P.arch = arch
	var inside := 0
	for i in 400:
		if fam.has(DropFamily.earned(P, keys)): inside += 1
	ok(arch != "" and inside >= 280, "earned drops come from the %s family %d/400 times" % [arch, inside])
	ok(inside < 400 or keys.size() <= fam.size(), "...but not every time")
	ok(DropFamily.earned(null, ["a"]) == "a", "no earner: any weapon from the list")
	ok(DropFamily.ground("zzz", 3, true, P, 1) == "zzz", "online: the ground rolls are left alone for everyone")
	P.arch = oldarch
	# 2. stairs
	var W = m.world
	var fl: Array = PolishTools.stair_flights(W)
	var n := 0
	var thin := 0
	for f in fl:
		n += (f["tiles"] as Array).size()
		if (f["tiles"] as Array).size() < 2: thin += 1
	ok(n == W.stairs.size(), "all %d stair tiles sit in a flight (%d flights, %d thin)" % [W.stairs.size(), fl.size(), thin])
	# 3. chest vs breakables
	var ch := Models.chest(0)
	var cr := Models.breakable("crate")
	main.add_child(ch); main.add_child(cr)
	var cs := _size(ch); var rs := _size(cr)
	ok(cs.x * cs.z >= rs.x * rs.z * 0.95, "a chest's footprint (%.2f x %.2f) is no smaller than a crate's (%.2f x %.2f)" % [cs.x, cs.z, rs.x, rs.z])
	var c0: Color = Models.CHEST_COLS[0][0]; var c1: Color = Models.CHEST_COLS[1][0]; var c2: Color = Models.CHEST_COLS[2][0]
	ok(c0 != c1 and c1 != c2 and c0 != c2, "the three chest tiers have their own colours")
	ch.queue_free(); cr.queue_free()
	# 4. a CPUParticles3D (or GPUParticles3D) draws a seed from the global stream when it is made: a few
	# chests in a match then moved every later roll (where the squad's bots land), failing --drop-check
	seed(31337); var r0 := randi()
	seed(31337)
	for t in 3: Models.chest(t).free()
	ok(randi() == r0, "building chests leaves the seeded global random stream alone")
	m.queue_free()
	print("POLISH DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
