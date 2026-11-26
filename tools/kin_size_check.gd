extends RefCounted
## --kin-size-check: a rigged Boki is as big as its data says (KinSize). Every species with a model, built the way the
## farm and the match build it (Models.kin), reads (KinSize.read: the root of its silhouette's area at the match's and
## the farm's pitch) within TOLERANCE of size.cm times M_PER_CM times READ_SHARE; the starters read close at each
## camera on its own, at the match and at the farm's scale, and Heatherhorn reads bigger than all of them.
## --table prints each.

const TOLERANCE := 0.05  # the share a species' measured read may differ from its data read
const STARTERS := ["cindle", "puddlet", "burrlet"]
const READ_SPREAD := 1.12  # at each camera, the starter reading biggest reads at most this many times the least
const BIG := "heatherhorn"
const BIG_OVER := 1.5  # Heatherhorn reads at least this many times the biggest starter
const FAR := 2.0  # the most a species' longest side may differ from its data length (an outlier model to look at)

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


## The world points of the meshes under `root` (every vertex KinSize.read would sample).
func _pts(root: Node3D) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				pts.append(mi.global_transform * v)
	return pts


## The m a built Boki reads as from one pitch (degrees): the root of its yaw-averaged silhouette area.
func _read_at(pts: PackedVector3Array, pitch: float) -> float:
	var area := 0.0
	for i in KinSize.YAWS:
		area += KinSize.cover(pts, deg_to_rad(pitch), PI * float(i) / KinSize.YAWS)
	return sqrt(area / KinSize.YAWS)


## Whether the starters' reads (id -> [read per pitch]) sit within READ_SPREAD at every pitch; `where` names the view.
func _close(reads: Dictionary, where: String) -> void:
	for p in KinSize.PITCHES.size():
		var most := 0.0
		var least := INF
		for id in STARTERS:
			most = maxf(most, float(reads[id][p]))
			least = minf(least, float(reads[id][p]))
		ok(
			most / least < READ_SPREAD,
			"%s, from %.0f degrees the starters read within %.2fx" % [where, KinSize.PITCHES[p], most / least]
		)


func run(m: Node) -> void:
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		_print_table = _print_table or a == "--table"
	var stage := Node3D.new()
	m.add_child(stage)
	var reads := {}
	var worst := 0.0
	var far := 1.0
	for id in Data.KIN:
		if not BokiRig.has(id):
			continue
		var k := Models.kin(id, {})
		stage.add_child(k)
		var mdl := (k.get_node("Body/Flex/BokiRig") as BokiRig).model
		var pts := _pts(mdl)
		var at: Array = KinSize.PITCHES.map(func(p: float) -> float: return _read_at(pts, p))
		var got := sqrt(float(at[0]) * float(at[1]))
		var cm := float(Unique.base_size(id)["cm"])
		var box := _box(mdl)
		var longest := box[box.max_axis_index()] / (cm * KinSize.M_PER_CM)
		reads[id] = at
		worst = maxf(worst, absf(got / (cm * KinSize.M_PER_CM * KinSize.READ_SHARE) - 1.0))
		far = maxf(far, maxf(longest, 1.0 / longest))
		if _print_table:
			print(
				(
					"KIN_SIZE_ROW %s data %.0f cm, box %.0f x %.0f x %.0f cm, read %.0f cm (57: %.0f, 20: %.0f)"
					% [id, cm, box.x * 100, box.y * 100, box.z * 100, got * 100, at[0] * 100, at[1] * 100]
				)
			)
		k.queue_free()
	ok(reads.size() >= 40, "%d species with a model measured" % reads.size())
	ok(
		worst <= TOLERANCE,
		"every species reads within %d%% of its data size (worst %.1f%%)" % [TOLERANCE * 100.0, worst * 100.0]
	)
	ok(far <= FAR, "every species' longest side is within %.1fx of its data length (worst %.2fx)" % [FAR, far])
	_close(reads, "in a match")
	var farm_scale := float(load("res://scripts/home/home.gd").get_script_constant_map()["FARM_BOKI_SCALE"])
	var farm := {}
	for id in STARTERS:
		var rec := Save.new_kin(id, "", 7)  # a fresh hatchling, the way the farm draws one (its evo scale)
		(rec["dna"] as Dictionary)["size"] = 0.0
		var k := Models.kin(id, rec)
		stage.add_child(k)
		k.scale = k.scale * farm_scale  # Home draws a Boki at its own scale times FARM_BOKI_SCALE, the same for each
		var pts := _pts((k.get_node("Body/Flex/BokiRig") as BokiRig).model)
		farm[id] = KinSize.PITCHES.map(func(p: float) -> float: return _read_at(pts, p))
		k.queue_free()
	_close(farm, "on the farm")
	var biggest := 0.0
	for id in STARTERS:
		biggest = maxf(biggest, sqrt(float(reads[id][0]) * float(reads[id][1])))
	var big := sqrt(float(reads[BIG][0]) * float(reads[BIG][1]))
	ok(
		big >= biggest * BIG_OVER,
		"Heatherhorn reads bigger than every starter (%.0f cm against %.0f)" % [big * 100.0, biggest * 100.0]
	)
	var t0 := Time.get_ticks_usec()
	KinSize.read((Models.kin(BIG, {}).get_node("Body/Flex/BokiRig") as BokiRig).model)
	print("KIN_SIZE_TIME read of one model %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	stage.queue_free()
	print("KIN_SIZE_DONE bad=%d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
