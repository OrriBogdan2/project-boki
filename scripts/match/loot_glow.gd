class_name LootGlow
extends RefCounted
## What rarity looks like on loot lying in the world: every drop gets a soft halo in its rarity
## colour (Data.RARITY), and Fine/Rare and up add a short light pillar that reads from across a
## fight. Meshes and materials are built once per tier and shared by every drop, and nothing here
## is a particle, so a pile-up costs two draws per item and none of the VFX particle budget. No flat
## ring: rings on the ground belong to gameplay (aim lanes, owner rings, discs).

## Per rarity tier (the Data.RARITY order): halo radius (m) and alpha, pillar height (m) and alpha.
## No pillar (height 0) for the two lowest tiers; from Rare up the pillar grows with the tier.
const LOOKS := [
	{"halo_r": 0.7, "halo_a": 0.2, "pillar_h": 0.0, "pillar_a": 0.0},
	{"halo_r": 0.75, "halo_a": 0.26, "pillar_h": 0.0, "pillar_a": 0.0},
	{"halo_r": 0.85, "halo_a": 0.32, "pillar_h": 2.6, "pillar_a": 0.34},
	{"halo_r": 0.95, "halo_a": 0.38, "pillar_h": 3.2, "pillar_a": 0.42},
	{"halo_r": 1.05, "halo_a": 0.44, "pillar_h": 3.8, "pillar_a": 0.5},
]
const HALO_Y := 0.7            # m above the ground: the height the token spins at
const PILLAR_R := Vector2(0.1, 0.18)    # m: top and bottom radius of a pillar
const SEGMENTS := 10

static var _shared := {}       # tier -> {halo, halo_mat, pillar, pillar_mat}

static func tier(rar: int) -> int:
	return clampi(rar, 0, LOOKS.size() - 1)

## Adds the halo (and, for Rare and up, the pillar) for a rarity tier under a drop.
static func attach(root: Node3D, rar: int) -> void:
	var r := tier(rar)
	var look: Dictionary = LOOKS[r]
	var res := _res(r)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = res["halo"]
	halo.material_override = res["halo_mat"]
	halo.position.y = HALO_Y
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	if float(look["pillar_h"]) <= 0.0:
		return
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	pillar.mesh = res["pillar"]
	pillar.material_override = res["pillar_mat"]
	pillar.position.y = float(look["pillar_h"]) * 0.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pillar)

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
		res["pillar_mat"] = Models.glow_mat(Color(col, float(look["pillar_a"])))
	_shared[r] = res
	return res
