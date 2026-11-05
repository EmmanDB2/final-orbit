#include "ship_state.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace final_orbit {

void ShipState::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_x"), &ShipState::get_x);
	ClassDB::bind_method(D_METHOD("set_x", "value"), &ShipState::set_x);
	ClassDB::bind_method(D_METHOD("get_y"), &ShipState::get_y);
	ClassDB::bind_method(D_METHOD("set_y", "value"), &ShipState::set_y);
	ClassDB::bind_method(D_METHOD("get_velocity_x"), &ShipState::get_velocity_x);
	ClassDB::bind_method(D_METHOD("set_velocity_x", "value"), &ShipState::set_velocity_x);
	ClassDB::bind_method(D_METHOD("get_velocity_y"), &ShipState::get_velocity_y);
	ClassDB::bind_method(D_METHOD("set_velocity_y", "value"), &ShipState::set_velocity_y);
	ClassDB::bind_method(D_METHOD("get_time"), &ShipState::get_time);
	ClassDB::bind_method(D_METHOD("set_time", "value"), &ShipState::set_time);
	ClassDB::bind_method(D_METHOD("is_on_surface"), &ShipState::is_on_surface);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "x"), "set_x", "get_x");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "y"), "set_y", "get_y");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "velocity_x"), "set_velocity_x", "get_velocity_x");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "velocity_y"), "set_velocity_y", "get_velocity_y");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "time"), "set_time", "get_time");
}

} // namespace final_orbit
