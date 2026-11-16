class_name LookProps
extends RefCounted
## Meshy-made props for making yourself (art/look/<name>.glb: the creator's dais and the shroud's satchel and
## lantern), drawn with our toon shader and outline so they light like the procedural body they sit on. The dais
## carries its painted texture; the worn props carry their paint in vertex colours, divided by the leather's colour
## (tools: Blender cleanup), so they are drawn with the Empty's own leather and add nothing to its 8-material budget.
## Loaded once and shared by every model that wears them.

const DIR := "res://art/look/%s.glb"
## The node name a worn prop carries: EmptySlim leaves it whole (it is already cut to its budget in Blender).
const NODE := "LookProp"

static var _meshes := {}
static var _mats := {}


## The prop's mesh, in its own space (the dais and the lantern hang from their top, the satchel from its centre).
static func mesh(prop: String) -> Mesh:
	if not _meshes.has(prop):
		_load(prop)
	return _meshes[prop]


## A textured prop's painted toon material (the dais).
static func mat(prop: String) -> Material:
	if not _mats.has(prop):
		var m := Models.toon(Color.WHITE)
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("albedo_tex", (mesh(prop).surface_get_material(0) as BaseMaterial3D).albedo_texture)
		_mats[prop] = m
	return _mats[prop]


## Puts a vertex-painted prop on a joint of the rig, like ShroudTailor.rigid, under the name EmptySlim skips; `m` is
## a material the body already wears (its vertex_ao multiplies the paint in).
static func wear(parent: Node3D, prop: String, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(parent, mesh(prop), m, pos, Vector3.ONE, rot, NODE)


static func _load(prop: String) -> void:
	var root := (load(DIR % prop) as PackedScene).instantiate()
	_meshes[prop] = (root.find_children("*", "MeshInstance3D")[0] as MeshInstance3D).mesh
	root.free()
