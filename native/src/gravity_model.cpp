#include "gravity_model.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace final_orbit {

void GravityModel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_acceleration", "x", "y", "time"), &GravityModel::get_acceleration);
	ClassDB::bind_method(D_METHOD("propagate", "state", "dt"), &GravityModel::propagate);
	ClassDB::bind_method(D_METHOD("predict_trajectory", "state", "duration", "samples"), &GravityModel::predict_trajectory, DEFVAL(256));
}

} // namespace final_orbit
