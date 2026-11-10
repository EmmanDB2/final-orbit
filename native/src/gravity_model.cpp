#include "gravity_model.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace final_orbit {

namespace {

// One tick of the real flight, which is how the forecast's own run is flown through air.
constexpr double TICK = 1.0 / 60.0;
// How long a step through air is for the runs that only bound the landing zone, and how many ticks
// apart the points of the flown line are kept.
constexpr double HELD_AIR_STEP = 0.1;
constexpr int SAMPLE_TICKS = 6;
// Above the air a coast is exact, so it goes in strides: this share of the way to the landing zone
// at a time, so it can't overshoot the top of it by much.
constexpr double COAST_SHARE = 0.25;
constexpr double LONGEST_COAST_STEP = 120.0;
constexpr int MAX_DESCENT_STEPS = 400000;
// The landing zone is drawn this much wider at each end than the runs that bound it, in world
// units, since a forecast is only good to a couple of meters.
constexpr double ZONE_SLACK = 100.0;
constexpr double FULL_CIRCLE = 6.283185307179586476925286766559;
constexpr double HALF_CIRCLE = FULL_CIRCLE / 2.0;

Ref<ShipState> copy_of(const Ref<ShipState> &p_state) {
	Ref<ShipState> copy;
	copy.instantiate();
	copy->x = p_state->x;
	copy->y = p_state->y;
	copy->velocity_x = p_state->velocity_x;
	copy->velocity_y = p_state->velocity_y;
	copy->time = p_state->time;
	copy->on_surface = p_state->on_surface;
	copy->ground_clearance = p_state->ground_clearance;
	copy->touchdown_speed = p_state->touchdown_speed;
	return copy;
}

// The short way around from one angle to another.
double short_way(double p_from, double p_to) {
	const double difference = std::fmod(p_to - p_from + HALF_CIRCLE, FULL_CIRCLE);
	return (difference < 0.0 ? difference + FULL_CIRCLE : difference) - HALF_CIRCLE;
}

double number_in(const Dictionary &p_dictionary, const char *p_key, double p_default) {
	const Variant value = p_dictionary.get(String(p_key), p_default);
	return value;
}

// Slower than this over the ground, in world units per second, a ship's path has no direction.
constexpr double STILL_SPEED = 0.5;

} // namespace

int GravityModel::get_local_root(int p_index) const {
	int index = p_index;
	while (index > 0 && get_body_parent(index) > 0) {
		index = get_body_parent(index);
	}
	return index;
}

PackedFloat64Array GravityModel::get_hold_headings(double p_x, double p_y, double p_velocity_x, double p_velocity_y, double p_time) const {
	const int body = get_dominant_body(p_x, p_y, p_time);
	const PackedFloat64Array body_velocity = get_body_velocity(body, p_time);
	const PackedFloat64Array body_position = get_body_position(body, p_time);
	// The ground's own velocity inside the landing zone, and the body's above it.
	const PackedFloat64Array frame = get_surface_velocity(p_x, p_y, p_time);
	double relative_x = p_velocity_x - frame[0];
	double relative_y = p_velocity_y - frame[1];
	// Nearly still over the ground, there's no path to point along, so it falls back on the body's.
	if (relative_x * relative_x + relative_y * relative_y < STILL_SPEED * STILL_SPEED) {
		relative_x = p_velocity_x - body_velocity[0];
		relative_y = p_velocity_y - body_velocity[1];
	}
	const double along = std::atan2(relative_x, -relative_y);
	const double away = std::atan2(p_x - body_position[0], body_position[1] - p_y);
	PackedFloat64Array headings;
	headings.push_back(along);
	headings.push_back(along + HALF_CIRCLE);
	headings.push_back(away + HALF_CIRCLE);
	headings.push_back(away);
	return headings;
}

void GravityModel::fly_descent(const Ref<ShipState> &p_state, const AeroBody &p_aero, int p_body, double p_horizon, DescentRun &r_run) const {
	const Ref<ShipState> state = p_state;
	const double zone_top = get_body_radius(p_body) + get_entry_altitude(p_body);
	// The run that says where the ship lands is flown through air a tick at a time, exactly as the
	// real flight is. The two that only bound the landing zone take longer steps.
	const double air_step = r_run.held ? HELD_AIR_STEP : TICK;
	const int sample_every = r_run.held ? 1 : SAMPLE_TICKS;
	r_run.peak_hull = r_run.hull_temperature;

	double elapsed = 0.0;
	bool was_in_air = false;
	int since_sample = 0;
	for (int step = 0; step < MAX_DESCENT_STEPS && elapsed < p_horizon; step++) {
		if (state->on_surface) {
			break;
		}
		const double density = get_air_density(state->x, state->y, state->time);
		const bool in_air = density > 0.0;
		if (was_in_air && !in_air) {
			// Back out of the top of the air. Where it goes from there shows once it's there.
			break;
		}
		if (in_air && !r_run.met_air) {
			r_run.met_air = true;
			r_run.entry = copy_of(state);
			// The line through the air starts here, from the last point above it.
			const PackedFloat64Array body_at = get_body_position(p_body, state->time);
			r_run.xs.push_back(state->x - body_at[0]);
			r_run.ys.push_back(state->y - body_at[1]);
			r_run.times.push_back(state->time);
		}

		if (in_air) {
			const double dt = std::min(air_step, std::max(p_horizon - elapsed, TICK));
			// The real flight meets the air a tick at a time, moving on and speeding up between
			// each. A longer step would meet all of it where and as fast as it started, so it
			// takes the air from where the ship is halfway through those ticks, at its speed then.
			const double lead = (dt - TICK) * 0.5;
			double density_met = density;
			double lead_velocity_x = 0.0;
			double lead_velocity_y = 0.0;
			PackedFloat64Array air;
			if (lead > 0.0) {
				const double lead_x = state->x + state->velocity_x * lead;
				const double lead_y = state->y + state->velocity_y * lead;
				density_met = get_air_density(lead_x, lead_y, state->time + lead);
				air = get_surface_velocity(lead_x, lead_y, state->time + lead);
				const PackedFloat64Array pull = get_acceleration(state->x, state->y, state->time);
				lead_velocity_x = pull[0] * lead;
				lead_velocity_y = pull[1] * lead;
			} else {
				air = get_surface_velocity(state->x, state->y, state->time);
			}
			r_run.motion.velocity_x = state->velocity_x + lead_velocity_x - air[0];
			r_run.motion.velocity_y = state->velocity_y + lead_velocity_y - air[1];
			if (r_run.held) {
				p_aero.advance_held(r_run.motion, dt, density_met, r_run.held_off_airflow);
			} else {
				double control_value = 0.0;
				if (r_run.control == AeroBody::CONTROL_STEER) {
					control_value = get_hold_headings(state->x, state->y, state->velocity_x, state->velocity_y, state->time)[r_run.hold];
				}
				AeroBody::Report report;
				p_aero.advance(r_run.motion, dt, density_met, r_run.rcs_fuel > 0.0 ? r_run.control : static_cast<int>(AeroBody::CONTROL_NONE), control_value, report);
				r_run.rcs_fuel -= r_run.rcs_fuel_rate * report.rcs_use * dt;
				// The hull warms toward the heat the way it does tick by tick in flight.
				const double heat = report.heat / r_run.heat_limit + r_run.star_heat;
				r_run.hull_temperature += (heat - r_run.hull_temperature) * std::min(dt / r_run.hull_heat_seconds, 1.0);
				r_run.peak_hull = std::max(r_run.peak_hull, r_run.hull_temperature);
			}
			state->velocity_x = air[0] + r_run.motion.velocity_x - lead_velocity_x;
			state->velocity_y = air[1] + r_run.motion.velocity_y - lead_velocity_y;
			propagate(state, dt);
			elapsed += dt;
		} else {
			if (get_dominant_body(state->x, state->y, state->time) != p_body) {
				break;
			}
			const PackedFloat64Array body_at = get_body_position(p_body, state->time);
			const PackedFloat64Array body_moving = get_body_velocity(p_body, state->time);
			const double from_body_x = state->x - body_at[0];
			const double from_body_y = state->y - body_at[1];
			const double speed = std::sqrt((state->velocity_x - body_moving[0]) * (state->velocity_x - body_moving[0]) + (state->velocity_y - body_moving[1]) * (state->velocity_y - body_moving[1]));
			const double to_zone = std::sqrt(from_body_x * from_body_x + from_body_y * from_body_y) - zone_top;
			double dt = std::clamp(COAST_SHARE * std::max(to_zone, 0.0) / std::max(speed, 1.0), TICK, LONGEST_COAST_STEP);
			dt = std::min(dt, std::max(p_horizon - elapsed, TICK));
			// A stride that would end inside the air, or on the ground, is cut down until it only
			// just does.
			Ref<ShipState> next;
			while (true) {
				next = copy_of(state);
				propagate(next, dt);
				const bool arrives = next->on_surface || get_air_density(next->x, next->y, next->time) > 0.0;
				if (!arrives || dt <= TICK) {
					break;
				}
				dt = std::max(dt * 0.5, TICK);
			}
			if (!r_run.held) {
				double control_value = 0.0;
				if (r_run.control == AeroBody::CONTROL_STEER) {
					control_value = get_hold_headings(state->x, state->y, state->velocity_x, state->velocity_y, state->time)[r_run.hold];
				}
				AeroBody::Report report;
				p_aero.advance(r_run.motion, dt, 0.0, r_run.rcs_fuel > 0.0 ? r_run.control : static_cast<int>(AeroBody::CONTROL_NONE), control_value, report);
				r_run.rcs_fuel -= r_run.rcs_fuel_rate * report.rcs_use * dt;
				const double kept = std::pow(1.0 - std::min(TICK / r_run.hull_heat_seconds, 1.0), dt / TICK);
				r_run.hull_temperature = r_run.star_heat + (r_run.hull_temperature - r_run.star_heat) * kept;
			}
			state->x = next->x;
			state->y = next->y;
			state->velocity_x = next->velocity_x;
			state->velocity_y = next->velocity_y;
			state->time = next->time;
			state->on_surface = next->on_surface;
			state->touchdown_speed = next->touchdown_speed;
			elapsed += dt;
		}
		was_in_air = in_air;

		since_sample++;
		if (r_run.met_air && (since_sample >= sample_every || state->on_surface)) {
			since_sample = 0;
			const PackedFloat64Array body_then = get_body_position(p_body, state->time);
			r_run.xs.push_back(state->x - body_then[0]);
			r_run.ys.push_back(state->y - body_then[1]);
			r_run.times.push_back(state->time);
		}
	}
	if (state->on_surface) {
		r_run.landed = true;
		r_run.speed = state->touchdown_speed;
	}
}

Dictionary GravityModel::predict_descent(const Ref<ShipState> &p_state, const Ref<AeroBody> &p_aero, const Dictionary &p_flight, double p_horizon, int p_samples) const {
	Dictionary result;
	result["lands"] = false;
	result["air"] = false;
	ERR_FAIL_COND_V(p_state.is_null(), result);
	ERR_FAIL_COND_V(p_aero.is_null(), result);

	const int body = get_dominant_body(p_state->x, p_state->y, p_state->time);
	result["body"] = body;
	result["made_at"] = p_state->time;

	DescentRun main;
	main.motion.heading = number_in(p_flight, "heading", 0.0);
	main.motion.spin = number_in(p_flight, "spin", 0.0);
	main.control = static_cast<int>(number_in(p_flight, "control", 0.0));
	main.hold = std::clamp(static_cast<int>(number_in(p_flight, "hold", 0.0)), 0, 3);
	main.rcs_fuel = number_in(p_flight, "rcs_fuel", 0.0);
	main.rcs_fuel_rate = number_in(p_flight, "rcs_fuel_rate", 0.0);
	main.heat_limit = std::max(number_in(p_flight, "heat_limit", 1.0), 1e-9);
	main.hull_heat_seconds = std::max(number_in(p_flight, "hull_heat_seconds", 1.0), 1e-6);
	main.hull_temperature = number_in(p_flight, "hull_temperature", 0.0);
	main.star_heat = number_in(p_flight, "star_heat", 0.0);
	const Ref<ShipState> flown = copy_of(p_state);
	fly_descent(flown, **p_aero, body, p_horizon, main);

	result["lands"] = main.landed;
	result["air"] = main.met_air;
	result["peak_hull"] = main.peak_hull;
	if (!main.landed && !main.met_air) {
		return result;
	}

	const PackedFloat64Array body_at_end = get_body_position(body, flown->time);
	const double end_x = flown->x - body_at_end[0];
	const double end_y = flown->y - body_at_end[1];
	if (main.landed) {
		result["speed"] = main.speed;
		result["touchdown_time"] = flown->time;
		// How much higher the ground is on one side of where it stands than the other.
		const int stance = std::max(1, static_cast<int>(number_in(p_flight, "stance_columns", 1.0)));
		const int64_t column = static_cast<int64_t>(std::floor(get_ground_column(flown->x, flown->y, flown->time)));
		const PackedFloat32Array strip = get_ground_strip(body, column - stance, 1, stance * 2 + 1);
		result["rise"] = strip.size() >= (stance * 2 + 1) * 2 ? static_cast<double>(strip[0]) - static_cast<double>(strip[stance * 4]) : 0.0;
	}
	if (!main.met_air) {
		// No air on the way: it's a plain coast to the ground, and the path line already shows it.
		result["spin"] = 0.0;
		result["ground_time"] = flown->time;
		PackedFloat64Array end;
		end.push_back(end_x);
		end.push_back(end_y);
		result["end"] = end;
		return result;
	}

	// Everything from the top of the air on is drawn against the ground as it is when the line
	// through the air starts, or as it is now if the ship's already in the air.
	const double spin = get_body_spin(body);
	const double ground_time = main.times.empty() ? p_state->time : main.times[0];
	result["spin"] = spin;
	result["ground_time"] = ground_time;

	const int count = static_cast<int>(main.xs.size());
	const int wanted = std::max(2, p_samples);
	PackedFloat64Array path;
	PackedFloat64Array times;
	for (int i = 0; i < std::min(count, wanted); i++) {
		// Evenly through the run, always ending on its last point.
		const int index = count <= wanted ? i : static_cast<int>(std::llround(static_cast<double>(i) * (count - 1) / (wanted - 1)));
		const double turned = -spin * (main.times[index] - ground_time);
		const double cos_turned = std::cos(turned);
		const double sin_turned = std::sin(turned);
		path.push_back(main.xs[index] * cos_turned - main.ys[index] * sin_turned);
		path.push_back(main.xs[index] * sin_turned + main.ys[index] * cos_turned);
		times.push_back(main.times[index]);
	}
	result["path"] = path;
	result["times"] = times;
	if (!main.landed) {
		return result;
	}

	const double end_angle = std::atan2(end_x, -end_y) - spin * (flown->time - ground_time);
	const double end_distance = std::sqrt(end_x * end_x + end_y * end_y);
	PackedFloat64Array end;
	end.push_back(std::sin(end_angle) * end_distance);
	end.push_back(-std::cos(end_angle) * end_distance);
	result["end"] = end;

	// The landing zone: the same fall from the top of the air, held end on and held broadside.
	double zone_from = end_angle;
	double zone_to = end_angle;
	const double least_off = p_aero->drag_held(0.0) <= p_aero->drag_held(HALF_CIRCLE) ? 0.0 : HALF_CIRCLE;
	const double most_off = p_aero->drag_held(HALF_CIRCLE / 2.0) >= p_aero->drag_held(-HALF_CIRCLE / 2.0) ? HALF_CIRCLE / 2.0 : -HALF_CIRCLE / 2.0;
	const double held_offs[2] = { least_off, most_off };
	for (const double off : held_offs) {
		DescentRun held;
		held.held = true;
		held.held_off_airflow = off;
		const Ref<ShipState> held_state = copy_of(main.entry);
		fly_descent(held_state, **p_aero, body, p_horizon, held);
		if (!held.landed) {
			continue;
		}
		const PackedFloat64Array body_then = get_body_position(body, held_state->time);
		const double angle = std::atan2(held_state->x - body_then[0], body_then[1] - held_state->y) - spin * (held_state->time - ground_time);
		const double from_end = short_way(end_angle, angle);
		zone_from = std::min(zone_from, end_angle + from_end);
		zone_to = std::max(zone_to, end_angle + from_end);
	}
	const double slack = ZONE_SLACK / std::max(end_distance, 1.0);
	result["zone_from"] = zone_from - slack;
	result["zone_to"] = zone_to + slack;
	return result;
}

void GravityModel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_body_spin", "index"), &GravityModel::get_body_spin);
	ClassDB::bind_method(D_METHOD("get_entry_altitude", "index"), &GravityModel::get_entry_altitude);
	ClassDB::bind_method(D_METHOD("get_hold_headings", "x", "y", "velocity_x", "velocity_y", "time"), &GravityModel::get_hold_headings);
	ClassDB::bind_method(D_METHOD("predict_descent", "state", "aero", "flight", "horizon", "samples"), &GravityModel::predict_descent, DEFVAL(256));
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
	ClassDB::bind_method(D_METHOD("get_satellite_count"), &GravityModel::get_satellite_count);
	ClassDB::bind_method(D_METHOD("get_satellite_parent", "index"), &GravityModel::get_satellite_parent);
	ClassDB::bind_method(D_METHOD("get_satellite_position", "index", "time"), &GravityModel::get_satellite_position);
	ClassDB::bind_method(D_METHOD("get_satellite_velocity", "index", "time"), &GravityModel::get_satellite_velocity);
	ClassDB::bind_method(D_METHOD("get_satellite_orbit_path", "index", "samples"), &GravityModel::get_satellite_orbit_path, DEFVAL(256));
}

} // namespace final_orbit
