class_name EmptyVoid
extends RefCounted
## The Empty's bare body: every skin-side part of the hunter rig drawn in one void material (a deep fill with stars
## seen through it, a lit edge and an ink line, shaders/void_body.gdshader), and the hunter's boot soles, cuffs and
## knee pads left off, so what shows under the cloak is a smooth, featureless silhouette.

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


## Puts the rig's skin-side parts in the void (the frame already applied).
static func dress(c: Dictionary, u: Dictionary) -> void:
	var body := material(u)
	var m: Dictionary = c["m"]
	var skin: Array = SKIN_MATS.map(func(k: String) -> Material: return m[k])
	for node in _nodes(c):
		var gear: Array = []
		for ch in node.get_children():
			var mi := ch as MeshInstance3D
			if mi == null:
				continue
			if _is_gear(node, mi, m):
				gear.append(mi)
			elif mi.material_override in skin:
				mi.material_override = body
		for mi in gear:
			mi.free()


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
