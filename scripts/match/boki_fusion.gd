class_name BokiFusion
extends RefCounted
## A Fusion's silhouette from the Boki's own Blender parts (art/kin/<species>/<species>_fusion.glb), in place of
## MergeParts' primitives: they ride the torso like any other parts. Forms without a model keep MergeParts.

const PATH := "res://art/kin/%s/%s_fusion.glb"
const HIP_Y := 0.54        # m: the torso height the parts are modelled for; 3D Hunters carry theirs higher
## A kit form's id, or a fallback form's type -> the species whose parts it wears.
const SPECIES := {"venom": "cindle", "tidal_shell": "puddlet", "spore": "burrlet", "stormwing": "zephyrak",
	"lunar": "wisplet"}

## The form key of a species, for tools ("" when it has no Fusion parts).
static func key_of(kin_id: String) -> String:
	var key: Variant = SPECIES.find_key(kin_id)
	return "" if key == null else String(key)

static func _key(form: Dictionary) -> String:
	return String(form["id"]) if form.get("kit", false) else String(form.get("type", ""))

## True when this form has Blender parts.
static func has(form: Dictionary) -> bool:
	var id := String(SPECIES.get(_key(form), ""))
	return id != "" and ResourceLoader.exists(PATH % [id, id])

## Adds the parts under `parent` at `base`, in the form's glow, and keeps them moving on their own.
static func build(parent: Node3D, form: Dictionary, base: Vector3) -> void:
	var id := String(SPECIES[_key(form)])
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
	if String(src.resource_name) == "boki_lit":
		var lit := Models.toon(Color.WHITE, false, 0.55)
		lit.set_shader_parameter("use_tex", true)
		lit.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
		return lit
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
