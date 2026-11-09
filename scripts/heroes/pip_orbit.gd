class_name PipOrbit
extends RefCounted
## Meeko's sun and moon, owner item 24: two living companions that circle her upper body on opposite
## sides, bob, spin and glow (the sun warm, the moon cool), trail a little behind her when she moves, and spin up
## and flare when she casts. They keep clear of her face and of the camera: on the side in front of her or toward
## the camera they sink and swing wider.
## The glb (art/wardens/pip, tools/art1/pip_companions.py) carries the sun and a raincloud skinned rigidly to her
## shoulders. make() lifts them off the body mesh: the sun as it is, and the cloud's face onto a small moon built
## here (the cloud's body and drops go). The faces keep their mood cells (WardenMood, warden_anim/pip.json "faces").
## Numbers: content/rules/tuning.json "meeko"; sizes are metres on the class-neutral model and scale with her.

const ART := "pip"
const SUN := ["cloth-sun", "eyes-mood_sun"]
const MOON_FACE := "eyes-mood_cloud"
const GONE := ["skin-cloud", "ice-drop"]
const LIGHT_ANCHOR := "anchor_hang_lantern"     # the sun's warm light and halo (warden_look "lights", "halos")
const HIPS := "hips"
## Crater directions on the moon (-Z is its face): round its rim and back, clear of the face.
const CRATERS := [
	Vector3(0.85, 0.45, -0.25), Vector3(-0.85, -0.4, -0.3), Vector3(0.1, -0.9, 0.4), Vector3(-0.4, 0.7, 0.6)]
const CRATER_R := 0.26        # x the moon's radius
const CRATER_FLAT := 0.35     # its depth, x its width
const FACE_LIFT := 0.004      # m the moon's face sits off its skin

static var _cache: Dictionary = {}    # source mesh -> [body without the companions, sun, moon]

var root: Node3D
var skel: Skeleton3D
var hips := -1
var d: Dictionary
var pals: Array = []          # [node, its glow material], the sun first
var pivot := Vector3.INF      # world point they circle, trailing her
var phase := 0.0
var spin := 0.0
var kick := 0.0               # 1 on a cast, fading
var last_km := ""
var t := 0.0

## Meeko's companions on her glb, or null for any other model.
static func make(model: Node3D, glb: Node3D, sk: Skeleton3D, art_name: String) -> PipOrbit:
	if art_name != ART:
		return null
	var body := _body(glb)
	if body == null:
		return null
	if not _cache.has(body.mesh):
		_cache[body.mesh] = _split(body.mesh)
	var parts: Array = _cache[body.mesh]
	body.mesh = parts[0]
	var o := PipOrbit.new()
	o.root = model
	o.skel = sk
	o.hips = WardenSkeleton.find(sk, HIPS)
	o.d = Tuning.of("meeko")
	var sun := o._pal(glb, "Sun", parts[1], Color(String(o.d["sun_glow"])))
	o._pal(glb, "Moon", parts[2], Color(String(o.d["moon_glow"])))
	var lamp := WardenGlb.anchor(model, LIGHT_ANCHOR)
	if lamp:
		lamp.reparent(sun, false)
		lamp.transform = Transform3D.IDENTITY
	return o

static func _body(glb: Node3D) -> MeshInstance3D:
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var m := mesh.surface_get_material(si)
			if m and m.resource_name == SUN[0]:
				return mi
	return null

## [the body without the sun and cloud (its LODs kept), the sun round its centre, the moon].
static func _split(src: ArrayMesh) -> Array:
	var body := src.duplicate() as ArrayMesh
	var sun := ArrayMesh.new()
	var face := -1
	var centre := Vector3.ZERO
	for si in range(src.get_surface_count() - 1, -1, -1):
		var nm := src.surface_get_material(si).resource_name
		if nm == SUN[0]:
			centre = _mid(src.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
		if nm == MOON_FACE:
			face = si
		if nm in SUN or nm in GONE or nm == MOON_FACE:
			body.surface_remove(si)
	for si in src.get_surface_count():
		var nm := src.surface_get_material(si).resource_name
		if nm in SUN:
			var a := _unskinned(src.surface_get_arrays(si), Transform3D(Basis.IDENTITY, -centre))
			_add(sun, a, src.surface_get_material(si))
	return [body, sun, _moon(src, face)]

## A small moon: a slightly flat ball, a few craters, the cloud's face laid onto its front.
static func _moon(src: ArrayMesh, face: int) -> ArrayMesh:
	var dd := Tuning.of("meeko")
	var r := float(dd["moon_r_m"])
	var depth := float(dd["moon_depth"])
	var out := ArrayMesh.new()
	var ball := Models.sphere(1.0, 16)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(ball, 0, Transform3D(Basis.from_scale(Vector3(r, r, r * depth)), Vector3.ZERO))
	st.commit(out)
	out.surface_set_material(0, _flat("skin-moon", Color(String(dd["moon_col"]))))
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in CRATERS:
		var n := (c as Vector3).normalized()
		var at := Vector3(n.x * r, n.y * r, n.z * r * depth) * 0.97
		var b := Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
		st.append_from(ball, 0, Transform3D(b * Basis.from_scale(Vector3(1, 1, CRATER_FLAT) * r * CRATER_R), at))
	st.commit(out)
	out.surface_set_material(1, _flat("hair-crater", Color(String(dd["crater_col"]))))
	if face >= 0:
		var a := _unskinned(src.surface_get_arrays(face), Transform3D.IDENTITY)
		_onto_moon(a, r, depth, float(dd["moon_face_k"]))
		_add(out, a, src.surface_get_material(face))
	return out

## The face decal, flattened round its middle, scaled by k and laid on the moon's front (-Z) with its normals.
static func _onto_moon(a: Array, r: float, depth: float, k: float) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var mid := _mid(v)
	for i in v.size():
		var x := (v[i].x - mid.x) * k
		var y := (v[i].y - mid.y) * k
		var z := -sqrt(maxf(0.0, r * r - x * x - y * y)) * depth
		nrm[i] = Vector3(x / (r * r), y / (r * r), z / (r * r * depth * depth)).normalized()
		v[i] = Vector3(x, y, z) + nrm[i] * FACE_LIFT
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nrm
	a[Mesh.ARRAY_TANGENT] = null

static func _unskinned(a: Array, xf: Transform3D) -> Array:
	a[Mesh.ARRAY_BONES] = null
	a[Mesh.ARRAY_WEIGHTS] = null
	a[Mesh.ARRAY_VERTEX] = xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return a

static func _add(mesh: ArrayMesh, a: Array, mat: Material) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

static func _mid(v: PackedVector3Array) -> Vector3:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	return (lo + hi) * 0.5

## A flat-painted glb material ("<slot>-<tag>"), so WardenGlb._toon dresses it like the rest of her.
static func _flat(nm: String, c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = nm
	m.albedo_color = c
	return m

func _pal(glb: Node3D, nm: String, mesh: ArrayMesh, glow: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.top_level = true
	glb.add_child(mi)
	mi.owner = glb      # (the glb's own anchors are reparented onto it)
	var gm := CareLook.orb_mat(glow)
	var ball := Models.part(mi, Models.sphere(1.0, 12), gm, Vector3.ZERO, Vector3.ONE * float(d["glow_r_m"]))
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pals.append([mi, gm])
	return mi

func step(dt: float) -> void:
	t += dt
	var km := String((root.get_meta(WardenClips.STATE, {}) as Dictionary).get("kmove", ""))
	if km != last_km and km != "":
		kick = 1.0
	last_km = km
	kick = maxf(0.0, kick - dt / float(d["cast_s"]))
	var xf := skel.global_transform
	var frame := xf.basis.orthonormalized()
	var sc := (xf.basis.get_scale().x + xf.basis.get_scale().y + xf.basis.get_scale().z) / 3.0
	var hip := skel.get_bone_global_pose(hips).origin if hips >= 0 else Vector3.ZERO
	var want := xf * (hip + Vector3.UP * float(d["lift_m"]))
	if not pivot.is_finite():
		pivot = want
	pivot = pivot.lerp(want, 1.0 - exp(-float(d["lag_rate"]) * dt))
	pivot = want + (pivot - want).limit_length(float(d["lag_max_m"]) * sc)
	var kk := kick * kick
	phase += TAU * float(d["orbit_hz"]) * dt * (1.0 + kk * float(d["cast_orbit_k"]))
	spin += TAU * float(d["spin_hz"]) * dt * (1.0 + kk * float(d["cast_spin_k"]))
	var cam := root.get_viewport().get_camera_3d() if root.is_inside_tree() else null
	var to_cam := Vector3.ZERO
	if cam:
		to_cam = cam.global_position - pivot
		to_cam.y = 0.0
		to_cam = to_cam.normalized()
	for i in pals.size():
		_place(pals[i], i, frame, sc, to_cam, kk)

func _place(pal: Array, i: int, frame: Basis, sc: float, to_cam: Vector3, kk: float) -> void:
	var a := phase + PI * i
	var out := Vector3(sin(a), 0.0, cos(a))       # on her model, -Z her front
	var out_w := frame * out
	var clear := maxf(smoothstep(0.2, 0.85, -out.z), smoothstep(0.2, 0.85, out_w.dot(to_cam)))
	var r := float(d["radius_m"]) + float(d["clear_push_m"]) * clear + float(d["cast_pop_m"]) * kk
	var y := float(d["bob_m"]) * sin(TAU * float(d["bob_hz"]) * t + PI * i) - float(d["clear_dip_m"]) * clear
	var turn := spin * (1.0 if i == 0 else -1.0)
	var tilt := float(d["tilt_rad"]) * sin(TAU * float(d["bob_hz"]) * 0.5 * t + i * 1.3)
	var b := Basis.looking_at(out_w, Vector3.UP) * Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, tilt)
	var at := pivot + frame * Vector3(out.x * r, y, out.z * r) * sc
	(pal[0] as Node3D).global_transform = Transform3D(b.scaled(Vector3.ONE * sc), at)
	var pulse := sin(TAU * float(d["pulse_hz"]) * t + PI * i)
	(pal[1] as ShaderMaterial).set_shader_parameter(
			"alpha", float(d["glow_a"]) * (1.0 + float(d["pulse"]) * pulse) + float(d["cast_flare"]) * kk)
