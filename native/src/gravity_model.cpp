#include "gravity_model.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace final_orbit {

void GravityModel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_acceleration", "x", "y", "time"), &GravityModel::get_acceleration);
	ClassDB::bind_method(D_METHOD("propagate", "state", "dt"), &GravityModel::propagate);
	ClassDB::bind_method(D_METHOD("predict_trajectory", "state", "duration", "samples"), &GravityModel::predict_trajectory, DEFVAL(256));
	ClassDB::bind_method(D_METHOD("find_encounter", "state", "duration"), &GravityModel::find_encounter);
	ClassDB::bind_method(D_METHOD("get_body_count"), &GravityModel::get_body_count);
	ClassDB::bind_method(D_METHOD("get_body_position", "index", "time"), &GravityModel::get_body_position);
	ClassDB::bind_method(D_METHOD("get_body_radius", "index"), &GravityModel::get_body_radius);
	ClassDB::bind_method(D_METHOD("get_dominant_body", "x", "y", "time"), &GravityModel::get_dominant_body);
	ClassDB::bind_method(D_METHOD("get_sphere_of_influence", "index"), &GravityModel::get_sphere_of_influence);
	ClassDB::bind_method(D_METHOD("get_body_orbit_path", "index", "samples"), &GravityModel::get_body_orbit_path, DEFVAL(256));
}

} // namespace final_orbit
