class_name MobGlb
extends Node
## A common monster drawn from a skinned model (art/mobs/<kind>/<kind>.glb, see docs/art/MOB_MODELS.md) instead of
## MobModels' primitives. The primitives' pivots stay, so mob.gd animates the monster as before; the primitives
## are hidden and this node, beside the model, copies each pivot's motion onto the bone of the same name every
## frame. The model's paint keeps the region's colour: its body hue band is repainted like a pack model's cloth
## (BiomeRun.recolor_mats, meta "pack_part").

const PATH := "res://art/mobs/%s/%s.glb"
## Primitive parts that stay drawn over the model, per kind: lights the model's paint can't give.
const KEEP := {"bomber": ["Spark"], "sentinel": ["Shards"]}
const BAND_WIDTH := 0.05      # half-width of the repainted hue band (fraction of the colour wheel)
const BAND_MIN_SAT := 0.3     # greys, bone whites and cream bellies below this saturation keep their paint
const BAND_MIN_VAL := 0.55    # parts darker than this share of the body's brightness (spines, fists) keep theirs

static var _scenes := {}

var _skel: Skeleton3D
var _body: Node3D
var _links: Array = []        # [bone, pivot, pivot rest in Body space (inverse), bone global rest]
var _skel_rel: Transform3D    # the skeleton in Body space

static func has(kind: String) -> bool:
	return ResourceLoader.exists(PATH % [kind, kind])

## Swaps a MobModels body for the kind's model, if it has one. Call after the primitives are built and merged.
static func dress(root: Node3D, kind: String) -> void:
	if not has(kind):
		return
	if not _scenes.has(kind):
		_scenes[kind] = load(PATH % [kind, kind])
	var body: Node3D = root.get_node("Body")
	_hide_primitives(body, KEEP.get(kind, []))
	var glb := (_scenes[kind] as PackedScene).instantiate() as Node3D
	body.add_child(glb)
	(root.get_meta("mats") as Array).append(_paint(glb, Data.MOBS[kind]))
	var f := MobGlb.new()
	f.name = "MobGlb"
	root.add_child(f)
	f._link(body, glb.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)

static func _hide_primitives(body: Node3D, keep: Array) -> void:
	var stack: Array = [body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if keep.has(String(n.name)):
			continue
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = false
		for ch in n.get_children():
			stack.append(ch)

## One toon material for the whole model: its texture, the body hue band repainted to the region's colour
## (the Blight keep their own ash and ember paint everywhere).
static func _paint(glb: Node3D, md: Dictionary) -> ShaderMaterial:
	var base: Color = md["color"]
	var m := Models.toon(Color.WHITE)
	m.set_shader_parameter("rim_amount", 0.5)
	m.set_shader_parameter("sss", 0.16)
	m.set_shader_parameter("sheen", 0.08)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("recolor", 0.0 if md.get("blight", false) else 1.0)
	m.set_shader_parameter("recolor_width", BAND_WIDTH)
	m.set_shader_parameter("recolor_min_sat", BAND_MIN_SAT)
	m.set_shader_parameter("recolor_to", base)
	m.set_meta("pack_part", "cloth")
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		# the paint's own body hue and brightness, measured when the model was skinned (glTF extras)
		var band: Array = (mi.get_meta("extras", {}) as Dictionary).get("band", [base.h, base.v])
		m.set_shader_parameter("recolor_hue", float(band[0]))
		m.set_shader_parameter("recolor_ref", float(band[1]))
		m.set_shader_parameter("recolor_min_val", float(band[1]) * BAND_MIN_VAL)
		var src := (mi as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		if src and src.albedo_texture:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
		(mi as MeshInstance3D).material_override = m
	return m

func _link(body: Node3D, skel: Skeleton3D) -> void:
	_body = body
	_skel = skel
	_skel_rel = _rel(skel)
	for bi in skel.get_bone_count():
		var pv := body.find_child(skel.get_bone_name(bi), true, false) as Node3D
		if pv and not pv is MeshInstance3D:
			_links.append([bi, pv, _rel(pv).affine_inverse(), skel.get_bone_global_rest(bi)])

## n's transform in Body space (the model may not be in the tree yet).
func _rel(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != _body:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf

func _process(_delta: float) -> void:
	if not _body.is_visible_in_tree():
		return
	var inv := _skel_rel.affine_inverse()
	for l in _links:
		var moved: Transform3D = _rel(l[1]) * l[2]
		_skel.set_bone_global_pose(l[0], inv * moved * _skel_rel * l[3])
