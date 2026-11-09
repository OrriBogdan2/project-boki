extends RefCounted
## --edge-read-check: what the terrain shader's edge cues rely on (shaders/terrain.gdshader, void_at). The
## height texture is 0 over the abyss and above 0 over every ground tile (so a cold abyss rim never lands on a
## terrace lip), and the Hollow Crown has both kinds of edge: ground beside the abyss and ground above lower ground.

const MIN_EDGES := 20     # tiles of each kind a map worth the cues has
const TerrainMesh := preload("res://scripts/match/terrain_mesh.gd")
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("EDGEREAD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	var w := m.world
	var tm = TerrainMesh.new(w)
	tm._fill_grid()
	var img: Image = tm.height_texture().get_image()
	var wrong := 0
	var abyss_edges := 0
	var lips := 0
	for z in w.h:
		for x in w.w:
			var r: float = img.get_pixel(x, z).r
			var is_void: bool = w.kind[w.idx(x, z)] == World.T_VOID
			if (r == 0.0) != is_void and not w.bridge.has(w.idx(x, z)): wrong += 1
			if is_void or w.kind[w.idx(x, z)] != World.T_GROUND: continue
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if not w.inb(x + d.x, z + d.y): continue
				var j: int = w.idx(x + d.x, z + d.y)
				if w.kind[j] == World.T_VOID: abyss_edges += 1
				elif w.kind[j] == World.T_GROUND and w.level[w.idx(x, z)] > w.level[j]: lips += 1
	ok(wrong == 0, "height texture is 0 exactly over the abyss (%d tiles disagree)" % wrong)
	ok(abyss_edges >= MIN_EDGES, "%d ground tiles beside the abyss" % abyss_edges)
	ok(lips >= MIN_EDGES, "%d terrace lip tiles over lower ground" % lips)
	print("EDGEREAD_CHECK %s" % ("FAILED %d" % bad if bad > 0 else "PASSED"))
	main.get_tree().quit(1 if bad > 0 else 0)
