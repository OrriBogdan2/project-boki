class_name PerfLog
extends RefCounted
## Cheap timing marks for the heavy one-off steps (building a match, the world's meshes, the map
## bake). Always on: a handful of marks per match. --perf-probe reads them to say what a hitch was,
## and -- --perf-log prints each step's time as it finishes.

static var marks: Array = []      # [usec, label, ms the step took]
static var _t := 0
static var _verbose := -1

## Starts timing a new run of steps (a match build).
static func reset() -> void:
	marks.clear()
	slices.clear()
	_t = Time.get_ticks_usec()

## The step that just finished: how long it took since the previous mark.
static func mark(label: String) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _t) / 1000.0
	_t = now
	marks.append([now, label, ms])
	if marks.size() > 400:
		marks = marks.slice(-200)
	if _verbose < 0:
		_verbose = 1 if "--perf-log" in OS.get_cmdline_user_args() else 0
	if _verbose == 1:
		print("PERF step %-28s %7.1f ms" % [label, ms])

## A line for --perf-log (and the --load-check report), not a timed step.
static var notes: Array = []
static func note(s: String) -> void:
	notes.append(s)
	if notes.size() > 50: notes = notes.slice(-25)
	if _verbose < 0:
		_verbose = 1 if "--perf-log" in OS.get_cmdline_user_args() else 0
	if _verbose == 1:
		print("PERF note " + s)

## Restarts the clock without logging (after a wait that isn't work, e.g. a frame of the loading screen).
static func skip() -> void:
	_t = Time.get_ticks_usec()
	_frame_us = _t

## The marks made between two times (usec), for blaming a slow frame.
static func between(t0: int, t1: int) -> Array:
	var out: Array = []
	for mk in marks:
		if int(mk[0]) > t0 and int(mk[0]) <= t1:
			out.append(mk)
	return out

# ------------------------------------------------------------------ slicing long build steps
## A build step under the loading screen that runs longer than this lets a frame draw (so the
## spinner keeps turning and the window never looks hung). Well inside a 100 ms frame on a real GPU;
## shorter only adds frames (each one draws the loading screen) to the load.
const SLICE_MS := 45.0
static var _frame_us := 0
static var _wait_us := 0
## The work each slice did before letting a frame draw: [usec, ms, where] (where: the slice point
## that ended it, only with trace_slices on, e.g. --load-check --hitch-trace).
static var slices: Array = []
static var trace_slices := false

## True when the step running now has had the CPU for SLICE_MS since the last frame drew.
static func slice_due() -> bool:
	return Time.get_ticks_usec() - _frame_us > int(SLICE_MS * 1000.0)

## Around a frame waited inside a step: the wait isn't the step's work, so its time comes off the mark.
static func wait_begin() -> void:
	_wait_us = Time.get_ticks_usec()
	var where := ""
	if trace_slices:
		var st := get_stack()
		if st.size() > 2: where = "%s:%d" % [String(st[2]["function"]), int(st[2]["line"])]
	slices.append([_wait_us, (_wait_us - _frame_us) / 1000.0, where])
	if slices.size() > 2000:
		slices = slices.slice(-1000)

static func wait_end() -> void:
	var now := Time.get_ticks_usec()
	_t += now - _wait_us
	_frame_us = now

## A frame just drew (a stage boundary): the next slice is measured from here.
static func frame_drawn() -> void:
	_frame_us = Time.get_ticks_usec()
