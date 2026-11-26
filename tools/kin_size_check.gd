extends RefCounted
## --kin-size-check: a rigged Boki is as big as its data says (KinSize). Every species with a model, built the way the
## farm and the match build it (Models.kin), has a longest side within 10% of size.cm times KinSize.M_PER_CM; the
## starters cover close areas at the game camera and Heatherhorn is bigger than all of them. --table prints each.

const TOLERANCE := 0.1  # the share a species' measured height may differ from its data height
const STARTERS := ["cindle", "puddlet", "burrlet"]
const VIEW_PITCH := deg_to_rad(57.0)  # the match camera's pitch (CamRig.pitch)
const VIEW_YAWS := 4  # turns of the model (evenly round) the covered area is averaged over
const COVER_SPREAD := 1.15  # the starter covering most of the screen covers at most this many times the least
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


## The area (m2) the meshes under `root` cover at the game camera: the hull of every vertex seen from VIEW_PITCH,
## averaged over VIEW_YAWS turns.
func _cover(root: Node3D) -> float:
	var total := 0.0
	for i in VIEW_YAWS:
		var turn := Basis(Vector3.UP, PI * float(i) / VIEW_YAWS)
		var pts := PackedVector2Array()
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh is ArrayMesh:
				for v in mi.mesh.get_faces():
					var w := turn * (mi.global_transform * v)
					pts.append(Vector2(w.x, w.y * cos(VIEW_PITCH) - w.z * sin(VIEW_PITCH)))
		var hull := Geometry2D.convex_hull(pts)
		var area := 0.0
		for j in hull.size() - 1:
			area += hull[j].x * hull[j + 1].y - hull[j + 1].x * hull[j].y
		total += absf(area) * 0.5
	return total / VIEW_YAWS


func run(m: Node) -> void:
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		_print_table = _print_table or a == "--table"
	var stage := Node3D.new()
	m.add_child(stage)
	var seen := {}
	var covers := {}
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
		if id in STARTERS:
			covers[id] = _cover((k.get_node("Body/Flex/BokiRig") as BokiRig).model)
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
	var most := 0.0
	var least := INF
	var longest_starter := 0.0
	for id in STARTERS:
		most = maxf(most, float(covers[id]))
		least = minf(least, float(covers[id]))
		var box: Vector3 = seen[id]
		longest_starter = maxf(longest_starter, box[box.max_axis_index()])
	ok(
		most / least < COVER_SPREAD,
		"the starters cover close areas at the game camera (%.0f to %.0f cm2)" % [least * 1e4, most * 1e4]
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
