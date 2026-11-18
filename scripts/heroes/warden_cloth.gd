class_name WardenCloth
extends RefCounted
## Loose cloth on bone chains (RIG_CONTRACT "Cloth chains"): bones named cloth_<name>_<i>, each the next one's
## child, the first a child of a contract bone (a skirt panel hangs from the hips), the last the tip (no skin).
## Godot's SpringBoneSimulator3D swings every chain; spheres on the hips and legs keep the cloth out of them.
## The skeleton's modifiers run only when WardenSync calls step (so a frame-by-frame shot is deterministic).
## Existing clips and the contract bones are untouched: the chains are extra leaves nothing animates.

const PREFIX := "cloth_"
const STIFFNESS := 3.0     # pull back toward the rest shape (holds the painted hem splay; per chain)
const DRAG := 0.5          # the velocity it loses (a run trails the skirt at ~45 deg, not flat)
const GRAVITY := 3.0        # m/s2 toward straight down
const RADIUS := 0.05        # m: a joint's own size against the spheres
const MAX_STEP := 1.0 / 30.0
## Beyond this camera distance (m) the chains ride the hips rigidly and cost nothing: at the game camera (~23 m, a
## ~60 px figure) the swing does not show, so 8 hunters in a match pay nothing; close cameras (menus, orbits) get it.
const LOD_M := 12.0
## [bone, centre offset from its head (rest: the bone points down, so -Y; m), radius (m), capsule height (m, 0 = a
## sphere)]: bodies cloth must not enter. glTF metres at class-neutral size: a thigh is 0.47 m, a shin 0.48 m.
## Capsules along the bones (one per leg segment, not three spheres: the sim tests every joint against every shape).
const SHAPES := [
	["thigh.L", Vector3(0, -0.21, 0), 0.12, 0.62], ["thigh.R", Vector3(0, -0.21, 0), 0.12, 0.62],
	["shin.L", Vector3(0, -0.25, 0), 0.085, 0.62], ["shin.R", Vector3(0, -0.25, 0), 0.085, 0.62],
	["foot.L", Vector3(0, 0, -0.08), 0.10, 0.0], ["foot.R", Vector3(0, 0, -0.08), 0.10, 0.0],
]

var skel: Skeleton3D
var sim: SpringBoneSimulator3D
var chains := 0
var enabled := true      # false: the chains ride the hips rigidly at any distance (shots and the bench compare)

## The cloth of a skeleton, or null when it has no cloth_ bones.
static func make(skeleton: Skeleton3D) -> WardenCloth:
	var roots: Array = []
	for bi in skeleton.get_bone_count():
		var par := skeleton.get_bone_parent(bi)
		if _cloth(skeleton, bi) and (par < 0 or not _cloth(skeleton, par)):
			roots.append(bi)
	if roots.is_empty():
		return null
	var c := WardenCloth.new()
	c.skel = skeleton
	c._build(roots)
	return c

static func _cloth(sk: Skeleton3D, bi: int) -> bool:
	return sk.get_bone_name(bi).begins_with(PREFIX)

func _build(roots: Array) -> void:
	sim = SpringBoneSimulator3D.new()
	sim.name = "Cloth"
	skel.add_child(sim)
	skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	sim.setting_count = roots.size()
	chains = roots.size()
	for i in roots.size():
		var cur := int(roots[i])
		var last := cur
		while true:
			var kids: Array = Array(skel.get_bone_children(last)).filter(func(k): return _cloth(skel, int(k)))
			if kids.is_empty():
				break
			last = int(kids[0])
		sim.set_root_bone_name(i, skel.get_bone_name(cur))
		sim.set_end_bone_name(i, skel.get_bone_name(last))
		sim.set_individual_config(i, false)
		sim.set_radius(i, RADIUS)
		sim.set_stiffness(i, STIFFNESS)
		sim.set_drag(i, DRAG)
		sim.set_gravity(i, GRAVITY)
		sim.set_enable_all_child_collisions(i, true)
	for sh in SHAPES:
		if skel.find_bone(String(sh[0])) < 0:
			continue
		var col: SpringBoneCollision3D
		if float(sh[3]) > 0.0:
			var cap := SpringBoneCollisionCapsule3D.new()
			cap.radius = float(sh[2])
			cap.height = float(sh[3])
			col = cap
		else:
			var sp := SpringBoneCollisionSphere3D.new()
			sp.radius = float(sh[2])
			col = sp
		col.bone_name = String(sh[0])
		col.position_offset = sh[1]
		sim.add_child(col)

## Sets every chain's spring (tuning shots).
func tune(stiffness: float, gravity: float, drag: float) -> void:
	for i in chains:
		sim.set_stiffness(i, stiffness)
		sim.set_gravity(i, gravity)
		sim.set_drag(i, drag)

## Runs the chains one step (called by WardenSync after it has posed the bones).
func step(dt: float) -> void:
	if not skel.is_inside_tree():
		return
	var cam := skel.get_viewport().get_camera_3d()
	var near := enabled and (cam == null or cam.global_position.distance_to(skel.global_position) < LOD_M)
	if near != sim.active:
		sim.active = near
		if near:
			sim.reset()      # (from the rest shape, not the swing it had when it went far)
	var n := clampi(ceili(dt / MAX_STEP), 1, 4)
	for i in n:
		skel.advance(dt / n)
