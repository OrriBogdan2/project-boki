class_name VoidCard
extends RefCounted
## The card Motley flicks (item 136, RMB flurry): void violet with a teal rim. VoidCard.make() is a mesh for the kit's
## projectile: its long edge lies along -Z, flat, so a flying card shows its face to the match camera. Unshaded, so it
## reads on any ground.

const TEX := "res://art/wardens/ostra/void_card.png"
const SIZE := Vector2(0.11, 0.16)   # m: as the fan's cards, one glove-length tall (ostra_FINAL_sheet)
const FLIGHT_K := 1.8               # in flight, for the match camera
static var _mat: StandardMaterial3D

static func make(k := FLIGHT_K) -> MeshInstance3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.albedo_texture = load(TEX) as Texture2D
	var q := PlaneMesh.new()
	q.size = SIZE * k
	var mi := MeshInstance3D.new()
	mi.name = "VoidCard"
	mi.mesh = q
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
