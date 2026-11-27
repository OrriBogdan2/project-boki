class_name EmptyGlb
extends RefCounted
## The Empty in 3D: a Meshy model of the Hooded Cloak cut for each sex (art/wardens/empty_f, empty_m), on Meshy's
## own skeleton and clips (WardenNative, docs/art/wardens/MESHY_NATIVE.md). Models.hunter builds the procedural Empty
## as before (its rig, the void head with its hollow, ghost and glow, the aura), then this dresses it in the .glb of its sex
## (WardenGlb.dress), hides the procedural body under it and dyes the cloak to the look's shroud and accent colours.
## The model has only that cut: another cut, the hood down, a trim pattern or an accessory keeps the procedural
## Empty, so every shroud choice still shows.

const KEYS := ["empty_f", "empty_m"]  # WardenGlb art names, by Unmasked "gender" (0 female, 1 male)
const CUT := 0  # Shrouds.STYLES: the Hooded Cloak, the cut the models wear
const CLOTH_PAINT := Color("2f3245")  # the models' painted cloak colour (their atlas: median of the cloak texels)
const TRIM_PAINT := Color("909db7")  # and of their hem band
## Procedural pieces that stay over the .glb: the void head (its hollow shell rides on it) and WardenGlb's own.
const KEEP := ["Head", "Aura"]
## The painted egg of a head inside each model's hood, by sex as KEYS (model space at rest, m: its centre, its
## height; measured on the .glb's faces in the hood that are neither cloak nor trim; the male's top, hidden from the
## front, from the game shots). The void head is fitted onto it, so the hood frames the void face as in the art
## (the procedural head is about twice its size).
const EGG := [[Vector3(0.0, 1.242, -0.09), 0.264], [Vector3(0.0, 1.235, -0.11), 0.25]]
const EGG_COVER := 1.06  # x the egg's height: the void shell just covers the painted egg


## The .glb this Empty look wears ("" for the procedural Empty).
static func key(appearance: Dictionary) -> String:
	var u := Unmasked.clean(appearance)
	var s := Shrouds.settings(u)
	if int(s["style"]) != CUT or int(s["hood"]) != 1 or int(s["trim"]) != 0 or int(s["accessory"]) != 0:
		return ""
	var k: String = KEYS[clampi(int(u["gender"]), 0, KEYS.size() - 1)]
	return k if WardenGlb.has_model(k) else ""


## The default Empty of a model key's sex, in the Hooded Cloak: the look the model's head size is measured against.
static func rest_look(k: String) -> Dictionary:
	var lk := Unmasked.default_look()
	lk["gender"] = KEYS.find(k)
	lk["shroud"] = CUT
	return lk


## Dresses the procedural Empty `root` (Models.hunter, look `appearance`, MantleLook params lk) in its 3D model
## when the look has one.
static func dress(root: Node3D, appearance: Dictionary, lk: Dictionary) -> void:
	var k := key(appearance)
	if k == "" or not WardenGlb.will_dress(k):
		return
	WardenGlb.dress(root, k, lk)
	if not bool(root.get_meta(WardenNative.META, false)):
		return
	_hide_body(root.get_node("Rig") as Node3D)
	var size := EmptyFrame.factor(Unmasked.clean(appearance), "head") / EmptyFrame.factor(rest_look(k), "head")
	_into_hood(root, KEYS.find(k), size)
	WardenBulk.apply(root, EmptyFrame.bulk(Unmasked.clean(appearance)))  # (the build slider thickens the skin)
	_dye(root.get_node("Warden") as Node3D, Unmasked.clean(appearance))


## The procedural body's meshes go, except the void head and the pieces every .glb Hunter keeps.
static func _hide_body(n: Node3D) -> void:
	for c in n.get_children():
		if String(c.name) in KEEP or String(c.name) in WardenGlb.KEEP or not c is Node3D:
			continue
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = false
		_hide_body(c as Node3D)


## The void head (the procedural Head and the hollow shell on it) scaled and moved onto the model's painted egg and
## hung on Meshy's Head bone, so it turns with the model's clips; `size` is the look's head-size slider against the rest
## look's, so the slider still sizes the head in the hood. The egg's numbers are for the model as fitted, times how far
## the rig's height scaled it (the glb's scale; 1 in the rest look).
static func _into_hood(root: Node3D, sex: int, size: float) -> void:
	var head := root.get_node("Rig/Torso/HeadPivot/Head") as Node3D
	var hollow := head.get_node("Hollow") as MeshInstance3D
	var fitted := (root.get_node("Warden") as Node3D).scale.y
	var box := WardenGlb.model_xf(root, hollow) * hollow.get_aabb()
	head.scale *= float(EGG[sex][1]) * fitted * EGG_COVER * size / box.size.y
	box = WardenGlb.model_xf(root, hollow) * hollow.get_aabb()
	var xf := WardenGlb.model_xf(root, head)
	xf.origin += (EGG[sex][0] as Vector3) * fitted - box.get_center()
	_hang(root, head, "Head", xf)
	var aura := root.get_node_or_null("Rig/Torso/Aura") as Node3D
	if aura:
		_hang(root, aura, "Spine02", WardenGlb.model_xf(root, aura))


## Puts the procedural node `nd` (at `xf` in the model's frame, at rest) on Meshy's bone `bone`: it rides the clips.
static func _hang(root: Node3D, nd: Node3D, bone: String, xf: Transform3D) -> void:
	var skel := WardenGlb.skeleton(root.get_node("Warden") as Node3D)
	var at := BoneAttachment3D.new()
	at.name = bone + "Hang"
	at.bone_name = bone
	skel.add_child(at)
	nd.reparent(at, false)
	nd.transform = (
		(WardenGlb.model_xf(root, skel) * skel.get_bone_global_rest(skel.find_bone(bone))).affine_inverse() * xf
	)


## The cloak takes the shroud colour and the hem band the accent (or, matching the shroud, its own lighter shade):
## a multiplier on the painted atlas, so the folds and brushwork stay.
static func _dye(glb: Node3D, u: Dictionary) -> void:
	var shroud: Color = Unmasked.COLOURS[int(u["colour"])]
	var cloth := _ratio(shroud, CLOTH_PAINT)
	var trim := cloth
	var accent := int(Shrouds.settings(u)["accent"])
	if accent != Shrouds.NO_ACCENT:
		var a: Color = Unmasked.COLOURS[accent]
		trim = _ratio(Color.from_hsv(a.h, clampf(a.s * 0.9, 0.05, 0.75), clampf(a.v * 0.95, 0.55, 0.95)), TRIM_PAINT)
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			var slot := String(src.resource_name).get_slice("-", 0) if src else ""
			if sm and slot in ["cloth", "trim"]:
				sm.set_shader_parameter("albedo", cloth if slot == "cloth" else trim)


static func _ratio(want: Color, painted: Color) -> Color:
	return Color(want.r / painted.r, want.g / painted.g, want.b / painted.b)
