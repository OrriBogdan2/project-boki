class_name LootGlow
extends RefCounted
## What rarity looks like on loot lying in the world: every drop gets a soft halo in its rarity
## colour (Data.RARITY), and Rare and up add a short light pillar (shaders/loot_pillar.gdshader) that
## reads from across a fight. Meshes and materials are built once per tier and shared by every drop,
## and nothing here is a particle, so a pile-up costs two draws per item and none of the VFX particle
## budget. No flat ring: rings on the ground belong to gameplay (aim lanes, owner rings, discs).

## Per rarity tier (the Data.RARITY order): halo radius (m) and alpha, pillar height (m) and alpha.
## No pillar (height 0) below Epic; Epic and Legendary get one that grows with the tier.
const LOOKS := [
	{"halo_r": 0.7, "halo_a": 0.3, "pillar_h": 0.0, "pillar_a": 0.0},
	{"halo_r": 0.75, "halo_a": 0.36, "pillar_h": 0.0, "pillar_a": 0.0},
	{"halo_r": 0.85, "halo_a": 0.42, "pillar_h": 0.0, "pillar_a": 0.0},
	{"halo_r": 0.95, "halo_a": 0.48, "pillar_h": 3.2, "pillar_a": 0.55},
	{"halo_r": 1.05, "halo_a": 0.55, "pillar_h": 3.8, "pillar_a": 0.65},
]
const HALO_Y := 0.7            # m above the ground: the height the token spins at
const PILLAR_SHADER := preload("res://shaders/loot_pillar.gdshader")
const PILLAR_R := Vector2(0.2, 0.42)    # m: top and bottom radius of a pillar
const SEGMENTS := 10
const HALO_RANGE := 50.0       # m at draw scale 1: past this a halo is not drawn (it is a close-up cue)
const PILLAR_RANGE := 140.0    # m at draw scale 1: the pillar is the far read, so it is culled much later
const COMMON_MIN_FX := 0.5     # Settings.q("fx") below this (Low) drops the Common halo altogether

static var _shared := {}       # tier -> {halo, halo_mat, pillar, pillar_mat}

static func tier(rar: int) -> int:
	return clampi(rar, 0, LOOKS.size() - 1)

## Adds the halo (and, for Epic and up, the pillar) for a rarity tier under a drop, with the culling
## ranges the current preset allows.
static func attach(root: Node3D, rar: int) -> void:
	var r := tier(rar)
	var look: Dictionary = LOOKS[r]
	var res := _res(r)
	var draw := float(Settings.q("draw"))
	if r > 0 or float(Settings.q("fx")) >= COMMON_MIN_FX:
		_add(root, "Halo", res["halo"], res["halo_mat"], HALO_Y, HALO_RANGE * draw)
	if float(look["pillar_h"]) > 0.0:
		_add(root, "Pillar", res["pillar"], res["pillar_mat"], float(look["pillar_h"]) * 0.5, PILLAR_RANGE * draw)

static func _add(root: Node3D, nm: String, mesh: Mesh, mat: Material, y: float, range_end: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = range_end
	root.add_child(mi)

## A hidden Legendary drop under the match, so the warm-up compiles the halo and pillar shaders
## before the first Epic drop lands mid-fight.
static func stand_in(parent: Node3D) -> void:
	var hidden := Node3D.new()
	hidden.name = "LootGlowStandIn"
	hidden.visible = false
	attach(hidden, LOOKS.size() - 1)
	parent.add_child(hidden)

static func _res(r: int) -> Dictionary:
	if _shared.has(r):
		return _shared[r]
	var look: Dictionary = LOOKS[r]
	var col: Color = Data.RARITY[r]["color"]
	var halo := SphereMesh.new()
	halo.radius = float(look["halo_r"])
	halo.height = halo.radius * 2.0
	halo.radial_segments = SEGMENTS
	halo.rings = SEGMENTS / 2
	var res := {"halo": halo, "halo_mat": Models.glow_mat(Color(col, float(look["halo_a"])))}
	if float(look["pillar_h"]) > 0.0:
		var pillar := CylinderMesh.new()
		pillar.top_radius = PILLAR_R.x
		pillar.bottom_radius = PILLAR_R.y
		pillar.height = float(look["pillar_h"])
		pillar.radial_segments = SEGMENTS
		pillar.rings = 1
		res["pillar"] = pillar
		var mat := ShaderMaterial.new()
		mat.shader = PILLAR_SHADER
		mat.set_shader_parameter("color", Color(col, float(look["pillar_a"])))
		mat.set_shader_parameter("height", float(look["pillar_h"]))
		res["pillar_mat"] = mat
	_shared[r] = res
	return res
