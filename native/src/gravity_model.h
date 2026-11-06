// gravity_model.h: the one interface the game uses for gravity and the bodies that make it.
// From DESIGN.md, "Physics" (Gravity model interface). PatchedConicsModel ships first;
// NBodyModel can plug in later, and nothing else in the game knows which is running.
//
// Bodies are numbered, and body 0 is the center of the system, fixed at the world origin.
#pragma once

#include "ship_state.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
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

protected:
	static void _bind_methods();
};

} // namespace final_orbit
