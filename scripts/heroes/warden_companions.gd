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
##   "face": "forward" (as modelled) or "outward", "sway_deg": a slow yaw, "lean_deg": a roll into the turn
##   "list": [{"id", "surfaces": [material names], "at": [x, y, z] the part's centre at rest, "phase_deg" (0 = her
##     right), "bob_period", "bob_phase", "bone": the bone it was skinned to, "anchors": [empties that ride it]}]
## Cosmetic only; nothing here touches a kit (the FX empties on the sun follow it, so a shot leaves the sun).

const PREFIX := "Companion_"   # node name of each cut-out part
const SNAP := 1.5      # m: a centre further than this from where it should be (a respawn) jumps there

static var _cut := {}        # mesh -> {body mesh, parts: {id: [mesh, rest centre]}}: one cut per .glb

class Part:
	var id := ""
	var node: MeshInstance3D
	var rest := Vector3.ZERO          # the part's centre at rest (skeleton space)
	var phase := 0.0                  # rad
	var bob_period := 2.7
	var bob_phase := 0.0
	var bone := -1                    # the bone its anchors were on
	var anchors: Array = []           # [empty, its rest position relative to the part's centre]
	var pos := Vector3.ZERO           # last placed (skeleton space)

var skel: Skeleton3D
var d: Dictionary
var parts: Array = []
var centre_bone := -1
var centre_off := Vector3.ZERO      # circle centre minus the bone's rest origin
var centre := Vector3.ZERO          # the eased centre (world)
var primed := false
var t := 0.0

## Cuts the companions out of `glb`'s body mesh when `data` has them; returns the live helper or null.
static func detach(glb: Node3D, sk: Skeleton3D, data: Dictionary) -> WardenCompanions:
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
	var cut := _cut_for(body, dd)
	if cut.is_empty():
		return null
	var wc := WardenCompanions.new()
	wc.skel = sk
	wc.d = dd
	body.mesh = cut["body"]
	for p in dd["list"]:
		var part := Part.new()
		part.id = String(p["id"])
		var pc := (cut["parts"] as Dictionary)[part.id] as Array
		var at: Array = p["at"]
		part.rest = Vector3(at[0], at[1], at[2])
		part.node = MeshInstance3D.new()
		part.node.name = PREFIX + part.id
		part.node.mesh = pc[0]
		part.node.position = part.rest
		part.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sk.add_child(part.node)
		part.phase = deg_to_rad(float(p.get("phase_deg", 0.0)))
		part.bob_period = float(p.get("bob_period", 2.7))
		part.bob_phase = float(p.get("bob_phase", 0.0))
		part.bone = WardenSkeleton.find(sk, String(p.get("bone", "")))
		for an in p.get("anchors", []):
			var nd := glb.find_child(String(an), true, false) as Node3D
			if nd and part.bone >= 0:
				var at_rest := sk.get_bone_global_rest(part.bone) * nd.position
				part.anchors.append([nd, at_rest - part.rest])
		wc.parts.append(part)
	var c: Array = dd.get("at", [0, 1, 0])
	wc.centre_bone = WardenSkeleton.find(sk, String(dd.get("bone", "hips")))
	var origin := sk.get_bone_global_rest(wc.centre_bone).origin if wc.centre_bone >= 0 else Vector3.ZERO
	wc.centre_off = Vector3(c[0], c[1], c[2]) - origin
	return wc

## The body mesh without the companions' surfaces and one unskinned mesh per companion, cut once per .glb.
static func _cut_for(body: MeshInstance3D, dd: Dictionary) -> Dictionary:
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
	var parts := {}
	var gone: Array = []
	for p in dd["list"]:
		var am := ArrayMesh.new()
		var at: Array = p["at"]
		var centre := Vector3(at[0], at[1], at[2])
		for nm in p["surfaces"]:
			var si := names.find(String(nm))
			if si < 0:
				continue
			gone.append(si)
			var arr := src.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] -= centre
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, src.surface_get_material(si))
		parts[String(p["id"])] = [am, centre]
	gone.sort()
	gone.reverse()
	for si in gone:
		mine.surface_remove(si)
	var out := {"body": mine, "parts": parts}
	_cut[key] = out
	return out

## The circle's point at angle `a` (0 = her right, through her front for dir 1) about `c` (skeleton space), with the
## vertical bob `bob_y`.
func spot(c: Vector3, a: float, bob_y: float) -> Vector3:
	var r: Array = d.get("radius", [0.5, 0.4])
	return c + Vector3(float(r[0]) * cos(a), bob_y, -float(r[1]) * sin(a))

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
	var sway := deg_to_rad(float(d.get("sway_deg", 0.0)))
	var lean := deg_to_rad(float(d.get("lean_deg", 0.0)))
	for p in parts:
		var part := p as Part
		var a := angle(part, t)
		part.pos = spot(c_s, a, bob(part, t))
		var roll := Basis(Vector3.FORWARD, lean * cos(2.0 * a + part.bob_phase))
		var bas: Basis
		if outward:
			bas = Basis.looking_at(Vector3(cos(a), 0.0, -sin(a)), Vector3.UP) * roll
		else:
			bas = Basis(Vector3.UP, sway * sin(TAU * t / (1.7 * float(d.get("period", 4.0))) + part.bob_phase)) * roll
		part.node.transform = Transform3D(bas, part.pos)
		# (the empties the sun carries sit on a bone: put them where that bone must hold them to land on the sun)
		if part.bone >= 0 and not part.anchors.is_empty():
			var inv := skel.get_bone_global_pose(part.bone).affine_inverse()
			for an in part.anchors:
				(an[0] as Node3D).position = inv * (part.pos + (an[1] as Vector3))
