extends RefCounted
## --far-ranges-check: builds the first authored map at every quality preset and looks at it from a
## skyship-high camera and a play camera. Prints one PERF line per preset and view (draws, visible tris)
## for before/after numbers, and asserts the ranges: High and Ultra never drop a tree, boulder or cliff,
## lower presets do, cliffs have a far version from the near range out, and the far version is lighter.
## (Without FarRanges in the tree it only prints the numbers, so the same tool measures the old build.)
##   --far-shots=<dir> also saves a PNG per preset and view.

const PRESETS := ["ultra", "high", "medium", "low", "very_low"]
const VIEWS := {"sky": [Vector3(0, 150, 60), 70.0], "play": [Vector3(0, 22, 14), 55.0]}

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("FARRANGES %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--far-shots="): shots = a.substr(12)
	var keep_q = Settings.v.get("quality", "auto")
	for p in PRESETS:
		if not Settings.QUALITY.has(p):
			continue
		Settings.v["quality"] = p
		await _preset(p, shots)
	Settings.v["quality"] = keep_q
	print("FARRANGES DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _preset(p: String, shots: String) -> void:
	var T: Dictionary = Data.TIERS[0]
	var w := World.new()
	w.biome = T["biome"].duplicate()
	w.clouds = T["clouds"]
	main.add_child(w)
	w.generate_authored(World.load_layout(World.layout_for_tier(0)), 9)
	await w.build_meshes()
	var sv := SubViewport.new()      # the title screen owns the main viewport, so look through our own
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(sv)
	main.get_viewport().disable_3d = true
	var cam := Camera3D.new()
	sv.add_child(cam)
	cam.current = true
	var mid := Vector3(w.w * 0.5, 0, w.h * 0.5)
	for view in VIEWS:
		cam.fov = VIEWS[view][1]
		cam.global_position = mid + VIEWS[view][0]
		cam.look_at(mid, Vector3.UP)
		for i in 4:
			await main.get_tree().process_frame
		var rs := RenderingServer
		var draws: int = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var tris: int = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("PERF farview %s %s: draws %d, tris %.0fk" % [p, view, draws, tris / 1000.0])
		if shots != "":
			sv.get_texture().get_image().save_png("%s/%s_%s.png" % [shots, p, view])
	main.get_viewport().disable_3d = false
	sv.free()
	if ResourceLoader.exists("res://scripts/perf/far_ranges.gd"):
		_asserts(p, w)
	w.free()

func _asserts(p: String, w: Node) -> void:
	var row: Dictionary = load("res://scripts/perf/far_ranges.gd").BIG[p]
	var unlimited := p in ["high", "ultra"]
	var seen := {"tree": 0, "rock": 0, "cliff": 0}
	var limited := {"tree": 0, "rock": 0, "cliff": 0}
	var far_n := 0
	var wrong_begin := 0
	var heavy := 0
	var wrong_end := 0
	var deco := w.get_node("Deco")
	for n in deco.get_children():
		var mmi := n as MultiMeshInstance3D
		var cls := String(n.name).get_slice("_", 0)
		if mmi == null or not seen.has(cls):
			continue
		seen[cls] += 1
		if mmi.visibility_range_end > 0.0:
			limited[cls] += 1
		if "_far_" in String(n.name):
			far_n += 1
			wrong_begin += 0 if is_equal_approx(mmi.visibility_range_begin, float(row["near"])) else 1
			var base := String(n.name).get_slice("_far_", 0) + "_"
			for o in deco.get_children():
				var near := o as MultiMeshInstance3D
				if near != null and String(o.name).begins_with(base) and not "_far_" in String(o.name):
					heavy += 0 if _tris(mmi.multimesh.mesh) < _tris(near.multimesh.mesh) else 1
					wrong_end += 0 if is_equal_approx(near.visibility_range_end, float(row["near"])) else 1
					break
	ok(wrong_begin == 0, "%s: every far cliff batch begins at the near range (%.0f m)" % [p, row["near"]])
	ok(heavy == 0, "%s: every far cliff mesh is lighter than its detailed mesh" % p)
	ok(seen["rock"] > 0 and seen["cliff"] > 0, "%s has rock and cliff batches (%s)" % [p, seen])
	ok(far_n > 0, "%s has %d far cliff batches" % [p, far_n])
	for cls in ["tree", "rock"]:
		var want: int = 0 if unlimited else seen[cls]
		ok(limited[cls] == want, "%s: %d of %d %s batches have a range" % [p, limited[cls], seen[cls], cls])
	ok(wrong_end == 0, "%s: a cliff batch with a far version ends at the near range" % p)
	ok(unlimited or limited["cliff"] == seen["cliff"], "%s: every cliff batch has a range" % p)

func _tris(m: Mesh) -> int:
	var t := 0
	for si in (m as ArrayMesh).get_surface_count():
		t += (m as ArrayMesh).surface_get_array_index_len(si) / 3
	return t
