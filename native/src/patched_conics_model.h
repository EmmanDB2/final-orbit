// patched_conics_model.h: the ship feels only the dominant body's gravity.
// From DESIGN.md, "Physics" (patched conics; coasting orbits are closed-form).
//
// Coasting is solved exactly with the universal variable form of Kepler's problem,
// which handles circles, ellipses, parabolas, and hyperbolas with one set of
// equations. It doesn't add up small steps, so a time step of any size lands on the
// same orbit, and orbits don't drift over time.
//
// Tier 0 has one body, fixed at the world origin. The moon and sphere-of-influence
// switching arrive in ticket 7.
#pragma once

#include "gravity_model.h"

namespace final_orbit {

class PatchedConicsModel : public GravityModel {
	GDCLASS(PatchedConicsModel, GravityModel)

public:
	// Sets the body at the world origin. p_mu is its gravitational parameter, which is
	// surface gravity times radius squared.
	void set_central_body(double p_mu, double p_radius);

	godot::PackedFloat64Array get_acceleration(double p_x, double p_y, double p_time) const override;
	void propagate(const godot::Ref<ShipState> &p_state, double p_dt) const override;
	godot::PackedFloat64Array predict_trajectory(const godot::Ref<ShipState> &p_state, double p_duration, int p_samples) const override;

protected:
	static void _bind_methods();

private:
	struct State2D {
		double x = 0.0;
		double y = 0.0;
		double vx = 0.0;
		double vy = 0.0;
	};

	// The conic a coasting ship is on, set up from one state. Every point on it can be
	// found from a single number, chi, the "universal anomaly".
	struct Conic {
		State2D start;
		double r0 = 0.0;
		double sqrt_mu = 0.0;
		double alpha = 0.0; // One over the semi-major axis: + ellipse, 0 parabola, - hyperbola.
		double sigma0 = 0.0;
	};

	Conic make_conic(const State2D &p_state) const;
	// The chi reached after p_dt seconds. This is the part that takes iterating.
	double solve_chi(const Conic &p_conic, double p_dt) const;
	// The seconds taken to reach chi. Going this way around needs no iterating.
	double time_at(const Conic &p_conic, double p_chi) const;
	void position_at(const Conic &p_conic, double p_chi, double p_dt, double &r_x, double &r_y) const;

	// Exact coast along the conic, with no surface check.
	State2D coast(const State2D &p_state, double p_dt) const;
	// Coast that stops at the surface. Returns true if the ship hit it.
	bool coast_to_surface(State2D &r_state, double p_dt) const;
	// Closest the current conic ever gets to the body.
	double periapsis_radius(const State2D &p_state) const;

	double mu = 1.0;
	double radius = 0.0;
};

} // namespace final_orbit
