// gravity_model.h: the one interface the game uses for gravity and the bodies that make it.
// From DESIGN.md, "Physics" (Gravity model interface). PatchedConicsModel ships first;
// NBodyModel can plug in later, and nothing else in the game knows which is running.
//
// Bodies are numbered, and body 0 is the center of the system, fixed at the world origin.
#pragma once

#include "aero_body.h"
#include "ship_state.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

namespace final_orbit {

class GravityModel : public godot::RefCounted {
	GDCLASS(GravityModel, godot::RefCounted)

public:
	// Gravity's pull at a point, as [x, y] in 64-bit.
	virtual godot::PackedFloat64Array get_acceleration(double p_x, double p_y, double p_time) const = 0;

	// Moves the state forward by p_dt seconds of coasting.
	virtual void propagate(const godot::Ref<ShipState> &p_state, double p_dt) const = 0;

	// Where the ship will coast over the next p_duration seconds, without changing it.
	// Flat [x0, y0, x1, y1, ...]. It ends at a surface, when a closed orbit comes all the
	// way around, or on leaving the current body's influence.
	//
	// Around a body that moves, the path is drawn around that body as it is now, because
	// that's what a pilot needs to read. A coming encounter is drawn around the body as
	// it will be at that moment, which find_encounter gives the time of.
	virtual godot::PackedFloat64Array predict_trajectory(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples) const = 0;

	// How far each point of predict_trajectory is above where its body's landing zone
	// starts, in the same order. Negative means inside it. That's the top of the
	// atmosphere, or a set height on an airless body.
	virtual godot::PackedFloat64Array predict_entry_heights(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples) const = 0;

	// The next time the ship's coast takes it under another body's gravity, as
	// [seconds from now, body index]. Empty if there isn't one.
	virtual godot::PackedFloat64Array find_encounter(const godot::Ref<ShipState> &p_state, double p_duration) const = 0;

	virtual int get_body_count() const = 0;
	// The body this one orbits. -1 for body 0, which orbits nothing.
	virtual int get_body_parent(int p_index) const = 0;
	// The planet a body belongs to: itself, or the planet a moon circles. Body 0 is its own.
	int get_local_root(int p_index) const;
	// Where a body is at a moment in time, as [x, y]. Bodies move on rails, computed from
	// the time, so this works for any moment without simulating up to it.
	virtual godot::PackedFloat64Array get_body_position(int p_index, double p_time) const = 0;
	// How a body is moving at a moment in time, as [x, y].
	virtual godot::PackedFloat64Array get_body_velocity(int p_index, double p_time) const = 0;
	virtual double get_body_radius(int p_index) const = 0;
	// How fast a body turns, in radians per second. Positive is clockwise on screen.
	virtual double get_body_spin(int p_index) const = 0;
	// How high a body's landing zone starts above its base radius: the top of its air, or a set
	// height on an airless body.
	virtual double get_entry_altitude(int p_index) const = 0;
	// The body whose gravity applies at this point and time.
	virtual int get_dominant_body(double p_x, double p_y, double p_time) const = 0;
	// How far a body's gravity dominates. Zero for a body with no limit, such as body 0.
	virtual double get_sphere_of_influence(int p_index) const = 0;
	// The low and high points of the ship's current orbit, as heights above the dominant
	// body's surface: [periapsis, apoapsis]. Apoapsis is -1 on a path that never comes back.
	virtual godot::PackedFloat64Array get_orbit_apsides(const godot::Ref<ShipState> &p_state) const = 0;
	// Height above the ground of the dominant body.
	virtual double get_altitude(double p_x, double p_y, double p_time) const = 0;
	// How fast the ground of the dominant body is moving under this point, as [x, y]. This
	// is the one place ground speed comes from. Spin only counts inside the body's landing
	// zone: higher up, this is just how the body itself is moving.
	virtual godot::PackedFloat64Array get_surface_velocity(double p_x, double p_y, double p_time) const = 0;
	// How high the ground of the dominant body is under this point, above its base radius.
	virtual double get_ground_height(double p_x, double p_y, double p_time) const = 0;
	// Which column of its rim's ground the dominant body has under this point. It stays the same
	// for a point fixed to the ground as the body turns.
	virtual double get_ground_column(double p_x, double p_y, double p_time) const = 0;
	// The highest a body's ground ever gets above its base radius.
	virtual double get_highest_ground(int p_index) const = 0;
	// A stretch of a body's rim for drawing or for checking what a ship is touching, flat
	// [height, map color band, height, ...]. Starts at a column and steps by p_step columns,
	// leaving out bumps narrower than a step.
	virtual godot::PackedFloat32Array get_ground_strip(int p_index, int64_t p_first_column, int64_t p_step, int p_count) const = 0;
	// A far-off line of mountains for drawing behind the skyline, flat [height, height, ...]. It
	// goes around the body at p_loop_share of the ground's speed, so it seems far away.
	virtual godot::PackedFloat32Array get_distant_ridge(int p_index, double p_first_column, double p_step, int p_count, double p_loop_share) const = 0;
	// How thick the air is at this point: 1.0 is the home planet's ground, and 0 is no air.
	virtual double get_air_density(double p_x, double p_y, double p_time) const = 0;
	// One lap of a body's rails around its parent, relative to the parent, flat
	// [x0, y0, x1, y1, ...]. Empty for body 0.
	virtual godot::PackedFloat64Array get_body_orbit_path(int p_index, int p_samples) const = 0;

	// Satellites are small things on rails around a body, like stations. They have no gravity, so
	// they change nothing around them, and they're numbered apart from the bodies.
	virtual int get_satellite_count() const = 0;
	// The body a satellite orbits.
	virtual int get_satellite_parent(int p_index) const = 0;
	// Where a satellite is at a moment in time, as [x, y].
	virtual godot::PackedFloat64Array get_satellite_position(int p_index, double p_time) const = 0;
	// How a satellite is moving at a moment in time, as [x, y].
	virtual godot::PackedFloat64Array get_satellite_velocity(int p_index, double p_time) const = 0;
	// One lap of a satellite's rails, relative to its parent, flat [x0, y0, x1, y1, ...].
	virtual godot::PackedFloat64Array get_satellite_orbit_path(int p_index, int p_samples) const = 0;

	// The headings STAB can hold for a ship here, moving like this: along its path around the body
	// it's orbiting, against it, toward that body, and away from it, in that order. Inside the
	// body's landing zone the path is measured against the turning ground, like the speed readout
	// and the dial, so against the path is what a landing burn cancels; higher up, against the body.
	godot::PackedFloat64Array get_hold_headings(double p_x, double p_y, double p_velocity_x, double p_velocity_y, double p_time) const;

	// Flies a ship's coast ahead with no more burns, to say where and how it comes down. Above any
	// air it coasts exactly. Through air it's flown step by step with the same pushes as the real
	// flight, turning as the air and its RCS turn it. Two more runs, held at the angles to the air
	// that slow it least and most, bound where it could come down. Nothing here is changed, so it
	// can run on another thread, given copies of the state and the ship's AeroBody.
	//
	// p_flight says how the ship is now: "heading", "spin", "control" (an AeroBody control, STEER
	// meaning STAB), "hold" (which of the hold headings), "rcs_fuel", "rcs_fuel_rate",
	// "heat_limit", "hull_heat_seconds", "hull_temperature", "star_heat", and "stance_columns" (how
	// far to each side it stands on the ground).
	//
	// The answer has "lands" and "air" (whether any of it was through air). With air it has the
	// "path" flown from the top of the air, flat [x, y, ...] from the body's middle, with each
	// point's "times". The path is drawn against the turning ground as it is at "ground_time", so
	// it ends on the ground the ship comes down on, and "spin" is how fast that ground turns.
	// A landing adds its "end" [x, y] the same way, its "speed" against the ground, the ground's
	// "rise" across the ship's stance there, the "peak_hull" temperature on the way, and the
	// landing zone from "zone_from" to "zone_to": angles around the body, clockwise from the top
	// of the screen, in the same ground frame. On an airless body the end is where it is in space
	// at touchdown, and "spin" is zero.
	godot::Dictionary predict_descent(const godot::Ref<ShipState> &p_state, const godot::Ref<AeroBody> &p_aero, const godot::Dictionary &p_flight, double p_horizon, int p_samples) const;

protected:
	static void _bind_methods();

private:
	// How one run of a descent is flown, and what came of it.
	struct DescentRun {
		// Held at an angle to the air, or free to turn.
		bool held = false;
		double held_off_airflow = 0.0;
		AeroBody::Motion motion;
		int control = AeroBody::CONTROL_NONE;
		int hold = 0;
		double rcs_fuel = 0.0;
		double rcs_fuel_rate = 0.0;
		double heat_limit = 1.0;
		double hull_heat_seconds = 1.0;
		double hull_temperature = 0.0;
		double star_heat = 0.0;

		bool met_air = false;
		bool landed = false;
		double peak_hull = 0.0;
		double speed = 0.0;
		// The moment it met the air, to start the other runs from.
		godot::Ref<ShipState> entry;
		// Where it went from the top of the air on, from the body's middle, with the time at each.
		std::vector<double> xs;
		std::vector<double> ys;
		std::vector<double> times;
	};

	void fly_descent(const godot::Ref<ShipState> &p_state, const AeroBody &p_aero, int p_body, double p_horizon, DescentRun &r_run) const;
};

} // namespace final_orbit
