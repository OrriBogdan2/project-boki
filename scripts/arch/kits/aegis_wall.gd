class_name AegisWall
extends Node3D
## Albert's raised aegis as it is drawn (BjornFx.aegis_*; the verbs wall underneath keeps the blocking): his wooden
## figurehead shield grown into a curved wall, in four layers, one mesh each: the planked face with the carved panel,
## iron frame and the sea light between the planks, the boards' darker back a hand inside it (the shield's
## thickness), the iron rim along the top and a soft contact on the ground (shaders/aegis_wall.gdshader). Local
## space: the curve's centre at the origin, the apex straight ahead (-Z). Four draw calls (VFX_QUALITY row 8).

## the wall: radius (m), half its arc (rad), height (m) and how far its top leans out (m); its chord is about 4.2 m
const R := 2.6
const HALF := 0.92
const H := 1.7
const LEAN := 1.2
## the boards' back: how far inside the face (m) and its height as a share of it
const BACK_GAP := 0.12
const BACK_H := 0.96
## the rim bar's depth (m) either side of the wall's top edge, and the ground contact's reach (m) behind and in front
const RIM_IN := 0.2
const RIM_OUT := 0.3
const GROUND_BACK := 0.35
const GROUND_FRONT := 0.7
## his planks, iron and sea light (content/vfx/bulwark.json wood, band, sea), the tint a broken wall fades to
const WOOD := Color("7a4f33")
const BAND := Color("706b65")
const SEA := Color("1fe0cc")
const BROKEN := Color("2e2620")
## the shader's own light at rest (a block flashes over it)
const REST_GLOW := 0.3
const SEGMENTS := 28

var mats: Array = []
var wood := WOOD
var band := BAND


func _init() -> void:
	var pal: Dictionary = HeroVfx.data("bulwark").get("palette", {})
	wood = Color(String(pal.get("wood", WOOD.to_html(false))))
	band = Color(String(pal.get("band", BAND.to_html(false))))
	var arc := 2.0 * HALF * R
	_layer(KitMeshes.wall(R, -HALF, HALF, H, SEGMENTS, LEAN), 0, arc)
	_layer(KitMeshes.wall(R - BACK_GAP, -HALF, HALF, H * BACK_H, SEGMENTS, LEAN * BACK_H), 1, arc)
	var rim := _layer(KitMeshes.band(R + LEAN - RIM_IN, R + LEAN + RIM_OUT, -HALF, HALF, SEGMENTS), 2, arc)
	rim.position.y = H + 0.04
	var ground := _layer(KitMeshes.band(R - GROUND_BACK, R + GROUND_FRONT, -HALF, HALF, SEGMENTS), 3, arc)
	ground.position.y = 0.03


func _layer(mesh: Mesh, kind: int, arc: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/aegis_wall.gdshader")
	mat.set_shader_parameter("kind", float(kind))
	mat.set_shader_parameter("arc_m", arc)
	mat.set_shader_parameter("height_m", Vector2(LEAN, H).length())
	mat.set_shader_parameter("sea", SEA)
	mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## `hurt` 0..1 (the wall's HP lost) darkens the wood and iron toward charred, `glow` is the shader's light (REST_GLOW
## and a block's flash on top).
func set_state(hurt: float, glow: float) -> void:
	for mat: ShaderMaterial in mats:
		mat.set_shader_parameter("albedo", wood.lerp(BROKEN, hurt * 0.65))
		mat.set_shader_parameter("rim_color", band.lerp(BROKEN, hurt * 0.65))
		mat.set_shader_parameter("glow", glow)
