extends RefCounted
## --perf-budget-check, the owner's expedition budget (DECISIONS 2026-11-08 performance pass): runs
## --perf-bench's expedition and fails when a frame after warm-up draws more than MAX_DRAWS calls or
## MAX_TRIS triangles, when more than MAX_SHADOW_LIGHTS lights cast shadows, or when any frame takes
## longer than MAX_FRAME_MS; then the fight worst case (tools/perf_fight.gd), which fails when its busiest
## moment has more than MAX_PARTICLES emitting (its frames count toward frame ms too). Wall time only means
## something on a real GPU, so run it through jobq (--needs gpu); the other numbers are the same on any
## renderer. Takes the bench's arguments (--quality=, --bench-view=, --bench-secs=).
##   godot --path . -- --perf-budget-check --quality=low --bench-view=1920x1080

const MAX_DRAWS := 1500           # draw calls in a frame
const MAX_TRIS := 1500000         # triangles in a frame
const MAX_SHADOW_LIGHTS := 2      # visible lights with shadows on
const MAX_FRAME_MS := 50.0        # ms, wall time of one frame
const WARM_FRAMES := 120          # frames skipped first: shader and model builds land there
const MAX_PARTICLES := 3999       # particles emitting at the fight's busiest moment (the owner's budget: under 4,000)

func run(main: Node) -> void:
	var bench = load("res://tools/perf_bench.gd").new()
	bench.setup(main)
	var frames: Array = (await bench._match()).slice(WARM_FRAMES)
	var fight = load("res://tools/perf_fight.gd").new(bench)
	frames.append_array(await fight.run())      # (the kits were cast once before it: warm)
	var fails := 0
	var worst := {"draws": 0.0, "tris": 0.0, "wall": 0.0}
	for f in frames:
		for k in worst:
			worst[k] = maxf(worst[k], float(f[k]))
	var lights: int = bench._shadow_lights()
	for row in [["draw calls", worst["draws"], MAX_DRAWS], ["triangles", worst["tris"], MAX_TRIS],
			["shadow lights", float(lights), MAX_SHADOW_LIGHTS], ["frame ms", worst["wall"], MAX_FRAME_MS],
			["fight particles", float(fight.peak["n"]), MAX_PARTICLES]]:
		var bad: bool = row[1] > row[2]
		fails += 1 if bad else 0
		print("BUDGET %s %s: worst %.0f, limit %.0f" % ["FAIL" if bad else "PASS", row[0], row[1], row[2]])
	print("BUDGET DONE, quality %s, failures: %d" % [Settings.quality(), fails])
	main.get_tree().quit(1 if fails > 0 else 0)
