class_name WardenSync
extends Node
## Each frame, after the hunter's animation, puts every mapped bone where its rig node has moved it.

var root: Node3D
var skel: Skeleton3D
var links: Array = []       # [bone index, rig node, node rest (model space) inverse, bone rest (skeleton space)]
var springs := WardenSprings.new()  # the spring_ bone chains (braids) swinging on top
var rigid_legs := {}        # bone index -> true: legs retargeted without the Legs node's shear (retarget_rigid)
var orbits := WardenOrbits.new()    # the orbit_ props (seeing-stones) circling their bone
var aim: WardenAim            # the body's pitch across terrace heights (WardenAim)
var sway: WardenSway          # a body that lags on its spring, tumbling props (WardenSway), or null
var head_look: WardenLookAt   # the head turns to the aim ahead of the body (WardenLookAt)
var flinch: WardenFlinch      # the hit flinch over the clips (WardenFlinch), or null
var wall: WardenWall          # the plant and push of a wall kick or bounce over the clips, or null
var clips: WardenClips        # a Hero's hand-keyed clips, or null: the bones follow the rig (WardenGlb.BONES)
var blade_root: Node3D        # a skinned weapon's FX points (item 76b), riding its bone
var blade_tip: Node3D
var blade_bone := -1
var blade_root_bone := -1     # (the bone blade_root rides; data "root_bone", else blade_bone)
var gun: Node3D
var muzzle: Node3D
var hand_nodes: Array = []    # [rig hand, its bone index]: the kits read the hands off the rig
var built: Array = []         # the rig's weapon and prow last hidden (ids; _keep_one_weapon)
var mood: WardenMood          # a face on glass and a hanging companion, when the art has them
var companions: WardenCompanions   # floating companions cut out of the body (Meeko's sun and cloud), or null
var hide_out: Array = []      # bone indices that shrink away while WardenGlb.CHAIN_OUT
var look_pose: Array = []     # [bone index, position, scale]: the player's sliders under the clips (_look_pose)
var rig_root: Array = []      # data "rig_root": the root bone stays on the Rig under the clips (a hover)
var pace: RigPace             # how often the bones are posed (every frame but on GL over Metal)
var leg_bones := PackedInt32Array()     # LEG_BONES' indices, for FootPlant.bones
var drop_pose: WardenDropPose  # the drop's shared ride and skydive poses over the clips or the rig, or null

func setup(model: Node3D, skeleton: Skeleton3D, rest: Dictionary) -> void:
	root = model
	skel = skeleton
	pace = RigPace.new(get_instance_id())
	process_priority = 10       # after Match renders the hunters (HunterAnim.update)
	for b in WardenGlb.BONES:
		var bi := WardenSkeleton.find(skel, b)
		var nd := root.get_node_or_null(String(WardenGlb.BONES[b])) as Node3D
		if bi < 0 or nd == null:
			continue
		links.append([bi, nd, (rest[b] as Transform3D).affine_inverse(), skel.get_bone_global_rest(bi)])
	links.sort_custom(func(a, c): return int(a[0]) < int(c[0]))     # parents before children
	head_look = WardenLookAt.make(model, skeleton)
	for b in WardenGlb.LEG_BONES:
		leg_bones.append(WardenSkeleton.find(skel, b))
	springs.setup(skel)
	orbits.setup(skel)      # (the glTF import hangs a node riding a bone on a BoneAttachment3D under it)
	drop_pose = WardenDropPose.make(root, skel)

## Plays the Hero's clips when its art has them; and finds a skinned weapon's FX points.
func use_clips(glb: Node3D, art_name: String) -> void:
	var dd := WardenClips.data(art_name)
	if bool(dd.get("legs_rigid", false)):
		for b in WardenGlb.LEG_BONES:
			rigid_legs[WardenSkeleton.find(skel, b)] = true
	var bl: Dictionary = dd.get("blade", {})
	if not bl.is_empty():
		blade_root = glb.find_child(String(bl["root"]), true, false) as Node3D
		blade_tip = glb.find_child(String(bl["tip"]), true, false) as Node3D
		blade_bone = WardenSkeleton.find(skel, String(bl.get("bone", "hand.R")))
		# ("root_bone": the root empty rides another bone than the tip: Vex's barrels on the arm)
		blade_root_bone = WardenSkeleton.find(skel, String(bl.get("root_bone", bl.get("bone", "hand.R"))))
		gun = root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
		muzzle = gun.get_node_or_null("Muzzle") as Node3D if gun else null
	for ch in springs.chains:
		var first := skel.get_bone_name(int(ch["ids"][0]))
		ch["own_rest"] = Array(dd.get("hang_own_rest", [])).any(func(n): return first.begins_with(String(n)))
	for b in dd.get("hide_while_chain", []):
		hide_out.append(WardenSkeleton.find(skel, String(b)))
	clips = WardenClips.make(root, glb, skel, art_name)
	sway = WardenSway.make(root, skel, dd.get("sway", {}))
	flinch = WardenFlinch.make(root, skel) if clips else null
	aim = WardenAim.make(root, skel, String((dd.get("blade", {}) as Dictionary).get("bone", "")))
	wall = WardenWall.make(root, skel) if clips else null
	if clips:
		_look_pose()
		root.set_meta(WardenClips.DEATH_T, float((dd.get("states", {}) as Dictionary).get("dead_t", 0.0)))
	if clips and bool(dd.get("rig_root", false)):
		rig_root = links.filter(func(l): return int(l[0]) == WardenSkeleton.find(skel, "root"))
		leg_bones.clear()       # a hover (Motley): no feet on the ground to plant
	if clips:
		for sd in ["L", "R"]:
			var nd := root.get_node_or_null(String(WardenGlb.BONES["hand." + sd])) as Node3D
			var bi := WardenSkeleton.find(skel, "hand." + sd)
			if nd and bi >= 0:
				hand_nodes.append([nd, bi])

## Hunter.equip rebuilds the rig's weapon and prow (a new match, a practice swap): on a skinned weapon those pieces
## must stay hidden, so one weapon is drawn in every mode (item 76b.5).
func _keep_one_weapon() -> void:
	if gun == null:
		return
	var holder := root.get_node_or_null(WardenGlb.SHIELD_PATH)
	var last := gun.get_child(gun.get_child_count() - 1)
	var now := [last.get_instance_id(), holder.get_instance_id() if holder else 0]
	if now != built:
		built = now
		WardenGlb._skinned_weapon(root)
		WardenGlb._hide_shield(root)

func _process(dt: float) -> void:
	_keep_one_weapon()
	if int(root.get_meta(WardenGlb.POSE_HELD, -1)) == Engine.get_process_frames():
		pace.held += dt        # SimLod.pose_every held this Hunter's pose: the next step catches the time up
		return
	dt = pace.step(dt, pace.every == 1 or RigPace.is_lead(get_viewport(), root.global_position))
	if dt == 0.0:
		return
	if clips:
		_play(dt)
		springs.still = clips.cur in clips.d.get("still", [])
	else:
		apply()
		if drop_pose:
			drop_pose.step(dt)
		apply_blade()
	head_look.step(dt, clips)
	FootPlant.bones(root, skel, leg_bones, dt)
	springs.fold = float(root.get_meta(WardenGlb.WING_FOLD, 0.0))
	springs.step(dt)
	if companions:
		companions.step(dt)     # (before the blade: the sun's FX points ride it)
	apply_blade()       # (again: a weapon that hangs on a chain, Pip's lantern, moved with the springs)
	orbits.look = root.get_meta(WardenGlb.ORBIT_LOOK, Vector3.INF)
	orbits.step(dt)
	if mood:
		mood.step(dt)
	if sway:
		sway.tumble(dt, orbits.pivots)
	if bool(root.get_meta(WardenGlb.CHAIN_OUT, false)):
		for bi in hide_out:
			skel.set_bone_pose_scale(int(bi), Vector3.ONE * 0.001)

## A rig node's place on the body you see (world): its bone's pose back through the retarget.
func shown(nd: Node3D) -> Transform3D:
	for l in links:
		if l[1] == nd:
			var to_rest := (l[3] as Transform3D).affine_inverse() * (l[2] as Transform3D).affine_inverse()
			return root.global_transform * skel.get_bone_global_pose(int(l[0])) * to_rest
	return nd.global_transform

## Every mapped bone onto its rig node's pose. Each local pose is worked out against its parent's pose as set (a
## pose keeps no shear, so that can differ from the rig's), kept here, not read back from the skeleton: a global
## pose read after a set recomputed the dirty bones and told every BoneAttachment3D, once per mapped bone.
func apply() -> void:
	var real := {}
	for l in links:
		var bi := int(l[0])
		var par := _real(skel.get_bone_parent(bi), real)
		skel.set_bone_pose(bi, par.affine_inverse() * _rig_pose(l))
		real[bi] = par * skel.get_bone_pose(bi)

## A bone's skeleton-space pose as set this frame: from real, else its parent's times its local pose (kept in real).
func _real(bi: int, real: Dictionary) -> Transform3D:
	if bi < 0:
		return Transform3D.IDENTITY
	if not real.has(bi):
		real[bi] = _real(skel.get_bone_parent(bi), real) * skel.get_bone_pose(bi)
	return real[bi]

func _rig_pose(l: Array) -> Transform3D:
	var now := WardenGlb.model_xf(root, l[1])
	return WardenGlb.retarget_rigid(now, l) if rigid_legs.has(int(l[0])) else WardenGlb.retarget(now, l)

## The player's MantleLook sliders under the clips: each contract bone's offset and scale for this look, against the
## neutral rig the clips were keyed on. The clips key rotations; these stay on the bones (WardenClips strips the
## position and scale tracks of the contract bones, the root's position aside).
func _look_pose() -> void:
	var now: Dictionary = root.get_meta("rig_rest", {})
	var glob := {}
	for b in WardenGlb.BONES:
		var bi := WardenSkeleton.find(skel, b)
		for l in links:
			if int(l[0]) == bi and now.has(b):
				glob[bi] = WardenGlb.retarget(now[b] as Transform3D, l)
	for bi in glob:
		var par := skel.get_bone_parent(int(bi))
		if par < 0 or not glob.has(par):
			continue
		var local: Transform3D = (glob[par] as Transform3D).affine_inverse() * (glob[bi] as Transform3D)
		look_pose.append([int(bi), local.origin, local.basis.get_scale()])

## The clips' pose, mixed with the retargeted rig while a state hands over (clips.proc_w), then the rig's hands and
## the Gun laid on what is shown, so kit FX leave the bodies you see.
func _play(dt: float) -> void:
	for o in look_pose:
		skel.set_bone_pose_position(int(o[0]), o[1])
		skel.set_bone_pose_scale(int(o[0]), o[2])
	clips.step(dt)
	var w := clips.proc_w
	if w >= 1.0:
		apply()
	elif w > 0.0:
		var poses: Array = []
		for l in links:
			poses.append(skel.get_bone_global_pose(int(l[0])))
		for i in links.size():
			var l: Array = links[i]
			var pose: Transform3D = poses[i]
			skel.set_bone_global_pose(int(l[0]), pose.interpolate_with(
					_rig_pose(l), w))
	for l in rig_root:
		skel.set_bone_global_pose(int(l[0]), WardenGlb.retarget(WardenGlb.model_xf(root, l[1]), l))
	if flinch:
		flinch.step(dt)
	if drop_pose:
		drop_pose.step(dt)
	if sway:
		sway.step(dt)
	aim.step(1.0 - w)
	if wall:
		wall.step(dt)
	if w < 1.0:
		var inv := skel.global_transform
		for h in hand_nodes:
			(h[0] as Node3D).global_position = inv * skel.get_bone_global_pose(int(h[1])).origin
	apply_blade()

## The Gun on the skinned blade: its origin at the blade's root, -Z along the blade, the Muzzle on the tip.
func apply_blade() -> void:
	if blade_tip == null or blade_root == null or gun == null or not gun.is_inside_tree():
		return
	# (from the bone, not the attachment nodes: those update after the skeleton does, a frame late)
	var hand := skel.global_transform * skel.get_bone_global_pose(blade_bone)
	var a := skel.global_transform * skel.get_bone_global_pose(blade_root_bone) * blade_root.position
	var b := hand * blade_tip.position
	if a.distance_squared_to(b) < 0.000000000001:
		return
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT
	gun.global_transform = Transform3D(Basis.looking_at(b - a, up), a)
	if muzzle:
		muzzle.global_position = b

