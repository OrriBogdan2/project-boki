class_name WardenGlb
extends RefCounted
## A Warden built in Blender (docs/art/wardens/RIG_CONTRACT.md): when art/wardens/<id>/<id>.glb exists, the
## procedural hunter Models.hunter built keeps its rig, weapon, glider and hit ring but hides its body, and the
## .glb's armature follows the rig nodes HunterAnim poses (each bone mapped to one node in BONES). With no file
## the procedural model stays as it is: the fallback.

const DIR := "res://art/wardens"
## Armature bone -> the rig node it follows (paths under the model root).
const BONES := {
	"root": "Rig",
	"hips": "Rig/Torso",
	"head": "Rig/Torso/HeadPivot",
	"upper_arm.L": "Rig/Torso/ArmLPivot",
	"forearm.L": "Rig/Torso/ArmLPivot/Elbow",
	"hand.L": "Rig/Torso/ArmLPivot/Elbow/Hand",
	"upper_arm.R": "Rig/Torso/ArmRPivot",
	"forearm.R": "Rig/Torso/ArmRPivot/Elbow",
	"hand.R": "Rig/Torso/ArmRPivot/Elbow/Hand",
	"thigh.L": "Rig/Legs/LegL",
	"shin.L": "Rig/Legs/LegL/Knee",
	"thigh.R": "Rig/Legs/LegR",
	"shin.R": "Rig/Legs/LegR/Knee",
	"pauldron.L": "Rig/Torso/PauldronL",
	"pauldron.R": "Rig/Torso/PauldronR",
	"skirt": "Rig/Torso/Skirt",
	"cape": "Rig/Torso/Cape",
	"scarf": "Rig/Torso/Scarf",
	"tail": "Rig/Torso/Tail",
	"wings": "Rig/Torso/Wings",
}
const OPTIONAL := ["cape", "scarf", "tail", "wings"]
## Procedural pieces that stay when the .glb dresses the hunter (the contract's "nodes the game keeps").
const KEEP := ["Gun", "Glider", "TeamRing", "Shield", "Shoulder", "Halo", "Focus"]
## glTF material name -> the toon shader's painted surface (RIG_CONTRACT "Materials").
const SLOTS := {"skin": 4, "hair": 5, "cloth": 1, "leather": 2, "metal": 3, "fur": 5, "eyes": 0, "team": 1, "glow": 0}

static func path(arch: String) -> String:
	return "%s/%s/%s.glb" % [DIR, arch, arch]

static func has_model(arch: String) -> bool:
	return arch != "" and ResourceLoader.exists(path(arch))

## Dresses the procedural hunter `root` in its Warden's .glb when there is one (meta "glb" says which).
static func dress(root: Node3D, arch: String) -> void:
	root.set_meta("glb", false)
	if not has_model(arch):
		return
	var scene := load(path(arch)) as PackedScene
	var glb: Node3D = scene.instantiate() as Node3D if scene else null
	var skels: Array = glb.find_children("*", "Skeleton3D", true, false) if glb else []
	var skel: Skeleton3D = skels[0] if not skels.is_empty() else null
	if skel == null:
		push_warning("WardenGlb: %s has no armature; keeping the procedural model" % path(arch))
		return
	_hide_body(root)
	glb.name = "Warden"
	root.add_child(glb)
	var sync := Sync.new()
	sync.setup(root, skel)
	glb.add_child(sync)
	var mats: Array = root.get_meta("mats", [])
	mats.append_array(_toon(glb))
	root.set_meta("mats", mats)
	root.set_meta("glb", true)

## Hides the procedural body's meshes, leaving the KEEP pieces.
static func _hide_body(n: Node) -> void:
	for ch in n.get_children():
		if String(ch.name) in KEEP:
			continue
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false
		_hide_body(ch)

## Every surface onto a hero-toon material for its slot (base colour only until the shader takes the atlas).
static func _toon(glb: Node) -> Array:
	var out: Array = []
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			var col := (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color.WHITE
			var m := Models.toon(col)
			m.set_shader_parameter("vertex_ao", true)
			m.set_shader_parameter("surface", int(SLOTS.get(String(src.resource_name) if src else "", 1)))
			Models.hero_look(m)
			(mi as MeshInstance3D).set_surface_override_material(si, m)
			out.append(m)
	return out

## The model-space transform of a rig node (chained up to the model root, so it works out of the tree too).
static func model_xf(root: Node3D, nd: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = nd
	while cur != root and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

## Each frame, puts every mapped bone where its rig node has moved it: the node's move since its rest
## applied to the bone's rest (all in model space).
class Sync extends Node:
	var root: Node3D
	var skel: Skeleton3D
	var links: Array = []       # [bone index, rig node, node rest (model space) inverse, bone rest (skeleton space)]

	func setup(model: Node3D, skeleton: Skeleton3D) -> void:
		root = model
		skel = skeleton
		for b in BONES:
			var bi := skel.find_bone(b)
			var nd := root.get_node_or_null(String(BONES[b])) as Node3D
			if bi < 0 or nd == null:
				if not b in OPTIONAL:
					push_warning("WardenGlb: no bone or rig node for %s" % b)
				continue
			links.append([bi, nd, WardenGlb.model_xf(root, nd).affine_inverse(), skel.get_bone_global_rest(bi)])
		links.sort_custom(func(a, c): return int(a[0]) < int(c[0]))     # parents before children

	func _process(_dt: float) -> void:
		for l in links:
			var now := WardenGlb.model_xf(root, l[1])
			skel.set_bone_global_pose(int(l[0]), now * (l[2] as Transform3D) * (l[3] as Transform3D))
