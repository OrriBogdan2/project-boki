extends RefCounted
## --perf-bench --tracy=<dir>: a Tracy capture of the bench's match part, headless (docs/PERF.md). tracy-capture
## records the zones from the running game; at the end it is told to stop and tracy-csvexport writes
## <dir>/zones.csv (one row per zone instance), which tools/perf/tracy_report.py reads. Build both first with
## tools/perf/build_tracy.sh.

const PORT := 18086              # the extension listens here (native/tracy/SConstruct)
const BIN_DIR := "res://tools/perf/bin/"
const STOP_WAIT_S := 30.0        # s: the longest wait for tracy-capture to save its trace after the stop signal
var dir := ""
var pid := -1

func start(out_dir: String) -> bool:
	dir = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	if not Prof.on:
		push_error("TRACY: the extension is not loaded; run tools/perf/build_tracy.sh and import the project once")
		return false
	pid = OS.create_process(_bin("tracy-capture"), ["-f", "-p", str(PORT), "-o", dir.path_join("match.tracy")])
	return pid > 0

## Stops the capture once it has seen the zones, then exports them. Returns whether zones.csv was written.
func finish(tree: SceneTree) -> bool:
	OS.execute("kill", ["-INT", str(pid)])      # tracy-capture saves its trace on SIGINT
	var waited := 0.0
	while OS.is_process_running(pid) and waited < STOP_WAIT_S:
		await tree.create_timer(0.25).timeout
		waited += 0.25
	var csv: Array = []
	OS.execute(_bin("tracy-csvexport"), ["-u", dir.path_join("match.tracy")], csv)
	var fa := FileAccess.open(dir.path_join("zones.csv"), FileAccess.WRITE)
	if fa == null or csv.is_empty() or String(csv[0]).is_empty():
		return false
	fa.store_string(String(csv[0]))
	return true

func _bin(tool: String) -> String:
	return ProjectSettings.globalize_path(BIN_DIR + tool)
