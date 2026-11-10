#include "aero_body.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace final_orbit {

namespace {

// One tick at normal speed. A longer tick, under time warp, is flown as this many of these, so
// the same descent comes out the same at any warp.
constexpr double BASE_STEP = 1.0 / 60.0;
// How much of the fastest thing going on one step may cover: the air's braking, its damping of a
// spin, or one swing of the ship about the way it trims.
constexpr double STEP_SHARE = 0.25;
constexpr int MAX_SUBSTEPS = 512;
// A layer seen edge-on, or with almost nothing left, has no outline worth pushing on.
constexpr double SMALLEST_AREA = 1.0;
// The air counts as out-turning the RCS from this share of the RCS's own strength, since the little
// it has left over then can't hold anything.
constexpr double OVERPOWERED_SHARE = 0.9;
constexpr double FULL_CIRCLE = 6.283185307179586476925286766559;
constexpr double HALF_CIRCLE = FULL_CIRCLE / 2.0;

double move_toward(double p_from, double p_to, double p_step) {
	if (std::abs(p_to - p_from) <= p_step) {
		return p_to;
	}
	return p_from + (p_to > p_from ? p_step : -p_step);
}

// The short way around from one heading to another.
double angle_difference(double p_from, double p_to) {
	const double difference = std::fmod(p_to - p_from + HALF_CIRCLE, FULL_CIRCLE);
	return (difference < 0.0 ? difference + FULL_CIRCLE : difference) - HALF_CIRCLE;
}

} // namespace

void AeroBody::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_outline", "polygons", "spacing"), &AeroBody::set_outline);
	ClassDB::bind_method(D_METHOD("get_segment_count"), &AeroBody::get_segment_count);
	ClassDB::bind_method(D_METHOD("get_segments"), &AeroBody::get_segments);
	ClassDB::bind_method(D_METHOD("set_pressure_coefficient", "value"), &AeroBody::set_pressure_coefficient);
	ClassDB::bind_method(D_METHOD("get_pressure_coefficient"), &AeroBody::get_pressure_coefficient);
	ClassDB::bind_method(D_METHOD("set_mass", "mass", "spin_resistance", "center"), &AeroBody::set_mass);
	ClassDB::bind_method(D_METHOD("set_rcs", "turn_acceleration", "can_turn_clockwise", "can_turn_back"), &AeroBody::set_rcs);
	ClassDB::bind_method(D_METHOD("measure", "density", "velocity_x", "velocity_y", "heading", "spin"), &AeroBody::measure);
	ClassDB::bind_method(D_METHOD("step", "dt", "density", "velocity_x", "velocity_y", "heading", "spin", "control", "control_value"), &AeroBody::step);
	ClassDB::bind_method(D_METHOD("snapshot"), &AeroBody::snapshot);
	ClassDB::bind_method(D_METHOD("drag_held", "off_airflow"), &AeroBody::drag_held);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "pressure_coefficient"), "set_pressure_coefficient", "get_pressure_coefficient");

	BIND_ENUM_CONSTANT(CONTROL_NONE);
	BIND_ENUM_CONSTANT(CONTROL_TURN);
	BIND_ENUM_CONSTANT(CONTROL_STEER);
	BIND_ENUM_CONSTANT(CONTROL_DAMP);

	BIND_ENUM_CONSTANT(STEP_VELOCITY_X);
	BIND_ENUM_CONSTANT(STEP_VELOCITY_Y);
	BIND_ENUM_CONSTANT(STEP_HEADING);
	BIND_ENUM_CONSTANT(STEP_SPIN);
	BIND_ENUM_CONSTANT(STEP_RCS_FIRING);
	BIND_ENUM_CONSTANT(STEP_RCS_USE);
	BIND_ENUM_CONSTANT(STEP_HEAT);
	BIND_ENUM_CONSTANT(STEP_HOT_X);
	BIND_ENUM_CONSTANT(STEP_HOT_Y);
	BIND_ENUM_CONSTANT(STEP_TORQUE);
	BIND_ENUM_CONSTANT(STEP_FORCE_X);
	BIND_ENUM_CONSTANT(STEP_FORCE_Y);
	BIND_ENUM_CONSTANT(STEP_OVERPOWERED);
	BIND_ENUM_CONSTANT(STEP_SUBSTEPS);
	BIND_ENUM_CONSTANT(STEP_SIZE);
}

void AeroBody::set_outline(const Array &p_polygons, double p_spacing) {
	segments.clear();
	polygons.clear();
	const double spacing = std::max(p_spacing, 0.5);

	for (int64_t i = 0; i < p_polygons.size(); i++) {
		const PackedVector2Array points = p_polygons[i];
		Polygon polygon;
		for (int64_t j = 0; j < points.size(); j++) {
			const double x = points[j].x;
			const double y = points[j].y;
			// A shape may come closed, ending on its first corner, or with a corner twice.
			if (!polygon.x.empty() && polygon.x.back() == x && polygon.y.back() == y) {
				continue;
			}
			polygon.x.push_back(x);
			polygon.y.push_back(y);
		}
		if (polygon.x.size() > 1 && polygon.x.front() == polygon.x.back() && polygon.y.front() == polygon.y.back()) {
			polygon.x.pop_back();
			polygon.y.pop_back();
		}
		const size_t count = polygon.x.size();
		if (count < 3) {
			continue;
		}

		double doubled_area = 0.0;
		for (size_t j = 0; j < count; j++) {
			const size_t next = (j + 1) % count;
			doubled_area += polygon.x[j] * polygon.y[next] - polygon.x[next] * polygon.y[j];
			polygon.middle_x += polygon.x[j] / count;
			polygon.middle_y += polygon.y[j] / count;
		}
		if (std::abs(doubled_area) < 2.0 * SMALLEST_AREA) {
			continue;
		}
		// Whichever way around the corners go, each edge's facing points out of the shape.
		const double outward = doubled_area > 0.0 ? 1.0 : -1.0;

		const int polygon_index = static_cast<int>(polygons.size());
		for (size_t j = 0; j < count; j++) {
			const size_t next = (j + 1) % count;
			const double edge_x = polygon.x[next] - polygon.x[j];
			const double edge_y = polygon.y[next] - polygon.y[j];
			const double length = std::sqrt(edge_x * edge_x + edge_y * edge_y);
			const double normal_x = outward * edge_y / length;
			const double normal_y = -outward * edge_x / length;
			polygon.normal_x.push_back(normal_x);
			polygon.normal_y.push_back(normal_y);
			const double from_middle_x = polygon.x[j] - polygon.middle_x;
			const double from_middle_y = polygon.y[j] - polygon.middle_y;
			polygon.reach = std::max(polygon.reach, std::sqrt(from_middle_x * from_middle_x + from_middle_y * from_middle_y));

			const int pieces = std::max(1, static_cast<int>(std::ceil(length / spacing)));
			for (int piece = 0; piece < pieces; piece++) {
				const double along = (piece + 0.5) / pieces;
				Segment segment;
				segment.x = polygon.x[j] + edge_x * along;
				segment.y = polygon.y[j] + edge_y * along;
				segment.normal_x = normal_x;
				segment.normal_y = normal_y;
				segment.length = length / pieces;
				segment.polygon = polygon_index;
				segments.push_back(segment);
			}
		}
		polygons.push_back(polygon);
	}
}

int AeroBody::get_segment_count() const {
	return static_cast<int>(segments.size());
}

PackedFloat64Array AeroBody::get_segments() const {
	PackedFloat64Array result;
	result.resize(static_cast<int64_t>(segments.size()) * 5);
	double *values = result.ptrw();
	for (size_t i = 0; i < segments.size(); i++) {
		values[i * 5] = segments[i].x;
		values[i * 5 + 1] = segments[i].y;
		values[i * 5 + 2] = segments[i].normal_x;
		values[i * 5 + 3] = segments[i].normal_y;
		values[i * 5 + 4] = segments[i].length;
	}
	return result;
}

void AeroBody::set_mass(double p_mass, double p_spin_resistance, const Vector2 &p_center) {
	mass = std::max(p_mass, 1e-6);
	spin_resistance = std::max(p_spin_resistance, 1e-6);
	center_x = p_center.x;
	center_y = p_center.y;
}

void AeroBody::set_rcs(double p_turn_acceleration, bool p_can_turn_clockwise, bool p_can_turn_back) {
	turn_acceleration = std::max(p_turn_acceleration, 0.0);
	can_turn_clockwise = p_can_turn_clockwise;
	can_turn_back = p_can_turn_back;
}

bool AeroBody::is_shadowed(const Segment &p_segment, double p_way_x, double p_way_y) const {
	for (size_t index = 0; index < polygons.size(); index++) {
		if (static_cast<int>(index) == p_segment.polygon) {
			// A layer's own outline bulges outward everywhere, so it can't shade itself.
			continue;
		}
		const Polygon &polygon = polygons[index];
		const double to_middle_x = polygon.middle_x - p_segment.x;
		const double to_middle_y = polygon.middle_y - p_segment.y;
		const double ahead = to_middle_x * p_way_x + to_middle_y * p_way_y;
		if (ahead < -polygon.reach) {
			continue;
		}
		const double aside_squared = to_middle_x * to_middle_x + to_middle_y * to_middle_y - ahead * ahead;
		if (aside_squared > polygon.reach * polygon.reach) {
			continue;
		}

		// Follow a line from the piece into the oncoming air, and see whether it passes through
		// the other shape: it's inside for as long as it's behind every one of its edges.
		double enters = -INFINITY;
		double leaves = INFINITY;
		bool misses = false;
		for (size_t edge = 0; edge < polygon.x.size(); edge++) {
			const double outside = (p_segment.x - polygon.x[edge]) * polygon.normal_x[edge] + (p_segment.y - polygon.y[edge]) * polygon.normal_y[edge];
			const double closing = p_way_x * polygon.normal_x[edge] + p_way_y * polygon.normal_y[edge];
			if (std::abs(closing) < 1e-12) {
				if (outside > 0.0) {
					misses = true;
					break;
				}
			} else if (closing > 0.0) {
				leaves = std::min(leaves, -outside / closing);
			} else {
				enters = std::max(enters, -outside / closing);
			}
		}
		if (!misses && leaves - std::max(enters, 0.0) > 1e-6) {
			return true;
		}
	}
	return false;
}

AeroBody::Loads AeroBody::loads_at(double p_velocity_x, double p_velocity_y, double p_spin, double p_density) const {
	Loads loads;
	if (p_density <= 0.0) {
		return loads;
	}
	const double pressure = 0.5 * pressure_coefficient * p_density;
	const bool can_shade = polygons.size() > 1;
	double hottest = 0.0;
	for (const Segment &segment : segments) {
		const double lever_x = segment.x - center_x;
		const double lever_y = segment.y - center_y;
		// The air this piece meets: the ship's own motion, plus the piece swinging around as it turns.
		const double through_x = p_velocity_x - p_spin * lever_y;
		const double through_y = p_velocity_y + p_spin * lever_x;
		const double into = through_x * segment.normal_x + through_y * segment.normal_y;
		if (into <= 0.0) {
			continue;
		}
		const double speed_squared = through_x * through_x + through_y * through_y;
		if (can_shade) {
			const double speed = std::sqrt(speed_squared);
			if (is_shadowed(segment, through_x / speed, through_y / speed)) {
				continue;
			}
		}
		const double push = pressure * into * into * segment.length;
		const double push_x = -push * segment.normal_x;
		const double push_y = -push * segment.normal_y;
		loads.force_x += push_x;
		loads.force_y += push_y;
		loads.torque += lever_x * push_y - lever_y * push_x;

		const double heating = speed_squared * into;
		hottest = std::max(hottest, heating);
		loads.hot_x += heating * segment.length * segment.normal_x;
		loads.hot_y += heating * segment.length * segment.normal_y;
	}
	loads.heat = std::sqrt(p_density) * hottest;
	const double hot_length = std::sqrt(loads.hot_x * loads.hot_x + loads.hot_y * loads.hot_y);
	if (hot_length > 0.0) {
		loads.hot_x /= hot_length;
		loads.hot_y /= hot_length;
	}
	return loads;
}

double AeroBody::steady_step(double p_speed, double p_spin, double p_density) const {
	if (p_density <= 0.0 || segments.empty()) {
		return BASE_STEP;
	}
	double outline = 0.0;
	double levers = 0.0;
	double levers_squared = 0.0;
	double farthest = 0.0;
	for (const Segment &segment : segments) {
		const double lever_x = segment.x - center_x;
		const double lever_y = segment.y - center_y;
		const double lever_squared = lever_x * lever_x + lever_y * lever_y;
		const double lever = std::sqrt(lever_squared);
		outline += segment.length;
		levers += segment.length * lever;
		levers_squared += segment.length * lever_squared;
		farthest = std::max(farthest, lever);
	}
	// Upper limits on how fast the air can brake the ship, slow its spin, and swing it.
	const double strength = pressure_coefficient * p_density;
	const double fastest_piece = p_speed + std::abs(p_spin) * farthest;
	const double braking = strength * fastest_piece * outline / mass;
	const double damping = strength * fastest_piece * levers_squared / spin_resistance;
	const double swinging = std::sqrt(strength * fastest_piece * fastest_piece * levers / spin_resistance);
	const double quickest = std::max(braking, std::max(damping, swinging));
	if (quickest <= 0.0 || !std::isfinite(quickest)) {
		return BASE_STEP;
	}
	return std::min(BASE_STEP, STEP_SHARE / quickest);
}

void AeroBody::advance(Motion &r_motion, double p_dt, double p_density, int p_control, double p_control_value, Report &r_report) const {
	r_report = Report();
	if (p_dt <= 0.0 || !std::isfinite(p_dt)) {
		return;
	}
	const bool in_air = p_density > 0.0 && !segments.empty();
	const bool steering = p_control != CONTROL_NONE && turn_acceleration > 0.0;

	int substeps = 1;
	if (in_air || steering) {
		const int base_steps = std::max(1, static_cast<int>(std::ceil(p_dt / BASE_STEP - 1e-9)));
		const double speed = std::sqrt(r_motion.velocity_x * r_motion.velocity_x + r_motion.velocity_y * r_motion.velocity_y);
		const double steady = in_air ? steady_step(speed, r_motion.spin, p_density) : BASE_STEP;
		const int splits = std::max(1, static_cast<int>(std::ceil(p_dt / base_steps / steady - 1e-9)));
		substeps = static_cast<int>(std::min<int64_t>(static_cast<int64_t>(base_steps) * splits, MAX_SUBSTEPS));
	}
	const double h = p_dt / substeps;
	r_report.substeps = substeps;

	double hot_x = 0.0;
	double hot_y = 0.0;
	for (int i = 0; i < substeps; i++) {
		const Motion before = r_motion;
		double air_turning = 0.0;
		if (in_air) {
			const double cos_heading = std::cos(r_motion.heading);
			const double sin_heading = std::sin(r_motion.heading);
			// Into the ship's own frame, where its outline is.
			const double own_x = r_motion.velocity_x * cos_heading + r_motion.velocity_y * sin_heading;
			const double own_y = -r_motion.velocity_x * sin_heading + r_motion.velocity_y * cos_heading;
			const Loads loads = loads_at(own_x, own_y, r_motion.spin, p_density);
			const double force_x = loads.force_x * cos_heading - loads.force_y * sin_heading;
			const double force_y = loads.force_x * sin_heading + loads.force_y * cos_heading;
			r_motion.velocity_x += force_x / mass * h;
			r_motion.velocity_y += force_y / mass * h;
			r_motion.spin += loads.torque / spin_resistance * h;

			// The air only ever takes energy from the ship's motion through it. If a step this
			// long would hand some back, shrink it to what the ship had.
			const double energy_before = mass * (before.velocity_x * before.velocity_x + before.velocity_y * before.velocity_y) + spin_resistance * before.spin * before.spin;
			const double energy_after = mass * (r_motion.velocity_x * r_motion.velocity_x + r_motion.velocity_y * r_motion.velocity_y) + spin_resistance * r_motion.spin * r_motion.spin;
			if (energy_after > energy_before && energy_after > 0.0) {
				const double keep = std::sqrt(energy_before / energy_after);
				r_motion.velocity_x *= keep;
				r_motion.velocity_y *= keep;
				r_motion.spin *= keep;
			}
			if (!std::isfinite(r_motion.velocity_x) || !std::isfinite(r_motion.velocity_y) || !std::isfinite(r_motion.spin)) {
				r_motion = before;
			}
			air_turning = (r_motion.spin - before.spin) / h;

			r_report.heat += loads.heat / substeps;
			hot_x += loads.hot_x * loads.heat;
			hot_y += loads.hot_y * loads.heat;
			r_report.torque = loads.torque;
			r_report.force_x = force_x;
			r_report.force_y = force_y;
		}

		if (steering) {
			const double most = turn_acceleration * h;
			const double spin_before_rcs = r_motion.spin;
			double wanted_spin = 0.0;
			bool holding = false;
			switch (p_control) {
				case CONTROL_TURN:
					r_motion.spin += std::clamp(p_control_value, -1.0, 1.0) * most;
					break;
				case CONTROL_STEER: {
					// Turn toward the heading as fast as still leaves room to stop on it.
					const double error = angle_difference(r_motion.heading, p_control_value);
					const double braking_limit = std::sqrt(2.0 * turn_acceleration * std::abs(error));
					wanted_spin = (error < 0.0 ? -1.0 : 1.0) * std::min(braking_limit, std::abs(error) * 4.0);
					holding = true;
				} break;
				case CONTROL_DAMP:
					holding = true;
					break;
				default:
					break;
			}
			if (holding) {
				r_motion.spin = move_toward(r_motion.spin, wanted_spin, most);
			}
			// The left nozzle turns the nose clockwise and the right one back, so a lost one can't
			// push its way.
			const double change = r_motion.spin - spin_before_rcs;
			if ((change > 0.0 && !can_turn_clockwise) || (change < 0.0 && !can_turn_back)) {
				r_motion.spin = spin_before_rcs;
			}
			const double fired = (r_motion.spin - spin_before_rcs) / most;
			r_report.rcs_firing += fired / substeps;
			r_report.rcs_use += std::abs(fired) / substeps;

			// Holding and losing: the RCS is flat out against the air and still can't get the turn
			// it wants, because the air turns the ship as hard as it can, or harder. That covers
			// being thrown round and being pinned at an angle it can't push back from.
			if (holding) {
				const double short_by = wanted_spin - spin_before_rcs;
				if (std::abs(short_by) > most * (1.0 + 1e-9) && air_turning * short_by < 0.0 && std::abs(air_turning) >= OVERPOWERED_SHARE * turn_acceleration) {
					r_report.overpowered += h;
				}
			}
		}

		r_motion.heading += r_motion.spin * h;
	}

	const double hot_length = std::sqrt(hot_x * hot_x + hot_y * hot_y);
	if (hot_length > 0.0) {
		r_report.hot_x = hot_x / hot_length;
		r_report.hot_y = hot_y / hot_length;
	}
}

Ref<AeroBody> AeroBody::snapshot() const {
	Ref<AeroBody> copy;
	copy.instantiate();
	copy->segments = segments;
	copy->polygons = polygons;
	copy->pressure_coefficient = pressure_coefficient;
	copy->mass = mass;
	copy->spin_resistance = spin_resistance;
	copy->center_x = center_x;
	copy->center_y = center_y;
	copy->turn_acceleration = turn_acceleration;
	copy->can_turn_clockwise = can_turn_clockwise;
	copy->can_turn_back = can_turn_back;
	return copy;
}

double AeroBody::drag_held(double p_off_airflow) const {
	// Nose first, the ship moves up its own art. Held off that, it moves that much round from it.
	const double own_x = std::sin(-p_off_airflow);
	const double own_y = -std::cos(-p_off_airflow);
	const Loads loads = loads_at(own_x, own_y, 0.0, 1.0);
	return -(loads.force_x * own_x + loads.force_y * own_y);
}

void AeroBody::advance_held(Motion &r_motion, double p_dt, double p_density, double p_off_airflow) const {
	if (p_dt <= 0.0 || !std::isfinite(p_dt) || p_density <= 0.0 || segments.empty()) {
		return;
	}
	const int base_steps = std::max(1, static_cast<int>(std::ceil(p_dt / BASE_STEP - 1e-9)));
	const double speed = std::sqrt(r_motion.velocity_x * r_motion.velocity_x + r_motion.velocity_y * r_motion.velocity_y);
	const int splits = std::max(1, static_cast<int>(std::ceil(p_dt / base_steps / steady_step(speed, 0.0, p_density) - 1e-9)));
	const int substeps = static_cast<int>(std::min<int64_t>(static_cast<int64_t>(base_steps) * splits, MAX_SUBSTEPS));
	const double h = p_dt / substeps;
	// Held at one angle to the air, the push on the ship is always the same way round from the way
	// it's going, and only grows with the square of its speed.
	const double own_x = std::sin(-p_off_airflow);
	const double own_y = -std::cos(-p_off_airflow);
	const Loads loads = loads_at(own_x, own_y, 0.0, p_density);
	const double along = loads.force_x * own_x + loads.force_y * own_y;
	const double across = -loads.force_x * own_y + loads.force_y * own_x;
	for (int i = 0; i < substeps; i++) {
		const double now_squared = r_motion.velocity_x * r_motion.velocity_x + r_motion.velocity_y * r_motion.velocity_y;
		const double now = std::sqrt(now_squared);
		if (now <= 0.0) {
			break;
		}
		const double way_x = r_motion.velocity_x / now;
		const double way_y = r_motion.velocity_y / now;
		// Never past a dead stop in one step.
		const double slowing = std::max(along * now_squared / mass * h, -now);
		const double sideways = across * now_squared / mass * h;
		double next_x = r_motion.velocity_x + way_x * slowing - way_y * sideways;
		double next_y = r_motion.velocity_y + way_y * slowing + way_x * sideways;
		const double next_squared = next_x * next_x + next_y * next_y;
		if (next_squared > now_squared && next_squared > 0.0) {
			const double keep = std::sqrt(now_squared / next_squared);
			next_x *= keep;
			next_y *= keep;
		}
		if (std::isfinite(next_x) && std::isfinite(next_y)) {
			r_motion.velocity_x = next_x;
			r_motion.velocity_y = next_y;
		}
	}
	r_motion.heading = std::atan2(r_motion.velocity_x, -r_motion.velocity_y) + p_off_airflow;
	r_motion.spin = 0.0;
}

PackedFloat64Array AeroBody::pack(const Motion &p_motion, double p_start_x, double p_start_y, const Report &p_report) const {
	PackedFloat64Array result;
	result.resize(STEP_SIZE);
	double *values = result.ptrw();
	values[STEP_VELOCITY_X] = p_motion.velocity_x - p_start_x;
	values[STEP_VELOCITY_Y] = p_motion.velocity_y - p_start_y;
	values[STEP_HEADING] = p_motion.heading;
	values[STEP_SPIN] = p_motion.spin;
	values[STEP_RCS_FIRING] = p_report.rcs_firing;
	values[STEP_RCS_USE] = p_report.rcs_use;
	values[STEP_HEAT] = p_report.heat;
	values[STEP_HOT_X] = p_report.hot_x;
	values[STEP_HOT_Y] = p_report.hot_y;
	values[STEP_TORQUE] = p_report.torque;
	values[STEP_FORCE_X] = p_report.force_x;
	values[STEP_FORCE_Y] = p_report.force_y;
	values[STEP_OVERPOWERED] = p_report.overpowered;
	values[STEP_SUBSTEPS] = p_report.substeps;
	return result;
}

PackedFloat64Array AeroBody::measure(double p_density, double p_velocity_x, double p_velocity_y, double p_heading, double p_spin) const {
	const double cos_heading = std::cos(p_heading);
	const double sin_heading = std::sin(p_heading);
	const Loads loads = loads_at(p_velocity_x * cos_heading + p_velocity_y * sin_heading, -p_velocity_x * sin_heading + p_velocity_y * cos_heading, p_spin, p_density);
	Motion motion;
	motion.heading = p_heading;
	motion.spin = p_spin;
	Report report;
	report.heat = loads.heat;
	report.hot_x = loads.hot_x;
	report.hot_y = loads.hot_y;
	report.torque = loads.torque;
	report.force_x = loads.force_x * cos_heading - loads.force_y * sin_heading;
	report.force_y = loads.force_x * sin_heading + loads.force_y * cos_heading;
	return pack(motion, 0.0, 0.0, report);
}

PackedFloat64Array AeroBody::step(double p_dt, double p_density, double p_velocity_x, double p_velocity_y, double p_heading, double p_spin, int p_control, double p_control_value) const {
	Motion motion;
	motion.velocity_x = p_velocity_x;
	motion.velocity_y = p_velocity_y;
	motion.heading = p_heading;
	motion.spin = p_spin;
	Report report;
	advance(motion, p_dt, p_density, p_control, p_control_value, report);
	return pack(motion, p_velocity_x, p_velocity_y, report);
}

} // namespace final_orbit
