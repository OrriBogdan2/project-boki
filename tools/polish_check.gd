extends RefCounted
## --polish-check: the demo-video polish pass. Prints PASS/FAIL lines.
##   1. every stair tile belongs to a full-width flight (PolishTools.stair_flights), on the default map
##   2. a chest reads as a different, chunkier thing than the crates, pots and barrels
##   3. building a chest draws nothing from the match's seeded global random stream
##   5. hit-stop and hit flash match the source (content/rules/hitstop.json): a light hit (Vex's rifle round) only
##      flashes; a heavy one (Kael's slam, Albert's wall bash, Lace's Supercharged arrow) also holds a few frames,
##      under one footage frame; the body flash sits in the footage band, the same for light and heavy

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
	_hitstop(m)
	m.queue_free()
	print("POLISH DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## 5. One hit of each kind between two bodies, with nobody as the player (the per-body freeze every online hit takes).
func _hitstop(m: Match) -> void:
	var r: Dictionary = Feel.rules()
	var frame := float(r["footage_frame_s"])
	var band: Array = r["flash_s"]
	var A: Hunter = m.player
	var V: Hunter = m.hunters[1] if m.hunters[0] == A else m.hunters[0]
	var rifle := float(Data.weapon_stats("quill_rifle")["dmg"])
	var supercharged := float(Data.weapon_stats("longbow")["draw"][1][1])
	var hits := [
		["Vex's rifle round", rifle, {"src": "primary"}],
		["Lace's Supercharged arrow", supercharged, {"src": "primary"}],
		["Kael's slam", 30.0, {"melee": true, "heavy": true, "payoff": false}],
		["Albert's wall bash", 10.0, {"src": "wall"}],
	]
	m.player = null
	for row in hits:
		m.time += 1.0          # (past Feel.HS_MULTI: each row is a first hit)
		A.freeze_t = 0.0
		V.freeze_t = 0.0
		V.hp = V.max_hp
		var t := Feel.hitstop(m, A, V, float(row[1]), row[2])
		var light: bool = row == hits[0]
		var held := V.freeze_t > 0.0 and (A.freeze_t > 0.0) == bool(row[2].get("melee", false))
		var none := V.freeze_t <= 0.0 and A.freeze_t <= 0.0
		var how := "a light hit only flashes" if light else "a few frames"
		ok(V.freeze_t < frame and A.freeze_t < frame and (none if light else held),
				"hit-stop: %s is tier %d, holds the target %.3f s and the attacker %.3f s (%s; footage frame %.2f s)"
						% [row[0], t, V.freeze_t, A.freeze_t, how, frame])
	m.player = A
	for i in range(1, 5):
		var tier: Array = Feel.HITSTOP[i]
		ok(float(tier.max()) < frame, "hit-stop: tier %d %s stays under one footage frame" % [i, str(tier)])
	var flashes := []
	for d in [rifle, 30.0]:
		V.hp = V.max_hp
		V.flash_t = 0.0
		V.hurt(d, A, {"src": "primary"})
		flashes.append(V.flash_t)
	ok(flashes[0] >= float(band[0]) and flashes[0] <= float(band[1]) and is_equal_approx(flashes[0], flashes[1]),
			"hit flash: light %.2f s, heavy %.2f s, the same and in the footage band %s"
					% [flashes[0], flashes[1], str(band)])
