extends RefCounted
## --fight-p99-check: the fight worst case's (--bench-fight, tools/perf_fight.gd: three trios, every E and R, a camp)
## frame-time p99 against the row recorded in tools/perf.tsv for this adapter, quality and window; fails when it
## is more than MAX_REGRESS over it. Wall time only means something on a real GPU, so the gate runs it through
## CheckRegistry.GPU_HOST (fight-p99-gpu, --needs gpu); elsewhere a fail is ADVISORY (docs/CHECKS_TIMING.md).
## No row for the adapter: prints the row to add and passes. Takes the bench's arguments.
##   godot --path . -- --fight-p99-check --quality=medium --bench-view=1920x1080 [--timing-strict]
## perf.tsv: key (adapter name part, lower case | quality | WxH), p99_ms, note. Re-record by editing the row.

const BASELINE := "res://tools/perf.tsv"
const MAX_REGRESS := 0.10  # a p99 more than this fraction over its baseline fails


func run(main: Node) -> void:
	var strict := "--timing-strict" in OS.get_cmdline_user_args()
	var bench = load("res://tools/perf_bench.gd").new()
	bench.setup(main)
	var frames: Array = await load("res://tools/perf_fight.gd").new(bench).run()
	var p99 := p99_of(frames.map(func(f): return float(f["wall"])))
	var win := main.get_window()
	var adapter := RenderingServer.get_video_adapter_name()
	var res := "%dx%d" % [win.size.x, win.size.y]
	var base := baseline_for(adapter, Settings.quality(), res)
	var fail := false
	if base < 0.0:
		print("FIGHT P99 no baseline for '%s|%s|%s'; measured %.1f ms. Add to tools/perf.tsv:" % [adapter, Settings.quality(), res, p99])
		print("%s|%s|%s\t%.1f" % [adapter.to_lower(), Settings.quality(), res, p99])
	else:
		var cap := base * (1.0 + MAX_REGRESS)
		fail = p99 > cap
		print("FIGHT P99 %s: %.1f ms over %d frames, cap %.1f (baseline %.1f +%d%%)" % [
			"FAIL" if fail else "PASS", p99, frames.size(), cap, base, roundi(MAX_REGRESS * 100.0)])
	var advisory := fail and not strict
	if advisory:
		print("FIGHT P99 ADVISORY: not a real GPU run or no --timing-strict; judged by fight-p99-gpu")
	main.get_tree().quit(1 if fail and not advisory else 0)


## The 99th-percentile of a list of frame times (ms), the way --perf-bench prints it.
static func p99_of(wall: Array) -> float:
	if wall.is_empty():
		return 0.0
	wall.sort()
	return float(wall[int((wall.size() - 1) * 0.99)])


## The recorded p99 for the adapter (a row's key part is found in its lower-cased name), quality and window; -1 if none.
static func baseline_for(adapter: String, quality: String, res: String, path := BASELINE) -> float:
	if not FileAccess.file_exists(path):
		return -1.0
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	for i in range(1, lines.size()):
		var cols := lines[i].split("\t")
		var key := cols[0].split("|")
		if cols.size() >= 2 and key.size() == 3 and adapter.to_lower().contains(key[0]) and key[1] == quality and key[2] == res:
			return float(cols[1])
	return -1.0
