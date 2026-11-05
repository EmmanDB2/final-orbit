// ship_state.h: where a ship is and how it's moving, in 64-bit.
// From DESIGN.md, "Physics". Godot's Vector2 is only 32-bit, so this class holds
// separate doubles, and GDScript's float is a double on the other side.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace final_orbit {

class ShipState : public godot::RefCounted {
	GDCLASS(ShipState, godot::RefCounted)

public:
	double x = 0.0;
	double y = 0.0;
	double velocity_x = 0.0;
	double velocity_y = 0.0;
	double time = 0.0;
	bool on_surface = false;
	// How far the ship's center sits above the ground when it's resting there.
	double ground_clearance = 0.0;
	// Speed relative to the ground at the last moment of contact.
	double touchdown_speed = 0.0;

	double get_x() const { return x; }
	void set_x(double p_value) { x = p_value; }
	double get_y() const { return y; }
	void set_y(double p_value) { y = p_value; }
	double get_velocity_x() const { return velocity_x; }
	void set_velocity_x(double p_value) { velocity_x = p_value; }
	double get_velocity_y() const { return velocity_y; }
	void set_velocity_y(double p_value) { velocity_y = p_value; }
	double get_time() const { return time; }
	void set_time(double p_value) { time = p_value; }
	bool is_on_surface() const { return on_surface; }
	double get_ground_clearance() const { return ground_clearance; }
	void set_ground_clearance(double p_value) { ground_clearance = p_value; }
	double get_touchdown_speed() const { return touchdown_speed; }

protected:
	static void _bind_methods();
};

} // namespace final_orbit
