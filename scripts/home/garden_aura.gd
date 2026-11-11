class_name GardenAura
extends CPUParticles3D
## The aura a Boki wears (rec.aura, a garden item with an "aura" block in content/rules/garden_items.json,
## GARDEN_MODERN.md section 1 looks): soft motes round the model. Looks only. night_only ones glow when the
## scene's day clock (a "day_t" on the current scene, Home) is in the night; elsewhere they always glow.

var night_only := false
var _t := 0.0

## Adds (or swaps) the aura on a model built by Models.kin. No aura, no node.
static func dress(root: Node3D, rec: Dictionary) -> void:
	var old: Node = root.get_node_or_null("GardenAura")
	if old:
		old.free()
	var id := String(rec.get("aura", ""))
	var a: Dictionary = GardenItems.item(id).get("aura", {}) if id != "" else {}
	if a.is_empty():
		return
	var pt := GardenAura.new()
	pt.name = "GardenAura"
	pt.night_only = bool(a.get("night_only", false))
	pt.amount = int(a.get("amount", 6))
	pt.lifetime = float(a.get("life", 2.5))
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 0.5
	pt.position = Vector3(0, 0.45, 0)
	pt.mesh = Models.sphere(float(a.get("size", 0.03)), 4)
	pt.color = Color(String(a.get("colour", "#ffffff")))
	pt.local_coords = false
	pt.direction = Vector3.UP
	pt.spread = 180.0
	pt.initial_velocity_min = 0.03
	pt.initial_velocity_max = 0.12
	pt.gravity = Vector3(0, float(a.get("rise", 0.1)), 0)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pt.material_override = pm
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.emitting = not pt.night_only
	root.add_child(pt)

## Should it glow now? Night on a scene with a day clock; always without one.
static func lit(scene: Node, night_only_: bool) -> bool:
	if not night_only_ or scene == null or not ("day_t" in scene):
		return true
	return HomeWork.is_night(float(scene.get("day_t")))

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	emitting = GardenAura.lit(get_tree().current_scene if is_inside_tree() else null, night_only)
