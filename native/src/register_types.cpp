#include "register_types.h"

#include "aero_body.h"
#include "gravity_model.h"
#include "patched_conics_model.h"
#include "ship_state.h"

#include <gdextension_interface.h>

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_final_orbit_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(final_orbit::ShipState);
	GDREGISTER_ABSTRACT_CLASS(final_orbit::GravityModel);
	GDREGISTER_CLASS(final_orbit::PatchedConicsModel);
	GDREGISTER_CLASS(final_orbit::AeroBody);
}

void uninitialize_final_orbit_module(ModuleInitializationLevel p_level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT final_orbit_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_final_orbit_module);
	init_obj.register_terminator(uninitialize_final_orbit_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
