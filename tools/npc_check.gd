extends RefCounted
## --npc-check: the talking NPCs drawn from rigged Meshy models (NpcModel, content/rules/npcs.json).
##   1. each NPC in the table builds from art/npcs/<id>/<id>.glb with its clips: every pose in its table is a clip
##      in the model, it stands at its height (within 6%) on the ground, with a name tag over its head
##   2. a pose change plays that pose's clip; a pose with no clip plays idle; "point" turns it to point_at
##   3. Hob is one (HobModel) and his talk-box portrait draws from it
##   4. the tutorial course: Pell stands by the landing; when a step begins Pell is by that step's stop and
##      talks, waves when you come near, and faces you

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("NPCCHECK %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for id in Content.rules("npcs"):
		if id != "desc":
			await _model(String(id))
	await _hob()
	await _tutorial()
	print("NPCCHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _model(id: String) -> void:
	var spec := NpcModel.spec(id)
	var n := NpcModel.new(id)
	main.add_child(n)
	await main.get_tree().process_frame
	ok(n.anim != null, "%s: built from its rigged model" % id)
	if n.anim == null:
		n.queue_free()
		return
	var clips: Dictionary = spec["clips"]
	var missing := clips.values().filter(func(c): return not n.anim.has_animation(String(c)))
	ok(missing.is_empty() and clips.has("idle") and clips.has("talk") and clips.has("wave"),
			"%s: idle, talk and wave at least, every pose a clip (missing %s)" % [id, missing])
	var ab := _world_aabb(n)
	ok(absf(ab.size.y - n.height()) < n.height() * 0.06 and absf(ab.position.y) < 0.08,
			"%s: %.2f m tall on the ground (%.2f m, feet at %.2f)" % [id, n.height(), ab.size.y, ab.position.y])
	ok(n.tag.position.y > ab.end.y and n.tag.text != "", "%s: its name over its head" % id)
	for pose in clips:
		n.pose = pose
		await main.get_tree().process_frame
		ok(n.anim.current_animation == String(clips[pose]), "%s: pose %s plays its clip" % [id, pose])
	n.pose = "no-such-pose"
	await main.get_tree().process_frame
	ok(n.anim.current_animation == String(clips["idle"]), "%s: a pose with no clip plays idle" % id)
	n.queue_free()

func _hob() -> void:
	var hob := HobModel.new()
	main.add_child(hob)
	hob.point_at = Vector3(5.0, 0.0, 0.0)
	hob.pose = "point"
	for i in 60:
		await main.get_tree().process_frame
	var facing := -hob.global_transform.basis.z
	ok(hob is NpcModel and hob.id == "hob" and hob.tag.text == FarmBuilder.full_name(),
			"Hob is an NpcModel, his name over him")
	ok(facing.dot(Vector3.RIGHT) > 0.9, "pointing, he turns to what he points at (%.2f)" % facing.dot(Vector3.RIGHT))
	var face := HobModel.face(112.0)
	var vp := face.get_child(0) if face.get_child_count() == 1 else null
	ok(vp is SubViewport and vp.find_children("*", "NpcModel", true, false).size() == 1,
			"his portrait draws from the model")
	face.free()
	hob.queue_free()

func _tutorial() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var tut: Tutorial = m.tut
	ok(tut != null and tut.pell != null and tut.pell.node.id == "pell", "the tutorial has Pell")
	if tut == null or tut.pell == null:
		m.queue_free()
		return
	var pell: NpcModel = tut.pell.node
	ok(pell.position.distance_to(tut.stop("land")) < 3.5, "Pell stands by the landing")
	tut.ack()
	m.step(Match.DT)
	ok(pell.pose in ["talk", "wave"], "as the first step begins Pell talks or waves (%s)" % pell.pose)
	m.player.global_position = pell.global_position + Vector3(0.0, 0.0, 3.0)
	for i in 30:
		tut.pell.tick(Match.DT)
	ok(pell.pose == "wave", "you come near: Pell waves (%s)" % pell.pose)
	var at := tut.step
	tut._finish(tut.id())
	for i in int(1.0 / Match.DT):
		tut.pell.tick(Match.DT)
	var want := tut.pell._spot(tut.id())
	var there := want.x == INF or pell.position.distance_to(want) < 0.1
	ok(tut.step > at and there and pell.scale.is_equal_approx(Vector3.ONE),
			"the next step: Pell is by its stop (%s)" % tut.id())
	for i in 40:      # (the turn runs on the frame)
		await main.get_tree().process_frame
	var to_you := m.player.global_position - pell.global_position
	ok((-pell.global_transform.basis.z).dot(Vector3(to_you.x, 0.0, to_you.z).normalized()) > 0.5, "and faces you")
	m.queue_free()

## The NPC's mesh bounds in the world, at rest.
static func _world_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		out = ab if first else out.merge(ab)
		first = false
	return out
