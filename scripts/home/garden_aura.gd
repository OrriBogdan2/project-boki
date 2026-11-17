class_name GardenAura
extends CPUParticles3D
## The aura a Boki wears (rec.aura, a garden item with an "aura" block in content/rules/garden_items.json,
## GARDEN_MODERN.md section 1 looks): soft motes round the model. Looks only. night_only ones glow when the
## scene's day clock (a "day_t" on the current scene, Home) is in the night; elsewhere they always glow.
## lean ones take the Boki's lean colour (a trail of it); chime ones sit still until chime() puffs them.
## One particle set a Boki, and none at Low quality or below.

const NO_LEAN := "#d8e8f4"      # the trail's colour before a Boki has any lean

var night_only := false
var chimes := false             # sits still until chime() puffs it
var _t := 0.0

## Adds (or swaps) the aura on a model built by Models.kin. No aura, no node.
static func dress(root: Node3D, rec: Dictionary) -> void:
	var old: Node = root.get_node_or_null("GardenAura")
	if old:
		old.free()
	var id := String(rec.get("aura", ""))
	var a: Dictionary = GardenItems.item(id).get("aura", {}) if id != "" else {}
	if a.is_empty() or Settings.lite():
		return
	var pt := GardenAura.new()
	pt.name = "GardenAura"
	pt.night_only = bool(a.get("night_only", false))
	pt.amount = int(a.get("amount", 6))
	pt.lifetime = float(a.get("life", 2.5))
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = float(a.get("radius", 0.5))
	pt.position = Vector3(0, float(a.get("y", 0.45)), 0)
	pt.mesh = Models.sphere(float(a.get("size", 0.03)), 4)
	pt.color = Color(String(a.get("colour", "#ffffff")))
	if bool(a.get("lean", false)):
		var key := String(Evo.lean(rec)[0])
		pt.color = Lean.face(key)["tint"] if key != "" else Color(NO_LEAN)
	if bool(a.get("chime", false)):
		pt.chimes = true
		pt.one_shot = true
		pt.explosiveness = 1.0
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
	pt.emitting = not pt.night_only and not pt.chimes
	root.add_child(pt)

## Puffs a chime aura's notes (once; a Boki that wears none does nothing).
static func chime(root: Node3D) -> void:
	var pt := root.get_node_or_null("GardenAura") as GardenAura
	if pt and pt.chimes:
		pt.restart()
		pt.emitting = true

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
