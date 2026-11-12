class_name WardenStart
extends RefCounted
## Where the walk and run rings pick up when a Hero moves off from idle (docs/art/LOCO_DIR.md, "Starts"). A ring left
## alone keeps the phase the last stop left it at, so a start could fade in over any stride: a foot half through its
## swing, the far end of a step. Instead the rings start at the phase of their forward loop whose pose lies nearest
## the idle's top (the pose a stop hands back to): the blend crosses the least, and the first foot to come down lands
## on the loop's own contact key. The run ring starts on the stride the walk ring starts on (nearest the idle and
## that walk pose together), so a start straight into a run hands from one ring to the other in step.
## The rings are in step (every direction shares the forward loop's length and strike keys), so one time serves all
## eight directions.

const STEPS := 48            # phases tried per loop
## The points whose distance from the idle's is summed: the trunk and the limbs' ends, what a pop in a start shows
## (the ankle is the foot bone's head, or the shin's on a rig without feet).
const POINTS := ["hips", "head", "hand.L", "hand.R", "foot.L", "foot.R"]

## [walk, run]: the phases (0..1) of the walk and run rings a start seeks them to: the same point of the stride.
static func phases(lib: AnimationLibrary, lc: Dictionary, sk: Skeleton3D) -> Array:
	var pts := {}
	for b in POINTS:
		var bi := WardenSkeleton.find(sk, b)
		if bi < 0 and b.begins_with("foot."):
			bi = WardenSkeleton.find(sk, b.replace("foot.", "shin."))
		if bi >= 0:
			pts[b] = bi
	var idle := _pose(lib.get_animation(String(lc["idle"])), 0.0, sk, pts)
	var walk := lib.get_animation(String(lc["walk"]["f"]))
	var walk_t := _nearest(walk, [idle], sk, pts)
	var run := lib.get_animation(String(lc["run"]["f"]))
	var run_t := _nearest(run, [idle, _pose(walk, walk_t, sk, pts)], sk, pts)
	return [walk_t / walk.length, run_t / run.length]

## The time in `a` whose points lie nearest, summed, the poses in `to`.
static func _nearest(a: Animation, to: Array, sk: Skeleton3D, pts: Dictionary) -> float:
	var best := INF
	var at := 0.0
	for i in STEPS:
		var t := a.length * i / STEPS
		var p := _pose(a, t, sk, pts)
		var dist := 0.0
		for q in to:
			for b in pts:
				dist += (p[b] as Vector3).distance_to(q[b])
		if dist < best:
			best = dist
			at = t
	return at

## Point name -> where `a` puts it at `t` in the skeleton's frame: the clip's rotations on the rest's offsets (the
## clips play rotations only, WardenClips._setup).
static func _pose(a: Animation, t: float, sk: Skeleton3D, pts: Dictionary) -> Dictionary:
	var turns := {}
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			var bone := String(a.track_get_path(i).get_concatenated_subnames())
			turns[sk.find_bone(bone)] = a.rotation_track_interpolate(i, t)
	var out := {}
	for b in pts:
		var xf := Transform3D.IDENTITY
		var bi: int = pts[b]
		while bi >= 0:
			var rest := sk.get_bone_rest(bi)
			var q: Quaternion = turns.get(bi, rest.basis.get_rotation_quaternion())
			xf = Transform3D(Basis(q), rest.origin) * xf
			bi = sk.get_bone_parent(bi)
		out[b] = xf.origin
	return out
