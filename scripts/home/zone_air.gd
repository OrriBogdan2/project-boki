class_name ZoneAir
extends RefCounted
## The air of a garden zone: one cheap ambient layer that tells you where the Waystone put you (pollen in
## Bramblebank, glints in Glasswater, embers in Cinderstep, fireflies in Hushwood, wind streaks on Kitewind
## Ridge). One GPUParticles3D over the island with a small fixed count, unshaded, no light and no burst; numbers
## in content/rules/zone_air.json. Off at the lowest quality preset, the count scaled by Settings fx above it.

const NAME := "ZoneAir"
const PREWARM_MAX_S := 3.0     # s of motion run on arrival so the air is already full, capped to keep the load light

static func rules() -> Dictionary:
	return Content.rules("zone_air")

## The layer for the zone the open garden shows, or {} (no base_mode, the hub, or a zone without one).
static func layer() -> Dictionary:
	if not FarmUnlocks.base_mode() or GardenZones.here == GardenZones.HUB:
		return {}
	return rules()["zones"].get(GardenZones.current(), {})

## How many motes the layer gets at the quality in effect (0 is none).
static func count(spec: Dictionary) -> int:
	if Settings.quality() == String(rules()["off_at"]):
		return 0
	return maxi(1, roundi(float(spec["count"]) * float(Settings.q("fx"))))

## Adds the zone's layer to Home `h` (once, from its build). Returns the node, or null when there is none.
static func add(h: Node3D) -> GPUParticles3D:
	var spec := layer()
	var n := 0 if spec.is_empty() else count(spec)
	if n == 0:
		return null
	var p := _emitter(spec, n)
	p.position = HomeLayout.LANDING + Vector3(0, float(spec["y"]), 0)
	h.add_child(p)
	return p

static func _emitter(spec: Dictionary, n: int) -> GPUParticles3D:
	var box := Vector3(rules()["box"][0], rules()["box"][1], rules()["box"][2])
	var vel := Vector3(spec["vel"][0], spec["vel"][1], spec["vel"][2])
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = vel.normalized() if vel != Vector3.ZERO else Vector3.UP
	pm.spread = float(spec["spread"])
	pm.initial_velocity_min = vel.length() * 0.7
	pm.initial_velocity_max = vel.length() * 1.3
	pm.gravity = Vector3(0, float(spec["grav"]), 0)
	pm.color_ramp = _fade(float(spec["fade"]))
	var p := GPUParticles3D.new()
	p.name = NAME
	p.amount = n
	p.lifetime = float(spec["life"])
	p.preprocess = minf(p.lifetime, PREWARM_MAX_S)
	p.randomness = 0.5
	p.process_material = pm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := box + vel.abs() * p.lifetime + Vector3.ONE
	p.visibility_aabb = AABB(-reach, reach * 2.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(spec["size"][0], spec["size"][1])
	quad.material = _look(Color(String(spec["col"])))
	p.draw_pass_1 = quad
	return p

## Alpha 0 -> 1 over the first `share` of a mote's life and back to 0 over the last.
static func _fade(share: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, share, 1.0 - share, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

## Unshaded, see-through, facing the camera, tinted by the fade ramp.
static func _look(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	return m
