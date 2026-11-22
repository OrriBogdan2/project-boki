extends RefCounted
## --holster-check: the one gun prop (scripts/heroes/warden_holster.gd). On a model with a hip socket and a hand socket
## the weapon's bone sits on the hip at aim_k 0, in the hand at 1, between them for a draw, so the gun is never at both
## places at once. Never touches the save.

const HIP_AT := Vector3(0.18, 0.95, 0.0)
const HAND_AT := Vector3(-0.45, 0.8, 0.35)
const TOL := 0.001  # m

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("HOLSTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	var skel := Skeleton3D.new()
	for b in ["root", "hips", "hand.L", "gun"]:
		skel.add_bone(b)
	skel.set_bone_parent(1, 0)
	skel.set_bone_parent(2, 1)
	skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)))
	skel.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(-0.45, -0.1, 0.35)))
	skel.reset_bone_poses()
	var model := Node3D.new()
	model.add_child(skel)
	var hip := {"bone": "hips", "pos": [0.18, 0.05, 0.0], "rot": [0.0, 0.0, 0.0]}
	var hand := {"bone": "hand.L", "pos": [0.0, 0.0, 0.0], "rot": [0.0, 0.0, 0.0]}
	var h := WardenHolster.make(model, skel, {"hip": hip, "hand": hand}, "gun")
	ok(h != null, "a holster with both sockets and the gun bone builds")
	ok(WardenHolster.make(model, skel, {"hip": hip}, "gun") == null, "a missing hand socket builds nothing")
	ok(WardenHolster.make(model, skel, {"hip": hip, "hand": hand}, "nope") == null, "a missing gun bone builds nothing")
	var gun := skel.find_bone("gun")
	var at := {}
	for k in [0.0, 0.5, 1.0]:
		model.set_meta(WardenHolster.DRAW, k)
		h.step()
		at[k] = skel.get_bone_pose(gun).origin  # (gun has no parent: local is global)
	ok(at[0.0].distance_to(HIP_AT) < TOL, "aim_k 0: the gun rides the hip socket %s" % at[0.0])
	ok(at[1.0].distance_to(HAND_AT) < TOL, "aim_k 1: the gun is in the hand %s" % at[1.0])
	ok(at[0.5].distance_to(HIP_AT.lerp(HAND_AT, 0.5)) < TOL, "aim_k 0.5: halfway through the draw")
	ok(at[0.0].distance_to(at[1.0]) > 0.5, "hip and hand are apart: one prop is on one of them, not both")
	model.free()
	print("HOLSTER_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
