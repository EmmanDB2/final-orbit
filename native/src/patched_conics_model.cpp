#include "patched_conics_model.h"

#include <godot_cpp/core/class_db.hpp>

#include <cmath>

using namespace godot;

namespace final_orbit {

namespace {

// Longest piece of a coast between surface checks, in seconds. Only used on paths
// that can actually reach the surface, so normal orbits stay one exact step.
constexpr double MAX_IMPACT_CHECK_STEP = 0.25;
constexpr int MAX_SOLVER_ITERATIONS = 64;
constexpr double SOLVER_TOLERANCE = 1e-12;

// The Stumpff functions C(z) and S(z) from the universal variable equations. Close to
// zero the closed forms divide by almost nothing, so a short series takes over.
void stumpff(double p_z, double &r_c, double &r_s) {
	if (std::abs(p_z) < 1e-6) {
		r_c = 0.5 - p_z / 24.0 + p_z * p_z / 720.0;
		r_s = 1.0 / 6.0 - p_z / 120.0 + p_z * p_z / 5040.0;
	} else if (p_z > 0.0) {
		const double root = std::sqrt(p_z);
		r_c = (1.0 - std::cos(root)) / p_z;
		r_s = (root - std::sin(root)) / (root * p_z);
	} else {
		const double root = std::sqrt(-p_z);
		r_c = (std::cosh(root) - 1.0) / -p_z;
		r_s = (std::sinh(root) - root) / (root * -p_z);
	}
}

} // namespace

void PatchedConicsModel::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_central_body", "mu", "radius"), &PatchedConicsModel::set_central_body);
}

void PatchedConicsModel::set_central_body(double p_mu, double p_radius) {
	mu = p_mu;
	radius = p_radius;
}

PackedFloat64Array PatchedConicsModel::get_acceleration(double p_x, double p_y, double p_time) const {
	PackedFloat64Array result;
	result.resize(2);
	const double r_squared = p_x * p_x + p_y * p_y;
	if (r_squared > 0.0) {
		const double r = std::sqrt(r_squared);
		const double scale = -mu / (r_squared * r);
		result.set(0, p_x * scale);
		result.set(1, p_y * scale);
	}
	return result;
}

PatchedConicsModel::State2D PatchedConicsModel::coast(const State2D &p_state, double p_dt) const {
	const double r0 = std::sqrt(p_state.x * p_state.x + p_state.y * p_state.y);
	if (p_dt == 0.0 || r0 == 0.0) {
		return p_state;
	}

	const double speed_squared = p_state.vx * p_state.vx + p_state.vy * p_state.vy;
	const double sqrt_mu = std::sqrt(mu);
	// Alpha is one over the semi-major axis: positive for ellipses, zero for parabolas,
	// negative for hyperbolas.
	const double alpha = 2.0 / r0 - speed_squared / mu;
	const double sigma0 = (p_state.x * p_state.vx + p_state.y * p_state.vy) / sqrt_mu;

	double chi;
	if (alpha > 1e-12) {
		chi = sqrt_mu * p_dt * alpha;
	} else if (alpha < -1e-12) {
		const double a = 1.0 / alpha;
		const double sign = p_dt > 0.0 ? 1.0 : -1.0;
		const double inner = -2.0 * mu * alpha * p_dt / (sigma0 * sqrt_mu + sign * std::sqrt(-mu * a) * (1.0 - r0 * alpha));
		chi = sign * std::sqrt(-a) * std::log(std::abs(inner));
		if (!std::isfinite(chi)) {
			chi = sqrt_mu * p_dt / r0;
		}
	} else {
		chi = sqrt_mu * p_dt / r0;
	}

	// Laguerre's method, which converges from any starting guess on this equation.
	constexpr double N = 5.0;
	double c = 0.5;
	double s = 1.0 / 6.0;
	double r = r0;
	for (int i = 0; i < MAX_SOLVER_ITERATIONS; i++) {
		const double z = alpha * chi * chi;
		stumpff(z, c, s);
		const double one_minus = 1.0 - alpha * r0;
		const double f = sigma0 * chi * chi * c + one_minus * chi * chi * chi * s + r0 * chi - sqrt_mu * p_dt;
		const double df = sigma0 * chi * (1.0 - z * s) + one_minus * chi * chi * c + r0;
		const double ddf = sigma0 * (1.0 - z * c) + one_minus * chi * (1.0 - z * s);
		r = df;
		const double root = std::sqrt(std::abs((N - 1.0) * (N - 1.0) * df * df - N * (N - 1.0) * f * ddf));
		const double denominator = df > 0.0 ? df + root : df - root;
		const double step = N * f / denominator;
		chi -= step;
		if (std::abs(step) <= SOLVER_TOLERANCE * (1.0 + std::abs(chi))) {
			break;
		}
	}

	const double z = alpha * chi * chi;
	stumpff(z, c, s);
	const double lagrange_f = 1.0 - chi * chi * c / r0;
	const double lagrange_g = p_dt - chi * chi * chi * s / sqrt_mu;

	State2D result;
	result.x = lagrange_f * p_state.x + lagrange_g * p_state.vx;
	result.y = lagrange_f * p_state.y + lagrange_g * p_state.vy;
	const double r1 = std::sqrt(result.x * result.x + result.y * result.y);
	const double lagrange_fdot = sqrt_mu * chi * (z * s - 1.0) / (r1 * r0);
	const double lagrange_gdot = 1.0 - chi * chi * c / r1;
	result.vx = lagrange_fdot * p_state.x + lagrange_gdot * p_state.vx;
	result.vy = lagrange_fdot * p_state.y + lagrange_gdot * p_state.vy;
	return result;
}

double PatchedConicsModel::periapsis_radius(const State2D &p_state) const {
	const double r = std::sqrt(p_state.x * p_state.x + p_state.y * p_state.y);
	if (r == 0.0) {
		return 0.0;
	}
	const double h = p_state.x * p_state.vy - p_state.y * p_state.vx;
	const double energy = 0.5 * (p_state.vx * p_state.vx + p_state.vy * p_state.vy) - mu / r;
	const double eccentricity = std::sqrt(std::max(0.0, 1.0 + 2.0 * energy * h * h / (mu * mu)));
	return (h * h / mu) / (1.0 + eccentricity);
}

bool PatchedConicsModel::coast_to_surface(State2D &r_state, double p_dt) const {
	int pieces = 1;
	if (radius > 0.0 && periapsis_radius(r_state) < radius) {
		pieces = std::max(1, static_cast<int>(std::ceil(std::abs(p_dt) / MAX_IMPACT_CHECK_STEP)));
	}
	const double piece_dt = p_dt / pieces;
	for (int i = 0; i < pieces; i++) {
		r_state = coast(r_state, piece_dt);
		const double r = std::sqrt(r_state.x * r_state.x + r_state.y * r_state.y);
		if (r < radius) {
			if (r > 0.0) {
				r_state.x *= radius / r;
				r_state.y *= radius / r;
			} else {
				r_state.y = -radius;
			}
			r_state.vx = 0.0;
			r_state.vy = 0.0;
			return true;
		}
	}
	return false;
}

void PatchedConicsModel::propagate(const Ref<ShipState> &p_state, double p_dt) const {
	ERR_FAIL_COND(p_state.is_null());

	State2D state;
	state.x = p_state->x;
	state.y = p_state->y;
	state.vx = p_state->velocity_x;
	state.vy = p_state->velocity_y;

	p_state->on_surface = coast_to_surface(state, p_dt);
	p_state->x = state.x;
	p_state->y = state.y;
	p_state->velocity_x = state.vx;
	p_state->velocity_y = state.vy;
	p_state->time += p_dt;
}

PackedFloat64Array PatchedConicsModel::predict_trajectory(const Ref<ShipState> &p_state, double p_duration, int p_samples) const {
	PackedFloat64Array points;
	ERR_FAIL_COND_V(p_state.is_null(), points);
	ERR_FAIL_COND_V(p_samples < 2, points);

	State2D state;
	state.x = p_state->x;
	state.y = p_state->y;
	state.vx = p_state->velocity_x;
	state.vy = p_state->velocity_y;

	points.push_back(state.x);
	points.push_back(state.y);
	const double step = p_duration / (p_samples - 1);
	for (int i = 1; i < p_samples; i++) {
		const bool hit = coast_to_surface(state, step);
		points.push_back(state.x);
		points.push_back(state.y);
		if (hit) {
			break;
		}
	}
	return points;
}

} // namespace final_orbit
