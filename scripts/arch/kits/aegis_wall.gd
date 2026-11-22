class_name AegisWall
extends Node3D
## Albert's raised aegis as it is drawn (BjornFx.aegis_*; the verbs wall underneath keeps the blocking): a
## translucent gold wall in four layers, one mesh each: the outer sheet with seams and the hammer cross, a brighter
## inner sheet, the lit rim along the top and a soft contact on the ground (shaders/aegis_wall.gdshader). Local space:
## the curve's centre at the origin, the apex straight ahead (-Z). Four draw calls (VFX_QUALITY row 8).

## the wall: radius (m), half its arc (rad), height (m) and how far its top leans out (m); its chord is about 4.2 m
const R := 2.6
const HALF := 0.92
const H := 1.7
const LEAN := 1.2
## the inner sheet: how far inside the outer one (m) and its height as a share of it
const INNER_GAP := 0.14
const INNER_H := 0.82
## the rim bar's depth (m) either side of the wall's top edge, and the ground contact's reach (m) behind and in front
const RIM_IN := 0.2
const RIM_OUT := 0.3
const GROUND_BACK := 0.35
const GROUND_FRONT := 0.7
## gold of the plates and his ivory (content/vfx/bulwark.json slab, ivory), the tint a broken wall fades to
const SLAB := Color("f6e3a8")
const IVORY := Color("fff0b0")
const BROKEN := Color("4a3a30")
## the shader's own light at rest, and the pulse an armed (full Guard) wall adds
const REST_GLOW := 0.3
const SEGMENTS := 28

var mats: Array = []
var slab := SLAB
var ivory := IVORY


func _init() -> void:
	var pal: Dictionary = HeroVfx.data("bulwark").get("palette", {})
	slab = Color(String(pal.get("slab", SLAB.to_html(false))))
	ivory = Color(String(pal.get("ivory", IVORY.to_html(false))))
	var arc := 2.0 * HALF * R
	_layer(KitMeshes.wall(R, -HALF, HALF, H, SEGMENTS, LEAN), 0, arc)
	_layer(KitMeshes.wall(R - INNER_GAP, -HALF, HALF, H * INNER_H, SEGMENTS, LEAN * INNER_H), 1, arc)
	var rim := _layer(KitMeshes.band(R + LEAN - RIM_IN, R + LEAN + RIM_OUT, -HALF, HALF, SEGMENTS), 2, arc)
	rim.position.y = H + 0.04
	var ground := _layer(KitMeshes.band(R - GROUND_BACK, R + GROUND_FRONT, -HALF, HALF, SEGMENTS), 3, arc)
	ground.position.y = 0.03


func _layer(mesh: Mesh, kind: int, arc: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/aegis_wall.gdshader")
	mat.set_shader_parameter("kind", float(kind))
	mat.set_shader_parameter("arc_m", arc)
	mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## `hurt` 0..1 (the wall's HP lost) fades the gold to a dull brown, `glow` is the shader's light (REST_GLOW, a block's
## flash and an armed pulse on top).
func set_state(hurt: float, glow: float) -> void:
	for mat: ShaderMaterial in mats:
		mat.set_shader_parameter("albedo", slab.lerp(BROKEN, hurt * 0.65))
		mat.set_shader_parameter("rim_color", ivory.lerp(BROKEN, hurt * 0.65))
		mat.set_shader_parameter("glow", glow)
