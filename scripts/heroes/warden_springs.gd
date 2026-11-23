class_name WardenSprings
extends RefCounted
## Hanging pieces on bone chains (RIG_CONTRACT "Spring chains"): bones named spring_<name>_<i>, each the next
## one's parent, the first a child of a contract bone (a braid hangs from the head). Each chain is a rope of its
## joints in world space: it keeps its momentum (damped), is pulled back toward the shape it has riding its parent
## rigidly (firmer at the root than at the tip; a spring_hang_* chain toward straight down from its root), and
## keeps its links' lengths, so a braid trails behind a run,
## swings out of a turn and settles when she stands. The last bone is the tip (no skin of its own).

const PREFIX := "spring_"
const PULL := 0.2           # the share of the way back to the rest shape per 1/60 s, at the root
const PULL_TIP := 0.07      # and at the tip
const DAMP := 0.84          # the velocity kept per 1/60 s
const WIND := 0.09          # m: how far a scarf tail's tip ripples at rest
const FLOOR_CHAIN := PREFIX + "scarftail_tail"     # a tail lies on the ground, not through it (the feet's height)
const FLOOR_UP := 0.04      # m its joints stay over the model's origin
const FOLD := 0.75          # radians a folded wing tips back about the side axis through its root
const TUCK := 0.8           # and turns in behind the back about the vertical
const FLARE := 1.15         # radians a flared wing swings out to her side about the front-back axis
var skel: Skeleton3D
var chains: Array = []      # {ids: bone indices root -> tip, pts, prev: joint positions (world), wing}
var fold := 0.0             # how far the wing chains are folded (1) or flared (-1) (WardenGlb.WING_FOLD)
var wind_t := 0.0
var calm := false           # no ripple (a check measuring how a chain settles)
var still := false          # no ripple: a statue pose (data "still": Claire's Rimelock)

func setup(skeleton: Skeleton3D) -> void:
	skel = skeleton
	for bi in skel.get_bone_count():
		var par := skel.get_bone_parent(bi)
		if not _spring(bi) or par < 0 or _spring(par):
			continue
		var ids: Array = [bi]
		var cur := bi
		while true:
			var kids: Array = Array(skel.get_bone_children(cur)).filter(func(c): return _spring(c))
			if kids.is_empty():
				break
			cur = int(kids[0])
			ids.append(cur)
		if ids.size() >= 2:
			# (a "hang" chain, spring_hang<name>_<i>: a chain or rope whose rest shape is straight down from its
			# root, not riding its parent: Kael's Warchain hangs from his fist whichever way the arm points;
			# a "wing" chain folds back while the Warden skates, WING_FOLD)
			chains.append({"ids": ids, "pts": PackedVector3Array(), "prev": PackedVector3Array(),
				"hang": skel.get_bone_name(bi).begins_with(PREFIX + "hang"),
				"wing": skel.get_bone_name(bi).begins_with(PREFIX + "wing"),
				"wind": skel.get_bone_name(bi).begins_with(PREFIX + "scarftail"),
				"floor": skel.get_bone_name(bi).begins_with(FLOOR_CHAIN)})

func _spring(bi: int) -> bool:
	return skel.get_bone_name(bi).begins_with(PREFIX)

func step(dt: float) -> void:
	if chains.is_empty() or not skel.is_inside_tree():
		return
	var xf := skel.global_transform
	var inv := xf.affine_inverse()
	var k := clampf(dt * 60.0, 0.0, 3.0)
	wind_t += dt
	for ch in chains:
		var ids: Array = ch["ids"]
		var par := skel.get_bone_parent(int(ids[0]))
		# each joint riding the parent rigidly: its rest relative to the parent's
		var base := skel.get_bone_global_pose(par) * skel.get_bone_global_rest(par).affine_inverse()
		var rest: Array = []
		var want := PackedVector3Array()
		# a wing folds: its rest shape tipped back (+Z, behind) and turned in, about its root
		var turn := Transform3D.IDENTITY
		if bool(ch["wing"]) and absf(fold) > 0.001:
			var r0: Transform3D = base * skel.get_bone_global_rest(int(ids[0]))
			var r1: Transform3D = base * skel.get_bone_global_rest(int(ids[ids.size() - 1]))
			var out := signf(r1.origin.x - r0.origin.x)
			var tip_in := Basis(Vector3.UP, -out * TUCK * fold)
			# (a wing hanging down from its root, Sable's moth wings, tips the other way to go back too)
			var up := 1.0 if r1.origin.y >= r0.origin.y else -1.0
			if fold > 0.0:
				turn = Transform3D(Basis(Vector3.RIGHT, up * FOLD * fold) * tip_in, Vector3.ZERO)
			else:
				turn = Transform3D(Basis(Vector3.BACK, up * out * FLARE * fold), Vector3.ZERO)
			turn = Transform3D(Basis.IDENTITY, r0.origin) * turn * Transform3D(Basis.IDENTITY, -r0.origin)
		for bi in ids:
			var r: Transform3D = turn * base * skel.get_bone_global_rest(int(bi))
			rest.append(r)
			want.append(xf * r.origin)
		var n := want.size()
		if ch["wind"] and not calm and not still:
			# (a long cloth tail never hangs dead: a slow travelling ripple, stronger toward its tip)
			for i in range(1, n):
				var u := float(i) / float(n - 1)
				var ripple := Vector3(sin(wind_t * 1.9 - i * 0.7), 0.35 * sin(wind_t * 1.3 - i * 0.9), 0.0)
				want[i] += xf.basis * ripple * WIND * u * u
		if ch["hang"]:
			for i in range(1, n):
				var seg := (xf * (rest[i] as Transform3D).origin).distance_to(
						xf * (rest[i - 1] as Transform3D).origin)
				want[i] = want[i - 1] + Vector3.DOWN * seg
		var pts: PackedVector3Array = ch["pts"]
		var prev: PackedVector3Array = ch["prev"]
		if pts.size() != n or pts[0].distance_to(want[0]) > 1.5:      # (the first frame, or a teleport)
			pts = want.duplicate()
			prev = want.duplicate()
		for i in range(1, n):
			var p := pts[i]
			var v := (p - prev[i]) * pow(DAMP, k)
			prev[i] = p
			p += v
			var pull := lerpf(PULL, PULL_TIP, float(i) / float(n - 1))
			if bool(ch["wing"]) and fold < -0.3:
				pull = lerpf(pull, 1.0, 0.85)      # (flared through a flip: the wing turns with her, no twist)
			pts[i] = p.lerp(want[i], 1.0 - pow(1.0 - pull, k))
		pts[0] = want[0]
		prev[0] = want[0]
		for i in range(1, n):
			var d := pts[i] - pts[i - 1]
			var ln := want[i].distance_to(want[i - 1])
			pts[i] = pts[i - 1] + d.normalized() * ln if d.length() > 1e-5 else want[i]
			if ch["floor"]:
				pts[i].y = maxf(pts[i].y, xf.origin.y + FLOOR_UP)
		ch["pts"] = pts
		ch["prev"] = prev
		for j in n - 1:
			var r: Transform3D = rest[j]
			var a := inv * pts[j]
			var from := ((rest[j + 1] as Transform3D).origin - r.origin).normalized()
			if ch.get("own_rest", false):       # (data "hang_own_rest": the fist's turn doesn't twist it edge on)
				r = skel.get_bone_global_rest(int(ids[j]))
				from = (skel.get_bone_global_rest(int(ids[j + 1])).origin - r.origin).normalized()
			var to := (inv * pts[j + 1] - a).normalized()
			var c := from.dot(to)
			var q := Quaternion.IDENTITY
			if c <= -0.999:      # (a chain flipped end for end: Quaternion(from, to) has no answer there)
				var side := Vector3.RIGHT if absf(from.x) < 0.9 else Vector3.FORWARD
				q = Quaternion(from.cross(side).normalized(), PI)
			elif c < 0.99999:
				q = Quaternion(from, to)
			skel.set_bone_global_pose(int(ids[j]), Transform3D(Basis(q) * r.basis, a))
