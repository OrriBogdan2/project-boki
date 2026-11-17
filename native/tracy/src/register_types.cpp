#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include "tracy_profiler.h"

using namespace godot;

static void initialize_tracy(ModuleInitializationLevel level) {
	if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		GDREGISTER_CLASS(TracyProfiler);
	}
}

static void uninitialize_tracy(ModuleInitializationLevel level) {}

extern "C" GDExtensionBool GDE_EXPORT tracy_zones_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library, GDExtensionInitialization *init) {
	GDExtensionBinding::InitObject init_obj(get_proc_address, library, init);
	init_obj.register_initializer(initialize_tracy);
	init_obj.register_terminator(uninitialize_tracy);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
