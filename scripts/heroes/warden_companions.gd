class_name WardenCompanions
extends RefCounted
## Companions that float round a Warden instead of riding a shoulder (Meeko's sun and raincloud, ART-1 pip).
## They are modelled into the body .glb (tools/art1/pip_companions.py: their own surfaces, skinned rigidly to the
## pauldrons), so at load `detach` cuts those surfaces out of the body mesh and puts each on its own unskinned
## MeshInstance3D under the Skeleton3D; nothing is re-baked. Each frame `step` sets them on a mostly horizontal
## circle (an ellipse) round her upper body, 180 degrees apart, with a little vertical bob at a different
## frequency each, a wobble in their speed, and a slow ease behind her when she moves. The faces stay readable
## (the decals keep facing the way she does, or outward). Data: warden_anim/<art>.json "companions" (all numbers):
##   "at": [x, y, z]       the circle's centre at rest, skeleton space (m), "bone": the bone it follows
##   "radius": [x, z]      the ellipse's half widths (side, front-back)
##   "period": s per turn, "dir": 1 or -1, "wobble": [rad, s]: the speed's slow swing
##   "bob": m, "lag": 1/s of the ease behind her, "trail_max": m the centre may fall behind
##   "avoid": [{"bone", "r"}]: spheres on her head and hands (contract bone names, r in metres) a part is pushed out of
##     when a lunge or an ult pose brings them to it (the push opens at once, eases off)
##   "clear_min": the gap the checks want; "view_clear": true (+ "view_margin": m of extra air) measures that gap
##     across the camera's line of sight (on screen), so a part never overlaps her silhouette
##   "face": "forward" (as modelled), "outward", or "camera" (its front, as modelled, squares up to the active camera),
##     "sway_deg": a slow yaw, "lean_deg": a roll into the turn
##   "list": [{"id", "surfaces": [material names], "at": [x, y, z] the part's centre at rest, "phase_deg" (0 = her
##     right), "bob_period", "bob_phase", "bone": the bone it was skinned to, "anchors": [empties that ride it]}]
##     "mood_only": {surface: [moods]}: a surface shown only in those WardenMood moods (the cloud's rain while it cries)
## Cosmetic only; nothing here touches a kit (the FX empties on the sun follow it, so a shot leaves the sun).
## On Meshy's own skeleton (WardenNative) `frame` takes the data's contract skeleton space onto that skeleton's (its
## units and its turn under the model), and each part's centre is the middle of its own surfaces there.

const PREFIX := "Companion_"  # node name of each cut-out part
const SNAP := 1.5  # m: a centre further than this from where it should be (a respawn) jumps there

static var _cut := {}  # mesh -> {body mesh, parts: {id: [mesh, rest centre]}}: one cut per .glb


class Part:
	var id := ""
	var node: MeshInstance3D
	var rest := Vector3.ZERO  # the part's centre at rest (skeleton space)
	var phase := 0.0  # rad
	var bob_period := 2.7
	var bob_phase := 0.0
	var bone := -1  # the bone its anchors were on
	var anchors: Array = []  # [empty, its rest position relative to the part's centre, the bone it rides]
	var pos := Vector3.ZERO  # last placed (skeleton space)
	var radius := 0.0  # the part's furthest vertex from its centre (skeleton space)
	var push := Vector3.ZERO  # how far the avoid spheres moved it off its circle
	var look := Basis.IDENTITY  # "face": "camera": the turn that points its front at the camera (eased)
	var looked := false
	var by_mood: Array = []  # [MeshInstance3D, [mood names]]: surfaces shown only in those moods ("mood_only")


var skel: Skeleton3D
var d: Dictionary
var parts: Array = []
var centre_bone := -1
var avoid: Array = []  # [bone index, radius (skeleton space)]: spheres the parts keep out of
var centre_off := Vector3.ZERO  # circle centre minus the bone's rest origin
var centre := Vector3.ZERO  # the eased centre (world)
var axes := Basis.IDENTITY  # the data's skeleton axes on this skeleton (`frame`'s basis)
var primed := false
var t := 0.0
var mood: WardenMood  # set by the owner: "mood_only" surfaces follow its current mood


## Cuts the companions out of `glb`'s body mesh when `data` has them; returns the live helper or null.
static func detach(glb: Node3D, sk: Skeleton3D, data: Dictionary, frame := Transform3D.IDENTITY) -> WardenCompanions:
	var dd: Dictionary = data.get("companions", {})
	if dd.is_empty() or sk == null:
		return null
	var wanted: Array = []
	for p in dd.get("list", []):
		wanted.append_array(p.get("surfaces", []))
	var body: MeshInstance3D = null
	for mi in sk.find_children("*", "MeshInstance3D", false, false):
		var m := (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var src := m.surface_get_material(si)
			if src and String(src.resource_name) in wanted:
				body = mi as MeshInstance3D
		if body:
			break
	if body == null:
		push_warning("WardenCompanions: no body mesh carries the companions' surfaces")
		return null
	var cut := _cut_for(body, dd, frame)
	if cut.is_empty():
		return null
	var wc := WardenCompanions.new()
	wc.skel = sk
	wc.d = dd
	wc.axes = frame.basis
	body.mesh = cut["body"]
	for p in dd["list"]:
		var part := Part.new()
		part.id = String(p["id"])
		var pc := (cut["parts"] as Dictionary)[part.id] as Array
		part.rest = pc[1]
		for si in (pc[0] as ArrayMesh).get_surface_count():
			for v: Vector3 in (pc[0] as ArrayMesh).surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				part.radius = maxf(part.radius, v.length())
		part.node = MeshInstance3D.new()
		part.node.name = PREFIX + part.id
		part.node.mesh = pc[0]
		part.node.position = part.rest
		part.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sk.add_child(part.node)
		if (pc[2] as ArrayMesh).get_surface_count() > 0:
			var mo := MeshInstance3D.new()
			mo.mesh = pc[2]
			part.node.add_child(mo)
			part.by_mood.append(
				[mo, (p.get("mood_only", {}) as Dictionary).values().reduce(func(a, b): return a + b, [])]
			)
		part.phase = deg_to_rad(float(p.get("phase_deg", 0.0)))
		part.bob_period = float(p.get("bob_period", 2.7))
		part.bob_phase = float(p.get("bob_phase", 0.0))
		part.bone = WardenSkeleton.find(sk, String(p.get("bone", "")))
		for an in p.get("anchors", []):
			var nd := glb.find_child(String(an), true, false) as Node3D
			var holder := nd.get_parent() as BoneAttachment3D if nd else null
			var bi := sk.find_bone(holder.bone_name) if holder else part.bone
			if nd and bi >= 0:
				var at_rest := sk.get_bone_global_rest(bi) * nd.position
				part.anchors.append([nd, at_rest - part.rest, bi])
		wc.parts.append(part)
	var c: Array = dd.get("at", [0, 1, 0])
	wc.centre_bone = WardenSkeleton.find(sk, String(dd.get("bone", "hips")))
	var origin := sk.get_bone_global_rest(wc.centre_bone).origin if wc.centre_bone >= 0 else Vector3.ZERO
	wc.centre_off = frame * Vector3(c[0], c[1], c[2]) - origin
	var sc := frame.basis.y.length()
	for av in dd.get("avoid", []):
		var bi := WardenSkeleton.find(sk, String(av["bone"]))
		if bi >= 0:
			wc.avoid.append([bi, float(av["r"]) * sc])
	return wc


## The body mesh without the companions' surfaces and one unskinned mesh per companion, cut once per .glb.
static func _cut_for(body: MeshInstance3D, dd: Dictionary, frame: Transform3D) -> Dictionary:
	var src := body.mesh as ArrayMesh
	if src == null:
		return {}
	var key := src.get_instance_id()
	if _cut.has(key):
		return _cut[key]
	var mine := src.duplicate() as ArrayMesh
	var names: Array = []
	for si in src.get_surface_count():
		var m := src.surface_get_material(si)
		names.append(String(m.resource_name) if m else "")
	var cuts := {}
	var gone: Array = []
	for p in dd["list"]:
		var am := ArrayMesh.new()
		var am_mood := ArrayMesh.new()  # (the "mood_only" surfaces: their own node, shown by mood)
		var at: Array = p["at"]
		var mid := frame * Vector3(at[0], at[1], at[2])
		if frame != Transform3D.IDENTITY:
			mid = _middle(src, names, p["surfaces"], mid)
		for nm in p["surfaces"]:
			var si := names.find(String(nm))
			if si < 0:
				continue
			gone.append(si)
			var arr := src.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] -= mid
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			var tgt := am_mood if (p.get("mood_only", {}) as Dictionary).has(String(nm)) else am
			tgt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			tgt.surface_set_material(tgt.get_surface_count() - 1, src.surface_get_material(si))
		cuts[String(p["id"])] = [am, mid, am_mood]
	gone.sort()
	gone.reverse()
	for si in gone:
		mine.surface_remove(si)
	var out := {"body": mine, "parts": cuts}
	_cut[key] = out
	return out


## The middle of the surfaces `surfs` of `src` (their bounds' mid), or `or_else` when it has none of them.
static func _middle(src: ArrayMesh, names: Array, surfs: Array, or_else: Vector3) -> Vector3:
	var box := AABB()
	var any := false
	for nm in surfs:
		var si := names.find(String(nm))
		if si < 0:
			continue
		for v: Vector3 in src.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			box = box.expand(v) if any else AABB(v, Vector3.ZERO)
			any = true
	return box.get_center() if any else or_else


## The circle's point at angle `a` (0 = her right, through her front for dir 1) about `c` (skeleton space), with the
## vertical bob `bob_y`.
func spot(c: Vector3, a: float, bob_y: float) -> Vector3:
	var r: Array = d.get("radius", [0.5, 0.4])
	return c + axes * Vector3(float(r[0]) * cos(a), bob_y, -float(r[1]) * sin(a))


## `at` moved out of the avoid spheres (head, hands) by the part's own size: the push opens at once and eases off.
func _clear(p: Part, at: Vector3, dt: float) -> Vector3:
	var q := at
	var vdir := _view_dir(at)
	for _pass in 3:
		for av in avoid:
			var c := skel.get_bone_global_pose(int(av[0])).origin
			var gap := q - c
			if vdir != Vector3.ZERO:
				gap -= vdir * gap.dot(vdir)  # (the gap on screen: along the line of sight does not count)
			var need := float(av[1]) + p.radius + (float(d_margin()) if vdir != Vector3.ZERO else 0.0)
			if gap.length() < need:
				var dn := gap.normalized() if gap.length() > 0.001 else (Vector3.UP - vdir * vdir.y).normalized()
				q += dn * (need - gap.length())
	var off := q - at
	p.push = off if off.length() >= p.push.length() else p.push.lerp(off, 1.0 - exp(-10.0 * dt))
	return at + p.push


func d_margin() -> float:
	return float(d.get("view_margin", 0.0)) * maxf(skel.global_basis.y.length(), 0.01)


## The active camera's line of sight to `at` (skeleton space), or ZERO when "view_clear" is off or there is no camera.
func _view_dir(at: Vector3) -> Vector3:
	if not bool(d.get("view_clear", false)) or not skel.is_inside_tree():
		return Vector3.ZERO
	var cam := skel.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	return (skel.global_basis.inverse() * (skel.global_transform * at - cam.global_position)).normalized()


## Eases `p.look` (in the data's axes) so its front, -Z as modelled, points at the active camera. False when there is no
##   camera.
func _face_camera(p: Part, dt: float) -> bool:
	if not skel.is_inside_tree():
		return false
	var cam := skel.get_viewport().get_camera_3d()
	if cam == null:
		return false
	var v := skel.global_basis.inverse() * (cam.global_position - skel.global_transform * p.pos)
	v = axes.orthonormalized().inverse() * v
	if v.length() < 0.001:
		return false
	var want := Basis.looking_at(v.normalized(), Vector3.UP)
	p.look = want if not p.looked else p.look.slerp(want, 1.0 - exp(-8.0 * dt))
	p.looked = true
	return true


func angle(p: Part, time: float) -> float:
	var w: Array = d.get("wobble", [0.0, 1.0])
	var a := float(d.get("dir", 1)) * TAU * time / float(d.get("period", 4.0))
	return p.phase + a + float(w[0]) * sin(TAU * time / float(w[1]))


func bob(p: Part, time: float) -> float:
	return float(d.get("bob", 0.08)) * sin(TAU * time / p.bob_period + p.bob_phase)


## Where the circle's centre wants to be now (world): the bone's pose plus the rest offset.
func _target() -> Vector3:
	var o := skel.get_bone_global_pose(centre_bone).origin if centre_bone >= 0 else Vector3.ZERO
	return skel.global_transform * (o + centre_off)


func step(dt: float) -> void:
	if parts.is_empty() or not skel.is_inside_tree():
		return
	t += dt
	var want := _target()
	var sc := maxf(skel.global_basis.y.length(), 0.01)
	if not primed or centre.distance_to(want) > SNAP * sc:
		centre = want
		primed = true
	else:
		centre = centre.lerp(want, 1.0 - exp(-float(d.get("lag", 6.0)) * dt))
		var off := centre - want
		var trail := float(d.get("trail_max", 0.25)) * sc
		if off.length() > trail:
			centre = want + off.normalized() * trail
	var c_s := skel.global_transform.affine_inverse() * centre
	var outward := String(d.get("face", "forward")) == "outward"
	var camera_face := String(d.get("face", "forward")) == "camera"
	var sway := deg_to_rad(float(d.get("sway_deg", 0.0)))
	var lean := deg_to_rad(float(d.get("lean_deg", 0.0)))
	for p in parts:
		var part := p as Part
		var a := angle(part, t)
		part.pos = _clear(part, spot(c_s, a, bob(part, t)), dt)
		var roll := Basis(Vector3.FORWARD, lean * cos(2.0 * a + part.bob_phase))
		var bas: Basis
		if camera_face and _face_camera(part, dt):
			bas = part.look * roll
		elif outward:
			bas = Basis.looking_at(Vector3(cos(a), 0.0, -sin(a)), Vector3.UP) * roll
		else:
			bas = Basis(Vector3.UP, sway * sin(TAU * t / (1.7 * float(d.get("period", 4.0))) + part.bob_phase)) * roll
		var turn := axes.orthonormalized()
		part.node.transform = Transform3D(turn * bas * turn.inverse(), part.pos)
		for bm in part.by_mood:
			(bm[0] as MeshInstance3D).visible = mood != null and WardenMood.IDS.find_key(mood.cur) in bm[1]
		# (the empties the sun carries sit on a bone: put them where that bone must hold them to land on the sun)
		for an in part.anchors:
			var inv := skel.get_bone_global_pose(int(an[2])).affine_inverse()
			(an[0] as Node3D).position = inv * (part.pos + (an[1] as Vector3))
