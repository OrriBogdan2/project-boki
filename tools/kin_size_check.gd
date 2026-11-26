extends RefCounted
## --kin-size-check: a rigged Boki stands as tall as its data says (KinSize). Every species with a model, built the way
## the farm and the match build it (Models.kin), measures within 10% of size.cm times KinSize.M_PER_CM, so the heights
## stand in the ratio of the data's centimetres; the starters stand close together and Heatherhorn stands over all.

const TOLERANCE := 0.1          # the share a species' measured height may differ from its data height
const STARTERS := ["cindle", "puddlet", "burrlet"]
const BIG := "heatherhorn"
const BIG_OVER := 1.5           # Heatherhorn stands at least this many times the tallest starter

var bad := 0
var _print_table := false

func ok(cond: bool, what: String) -> void:
	print("KIN_SIZE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## The metres from the lowest to the highest point of the meshes under `root`, in the world.
func _stands(root: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	return hi - lo

func run(m: Node) -> void:
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		_print_table = _print_table or a == "--table"
	var stage := Node3D.new()
	m.add_child(stage)
	var seen := {}
	var worst := 0.0
	for id in Data.KIN:
		if not BokiRig.has(id):
			continue
		var k := Models.kin(id, {})
		stage.add_child(k)
		var h := _stands((k.get_node("Body/Flex/BokiRig") as BokiRig).model)
		var cm := float(Unique.base_size(id)["cm"])
		seen[id] = h
		worst = maxf(worst, absf(h / (cm * KinSize.M_PER_CM) - 1.0))
		if _print_table:
			print("KIN_SIZE_ROW %s data %.0f cm, stands %.1f cm, raw glb %.1f cm" % [id, cm, h * 100.0,
				KinSize.height(k.get_node("Body/Flex/BokiRig").model) * 100.0])
		k.queue_free()
	ok(seen.size() >= 40, "%d species with a model measured" % seen.size())
	ok(worst <= TOLERANCE, "every species stands within %d%% of its data height (worst %.1f%%)" % [TOLERANCE * 100.0, worst * 100.0])
	var tall := 0.0
	for s in STARTERS:
		tall = maxf(tall, float(seen[s]))
	var small := 99.0
	for s in STARTERS:
		small = minf(small, float(seen[s]))
	ok(tall / small < 1.25, "the starters stand close together (%.0f to %.0f cm)" % [small * 100.0, tall * 100.0])
	ok(float(seen[BIG]) >= tall * BIG_OVER, "Heatherhorn stands over every starter (%.0f cm against %.0f)" % [
		float(seen[BIG]) * 100.0, tall * 100.0])
	stage.queue_free()
	print("KIN_SIZE_DONE bad=%d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
