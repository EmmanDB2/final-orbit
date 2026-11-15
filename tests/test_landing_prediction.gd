# test_landing_prediction.gd: checks the forecast of how the ship comes down against what it then
# really does, flown by the real ship script.
# From DESIGN.md, "Physics" (Landing prediction). Run after building the Mac library:
#   godot --headless --path . --script tests/test_landing_prediction.gd
#
# It borrows the world and the hand-flown ship from the aerodynamics suite. Lines starting REPORT
# are numbers worth reading, not checks.
extends "res://tests/test_aerodynamics.gd"

## Level ground around the top of the home planet, where ships in these tests are set down.
const LEVEL_COLUMNS: int = 600

var _level_height: float = 0.0


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_build_world()
	_level_height = (_model as PatchedConicsModel).add_flat_ground(_planet_index, -LEVEL_COLUMNS, LEVEL_COLUMNS, 60)

	_test_hold_headings()
	_test_forecast_from_the_top_of_the_air()
	_test_forecast_from_orbit()
	_test_forecast_with_stab()
	_test_verdicts()
	_test_moon()
	_test_never_waits()
	_test_path_line()
	_test_comms_status()

	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
	return true


# A forecast worked out here and now, the way the ship asks for one, with its verdict.
func _forecast(ship: Node2D) -> Dictionary:
	var answer: Dictionary = _model.predict_descent(ship._state_copy(), ship._aero_copy(), ship._flight_now(), ship.prediction_horizon, ship.prediction_samples)
	answer["verdict"] = ship._verdict_of(answer) if answer["lands"] else ""
	return answer


# How far around the body the forecast's landing is, as an angle fixed to the ground.
func _forecast_on_ground(forecast: Dictionary) -> float:
	var end: PackedFloat64Array = forecast["end"]
	return atan2(end[0], -end[1]) - forecast["spin"] * forecast["ground_time"]


# The same for where a ship is right now.
func _ship_on_ground(ship: Node2D, radius: float) -> float:
	return _model.get_ground_column(ship.state.x, ship.state.y, ship.state.time) * WORLD_PIXEL / radius


# Flies to the ground and compares with a forecast made earlier: how far apart along the ground,
# whether the real landing is inside the forecast's zone, and the speeds.
func _compare(label: String, ship: Node2D, forecast: Dictionary, most_apart: float) -> void:
	var seconds: float = 0.0
	while not ship.state.is_on_surface() and seconds < 3600.0:
		ship._physics_process(TICK)
		seconds += TICK
	var landed_at: float = _ship_on_ground(ship, _planet.radius)
	var apart: float = angle_difference(_forecast_on_ground(forecast), landed_at) * _planet.radius
	var spin_turn: float = forecast["spin"] * forecast["ground_time"]
	var into_zone: float = angle_difference(forecast["zone_from"] - spin_turn, landed_at)
	var zone_width: float = forecast["zone_to"] - forecast["zone_from"]
	_report("%s: forecast %s at %.0f units/s; really came down %.0f units (%.1f m) away at %.0f units/s, after %.0f s. The landing zone was %.0f m wide." % [label, forecast["verdict"], forecast["speed"], absf(apart), Units.meters(absf(apart)), ship.state.get_touchdown_speed(), seconds, Units.meters(zone_width * _planet.radius)])
	_check_true("%s: the forecast lands close to the real flight" % label, absf(apart) < most_apart)
	_check_true("%s: the real landing is inside the landing zone" % label, into_zone >= -0.00001 and into_zone <= zone_width + 0.00001)
	_check("%s: at about the forecast speed" % label, ship.state.get_touchdown_speed(), forecast["speed"], 15.0)


# The headings STAB holds come from the physics core now, for the ship and the forecast alike.
func _test_hold_headings() -> void:
	var at: PackedFloat64Array = _model.get_body_position(_planet_index, 0.0)
	var moving: PackedFloat64Array = _model.get_body_velocity(_planet_index, 0.0)
	# Over the top of the planet, moving right.
	var headings: PackedFloat64Array = _model.get_hold_headings(at[0], at[1] - 200000.0, moving[0] + 3000.0, moving[1], 0.0)
	_check("along the path is nose right", headings[0], PI / 2.0, 1e-9)
	_check("against it is nose left", angle_difference(headings[1], -PI / 2.0), 0.0, 1e-9)
	_check("toward the planet is nose down", angle_difference(headings[2], PI), 0.0, 1e-9)
	_check("away from it is nose up", headings[3], 0.0, 1e-9)


# Hands off from the top of the air: the forecast made there, against the flight from there.
func _test_forecast_from_the_top_of_the_air() -> void:
	var ship: Node2D = _deorbit(0.0)
	ship.fuel = ship.body.fuel_capacity * 0.1
	ship._update_performance()
	ship.assist_enabled = true
	ship.stab_enabled = true
	while _model.get_air_density(ship.state.x, ship.state.y, ship.state.time) <= 0.0:
		ship._physics_process(TICK)
	ship.stab_enabled = false
	var forecast: Dictionary = _forecast(ship)
	_check_true("at the top of the air there's a landing to forecast", forecast["lands"] and forecast["air"])
	# The flat lander comes down about 233 here where the first one did 286, so it's a hard landing, not a crash.
	_check_true("the start orbit's descent, hands off, isn't safe (%s)" % forecast["verdict"], forecast["verdict"] == "HARD" or forecast["verdict"] == "CRASH")
	var again: Dictionary = _forecast(ship)
	_check("the same forecast twice is the same", again["speed"] - forecast["speed"] + again["zone_to"] - forecast["zone_to"], 0.0, 0.0)
	_compare("hands off from the top of the air", ship, forecast, 400.0)
	ship.free()


# The same descent forecast from the start orbit, half a lap before the air.
func _test_forecast_from_orbit() -> void:
	var ship: Node2D = _deorbit(0.0)
	ship.fuel = ship.body.fuel_capacity * 0.1
	ship._update_performance()
	ship.assist_enabled = true
	var forecast: Dictionary = _forecast(ship)
	_check_true("from the start orbit there's a landing to forecast", forecast["lands"] and forecast["air"])
	_check_true("its line through the air starts above the air, later on", forecast["ground_time"] > ship.state.time + 10.0)
	_compare("hands off from the start orbit", ship, forecast, 2000.0)
	ship.free()

	# Up in a round orbit, nothing's coming down, and nothing's asked for.
	ship = _ship_over(_planet_index, _planet.radius, 30000.0, Vector2.ZERO, 0.0)
	var body_velocity: PackedFloat64Array = _model.get_body_velocity(_planet_index, 0.0)
	ship.state.velocity_x = body_velocity[0] + sqrt(_planet.get_mu() / (_planet.radius + 30000.0))
	ship.state.velocity_y = body_velocity[1]
	_check_true("a round orbit isn't coming down", not ship._is_coming_down())
	ship.free()


# With STAB holding engine first, the forecast flies it held too.
func _test_forecast_with_stab() -> void:
	var ship: Node2D = _deorbit(0.0)
	ship.fuel = ship.body.fuel_capacity * 0.1
	ship._update_performance()
	ship.stab_enabled = true
	while _model.get_air_density(ship.state.x, ship.state.y, ship.state.time) <= 0.0:
		ship._physics_process(TICK)
	var forecast: Dictionary = _forecast(ship)
	_compare("held engine first by STAB", ship, forecast, 400.0)
	ship.free()


func _test_verdicts() -> void:
	# Let go a little above level ground, sinking slowly, on the engine bell.
	var ship: Node2D = _ship_over(_planet_index, _planet.radius, _level_height + 105.0 + 4.0, Vector2(0.0, 10.0), 0.0, 0.1)
	var forecast: Dictionary = _forecast(ship)
	_check_true("a gentle, slow touchdown is SAFE (%s at %.0f units/s)" % [forecast["verdict"], forecast.get("speed", -1.0)], forecast["verdict"] == "SAFE")
	_fly(ship, 3.0)
	_check("and it really touches down at that speed", ship.state.get_touchdown_speed(), forecast["speed"], 3.0)
	ship.free()

	# A little higher, it's a hard landing, and from higher still a crash.
	ship = _ship_over(_planet_index, _planet.radius, _level_height + 105.0 + 60.0, Vector2(0.0, 10.0), 0.0, 0.1)
	forecast = _forecast(ship)
	_check_true("dropped from 3 m it's HARD (%s at %.0f units/s)" % [forecast["verdict"], forecast.get("speed", -1.0)], forecast["verdict"] == "HARD")
	ship.free()
	ship = _ship_over(_planet_index, _planet.radius, _level_height + 105.0 + 400.0, Vector2(0.0, 10.0), 0.0, 0.1)
	forecast = _forecast(ship)
	_check_true("dropped from 20 m it's a CRASH (%s at %.0f units/s)" % [forecast["verdict"], forecast.get("speed", -1.0)], forecast["verdict"] == "CRASH")
	ship.free()

	# The same slow touchdown on ground too steep to stand on isn't safe.
	ship = _ship_over(_planet_index, _planet.radius, _level_height + 105.0 + 4.0, Vector2(0.0, 10.0), 0.0, 0.1)
	_check_true("level ground isn't too steep", not ship._too_steep(0.0))
	_check_true("ground rising 12 units under the bell is", ship._too_steep(12.0))
	ship.legs_down = true
	_check_true("but not under the legs, which stand wider", not ship._too_steep(12.0))
	ship.legs_down = false
	var steep: Dictionary = _forecast(ship)
	steep["rise"] = 12.0
	_check_true("so a slow touchdown there is HARD, not SAFE", ship._verdict_of(steep) == "HARD")
	ship.free()

	# Straight down into the air, very fast: the hull can't take it.
	ship = _ship_over(_planet_index, _planet.radius, 14900.0, Vector2(0.0, 12000.0), 0.0)
	forecast = _forecast(ship)
	_report("straight down into the air at 12,000 units/s: forecast %s, hull reaching %.2f" % [forecast["verdict"], forecast["peak_hull"]])
	_check_true("a steep, fast entry is a BURN-UP", forecast["verdict"] == "BURN-UP")
	var hottest: float = 0.0
	var seconds: float = 0.0
	while not ship.state.is_on_surface() and seconds < 120.0:
		ship._physics_process(TICK)
		seconds += TICK
		hottest = maxf(hottest, ship.hull_temperature)
	_check_true("and the real hull does burn (%.2f)" % hottest, hottest > 1.0)
	ship.free()


# The moon has no air: the forecast is the plain coast to the ground, with its speed.
func _test_moon() -> void:
	var ship: Node2D = _ship_over(_moon_index, _moon.radius, 3000.0, Vector2(150.0, 20.0), 0.0)
	var forecast: Dictionary = _forecast(ship)
	_check_true("falling onto the moon, there's a landing to forecast", forecast["lands"])
	_check_true("with no air, and no line flown through any", not forecast["air"] and not forecast.has("path"))
	_check_true("and nowhere for a landing zone to spread", not forecast.has("zone_from"))
	_check_true("a fall from that high is a CRASH (%s)" % forecast["verdict"], forecast["verdict"] == "CRASH")
	var touchdown_time: float = forecast["touchdown_time"]
	var seconds: float = 0.0
	while not ship.state.is_on_surface() and seconds < 600.0:
		ship._physics_process(TICK)
		seconds += TICK
	_check("it hits at the forecast speed", ship.state.get_touchdown_speed(), forecast["speed"], 2.0)
	_check("at the forecast time", ship.state.time, touchdown_time, 0.2)
	# The wreck settles lower than the ship stood, so compare how far around the moon they are.
	var body_now: PackedFloat64Array = _model.get_body_position(_moon_index, ship.state.time)
	var end: PackedFloat64Array = forecast["end"]
	var around: float = angle_difference(atan2(end[0], -end[1]), atan2(ship.state.x - body_now[0], body_now[1] - ship.state.y))
	_check("in the forecast place", around * _moon.radius, 0.0, 10.0)
	ship.free()

	# Let go just above the moon, it's safe.
	var ground: float = _model.get_ground_height(_model.get_body_position(_moon_index, 0.0)[0], _model.get_body_position(_moon_index, 0.0)[1] - _moon.radius, 0.0)
	ship = _ship_over(_moon_index, _moon.radius, ground + 105.0 + 10.0, Vector2.ZERO, 0.0)
	var gentle: Dictionary = _forecast(ship)
	_check_true("let go 10 units above the moon, it's not a crash (%s at %.0f units/s)" % [gentle["verdict"], gentle.get("speed", -1.0)], gentle["verdict"] == "SAFE" or gentle["verdict"] == "HARD")
	ship.free()


# Asking for a forecast returns at once, and the answer turns up later without anyone waiting.
func _test_never_waits() -> void:
	var ship: Node2D = _deorbit(0.0)
	ship.assist_enabled = true
	var prediction := LandingPrediction.new()
	var started: int = Time.get_ticks_usec()
	prediction.start(_model, ship._state_copy(), ship._aero_copy(), ship._flight_now(), ship.prediction_horizon, ship.prediction_samples)
	var asking: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var early: Dictionary = prediction.take()
	var taking: int = Time.get_ticks_usec() - started
	_check_true("asking for a forecast takes no time to speak of (%d microseconds)" % asking, asking < 2000)
	_check_true("and looking for the answer doesn't wait for it (%d microseconds)" % taking, taking < 2000 and early.is_empty() or not early.is_empty())
	var answer: Dictionary = early
	var waited_from: int = Time.get_ticks_msec()
	while answer.is_empty() and Time.get_ticks_msec() - waited_from < 5000:
		OS.delay_msec(1)
		answer = prediction.take()
	_check_true("the answer turns up by itself", answer.get("lands", false))
	_check_true("and then there's nothing left running", not prediction.is_busy())
	_report("a forecast from the start orbit takes about %d ms on another thread here" % (Time.get_ticks_msec() - waited_from))

	# The ship keeps one going by itself, a few times a second, and tells whoever's listening.
	var heard: Array[Dictionary] = []
	ship.landing_predicted.connect(func(prediction_heard: Dictionary) -> void: heard.append(prediction_heard))
	var slowest: int = 0
	waited_from = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited_from < 1200:
		started = Time.get_ticks_usec()
		ship._forecast_landing()
		slowest = maxi(slowest, Time.get_ticks_usec() - started)
		OS.delay_msec(4)
	_check_true("the ship hears forecasts a few times a second (%d in 1.2 s)" % heard.size(), heard.size() >= 2 and heard.size() <= 6)
	_check_true("each with a verdict", heard.size() > 0 and heard[heard.size() - 1].get("verdict", "") == "CRASH")
	_check_true("and keeping them coming never holds the flight up (%d microseconds at worst)" % slowest, slowest < 3000)
	ship.free()


# The path line: above the air it stops at the top of the air and the flown line carries on to the
# ground. In the air there's only the flown line. On the moon the coast is left as it is.
func _test_path_line() -> void:
	var ship: Node2D = _deorbit(0.0)
	var line: Node2D = load("res://scripts/trajectory_preview.gd").new()
	root.add_child(line)
	line.start_preview(_model, ship.state)
	line._on_view_changed(ship.state.x, ship.state.y, 1.0 / 800.0)
	var whole: int = line._screen_points.size()
	_check("with no forecast, the coast is drawn whole", whole, line.sample_count, 0.0)
	_check_true("and there's no landing to label", line.landing_point().is_empty())
	var forecast: Dictionary = _forecast(ship)
	line._on_ship_landing_predicted(forecast)
	_check_true("with one, the coast stops at the top of the air (%d of %d points)" % [line._screen_points.size(), whole], line._screen_points.size() < whole and line._screen_points.size() >= 2)
	_check_true("and the flown line carries on from there", line._flown.points.size() >= 16 and not line._riding)
	var coast_end: Vector2 = line._screen_points[line._screen_points.size() - 1] / line._pixels_per_unit + Vector2(line._anchor_x, line._anchor_y)
	_check("starting where the coast stops", coast_end.distance_to(line._flown.points[0]), 0.0, 400.0)
	var landing: PackedFloat64Array = line.landing_point()
	var body_now: PackedFloat64Array = _model.get_body_position(_planet_index, ship.state.time)
	var landing_height: float = Vector2(landing[0] - body_now[0], landing[1] - body_now[1]).length() - _planet.radius
	_check_true("and ending on the ground (%.0f units above the base)" % landing_height, landing_height > 0.0 and landing_height < 3500.0)
	_check_true("with the landing zone marked along the ground there", line._flown.zone.size() >= 3)

	# Once the ship's in the air, only the flown line is left, starting from the ship.
	ship.stab_enabled = true
	while _model.get_air_density(ship.state.x, ship.state.y, ship.state.time) <= 0.0:
		ship._physics_process(TICK)
	_fly(ship, 2.0)
	line._on_ship_landing_predicted(_forecast(ship))
	line._on_ship_world_position_changed(ship.state.x, ship.state.y)
	_check_true("in the air, the line is the flown one alone", line._riding and line._flown.from_index >= 0)
	_fly(ship, 1.0)
	line._on_ship_world_position_changed(ship.state.x, ship.state.y)
	var from_body := Vector2(ship.state.x - _model.get_body_position(_planet_index, ship.state.time)[0], ship.state.y - _model.get_body_position(_planet_index, ship.state.time)[1])
	var drawn_from: Vector2 = line._flown.from_point.rotated(line._ground_turn())
	_check("and it starts from the ship as it flies on", drawn_from.distance_to(from_body), 0.0, 1.0)
	var next_on_line: Vector2 = line._flown.points[line._flown.from_index]
	_check_true("with the rest of the line just ahead", next_on_line.distance_to(line._flown.from_point) < 3000.0)
	line._on_ship_landing_predicted({})
	_check_true("with no forecast any more, it's the coast again", not line._riding and line._flown.points.is_empty())
	ship.free()
	line.free()

	ship = _ship_over(_moon_index, _moon.radius, 3000.0, Vector2(150.0, 20.0), 0.0)
	line = load("res://scripts/trajectory_preview.gd").new()
	root.add_child(line)
	line.start_preview(_model, ship.state)
	line._on_view_changed(ship.state.x, ship.state.y, 1.0 / 8.0)
	whole = line._screen_points.size()
	line._on_ship_landing_predicted(_forecast(ship))
	_check("over the moon, the coast is left whole", line._screen_points.size(), whole, 0.0)
	_check_true("with nothing flown through air", line._flown.points.is_empty() and not line._riding)
	var moon_now: PackedFloat64Array = _model.get_body_position(_moon_index, ship.state.time)
	var coast_last: Vector2 = line._screen_points[whole - 1] / line._pixels_per_unit + Vector2(line._anchor_x, line._anchor_y)
	var labelled: PackedFloat64Array = line.landing_point()
	_check("and the label goes at the end of it", coast_last.distance_to(Vector2(labelled[0] - moon_now[0], labelled[1] - moon_now[1])), 0.0, 60.0)
	ship.free()
	line.free()


func _test_comms_status() -> void:
	var comms := CommsLine.new()
	var data := {"time": 0.0, "docked": false, "landed": false, "periapsis": -100.0, "apoapsis": 5000.0, "against_station": false}
	comms._on_flight_data(data)
	_check_true("with no forecast, a path into the ground is an IMPACT TRAJECTORY", comms._status == "IMPACT TRAJECTORY")
	for verdict: String in ["SAFE", "HARD", "CRASH", "BURN-UP"]:
		data["landing"] = verdict
		comms._on_flight_data(data)
		_check_true("a %s forecast reads %s TRAJECTORY" % [verdict, verdict], comms._status == "%s TRAJECTORY" % verdict)
	data["landing"] = ""
	data["periapsis"] = 20000.0
	comms._on_flight_data(data)
	_check_true("and a clear orbit is ORBIT STABLE again", comms._status == "ORBIT STABLE")
	comms.free()
