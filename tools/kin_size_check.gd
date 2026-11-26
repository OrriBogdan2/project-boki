extends RefCounted
## --kin-size-check: a rigged Boki is as big as its data says (KinSize). Every species with a model, built the way the
## farm and the match build it (Models.kin), has a longest side within 10% of size.cm times KinSize.M_PER_CM; the
## starters have close footprints (seen from above) and Heatherhorn is bigger than all of them. --table prints each.

const TOLERANCE := 0.1  # the share a species' measured height may differ from its data height
const STARTERS := ["cindle", "puddlet", "burrlet"]
const FOOTPRINT_SPREAD := 1.2  # the biggest starter footprint is at most this many times the smallest
const BIG := "heatherhorn"
const BIG_OVER := 1.5  # Heatherhorn stands at least this many times the tallest starter

var bad := 0
var _print_table := false


func ok(cond: bool, what: String) -> void:
	print("KIN_SIZE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


## The metre size of the box round the meshes under `root`, in the world.
func _box(root: Node3D) -> Vector3:
	var all := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		all = b if first else all.merge(b)
		first = false
	return all.size


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
		var box := _box((k.get_node("Body/Flex/BokiRig") as BokiRig).model)
		var longest := box[box.max_axis_index()]
		var cm := float(Unique.base_size(id)["cm"])
		seen[id] = box
		worst = maxf(worst, absf(longest / (cm * KinSize.M_PER_CM) - 1.0))
		if _print_table:
			print(
				(
					"KIN_SIZE_ROW %s data %.0f cm, box %.0f x %.0f x %.0f cm"
					% [id, cm, box.x * 100, box.y * 100, box.z * 100]
				)
			)
		k.queue_free()
	ok(seen.size() >= 40, "%d species with a model measured" % seen.size())
	ok(
		worst <= TOLERANCE,
		(
			"every species' longest side is within %d%% of its data size (worst %.1f%%)"
			% [TOLERANCE * 100.0, worst * 100.0]
		)
	)
	var big := 0.0
	var small := INF
	var longest_starter := 0.0
	for s in STARTERS:
		var box: Vector3 = seen[s]
		big = maxf(big, box.x * box.z)
		small = minf(small, box.x * box.z)
		longest_starter = maxf(longest_starter, box[box.max_axis_index()])
	ok(
		big / small < FOOTPRINT_SPREAD,
		"the starters have close footprints (%.0f to %.0f cm2)" % [small * 1e4, big * 1e4]
	)
	var heather: Vector3 = seen[BIG]
	var heather_longest := heather[heather.max_axis_index()]
	ok(
		heather_longest >= longest_starter * BIG_OVER,
		(
			"Heatherhorn is bigger than every starter (%.0f cm against %.0f)"
			% [heather_longest * 100.0, longest_starter * 100.0]
		)
	)
	stage.queue_free()
	print("KIN_SIZE_DONE bad=%d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
