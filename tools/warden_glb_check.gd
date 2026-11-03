extends RefCounted
## --warden-glb-check (docs/art/wardens/RIG_CONTRACT.md): the .glb loader's bone table covers every rig node
## HunterAnim poses; every Warden without art/wardens/<name>/<name>.glb builds the procedural model (the
## fallback). Each Warden that has a .glb: it loads, its armature is the contract's (bone names, parents,
## each bone on its rig node), every kit move in every table retargets onto it (the bones sit exactly where
## their rig nodes put them, and each keyed channel moves the bones it drives), the anchor empties ride
## their bones, every surface is on the hero toon shader with the atlas, the hit radius and ring are the
## same as the procedural model's, it stays in the triangle and slot budget, and the player's setting
## turns it back into the procedural model and on again.

## Every node HunterAnim binds (HunterAnim._init) that a body mesh can hang on.
const ANIM_PARTS := ["Rig", "Rig/Torso", "Rig/Torso/HeadPivot", "Rig/Torso/ArmLPivot", "Rig/Torso/ArmLPivot/Elbow",
	"Rig/Torso/ArmLPivot/Elbow/Hand", "Rig/Torso/ArmRPivot", "Rig/Torso/ArmRPivot/Elbow",
	"Rig/Torso/ArmRPivot/Elbow/Hand",
	"Rig/Legs/LegL", "Rig/Legs/LegL/Knee", "Rig/Legs/LegR", "Rig/Legs/LegR/Knee", "Rig/Torso/PauldronL",
	"Rig/Torso/PauldronR", "Rig/Torso/Skirt", "Rig/Torso/Cape", "Rig/Torso/Scarf", "Rig/Torso/Tail", "Rig/Torso/Wings"]
## Each kit-move channel and the bones it moves (relative to their parent bone). The blade channels only
## drive bladed weapons, so they are not asserted on other Wardens.
const CHANNEL_BONES := {
	"p": ["hips"], "y": ["hips"], "r": ["hips"], "fx": ["root"], "fy": ["root"], "fz": ["root"],
	"lift": ["root", "hips"], "sq": ["root", "hips"],
	"legs": ["thigh.L", "shin.L", "thigh.R", "shin.R"],
	"fl": ["upper_arm.L", "forearm.L", "hand.L"], "fr": ["upper_arm.R", "forearm.R", "hand.R"],
	"gp": ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"],
	"wa": ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"],
	"wo": ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"],
}
## A channel's weight: it only plays when that is above zero.
const CHANNEL_WEIGHT := {"legs": "lw", "fl": "hw", "fr": "rw"}
const KEYED := 0.04            # a channel value this big counts as keyed (rad, m, or squash)
const MOVED := 0.004           # a bone moved: this many m, or rad of turn, from its pose with no move
const EXACT := 0.0005          # m: a bone sits on its rig node's retargeted pose
const SLOT_MAX := 8
const TRIS_MAX := 15000

var bad := 0
var n := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	n += 1
	print("WARDENGLB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var mapped := WardenGlb.BONES.values()
	var unmapped := ANIM_PARTS.filter(func(p): return not p in mapped)
	ok(unmapped.is_empty(), "every rig node HunterAnim poses has a bone (unmapped %s)" % str(unmapped))
	ok(
		WardenGlb.path("gunslinger") == "res://art/wardens/vex/vex.glb",
		"a Warden's file is art/wardens/<name>/<name>.glb, named as its art (Vex)"
	)
	ok(
		not WardenGlb.has_model("") and not WardenGlb.has_model("no_such_warden"),
		"no archetype, or one with no file, has no .glb"
	)
	var fallback: Array = []
	var loaded: Array = []
	for a in Arch.ids():
		var m := _model(a)
		var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
		if WardenGlb.has_model(a):
			if bool(m.get_meta("glb", false)) and m.has_node("Warden") and not head.visible:
				loaded.append(a)
			else:
				print("WARDENGLB %s has a .glb that did not load" % a)
		elif not bool(m.get_meta("glb", true)) and not m.has_node("Warden") and head.visible:
			fallback.append(a)
		m.free()
	ok(fallback.size() + loaded.size() == Arch.ids().size(),
			"every Warden builds: %d from their .glb %s, %d procedural (the fallback)" % [
				loaded.size(),
				str(loaded),
				fallback.size()
			])
	ok("gunslinger" in loaded, "Vex (gunslinger) is drawn from her .glb")
	for a in loaded:
		_contract(a)
		_kmoves(a)
		await _anchors(main, a)
		_shading(a)
		_hitbox(a)
		_setting(a)
	print("WARDENGLB %d checks, %d failed" % [n, bad])
	print("WARDENGLB_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()

func _model(a: String) -> Node3D:
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	holder.add_child(m)
	return m

func _skel(m: Node3D) -> Skeleton3D:
	return WardenGlb.skeleton(m.get_node("Warden"))

## The armature is the contract's, built where the rig's nodes rest; the budget.
func _contract(a: String) -> void:
	var m := _model(a)
	var sk := _skel(m)
	var bad_bones: Array = WardenSkeleton.mismatches(sk, WardenGlb.neutral_rest(a))
	ok(bad_bones.is_empty(), "%s: the .glb's armature is the contract's: names, parents, each bone on its rig node %s"
			% [a, str(bad_bones)])
	var tris := 0
	var slots := {}
	var unskinned := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if (mi as MeshInstance3D).skin == null:
			unskinned += 1
		for si in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(si) / 3
			var src := mesh.surface_get_material(si)
			slots[String(src.resource_name) if src else ""] = true
	var unknown := slots.keys().filter(func(s): return not WardenGlb.SLOTS.has(s))
	ok(unskinned == 0 and tris <= TRIS_MAX and slots.size() <= SLOT_MAX and unknown.is_empty(),
			"%s: skinned (%d meshes not), %d triangles (at most %d), slots %s (at most %d, all toon slots)"
			% [a, unskinned, tris, TRIS_MAX, str(slots.keys()), SLOT_MAX])
	m.free()

## Every kit move of every table, played on this Warden: after each key, every bone is exactly where its rig
## node's pose retargets it, and each channel the key drives has moved its bones.
func _kmoves(a: String) -> void:
	var m := _model(a)
	var an := HunterAnim.new(m)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var sk := _skel(m)
	_drive(an, sync, "", 0.0)
	var still := _local_poses(sk)
	var worst := 0.0
	var count := 0
	var dead: Array = []
	for t in [HunterAnim.KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, KMovesStone.MOVES, MergeMoves.MOVES,
			KMovesCare.MOVES, KMovesPinBjorn.MOVES, KMovesDJ.MOVES]:
		for mv in t:
			count += 1
			var moved := {}
			var keyed := {}
			var def := HunterAnim.km_def(mv)
			var end_t := float(def["keys"][-1][0])
			for k in def["keys"]:
				# a move that doesn't hold ends on its last key: it is played up to just before it
				_drive(an, sync, mv, float(k[0]) if def.get("hold", false) else minf(float(k[0]), end_t - 0.002))
				for l in sync.links:
					var want := WardenGlb.retarget(WardenGlb.model_xf(m, l[1]), l)
					worst = maxf(worst, sk.get_bone_global_pose(int(l[0])).origin.distance_to(want.origin))
				var now := _local_poses(sk)
				for ch in _keyed(k[1]):
					keyed[ch] = true
					for b in CHANNEL_BONES[ch]:
						if _moved(still.get(b), now.get(b)):
							moved[ch] = true
			for ch in keyed:
				if not moved.has(ch):
					dead.append("%s:%s" % [mv, ch])
	ok(worst <= EXACT, "%s: across %d kit moves every bone sits on its rig node's retargeted pose (worst %.5f m)"
			% [a, count, worst])
	ok(dead.is_empty(), "%s: every keyed channel of every kit move moves the bones it drives (dead: %s)"
			% [a, str(dead)])
	m.free()

func _drive(an: HunterAnim, sync: WardenGlb.Sync, mv: String, tt: float) -> void:
	for k in 20:
		an.update(1.0 / 60.0, {"fired": 99.0, "face": 0.0, "grounded": true, "kmove": mv, "kmove_t": tt})
	sync.apply()

## The channels a key plays: keyed past KEYED, with their weight on.
func _keyed(key: Dictionary) -> Array:
	var out: Array = []
	for ch in CHANNEL_BONES:
		if not key.has(ch) or float(key.get(CHANNEL_WEIGHT.get(ch, ""), 1.0)) <= 0.0:
			continue
		var v = key[ch]
		var amount := 0.0
		if v is Vector3:
			amount = (v as Vector3).length()
		elif v is Array:
			for x in v:
				amount = maxf(amount, absf(float(x)))
		else:
			amount = absf(float(v))
		if amount >= KEYED:
			out.append(ch)
	return out

## Each contract bone's pose relative to its parent bone.
func _local_poses(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for b in WardenGlb.BONES:
		var bi := WardenSkeleton.find(sk, b)
		if bi >= 0:
			out[b] = sk.get_bone_pose(bi)
	return out

func _moved(a, b) -> bool:
	if a == null or b == null:
		return false
	var ta: Transform3D = a
	var tb: Transform3D = b
	var rel := ta.basis.orthonormalized().inverse() * tb.basis.orthonormalized()
	var turn := rel.get_rotation_quaternion().get_angle()
	var grow := (ta.basis.get_scale() - tb.basis.get_scale()).length()
	return ta.origin.distance_to(tb.origin) > MOVED or turn > MOVED or grow > MOVED

## The anchor empties are on their bones and move with them.
func _anchors(main: Node, a: String) -> void:
	var m := _model(a)
	var missing: Array = []
	var off_bone: Array = []
	for nm in WardenGlb.ANCHORS:
		var an := WardenGlb.anchor(m, nm)
		if an == null:
			missing.append(nm)
		elif not an.get_parent() is BoneAttachment3D:
			off_bone.append(nm)
	ok(missing.is_empty() and off_bone.is_empty(),
			"%s: the anchor empties ride bone attachments (missing %s, not on a bone %s)"
			% [a, str(missing), str(off_bone)])
	var top := WardenGlb.anchor(m, "anchor_head_top")
	if top != null:
		await main.get_tree().process_frame
		var before := top.global_position
		(m.get_node("Rig/Torso/HeadPivot") as Node3D).rotation.x += 0.6
		(m.get_node("Warden/Sync") as WardenGlb.Sync).apply()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var d := top.global_position.distance_to(before)
		ok(d > 0.05, "%s: anchor_head_top follows the head as it nods (%.3f m)" % [a, d])
	m.free()

## Every surface on the hero toon shader with the atlas, and in the model's hit-flash list.
func _shading(a: String) -> void:
	var m := _model(a)
	var mats: Array = m.get_meta("mats", [])
	var wrong := 0
	var surfaces := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			surfaces += 1
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			if sm == null or sm.shader != Models.HERO or not sm.get_shader_parameter("use_tex") \
					or sm.get_shader_parameter("albedo_tex") == null or not sm in mats:
				wrong += 1
	ok(surfaces > 0 and wrong == 0,
			"%s: all %d surfaces on the hero toon shader with the atlas, in the hit flash (%d not)"
			% [a, surfaces, wrong])
	m.free()

## The hit radius and the ring that shows it are the same with the .glb as without, and the .glb brings no
## collision of its own.
func _hitbox(a: String) -> void:
	var with := _model(a)
	var ring_w := (with.get_node("TeamRing") as Node3D).global_transform.basis.get_scale().x
	var shapes := with.get_node("Warden").find_children("*", "CollisionObject3D", true, false).size() \
			+ with.get_node("Warden").find_children("*", "CollisionShape3D", true, false).size()
	with.free()
	WardenGlb.set_model(a, false)
	var without := _model(a)
	var ring_p := (without.get_node("TeamRing") as Node3D).global_transform.basis.get_scale().x
	without.free()
	WardenGlb.set_model(a, true)
	ok(absf(ring_w - ring_p) < 0.0001 and shapes == 0,
			"%s: hit ring %.3f with the .glb, %.3f without (hit radius %.2f m), no collision in the .glb"
			% [a, ring_w, ring_p, Arch.hit_r(a, Data.CLASSES[Arch.weight(a)])])

## Settings > Video > Warden models: off builds the procedural model, on the .glb again.
func _setting(a: String) -> void:
	WardenGlb.set_model(a, false)
	var off := _model(a)
	var proc := not off.has_node("Warden") and (off.get_node("Rig/Torso/HeadPivot/Head") as Node3D).visible \
			and not WardenGlb.uses_model(a)
	off.free()
	WardenGlb.set_model(a, true)
	var on := _model(a)
	var back := on.has_node("Warden") and WardenGlb.uses_model(a)
	on.free()
	ok(proc and back, "%s: the Warden models setting turns it procedural (%s) and back to its 3D model (%s)"
			% [a, str(proc), str(back)])
