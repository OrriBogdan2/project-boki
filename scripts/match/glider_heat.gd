class_name GliderHeat
extends RefCounted
## A glider's heat on the canopy itself, so teammates and enemies read it from the world (the HUD ring is only
## for you): the cloth warms toward ember as heat climbs, an overheated glider trails a thin smoke, and one that
## burns while it lifts you out of the abyss at half strength flickers. canopy_heat and canopy_burn are two
## shared toon-shader parameters on the canopy's own material: no extra draw calls.
## Nothing happens when the glider opens or closes.

const SMOKE_EVERY := 0.12      # s between smoke puffs while overheated
const SMOKE_BACK := 0.9        # m behind the canopy the puffs start
const SMOKE_UP := 2.0          # m above the feet the puffs start (the canopy's height)
const NET_LEVELS := 14         # heat steps on the wire: 0..14 (15 = overheated)

static func overheated(h: Hunter) -> bool:
	return h.gliding and not h.dropping and h.glide_fuel <= 0.001

## The glider burns while it lifts you out of the abyss at half strength.
static func burning(h: Hunter) -> bool:
	return overheated(h) and h.below_lip

## Every frame on every Hunter whose canopy is open: sets the canopy's heat and burn, and puffs smoke at overheat.
static func tick(h: Hunter, glider: Node3D, dt: float) -> void:
	var mat := (glider.get_node("Canopy") as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("canopy_heat", 1.0 - clampf(h.glide_fuel, 0.0, 1.0))
	mat.set_shader_parameter("canopy_burn", 1.0 if burning(h) else 0.0)
	var puff := int(h.m.time / SMOKE_EVERY) != int((h.m.time - dt) / SMOKE_EVERY)
	if puff and overheated(h) and h.model.visible:
		var flat := Vector3(-h.vel.x, 0.0, -h.vel.z)
		var back := flat.normalized() if flat.length() > 0.5 else Vector3.UP
		h.m.fx.smoke(h.pos + Vector3(0, SMOKE_UP, 0) + back * SMOKE_BACK, back)

## Heat on the wire, 4 bits of the hunter flags (match._flags): 0..NET_LEVELS by heat, 15 while overheated. Whether
## it burns (over the abyss) is one more bit; a remote Hunter takes its lip state from it.
static func net_level(h: Hunter) -> int:
	return 15 if h.glide_fuel <= 0.001 else int(round((1.0 - h.glide_fuel) * NET_LEVELS))

## What a received level says: the heat to show on a remote Hunter (glide_fuel).
static func fuel_of(level: int) -> float:
	return 0.0 if level >= 15 else 1.0 - float(level) / NET_LEVELS
