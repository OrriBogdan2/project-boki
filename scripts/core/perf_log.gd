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

## Restarts the clock without logging (after a wait that isn't work, e.g. a frame of the loading screen).
static func skip() -> void:
	_t = Time.get_ticks_usec()

## The marks made between two times (usec), for blaming a slow frame.
static func between(t0: int, t1: int) -> Array:
	var out: Array = []
	for mk in marks:
		if int(mk[0]) > t0 and int(mk[0]) <= t1:
			out.append(mk)
	return out
