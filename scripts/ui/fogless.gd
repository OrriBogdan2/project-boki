class_name Fogless
extends RefCounted
## A model shown in a UI viewport of its own world (a menu portrait, the hatch reveal, the results island) is still
## drawn by shaders that read the match's sight fog, which is global (vis_*): in a match, standing at that world's
## origin, it sat outside sight and was greyed, darkened and cooled (Vespyx a dark teal fox in the HUD, menus and
## the reveal, owner 11-19), and a portrait was cached that way. apply() gives the model its own copies of the
## materials that read the fog, with no_fog on; the kin and Hunters in the match keep theirs.

static var _fog_shaders := {}  # shader -> it has a no_fog uniform


## Once `root` is ready (a rigged Boki dresses its coat in _ready), its fog-reading materials become fogless copies.
static func apply(root: Node) -> void:
	if not root.is_node_ready():
		root.ready.connect(func() -> void: apply(root), CONNECT_ONE_SHOT)
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override:  # a primitive part (Models.part) wears one for every surface
			var o := _unfogged(mi.material_override)
			if o:
				mi.material_override = o
			continue
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var m := _unfogged(mi.get_active_material(si))
			if m:
				mi.set_surface_override_material(si, m)


## A copy of `m` (and its next passes) with no_fog on, or null when nothing in it reads the fog.
static func _unfogged(m: Material) -> Material:
	if not m is ShaderMaterial:
		return null
	var sm := m as ShaderMaterial
	var nxt := _unfogged(sm.next_pass)
	var fog := sm.shader != null and _reads_fog(sm.shader)
	if not fog and nxt == null:
		return null
	var c := sm.duplicate() as ShaderMaterial
	if fog:
		c.set_shader_parameter("no_fog", true)
	if nxt:
		c.next_pass = nxt
	return c


static func _reads_fog(sh: Shader) -> bool:
	if not _fog_shaders.has(sh):
		_fog_shaders[sh] = sh.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u["name"] == "no_fog")
	return _fog_shaders[sh]
