extends RefCounted
## --match-repeat-check: what a long session leaves behind. CYCLES expeditions (a new seed each, as a player gets
## them) run back to back, each SIM_S s of match time on autopilot and then home to the farm; after every farm
## visit it reads the engine's object, node, orphan-node and resource counts, the static and video memory and
## the meshes the shared mesh caches hold (MeshCache). The first WARM cycles fill what every later match shares;
## after those, one more match may add at most MESH_GROWTH cached meshes and OBJ_GROWTH objects, no orphan node
## may be left, and a mesh the sweep dropped must come back the same. Static memory is reported, not judged:
## the Warden and Boki model caches (WardenGlb, BokiRig) grow with each Hero and species first seen, up to the
## roster. Headless; never touches the save.
##   godot --headless -- --match-repeat-check [--repeat-cycles=8]
## On a GPU (jobq --needs gpu) the video and texture memory lines include the painted map (MapPaint).

const CYCLES := 5               # expeditions in a run (--repeat-cycles= overrides)
const WARM := 3                 # cycles that may fill the shared caches before growth counts
const SIM_S := 20.0             # s of match time per expedition
const DT := 1.0 / 60.0          # s per match step (Match.DT)
const FRAME_EVERY := 30         # match steps between frames, so deferred frees and timers run
const HOME_FRAMES := 30         # frames on the farm before the counts are read
const MESH_GROWTH := 60         # cached meshes one more match may add (~420 a match before MeshCache)
const OBJ_GROWTH := 400         # objects one more match may add (~750 a match before MeshCache)

var main: Node
var bad := 0

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	if Save.d["roster"].is_empty():
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
	var cycles := CYCLES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--repeat-cycles="):
			cycles = maxi(WARM + 1, int(a.get_slice("=", 1)))
	var rows: Array = []
	for i in cycles:
		var build_ms: int = await _expedition(4101 + i * 17)
		await _home()
		var row := _counts()
		row["build_ms"] = build_ms
		rows.append(row)
		print("REPEAT cycle %d: %s" % [i + 1, _fmt(row)])
	_judge(rows)
	_rebuild_same()
	print("REPEAT %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## Runs one expedition; returns the ms its build took (to the frame the Match appeared in).
func _expedition(seed_v: int) -> int:
	var t0 := Time.get_ticks_msec()
	main.show_screen("match", {"teams": 6, "squad": 3, "tier": 0, "seed": seed_v, "autoplay": true, "god": true})
	var mt: Match = null
	while mt == null:
		await main.get_tree().process_frame
		mt = main.current as Match
	var build_ms := Time.get_ticks_msec() - t0
	mt.set_process(false)
	for s in int(SIM_S / DT):
		if not is_instance_valid(mt):
			break
		mt.step(DT)
		if s % FRAME_EVERY == 0:
			await main.get_tree().process_frame
	return build_ms

func _home() -> void:
	main.show_screen("home", {})
	for f in HOME_FRAMES:
		await main.get_tree().process_frame

func _counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"meshes": MeshCache.entries(),
		"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"tex_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
	}

func _fmt(r: Dictionary) -> String:
	return "objects %d nodes %d orphans %d resources %d cached meshes %d static %.1f MB video %.1f MB" % [r["objects"],
			r["nodes"], r["orphans"], r["resources"], r["meshes"], r["mem_mb"], r["vram_mb"]] \
			+ " textures %.1f MB (build %d ms)" % [r["tex_mb"], r["build_ms"]]

func _judge(rows: Array) -> void:
	var a: Dictionary = rows[WARM - 1]
	var b: Dictionary = rows[-1]
	var n := rows.size() - WARM
	var meshes := (int(b["meshes"]) - int(a["meshes"])) / float(n)
	var obj := (int(b["objects"]) - int(a["objects"])) / float(n)
	_ok(meshes <= MESH_GROWTH, "cached meshes per match after the warm-up: %+.0f (limit %d)" % [meshes, MESH_GROWTH])
	_ok(obj <= OBJ_GROWTH, "objects per match after the warm-up: %+.0f (limit %d)" % [obj, OBJ_GROWTH])
	_ok(int(b["orphans"]) == 0, "orphan nodes after the last match: %d" % int(b["orphans"]))
	print("REPEAT static memory per match after the warm-up: %+.1f MB, video %+.1f MB" % [
			(float(b["mem_mb"]) - float(a["mem_mb"])) / n, (float(b["vram_mb"]) - float(a["vram_mb"])) / n])

## A mesh the sweep dropped comes back the same when a build asks for it again (so a sweep never shows).
func _rebuild_same() -> void:
	var a := Models.crystal(0.1234, 0.5678)
	for i in MeshCache.IDLE_SWEEPS:
		MeshCache.sweep()
	var b := Models.crystal(0.1234, 0.5678)
	_ok(a != b and a.surface_get_arrays(0) == b.surface_get_arrays(0), "a swept mesh is rebuilt, the same")

func _ok(cond: bool, what: String) -> void:
	print("REPEAT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
