// gravity_model.h: the one interface the game uses for gravity and the bodies that make it.
// From DESIGN.md, "Physics" (Gravity model interface). PatchedConicsModel ships first;
// NBodyModel can plug in later, and nothing else in the game knows which is running.
//
// Bodies are numbered, and body 0 is the center of the system, fixed at the world origin.
#pragma once

#include "ship_state.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
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

	// The next time the ship's coast takes it under another body's gravity, as
	// [seconds from now, body index]. Empty if there isn't one.
	virtual godot::PackedFloat64Array find_encounter(const godot::Ref<ShipState> &p_state, double p_duration) const = 0;

	virtual int get_body_count() const = 0;
	// Where a body is at a moment in time, as [x, y]. Bodies move on rails, computed from
	// the time, so this works for any moment without simulating up to it.
	virtual godot::PackedFloat64Array get_body_position(int p_index, double p_time) const = 0;
	virtual double get_body_radius(int p_index) const = 0;
	// The body whose gravity applies at this point and time.
	virtual int get_dominant_body(double p_x, double p_y, double p_time) const = 0;
	// How far a body's gravity dominates. Zero for a body with no limit, such as body 0.
	virtual double get_sphere_of_influence(int p_index) const = 0;
	// One lap of a body's rails, flat [x0, y0, x1, y1, ...]. Empty for body 0.
	virtual godot::PackedFloat64Array get_body_orbit_path(int p_index, int p_samples) const = 0;

protected:
	static void _bind_methods();
};

} // namespace final_orbit
