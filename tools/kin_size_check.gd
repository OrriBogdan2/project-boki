extends RefCounted
## --kin-size-check: a rigged Boki is as big as its data says (KinSize). Every species with a model, built the way the
## farm and the match build it (Models.kin) and held in its idle pose, reads (KinSize.read: the root of its silhouette's
## area at the match's and the farm's pitch) within TOLERANCE of size.cm x M_PER_CM x READ_SHARE; KinSize.READS (the
## idle reads the game fits by) is up to date; the starters read close at each camera on its own, in a match and at
## the farm's scale, and Heatherhorn reads bigger than all of them. --table prints each. --write measures every
## species' idle read and writes content/rules/kin_read.json (run it after a model swap; the check names it).

const TOLERANCE := 0.05  # the share a species' measured read may differ from its data read
const STALE := 0.02  # the share a species' KinSize.READS entry may differ from its model's idle read
const STARTERS := ["cindle", "puddlet", "burrlet"]
const READ_SPREAD := 1.12  # at each camera, the starter reading biggest reads at most this many times the least
const BIG := "heatherhorn"
const BIG_OVER := 1.5  # Heatherhorn reads at least this many times the biggest starter
const FAR := 2.0  # the most a species' longest side may differ from its data length (an outlier model to look at)
const OUT := "res://content/rules/kin_read.json"

var bad := 0
var _print_table := false


func ok(cond: bool, what: String) -> void:
	print("KIN_SIZE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


## A Boki built as the game builds it, under `stage`, its rig held at the start of its idle clip (no frame has run, so
## that is its pose; KinSize.READS was measured the same way).
func _build(stage: Node3D, id: String, rec: Dictionary) -> BokiRig:
	var k := Models.kin(id, rec)
	stage.add_child(k)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.player.seek(0.0, true)
	return rig


## The m a built Boki reads as in the world from each of KinSize.PITCHES (its model's idle read times its world scale).
func _reads(rig: BokiRig) -> Array:
	var pts := KinSize.points(rig.model, true)
	var scale := rig.model.global_basis.get_scale().x
	return KinSize.PITCHES.map(func(p: float) -> float: return KinSize.read_at(pts, p) * scale)


## The two reads' geometric mean: KinSize.read's.
func _mean(at: Array) -> float:
	return sqrt(float(at[0]) * float(at[1]))


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
	var write := false
	for a in OS.get_cmdline_user_args():
		_print_table = _print_table or a == "--table"
		write = write or a == "--write"
	var stage := Node3D.new()
	m.add_child(stage)
	var known: Dictionary = Content.rules(KinSize.READS).get("reads", {})
	var idle := {}
	var reads := {}
	var worst := 0.0
	var far := 1.0
	var stale: Array[String] = []
	for id in Data.KIN:
		if not BokiRig.has(id):
			continue
		var rig := _build(stage, id, {})
		idle[id] = snappedf(KinSize.read(rig.model, true), 0.0001)  # in the model's own space, as fit() takes it
		if not known.has(id) or absf(float(known[id]) / float(idle[id]) - 1.0) > STALE:
			stale.append(id)
		var at := _reads(rig)
		var cm := float(Unique.base_size(id)["cm"])
		var box := KinSize.box(rig.model) * rig.model.global_basis.get_scale().x
		var longest := box[box.max_axis_index()] / (cm * KinSize.M_PER_CM)
		reads[id] = at
		worst = maxf(worst, absf(_mean(at) / (cm * KinSize.M_PER_CM * KinSize.READ_SHARE) - 1.0))
		far = maxf(far, maxf(longest, 1.0 / longest))
		if _print_table:
			print(
				(
					"KIN_SIZE_ROW %s data %.0f cm, bind box %.0f x %.0f x %.0f cm, idle read %.0f cm (%.0f, %.0f)"
					% [id, cm, box.x * 100, box.y * 100, box.z * 100, _mean(at) * 100, at[0] * 100, at[1] * 100]
				)
			)
		rig.get_parent().get_parent().get_parent().queue_free()
	if write:
		var f := FileAccess.open(OUT, FileAccess.WRITE)
		var doc := "Each rigged Boki's idle read (m, at fit 1): KinSize.READS. Written by --kin-size-check --write."
		f.store_string(JSON.stringify({"doc": doc, "reads": idle}, "\t", true) + "\n")
		f.close()
		print("KIN_SIZE wrote %d reads to %s" % [idle.size(), OUT])
		stale.clear()
	ok(reads.size() >= 40, "%d species with a model measured" % reads.size())
	ok(
		stale.is_empty(),
		"KinSize.READS matches every model's idle read (stale: %s; run --kin-size-check --write)" % [stale]
	)
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
		var rig := _build(stage, id, rec)
		var root := rig.get_parent().get_parent().get_parent() as Node3D
		root.scale = root.scale * farm_scale  # Home: its own scale times FARM_BOKI_SCALE, the same for each
		farm[id] = _reads(rig)
		root.queue_free()
	_close(farm, "on the farm")
	var biggest := 0.0
	for id in STARTERS:
		biggest = maxf(biggest, _mean(reads[id]))
	var big := _mean(reads[BIG])
	ok(
		big >= biggest * BIG_OVER,
		"Heatherhorn reads bigger than every starter (%.0f cm against %.0f)" % [big * 100.0, biggest * 100.0]
	)
	stage.queue_free()
	print("KIN_SIZE_DONE bad=%d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
