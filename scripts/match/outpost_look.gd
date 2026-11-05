class_name OutpostLook
extends RefCounted
## What an outpost's uplink looks like in each state, shown by the object itself (ExitModels.uplink):
## neutral and unlit; charging, where the crystal and the four pylon lamps fill with the charge and the
## banner climbs the mast in the holder's team colour; open, everything lit. The yard's edge (Zone) and
## the charge ring show only while they matter: you stand in the yard, or it is contested. No particles,
## no column while charging, and the only motion is the banner stirring and the crystal turning slowly.

const NEUTRAL := Color("7d8494")        # stone grey: an uplink nobody holds, or one gone dark
const BANNER_LOW := 2.2                 # m up the mast: the banner when nobody holds it
const BANNER_HIGH := 3.3                # m: ... when a team holds it
const SWAY_RAD := 0.12                  # rad, how far the banner stirs
const SWAY_RATE := 1.7                  # rad/s of the stir
const CRYSTAL_GLOW := 1.3               # shader glow of a fully charged crystal
const LAMP_GLOW := 0.9                  # shader glow of a lit pylon lamp

## 0..1 how lit the beacon is for this exit, and whether a team holds it (banner raised).
static func lit_of(x: Dictionary) -> float:
	match String(x["state"]):
		"charging": return float(x["prog"])
		"open": return 1.0
	return 0.0

static func held(x: Dictionary) -> bool:
	return String(x["state"]) in ["charging", "open", "fizzling"] and int(x["team"]) >= 0

## Sets the node's crystal, lamps, banner and screen for `lit` (0..1), the holder's colour `col` and `raise` (0..1).
## (Callers apply it when one of those changes, not every frame.)
static func apply(n: Node3D, lit: float, col: Color, raise: float) -> void:
	var cm := _mat(n.get_node("Mast/Crystal").get_child(0))
	cm.set_shader_parameter("glow", CRYSTAL_GLOW * lit)
	cm.set_shader_parameter("albedo", NEUTRAL.lerp(col, clampf(lit * 2.0, 0.0, 1.0)))
	for i in 4:
		var f := clampf(lit * 4.0 - float(i), 0.0, 1.0)
		var lm := _mat(n.get_node("Lamp%d" % i))
		lm.set_shader_parameter("albedo", NEUTRAL.lerp(col, f))
		lm.set_shader_parameter("glow", LAMP_GLOW * f)
	var flag := n.get_node("Mast/Banner") as Node3D
	flag.position.y = lerpf(BANNER_LOW, BANNER_HIGH, raise)
	_mat(flag.get_node("Cloth")).set_shader_parameter("albedo", NEUTRAL.lerp(col, raise))
	_mat(n.get_node("Screen")).set_shader_parameter("albedo", col if lit > 0.001 else NEUTRAL)

## The banner stirring on a held outpost (per frame, one rotation).
static func sway(n: Node3D, t: float) -> void:
	(n.get_node("Mast/Banner") as Node3D).rotation.y = sin(t * SWAY_RATE) * SWAY_RAD

## The yard's edge (and the charge ring on it): shown while `visible_ring`, coloured for a contest.
static func rings(n: Node3D, visible_ring: bool, contested: bool, charging: bool, prog: float) -> void:
	var zone := n.get_node("Zone") as MeshInstance3D
	var charge := n.get_node("Charge") as MeshInstance3D
	if zone.visible != visible_ring:
		zone.visible = visible_ring
	var show_charge := visible_ring and charging
	if charge.visible != show_charge:
		charge.visible = show_charge
	if visible_ring:
		var edge := Color("ff7a5a") if contested else ExitModels.UPLINK
		(zone.material_override as ShaderMaterial).set_shader_parameter("color", Color(edge, 0.3))
		(charge.material_override as ShaderMaterial).set_shader_parameter("arc", prog)

static func _mat(mi: Node) -> ShaderMaterial:
	return (mi as MeshInstance3D).material_override as ShaderMaterial
