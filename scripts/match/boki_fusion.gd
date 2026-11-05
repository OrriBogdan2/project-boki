class_name BokiFusion
extends RefCounted
## A Fusion's silhouette from the Boki's own Blender parts (art/kin/<species>/<species>_fusion.glb), in place of
## MergeParts' primitives: they ride the torso like any other parts. Forms without a model keep MergeParts.

const PATH := "res://art/kin/%s/%s_fusion.glb"
## Fusion type -> the species whose parts it wears.
const HIP_Y := 0.42        # m: the torso height the parts are modelled for; 3D Hunters carry theirs higher
const SPECIES := {"venom": "cindle"}

## True when this form has Blender parts.
static func has(form: Dictionary) -> bool:
	var id := String(SPECIES.get(String(form.get("type", "")), ""))
	return id != "" and ResourceLoader.exists(PATH % [id, id])

## Adds the parts under `parent` at `base`, in the form's glow, and keeps them moving on their own.
static func build(parent: Node3D, form: Dictionary, base: Vector3) -> void:
	var id := String(SPECIES[String(form["type"])])
	var parts := (load(PATH % [id, id]) as PackedScene).instantiate() as Node3D
	parts.name = "FusionParts"
	parent.add_child(parts)
	var torso := parent.get_parent() as Node3D
	parts.scale = Vector3.ONE / parent.scale.x          # a Fusion's own sizes: part_k is for the primitive parts
	parts.position = base + Vector3(0, (HIP_Y - torso.position.y) / parent.scale.x, 0)
	var glow: Color = form["glow"]
	for mi in parts.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for si in inst.mesh.get_surface_count():
			inst.set_surface_override_material(si, _material(inst.mesh.surface_get_material(si), glow))
	var player := parts.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	player.play("idle")

static func _material(src: Material, glow: Color) -> Material:
	if String(src.resource_name) == "boki_glow":
		return Models.toon(glow, false, 0.9)
	var m := Models.toon(Color.WHITE, false)
	Models.hero_look(m)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
	for k in WardenGlb.PAINTED:
		m.set_shader_parameter(k, WardenGlb.PAINTED[k])
	for k in BokiRig.COAT_LOOK:
		m.set_shader_parameter(k, BokiRig.COAT_LOOK[k])
	m.next_pass = BokiRig._ink()
	return m
