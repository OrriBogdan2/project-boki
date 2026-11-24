extends RefCounted
## --warden-native-check (docs/art/wardens/MESHY_NATIVE.md): each Hunter switched onto Meshy's own skeleton
## (content/rules/warden_native.json) builds from its <art>_meshy.glb with Meshy's bones as Meshy named them (no
## contract bones, no WardenSync), its clips play for the game states (idle, walk, run, jump, attack, crouch), it
## stands as tall as the contract model, faces the way the Hunter faces, keeps the hit ring, hides the rig's procedural
## weapon, puts the aim node on Meshy's hand, hangs the anchor empties on Meshy's bones and wears the drop poses (the
## landing squash: --land-weight-check). Every other Warden keeps the contract path.

const HEIGHT_TOL := 0.03  # share: the head stands this close to the contract model's head height
const UPRIGHT := 0.25  # m, Meshy scale: the head stays this far over the hips in every state (a clip in a wrong frame)
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
	# (own: a bone named as the contract names it, not WardenSkeleton.find's Meshy stand-in)
	var contract := CONTRACT_BONES.filter(func(b): return WardenSkeleton.own(sk, b) >= 0)
	ok(
		sk.find_bone("Hips") >= 0 and sk.find_bone("RightHand") >= 0 and contract.is_empty(),
		"%s: Meshy's skeleton (%d bones, no contract bones %s)" % [a, sk.get_bone_count(), str(contract)]
	)
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
	# (every state carries "cast" like Hunter._anim_state's: without it WardenNative reads the state
	# as not yet filled and ignores the swing; the idle case is the first read, the baseline
	# the attack's swing_n 1 is counted against)
	var cases := [
		["idle", {"cast": 99.0, "grounded": true}],
		["walk", {"cast": 99.0, "grounded": true, "vel": Vector3(0.0, 0.0, -1.5)}],
		["run", {"cast": 99.0, "grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}],
		["jump", {"cast": 99.0, "grounded": false, "vel": Vector3(0.0, 3.0, -4.0)}],
		["crouch", {"cast": 99.0, "grounded": true, "crouch": 1.0}],
		["attack", {"cast": 99.0, "grounded": true, "swing_n": 1}],
	]
	for c in cases:
		m.set_meta(WardenClips.STATE, c[1])
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var want := String(nat.plays[c[0]])
		var sk := nat.skel
		var up := (
			sk.get_bone_global_pose(sk.find_bone("Head")).origin.y
			- sk.get_bone_global_pose(sk.find_bone("Hips")).origin.y
		)
		ok(up > UPRIGHT, "%s: %s stands up (head %.2f m over the hips)" % [a, c[0], up])
		ok(nat.player.current_animation == want, "%s: %s plays %s (%s)" % [a, c[0], want, nat.player.current_animation])
	var shown := m.get_node("Rig/Torso/Aim/Gun").find_children("*", "MeshInstance3D", true, false).filter(
		func(mi): return (mi as MeshInstance3D).visible
	)
	ok(shown.is_empty(), "%s: the rig's procedural weapon is hidden" % a)
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	ok(gun.global_position.distance_to(nat.hand_position()) < 0.01, "%s: the aim node rides Meshy's hand" % a)
	var anchors := ["anchor_head_top", "anchor_chest", "anchor_gun_R"].filter(func(an): return WardenGlb.anchor(m, an))
	ok(anchors.size() == 3, "%s: the anchors ride Meshy's bones (%s)" % [a, str(anchors)])
	_toon(a, m)
	_crouch_arms(a, nat)
	_only_meshy(a, m)
	await _orbits(main, a, nat)
	_drop_poses(a, m, nat)
	m.free()


## The drop's shared poses (WardenDropPose) on Meshy's bones, held to the contract Heroes' bars (--clip-check's
## _drop_poses): upright aboard the rocket, belly down and spread in the skydive, banking into a steer, off for the
## glider.
func _drop_poses(a: String, m: Node3D, nat: WardenNative) -> void:
	var clip_check = load("res://tools/clip_check.gd").new()
	clip_check._drop_poses(a, m, nat)
	ok(clip_check.bad == 0, "%s: the drop poses on Meshy's bones (%d misses)" % [a, clip_check.bad])
	nat.set_process(true)


## Every surface wears the game's hero-toon material (not Meshy's PBR), and the hit flashes see them (meta "mats"); a
## flame slot's surface (Cinder's heel jets, WardenProps) wears the toon pass's flame shader instead, and a mood face
## (Meeko's sun and cloud, WardenMood) its face shader.
func _toon(a: String, m: Node3D) -> void:
	var surfaces := 0
	var toon := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			surfaces += 1
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			var game := sm != null and (sm.shader == Models.HERO or sm.shader == WardenGlb.FLAME)
			var face := sm != null and (sm.shader == WardenMood.ATLAS_SHADER or sm.shader == WardenMood.FACE_SHADER)
			toon += int(face or (game and (m.get_meta("mats", []) as Array).has(sm)))
	ok(surfaces > 0 and toon == surfaces, "%s: hero-toon on %d of %d surfaces" % [a, toon, surfaces])


## The crouch's arm bones play the walk's arm keys (Meshy's crouch holds a torch out); its legs keep the crouch.
func _crouch_arms(a: String, nat: WardenNative) -> void:
	var from := String(nat.d.get("crouch_arms_from", ""))
	if from == "":
		return
	var mix := nat.player.get_animation(String(nat.plays["crouch"]))
	var arms := nat.player.get_animation(String(nat.plays[from]))
	var meshy := nat.player.get_animation(String(nat.d["clips"]["crouch"]))
	var arm := NodePath(String(meshy.track_get_path(0)).get_slice(":", 0) + ":RightForeArm")
	var leg := NodePath(String(arm).get_slice(":", 0) + ":RightLeg")
	var rot := Animation.TYPE_ROTATION_3D
	var mi := mix.find_track(arm, rot)
	var ai := arms.find_track(arm, rot)
	var same_arm: bool = mi >= 0 and ai >= 0 and mix.track_get_key_value(mi, 0) == arms.track_get_key_value(ai, 0)
	var li := mix.find_track(leg, rot)
	var ci := meshy.find_track(leg, rot)
	var same_leg: bool = li >= 0 and ci >= 0 and mix.track_get_key_value(li, 0) == meshy.track_get_key_value(ci, 0)
	ok(same_arm and same_leg, "%s: the crouch takes the %s's arms and keeps its own legs" % [a, from])


## Only Meshy's model draws the body: no mesh of the hidden procedural rig (its weapon, the Offhand's second gauntlet
## or twin piece) shows, where it would float off the Meshy body in every frame. (Glow quads and the hit ring live
## outside the rig and are not counted.)
func _only_meshy(a: String, m: Node3D) -> void:
	var stray: Array = []
	for gi in m.get_node("Rig").find_children("*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).is_visible_in_tree():
			stray.append(String(m.get_path_to(gi)))
	ok(stray.is_empty(), "%s: no rig mesh draws beside Meshy's model (showing: %s)" % [a, str(stray)])


## Each data orbit (Tenzo's seeing-stones) rides its Meshy bone with all its props, round the head at the contract
## model's height, and turns over time.
func _orbits(main: Node, a: String, nat: WardenNative) -> void:
	var want: Dictionary = nat.d.get("orbits", {})
	for orb in want:
		var nd := nat.skel.find_child(String(orb), true, false) as Node3D
		var props := nd.get_children().filter(func(c): return c is MeshInstance3D) if nd else []
		var head := nat.skel.global_transform * nat.skel.get_bone_global_pose(nat.skel.find_bone("Head")).origin
		var far := 0.0
		for p in props:
			far = maxf(far, (p as Node3D).global_position.distance_to(head))
		var p0: Vector3 = props[0].global_position if not props.is_empty() else Vector3.ZERO
		for k in 10:
			await main.get_tree().process_frame
		var moved: float = props[0].global_position.distance_to(p0) if not props.is_empty() else 0.0
		ok(
			(
				nd != null
				and props.size() >= 3
				and far < 0.8
				and moved > 0.0005
				and nat.orbits.pivots.size() == want.size()
			),
			(
				"%s: %s rides %s (%d props, %.2f m from the head at most, moved %.3f m)"
				% [a, orb, want[orb], props.size(), far, moved]
			)
		)
