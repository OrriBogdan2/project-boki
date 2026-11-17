class_name WardenCloth
extends RefCounted
## Loose cloth on bone chains (RIG_CONTRACT "Cloth chains"): bones named cloth_<name>_<i>, each the next one's
## child, the first a child of a contract bone (a skirt panel hangs from the hips), the last the tip (no skin).
## Godot's SpringBoneSimulator3D swings every chain; spheres on the hips and legs keep the cloth out of them.
## The skeleton's modifiers run only when WardenSync calls step (so a frame-by-frame shot is deterministic).
## Existing clips and the contract bones are untouched: the chains are extra leaves nothing animates.

const PREFIX := "cloth_"
const STIFFNESS := 0.6     # pull back toward the rest shape (per chain, SpringBoneSimulator3D units)
const DRAG := 0.2          # the velocity it loses
const GRAVITY := 5.0        # m/s2 toward straight down
const RADIUS := 0.05        # m: a joint's own size against the spheres
const MAX_STEP := 1.0 / 30.0
## [bone, offset along the bone from its head (rest: the bone points down, so -Y; m), radius (m)]: bodies cloth
## must not enter. glTF metres at class-neutral size: a thigh is 0.47 m, a shin 0.48 m.
const SPHERES := [
	["thigh.L", Vector3(0, -0.06, 0), 0.13], ["thigh.L", Vector3(0, -0.22, 0), 0.115], ["thigh.L", Vector3(0, -0.38, 0), 0.10],
	["thigh.R", Vector3(0, -0.06, 0), 0.13], ["thigh.R", Vector3(0, -0.22, 0), 0.115], ["thigh.R", Vector3(0, -0.38, 0), 0.10],
	["shin.L", Vector3(0, -0.08, 0), 0.09], ["shin.L", Vector3(0, -0.26, 0), 0.085], ["shin.L", Vector3(0, -0.42, 0), 0.08],
	["shin.R", Vector3(0, -0.08, 0), 0.09], ["shin.R", Vector3(0, -0.26, 0), 0.085], ["shin.R", Vector3(0, -0.42, 0), 0.08],
	["foot.L", Vector3(0, 0, -0.08), 0.10], ["foot.R", Vector3(0, 0, -0.08), 0.10],
]

var skel: Skeleton3D
var sim: SpringBoneSimulator3D
var chains := 0

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
	for sp in SPHERES:
		var bi := skel.find_bone(String(sp[0]))
		if bi < 0:
			continue
		var col := SpringBoneCollisionSphere3D.new()
		col.bone_name = String(sp[0])
		col.position_offset = sp[1]
		col.radius = float(sp[2])
		sim.add_child(col)

## Runs the chains one step (called by WardenSync after it has posed the bones).
func step(dt: float) -> void:
	if not skel.is_inside_tree():
		return
	var n := clampi(ceili(dt / MAX_STEP), 1, 4)
	for i in n:
		skel.advance(dt / n)
