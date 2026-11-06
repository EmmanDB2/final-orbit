// patched_conics_model.h: the ship feels only the dominant body's gravity.
// From DESIGN.md, "Physics" (patched conics; coasting orbits are closed-form; bodies on
// Kepler rails; each body's mass sets its gravity and sphere of influence).
//
// Coasting is solved exactly with the universal variable form of Kepler's problem,
// which handles circles, ellipses, parabolas, and hyperbolas with one set of
// equations. It doesn't add up small steps, so a time step of any size lands on the
// same orbit, and orbits don't drift over time.
//
// Bodies nest: a star at the center, planets on rails around it, moons on rails around
// those. Inside a body's sphere of influence the ship's orbit is solved around that body,
// in its moving frame. World position and velocity carry straight across each switch.
#pragma once

#include "gravity_model.h"

#include <vector>

namespace final_orbit {

class PatchedConicsModel : public GravityModel {
	GDCLASS(PatchedConicsModel, GravityModel)

public:
	// Sets body 0, fixed at the world origin. p_mu is its gravitational parameter, which
	// is surface gravity times radius squared. p_entry_altitude is the height where its
	// landing zone starts.
	void set_central_body(double p_mu, double p_radius, double p_entry_altitude = 0.0);

	// Adds a body on rails around an existing one and returns its index. Call
	// set_central_body first. Angles are in radians, and the body goes clockwise on screen,
	// the same way the ship starts.
	int add_body(int p_parent, double p_mu, double p_radius, double p_semi_major_axis, double p_eccentricity, double p_argument_of_periapsis, double p_mean_anomaly_at_start, double p_entry_altitude = 0.0);

	godot::PackedFloat64Array get_acceleration(double p_x, double p_y, double p_time) const override;
	void propagate(const godot::Ref<ShipState> &p_state, double p_dt) const override;
	godot::PackedFloat64Array predict_trajectory(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples) const override;
	godot::PackedFloat64Array predict_entry_heights(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples) const override;
	godot::PackedFloat64Array find_encounter(const godot::Ref<ShipState> &p_state, double p_duration) const override;
	double get_altitude(double p_x, double p_y, double p_time) const override;
	godot::PackedFloat64Array get_surface_velocity(double p_x, double p_y, double p_time) const override;
	int get_body_count() const override;
	int get_body_parent(int p_index) const override;
	godot::PackedFloat64Array get_body_position(int p_index, double p_time) const override;
	godot::PackedFloat64Array get_body_velocity(int p_index, double p_time) const override;
	godot::PackedFloat64Array get_orbit_apsides(const godot::Ref<ShipState> &p_state) const override;
	double get_body_radius(int p_index) const override;
	int get_dominant_body(double p_x, double p_y, double p_time) const override;
	double get_sphere_of_influence(int p_index) const override;
	godot::PackedFloat64Array get_body_orbit_path(int p_index, int p_samples) const override;

protected:
	static void _bind_methods();

private:
	struct State2D {
		double x = 0.0;
		double y = 0.0;
		double vx = 0.0;
		double vy = 0.0;
	};

	struct Body {
		double mu = 1.0;
		double radius = 0.0;
		double entry_altitude = 0.0;
		// Radians per second. Zero for now: spinning planets are Tier 1.
		double spin_rate = 0.0;
		// The body this one orbits, and its rails around it. Body 0 doesn't use these.
		int parent = -1;
		double semi_major_axis = 0.0;
		double eccentricity = 0.0;
		double argument_of_periapsis = 0.0;
		double mean_anomaly_at_start = 0.0;
		double mean_motion = 0.0;
		double sphere_of_influence = 0.0;
	};

	// The conic a coasting ship is on, set up from one state relative to its body. Every
	// point on it can be found from a single number, chi, the "universal anomaly".
	struct Conic {
		State2D start;
		double mu = 1.0;
		double r0 = 0.0;
		double sqrt_mu = 0.0;
		double alpha = 0.0; // One over the semi-major axis: + ellipse, 0 parabola, - hyperbola.
		double sigma0 = 0.0;
	};

	enum class SegmentEndReason {
		HORIZON,
		LAP,
		IMPACT,
		ENCOUNTER,
		LEFT_BODY,
	};

	struct SegmentEnd {
		SegmentEndReason reason = SegmentEndReason::HORIZON;
		double duration = 0.0;
		int next_body = 0;
	};

	Conic make_conic(const State2D &p_state, double p_mu) const;
	// The chi reached after p_dt seconds. This is the part that takes iterating.
	double solve_chi(const Conic &p_conic, double p_dt) const;
	// The seconds taken to reach chi. Going this way around needs no iterating.
	double time_at(const Conic &p_conic, double p_chi) const;
	void position_at(const Conic &p_conic, double p_chi, double p_dt, double &r_x, double &r_y) const;

	// Exact coast along the conic, with no surface check.
	State2D coast(const State2D &p_state, double p_dt, double p_mu) const;
	// Coast that stops at the body's surface. Returns true if the ship hit it, with its
	// speed relative to the ground at that moment.
	bool coast_to_surface(State2D &r_state, double p_dt, const Body &p_body, double p_clearance, double &r_touchdown_speed) const;
	// How fast the ground moves in the body's own frame, at a point relative to the body.
	void ground_velocity_on_body(const Body &p_body, double p_x, double p_y, double &r_vx, double &r_vy) const;
	// Closest the current conic ever gets to the body.
	double periapsis_radius(const State2D &p_state, double p_mu) const;
	// Fastest the ship can go on this conic above the body's surface.
	double peak_speed(const State2D &p_state, const Body &p_body) const;

	// Where a body is and how it's moving relative to its parent, computed from the time.
	State2D rail_state(int p_index, double p_time) const;
	// The same in the world, adding up its parents.
	State2D body_state(int p_index, double p_time) const;
	int dominant_body(double p_x, double p_y, double p_time) const;
	// The longest jump that can't skip over a sphere of influence.
	double safe_step(const State2D &p_world, double p_time, int p_body) const;

	// Follows a coast around one body until something changes.
	SegmentEnd walk_segment(const State2D &p_relative, int p_body, double p_start_time, double p_horizon, double p_clearance) const;
	bool segment_event(const State2D &p_relative, int p_body, double p_time, double p_clearance, SegmentEnd &r_end) const;
	void sample_segment(godot::PackedFloat64Array *r_points, godot::PackedFloat64Array *r_heights, const State2D &p_relative, int p_body, const SegmentEnd &p_end, double p_origin_x, double p_origin_y, int p_count, double p_clearance) const;
	// Fills whichever of the two arrays it's given.
	void build_path(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples, godot::PackedFloat64Array *r_points, godot::PackedFloat64Array *r_heights) const;

	std::vector<Body> bodies = { Body() };
};

} // namespace final_orbit
