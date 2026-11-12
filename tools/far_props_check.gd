extends RefCounted
## --far-props-check: the far-off floating rocks and trees around the map are MultiMeshes
## (one per shape), not one node each. Builds a big map's meshes and counts them.
## Prints "FPCHECK ok|FAIL ..." lines and "FPCHECK DONE, failures: N".

var bad := 0

func ok(cond: bool, msg: String) -> void:
	print("FPCHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var w := World.new()
	main.add_child(w)
	w.generate(5, World.BIG_SIZE, World.BIG_ISLANDS)
	await w.build_meshes()
	var far := 0
	var instances := 0
	for c in w.find_children("Far_*", "MultiMeshInstance3D", true, false):
		far += 1
		instances += (c as MultiMeshInstance3D).multimesh.instance_count
	ok(far > 0, "far props are batched (%d MultiMeshes)" % far)
	ok(instances > far, "shapes repeat, so batches hold several props (%d instances)" % instances)
	ok(far <= Flora.STYLES.size() * Flora.VARIANTS * 2, "at most one batch per kind, style and variant")
	print("FPCHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
