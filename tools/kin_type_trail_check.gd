extends RefCounted
## --kin-type-trail-check: a moving Boki leaves a light trail in its type's colour (KinTypeTrail), and the
## capture pop takes the same colour. Every type is in exactly one shared group, the groups are the only
## particle nodes (4 for all Boki), and a Boki that stands still, is parked, hidden or far away leaves none.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KINTRAIL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var seen := {}
	for g: String in KinTypeTrail.GROUPS:
		for t: String in KinTypeTrail.GROUPS[g]["types"]:
			ok(not seen.has(t), "%s is in one group only" % t)
			seen[t] = g
	for t: String in KinTypeFx.LOOKS:
		ok(seen.has(t), "%s has a trail group" % t)
	ok(seen.size() == KinTypeFx.LOOKS.size(), "no group lists a type that does not exist (%d)" % seen.size())
	var fire := KinTypeTrail.colour("fire", Color.BLACK)
	ok(fire == Color(String(KinTypeFx.LOOKS["fire"]["col"])), "the capture pop colour is the type colour")
	ok(KinTypeTrail.colour("", Color.RED) == Color.RED, "a Boki with no type keeps its own colour")
	await _match_test(main)
	print("KINTRAIL DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _match_test(main: Node) -> void:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	var k: Kin = m.player.kin
	ok(k != null, "the player has a Boki")
	if k == null: return
	var trail := KinTypeTrail.of(m.fx)
	ok(KinTypeTrail.of(m.fx) == trail, "one trail node serves every Boki")
	var emitters := trail.get_children().filter(func(c): return c is GPUParticles3D)
	ok(emitters.size() == KinTypeTrail.GROUPS.size(), "%d shared emitters, one per group" % emitters.size())
	k.state = "active"
	k.vel = Vector3(3, 0, 0)
	k.render(0.2, 1.0)
	ok(k.visible, "a summoned Boki is shown")
	ok(trail.emitted > 0, "a moving Boki leaves a trail particle")
	var n := trail.emitted
	k.vel = Vector3.ZERO
	k.render(0.2, 1.0)
	ok(trail.emitted == n and k.trail_t == 0.0, "standing still leaves none")
	k.vel = Vector3(3, 0, 0)
	k.state = "downed"
	k.render(0.2, 1.0)
	ok(trail.emitted == n, "a knocked-out Boki leaves none")
	k.state = "active"
	k.unseen = true
	k.render(0.2, 1.0)
	ok(trail.emitted == n, "a rival's Boki out of sight leaves none")
	k.unseen = false
	k.pos = m.player.pos + Vector3(KinTypeTrail.MAX_RANGE + 10.0, 0, 0)
	k.render(0.2, 1.0)
	ok(trail.emitted == n, "a far-off Boki leaves none")
	ok(m.fx.get_children().filter(func(c): return c is KinTypeTrail).size() == 1, "still one trail node")
