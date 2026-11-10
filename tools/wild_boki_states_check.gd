extends RefCounted
## --wild-boki-states-check: what a wild Boki plays in a match. KinWildPose picks startle, bolt, charge, dazed and
## scan; every rigged species answers each with the right clip, face and Flex layer for its body plan, and the
## knocked-out Boki sways and slumps on a live clip (never a frozen rest pose or a slide). Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const RigCheck := preload("res://tools/boki_rig_check.gd")
const STEP := 1.0 / 60.0
const SETTLE_S := 1.2
const POSES := ["alert", "growl", "whine", "dazed", "scan"]

var bad := 0
var lean_by_plan := {}

func ok(cond: bool, what: String) -> void:
	print("WILDBOKI %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	_picker()
	for id in RigCheck.SPECIES_LIST:
		await _species(main, id)
	var feel := func(plan: String) -> float: return float(lean_by_plan.get(plan, 0.0))
	ok(feel.call("quad") > feel.call("flyer") and feel.call("flyer") > feel.call("serpent"),
		"the knocked-out lean follows the body plan: quad %.2f > flyer %.2f > serpent %.2f"
		% [feel.call("quad"), feel.call("flyer"), feel.call("serpent")])
	print("WILDBOKI DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _picker() -> void:
	var p := KinWildPose.pose
	ok(p.call("wild", false, false, false, 9.0) == "", "wandering has no pose: the walk clip carries it")
	ok(p.call("wild", true, true, false, 0.1) == "alert", "the first hit startles it, timid or not")
	ok(p.call("wild", true, true, false, 1.0) == "whine", "a timid one bolts")
	ok(p.call("wild", true, false, false, 1.0) == "growl", "a brave one charges")
	ok(p.call("dazed", false, false, false, 0.0) == "dazed", "knocked out it is dazed")
	ok(p.call("dazed", false, true, true, 0.0) == "scan", "under the scan beam it is held")
	ok(p.call("downed", true, false, false, 0.0) == "", "an owned Boki's downed pose is not ours")

## Sets the pose, runs the rig for `secs`, and returns the largest |flex.rotation.x| and the z swing it saw.
func _hold(rig: BokiRig, k: Node3D, pose: String, secs: float, speed := 0.0) -> Dictionary:
	k.set_meta("pose", pose)
	rig._speed = speed
	var lean := 0.0
	var zmin := 0.0
	var zmax := 0.0
	for i in int(secs / STEP):
		rig._pos_prev = k.global_position - Vector3(0, 0, speed * STEP)
		rig._pick_clip(STEP)
		rig._keep_flex()
		lean = maxf(lean, absf(rig.flex.rotation.x))
		zmin = minf(zmin, rig.flex.rotation.z)
		zmax = maxf(zmax, rig.flex.rotation.z)
	return {"lean": lean, "swing": zmax - zmin}

func _species(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	(k.get_node("Body/Flex/BokiRig") as BokiRig).manual = true
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var plan := String(KinPuppet.BODY.get(id, "blob"))
	var at := k.global_position
	var label := "%s (%s)" % [id, plan]

	_hold(rig, k, "alert", SETTLE_S)
	ok(rig.flex.scale.y > 1.05 and rig.flex.rotation.x > 0.0, "%s alert: stands tall, rocks back" % label)
	_face(rig, k, "angry", "alert", label, 0.4)

	_hold(rig, k, "growl", SETTLE_S)
	ok(rig.clip == "idle", "%s growling in place stays on its feet" % label)
	_hold(rig, k, "growl", SETTLE_S, 2.0)
	ok(rig.clip == "run", "%s charging runs, even slower than a gallop" % label)
	_face(rig, k, "angry", "growl", label)
	_hold(rig, k, "whine", SETTLE_S, 2.0)
	ok(rig.clip == "run" and rig.flex.scale.y < 0.9, "%s bolting runs low" % label)
	_face(rig, k, "sad", "whine", label)

	var dazed := _hold(rig, k, "dazed", SETTLE_S * 2.0)
	lean_by_plan[plan] = maxf(float(lean_by_plan.get(plan, 0.0)), float(dazed["lean"]))
	var slow := rig.clip == "idle" and is_equal_approx(rig.player.speed_scale, 0.4)
	ok(slow, "%s dazed: a slow idle, not a frozen pose" % label)
	ok(rig.flex.scale.y < 0.92, "%s dazed: slumped to %.2f of its height" % [label, rig.flex.scale.y])
	ok(float(dazed["swing"]) > 0.1, "%s dazed: sways %.2f rad side to side" % [label, dazed["swing"]])
	_face(rig, k, "sleepy", "dazed", label)
	rig.seek(0.5)
	ok(_posed(rig), "%s dazed: the skeleton is off its rest pose (no T-pose)" % label)
	var rest := Vector3(0, rig._flex_y, 0)
	ok(k.global_position == at and rig.flex.position.is_equal_approx(rest), "%s dazed: it stays put" % label)

	_hold(rig, k, "scan", SETTLE_S)
	ok(rig.clip == "run" and is_equal_approx(rig.player.speed_scale, 0.7), "%s lifted by the scan: legs kick" % label)
	ok(rig.flex.scale.y > 1.1, "%s lifted by the scan: stretched up" % label)

	_hold(rig, k, "", SETTLE_S)
	ok(absf(rig.flex.scale.y - 1.0) < 0.01 and absf(rig.flex.rotation.x) < 0.01 and rig.clip == "idle",
		"%s back to rest when the pose ends" % label)
	k.queue_free()
	await main.get_tree().process_frame

func _face(rig: BokiRig, k: Node3D, shape: String, pose: String, label: String, least := 0.9) -> void:
	k.set_meta("pose", pose)
	rig._face_step(1.0)
	var w := rig.face.get_blend_shape_value(rig.face.find_blend_shape_by_name(shape))
	ok(w >= least, "%s %s shows %s on the face: %.2f" % [label, pose, shape, w])

## Some bone sits off its rest pose: the clip drives the skeleton.
func _posed(rig: BokiRig) -> bool:
	var skel := rig.skeleton()
	for i in skel.get_bone_count():
		if not skel.get_bone_pose(i).is_equal_approx(skel.get_bone_rest(i)):
			return true
	return false
