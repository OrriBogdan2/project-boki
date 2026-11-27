class_name HunterCrown
extends RefCounted
## The top of a hunter's skull in world metres (size sheets: tools/hunter_size_sheet.gd, tools/farm_3d_sizes.gd).

const CROWN_KEEP := 0.5  # a head slice this share of the head's widest slice or more is still skull
const SLICE := 0.02  # m: crown slices' thickness
const HEAD_R := 0.3  # m (at the drawn size) round the head's axis that the crown is looked for in
const HEAD_ROOM := 0.35  # m (at the drawn size) over the head bone that the crown is looked for in


## The world y of the top of the skull of `model` drawn at scale `s` (`top`: the highest body point, used if no head bone): the highest 2 cm slice, in a column round the head bone, that is at least
## CROWN_KEEP as wide as the head (the middle 90% of its points, so a lone spike or ear tip does not widen it).
static func crown(model: Node3D, pts: PackedVector3Array, s: float, top: float) -> float:
	var sk := _skeleton(model)
	var head_i := -1
	for b in sk.get_bone_count() if sk else 0:
		if sk.get_bone_name(b).to_lower() == "head":
			head_i = b
	if head_i < 0:
		print("CROWN no head bone: top used")
		return top
	var hp := (sk.global_transform * sk.get_bone_global_pose(head_i)).origin
	var slices := {}
	for wp in pts:
		var dy := wp.y - hp.y
		if dy < 0.0 or dy > HEAD_ROOM * s or Vector2(wp.x - hp.x, wp.z - hp.z).length() > HEAD_R * s:
			continue
		var key := int(dy / (SLICE * s))
		if not slices.has(key):
			slices[key] = []
		(slices[key] as Array).append(wp)
	var widths := {}
	var widest := 0.0
	for key in slices:
		var w := _width(slices[key])
		widths[key] = w
		widest = maxf(widest, w)
	var best := -1
	for key in widths:
		if widths[key] >= CROWN_KEEP * widest and key > best:
			best = key
	return hp.y + (best + 1) * SLICE * s


## How wide a slice's points are across: the bigger of its x and z spread, the middle 90% of the points.
static func _width(pts: Array) -> float:
	if pts.size() < 6:
		return 0.0
	var xs := []
	var zs := []
	for wp in pts:
		xs.append(wp.x)
		zs.append(wp.z)
	xs.sort()
	zs.sort()
	var lo := int(pts.size() * 0.05)
	var hi := pts.size() - 1 - lo
	return maxf(xs[hi] - xs[lo], zs[hi] - zs[lo])


static func _skeleton(model: Node3D) -> Skeleton3D:
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			return n
		stack.append_array(n.get_children())
	return null
