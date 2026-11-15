class_name Prof
extends RefCounted
## Tracy zones for the profiling build (docs/PERF.md). Every shipped build lacks the extension, so `on` is
## false and each call returns at once. Zones nest; every begin() needs its end() on the same path.

static var _tracy: Object = ClassDB.instantiate(&"TracyProfiler") if ClassDB.class_exists(&"TracyProfiler") else null
static var on := _tracy != null

static func begin(zone: String) -> void:
	if on: _tracy.zone_begin(zone)

static func end() -> void:
	if on: _tracy.zone_end()

## Ends a frame (Tracy's frame time and per-frame zone statistics count from here).
static func frame() -> void:
	if on: _tracy.frame_mark()
