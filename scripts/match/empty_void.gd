class_name EmptyVoid
extends RefCounted
## The Empty's bare body: every skin-side part of the hunter rig drawn in one void material (a deep fill with stars
## seen through it, a lit edge and an ink line, shaders/void_body.gdshader), and the hunter's boot soles, cuffs and
## knee pads left off, so what shows under the cloak is a smooth, featureless silhouette. Earned clothes (Wardrobe)
## are drawn on the same parts, so they fit every frame the sliders make.

const VOID_BODY := preload("res://shaders/void_body.gdshader")
const OUTLINE_W := 0.0024  # the ink line (outline.gdshader), bolder than a Hunter's
const DROP_Z := -0.01  # m: a part in front of the knee's pivot is the knee pad (the bare body has none)
## The skin-side materials HunterBody gives the body: on the Empty they all become the void.
const SKIN_MATS := ["body", "pants", "skin", "leather", "dark"]


## The body's material: the void fill in the look's tint, its lit edge and ink line in the outline colour.
static func material(u: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOID_BODY
	var line: Color = Unmasked.LINES[u["line"]]
	mat.set_shader_parameter("deep", Unmasked.VOID_TINTS[u["void"]])
	mat.set_shader_parameter("edge", line)
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("color", line)
	ink.set_shader_parameter("width", OUTLINE_W)
	mat.next_pass = ink
	return mat


## Puts the rig's skin-side parts in the void (the frame already applied); the parts a worn top, bottom or feet
## piece covers (Wardrobe) are that piece's cloth instead.
static func dress(c: Dictionary, u: Dictionary) -> void:
	var body := material(u)
	var m: Dictionary = c["m"]
	var skin: Array = SKIN_MATS.map(func(k: String) -> Material: return m[k])
	var cloth := _cloth(u)
	for node in _nodes(c):
		var gear: Array = []
		for ch in node.get_children():
			var mi := ch as MeshInstance3D
			if mi == null:
				continue
			var slot := _slot(node, mi, m, u)
			if cloth.has(slot):
				mi.material_override = cloth[slot]
			elif _is_gear(node, mi, m):
				gear.append(mi)
			elif mi.material_override in skin:
				mi.material_override = body
		for mi in gear:
			mi.free()


## The cloth of each worn top, bottom and feet piece, by slot: painted like a hunter's (cloth, or leather for feet).
static func _cloth(u: Dictionary) -> Dictionary:
	var out := {}
	for slot in ["top", "bottom", "feet"]:
		var p := Wardrobe.worn(u, slot)
		if not p.is_empty():
			out[slot] = Models.painted(Models.toon(Color(String(p["col"]))), 2 if slot == "feet" else 1, 0.3, 0.3, 0.26)
	return out


## The slot whose worn piece would cover this part of the body ("" for none): the torso and sleeves (as far as the
## top's sleeves reach) a top, the hips and thighs a bottom (long ones the knee and the shin too, under no boots),
## the sole (and boots the shin and its cuff) feet.
static func _slot(node: Node, mi: MeshInstance3D, m: Dictionary, u: Dictionary) -> String:
	var mat := mi.material_override
	var nm := String(node.name)
	if nm == "Knee":
		if mat == m["pants"]:
			return "bottom" if int(Wardrobe.worn(u, "bottom").get("length", 0)) >= 2 else ""
		if mat == m["dark"]:
			return "feet"
		if bool(Wardrobe.worn(u, "feet").get("boots", false)) and (mat == m["trim"] or _is_shin(mi, m)):
			return "feet"
		return "bottom" if _is_shin(mi, m) and int(Wardrobe.worn(u, "bottom").get("length", 0)) >= 2 else ""
	if mat == m["pants"]:
		return "bottom"
	if mat != m["body"]:
		return ""
	var reach := int(Wardrobe.worn(u, "top").get("sleeves", 0))
	if nm.begins_with("Arm"):
		return "top" if reach >= 1 else ""
	if nm == "Elbow":
		return "top" if reach >= 2 else ""
	return "top"


## The shin: the hunter's boot, hanging from the knee (in front of it is the knee pad).
static func _is_shin(mi: MeshInstance3D, m: Dictionary) -> bool:
	return mi.material_override == m["leather"] and mi.position.z >= DROP_Z


## The rig's nodes that carry the body: the torso, each leg and knee, each arm's shoulder, elbow and hand.
static func _nodes(c: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = [c["torso"]]
	var legs: Node = (c["torso"] as Node3D).get_parent().get_node("Legs")
	for nm in ["LegL", "LegR"]:
		out.append(legs.get_node(nm))
		out.append(legs.get_node(nm + "/Knee"))
	for sd in ["L", "R"]:
		out.append_array(c["arms"][sd])
	return out


## A hunter's gear on the rig's joints, which the bare body does not have: the boot's sole and cuff and the knee pad
## (on the knee), the glove's cuff (on the hand).
static func _is_gear(node: Node, mi: MeshInstance3D, m: Dictionary) -> bool:
	var mat := mi.material_override
	if node.name == "Knee":
		return mat in [m["dark"], m["trim"], m["steel"]] or (mat == m["leather"] and mi.position.z < DROP_Z)
	return node.name == "Hand" and mat == m["leather"]
