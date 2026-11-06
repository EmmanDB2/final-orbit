#include "patched_conics_model.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace final_orbit {

namespace {

// Longest piece of a coast between surface checks, in seconds. Only used on paths
// that can actually reach the surface, so normal orbits stay one exact step.
constexpr double MAX_IMPACT_CHECK_STEP = 0.25;
// Shortest jump between sphere of influence checks, in seconds.
constexpr double MIN_SOI_CHECK_STEP = 0.25;
// Extra caution on how fast a sphere of influence could be coming up.
constexpr double SOI_STEP_MARGIN = 1.2;
constexpr int MAX_WALK_STEPS = 20000;
constexpr int MAX_SOLVER_ITERATIONS = 64;
constexpr double SOLVER_TOLERANCE = 1e-12;
constexpr int MAX_BISECTIONS = 48;
constexpr double FULL_CIRCLE = 6.283185307179586476925286766559;
constexpr double HALF_CIRCLE = FULL_CIRCLE / 2.0;

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
	ClassDB::bind_method(D_METHOD("set_central_body", "mu", "radius", "entry_altitude"), &PatchedConicsModel::set_central_body, DEFVAL(0.0));
	ClassDB::bind_method(D_METHOD("add_body", "parent", "mu", "radius", "semi_major_axis", "eccentricity", "argument_of_periapsis", "mean_anomaly_at_start", "entry_altitude"), &PatchedConicsModel::add_body, DEFVAL(0.0));
	ClassDB::bind_method(D_METHOD("set_body_spin", "index", "rate"), &PatchedConicsModel::set_body_spin);
}

void PatchedConicsModel::set_central_body(double p_mu, double p_radius, double p_entry_altitude) {
	bodies[0].mu = p_mu;
	bodies[0].radius = p_radius;
	bodies[0].entry_altitude = p_entry_altitude;
}

int PatchedConicsModel::add_body(int p_parent, double p_mu, double p_radius, double p_semi_major_axis, double p_eccentricity, double p_argument_of_periapsis, double p_mean_anomaly_at_start, double p_entry_altitude) {
	ERR_FAIL_INDEX_V(p_parent, static_cast<int>(bodies.size()), -1);
	const double parent_mu = bodies[p_parent].mu;
	Body body;
	body.parent = p_parent;
	body.mu = p_mu;
	body.radius = p_radius;
	body.entry_altitude = p_entry_altitude;
	body.semi_major_axis = p_semi_major_axis;
	body.eccentricity = p_eccentricity;
	body.argument_of_periapsis = p_argument_of_periapsis;
	body.mean_anomaly_at_start = p_mean_anomaly_at_start;
	body.mean_motion = std::sqrt(parent_mu / (p_semi_major_axis * p_semi_major_axis * p_semi_major_axis));
	body.sphere_of_influence = p_semi_major_axis * std::pow(p_mu / parent_mu, 0.4);
	bodies.push_back(body);
	return static_cast<int>(bodies.size()) - 1;
}

void PatchedConicsModel::set_body_spin(int p_index, double p_rate) {
	ERR_FAIL_INDEX(p_index, static_cast<int>(bodies.size()));
	bodies[p_index].spin_rate = p_rate;
}

PatchedConicsModel::State2D PatchedConicsModel::body_state(int p_index, double p_time) const {
	State2D result;
	if (p_index >= static_cast<int>(bodies.size())) {
		return result;
	}
	for (int index = p_index; index > 0; index = bodies[index].parent) {
		const State2D rail = rail_state(index, p_time);
		result.x += rail.x;
		result.y += rail.y;
		result.vx += rail.vx;
		result.vy += rail.vy;
	}
	return result;
}

PatchedConicsModel::State2D PatchedConicsModel::rail_state(int p_index, double p_time) const {
	State2D result;
	if (p_index <= 0 || p_index >= static_cast<int>(bodies.size())) {
		return result;
	}

	const Body &body = bodies[p_index];
	double mean_anomaly = std::fmod(body.mean_anomaly_at_start + body.mean_motion * p_time, FULL_CIRCLE);
	if (mean_anomaly > HALF_CIRCLE) {
		mean_anomaly -= FULL_CIRCLE;
	} else if (mean_anomaly < -HALF_CIRCLE) {
		mean_anomaly += FULL_CIRCLE;
	}

	// Kepler's equation for an ellipse. Moons are close to circular, so this settles fast.
	const double e = body.eccentricity;
	double eccentric_anomaly = mean_anomaly;
	for (int i = 0; i < 16; i++) {
		const double step = (eccentric_anomaly - e * std::sin(eccentric_anomaly) - mean_anomaly) / (1.0 - e * std::cos(eccentric_anomaly));
		eccentric_anomaly -= step;
		if (std::abs(step) < 1e-14) {
			break;
		}
	}

	const double cos_e = std::cos(eccentric_anomaly);
	const double sin_e = std::sin(eccentric_anomaly);
	const double squeeze = std::sqrt(1.0 - e * e);
	const double a = body.semi_major_axis;
	const double along = a * (cos_e - e);
	const double across = a * squeeze * sin_e;
	const double r = a * (1.0 - e * cos_e);
	const double rate = std::sqrt(bodies[body.parent].mu * a) / r;
	const double speed_along = -rate * sin_e;
	const double speed_across = rate * squeeze * cos_e;

	const double cos_w = std::cos(body.argument_of_periapsis);
	const double sin_w = std::sin(body.argument_of_periapsis);
	result.x = along * cos_w - across * sin_w;
	result.y = along * sin_w + across * cos_w;
	result.vx = speed_along * cos_w - speed_across * sin_w;
	result.vy = speed_along * sin_w + speed_across * cos_w;
	return result;
}

int PatchedConicsModel::dominant_body(double p_x, double p_y, double p_time) const {
	// Start at the center and go inward for as long as a child's sphere holds the point.
	int current = 0;
	bool went_inward = true;
	while (went_inward) {
		went_inward = false;
		for (int i = 1; i < static_cast<int>(bodies.size()); i++) {
			if (bodies[i].parent != current) {
				continue;
			}
			const State2D child = body_state(i, p_time);
			const double dx = p_x - child.x;
			const double dy = p_y - child.y;
			const double soi = bodies[i].sphere_of_influence;
			if (dx * dx + dy * dy < soi * soi) {
				current = i;
				went_inward = true;
				break;
			}
		}
	}
	return current;
}

PackedFloat64Array PatchedConicsModel::get_acceleration(double p_x, double p_y, double p_time) const {
	PackedFloat64Array result;
	result.resize(2);
	result.set(0, 0.0);
	result.set(1, 0.0);

	const int index = dominant_body(p_x, p_y, p_time);
	const State2D body = body_state(index, p_time);
	const double dx = p_x - body.x;
	const double dy = p_y - body.y;
	const double r_squared = dx * dx + dy * dy;
	if (r_squared > 0.0) {
		const double r = std::sqrt(r_squared);
		const double scale = -bodies[index].mu / (r_squared * r);
		result.set(0, dx * scale);
		result.set(1, dy * scale);
	}
	return result;
}

PatchedConicsModel::Conic PatchedConicsModel::make_conic(const State2D &p_state, double p_mu) const {
	Conic conic;
	conic.start = p_state;
	conic.mu = p_mu;
	conic.r0 = std::sqrt(p_state.x * p_state.x + p_state.y * p_state.y);
	conic.sqrt_mu = std::sqrt(p_mu);
	if (conic.r0 > 0.0) {
		const double speed_squared = p_state.vx * p_state.vx + p_state.vy * p_state.vy;
		conic.alpha = 2.0 / conic.r0 - speed_squared / p_mu;
		conic.sigma0 = (p_state.x * p_state.vx + p_state.y * p_state.vy) / conic.sqrt_mu;
	}
	return conic;
}

double PatchedConicsModel::solve_chi(const Conic &p_conic, double p_dt) const {
	const double r0 = p_conic.r0;
	const double sqrt_mu = p_conic.sqrt_mu;
	const double alpha = p_conic.alpha;
	const double sigma0 = p_conic.sigma0;

	double chi;
	if (alpha > 1e-12) {
		chi = sqrt_mu * p_dt * alpha;
	} else if (alpha < -1e-12) {
		const double a = 1.0 / alpha;
		const double sign = p_dt > 0.0 ? 1.0 : -1.0;
		const double inner = -2.0 * p_conic.mu * alpha * p_dt / (sigma0 * sqrt_mu + sign * std::sqrt(-p_conic.mu * a) * (1.0 - r0 * alpha));
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
	for (int i = 0; i < MAX_SOLVER_ITERATIONS; i++) {
		const double z = alpha * chi * chi;
		stumpff(z, c, s);
		const double one_minus = 1.0 - alpha * r0;
		const double f = sigma0 * chi * chi * c + one_minus * chi * chi * chi * s + r0 * chi - sqrt_mu * p_dt;
		const double df = sigma0 * chi * (1.0 - z * s) + one_minus * chi * chi * c + r0;
		const double ddf = sigma0 * (1.0 - z * c) + one_minus * chi * (1.0 - z * s);
		const double root = std::sqrt(std::abs((N - 1.0) * (N - 1.0) * df * df - N * (N - 1.0) * f * ddf));
		const double denominator = df > 0.0 ? df + root : df - root;
		const double step = N * f / denominator;
		chi -= step;
		if (std::abs(step) <= SOLVER_TOLERANCE * (1.0 + std::abs(chi))) {
			break;
		}
	}
	return chi;
}

double PatchedConicsModel::time_at(const Conic &p_conic, double p_chi) const {
	double c;
	double s;
	stumpff(p_conic.alpha * p_chi * p_chi, c, s);
	const double chi_squared = p_chi * p_chi;
	return (p_conic.sigma0 * chi_squared * c + (1.0 - p_conic.alpha * p_conic.r0) * chi_squared * p_chi * s + p_conic.r0 * p_chi) / p_conic.sqrt_mu;
}

void PatchedConicsModel::position_at(const Conic &p_conic, double p_chi, double p_dt, double &r_x, double &r_y) const {
	double c;
	double s;
	stumpff(p_conic.alpha * p_chi * p_chi, c, s);
	const double lagrange_f = 1.0 - p_chi * p_chi * c / p_conic.r0;
	const double lagrange_g = p_dt - p_chi * p_chi * p_chi * s / p_conic.sqrt_mu;
	r_x = lagrange_f * p_conic.start.x + lagrange_g * p_conic.start.vx;
	r_y = lagrange_f * p_conic.start.y + lagrange_g * p_conic.start.vy;
}

PatchedConicsModel::State2D PatchedConicsModel::coast(const State2D &p_state, double p_dt, double p_mu) const {
	const Conic conic = make_conic(p_state, p_mu);
	if (p_dt == 0.0 || conic.r0 == 0.0) {
		return p_state;
	}

	const double chi = solve_chi(conic, p_dt);

	State2D result;
	position_at(conic, chi, p_dt, result.x, result.y);

	double c;
	double s;
	const double z = conic.alpha * chi * chi;
	stumpff(z, c, s);
	const double r1 = std::sqrt(result.x * result.x + result.y * result.y);
	const double lagrange_fdot = conic.sqrt_mu * chi * (z * s - 1.0) / (r1 * conic.r0);
	const double lagrange_gdot = 1.0 - chi * chi * c / r1;
	result.vx = lagrange_fdot * p_state.x + lagrange_gdot * p_state.vx;
	result.vy = lagrange_fdot * p_state.y + lagrange_gdot * p_state.vy;
	return result;
}

double PatchedConicsModel::periapsis_radius(const State2D &p_state, double p_mu) const {
	const double r = std::sqrt(p_state.x * p_state.x + p_state.y * p_state.y);
	if (r == 0.0) {
		return 0.0;
	}
	const double h = p_state.x * p_state.vy - p_state.y * p_state.vx;
	const double energy = 0.5 * (p_state.vx * p_state.vx + p_state.vy * p_state.vy) - p_mu / r;
	const double eccentricity = std::sqrt(std::max(0.0, 1.0 + 2.0 * energy * h * h / (p_mu * p_mu)));
	return (h * h / p_mu) / (1.0 + eccentricity);
}

double PatchedConicsModel::peak_speed(const State2D &p_state, const Body &p_body) const {
	const double r = std::sqrt(p_state.x * p_state.x + p_state.y * p_state.y);
	if (r == 0.0) {
		return 0.0;
	}
	const double speed_squared = p_state.vx * p_state.vx + p_state.vy * p_state.vy;
	const double alpha = 2.0 / r - speed_squared / p_body.mu;
	const double lowest = std::max(std::max(periapsis_radius(p_state, p_body.mu), p_body.radius), 1.0);
	return std::sqrt(std::max(0.0, p_body.mu * (2.0 / lowest - alpha)));
}

void PatchedConicsModel::ground_velocity_on_body(const Body &p_body, double p_x, double p_y, double &r_vx, double &r_vy) const {
	r_vx = -p_body.spin_rate * p_y;
	r_vy = p_body.spin_rate * p_x;
}

bool PatchedConicsModel::coast_to_surface(State2D &r_state, double p_dt, const Body &p_body, double p_clearance, double &r_touchdown_speed) const {
	const double contact = p_body.radius + p_clearance;
	int pieces = 1;
	if (contact > 0.0 && periapsis_radius(r_state, p_body.mu) < contact) {
		pieces = std::max(1, static_cast<int>(std::ceil(std::abs(p_dt) / MAX_IMPACT_CHECK_STEP)));
	}
	const double piece_dt = p_dt / pieces;
	for (int i = 0; i < pieces; i++) {
		r_state = coast(r_state, piece_dt, p_body.mu);
		const double r = std::sqrt(r_state.x * r_state.x + r_state.y * r_state.y);
		if (r < contact) {
			if (r > 0.0) {
				r_state.x *= contact / r;
				r_state.y *= contact / r;
			} else {
				r_state.y = -contact;
			}
			double ground_vx;
			double ground_vy;
			ground_velocity_on_body(p_body, r_state.x, r_state.y, ground_vx, ground_vy);
			r_touchdown_speed = std::sqrt((r_state.vx - ground_vx) * (r_state.vx - ground_vx) + (r_state.vy - ground_vy) * (r_state.vy - ground_vy));
			r_state.vx = ground_vx;
			r_state.vy = ground_vy;
			return true;
		}
	}
	return false;
}

double PatchedConicsModel::safe_step(const State2D &p_world, double p_time, int p_body) const {
	const State2D origin = body_state(p_body, p_time);
	State2D relative;
	relative.x = p_world.x - origin.x;
	relative.y = p_world.y - origin.y;
	relative.vx = p_world.vx - origin.vx;
	relative.vy = p_world.vy - origin.vy;
	const double peak = peak_speed(relative, bodies[p_body]);

	double step = INFINITY;
	if (p_body != 0 && peak > 0.0) {
		const double r = std::sqrt(relative.x * relative.x + relative.y * relative.y);
		step = (bodies[p_body].sphere_of_influence - r) / (peak * SOI_STEP_MARGIN);
	}
	for (int i = 1; i < static_cast<int>(bodies.size()); i++) {
		if (bodies[i].parent != p_body) {
			continue;
		}
		const State2D child = body_state(i, p_time);
		const double gap = std::sqrt((p_world.x - child.x) * (p_world.x - child.x) + (p_world.y - child.y) * (p_world.y - child.y)) - bodies[i].sphere_of_influence;
		const double child_vx = child.vx - origin.vx;
		const double child_vy = child.vy - origin.vy;
		const double closing = peak + std::sqrt(child_vx * child_vx + child_vy * child_vy);
		if (closing > 0.0) {
			step = std::min(step, gap / (closing * SOI_STEP_MARGIN));
		}
	}
	return std::max(step, MIN_SOI_CHECK_STEP);
}

void PatchedConicsModel::propagate(const Ref<ShipState> &p_state, double p_dt) const {
	ERR_FAIL_COND(p_state.is_null());

	State2D world;
	world.x = p_state->x;
	world.y = p_state->y;
	world.vx = p_state->velocity_x;
	world.vy = p_state->velocity_y;

	const double direction = p_dt < 0.0 ? -1.0 : 1.0;
	double remaining = std::abs(p_dt);
	double time = p_state->time;
	bool on_surface = false;
	double touchdown_speed = p_state->touchdown_speed;

	for (int step = 0; remaining > 0.0 && step < MAX_WALK_STEPS; step++) {
		const int index = dominant_body(world.x, world.y, time);
		const double h = std::min(remaining, safe_step(world, time, index));

		const State2D origin = body_state(index, time);
		State2D relative;
		relative.x = world.x - origin.x;
		relative.y = world.y - origin.y;
		relative.vx = world.vx - origin.vx;
		relative.vy = world.vy - origin.vy;

		on_surface = coast_to_surface(relative, direction * h, bodies[index], p_state->ground_clearance, touchdown_speed);
		time += direction * h;
		remaining -= h;

		// A ship on the surface rides along with the body for the rest of the step.
		if (on_surface && remaining > 0.0) {
			time += direction * remaining;
			remaining = 0.0;
		}

		const State2D new_origin = body_state(index, time);
		world.x = relative.x + new_origin.x;
		world.y = relative.y + new_origin.y;
		world.vx = relative.vx + new_origin.vx;
		world.vy = relative.vy + new_origin.vy;
	}

	p_state->on_surface = on_surface;
	p_state->touchdown_speed = touchdown_speed;
	p_state->x = world.x;
	p_state->y = world.y;
	p_state->velocity_x = world.vx;
	p_state->velocity_y = world.vy;
	p_state->time = p_state->time + p_dt;
}

bool PatchedConicsModel::segment_event(const State2D &p_relative, int p_body, double p_time, double p_clearance, SegmentEnd &r_end) const {
	const Body &body = bodies[p_body];
	const double r_squared = p_relative.x * p_relative.x + p_relative.y * p_relative.y;
	const double contact = body.radius + p_clearance;

	if (r_squared < contact * contact) {
		r_end.reason = SegmentEndReason::IMPACT;
		return true;
	}
	if (p_body != 0 && r_squared > body.sphere_of_influence * body.sphere_of_influence) {
		r_end.reason = SegmentEndReason::LEFT_BODY;
		r_end.next_body = body.parent;
		return true;
	}

	const State2D origin = body_state(p_body, p_time);
	for (int i = 1; i < static_cast<int>(bodies.size()); i++) {
		if (bodies[i].parent != p_body) {
			continue;
		}
		const State2D child = body_state(i, p_time);
		const double dx = p_relative.x + origin.x - child.x;
		const double dy = p_relative.y + origin.y - child.y;
		const double soi = bodies[i].sphere_of_influence;
		if (dx * dx + dy * dy < soi * soi) {
			r_end.reason = SegmentEndReason::ENCOUNTER;
			r_end.next_body = i;
			return true;
		}
	}
	return false;
}

PatchedConicsModel::SegmentEnd PatchedConicsModel::walk_segment(const State2D &p_relative, int p_body, double p_start_time, double p_horizon, double p_clearance) const {
	const Body &body = bodies[p_body];
	const Conic conic = make_conic(p_relative, body.mu);

	SegmentEnd end;
	double limit = p_horizon;
	if (conic.alpha > 1e-12) {
		const double lap = time_at(conic, FULL_CIRCLE / std::sqrt(conic.alpha));
		if (lap <= limit) {
			limit = lap;
			end.reason = SegmentEndReason::LAP;
		}
	}

	const double contact = body.radius + p_clearance;
	const bool can_hit_surface = contact > 0.0 && periapsis_radius(p_relative, body.mu) < contact;
	double elapsed = 0.0;
	for (int step = 0; step < MAX_WALK_STEPS && elapsed < limit; step++) {
		const State2D here = coast(p_relative, elapsed, body.mu);
		const State2D origin = body_state(p_body, p_start_time + elapsed);
		State2D world;
		world.x = here.x + origin.x;
		world.y = here.y + origin.y;
		world.vx = here.vx + origin.vx;
		world.vy = here.vy + origin.vy;

		double h = std::min(limit - elapsed, safe_step(world, p_start_time + elapsed, p_body));
		if (can_hit_surface) {
			// It can't reach the surface any sooner than flat out in a straight line.
			const double r = std::sqrt(here.x * here.x + here.y * here.y);
			h = std::min(h, std::max(1.0, (r - contact) / std::max(peak_speed(here, body), 1.0)));
		}

		const double next = elapsed + h;
		SegmentEnd event = end;
		if (segment_event(coast(p_relative, next, body.mu), p_body, p_start_time + next, p_clearance, event)) {
			// Something changed during this jump, so narrow down when.
			double before = elapsed;
			double after = next;
			for (int i = 0; i < MAX_BISECTIONS; i++) {
				const double middle = 0.5 * (before + after);
				SegmentEnd probe = end;
				if (segment_event(coast(p_relative, middle, body.mu), p_body, p_start_time + middle, p_clearance, probe)) {
					after = middle;
				} else {
					before = middle;
				}
			}
			event.duration = after;
			return event;
		}
		elapsed = next;
	}

	end.duration = elapsed;
	return end;
}

void PatchedConicsModel::sample_segment(PackedFloat64Array *r_points, PackedFloat64Array *r_heights, const State2D &p_relative, int p_body, const SegmentEnd &p_end, double p_origin_x, double p_origin_y, int p_count, double p_clearance) const {
	const Body &body = bodies[p_body];
	const Conic conic = make_conic(p_relative, body.mu);
	const double contact = body.radius + p_clearance;
	if (conic.r0 == 0.0) {
		return;
	}

	// Samples are even in chi rather than in time. A ship crawls through the far end of
	// an ellipse and rushes through the near end, so even time steps would bunch up
	// where it's straightest and spread out where it curves hardest.
	const double end_chi = p_end.reason == SegmentEndReason::LAP ? FULL_CIRCLE / std::sqrt(conic.alpha) : solve_chi(conic, p_end.duration);

	for (int i = 0; i < p_count; i++) {
		const double chi = p_count > 1 ? end_chi * i / (p_count - 1) : 0.0;
		double x;
		double y;
		position_at(conic, chi, time_at(conic, chi), x, y);

		// Land exactly on the surface.
		if (i == p_count - 1 && p_end.reason == SegmentEndReason::IMPACT) {
			const double r = std::sqrt(x * x + y * y);
			if (r > 0.0) {
				x *= contact / r;
				y *= contact / r;
			}
		}
		if (r_points) {
			r_points->push_back(x + p_origin_x);
			r_points->push_back(y + p_origin_y);
		}
		if (r_heights) {
			r_heights->push_back(std::sqrt(x * x + y * y) - body.radius - body.entry_altitude);
		}
	}
}

void PatchedConicsModel::build_path(const Ref<ShipState> &p_state, double p_duration, int p_samples, PackedFloat64Array *r_points, PackedFloat64Array *r_heights) const {
	const double now = p_state->time;
	const double clearance = p_state->ground_clearance;
	const int index = dominant_body(p_state->x, p_state->y, now);
	const State2D origin = body_state(index, now);
	State2D relative;
	relative.x = p_state->x - origin.x;
	relative.y = p_state->y - origin.y;
	relative.vx = p_state->velocity_x - origin.vx;
	relative.vy = p_state->velocity_y - origin.vy;

	if (p_duration <= 0.0) {
		SegmentEnd nothing;
		sample_segment(r_points, r_heights, relative, index, nothing, origin.x, origin.y, 1, clearance);
		return;
	}

	const SegmentEnd first = walk_segment(relative, index, now, p_duration, clearance);
	if (first.reason != SegmentEndReason::ENCOUNTER) {
		sample_segment(r_points, r_heights, relative, index, first, origin.x, origin.y, p_samples, clearance);
		return;
	}

	// Two thirds of the line for the way there, and the rest for the flyby. The flyby is
	// drawn around the other body as it will be at the moment the ship arrives, seen from
	// the current body, which is drawn where it is now.
	const int first_count = std::max(2, p_samples * 2 / 3);
	sample_segment(r_points, r_heights, relative, index, first, origin.x, origin.y, first_count, clearance);

	const double arrival = now + first.duration;
	const State2D at_arrival = coast(relative, first.duration, bodies[index].mu);
	const State2D origin_then = body_state(index, arrival);
	const State2D moon = body_state(first.next_body, arrival);
	State2D around_moon;
	around_moon.x = at_arrival.x + origin_then.x - moon.x;
	around_moon.y = at_arrival.y + origin_then.y - moon.y;
	around_moon.vx = at_arrival.vx + origin_then.vx - moon.vx;
	around_moon.vy = at_arrival.vy + origin_then.vy - moon.vy;

	const SegmentEnd second = walk_segment(around_moon, first.next_body, arrival, std::max(p_duration - first.duration, 1.0), clearance);
	sample_segment(r_points, r_heights, around_moon, first.next_body, second, moon.x - origin_then.x + origin.x, moon.y - origin_then.y + origin.y, std::max(2, p_samples - first_count), clearance);
}

PackedFloat64Array PatchedConicsModel::predict_trajectory(const Ref<ShipState> &p_state, double p_duration, int p_samples) const {
	PackedFloat64Array points;
	ERR_FAIL_COND_V(p_state.is_null(), points);
	ERR_FAIL_COND_V(p_samples < 2, points);
	build_path(p_state, p_duration, p_samples, &points, nullptr);
	return points;
}

PackedFloat64Array PatchedConicsModel::predict_entry_heights(const Ref<ShipState> &p_state, double p_duration, int p_samples) const {
	PackedFloat64Array heights;
	ERR_FAIL_COND_V(p_state.is_null(), heights);
	ERR_FAIL_COND_V(p_samples < 2, heights);
	build_path(p_state, p_duration, p_samples, nullptr, &heights);
	return heights;
}

PackedFloat64Array PatchedConicsModel::find_encounter(const Ref<ShipState> &p_state, double p_duration) const {
	PackedFloat64Array result;
	ERR_FAIL_COND_V(p_state.is_null(), result);

	const double now = p_state->time;
	const int index = dominant_body(p_state->x, p_state->y, now);
	if (p_duration <= 0.0) {
		return result;
	}

	const State2D origin = body_state(index, now);
	State2D relative;
	relative.x = p_state->x - origin.x;
	relative.y = p_state->y - origin.y;
	relative.vx = p_state->velocity_x - origin.vx;
	relative.vy = p_state->velocity_y - origin.vy;

	const SegmentEnd end = walk_segment(relative, index, now, p_duration, p_state->ground_clearance);
	if (end.reason == SegmentEndReason::ENCOUNTER) {
		result.push_back(end.duration);
		result.push_back(end.next_body);
	}
	return result;
}

double PatchedConicsModel::get_altitude(double p_x, double p_y, double p_time) const {
	const int index = dominant_body(p_x, p_y, p_time);
	const State2D body = body_state(index, p_time);
	const double dx = p_x - body.x;
	const double dy = p_y - body.y;
	return std::sqrt(dx * dx + dy * dy) - bodies[index].radius;
}

PackedFloat64Array PatchedConicsModel::get_surface_velocity(double p_x, double p_y, double p_time) const {
	const int index = dominant_body(p_x, p_y, p_time);
	const State2D body = body_state(index, p_time);
	const double dx = p_x - body.x;
	const double dy = p_y - body.y;
	double ground_vx = 0.0;
	double ground_vy = 0.0;
	if (std::sqrt(dx * dx + dy * dy) - bodies[index].radius <= bodies[index].entry_altitude) {
		ground_velocity_on_body(bodies[index], dx, dy, ground_vx, ground_vy);
	}

	PackedFloat64Array result;
	result.push_back(body.vx + ground_vx);
	result.push_back(body.vy + ground_vy);
	return result;
}

int PatchedConicsModel::get_body_count() const {
	return static_cast<int>(bodies.size());
}

int PatchedConicsModel::get_body_parent(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, static_cast<int>(bodies.size()), -1);
	return bodies[p_index].parent;
}

PackedFloat64Array PatchedConicsModel::get_body_position(int p_index, double p_time) const {
	PackedFloat64Array result;
	const State2D state = body_state(p_index, p_time);
	result.push_back(state.x);
	result.push_back(state.y);
	return result;
}

PackedFloat64Array PatchedConicsModel::get_body_velocity(int p_index, double p_time) const {
	PackedFloat64Array result;
	const State2D state = body_state(p_index, p_time);
	result.push_back(state.vx);
	result.push_back(state.vy);
	return result;
}

PackedFloat64Array PatchedConicsModel::get_orbit_apsides(const Ref<ShipState> &p_state) const {
	PackedFloat64Array result;
	ERR_FAIL_COND_V(p_state.is_null(), result);

	const int index = dominant_body(p_state->x, p_state->y, p_state->time);
	const Body &body = bodies[index];
	const State2D origin = body_state(index, p_state->time);
	State2D relative;
	relative.x = p_state->x - origin.x;
	relative.y = p_state->y - origin.y;
	relative.vx = p_state->velocity_x - origin.vx;
	relative.vy = p_state->velocity_y - origin.vy;

	const Conic conic = make_conic(relative, body.mu);
	const double periapsis = periapsis_radius(relative, body.mu);
	result.push_back(periapsis - body.radius);
	result.push_back(conic.alpha > 1e-12 ? 2.0 / conic.alpha - periapsis - body.radius : -1.0);
	return result;
}

double PatchedConicsModel::get_body_radius(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, static_cast<int>(bodies.size()), 0.0);
	return bodies[p_index].radius;
}

int PatchedConicsModel::get_dominant_body(double p_x, double p_y, double p_time) const {
	return dominant_body(p_x, p_y, p_time);
}

double PatchedConicsModel::get_sphere_of_influence(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, static_cast<int>(bodies.size()), 0.0);
	return bodies[p_index].sphere_of_influence;
}

PackedFloat64Array PatchedConicsModel::get_body_orbit_path(int p_index, int p_samples) const {
	PackedFloat64Array points;
	ERR_FAIL_INDEX_V(p_index, static_cast<int>(bodies.size()), points);
	ERR_FAIL_COND_V(p_samples < 2, points);
	if (p_index == 0) {
		return points;
	}

	const double period = FULL_CIRCLE / bodies[p_index].mean_motion;
	for (int i = 0; i < p_samples; i++) {
		const State2D state = rail_state(p_index, period * i / (p_samples - 1));
		points.push_back(state.x);
		points.push_back(state.y);
	}
	return points;
}

} // namespace final_orbit
