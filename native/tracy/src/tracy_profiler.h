#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

// The GDScript side of Tracy (profiling builds only): zones nest like a stack, one per thread.
class TracyProfiler : public godot::RefCounted {
	GDCLASS(TracyProfiler, godot::RefCounted)

protected:
	static void _bind_methods();

public:
	// Opens a zone shown as `name` in Tracy (the name is copied, so a built string is fine).
	void zone_begin(const godot::String &name);
	// Closes the innermost open zone; a call with none open does nothing.
	void zone_end();
	// Ends a frame: Tracy's frame time and the per-frame zone statistics count from here.
	void frame_mark();
};
