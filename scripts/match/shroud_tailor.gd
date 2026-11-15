class_name ShroudTailor
extends RefCounted
## Collects one Empty's cloth while the cut is built, weights it to ShroudSkin's bones and bakes one skinned mesh per
## tone. A rule says what a piece follows (see add): `legs` and `arms` 0..1 are how much cloth near a limb moves
## with it; `bone`, `from` and `reach` hang it from a cloth spring, the far end moving most.

const TONES := ["body", "alt", "trim"]
## How each body's cloth is cut, whatever the style: [height (m, torso space), reach (m), x the width there]. Hers
## comes in at the shoulders and waist and out over the hips; his is broad across the shoulders over lean hips.
const FIGURE := {
	true: [[0.5, 0.1, 0.94], [0.26, 0.09, 0.86], [0.0, 0.1, 1.09]],
	false: [[0.47, 0.11, 1.1], [0.02, 0.14, 0.94]],
}
const NECK := {true: 0.85, false: 1.1}      # x the collar's girth: her slimmer neck, his thicker one
static var _baked := {}

var c: Dictionary
var fit: Dictionary                 # the look's settings
var m: Dictionary                   # the model's materials
var torso: Node3D
var bw: float
var span: float
var fem: bool
var ly: float                       # the legs' length factor
var floor_y: float                  # the ground, in torso space
var hip_y: float
var joints := {}                    # shoulder, elbow, hand, hip, knee per side [L, R]
var tag := ""                       # what this build's meshes depend on (their cache keys)
var key := ""
var cached := false                 # this exact shroud is already baked: skip making the cloth again
var pieces := {"body": [], "alt": [], "trim": []}
var bands: Array = []               # edges that take the trim: {fn(u, w), length (m), rule}
var keep := 0.6                     # of the cloth's triangles: most shells are cut finer than they need
var bulk := 1.0                     # the race bulk Models.hunter puts on the body, which the cloth takes too

func _init(ctx: Dictionary, settings: Dictionary) -> void:
	c = ctx
	fit = settings
	m = (ctx["m"] as Dictionary).duplicate()
	m["alt"] = m["cloak"]
	torso = ctx["torso"]
	bw = ctx["bw"]
	span = (0.9 if ctx["fem"] else 1.0) * float(ctx["cw"])
	fem = ctx["fem"]
	var legs := torso.get_parent().get_node("Legs") as Node3D
	ly = legs.scale.y
	floor_y = -torso.position.y
	var leg_l := legs.get_node("LegL") as Node3D
	var leg_r := legs.get_node("LegR") as Node3D
	var arms: Dictionary = ctx["arms"]
	hip_y = leg_l.position.y * ly - torso.position.y
	joints = {"hip": [_at(leg_l.position, ly), _at(leg_r.position, ly)], "knee": [], "sh": [], "el": [], "ha": []}
	for i in 2:
		var sd: String = ["L", "R"][i]
		var hip: Vector3 = joints["hip"][i]
		joints["knee"].append(hip + Vector3(0, -0.2 * ly, 0))
		var sh := (arms[sd][0] as Node3D).position
		joints["sh"].append(sh)
		joints["el"].append(sh + (arms[sd][1] as Node3D).position)
		joints["ha"].append(sh + (arms[sd][1] as Node3D).position + (arms[sd][2] as Node3D).position)
	tag = "%.3f|%.3f|%.3f|%s" % [bw, span, ly, fem]
	key = "%s|%s|%s|%s|%s" % [settings["style"], settings["hood"], settings["trim"], settings["accessory"], tag]
	cached = _baked.has(key)
	if int(settings["accent"]) >= 0:
		m["trim"] = _accent(Unmasked.COLOURS[settings["accent"]])

func _at(p: Vector3, k: float) -> Vector3:
	return Vector3(p.x, p.y * k - torso.position.y, p.z)

## The accent as the model's own trim material takes it (the same lighting setup, a new colour).
func _accent(col: Color) -> ShaderMaterial:
	var mat := (m["trim"] as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo", col)
	return mat

## Adds a piece of cloth to a tone. rule: {legs, arms, bone, from, reach, share}, see _weigh.
func add(tone: String, mesh: Mesh, rule: Dictionary, xf := Transform3D.IDENTITY) -> void:
	if not cached:
		(pieces[tone] as Array).append([mesh, rule, xf])

## A piece that rides one joint of the rig, not the cloth.
func rigid(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	Models.part(parent, mesh, mat, pos, Vector3.ONE, rot)

## An edge that wears the trim: fn(u, w) is the band, u along the edge, w across it, `metres` long.
func band(fn: Callable, metres: float, rule: Dictionary) -> void:
	bands.append({"fn": fn, "len": metres, "rule": rule})

## The cloth bones and meshes, and the springs the cut needs: HunterAnim picks up Cape and Scarf by name.
func finish() -> void:
	var skin := ShroudSkin.new()
	skin.position = Vector3.ZERO
	skin.scale = Vector3(bulk, 1.0, bulk)
	torso.add_child(skin)
	var legs := torso.get_parent().get_node("Legs")
	var arms: Dictionary = c["arms"]
	skin.follow({
		ShroudSkin.SKIRT: torso.get_node("Skirt"), ShroudSkin.CAPE: Models._pivot(torso, "Cape", Vector3(0, 0.6, 0.12)),
		ShroudSkin.SCARF: Models._pivot(torso, "Scarf", Vector3(0, 0.62, 0.05)),
		ShroudSkin.LEG_L: legs.get_node("LegL"), ShroudSkin.LEG_R: legs.get_node("LegR"),
		ShroudSkin.KNEE_L: c["knees"]["L"], ShroudSkin.KNEE_R: c["knees"]["R"],
		ShroudSkin.ARM_L: arms["L"][0], ShroudSkin.ARM_R: arms["R"][0],
		ShroudSkin.ELBOW_L: arms["L"][1], ShroudSkin.ELBOW_R: arms["R"][1],
	})
	# the body's small parts share the cloth's materials: soles with the legs, the cuffs with the accent
	var base: Dictionary = c["m"]
	var root := torso.get_parent().get_parent()
	root.set_meta("shroud_swap", {base["dark"]: base["pants"], base["acc"]: m["trim"], base["trim"]: m["trim"]})
	var meshes := _bake()
	for tone in meshes:
		var mi := MeshInstance3D.new()
		mi.name = "Cloth" + String(tone).capitalize()
		mi.mesh = meshes[tone]
		mi.material_override = m[tone]
		skin.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _bake() -> Dictionary:
	if cached:
		return _baked[key]
	var out := {}
	for tone in TONES:
		if not (pieces[tone] as Array).is_empty():
			out[tone] = _bake_tone(pieces[tone])
	_baked[key] = out
	return out

func _bake_tone(list: Array) -> ArrayMesh:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	for pc in list:
		var src: Array = (pc[0] as Mesh).surface_get_arrays(0)
		var xf: Transform3D = pc[2]
		var base := vs.size()
		var pts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var lo := INF
		var hi := -INF
		for p in pts:
			var q: Vector3 = xf * p
			lo = minf(lo, q.y)
			hi = maxf(hi, q.y)
		for i in pts.size():
			var p: Vector3 = xf * pts[i]
			var w := _weigh(p, pc[1])
			p = _fit(p, w)
			vs.append(p)
			ns.append((xf.basis * (src[Mesh.ARRAY_NORMAL] as PackedVector3Array)[i]).normalized())
			uvs.append((src[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[i])
			uv2.append(Vector2(lo, hi))
			var col: Variant = src[Mesh.ARRAY_COLOR]
			cols.append(Color.WHITE if col == null else (col as PackedColorArray)[i])
			_top4(w, bones, weights)
		for j in (src[Mesh.ARRAY_INDEX] as PackedInt32Array):
			idx.append(base + j)
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = vs
	arrs[Mesh.ARRAY_NORMAL] = ns
	arrs[Mesh.ARRAY_TEX_UV] = uvs
	arrs[Mesh.ARRAY_TEX_UV2] = uv2
	arrs[Mesh.ARRAY_COLOR] = cols
	arrs[Mesh.ARRAY_BONES] = bones
	arrs[Mesh.ARRAY_WEIGHTS] = weights
	arrs[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	var fine := EmptySlim.reduce(arrs, keep)
	if not fine.is_empty():
		arrs[Mesh.ARRAY_INDEX] = fine
	var far := EmptySlim.reduce(arrs, EmptySlim.LOD_KEEP)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs, [], {} if far.is_empty() else {0.05: far})
	return am

## How much wider the cloth is cut at height y for this body (FIGURE).
func girth(y: float) -> float:
	var k := 1.0
	for f in FIGURE[fem]:
		k += (float(f[2]) - 1.0) * exp(-pow((y - float(f[0])) / float(f[1]), 2.0))
	return k

## A cloth vertex taken in or let out to the body's figure; cloth that rides an arm (a sleeve) stays round the arm.
func _fit(p: Vector3, w: PackedFloat32Array) -> Vector3:
	var arm := w[ShroudSkin.ARM_L] + w[ShroudSkin.ARM_R] + w[ShroudSkin.ELBOW_L] + w[ShroudSkin.ELBOW_R]
	var k := lerpf(girth(p.y), 1.0, smoothstep(0.4, 0.8, arm))
	return Vector3(p.x * k, p.y, p.z * lerpf(1.0, k, 0.5))

## How much a cloth vertex follows each bone. legs: cloth below the hip follows the leg on its side, more toward
## the hem, the lower part with the knee (so a kicked-back shin keeps its cloth). arms: cloth within reach of an
## arm moves with it. bone/from/reach/share: a spring piece, moving more the farther it hangs from `from`. What
## is left stays with the Skirt spring below the hip and with the torso above it.
func _weigh(p: Vector3, r: Dictionary) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(ShroudSkin.COUNT)
	var legs := float(r.get("legs", 0.0))
	var arms := float(r.get("arms", 0.0))
	var below := clampf((hip_y + 0.05 - p.y) / (hip_y + 0.05 - floor_y), 0.0, 1.0)
	if arms > 0.0:
		for s in 2:
			var d1 := Geometry3D.get_closest_point_to_segment(p, joints["sh"][s], joints["el"][s]).distance_to(p)
			var d2 := Geometry3D.get_closest_point_to_segment(p, joints["el"][s], joints["ha"][s]).distance_to(p)
			w[ShroudSkin.ARM_L + s] = arms * (1.0 - smoothstep(0.1, 0.3, d1)) * (1.0 - below)
			w[ShroudSkin.ELBOW_L + s] = arms * (1.0 - smoothstep(0.08, 0.26, d2)) * (1.0 - below)
	if legs > 0.0:
		var sx := smoothstep(-0.2, 0.2, p.x)
		var k := legs * smoothstep(0.05, 0.5, below)
		var kn := smoothstep(0.45, 0.95, below) * 0.65
		w[ShroudSkin.LEG_L] = k * (1.0 - sx) * (1.0 - kn)
		w[ShroudSkin.LEG_R] = k * sx * (1.0 - kn)
		w[ShroudSkin.KNEE_L] = k * (1.0 - sx) * kn
		w[ShroudSkin.KNEE_R] = k * sx * kn
	if r.has("bone"):
		var far := clampf(p.distance_to(r["from"]) / float(r["reach"]), 0.0, 1.0)
		w[r["bone"]] = float(r.get("share", 1.0)) * smoothstep(0.0, 0.6, far)
	var sum := 0.0
	for x in w:
		sum += x
	if sum > 1.0:
		for i in w.size():
			w[i] /= sum
	elif sum < 1.0:
		var lower := smoothstep(0.0, 0.2, below)
		w[ShroudSkin.SKIRT] += (1.0 - sum) * lower
		w[ShroudSkin.TORSO] += (1.0 - sum) * (1.0 - lower)
	return w

## The four strongest bones, weights summing to 1, as the mesh arrays want them.
static func _top4(w: PackedFloat32Array, bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	var order: Array = range(w.size())
	order.sort_custom(func(a: int, b: int) -> bool: return w[a] > w[b])
	var sum := 0.0
	for i in 4:
		sum += w[order[i]]
	for i in 4:
		bones.append(order[i])
		weights.append(w[order[i]] / sum)
