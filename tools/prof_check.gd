extends RefCounted
## --prof-check: the Tracy hooks (docs/PERF.md). Prof's zones are no-ops where the extension is absent (every
## shipped build), `on` follows whether the engine has the class, the export presets keep perf_tracy/ out, and
## tools/perf/tracy_report.py ranks a tracy-csvexport file by mean and p95 after the warm-up.

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("PROF %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	Prof.begin("check")
	Prof.end()
	Prof.end()      # (nothing open: ignored)
	Prof.frame()
	ok(Prof.on == ClassDB.class_exists(&"TracyProfiler"), "Prof.on follows the extension class")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var kept_out := presets.count(",perf_tracy/*,tools/perf/*")
	ok(kept_out > 0 and kept_out == presets.count("exclude_filter="), "every export preset keeps perf_tracy/ out")
	_report()
	print("PROF DONE, failures: %d" % fails)
	main_node.get_tree().quit(1 if fails > 0 else 0)

func _report() -> void:
	var rows := ["name,src_file,src_line,ns_since_start,exec_time_ns,thread,value"]
	rows.append("warmup,gdscript,0,0,90000000,1,")        # inside the dropped warm-up
	for i in 20:
		rows.append("slow,gdscript,0,%d,%d,1," % [4000000000 + i * 1000, (i + 1) * 1000000])   # 1..20 ms
		rows.append("fast,gdscript,0,%d,1000000,1," % [4000000000 + i * 1000])
	var csv := OS.get_cache_dir().path_join("prof_check.csv")
	FileAccess.open(csv, FileAccess.WRITE).store_string("\n".join(rows) + "\n")
	var out: Array = []
	var script := ProjectSettings.globalize_path("res://tools/perf/tracy_report.py")
	var rc := OS.execute("python3", ["-I", script, csv, "--top", "2"], out)
	var lines := String(out[0]).split("\n") if not out.is_empty() else PackedStringArray()
	ok(rc == 0 and lines.size() > 3, "the report runs")
	var first := lines[2] if lines.size() > 3 else ""
	ok(first.begins_with("| slow | 20 | 10.500 | 19.000 "), "slowest first: mean 10.5, p95 19 ms")
	ok(lines.size() > 3 and lines[3].begins_with("| fast | 20 | 1.000 "), "the second zone follows")
	ok(not "\n".join(lines).contains("warmup"), "the warm-up zone is dropped")
