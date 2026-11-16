#include "tracy_profiler.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include <vector>

#include "tracy/TracyC.h"

using namespace godot;

static const uint32_t ZONE_COLOR = 0; // 0: Tracy picks a colour from the zone name
static thread_local std::vector<TracyCZoneCtx> open_zones; // Tracy zones nest per thread

void TracyProfiler::_bind_methods() {
	ClassDB::bind_method(D_METHOD("zone_begin", "name"), &TracyProfiler::zone_begin);
	ClassDB::bind_method(D_METHOD("zone_end"), &TracyProfiler::zone_end);
	ClassDB::bind_method(D_METHOD("frame_mark"), &TracyProfiler::frame_mark);
}

void TracyProfiler::zone_begin(const String &name) {
	const CharString utf8 = name.utf8();
	const char *file = "gdscript";
	const uint64_t srcloc = ___tracy_alloc_srcloc_name(0, file, 8, file, 8, utf8.get_data(), utf8.length(), ZONE_COLOR);
	open_zones.push_back(___tracy_emit_zone_begin_alloc(srcloc, 1));
}

void TracyProfiler::zone_end() {
	if (open_zones.empty()) {
		return;
	}
	___tracy_emit_zone_end(open_zones.back());
	open_zones.pop_back();
}

void TracyProfiler::frame_mark() {
	___tracy_emit_frame_mark(nullptr);
}
