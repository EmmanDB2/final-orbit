# test_gravity_model.gd: checks the physics core against known orbital results.
# From DESIGN.md, "Physics". Run after building the Mac library:
#   godot --headless --path . --script tests/test_gravity_model.gd
extends SceneTree

const MU: float = 4.5e12
const RADIUS: float = 150000.0
const LOW_ORBIT: float = 180000.0
const MOON_MU: float = 5.4e10
const MOON_RADIUS: float = 30000.0
const MOON_ORBIT: float = 600000.0
const MOON_ECCENTRICITY: float = 0.04

var _checks: int = 0
var _failures: int = 0
var _model: GravityModel


func _initialize() -> void:
	var patched_conics := PatchedConicsModel.new()
	patched_conics.set_central_body(MU, RADIUS)
	_model = patched_conics

	_test_satellites()
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
	_test_no_moon_means_no_encounters()
	_test_ground_clearance()
	_test_touchdown_speed()
	_test_entry_heights()
	_test_orbit_apsides()

	var with_moon := PatchedConicsModel.new()
	with_moon.set_central_body(MU, RADIUS)
	with_moon.add_body(0, MOON_MU, MOON_RADIUS, MOON_ORBIT, MOON_ECCENTRICITY, 0.5, 0.3)
	_model = with_moon

	_test_rails()
	_test_dominant_body()
	_test_gravity_inside_soi()
	_test_orbit_around_moon()
	_test_flyby()
	_test_big_step_through_soi()
	_test_landing_on_moon()
	_test_encounter_prediction()
	_test_prediction_inside_soi()
	_test_moon_ground_speed_and_altitude()

	_test_nested_system()
	_test_spin()
	_test_air()
	_test_terrain()

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
	var lowest: float = INF
	for i in range(0, impact.size(), 2):
		lowest = minf(lowest, Vector2(impact[i], impact[i + 1]).length())
	_check("prediction never goes under the surface", lowest, RADIUS, 1e-6)
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


func _test_no_moon_means_no_encounters() -> void:
	_check("one body when there's no moon", _model.get_body_count(), 1, 0.0)
	_check("that body is dominant", _model.get_dominant_body(1.0e9, 0.0, 0.0), 0, 0.0)
	_check("nothing to encounter", _model.find_encounter(_circular_state(LOW_ORBIT), 100000.0).size(), 0, 0.0)
	_check("body 0 has no limit", _model.get_sphere_of_influence(0), 0.0, 0.0)
	_check("body 0 has no rails to draw", _model.get_body_orbit_path(0, 16).size(), 0, 0.0)


func _test_ground_clearance() -> void:
	var state := _state(0.0, -(RADIUS + 5000.0), 0.0, 0.0)
	state.ground_clearance = 105.0
	var points: PackedFloat64Array = _model.predict_trajectory(state, 100000.0, 64)
	_check("the line ends with the ship resting on the ground", Vector2(points[126], points[127]).length(), RADIUS + 105.0, 1e-2)
	for i in range(3600):
		_model.propagate(state, 1.0 / 60.0)
	_check("the ship rests above the surface by its clearance", _radius_of(state), RADIUS + 105.0, 1e-6)
	_check("altitude measures from the ground", _model.get_altitude(state.x, state.y, state.time), 105.0, 1e-6)
	_check("a ship with no clearance rests on the surface", _state(0.0, -RADIUS, 0.0, 0.0).ground_clearance, 0.0, 0.0)


func _test_touchdown_speed() -> void:
	var start: float = RADIUS + 5000.0
	var contact: float = RADIUS + 105.0
	var state := _state(0.0, -start, 0.0, 0.0)
	state.ground_clearance = 105.0
	var expected: float = sqrt(2.0 * MU * (1.0 / contact - 1.0 / start))
	while not state.is_on_surface():
		_model.propagate(state, 1.0 / 60.0)
	_check("touchdown speed matches free fall", state.get_touchdown_speed(), expected, 5.0)
	_check("the ground stops the ship", _speed_of(state), 0.0, 0.0)
	_check("the ground isn't moving", _model.get_surface_velocity(state.x, state.y, state.time)[0], 0.0, 0.0)


func _test_entry_heights() -> void:
	var entry_model := PatchedConicsModel.new()
	entry_model.set_central_body(MU, RADIUS, 15000.0)
	# Dips to periapsis 160000, which is 10000 up, below the entry height of 15000.
	var periapsis: float = 160000.0
	var apoapsis: float = 300000.0
	var a: float = (periapsis + apoapsis) / 2.0
	var state := _state(0.0, -apoapsis, sqrt(MU * (2.0 / apoapsis - 1.0 / a)), 0.0)
	var points: PackedFloat64Array = entry_model.predict_trajectory(state, 100000.0, 256)
	var heights: PackedFloat64Array = entry_model.predict_entry_heights(state, 100000.0, 256)
	_check("one height per point", heights.size(), points.size() / 2.0, 0.0)
	_check("high up is above the landing zone", heights[0], apoapsis - RADIUS - 15000.0, 1e-3)
	var lowest: float = INF
	var first_low: int = -1
	var last_low: int = -1
	for i in range(heights.size()):
		lowest = minf(lowest, heights[i])
		if heights[i] < 0.0:
			if first_low < 0:
				first_low = i
			last_low = i
		_check_quiet(sqrt(points[i * 2] * points[i * 2] + points[i * 2 + 1] * points[i * 2 + 1]) - RADIUS - 15000.0, heights[i], 1e-6)
	_check("periapsis dips below the entry height", lowest, 10000.0 - 15000.0, 50.0)
	_check("the low part is one stretch in the middle", 1.0 if first_low > 0 and last_low < 255 else 0.0, 1.0, 0.0)


func _test_orbit_apsides() -> void:
	var periapsis: float = 180000.0
	var apoapsis: float = 540000.0
	var a: float = (periapsis + apoapsis) / 2.0
	var state := _state(0.0, -periapsis, sqrt(MU * (2.0 / periapsis - 1.0 / a)), 0.0)
	var apsides: PackedFloat64Array = _model.get_orbit_apsides(state)
	_check("periapsis height", apsides[0], periapsis - RADIUS, 1e-3)
	_check("apoapsis height", apsides[1], apoapsis - RADIUS, 1e-3)
	var open := _state(0.0, -periapsis, sqrt(2.0 * MU / periapsis) * 1.2, 0.0)
	_check("an open path has no apoapsis", _model.get_orbit_apsides(open)[1], -1.0, 0.0)


func _check_quiet(actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		_check("heights match the points", actual, expected, tolerance)


func _test_moon_ground_speed_and_altitude() -> void:
	var r: float = 60000.0
	var state := _state_around_moon(100.0, r, 0.0, 0.0, 0.0)
	_check("altitude above the moon", _model.get_altitude(state.x, state.y, state.time), r - MOON_RADIUS, 1e-2)
	var ground: PackedFloat64Array = _model.get_surface_velocity(state.x, state.y, state.time)
	var moon: PackedFloat64Array = _moon_velocity(state.time)
	_check("the moon's ground moves with the moon, x", ground[0], moon[0], 1e-2)
	_check("the moon's ground moves with the moon, y", ground[1], moon[1], 1e-2)
	var falling := _state_around_moon(100.0, r, 0.0, -300.0, 0.0)
	while not falling.is_on_surface():
		_model.propagate(falling, 1.0 / 60.0)
	var expected: float = sqrt(300.0 * 300.0 + 2.0 * MOON_MU * (1.0 / MOON_RADIUS - 1.0 / r))
	_check("touchdown speed is relative to the moon", falling.get_touchdown_speed(), expected, 5.0)


func _moon_position(time: float) -> Vector2:
	var p: PackedFloat64Array = _model.get_body_position(1, time)
	return Vector2(p[0], p[1])


func _moon_x(time: float) -> float:
	return _model.get_body_position(1, time)[0]


func _moon_y(time: float) -> float:
	return _model.get_body_position(1, time)[1]


func _moon_velocity(time: float) -> PackedFloat64Array:
	var h: float = 0.01
	return PackedFloat64Array([
			(_moon_x(time + h) - _moon_x(time - h)) / (2.0 * h),
			(_moon_y(time + h) - _moon_y(time - h)) / (2.0 * h)])


func _soi() -> float:
	return MOON_ORBIT * pow(MOON_MU / MU, 0.4)


# A ship placed relative to the moon, in world position and velocity.
func _state_around_moon(time: float, offset_x: float, offset_y: float, velocity_x: float, velocity_y: float) -> ShipState:
	var moon_velocity: PackedFloat64Array = _moon_velocity(time)
	var state := _state(_moon_x(time) + offset_x, _moon_y(time) + offset_y, moon_velocity[0] + velocity_x, moon_velocity[1] + velocity_y)
	state.time = time
	return state


func _distance_from_moon(state: ShipState) -> float:
	return sqrt(pow(state.x - _moon_x(state.time), 2.0) + pow(state.y - _moon_y(state.time), 2.0))


func _speed_relative_to_moon(state: ShipState) -> float:
	var moon_velocity: PackedFloat64Array = _moon_velocity(state.time)
	return sqrt(pow(state.velocity_x - moon_velocity[0], 2.0) + pow(state.velocity_y - moon_velocity[1], 2.0))


func _test_rails() -> void:
	var period: float = TAU * sqrt(pow(MOON_ORBIT, 3.0) / MU)
	_check("two bodies", _model.get_body_count(), 2, 0.0)
	_check("body 0 stays at the origin", _model.get_body_position(0, 500.0)[0], 0.0, 0.0)
	_check("a moon lap closes x", _moon_x(period), _moon_x(0.0), 1e-5)
	_check("a moon lap closes y", _moon_y(period), _moon_y(0.0), 1e-5)
	_check("rails work far in the future", _moon_x(period * 100000.0), _moon_x(0.0), 1e-1)

	var mean_motion: float = TAU / period
	var at_periapsis: float = -0.3 / mean_motion
	_check("moon's closest point", _moon_position(at_periapsis).length(), MOON_ORBIT * (1.0 - MOON_ECCENTRICITY), 1e-5)
	_check("moon's farthest point", _moon_position(at_periapsis + period / 2.0).length(), MOON_ORBIT * (1.0 + MOON_ECCENTRICITY), 1e-5)

	var r: float = _moon_position(123.0).length()
	var velocity: PackedFloat64Array = _moon_velocity(123.0)
	_check("moon's speed fits its orbit", Vector2(velocity[0], velocity[1]).length(), sqrt(MU * (2.0 / r - 1.0 / MOON_ORBIT)), 1e-3)

	var a: Vector2 = _moon_position(0.0)
	var b: Vector2 = _moon_position(1.0)
	_check("moon goes the same way as the ship", 1.0 if a.x * b.y - a.y * b.x > 0.0 else 0.0, 1.0, 0.0)

	_check("sphere of influence comes from the masses", _model.get_sphere_of_influence(1), _soi(), 1e-6)
	_check("moon radius", _model.get_body_radius(1), MOON_RADIUS, 0.0)

	var path: PackedFloat64Array = _model.get_body_orbit_path(1, 65)
	_check("moon's rails path has every sample", path.size(), 130, 0.0)
	_check("moon's rails path closes", path[128], path[0], 1e-5)


func _test_dominant_body() -> void:
	var moon: Vector2 = _moon_position(50.0)
	_check("inside the sphere: the moon", _model.get_dominant_body(moon.x + _soi() * 0.9, moon.y, 50.0), 1, 0.0)
	_check("outside the sphere: the planet", _model.get_dominant_body(moon.x + _soi() * 1.1, moon.y, 50.0), 0, 0.0)
	_check("near the planet: the planet", _model.get_dominant_body(0.0, -LOW_ORBIT, 50.0), 0, 0.0)
	var later: Vector2 = _moon_position(500.0)
	_check("the sphere moves with the moon", _model.get_dominant_body(later.x, later.y, 50.0), 0, 0.0)


func _test_gravity_inside_soi() -> void:
	var pull: PackedFloat64Array = _model.get_acceleration(_moon_x(50.0) + 60000.0, _moon_y(50.0), 50.0)
	_check("gravity pulls toward the moon", pull[0], -MOON_MU / (60000.0 * 60000.0), 1e-9)
	_check("and only the moon", pull[1], 0.0, 1e-9)


func _test_orbit_around_moon() -> void:
	var r: float = 60000.0
	var state := _state_around_moon(0.0, r, 0.0, 0.0, sqrt(MOON_MU / r))
	var period: float = TAU * sqrt(pow(r, 3.0) / MOON_MU)
	var worst: float = 0.0
	var ticks: int = roundi(period * 60.0)
	var left: bool = false
	for i in range(ticks):
		_model.propagate(state, 1.0 / 60.0)
		worst = maxf(worst, absf(_distance_from_moon(state) - r))
		left = left or _model.get_dominant_body(state.x, state.y, state.time) != 1
	_check("stays in orbit around the moving moon", worst, 0.0, 2.0)
	_check("and never leaves its sphere", 1.0 if left else 0.0, 0.0, 0.0)


func _test_flyby() -> void:
	# Coming in from outside the sphere, aimed to pass off to one side of the moon.
	var start_gap: float = _soi() * 1.15
	var state := _state_around_moon(0.0, -start_gap, 80000.0, 1500.0, 0.0)
	var was_inside: bool = false
	var entered: bool = false
	var left: bool = false
	var speed_in: float = 0.0
	var speed_out: float = 0.0
	var closest: float = INF
	var largest_jump: float = 0.0
	for i in range(30000):
		var x: float = state.x
		var y: float = state.y
		var vx: float = state.velocity_x
		var vy: float = state.velocity_y
		_model.propagate(state, 1.0 / 60.0)
		largest_jump = maxf(largest_jump, Vector2(state.x - x - vx / 60.0, state.y - y - vy / 60.0).length())
		var inside: bool = _model.get_dominant_body(state.x, state.y, state.time) == 1
		if inside and not was_inside:
			entered = true
			speed_in = _speed_relative_to_moon(state)
		if was_inside and not inside:
			left = true
			speed_out = _speed_relative_to_moon(state)
			break
		was_inside = inside
		if inside:
			closest = minf(closest, _distance_from_moon(state))
	_check("flyby enters the sphere", 1.0 if entered else 0.0, 1.0, 0.0)
	_check("flyby leaves the sphere", 1.0 if left else 0.0, 1.0, 0.0)
	_check("position and velocity carry across the switches", largest_jump, 0.0, 0.05)
	_check("moon-relative speed out matches speed in (relative)", speed_out / speed_in, 1.0, 0.01)
	_check("the moon bent the path inward", 1.0 if closest < 80000.0 else 0.0, 1.0, 0.0)
	_check("and it missed the surface", 1.0 if closest > MOON_RADIUS else 0.0, 1.0, 0.0)


func _test_big_step_through_soi() -> void:
	var start_gap: float = _soi() * 1.15
	var stepped := _state_around_moon(0.0, -start_gap, 80000.0, 1500.0, 0.0)
	var jumped := _state_around_moon(0.0, -start_gap, 80000.0, 1500.0, 0.0)
	for i in range(12000):
		_model.propagate(stepped, 1.0 / 60.0)
	_model.propagate(jumped, 200.0)
	_check("a big jump can't skip the moon, x", jumped.x, stepped.x, 500.0)
	_check("a big jump can't skip the moon, y", jumped.y, stepped.y, 500.0)
	_check("clock agrees", jumped.time, stepped.time, 1e-6)


func _test_landing_on_moon() -> void:
	var state := _state_around_moon(0.0, 60000.0, 0.0, 0.0, 0.0)
	for i in range(6000):
		_model.propagate(state, 1.0 / 60.0)
	_check("falls to the moon's surface", 1.0 if state.is_on_surface() else 0.0, 1.0, 0.0)
	_check("stops on the moon's surface", _distance_from_moon(state), MOON_RADIUS, 1e-4)
	_check("then moves with the moon", _speed_relative_to_moon(state), 0.0, 1e-2)
	var start: Vector2 = _moon_position(state.time)
	for i in range(3000):
		_model.propagate(state, 1.0 / 60.0)
	_check("the moon really moved", 1.0 if _moon_position(state.time).distance_to(start) > 50000.0 else 0.0, 1.0, 0.0)
	_check("and the ship rode along", _distance_from_moon(state), MOON_RADIUS, 1e-4)
	var away: Vector2 = (Vector2(state.x, state.y) - _moon_position(state.time)).normalized()
	for i in range(120):
		state.velocity_x += away.x * 300.0 / 60.0
		state.velocity_y += away.y * 300.0 / 60.0
		_model.propagate(state, 1.0 / 60.0)
	_check("thrust lifts off the moon", 1.0 if _distance_from_moon(state) > MOON_RADIUS + 100.0 else 0.0, 1.0, 0.0)


func _test_encounter_prediction() -> void:
	var start_gap: float = _soi() * 1.5
	var state := _state_around_moon(0.0, -start_gap, 80000.0, 1500.0, 0.0)
	var points: PackedFloat64Array = _model.predict_trajectory(state, 3600.0, 600)
	var encounter: PackedFloat64Array = _model.find_encounter(state, 3600.0)
	_check("predicts the encounter", encounter.size(), 2, 0.0)
	_check("with the moon", encounter[1], 1, 0.0)
	_check("line has every sample", points.size(), 1200, 0.0)
	_check("line starts at the ship", points[0], state.x, 1e-6)

	var ghost: Vector2 = _moon_position(encounter[0])
	var worst: float = 0.0
	var arrived_at: float = -1.0
	for i in range(30000):
		_model.propagate(state, 1.0 / 60.0)
		var inside: bool = _model.get_dominant_body(state.x, state.y, state.time) == 1
		if inside and arrived_at < 0.0:
			arrived_at = state.time
		if arrived_at >= 0.0 and not inside:
			break
		if inside and i % 60 == 0:
			var relative: Vector2 = Vector2(state.x, state.y) - _moon_position(state.time)
			var drawn: Vector2 = ghost + relative
			worst = maxf(worst, _distance_to_path(drawn.x, drawn.y, points))
	_check("arrival time was right", arrived_at, encounter[0], 0.05)
	_check("flyby stays on the line drawn around the future moon", worst, 0.0, 30.0)
	var last: Vector2 = Vector2(points[1198], points[1199])
	_check("line ends leaving the moon's sphere", last.distance_to(ghost), _soi(), 1.0)
	_check("nothing to encounter while inside", _model.find_encounter(_state_around_moon(0.0, 60000.0, 0.0, 0.0, 900.0), 3600.0).size(), 0, 0.0)


func _test_prediction_inside_soi() -> void:
	var now: float = 40.0
	var r: float = 60000.0
	var state := _state_around_moon(now, r, 0.0, 0.0, sqrt(MOON_MU / r))
	var points: PackedFloat64Array = _model.predict_trajectory(state, 3600.0, 256)
	var moon: Vector2 = _moon_position(now)
	_check("an orbit around the moon closes on the line", Vector2(points[510], points[511]).distance_to(Vector2(points[0], points[1])), 0.0, 1.0)
	_check("and is drawn around the moon as it is now", Vector2(points[256], points[257]).distance_to(moon), r, 5.0)

	var leaving := _state_around_moon(now, r, 0.0, 2500.0, 0.0)
	var out: PackedFloat64Array = _model.predict_trajectory(leaving, 3600.0, 128)
	_check("an escape stops at the sphere's edge", Vector2(out[254], out[255]).distance_to(moon), _soi(), 1.0)

	var falling := _state_around_moon(now, r, 0.0, -400.0, 100.0)
	var crash: PackedFloat64Array = _model.predict_trajectory(falling, 3600.0, 128)
	_check("a crash stops on the moon's surface", sqrt(pow(crash[254] - _moon_x(now), 2.0) + pow(crash[255] - _moon_y(now), 2.0)), MOON_RADIUS, 1e-3)


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


# A star, a planet on rails around it, and a moon on rails around the planet.
func _test_nested_system() -> void:
	const STAR_MU := 2.25e16
	const PLANET_ORBIT := 4.53e7
	const NEST_MOON_ORBIT := 6.0e5
	var system := PatchedConicsModel.new()
	system.set_central_body(STAR_MU, 2.5e6)
	var planet: int = system.add_body(0, MU, RADIUS, PLANET_ORBIT, 0.0, 0.0, 0.0)
	var moon: int = system.add_body(planet, MOON_MU, MOON_RADIUS, NEST_MOON_ORBIT, 0.0, 0.0, 0.0)
	_check("planet is body 1", planet, 1, 0.0)
	_check("moon is body 2", moon, 2, 0.0)
	_check("body 0 orbits nothing", system.get_body_parent(0), -1, 0.0)
	_check("the moon orbits the planet", system.get_body_parent(moon), planet, 0.0)
	_check("the moon belongs to the planet", system.get_local_root(moon), planet, 0.0)
	_check("the planet belongs to itself", system.get_local_root(planet), planet, 0.0)
	_check("the star belongs to itself", system.get_local_root(0), 0, 0.0)

	var planet_soi: float = PLANET_ORBIT * pow(MU / STAR_MU, 0.4)
	var moon_soi: float = NEST_MOON_ORBIT * pow(MOON_MU / MU, 0.4)
	_check("planet's sphere comes from the star", system.get_sphere_of_influence(planet), planet_soi, 1e-6)
	_check("moon's sphere comes from the planet", system.get_sphere_of_influence(moon), moon_soi, 1e-6)

	# Rails add up.
	var t := 1234.5
	var planet_at: PackedFloat64Array = system.get_body_position(planet, t)
	var moon_at: PackedFloat64Array = system.get_body_position(moon, t)
	_check("planet stays on its rails", _length(planet_at[0], planet_at[1]), PLANET_ORBIT, 1e-6)
	_check("moon stays on its rails around the moving planet", _length(moon_at[0] - planet_at[0], moon_at[1] - planet_at[1]), NEST_MOON_ORBIT, 1e-6)
	var before: PackedFloat64Array = system.get_body_position(moon, t - 0.5)
	var after: PackedFloat64Array = system.get_body_position(moon, t + 0.5)
	var moon_velocity: PackedFloat64Array = system.get_body_velocity(moon, t)
	_check("moon's velocity includes the planet's, x", moon_velocity[0], after[0] - before[0], 0.01)
	_check("moon's velocity includes the planet's, y", moon_velocity[1], after[1] - before[1], 0.01)
	var moon_path: PackedFloat64Array = system.get_body_orbit_path(moon, 33)
	_check("moon's rails are relative to the planet", _length(moon_path[0], moon_path[1]), NEST_MOON_ORBIT, 1e-6)
	var planet_path: PackedFloat64Array = system.get_body_orbit_path(planet, 33)
	_check("planet's rails are relative to the star", _length(planet_path[8], planet_path[9]), PLANET_ORBIT, 1e-6)

	# Which gravity applies.
	_check("near the moon means the moon", system.get_dominant_body(moon_at[0] + moon_soi * 0.5, moon_at[1], t), moon, 0.0)
	_check("in the planet's sphere means the planet", system.get_dominant_body(planet_at[0] + planet_soi * 0.9, planet_at[1], t), planet, 0.0)
	_check("past the planet's sphere means the star", system.get_dominant_body(planet_at[0] + planet_soi * 1.1, planet_at[1], t), 0, 0.0)
	var ground: PackedFloat64Array = system.get_surface_velocity(moon_at[0] + moon_soi * 0.5, moon_at[1], t)
	_check("ground speed comes with the parents", ground[0], moon_velocity[0], 1e-6)

	# A low orbit around the moving planet closes in the planet's frame.
	var start_at: PackedFloat64Array = system.get_body_position(planet, 0.0)
	var start_velocity: PackedFloat64Array = system.get_body_velocity(planet, 0.0)
	var low := RADIUS + 30000.0
	var orbit := ShipState.new()
	orbit.x = start_at[0]
	orbit.y = start_at[1] - low
	orbit.velocity_x = start_velocity[0] + sqrt(MU / low)
	orbit.velocity_y = start_velocity[1]
	var points: PackedFloat64Array = system.predict_trajectory(orbit, 3600.0, 65)
	_check("predicted lap starts at the ship", points[0], orbit.x, 1e-6)
	_check("predicted lap ends where it starts", points[points.size() - 1], points[1], 1e-3)
	var period: float = TAU * sqrt(low * low * low / MU)
	for i in range(200):
		system.propagate(orbit, period / 200.0)
	var end_at: PackedFloat64Array = system.get_body_position(planet, period)
	_check("one lap later it's back above the planet, x", orbit.x - end_at[0], 0.0, 0.01)
	_check("one lap later it's back above the planet, y", orbit.y - end_at[1], -low, 0.01)

	# Leaving the planet: world position carries across, and the star takes over.
	var escape := ShipState.new()
	var escape_at: PackedFloat64Array = system.get_body_position(planet, 0.0)
	var escape_velocity: PackedFloat64Array = system.get_body_velocity(planet, 0.0)
	escape.x = escape_at[0] - low
	escape.y = escape_at[1]
	escape.velocity_x = escape_velocity[0]
	escape.velocity_y = escape_velocity[1] + sqrt(MU / low) * 2.0
	var path_out: PackedFloat64Array = system.predict_trajectory(escape, 40000.0, 33)
	var path_end_x: float = path_out[path_out.size() - 2]
	var path_end_y: float = path_out[path_out.size() - 1]
	_check("the line ends at the planet's sphere", _length(path_end_x - escape_at[0], path_end_y - escape_at[1]), planet_soi, 1.0)
	var left_at := -1.0
	while left_at < 0.0 and escape.time < 40000.0:
		system.propagate(escape, 5.0)
		if system.get_dominant_body(escape.x, escape.y, escape.time) == 0:
			left_at = escape.time
	_check("the ship leaves the planet's sphere", left_at > 0.0, true, 0.0)
	var r_out: float = _length(escape.x, escape.y)
	var energy: float = 0.5 * (escape.velocity_x * escape.velocity_x + escape.velocity_y * escape.velocity_y) - STAR_MU / r_out
	system.propagate(escape, 3000.0)
	if system.get_dominant_body(escape.x, escape.y, escape.time) == 0:
		var r_later: float = _length(escape.x, escape.y)
		var energy_later: float = 0.5 * (escape.velocity_x * escape.velocity_x + escape.velocity_y * escape.velocity_y) - STAR_MU / r_later
		_check("the orbit around the star holds", energy_later / energy, 1.0, 1e-9)

	# Coming in from deep space: the planet shows up as an encounter.
	var inbound := ShipState.new()
	var in_at: PackedFloat64Array = system.get_body_position(planet, 0.0)
	var in_velocity: PackedFloat64Array = system.get_body_velocity(planet, 0.0)
	inbound.x = in_at[0]
	inbound.y = in_at[1] - planet_soi * 3.0
	inbound.velocity_x = in_velocity[0]
	inbound.velocity_y = in_velocity[1] + 3000.0
	var encounter: PackedFloat64Array = system.find_encounter(inbound, 7200.0)
	_check("the planet shows as an encounter", encounter.size(), 2, 0.0)
	if encounter.size() == 2:
		_check("it's the planet", int(encounter[1]), planet, 0.0)
		system.propagate(inbound, encounter[0] + 1.0)
		_check("flying there arrives in the planet's sphere", system.get_dominant_body(inbound.x, inbound.y, inbound.time), planet, 0.0)

	# Inside the planet's sphere: the moon shows as an encounter, with the flyby drawn in
	# the planet's frame even though the planet moves a long way meanwhile.
	var aimed := ShipState.new()
	var moon_now: PackedFloat64Array = system.get_body_position(moon, 0.0)
	var moon_velocity_now: PackedFloat64Array = system.get_body_velocity(moon, 0.0)
	aimed.x = moon_now[0] - moon_soi * 1.3
	aimed.y = moon_now[1]
	aimed.velocity_x = moon_velocity_now[0] + 2000.0
	aimed.velocity_y = moon_velocity_now[1]
	var moon_encounter: PackedFloat64Array = system.find_encounter(aimed, 3600.0)
	_check("the moon shows as an encounter", moon_encounter.size(), 2, 0.0)
	if moon_encounter.size() == 2:
		_check("it's the moon", int(moon_encounter[1]), moon, 0.0)
		var samples := 64
		var predicted: PackedFloat64Array = system.predict_trajectory(aimed, moon_encounter[0] + 200.0, samples)
		var seam: int = (samples * 2 / 3 - 1) * 2
		var planet_then: PackedFloat64Array = system.get_body_position(planet, 0.0)
		var predicted_x: float = predicted[seam] - planet_then[0]
		var predicted_y: float = predicted[seam + 1] - planet_then[1]
		system.propagate(aimed, moon_encounter[0])
		var planet_arrival: PackedFloat64Array = system.get_body_position(planet, moon_encounter[0])
		_check("the flyby starts where the ship really arrives, x", predicted_x, aimed.x - planet_arrival[0], 0.5)
		_check("the flyby starts where the ship really arrives, y", predicted_y, aimed.y - planet_arrival[1], 0.5)


func _length(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


# Spinning: the ground moves, a landed ship rides along, and touchdown is against the ground.
func _test_spin() -> void:
	const SPIN := 0.0022
	const ZONE := 15000.0
	var spinning := PatchedConicsModel.new()
	spinning.set_central_body(MU, RADIUS, ZONE)
	spinning.set_body_spin(0, SPIN)

	var ground: PackedFloat64Array = spinning.get_surface_velocity(0.0, -RADIUS, 0.0)
	_check("the top of the planet moves clockwise", ground[0], SPIN * RADIUS, 1e-9)
	_check("and not up or down", ground[1], 0.0, 1e-9)
	var high: PackedFloat64Array = spinning.get_surface_velocity(0.0, -(RADIUS + ZONE * 2.0), 0.0)
	_check("above the landing zone spin doesn't count", high[0], 0.0, 0.0)

	var landed := ShipState.new()
	landed.ground_clearance = 100.0
	landed.x = 0.0
	landed.y = -(RADIUS + 100.0)
	landed.velocity_x = SPIN * (RADIUS + 100.0)
	for i in range(3600):
		spinning.propagate(landed, 1.0 / 60.0)
	_check("a landed ship stays on the ground", 1.0 if landed.is_on_surface() else 0.0, 1.0, 0.0)
	var turned: float = SPIN * landed.time
	_check("and rides around with it, x", landed.x, sin(turned) * (RADIUS + 100.0), 1.0)
	_check("and rides around with it, y", landed.y, -cos(turned) * (RADIUS + 100.0), 1.0)
	var under: PackedFloat64Array = spinning.get_surface_velocity(landed.x, landed.y, landed.time)
	_check("it's still against the ground, x", landed.velocity_x, under[0], 1e-6)
	_check("it's still against the ground, y", landed.velocity_y, under[1], 1e-6)

	var along := ShipState.new()
	along.ground_clearance = 100.0
	along.y = -(RADIUS + 110.0)
	along.velocity_x = SPIN * RADIUS
	var against := ShipState.new()
	against.ground_clearance = 100.0
	against.y = -(RADIUS + 110.0)
	against.velocity_x = -SPIN * RADIUS
	for i in range(240):
		if not along.is_on_surface():
			spinning.propagate(along, 1.0 / 60.0)
		if not against.is_on_surface():
			spinning.propagate(against, 1.0 / 60.0)
	_check("coming down with the spin only hits at the fall speed", along.get_touchdown_speed(), sqrt(2.0 * MU / (RADIUS * RADIUS) * 10.0), 15.0)
	_check("coming down against it, the ground hits at twice the spin", against.get_touchdown_speed(), 2.0 * SPIN * RADIUS, 30.0)


func _test_air() -> void:
	const ZONE := 15000.0
	const SCALE_HEIGHT := 2000.0
	var airy := PatchedConicsModel.new()
	airy.set_central_body(MU, RADIUS, ZONE)
	_check("no air until it's given some", airy.get_air_density(0.0, -RADIUS, 0.0), 0.0, 0.0)
	airy.set_body_atmosphere(0, 1.0, SCALE_HEIGHT)
	_check("thickest at the ground", airy.get_air_density(0.0, -RADIUS, 0.0), 1.0, 1e-9)
	_check("none at the top", airy.get_air_density(0.0, -(RADIUS + ZONE), 0.0), 0.0, 1e-12)
	_check("none above the top", airy.get_air_density(0.0, -(RADIUS + ZONE * 2.0), 0.0), 0.0, 0.0)
	var one_up: float = airy.get_air_density(0.0, -(RADIUS + SCALE_HEIGHT), 0.0)
	_check("thins by e every scale height", one_up, exp(-1.0), 1e-3)


func _test_terrain() -> void:
	var world := PatchedConicsModel.new()
	world.set_central_body(MU, RADIUS)
	_check("no terrain means flat ground", world.get_ground_height(0.0, -RADIUS, 0.0), 0.0, 0.0)
	world.set_body_terrain(0, 7, 2600.0, 420.0, 46.0, 7.0, 0.0, 0.0, 220.0, 0.0, RADIUS * 0.6)
	var highest: float = world.get_highest_ground(0)
	_check("terrain has a highest point", 1.0 if highest > 3000.0 else 0.0, 1.0, 0.0)

	# Same seed, same ground.
	var twin := PatchedConicsModel.new()
	twin.set_central_body(MU, RADIUS)
	twin.set_body_terrain(0, 7, 2600.0, 420.0, 46.0, 7.0, 0.0, 0.0, 220.0, 0.0, RADIUS * 0.6)
	var other := PatchedConicsModel.new()
	other.set_central_body(MU, RADIUS)
	other.set_body_terrain(0, 8, 2600.0, 420.0, 46.0, 7.0, 0.0, 0.0, 220.0, 0.0, RADIUS * 0.6)
	var strip: PackedFloat32Array = world.get_ground_strip(0, 1000, 1, 3000)
	var same: PackedFloat32Array = twin.get_ground_strip(0, 1000, 1, 3000)
	var different: PackedFloat32Array = other.get_ground_strip(0, 1000, 1, 3000)
	var matches: int = 0
	var differs: int = 0
	var lowest: float = INF
	var tallest: float = -INF
	var whole_steps: int = 0
	for i in range(0, strip.size(), 2):
		if strip[i] == same[i]:
			matches += 1
		if strip[i] != different[i]:
			differs += 1
		lowest = minf(lowest, strip[i])
		tallest = maxf(tallest, strip[i])
		if is_equal_approx(fposmod(strip[i], 2.0), 0.0):
			whole_steps += 1
	_check("the same seed gives the same ground", matches, 3000.0, 0.0)
	_check("another seed gives other ground", 1.0 if differs > 2000 else 0.0, 1.0, 0.0)
	_check("heights are whole steps of the ground's pixels", whole_steps, 3000.0, 0.0)
	_check("the ground stays above the base radius", 1.0 if lowest >= 0.0 else 0.0, 1.0, 0.0)
	_check("and below its highest point", 1.0 if tallest <= highest else 0.0, 1.0, 0.0)

	# All the way around, it never jumps much, even where the loop closes.
	var columns: int = ceili(TAU * RADIUS / 2.0)
	var around: PackedFloat32Array = world.get_ground_strip(0, 0, 8, columns / 8 + 2)
	var biggest_jump: float = 0.0
	for i in range(2, around.size(), 2):
		biggest_jump = maxf(biggest_jump, absf(around[i] - around[i - 2]))
	print("biggest jump around the rim: %.0f" % biggest_jump)
	_check("the ground has no huge jump anywhere around", 1.0 if biggest_jump < 340.0 else 0.0, 1.0, 0.0)
	var seam: PackedFloat32Array = world.get_ground_strip(0, columns - 2, 1, 4)
	_check("and none where the loop closes", 1.0 if absf(seam[0] - seam[6]) < 30.0 else 0.0, 1.0, 0.0)
	var loop_a: PackedFloat32Array = world.get_ground_strip(0, 5, 1, 1)
	var loop_b: PackedFloat32Array = world.get_ground_strip(0, 5 + columns, 1, 1)
	_check("the rim is a loop", loop_a[0], loop_b[0], 0.0)

	# Dropping a ship: contact is at the terrain, not the base radius.
	var peak_column: int = -1
	var peak: float = -1.0
	var valley_column: int = -1
	var valley: float = INF
	var wide: PackedFloat32Array = world.get_ground_strip(0, 0, 1, 40000)
	for i in range(40000):
		var height: float = wide[i * 2]
		if height > peak:
			peak = height
			peak_column = i
		if height < valley:
			valley = height
			valley_column = i
	_check("this stretch has a real hill", 1.0 if peak - valley > 200.0 else 0.0, 1.0, 0.0)
	for pair in [[peak_column, peak, "on the hill"], [valley_column, valley, "in the valley"]]:
		var angle: float = (pair[0] + 0.5) * 2.0 / RADIUS
		var r: float = RADIUS + pair[1] + 100.0 + 5.0
		var ship := ShipState.new()
		ship.ground_clearance = 100.0
		ship.x = sin(angle) * r
		ship.y = -cos(angle) * r
		for i in range(120):
			world.propagate(ship, 1.0 / 60.0)
		_check("the ship stops %s" % pair[2], sqrt(ship.x * ship.x + ship.y * ship.y), RADIUS + pair[1] + 100.0, 3.0)
		_check("touching it", 1.0 if ship.is_on_surface() else 0.0, 1.0, 0.0)
		_check("and altitude reads from the ground, %s" % pair[2], world.get_altitude(ship.x, ship.y, ship.time), 100.0, 3.0)

	# The ground turns with the planet: the same column stays under a landed ship.
	var turning := PatchedConicsModel.new()
	turning.set_central_body(MU, RADIUS, 15000.0)
	turning.set_body_spin(0, 0.0022)
	turning.set_body_terrain(0, 7, 2600.0, 420.0, 46.0, 7.0, 0.0, 0.0, 220.0, 0.0, RADIUS * 0.6)
	var angle_there: float = 0.1
	var start_r: float = RADIUS + turning.get_ground_height(sin(angle_there) * RADIUS, -cos(angle_there) * RADIUS, 0.0) + 100.0
	var rider := ShipState.new()
	rider.ground_clearance = 100.0
	rider.x = sin(angle_there) * start_r
	rider.y = -cos(angle_there) * start_r
	rider.velocity_x = cos(angle_there) * 0.0022 * start_r
	rider.velocity_y = sin(angle_there) * 0.0022 * start_r
	turning.propagate(rider, 0.0)
	var column_before: float = turning.get_ground_column(rider.x, rider.y, rider.time)
	for i in range(1800):
		turning.propagate(rider, 1.0 / 60.0)
	_check("a landed ship stays over the same ground", turning.get_ground_column(rider.x, rider.y, rider.time), column_before, 2.0)

	# A far-out strip leaves out what it can't show.
	var fine: PackedFloat32Array = world.get_ground_strip(0, 1000, 1, 512)
	var coarse: PackedFloat32Array = world.get_ground_strip(0, 1000, 64, 8)
	var fine_change: int = 0
	for i in range(2, fine.size(), 2):
		if fine[i] != fine[i - 2]:
			fine_change += 1
	_check("up close there are small bumps", 1.0 if fine_change > 50 else 0.0, 1.0, 0.0)
	_check("and far out the steps are bigger", 1.0 if is_equal_approx(fposmod(coarse[0], 128.0), 0.0) else 0.0, 1.0, 0.0)

	# The far-off mountains loop too, and are the same for the same seed.
	var ridged := PatchedConicsModel.new()
	ridged.set_central_body(MU, RADIUS)
	ridged.set_body_terrain(0, 7, 2600.0, 420.0, 46.0, 7.0, 0.0, 0.0, 220.0, 0.0, RADIUS * 0.6, 150.0)
	var loop_columns: float = ceilf(TAU * RADIUS / 2.0) * 0.3
	var ridge_here: PackedFloat32Array = ridged.get_distant_ridge(0, 100.0, 1.0, 1, 0.3)
	var ridge_again: PackedFloat32Array = ridged.get_distant_ridge(0, 100.0 + loop_columns, 1.0, 1, 0.3)
	_check("the far mountains loop", ridge_here[0], ridge_again[0], 2.0)
	var ridge_many: PackedFloat32Array = ridged.get_distant_ridge(0, 0.0, 8.0, 2000, 0.3)
	var ridge_top: float = 0.0
	for value: float in ridge_many:
		ridge_top = maxf(ridge_top, value)
	_check("the far mountains have height", 1.0 if ridge_top > 50.0 and ridge_top <= 160.0 else 0.0, 1.0, 0.0)

	# Sea stays flat where the map says sea.
	var with_sea := PatchedConicsModel.new()
	with_sea.set_central_body(MU, RADIUS)
	with_sea.set_body_terrain(0, 7, 2600.0, 420.0, 46.0, 7.0, 0.0, 0.0, 220.0, 0.5, RADIUS * 0.6)
	var coast: PackedFloat32Array = with_sea.get_ground_strip(0, 0, 32, 14000)
	var flat_sea: int = 0
	var sea_count: int = 0
	for i in range(0, coast.size(), 2):
		if coast[i + 1] < 3.0:
			sea_count += 1
			if coast[i] == 0.0:
				flat_sea += 1
	_check("this planet has sea on its rim", 1.0 if sea_count > 100 else 0.0, 1.0, 0.0)
	_check("and the sea is flat", flat_sea, sea_count, 0.0)


func _test_satellites() -> void:
	var model := PatchedConicsModel.new()
	model.set_central_body(MU, RADIUS)
	var moon: int = model.add_body(0, MOON_MU, MOON_RADIUS, MOON_ORBIT, MOON_ECCENTRICITY, 0.0, 0.0)
	var bodies_before: int = model.get_body_count()
	var station: int = model.add_satellite(0, LOW_ORBIT, 0.0, 0.0, 0.5)
	var around_moon: int = model.add_satellite(moon, MOON_RADIUS * 2.0, 0.0, 0.0, 0.0)
	_check("satellites don't count as bodies", model.get_body_count(), bodies_before, 0.0)
	_check("they have their own numbers", model.get_satellite_count(), 2.0, 0.0)
	_check("and know what they orbit", model.get_satellite_parent(around_moon), moon, 0.0)

	# On rails, it goes where a coasting ship started beside it goes.
	var at: PackedFloat64Array = model.get_satellite_position(station, 0.0)
	var moving: PackedFloat64Array = model.get_satellite_velocity(station, 0.0)
	_check("it sits at its orbit's height", sqrt(at[0] * at[0] + at[1] * at[1]), LOW_ORBIT, 1e-6)
	_check("and starts where it's told", atan2(at[1], at[0]), 0.5, 1e-9)
	var ship := ShipState.new()
	ship.x = at[0]
	ship.y = at[1]
	ship.velocity_x = moving[0]
	ship.velocity_y = moving[1]
	model.propagate(ship, 150.0)
	var later: PackedFloat64Array = model.get_satellite_position(station, 150.0)
	_check("a ship coasting beside it stays beside it", Vector2(ship.x - later[0], ship.y - later[1]).length(), 0.0, 1e-3)
	_check("its rails hold no gravity", model.get_dominant_body(later[0], later[1], 150.0), 0.0, 0.0)

	# Around a moon, it rides along.
	var moon_at: PackedFloat64Array = model.get_body_position(moon, 40.0)
	var small: PackedFloat64Array = model.get_satellite_position(around_moon, 40.0)
	_check("around a moon it stays with the moon", Vector2(small[0] - moon_at[0], small[1] - moon_at[1]).length(), MOON_RADIUS * 2.0, 1e-6)
	var lap: PackedFloat64Array = model.get_satellite_orbit_path(station, 65)
	_check("its lap closes", Vector2(lap[0] - lap[128], lap[1] - lap[129]).length(), 0.0, 1e-3)
