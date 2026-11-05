// gravity_model.h: the one interface the game uses for gravity.
// From DESIGN.md, "Physics" (Gravity model interface). PatchedConicsModel ships first;
// NBodyModel can plug in later, and nothing else in the game knows which is running.
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
	// Flat [x0, y0, x1, y1, ...]. It stops early if the path hits a surface, ending exactly
	// on it, or once a closed orbit has come all the way around.
	virtual godot::PackedFloat64Array predict_trajectory(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples) const = 0;

protected:
	static void _bind_methods();
};

} // namespace final_orbit
