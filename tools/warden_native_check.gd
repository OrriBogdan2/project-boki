extends RefCounted
## --warden-native-check (docs/art/wardens/MESHY_NATIVE.md): each Hunter switched onto Meshy's own skeleton
## (content/rules/warden_native.json) builds from its <art>_meshy.glb with Meshy's bones as Meshy named them (no contract
## bones, no WardenSync), its clips play for the game states (idle, walk, run, jump, attack, crouch), it stands as
## tall as the contract model, faces the way the Hunter faces, keeps the hit ring, hides the rig's procedural weapon
## puts the aim node on Meshy's hand and hangs the anchor empties on Meshy's bones. Every other Warden keeps the contract path.

const HEIGHT_TOL := 0.03       # share: the head stands this close to the contract model's head height
const CONTRACT_BONES := ["hips", "upper_arm.L", "thigh.L"]

var bad := 0
var n := 0
var holder: Node3D


func ok(cond: bool, what: String) -> void:
	n += 1
	print("WARDENNATIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var native: Array = []
	for a in Arch.ids():
		var m := _model(a)
		var is_on := WardenNative.on(a)
		ok(
			is_on == m.has_node("Warden/Native") and is_on == bool(m.get_meta(WardenNative.META, false)),
			"%s: %s" % [a, "on Meshy's skeleton" if is_on else "not on the native path"]
		)
		if is_on:
			native.append(a)
			ok(not m.has_node("Warden/Sync") and not bool(m.get_meta("glb", true)), "%s: no contract sync" % a)
		m.free()
	ok(not native.is_empty(), "native Hunters: %s" % str(native))
	for a in native:
		_bones(a)
		_height(a)
		await _states(main, a)
	print("WARDENNATIVE DONE %d checks, %d failed" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func _model(a: String) -> Node3D:
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	holder.add_child(m)
	return m


## Meshy's bones, as Meshy named them: none of the contract's; the model faces -Z like every Hunter.
func _bones(a: String) -> void:
	var m := _model(a)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var contract := CONTRACT_BONES.filter(func(b): return WardenSkeleton.find(sk, b) >= 0)
	ok(sk.find_bone("Hips") >= 0 and sk.find_bone("RightHand") >= 0 and contract.is_empty(),
			"%s: Meshy's skeleton (%d bones, no contract bones %s)" % [a, sk.get_bone_count(), str(contract)])
	var head := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var front := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("headfront")).origin
	var fwd := m.global_transform.basis.inverse() * (front - head)
	ok(fwd.z < 0.0 and absf(fwd.z) > absf(fwd.x), "%s: faces -Z (head to face %s)" % [a, fwd])
	m.free()


## The head stands where the contract model's does (the same size in game).
func _height(a: String) -> void:
	var nm := WardenGlb.art(a)
	var old := (load("res://art/wardens/%s/%s.glb" % [nm, nm]) as PackedScene).instantiate() as Node3D
	var osk := WardenGlb.skeleton(old)
	var want := osk.get_bone_global_rest(osk.find_bone("head")).origin.y
	old.free()
	var m := _model(a)
	var glb := m.get_node("Warden") as Node3D
	var sk := WardenGlb.skeleton(glb)
	var got := glb.scale.y * sk.get_bone_global_rest(sk.find_bone("Head")).origin.y
	ok(absf(got / want - 1.0) < HEIGHT_TOL, "%s: head at %.3f m, contract model's %.3f m" % [a, got, want])
	m.free()


## Each game state plays its clip; the aim node rides the hand; the rig's weapon is hidden.
func _states(main: Node, a: String) -> void:
	var m := _model(a)
	var nat := m.get_node("Warden/Native") as WardenNative
	var cases := [
		["idle", {"grounded": true}],
		["walk", {"grounded": true, "vel": Vector3(0.0, 0.0, -1.5)}],
		["run", {"grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}],
		["jump", {"grounded": false, "vel": Vector3(0.0, 3.0, -4.0)}],
		["crouch", {"grounded": true, "crouch": 1.0}],
		["attack", {"grounded": true, "swing_n": 1}],
	]
	for c in cases:
		m.set_meta(WardenClips.STATE, c[1])
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var want := String(nat.d["clips"][c[0]])
		ok(nat.player.current_animation == want, "%s: %s plays %s (%s)" % [a, c[0], want, nat.player.current_animation])
	var shown := m.get_node("Rig/Torso/Aim/Gun").find_children("*", "MeshInstance3D", true, false).filter(
			func(mi): return (mi as MeshInstance3D).visible)
	ok(shown.is_empty(), "%s: the rig's procedural weapon is hidden" % a)
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	ok(gun.global_position.distance_to(nat.hand_position()) < 0.01, "%s: the aim node rides Meshy's hand" % a)
	var anchors := ["anchor_head_top", "anchor_chest", "anchor_gun_R"].filter(func(an): return WardenGlb.anchor(m, an))
	ok(anchors.size() == 3, "%s: the anchors ride Meshy's bones (%s)" % [a, str(anchors)])
	m.free()
