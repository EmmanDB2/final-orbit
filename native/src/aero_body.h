// aero_body.h: how the air pushes on a ship, piece by piece of its outline.
// From DESIGN.md, "Physics" (Aerodynamics: the air pushes on each exposed part of the outline, by
// how squarely it faces the airflow, and the pushes add up to drag, lift, and a turning force
// around the live center of mass).
//
// The outline is one closed shape per layer of the ship, cut into short straight pieces that each
// know which way they face. A piece feels the air it's moving into: the ship's speed through the
// air plus the piece's own speed from the ship turning. If that carries it into the air, and no
// other layer stands in the way, the air pushes straight back along the way it faces, by the
// square of how fast it meets it. Nothing here knows what a nose or a tail is. Which end leads,
// how hard it's to turn, and how fast a spin dies all come from the shape and where the mass is.
//
// It also flies the ship's turning for a tick: the air's turning force and the RCS together, in
// short steps so a long tick under time warp stays steady. The RCS's rules live here so the real
// flight and the landing prediction can't drift apart.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <vector>

namespace final_orbit {

class AeroBody : public godot::RefCounted {
	GDCLASS(AeroBody, godot::RefCounted)

public:
	// What the RCS is doing with the ship's turning.
	enum Control {
		// Nothing: the ship turns as it's pushed.
		CONTROL_NONE = 0,
		// The pilot's turn keys: the value is how hard, from -1 to 1.
		CONTROL_TURN = 1,
		// Turn to a heading and stop there: the value is the heading, in radians.
		CONTROL_STEER = 2,
		// Stop any spin.
		CONTROL_DAMP = 3,
	};

	// Where each number is in what step() and measure() give back.
	enum StepResult {
		// How the air changed the ship's velocity, in the world.
		STEP_VELOCITY_X = 0,
		STEP_VELOCITY_Y = 1,
		STEP_HEADING = 2,
		STEP_SPIN = 3,
		// How much the RCS fired over the step, as a share of flat out: with its sign, positive
		// for clockwise, and without.
		STEP_RCS_FIRING = 4,
		STEP_RCS_USE = 5,
		// Heating on the hottest piece: the square root of the air's density times its speed
		// cubed, less for a glancing hit. Then which way the heated side faces, on the art.
		STEP_HEAT = 6,
		STEP_HOT_X = 7,
		STEP_HOT_Y = 8,
		// The air's turning force at the end of the step, and its push, in the world.
		STEP_TORQUE = 9,
		STEP_FORCE_X = 10,
		STEP_FORCE_Y = 11,
		// Seconds of the step the air out-turned an RCS that was trying to hold.
		STEP_OVERPOWERED = 12,
		STEP_SUBSTEPS = 13,
		STEP_SIZE = 14,
	};

	// The ship's turning and its velocity through the air, in the world.
	struct Motion {
		double velocity_x = 0.0;
		double velocity_y = 0.0;
		double heading = 0.0;
		double spin = 0.0;
	};

	// What the air did over one step.
	struct Report {
		double rcs_firing = 0.0;
		double rcs_use = 0.0;
		double heat = 0.0;
		double hot_x = 0.0;
		double hot_y = 0.0;
		double torque = 0.0;
		double force_x = 0.0;
		double force_y = 0.0;
		double overpowered = 0.0;
		int substeps = 0;
	};

	// The outline, one closed shape per layer, in art pixels from the middle of the ship's grid.
	// Each is cut into pieces about p_spacing long. Call again whenever the shape changes.
	void set_outline(const godot::Array &p_polygons, double p_spacing);
	int get_segment_count() const;
	// Every piece, flat [x, y, facing x, facing y, length, ...], for tests.
	godot::PackedFloat64Array get_segments() const;

	// How hard the air pushes on a piece that meets it squarely: 2.0 stops every bit of air that
	// hits it.
	void set_pressure_coefficient(double p_value) { pressure_coefficient = p_value; }
	double get_pressure_coefficient() const { return pressure_coefficient; }

	// The ship's mass, how hard it is to spin, and its center of mass on the art, all as they are
	// right now.
	void set_mass(double p_mass, double p_spin_resistance, const godot::Vector2 &p_center);
	// How quickly the RCS changes the spin, in radians per second squared, and which ways it still
	// can.
	void set_rcs(double p_turn_acceleration, bool p_can_turn_clockwise, bool p_can_turn_back);

	// The air's push on the ship as it is, without moving it: the same list as step(), with the
	// velocity and RCS entries zero.
	godot::PackedFloat64Array measure(double p_density, double p_velocity_x, double p_velocity_y, double p_heading, double p_spin) const;
	// Flies the ship's turning and the air's push for p_dt seconds. The velocity is the ship's
	// through the air, in the world.
	godot::PackedFloat64Array step(double p_dt, double p_density, double p_velocity_x, double p_velocity_y, double p_heading, double p_spin, int p_control, double p_control_value) const;

	// The same step on plain numbers, for the landing prediction.
	void advance(Motion &r_motion, double p_dt, double p_density, int p_control, double p_control_value, Report &r_report) const;

protected:
	static void _bind_methods();

private:
	struct Segment {
		double x = 0.0;
		double y = 0.0;
		double normal_x = 0.0;
		double normal_y = 0.0;
		double length = 0.0;
		int polygon = 0;
	};

	struct Polygon {
		// Corners in order, and the way each edge from a corner to the next faces.
		std::vector<double> x;
		std::vector<double> y;
		std::vector<double> normal_x;
		std::vector<double> normal_y;
		double middle_x = 0.0;
		double middle_y = 0.0;
		double reach = 0.0;
	};

	// The air's push in the ship's own frame.
	struct Loads {
		double force_x = 0.0;
		double force_y = 0.0;
		double torque = 0.0;
		double heat = 0.0;
		double hot_x = 0.0;
		double hot_y = 0.0;
	};

	// Whether another layer stands between a piece and the air it's moving into.
	bool is_shadowed(const Segment &p_segment, double p_way_x, double p_way_y) const;
	Loads loads_at(double p_velocity_x, double p_velocity_y, double p_spin, double p_density) const;
	// The longest step that stays steady for this much air and speed.
	double steady_step(double p_speed, double p_spin, double p_density) const;
	godot::PackedFloat64Array pack(const Motion &p_motion, double p_start_x, double p_start_y, const Report &p_report) const;

	std::vector<Segment> segments;
	std::vector<Polygon> polygons;
	double pressure_coefficient = 1.8;
	double mass = 1.0;
	double spin_resistance = 1.0;
	double center_x = 0.0;
	double center_y = 0.0;
	double turn_acceleration = 0.0;
	bool can_turn_clockwise = true;
	bool can_turn_back = true;
};

} // namespace final_orbit

VARIANT_ENUM_CAST(final_orbit::AeroBody::Control);
VARIANT_ENUM_CAST(final_orbit::AeroBody::StepResult);
