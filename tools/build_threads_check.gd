extends RefCounted
## --build-threads-check: the match build's worker-thread steps (BuildThreads) give what one pass gives. The
## expedition map's terrain traced in one band and in eight has the same vertices, chunk ranges, underside
## and rim spots, and every authored island's shape tests from the threads match a direct call.

var bad := 0

func run(main: Node) -> void:
	Save.no_write = true
	var layout := WideLayout.pick({}, false, 0)
	var world := World.new()
	main.add_child(world)
	await world.generate_authored(layout, 4101)
	var one := TerrainMesh.new(world)
	var p1: Array = await one.build_chunked(32, 1)
	var many := TerrainMesh.new(world)
	var p8: Array = await many.build_chunked(32, 8)
	_ok("terrain: %d chunks from one band, %d from eight" % [p1.size(), p8.size()], p1.size() == p8.size())
	var verts := one.V == many.V and one.N == many.N and one.C == many.C and one.UV == many.UV
	_ok("terrain: the same %d vertices, normals, colours and uvs" % one.V.size(), verts)
	_ok("terrain: the same chunk ranges, underside and rim spots",
			one._ranges == many._ranges and one.under == many.under and one.rims == many.rims)
	var defs: Array = layout.get("islands", [])
	var seed := int(layout.get("seed", 1))
	var job := func(ii: int) -> Dictionary: return GroundShapes.island(defs[ii], world.w, world.h, seed)
	var threaded: Array = await BuildThreads.start(world, job, defs.size()).wait()
	var same := 0
	for ii in defs.size():
		if GroundShapes.island(defs[ii], world.w, world.h, seed) == threaded[ii]:
			same += 1
	_ok("islands: %d of %d shape tests the same from the threads" % [same, defs.size()], same == defs.size())
	print("BUILDTHREADS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _ok(what: String, good: bool) -> void:
	print("%s %s" % ["PASS" if good else "FAIL", what])
	if not good:
		bad += 1
