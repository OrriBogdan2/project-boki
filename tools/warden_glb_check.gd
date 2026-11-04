extends RefCounted
## --warden-glb-check (docs/art/wardens/RIG_CONTRACT.md): the .glb loader's bone table covers every rig node
## HunterAnim poses; every Warden without art/wardens/<name>/<name>.glb builds the procedural model (the
## fallback). Each Warden that has a .glb: it loads, its armature is the contract's (bone names, parents,
## each bone on its rig node), every kit move in every table retargets onto it (the bones sit exactly where
## their rig nodes put them, and each keyed channel moves the bones it drives), the anchor empties ride
## their bones, every surface is on the hero toon shader with the atlas, the hit radius and ring are the
## same as the procedural model's, it stays in the triangle and slot budget, the player's setting turns it
## back into the procedural model and on again, and its idle and run stay its own (not another Warden's).

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
const MOTION_BONES := ["hips", "thigh.L", "shin.L", "thigh.R", "shin.R", "upper_arm.L", "forearm.L", "upper_arm.R",
	"forearm.R", "head"]
const OWN_MOTION := 0.05       # rad: two Wardens' idle or run joint angles differ by more than this on average
const TRIS_MAX := 45000         # a Warden baked from Meshy (PIPELINE.md r3): ~30-40k body and weapon, the face kept

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
	var vex := WardenGlb.art("gunslinger")
	ok(
		WardenGlb.path("gunslinger") == "res://art/wardens/%s/%s.glb" % [vex, vex]
				and (vex == "vex" or vex.begins_with("vex_") and WardenGlb.variant("vex") == vex),
		"a Warden's file is art/wardens/<name>/<name>.glb, named as its art (Vex: %s; a variant only when picked)"
				% vex
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
		_own_motion(a, "bulwark" if a != "bulwark" else "gunslinger")
		_weapon(a)
		_springs(a)
		_own_look(a)
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
		# (props on an orbit ride their bone unskinned: WardenGlb.Orbits turns them)
		var orbit := String(mi.get_parent().name).begins_with(WardenGlb.Orbits.PREFIX)
		if (mi as MeshInstance3D).skin == null and not orbit:
			unskinned += 1
		for si in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(si) / 3
			var src := mesh.surface_get_material(si)
			slots[String(src.resource_name).get_slice("-", 0) if src else ""] = true
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

## A .glb that carries its weapon: it is in the hands (under the Gun node, whose Muzzle stays where the shots
## leave), the procedural weapon is hidden, and its magazine (if it has one apart) is the Gun's Mag.
## A model's spring chains (RIG_CONTRACT "Spring chains": braids) swing: moved sideways, each chain's tip trails
## its rigid place, and standing still it settles back on it. (No chains: nothing to check.)
func _springs(a: String) -> void:
	var m := _model(a)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.springs.chains.is_empty():
		m.free()
		return
	var sk := _skel(m)
	sync._process(1.0 / 60.0)
	var lag := 0.0
	for i in 6:
		m.position.x += 0.08
		sync._process(1.0 / 60.0)
		lag = maxf(lag, _spring_off(sk, sync))
	for i in 240:
		sync._process(1.0 / 60.0)
	var rest := _spring_off(sk, sync)
	ok(lag > 0.02 and rest < 0.01, "%s: %d spring chains trail a sideways move (tip %.3f m off) and settle (%.4f m)"
			% [a, sync.springs.chains.size(), lag, rest])
	m.free()

## A model's own look (content/rules/warden_look.json) reaches its surfaces: every surface of a slot it names
## carries that slot's values. (No entry: nothing to check.)
func _own_look(a: String) -> void:
	var own := WardenGlb.look(WardenGlb.art(a))
	if own.is_empty():
		return
	var m := _model(a)
	var slots: Dictionary = own.get("slots", {})
	var seen := 0
	var wrong: Array = []
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			var slot := String(src.resource_name).get_slice("-", 0) if src else ""
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			for k in (slots.get(slot, {}) as Dictionary):
				var want: Variant = WardenGlb._param(slots[slot][k])
				var got: Variant = sm.get_shader_parameter(k)
				seen += 1
				var same: bool = got.is_equal_approx(want) if want is Color else is_equal_approx(float(got),
						float(want))
				if not same:
					wrong.append("%s.%s" % [slot, k])
	ok(seen > 0 and wrong.is_empty(), "%s: its own look (warden_look.json) is on its surfaces (%d values, wrong %s)"
			% [a, seen, str(wrong)])
	m.free()

## The largest distance of a spring chain's tip from where it rides its parent rigidly.
func _spring_off(sk: Skeleton3D, sync: WardenGlb.Sync) -> float:
	var worst := 0.0
	for ch in sync.springs.chains:
		var ids: Array = ch["ids"]
		var tip := int(ids[ids.size() - 1])
		var par := sk.get_bone_parent(int(ids[0]))
		var base := sk.get_bone_global_pose(par) * sk.get_bone_global_rest(par).affine_inverse()
		var rigid := base * sk.get_bone_global_rest(tip)
		worst = maxf(worst, rigid.origin.distance_to(sk.get_bone_global_pose(tip).origin))
	return worst

func _weapon(a: String) -> void:
	var m := _model(a)
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	var weapon := gun.get_node_or_null(WardenGlb.WEAPON) as MeshInstance3D
	if weapon == null:
		m.free()
		return
	var shown := gun.find_children("*", "MeshInstance3D", true, false).filter(
			func(mi): return (mi as Node3D).is_visible_in_tree() and mi != weapon and not weapon.is_ancestor_of(mi))
	var mag := gun.get_node_or_null("Mag") as MeshInstance3D
	var own_mag := weapon.find_child(WardenGlb.WEAPON_MAG, true, false) != null
	# its own magazine is the Mag; a weapon modelled whole leaves the Mag node empty (the reload moves nothing)
	var mag_ok := mag != null and (mag.mesh != null and mag in shown if own_mag else mag.mesh == null)
	var stray := shown.filter(func(mi): return mi != mag)
	var left := str(stray.map(func(mi): return mi.name))
	ok(gun.has_node("Muzzle") and stray.is_empty() and mag_ok,
			"%s holds its own weapon (in the Gun with the Muzzle, procedural parts left %s, its magazine the Mag: %s)"
			% [a, left, str(mag_ok)])
	m.free()

## The skeleton is shared names and layout only: each Warden keeps its own motion. Over an idle and a run
## cycle, this Warden's bones and another Warden's (its rig driving the same contract skeleton) take
## clearly different joint angles.
func _own_motion(a: String, other: String) -> void:
	var m := _model(a)
	var mine := _skel(m)
	var o := _model(other)
	var theirs := WardenSkeleton.build(WardenGlb.neutral_rest(other))
	o.add_child(theirs)
	var o_sync := WardenGlb.Sync.new()
	o_sync.setup(o, theirs, WardenGlb.neutral_rest(other))
	var pairs := [[HunterAnim.new(m), m.get_node("Warden/Sync"), mine], [HunterAnim.new(o), o_sync, theirs]]
	for gait in ["idle", "run"]:
		var diff := 0.0
		var samples := 0
		for f in 90:
			for pr in pairs:
				var st := {"fired": 99.0, "face": 0.0, "grounded": true}
				if gait == "run":
					st["vel"] = Vector3(0, 0, -4.6)
				(pr[0] as HunterAnim).update(1.0 / 60.0, st)
				(pr[1] as WardenGlb.Sync).apply()
			if f % 6 == 0:
				for b in MOTION_BONES:
					var qa := mine.get_bone_pose_rotation(WardenSkeleton.find(mine, b))
					var qb := theirs.get_bone_pose_rotation(WardenSkeleton.find(theirs, b))
					diff += qa.angle_to(qb)
					samples += 1
		var mean := diff / maxf(1.0, samples)
		ok(mean > OWN_MOTION, "%s keeps its own %s: its joint angles differ from %s's by %.2f rad on average"
				% [a, gait, other, mean])
	o_sync.free()
	m.free()
	o.free()

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
