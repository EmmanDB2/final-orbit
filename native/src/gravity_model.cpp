#include "gravity_model.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace final_orbit {

int GravityModel::get_local_root(int p_index) const {
	int index = p_index;
	while (index > 0 && get_body_parent(index) > 0) {
		index = get_body_parent(index);
	}
	return index;
}

void GravityModel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_acceleration", "x", "y", "time"), &GravityModel::get_acceleration);
	ClassDB::bind_method(D_METHOD("propagate", "state", "dt"), &GravityModel::propagate);
	ClassDB::bind_method(D_METHOD("predict_trajectory", "state", "duration", "samples"), &GravityModel::predict_trajectory, DEFVAL(256));
	ClassDB::bind_method(D_METHOD("predict_entry_heights", "state", "duration", "samples"), &GravityModel::predict_entry_heights, DEFVAL(256));
	ClassDB::bind_method(D_METHOD("find_encounter", "state", "duration"), &GravityModel::find_encounter);
	ClassDB::bind_method(D_METHOD("get_altitude", "x", "y", "time"), &GravityModel::get_altitude);
	ClassDB::bind_method(D_METHOD("get_surface_velocity", "x", "y", "time"), &GravityModel::get_surface_velocity);
	ClassDB::bind_method(D_METHOD("get_air_density", "x", "y", "time"), &GravityModel::get_air_density);
	ClassDB::bind_method(D_METHOD("get_ground_height", "x", "y", "time"), &GravityModel::get_ground_height);
	ClassDB::bind_method(D_METHOD("get_ground_column", "x", "y", "time"), &GravityModel::get_ground_column);
	ClassDB::bind_method(D_METHOD("get_highest_ground", "index"), &GravityModel::get_highest_ground);
	ClassDB::bind_method(D_METHOD("get_distant_ridge", "index", "first_column", "step", "count", "loop_share"), &GravityModel::get_distant_ridge);
	ClassDB::bind_method(D_METHOD("get_ground_strip", "index", "first_column", "step", "count"), &GravityModel::get_ground_strip);
	ClassDB::bind_method(D_METHOD("get_body_count"), &GravityModel::get_body_count);
	ClassDB::bind_method(D_METHOD("get_body_parent", "index"), &GravityModel::get_body_parent);
	ClassDB::bind_method(D_METHOD("get_local_root", "index"), &GravityModel::get_local_root);
	ClassDB::bind_method(D_METHOD("get_body_position", "index", "time"), &GravityModel::get_body_position);
	ClassDB::bind_method(D_METHOD("get_body_velocity", "index", "time"), &GravityModel::get_body_velocity);
	ClassDB::bind_method(D_METHOD("get_orbit_apsides", "state"), &GravityModel::get_orbit_apsides);
	ClassDB::bind_method(D_METHOD("get_body_radius", "index"), &GravityModel::get_body_radius);
	ClassDB::bind_method(D_METHOD("get_dominant_body", "x", "y", "time"), &GravityModel::get_dominant_body);
	ClassDB::bind_method(D_METHOD("get_sphere_of_influence", "index"), &GravityModel::get_sphere_of_influence);
	ClassDB::bind_method(D_METHOD("get_body_orbit_path", "index", "samples"), &GravityModel::get_body_orbit_path, DEFVAL(256));
}

} // namespace final_orbit
