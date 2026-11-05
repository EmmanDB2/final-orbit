// register_types.h: Godot's entry point into the physics core library.
#pragma once

#include <godot_cpp/core/class_db.hpp>

void initialize_final_orbit_module(godot::ModuleInitializationLevel p_level);
void uninitialize_final_orbit_module(godot::ModuleInitializationLevel p_level);
