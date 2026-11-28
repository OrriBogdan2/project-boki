extends RefCounted
## --empty-native-check (docs/art/wardens/MESHY_NATIVE.md "The Empty"): the player's Empty in the Hooded Cloak is drawn
## on Meshy's own skeleton and clips, as the native Hunters are: Meshy's bones, no contract sync, faces -Z like every
## Hunter, each state and the farm's lift play their clip (no T-pose), the void head rides Meshy's Head bone and the
## aura its Spine02, the procedural body is hidden, and the packed pick-up and sit clips are in the file.

const UPRIGHT := 0.2  # m: the head stays this far over the hips in every state (the Empty is shorter than a Hunter)
const CALM := 99.0  # s since the last cast (Hunter._anim_state always sends "cast")
const POSED_MIN := 10  # bones turned off Meshy's rest in a playing clip (the T-pose turns none)
const TURNED := 0.03  # rad: a bone this far off its rest is posed
const CLIPS := ["Idle", "walk", "run", "Jump_Run", "Attack", "Crouch_Walk_with_Torch", "PickUp", "Sit"]

const FACE_AHEAD := 0.05  # m: the painted face's front ahead of the Head bone, on the rig's +Z
const EGG_BEHIND := 0.02  # m: the egg cover's front at most this far behind the void shell's, at rest
const EGG_OFF := 0.03  # m: and their middles this close, seen from the front
var bad := 0
var n := 0
var holder: Node3D


func ok(cond: bool, what: String) -> void:
	n += 1
	print("EMPTYNATIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	for key in EmptyGlb.KEYS:
		await _one(main, key)
	print("EMPTYNATIVE DONE %d checks, %d failed" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func _one(main: Node, key: String) -> void:
	var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", EmptyGlb.rest_look(key))
	holder.add_child(m)
	var nat := m.get_node_or_null("Warden/Native") as WardenNative
	ok(nat != null and not m.has_node("Warden/Sync"), "%s: on Meshy's skeleton, no contract sync" % key)
	if nat == null:
		m.free()
		return
	var sk := nat.skel
	var head := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var front := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("headfront")).origin
	var fwd := m.global_transform.basis.inverse() * (front - head)
	ok(fwd.z < 0.0 and absf(fwd.z) > absf(fwd.x), "%s: faces -Z (head to face %s)" % [key, fwd])
	# (Meshy puts headfront on +Z whatever the mesh: the painted face must be there too, or the clips walk the cloak
	# backwards, as the 11-27 packs did)
	var rest_head := sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var face_z: float = (EmptyGlb.EGG[EmptyGlb.KEYS.find(key)][0] as Vector3).z - rest_head.z
	ok(face_z > FACE_AHEAD, "%s: the painted face is on the rig's front (%.3f m ahead of Head)" % [key, face_z])
	ok(CLIPS.all(func(c): return nat.player.has_animation(c)), "%s: the file carries %s" % [key, str(CLIPS)])
	var cases := [
		["idle", {"grounded": true}],
		["walk", {"grounded": true, "vel": Vector3(0.0, 0.0, -1.5)}],
		["run", {"grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}],
		["jump", {"grounded": false, "vel": Vector3(0.0, 3.0, -4.0)}],
		["crouch", {"grounded": true, "crouch": 1.0}],
		["act_lift", {"grounded": true, "act": "lift"}],
	]
	for c in cases:
		m.set_meta(WardenClips.STATE, {"cast": CALM}.merged(c[1], true))
		for k in 30:
			await main.get_tree().process_frame
		var up := (
			sk.get_bone_global_pose(sk.find_bone("Head")).origin.y
			- sk.get_bone_global_pose(sk.find_bone("Hips")).origin.y
		)
		ok(up > UPRIGHT, "%s: %s stands up (head %.2f m over the hips)" % [key, c[0], up])
		ok(
			nat.player.current_animation == String(nat.plays[c[0]]),
			"%s: %s plays %s" % [key, c[0], nat.player.current_animation]
		)
		ok(_posed(sk) >= POSED_MIN, "%s: %s is posed (%d bones off rest)" % [key, c[0], _posed(sk)])
	var hood := m.find_child("VoidHead", true, false) as MeshInstance3D
	var body := sk.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	ok(hood != null and hood.skin == body.skin, "%s: the void head is skinned with the cloak's own skin" % key)
	var egg := m.find_child("VoidEgg", true, false) as MeshInstance3D
	ok(egg != null and egg.skin == body.skin, "%s: the painted egg has its black cover on the same skin" % key)
	if egg and hood:
		var e := egg.get_aabb()
		var h := hood.get_aabb()
		var behind := h.end.z - e.end.z  # (fronts: the .glb faces +Z)
		var off := Vector2(e.get_center().x - h.get_center().x, e.get_center().y - h.get_center().y).length()
		ok(
			behind > 0.0 and behind < EGG_BEHIND and off < EGG_OFF,
			"%s: the egg cover sits just behind the void shell's front (%.3f m behind, %.3f m off)" % [key, behind, off]
		)
	var aura := m.find_child("Aura", true, false)
	ok(aura == null or aura.get_parent() is BoneAttachment3D, "%s: the aura rides a Meshy bone" % key)
	var shown := m.get_node("Rig/Torso").get_children().any(
		func(c): return c is MeshInstance3D and (c as MeshInstance3D).visible
	)
	ok(not shown, "%s: the procedural body is hidden" % key)
	m.free()


## Bones of `sk` turned off their rest.
func _posed(sk: Skeleton3D) -> int:
	var posed := 0
	for b in sk.get_bone_count():
		if sk.get_bone_pose_rotation(b).angle_to(sk.get_bone_rest(b).basis.get_rotation_quaternion()) > TURNED:
			posed += 1
	return posed
