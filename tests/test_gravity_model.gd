# test_gravity_model.gd: checks the physics core against known orbital results.
# From DESIGN.md, "Physics". Run after building the Mac library:
#   godot --headless --path . --script tests/test_gravity_model.gd
extends SceneTree

const MU: float = 4.5e12
const RADIUS: float = 150000.0
const LOW_ORBIT: float = 180000.0

var _checks: int = 0
var _failures: int = 0
var _model: GravityModel


func _initialize() -> void:
	var patched_conics := PatchedConicsModel.new()
	patched_conics.set_central_body(MU, RADIUS)
	_model = patched_conics

	_test_acceleration()
	_test_circular_orbit_closes()
	_test_small_steps_match_one_big_step()
	_test_long_flight_does_not_drift()
	_test_ellipse_reaches_apoapsis()
	_test_hyperbola()
	_test_parabola()
	_test_free_fall_hits_surface_on_time()
	_test_big_step_does_not_tunnel()
	_test_takeoff_from_surface()
	_test_predict_trajectory()
	_test_prediction_matches_real_flight()
	_test_prediction_stops_after_one_lap()
	_test_prediction_follows_the_curve()
	_test_prediction_of_open_path()
	_test_repeatable()
	_test_precision_far_from_body()

	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	var ok: bool = absf(actual - expected) <= tolerance
	if not ok:
		_failures += 1
	print("%s %s: got %s, expected %s, within %s" % [
			"PASS" if ok else "FAIL", label,
			String.num_scientific(actual), String.num_scientific(expected), String.num_scientific(tolerance)])


func _state(x: float, y: float, velocity_x: float, velocity_y: float) -> ShipState:
	var state := ShipState.new()
	state.x = x
	state.y = y
	state.velocity_x = velocity_x
	state.velocity_y = velocity_y
	return state


func _circular_state(r: float) -> ShipState:
	return _state(0.0, -r, sqrt(MU / r), 0.0)


func _period(semi_major_axis: float) -> float:
	return TAU * sqrt(pow(semi_major_axis, 3.0) / MU)


func _radius_of(state: ShipState) -> float:
	return sqrt(state.x * state.x + state.y * state.y)


func _speed_of(state: ShipState) -> float:
	return sqrt(state.velocity_x * state.velocity_x + state.velocity_y * state.velocity_y)


func _energy_of(state: ShipState) -> float:
	return 0.5 * _speed_of(state) * _speed_of(state) - MU / _radius_of(state)


func _angular_momentum_of(state: ShipState) -> float:
	return state.x * state.velocity_y - state.y * state.velocity_x


func _test_acceleration() -> void:
	var at_x: PackedFloat64Array = _model.get_acceleration(LOW_ORBIT, 0.0, 0.0)
	_check("gravity points inward", at_x[0], -MU / (LOW_ORBIT * LOW_ORBIT), 1e-9)
	_check("no sideways gravity", at_x[1], 0.0, 1e-12)
	var diagonal: PackedFloat64Array = _model.get_acceleration(300000.0, 400000.0, 0.0)
	var strength: float = MU / (500000.0 * 500000.0)
	_check("diagonal gravity x", diagonal[0], -strength * 0.6, 1e-9)
	_check("diagonal gravity y", diagonal[1], -strength * 0.8, 1e-9)


func _test_circular_orbit_closes() -> void:
	var state := _circular_state(LOW_ORBIT)
	var period: float = _period(LOW_ORBIT)
	_model.propagate(state, period / 2.0)
	_check("half orbit reaches far side x", state.x, 0.0, 1e-5)
	_check("half orbit reaches far side y", state.y, LOW_ORBIT, 1e-5)
	_model.propagate(state, period / 2.0)
	_check("full orbit closes x", state.x, 0.0, 1e-5)
	_check("full orbit closes y", state.y, -LOW_ORBIT, 1e-5)
	_check("clock counts the flight", state.time, period, 1e-6)
	_check("not on the surface", 1.0 if state.is_on_surface() else 0.0, 0.0, 0.0)


func _test_small_steps_match_one_big_step() -> void:
	var stepped := _state(0.0, -LOW_ORBIT, 6500.0, 300.0)
	var jumped := _state(0.0, -LOW_ORBIT, 6500.0, 300.0)
	for i in range(3600):
		_model.propagate(stepped, 1.0 / 60.0)
	_model.propagate(jumped, 60.0)
	_check("60 Hz steps match one jump, x", stepped.x, jumped.x, 1e-4)
	_check("60 Hz steps match one jump, y", stepped.y, jumped.y, 1e-4)


func _test_long_flight_does_not_drift() -> void:
	var state := _state(0.0, -LOW_ORBIT, 5600.0, 400.0)
	var energy: float = _energy_of(state)
	var angular_momentum: float = _angular_momentum_of(state)
	for i in range(216000):
		_model.propagate(state, 1.0 / 60.0)
	_check("one hour at 60 Hz keeps energy (relative)", _energy_of(state) / energy, 1.0, 1e-9)
	_check("one hour at 60 Hz keeps angular momentum (relative)", _angular_momentum_of(state) / angular_momentum, 1.0, 1e-9)


func _test_ellipse_reaches_apoapsis() -> void:
	var periapsis: float = 180000.0
	var apoapsis: float = 540000.0
	var semi_major_axis: float = (periapsis + apoapsis) / 2.0
	var speed: float = sqrt(MU * (2.0 / periapsis - 1.0 / semi_major_axis))
	var state := _state(0.0, -periapsis, speed, 0.0)
	_model.propagate(state, _period(semi_major_axis) / 2.0)
	_check("ellipse reaches apoapsis x", state.x, 0.0, 1e-4)
	_check("ellipse reaches apoapsis y", state.y, apoapsis, 1e-4)
	_check("speed at apoapsis", _speed_of(state), sqrt(MU * (2.0 / apoapsis - 1.0 / semi_major_axis)), 1e-6)


func _test_hyperbola() -> void:
	var escape_speed: float = sqrt(2.0 * MU / LOW_ORBIT)
	var state := _state(0.0, -LOW_ORBIT, escape_speed * 1.5, 0.0)
	var energy: float = _energy_of(state)
	_model.propagate(state, 2000.0)
	_check("hyperbola keeps energy (relative)", _energy_of(state) / energy, 1.0, 1e-9)
	_check("hyperbola is moving away", 1.0 if _radius_of(state) > LOW_ORBIT * 10.0 else 0.0, 1.0, 0.0)
	_model.propagate(state, -2000.0)
	_check("hyperbola runs backward to start x", state.x, 0.0, 1e-3)
	_check("hyperbola runs backward to start y", state.y, -LOW_ORBIT, 1e-3)


func _test_parabola() -> void:
	var escape_speed: float = sqrt(2.0 * MU / LOW_ORBIT)
	var state := _state(0.0, -LOW_ORBIT, escape_speed, 0.0)
	_model.propagate(state, 1000.0)
	_check("parabola keeps escape speed everywhere", _speed_of(state), sqrt(2.0 * MU / _radius_of(state)), 1e-5)
	_model.propagate(state, -1000.0)
	_check("parabola runs backward to start y", state.y, -LOW_ORBIT, 1e-3)


func _test_free_fall_hits_surface_on_time() -> void:
	var start: float = 200000.0
	var ratio: float = RADIUS / start
	var fall_time: float = sqrt(pow(start, 3.0) / (2.0 * MU)) * (acos(sqrt(ratio)) + sqrt(ratio * (1.0 - ratio)))
	var state := _state(0.0, -start, 0.0, 0.0)
	_model.propagate(state, fall_time - 0.5)
	_check("still falling just before impact", 1.0 if state.is_on_surface() else 0.0, 0.0, 0.0)
	_model.propagate(state, 1.0)
	_check("on the surface just after impact", 1.0 if state.is_on_surface() else 0.0, 1.0, 0.0)
	_check("stopped at the surface", _radius_of(state), RADIUS, 1e-6)
	_check("no speed left", _speed_of(state), 0.0, 0.0)
	for i in range(600):
		_model.propagate(state, 1.0 / 60.0)
	_check("rests on the surface", _radius_of(state), RADIUS, 1e-6)


func _test_big_step_does_not_tunnel() -> void:
	var state := _state(0.0, -LOW_ORBIT, 1000.0, 0.0)
	_model.propagate(state, 100000.0)
	_check("a huge step still hits the planet", 1.0 if state.is_on_surface() else 0.0, 1.0, 0.0)
	_check("and stops at its surface", _radius_of(state), RADIUS, 1e-6)


func _test_takeoff_from_surface() -> void:
	var state := _state(0.0, -RADIUS, 0.0, 0.0)
	for i in range(120):
		state.velocity_y -= 300.0 / 60.0
		_model.propagate(state, 1.0 / 60.0)
	_check("thrust stronger than gravity lifts off", 1.0 if _radius_of(state) > RADIUS + 100.0 else 0.0, 1.0, 0.0)
	_check("and leaves the surface", 1.0 if state.is_on_surface() else 0.0, 0.0, 0.0)


func _test_predict_trajectory() -> void:
	var state := _circular_state(LOW_ORBIT)
	var period: float = _period(LOW_ORBIT)
	var points: PackedFloat64Array = _model.predict_trajectory(state, period, 257)
	_check("prediction has every sample", points.size(), 514, 0.0)
	_check("prediction starts at the ship", points[1], -LOW_ORBIT, 0.0)
	_check("prediction closes the orbit", points[513], -LOW_ORBIT, 1e-4)
	_check("prediction leaves the ship alone", state.y, -LOW_ORBIT, 0.0)
	_check("prediction leaves the clock alone", state.time, 0.0, 0.0)
	var falling := _state(0.0, -LOW_ORBIT, 500.0, 0.0)
	var impact: PackedFloat64Array = _model.predict_trajectory(falling, 100000.0)
	_check("prediction stops early at impact", 1.0 if impact.size() < 512 else 0.0, 1.0, 0.0)
	var last_x: float = impact[impact.size() - 2]
	var last_y: float = impact[impact.size() - 1]
	_check("prediction ends on the surface", sqrt(last_x * last_x + last_y * last_y), RADIUS, 1e-6)


# The whole point of a preview: fly the ship for real, and every point it passes through
# should sit on the line that was predicted before it set off.
func _test_prediction_matches_real_flight() -> void:
	var flown := _state(0.0, -LOW_ORBIT, 5900.0, 600.0)
	var semi_major_axis: float = 1.0 / (2.0 / _radius_of(flown) - _speed_of(flown) * _speed_of(flown) / MU)
	var points: PackedFloat64Array = _model.predict_trajectory(flown, 100000.0, 512)
	var worst: float = 0.0
	for tick in range(roundi(_period(semi_major_axis) * 60.0)):
		_model.propagate(flown, 1.0 / 60.0)
		if tick % 120 == 0:
			worst = maxf(worst, _distance_to_path(flown.x, flown.y, points))
	_check("flown path stays on the predicted line", worst, 0.0, 15.0)


func _test_prediction_stops_after_one_lap() -> void:
	var state := _state(0.0, -LOW_ORBIT, 5600.0, 400.0)
	var points: PackedFloat64Array = _model.predict_trajectory(state, 100000.0, 512)
	_check("a long horizon still gets every sample", points.size(), 1024, 0.0)
	_check("and shows one lap, ending at the start x", points[1022], state.x, 1e-3)
	_check("and shows one lap, ending at the start y", points[1023], state.y, 1e-3)


func _test_prediction_follows_the_curve() -> void:
	# Very stretched ellipse: periapsis 160000, apoapsis 1600000.
	var periapsis: float = 160000.0
	var semi_major_axis: float = (periapsis + 1600000.0) / 2.0
	var speed: float = sqrt(MU * (2.0 / periapsis - 1.0 / semi_major_axis))
	var state := _state(0.0, -periapsis, speed, 0.0)
	var points: PackedFloat64Array = _model.predict_trajectory(state, 100000.0, 512)
	var longest: float = 0.0
	for i in range(0, points.size() - 2, 2):
		longest = maxf(longest, Vector2(points[i + 2] - points[i], points[i + 3] - points[i + 1]).length())
	# With even time steps the segments at periapsis would be about 30000 long here.
	_check("no long straight segments on a stretched orbit", 1.0 if longest < 15000.0 else 0.0, 1.0, 0.0)


func _test_prediction_of_open_path() -> void:
	var escape_speed: float = sqrt(2.0 * MU / LOW_ORBIT)
	var state := _state(0.0, -LOW_ORBIT, escape_speed * 1.2, 0.0)
	var points: PackedFloat64Array = _model.predict_trajectory(state, 3600.0, 512)
	var flown := _state(0.0, -LOW_ORBIT, escape_speed * 1.2, 0.0)
	_model.propagate(flown, 3600.0)
	_check("escape path has every sample", points.size(), 1024, 0.0)
	_check("escape path ends where the ship will be, x", points[1022], flown.x, 1e-2)
	_check("escape path ends where the ship will be, y", points[1023], flown.y, 1e-2)


func _distance_to_path(x: float, y: float, points: PackedFloat64Array) -> float:
	var best: float = INF
	var point := Vector2(x, y)
	for i in range(0, points.size() - 2, 2):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				point, Vector2(points[i], points[i + 1]), Vector2(points[i + 2], points[i + 3]))
		best = minf(best, point.distance_to(closest))
	return best


func _test_repeatable() -> void:
	var first := _state(1000.0, -LOW_ORBIT, 5200.0, 700.0)
	var second := _state(1000.0, -LOW_ORBIT, 5200.0, 700.0)
	for i in range(5000):
		_model.propagate(first, 1.0 / 60.0)
		_model.propagate(second, 1.0 / 60.0)
	_check("same inputs give exactly the same x", first.x, second.x, 0.0)
	_check("same inputs give exactly the same y", first.y, second.y, 0.0)


func _test_precision_far_from_body() -> void:
	var state := _state(1.0e12, 0.0, 1.0, 0.0)
	var start: float = state.x
	for i in range(60):
		_model.propagate(state, 1.0 / 60.0)
	_check("1 px/s still moves at x = 1e12", state.x - start, 1.0, 1e-2)
