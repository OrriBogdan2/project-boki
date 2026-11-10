class_name ZoneScatter
extends RefCounted
## A zone's ground dressing (GARDEN.md 10.7 step 7): flat stepped terrace slabs and glowing cracks, each
## one MultiMesh (one draw call apiece, one material per theme). Purely visual: nothing blocks or is
## saved, and they only go on open ground clear of anything built. Data: garden_zones.json
## zones.<id>.scatter (seed, terraces, cracks); a zone without one gets nothing.

const TILE_CLEAR := 1              # tiles kept inside the world's edge when looking for open ground
const STEP_H := [0.07, 0.15]       # m: the lower and the upper terrace slab
const SLAB := 2.3                  # m: a lower slab's side; the upper one is 60% of it
const CRACK := Vector3(1.5, 0.03, 0.14)    # m: one crack's length, height and width
const CRACK_GLOW := 1.8            # emission energy of the cracks (they stay lit at night)

static func build(h) -> void:
	var sc: Dictionary = GardenZones.info(h.zone).get("scatter", {})
	if sc.is_empty():
		return
	var open := _open_tiles(h.world, h.hb)
	var r := RandomNumberGenerator.new()
	r.seed = int(sc["seed"])
	var theme: Dictionary = HomeLayout.THEMES[GardenZones.info(h.zone)["theme"]]
	var top := Color(String(theme["top2"])).lightened(0.3)
	var slabs: Array[Transform3D] = []
	for i in int(sc["terraces"]):
		var at: Vector2 = open[r.randi() % open.size()]
		for t in 2:
			var side := SLAB * (1.0 if t == 0 else 0.6)
			var dims := Vector3(side, STEP_H[t], side)
			slabs.append(Transform3D(Basis.from_scale(dims), Vector3(at.x, STEP_H[t] * 0.5, at.y)))
	_add(h, slabs, _material(top, 0.0), "Terraces")
	var cracks: Array[Transform3D] = []
	for i in int(sc["cracks"]):
		var at: Vector2 = open[r.randi() % open.size()]
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(CRACK)
		cracks.append(Transform3D(b, Vector3(at.x, CRACK.y * 0.5 + STEP_H[0], at.y)))
	_add(h, cracks, _material(Color("ff7a2a"), CRACK_GLOW), "Cracks")

## Tile centres (x, z) of open island-0 ground with open ground all round (no wild, build or water).
static func _open_tiles(w: World, hb: HomeBuild) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for z in range(TILE_CLEAR, w.h - TILE_CLEAR):
		for x in range(TILE_CLEAR, w.w - TILE_CLEAR):
			var clear := true
			for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				clear = clear and _free(w, hb, x + o.x, z + o.y)
			if clear:
				out.append(Vector2(x + 0.5, z + 0.5))
	return out

static func _free(w: World, hb: HomeBuild, x: int, z: int) -> bool:
	var i := w.idx(x, z)
	if w.island[i] != 0 or w.kind[i] != World.T_GROUND or w.level[i] != 0:
		return false
	return not (hb.occ.has(i) or hb.blocked.has(i) or w.paint.has(i))

static func _material(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

static func _add(h, xf: Array[Transform3D], mat: Material, node_name: String) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
