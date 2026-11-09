class_name BoxBeam
extends RefCounted
## What a deathbox shows from across a fight: a thin beam in the rarity colour of the best item left
## in it (Data.RARITY, the colours ground loot uses), taller for better things, and a team-coloured
## ground rim. An emptied box switches the beam off and dims its rim. One shared mesh and material per
## tier, no lights, no particles, so it reads on every quality preset.

const RADIUS_M := Vector2(0.07, 0.11)     # top and bottom radius of the beam
const HEIGHT_M := [3.0, 3.6, 4.4, 5.2, 6.4]     # beam height by rarity tier (Common .. Legendary)
const BEAM_A := 0.7                       # beam alpha (additive glow, so this is brightness)
const RIM_A := 1.0                        # the owner rim's alpha with something left to take
const RIM_DIM_A := 0.3                    # ...and once the box is empty

static var _shared := {}                  # tier -> {mesh, mat}

## The rarity tier of the best thing in a box (Common when it only holds gems, seeds, kin or a belt).
static func best_tier(b: Dictionary) -> int:
	var best := 0
	for c in Pack._box_things(b):
		best = maxi(best, Loot.rar_of(c["it"]))
	return best

static func beam_of(b: Dictionary) -> MeshInstance3D:
	var n: Node3D = b["node"]
	return n.get_node_or_null("Beam") as MeshInstance3D if n != null else null

## Makes the beam on a fresh box, or re-reads the box after something was taken.
static func refresh(b: Dictionary) -> void:
	var n: Node3D = b["node"]
	if n == null:
		return
	var empty: bool = b["empty"]
	var beam := beam_of(b)
	if beam == null:
		beam = MeshInstance3D.new()
		beam.name = "Beam"
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(beam)
	var tier := best_tier(b)
	var res := _res(tier)
	beam.mesh = res["mesh"]
	beam.material_override = res["mat"]
	beam.position.y = float(HEIGHT_M[tier]) * 0.5
	beam.visible = not empty
	var rim := n.get_node_or_null("OwnerRing") as MeshInstance3D
	if rim != null:
		var col: Color = n.get_meta("owner_col", Color.WHITE)
		var rim_mat := rim.material_override as ShaderMaterial
		rim_mat.set_shader_parameter("color", Color(col, RIM_DIM_A if empty else RIM_A))

static func _res(tier: int) -> Dictionary:
	if not _shared.has(tier):
		var mesh := CylinderMesh.new()
		mesh.top_radius = RADIUS_M.x
		mesh.bottom_radius = RADIUS_M.y
		mesh.height = float(HEIGHT_M[tier])
		mesh.radial_segments = 8
		mesh.rings = 1
		var col: Color = Data.RARITY[tier]["color"]
		_shared[tier] = {"mesh": mesh, "mat": Models.glow_mat(Color(col, BEAM_A))}
	return _shared[tier]
