class_name Prof
extends RefCounted
## Tracy zones for the profiling build (docs/PERF.md). Every shipped build lacks the extension, so `on` is
## false and each call returns at once. Zones nest; every begin() needs its end() on the same path.
## The fight bench (--perf-bench) turns on `sums` instead: each zone's microseconds add up in `us`, keyed by
## the zone name (nested zones count inside their parent too), and it prints them (BENCH fight zones).

static var _tracy: Object = ClassDB.instantiate(&"TracyProfiler") if ClassDB.class_exists(&"TracyProfiler") else null
static var on := _tracy != null
static var sums := false
static var us := {}
static var _open: Array = []  # [zone, start usec] pairs, innermost last


static func begin(zone: String) -> void:
	if on:
		_tracy.zone_begin(zone)
	if sums:
		_open.append([zone, Time.get_ticks_usec()])


static func end() -> void:
	if on:
		_tracy.zone_end()
	if sums and not _open.is_empty():
		var z: Array = _open.pop_back()
		us[z[0]] = int(us.get(z[0], 0)) + Time.get_ticks_usec() - int(z[1])


## Ends a frame (Tracy's frame time and per-frame zone statistics count from here).
static func frame() -> void:
	if on:
		_tracy.frame_mark()
	_open.clear()  # (a zone left open by an early return never leaks into the next frame)
