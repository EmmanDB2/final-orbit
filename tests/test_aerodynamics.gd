# test_aerodynamics.gd: checks how the air pushes on a ship, from simple shapes with known answers
# up to whole descents flown by the real ship script.
# From DESIGN.md, "Physics" (Aerodynamics). Run after building the Mac library:
#   godot --headless --path . --script tests/test_aerodynamics.gd
#
# The descents drive scenes/ship.tscn by calling its physics tick by hand, so they run as fast as
# the machine can go and come out the same every time. Lines starting REPORT are numbers worth
# reading, not checks.
extends SceneTree

const TICK: float = 1.0 / 60.0
## Ten times warp, the most there is in air.
const WARP_TICK: float = 10.0 / 60.0
const WORLD_PIXEL: float = 2.0

var _checks: int = 0
var _failures: int = 0
var _ran: bool = false
var _model: GravityModel
var _planet: BodyData
var _planet_index: int = 0
var _moon: BodyData
var _moon_index: int = 0
var _warnings: Array[String] = []


# Nodes added before the first frame aren't ready yet, so everything runs from the first frame.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_build_world()

	_test_flat_face()
	_test_tilted_plate()
	_test_dart_leads_with_its_heavy_end()
	_test_spin_dies_in_air()
	_test_shade()
	_test_air_never_adds_energy()
	_test_long_ticks_match_short_ones()
	_test_cost()

	_test_outline_follows_the_ship()
	_test_lander_trim()
	_test_damaged_side()
	_test_lift()
	_test_stab_against_the_air()
	_test_moon_has_no_air()
	_test_descents()

	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	var ok: bool = absf(actual - expected) <= tolerance
	if not ok:
		_failures += 1
	print("%s %s: got %s, expected %s, within %s" % ["PASS" if ok else "FAIL", label, snappedf(actual, 0.0001), snappedf(expected, 0.0001), tolerance])


func _check_true(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _report(text: String) -> void:
	print("REPORT %s" % text)


# --- Simple shapes, straight on the physics core ---


func _box(half_width: float, half_length: float, middle: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		middle + Vector2(-half_width, -half_length), middle + Vector2(half_width, -half_length),
		middle + Vector2(half_width, half_length), middle + Vector2(-half_width, half_length)])


func _shape(polygons: Array[PackedVector2Array], mass: float, spin_resistance: float, center: Vector2 = Vector2.ZERO) -> AeroBody:
	var aero := AeroBody.new()
	aero.pressure_coefficient = 2.0
	aero.set_outline(polygons, 2.0)
	aero.set_mass(mass, spin_resistance, center)
	return aero


# A face square to the air stops all of it: half the coefficient, times density, speed squared, and
# the face's length. Nothing else on a box faces the air.
func _test_flat_face() -> void:
	var aero: AeroBody = _shape([_box(10.0, 30.0)], 100.0, 1000.0)
	# Moving up the screen, nose first, at 50.
	var loads: PackedFloat64Array = aero.measure(0.5, 0.0, -50.0, 0.0, 0.0)
	_check("a square face is pushed straight back", loads[AeroBody.STEP_FORCE_Y], 0.5 * 2.0 * 0.5 * 2500.0 * 20.0, 1e-6)
	_check("and not sideways", loads[AeroBody.STEP_FORCE_X], 0.0, 1e-6)
	_check("and not turned", loads[AeroBody.STEP_TORQUE], 0.0, 1e-6)
	# Side on, the long side catches three times as much.
	loads = aero.measure(0.5, 50.0, 0.0, 0.0, 0.0)
	_check("side on, the long side catches it", loads[AeroBody.STEP_FORCE_X], -0.5 * 2.0 * 0.5 * 2500.0 * 60.0, 1e-6)
	# The same push whichever way the ship and the air are turned together.
	loads = aero.measure(0.5, 50.0, 0.0, PI / 2.0, 0.0)
	_check("turned with the air, it's the same push", loads[AeroBody.STEP_FORCE_X], -0.5 * 2.0 * 0.5 * 2500.0 * 20.0, 1e-6)
	_check("heating is the root of density times speed cubed", loads[AeroBody.STEP_HEAT], sqrt(0.5) * 125000.0, 1e-6)
	_check("the hot side faces the way it's going", loads[AeroBody.STEP_HOT_X], 0.0, 1e-9)
	loads = aero.measure(0.0, 50.0, 0.0, 0.0, 0.0)
	_check("no air, no push", absf(loads[AeroBody.STEP_FORCE_X]) + absf(loads[AeroBody.STEP_FORCE_Y]) + absf(loads[AeroBody.STEP_TORQUE]) + loads[AeroBody.STEP_HEAT], 0.0, 0.0)


# A thin plate tilted 45 degrees to the air is pushed square to its face: as much sideways as back.
func _test_tilted_plate() -> void:
	var aero: AeroBody = _shape([_box(40.0, 0.5)], 100.0, 1000.0)
	var loads: PackedFloat64Array = aero.measure(1.0, 0.0, -100.0, PI / 4.0, 0.0)
	var drag: float = loads[AeroBody.STEP_FORCE_Y]
	var lift: float = absf(loads[AeroBody.STEP_FORCE_X])
	_check_true("a tilted plate is slowed", drag > 0.0)
	# The plate's thin ends catch a little too, so it's close to even, not exact.
	_check("and pushed sideways about as hard", lift / drag, 1.0, 0.05)


# A long thin body with its mass at one end, like a dart, turns to lead with that end from any
# start and stops swinging. Nothing says which end is the front: it's the mass and the shape.
func _test_dart_leads_with_its_heavy_end() -> void:
	var aero: AeroBody = _shape([_box(6.0, 60.0)], 2000.0, 400000.0, Vector2(0.0, -50.0))
	for start: float in [0.3, PI / 2.0, PI - 0.3, -2.0]:
		var heading: float = start
		var spin: float = 0.0
		var velocity := Vector2(0.0, -400.0)
		var late_swing: float = 0.0
		for tick in range(60 * 40):
			var flown: PackedFloat64Array = aero.step(TICK, 0.05, velocity.x, velocity.y, heading, spin, AeroBody.CONTROL_NONE, 0.0)
			# Hold its speed through the air, as falling at its top speed would, so only its turning shows.
			heading = flown[AeroBody.STEP_HEADING]
			spin = flown[AeroBody.STEP_SPIN]
			if tick > 60 * 35:
				late_swing = maxf(late_swing, absf(spin))
		_check("a dart started at %.1f ends up heavy end first" % start, absf(angle_difference(heading, 0.0)), 0.0, 0.02)
		_check("and its swing dies out", late_swing, 0.0, 0.01)


func _test_spin_dies_in_air() -> void:
	var aero: AeroBody = _shape([_box(20.0, 60.0)], 5000.0, 4000000.0)
	var spin: float = 3.0
	var heading: float = 0.0
	for tick in range(60 * 10):
		var flown: PackedFloat64Array = aero.step(TICK, 0.2, 0.0, 0.0, heading, spin, AeroBody.CONTROL_NONE, 0.0)
		heading = flown[AeroBody.STEP_HEADING]
		spin = flown[AeroBody.STEP_SPIN]
	_check_true("spinning in still air slows the spin (3.0 down to %.3f)" % spin, spin > 0.0 and spin < 1.0)
	var empty: PackedFloat64Array = aero.step(1.0, 0.0, 0.0, 0.0, 0.0, 3.0, AeroBody.CONTROL_NONE, 0.0)
	_check("spinning in a vacuum doesn't", empty[AeroBody.STEP_SPIN], 3.0, 0.0)


# One layer directly behind another feels nothing, and beside it feels the air again.
func _test_shade() -> void:
	var front: PackedVector2Array = _box(20.0, 5.0, Vector2(0.0, -40.0))
	var alone: AeroBody = _shape([front], 100.0, 1000.0)
	var behind: AeroBody = _shape([front, _box(10.0, 5.0, Vector2(0.0, 0.0))], 100.0, 1000.0)
	var beside: AeroBody = _shape([front, _box(10.0, 5.0, Vector2(60.0, 0.0))], 100.0, 1000.0)
	var push_alone: float = alone.measure(1.0, 0.0, -100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	var push_behind: float = behind.measure(1.0, 0.0, -100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	var push_beside: float = beside.measure(1.0, 0.0, -100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	_check("a part behind another is out of the air", push_behind, push_alone, 1e-6)
	_check("a part beside it isn't", push_beside, push_alone * 1.5, 1e-6)
	# Coming the other way, the small part is in front, and shades only what's behind it.
	var push_back: float = -behind.measure(1.0, 0.0, 100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	_check("from the other side, the small part shades half the big one", push_back, push_alone, 1e-6)


# The air only ever slows the ship's motion through it, at any speed, spin, air, or tick length.
func _test_air_never_adds_energy() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var full: Dictionary = body.with_fuel(body.fuel_capacity)
	var aero := AeroBody.new()
	aero.set_outline(body.outline_polygons_now(), design.air_segment_length)
	aero.set_mass(full["mass"], full["spin_resistance"], full["center_of_mass"])
	var random := RandomNumberGenerator.new()
	random.seed = 20261110
	var gained: int = 0
	var broken: int = 0
	var most_substeps: int = 0
	for i in range(4000):
		var speed: float = pow(10.0, random.randf_range(0.0, 4.7))
		var way: float = random.randf_range(0.0, TAU)
		var velocity := Vector2(cos(way), sin(way)) * speed
		var spin: float = random.randf_range(-8.0, 8.0)
		var density: float = pow(10.0, random.randf_range(-4.0, 0.5))
		var dt: float = [TICK * 0.5, TICK, TICK * 5.0, WARP_TICK, 100.0 * TICK][random.randi_range(0, 4)]
		var flown: PackedFloat64Array = aero.step(dt, density, velocity.x, velocity.y, random.randf_range(0.0, TAU), spin, AeroBody.CONTROL_NONE, 0.0)
		var after := Vector2(velocity.x + flown[AeroBody.STEP_VELOCITY_X], velocity.y + flown[AeroBody.STEP_VELOCITY_Y])
		var spin_after: float = flown[AeroBody.STEP_SPIN]
		var before_energy: float = full["mass"] * velocity.length_squared() + full["spin_resistance"] * spin * spin
		var after_energy: float = full["mass"] * after.length_squared() + full["spin_resistance"] * spin_after * spin_after
		if after_energy > before_energy * (1.0 + 1e-12):
			gained += 1
		for value: float in flown:
			if is_nan(value) or is_inf(value):
				broken += 1
		most_substeps = maxi(most_substeps, int(flown[AeroBody.STEP_SUBSTEPS]))
	_check("the air never adds energy, over 4,000 wild steps", gained, 0.0, 0.0)
	_check("and never gives a number that isn't one", broken, 0.0, 0.0)
	_report("most short steps in one tick: %d" % most_substeps)


# The same ten seconds through the air as 600 normal ticks and as 60 ticks at ten times warp.
func _test_long_ticks_match_short_ones() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var full: Dictionary = body.with_fuel(body.fuel_capacity)
	var aero := AeroBody.new()
	aero.set_outline(body.outline_polygons_now(), design.air_segment_length)
	aero.set_mass(full["mass"], full["spin_resistance"], full["center_of_mass"])
	var ends: Array[PackedFloat64Array] = []
	for tick: float in [TICK, WARP_TICK]:
		var velocity := Vector2(1500.0, 300.0)
		var heading: float = 0.4
		var spin: float = 0.5
		for i in range(roundi(10.0 / tick)):
			var flown: PackedFloat64Array = aero.step(tick, 0.02, velocity.x, velocity.y, heading, spin, AeroBody.CONTROL_NONE, 0.0)
			velocity += Vector2(flown[AeroBody.STEP_VELOCITY_X], flown[AeroBody.STEP_VELOCITY_Y])
			heading = flown[AeroBody.STEP_HEADING]
			spin = flown[AeroBody.STEP_SPIN]
		ends.append(PackedFloat64Array([velocity.x, velocity.y, heading, spin]))
	_check("ten times warp ends at the same speed", Vector2(ends[1][0] - ends[0][0], ends[1][1] - ends[0][1]).length(), 0.0, 0.01)
	_check("and the same heading", ends[1][2], ends[0][2], 1e-4)
	_check("and the same spin", ends[1][3], ends[0][3], 1e-4)


func _test_cost() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	body.set_parts_out(1.0)
	var full: Dictionary = body.with_fuel(body.fuel_capacity)
	var aero := AeroBody.new()
	aero.set_outline(body.outline_polygons_now(), design.air_segment_length)
	aero.set_mass(full["mass"], full["spin_resistance"], full["center_of_mass"])
	aero.set_rcs(1.5, true, true)
	var rounds: int = 20000
	var started: int = Time.get_ticks_usec()
	for i in range(rounds):
		aero.step(TICK, 0.02, 3000.0, 400.0, i * 0.001, 0.2, AeroBody.CONTROL_DAMP, 0.0)
	var normal: float = float(Time.get_ticks_usec() - started) / rounds
	started = Time.get_ticks_usec()
	for i in range(rounds / 10):
		aero.step(WARP_TICK, 0.02, 3000.0, 400.0, i * 0.001, 0.2, AeroBody.CONTROL_DAMP, 0.0)
	var warped: float = float(Time.get_ticks_usec() - started) / (rounds / 10)
	started = Time.get_ticks_usec()
	for i in range(200):
		aero.set_outline(body.outline_polygons_now(), design.air_segment_length)
	var rebuild: float = float(Time.get_ticks_usec() - started) / 200.0
	_report("the lander with its legs down is %d pieces; a tick in air costs %.1f microseconds here, %.1f at ten times warp, and a rebuild of the outline %.0f" % [aero.get_segment_count(), normal, warped, rebuild])
	_check_true("a tick in air is far under a millisecond", normal < 200.0 and warped < 1000.0)


# --- The real ship, flown by hand ---


func _build_world() -> void:
	var star: BodyData = load("res://data/home_star.tres")
	_planet = load("res://data/home_planet.tres")
	_moon = load("res://data/moon.tres")
	var model := PatchedConicsModel.new()
	model.set_central_body(star.get_mu(), star.radius, star.landing_line_altitude)
	_planet_index = _add_body(model, 0, _planet)
	_moon_index = _add_body(model, _planet_index, _moon)
	_model = model


# The same setup as main.gd gives each body.
func _add_body(model: PatchedConicsModel, parent: int, body: BodyData) -> int:
	var index: int = model.add_body(parent, body.get_mu(), body.radius,
			body.orbit_semi_major_axis, body.orbit_eccentricity, body.orbit_argument_of_periapsis,
			body.orbit_start_angle, body.landing_line_altitude)
	model.set_body_spin(index, body.spin_rate)
	model.set_body_atmosphere(index, body.air_density, body.air_scale_height)
	model.set_body_terrain(index, body.terrain_seed, body.terrain_mountains, body.terrain_hills,
			body.terrain_rough, body.terrain_rocks, body.terrain_crater_depth, body.terrain_crater_share,
			body.terrain_cliff_step, body.sea_level, body.radius * 0.6, body.terrain_ridge_height)
	return index


# A ship over the top of a body, this high above its base radius, moving at this velocity against
# the air there (or against the body, above the air). Starts in RAW with nothing switched on.
func _ship_over(body_index: int, radius: float, height: float, through: Vector2, heading: float, fuel_share: float = 1.0) -> Node2D:
	var ship: Node2D = load("res://scenes/ship.tscn").instantiate()
	root.add_child(ship)
	var at: PackedFloat64Array = _model.get_body_position(body_index, 0.0)
	var state := ShipState.new()
	state.x = at[0]
	state.y = at[1] - radius - height
	var air: PackedFloat64Array = _model.get_surface_velocity(state.x, state.y, 0.0)
	state.velocity_x = air[0] + through.x
	state.velocity_y = air[1] + through.y
	ship.assist_enabled = false
	ship.start_flight(_model, state, heading)
	ship.fuel = ship.body.fuel_capacity * fuel_share
	ship._update_performance()
	_warnings.clear()
	ship.warning_raised.connect(func(text: String) -> void: _warnings.append(text))
	return ship


func _through_air(ship: Node2D) -> Vector2:
	var state: ShipState = ship.state
	var air: PackedFloat64Array = _model.get_surface_velocity(state.x, state.y, state.time)
	return Vector2(state.velocity_x - air[0], state.velocity_y - air[1])


# How far the engine end is from leading the way through the air, in degrees: 0 is engine first,
# 90 broadside, and 180 nose first.
func _off_engine_first(ship: Node2D) -> float:
	return rad_to_deg(Vector2.DOWN.rotated(ship.heading).angle_to(_through_air(ship)))


func _fly(ship: Node2D, seconds: float, tick: float = TICK) -> void:
	for i in range(roundi(seconds / tick)):
		if ship.state.is_on_surface():
			return
		ship._physics_process(tick)


# Where a ship's outline settles against a steady wind, found by turning it through the wind and
# watching which way the air turns it back: in degrees off engine first, to each side.
func _steady_trims(ship: Node2D) -> PackedFloat64Array:
	var aero: AeroBody = ship._aero
	aero.set_outline(ship.body.outline_polygons_now(), ship.design.air_segment_length)
	var trims := PackedFloat64Array()
	var last: float = 0.0
	for step in range(0, 721):
		var off: float = deg_to_rad(step * 0.5)
		# Engine first is the ship pointing up while moving down the screen.
		var torque: float = aero.measure(1.0, 0.0, 100.0, -off, 0.0)[AeroBody.STEP_TORQUE]
		# Settled is where the air turns it back from both sides.
		if step > 0 and last < 0.0 and torque >= 0.0:
			trims.append(wrapf(step * 0.5 - 0.25, -180.0, 180.0))
		last = torque
	return trims


func _test_outline_follows_the_ship() -> void:
	var ship: Node2D = _ship_over(_planet_index, _planet.radius, 9000.0, Vector2(0.0, 300.0), 0.0)
	_fly(ship, 0.1)
	_check_true("the air has an outline to push on (%d pieces)" % ship._aero.get_segment_count(), ship._aero.get_segment_count() > 40)
	# The push on it falling engine first, at a set speed and air.
	var stowed: float = ship._aero.measure(1.0, 0.0, 100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	ship._toggle_legs()
	_fly(ship, 2.5)
	var down: float = ship._aero.measure(1.0, 0.0, 100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	_check_true("legs down catch more air (%.0f against %.0f)" % [absf(down), absf(stowed)], absf(down) > absf(stowed) * 1.1)
	ship.take_hit(Vector2(50.0, 40.0), 4.0e8)
	_fly(ship, 0.1)
	var after: float = ship._aero.measure(1.0, 0.0, 100.0, 0.0, 0.0)[AeroBody.STEP_FORCE_Y]
	_check_true("and damage changes it again", after != down)
	ship.free()


# Dropped into the home planet's air every which way, with nothing holding it, the lander ends up
# the same way round each time, and stops swinging. Which way that is comes from its shape and its
# mass: this reports it, and checks drained tanks make it less steady.
func _test_lander_trim() -> void:
	var trims: Dictionary = {}
	for fuel_share: float in [1.0, 0.0]:
		var probe: Node2D = _ship_over(_planet_index, _planet.radius, 14500.0, Vector2.ZERO, 0.0, fuel_share)
		var steady: PackedFloat64Array = _steady_trims(probe)
		probe.free()
		_check("the lander has one way it settles to each side, tanks %d%%" % roundi(fuel_share * 100.0), steady.size(), 2.0, 0.0)
		if steady.size() != 2:
			continue
		trims[fuel_share] = absf(steady[0])
		_check("the same tilt to either side", absf(steady[0]) - absf(steady[1]), 0.0, 4.0)

		# Dead on engine first or nose first it balances for a while before it goes, like a pencil on
		# its point, so those two start a few degrees off.
		for start: Array in [["engine first", 4.0], ["broadside", 90.0], ["nose first", 176.0], ["broadside the other way", -90.0]]:
			# Engine first while falling straight down is nose up, and each start turns it from there.
			var ship: Node2D = _ship_over(_planet_index, _planet.radius, 14500.0, Vector2(0.0, 600.0), -deg_to_rad(start[1]), fuel_share)
			var spins := PackedFloat64Array()
			var seconds: float = 0.0
			var settled: float = 0.0
			while seconds < 60.0:
				ship._physics_process(TICK)
				seconds += TICK
				if ship.state.is_on_surface():
					break
				settled = _off_engine_first(ship)
				spins.append(absf(ship.angular_velocity))
			# The swing over the whole fall, against the last second of it.
			var largest_spin: float = 0.0
			var late_spin: float = 0.0
			for i in range(spins.size()):
				largest_spin = maxf(largest_spin, spins[i])
				if i >= spins.size() - 60:
					late_spin = maxf(late_spin, spins[i])
			var nearest: float = minf(absf(settled - steady[0]), absf(settled - steady[1]))
			_check("dropped %s with tanks %d%%, it settles where the air holds it" % [start[0], roundi(fuel_share * 100.0)], nearest, 0.0, 6.0)
			_check_true("and its swing dies out (%.2f rad/s at most, %.3f in the last second)" % [largest_spin, late_spin], late_spin < 0.2 and late_spin < largest_spin * 0.2)
			ship.free()
	if trims.size() == 2:
		_report("left alone in air, the lander settles %.0f degrees off engine first with full tanks and %.0f with empty ones (0 would be engine first, 90 broadside)" % [trims[1.0], trims[0.0]])
		_check_true("drained tanks make it less steady: a wider tilt", trims[0.0] > trims[1.0] + 5.0)

	var legs: Node2D = _ship_over(_planet_index, _planet.radius, 14500.0, Vector2.ZERO, 0.0, 0.5)
	legs.body.set_parts_out(1.0)
	var legs_down: PackedFloat64Array = _steady_trims(legs)
	legs.body.set_parts_out(0.0)
	var legs_up: PackedFloat64Array = _steady_trims(legs)
	legs.free()
	if legs_down.size() > 0 and legs_up.size() > 0:
		_report("with half tanks it settles %.0f degrees off engine first with the legs up and %.0f with them down" % [absf(legs_up[0]), absf(legs_down[0])])


# With one side crushed, the lander doesn't settle the same to both sides any more, or doesn't
# settle at all.
func _test_damaged_side() -> void:
	var ship: Node2D = _ship_over(_planet_index, _planet.radius, 14500.0, Vector2.ZERO, 0.0)
	var whole: PackedFloat64Array = _steady_trims(ship)
	ship.body.crush(Vector2.RIGHT, 2.0e9, 7)
	ship.body.split_off()
	ship._update_for_damage()
	var damaged: PackedFloat64Array = _steady_trims(ship)
	var lopsided: bool = damaged.size() != 2
	if damaged.size() == 2 and whole.size() == 2:
		lopsided = absf(absf(damaged[0]) - absf(damaged[1])) > absf(absf(whole[0]) - absf(whole[1])) + 6.0
		_report("whole, the lander settles at %.0f and %.0f degrees; with its right side crushed, at %.0f and %.0f" % [whole[0], whole[1], damaged[0], damaged[1]])
	else:
		_report("with its right side crushed, the lander has %d ways to settle" % damaged.size())
	_check_true("a lander with one side crushed trims crooked or tumbles", lopsided)
	ship.free()


# Held tilted to the air, the lander is pushed sideways as well as slowed.
func _test_lift() -> void:
	var drift: Dictionary = {}
	for tilt: float in [0.0, 35.0]:
		var ship: Node2D = _ship_over(_planet_index, _planet.radius, 9000.0, Vector2(0.0, 900.0), 0.0)
		ship.point_at(deg_to_rad(tilt))
		ship.heading = deg_to_rad(tilt)
		_fly(ship, 6.0)
		drift[tilt] = _through_air(ship).x
		ship.free()
	_check("falling straight, engine first, it barely drifts", drift[0.0], 0.0, 12.0)
	_check_true("tilted 35 degrees, it slides sideways through the air (%.0f units/s after 6 s)" % drift[35.0], absf(drift[35.0]) > 80.0)


# High and slow, the RCS holds the ship broadside to the air. Low and fast, the air out-turns it,
# and the pilot's told once.
func _test_stab_against_the_air() -> void:
	# STAB picks whichever of its directions is nearest: nose up here is straight away from the planet.
	var ship: Node2D = _ship_over(_planet_index, _planet.radius, 13500.0, Vector2(1500.0, 0.0), 0.0)
	ship.stab_enabled = true
	var worst: float = 0.0
	for i in range(60 * 5):
		ship._physics_process(TICK)
		worst = maxf(worst, absf(angle_difference(ship.heading, ship._stab_heading())))
	_check("high and slow, STAB holds broadside to the air", rad_to_deg(worst), 0.0, 1.0)
	_check("with no warning", _warnings.count("AIR OVERPOWERING RCS"), 0.0, 0.0)
	_check_true("burning RCS propellant to do it", ship.rcs_fuel < ship.design.rcs_capacity)
	ship.free()

	ship = _ship_over(_planet_index, _planet.radius, 5000.0, Vector2(2500.0, 0.0), 0.0)
	ship.stab_enabled = true
	worst = 0.0
	for i in range(60 * 5):
		ship._physics_process(TICK)
		worst = maxf(worst, absf(angle_difference(ship.heading, ship._stab_heading())))
	_check_true("low and fast, it can't (pushed %.0f degrees off)" % rad_to_deg(worst), rad_to_deg(worst) > 20.0)
	_check("and the comms says so, once", _warnings.count("AIR OVERPOWERING RCS"), 1.0, 0.0)
	ship.free()

	ship = _ship_over(_planet_index, _planet.radius, 5000.0, Vector2(2500.0, 0.0), 0.0)
	ship.assist_enabled = true
	_fly(ship, 3.0)
	_check_true("ASS loses the same fight, and says so (turned %.0f degrees)" % rad_to_deg(absf(ship.heading)), _warnings.count("AIR OVERPOWERING RCS") == 1 and absf(ship.heading) > 0.35)
	ship.free()

	ship = _ship_over(_planet_index, _planet.radius, 5000.0, Vector2(2500.0, 0.0), 0.0)
	ship.point_at(0.0)
	_fly(ship, 3.0)
	_check_true("and so does drag to point", _warnings.count("AIR OVERPOWERING RCS") == 1)
	ship.free()


# The moon has no air: skimming it fast and spinning, nothing pushes on the ship.
func _test_moon_has_no_air() -> void:
	var ship: Node2D = _ship_over(_moon_index, _moon.radius, 1500.0, Vector2(900.0, 0.0), 0.7)
	ship.angular_velocity = 1.3
	var coasting := ShipState.new()
	coasting.x = ship.state.x
	coasting.y = ship.state.y
	coasting.velocity_x = ship.state.velocity_x
	coasting.velocity_y = ship.state.velocity_y
	coasting.ground_clearance = ship.state.ground_clearance
	var hottest: float = 0.0
	for i in range(60 * 3):
		ship._physics_process(TICK)
		_model.propagate(coasting, TICK)
		hottest = maxf(hottest, ship.heat_share)
	_check("over the moon, the ship coasts exactly as if alone", Vector2(ship.state.x - coasting.x, ship.state.y - coasting.y).length(), 0.0, 0.0)
	_check("its spin doesn't change", ship.angular_velocity, 1.3, 0.0)
	_check("and nothing heats it", hottest, 0.0, 0.0)
	ship.free()


# A ship in the start orbit, slowed in one go until its low point is at this height. Nose against
# the way it's going, so engine first.
func _deorbit(periapsis: float, start_height: float = 30000.0) -> Node2D:
	var ship: Node2D = _ship_over(_planet_index, _planet.radius, start_height, Vector2.ZERO, -PI / 2.0)
	var state: ShipState = ship.state
	var body_velocity: PackedFloat64Array = _model.get_body_velocity(_planet_index, 0.0)
	var speed: float = sqrt(_planet.get_mu() / (_planet.radius + start_height))
	state.velocity_x = body_velocity[0] + speed
	state.velocity_y = body_velocity[1]
	while _model.get_orbit_apsides(state)[0] > periapsis:
		speed -= 1.0
		state.velocity_x = body_velocity[0] + speed
	return ship


# Flies a descent to the ground and says how it went.
func _descend(ship: Node2D, tick: float, hands_off_in_air: bool) -> Dictionary:
	var state: ShipState = ship.state
	var result := {"heat": 0.0, "hull": 0.0, "spin": 0.0, "finite": true, "rcs": 0.0}
	var rcs_at_start: float = ship.rcs_fuel
	var seconds: float = 0.0
	while not state.is_on_surface() and seconds < 1800.0:
		if hands_off_in_air and ship.stab_enabled and _model.get_air_density(state.x, state.y, state.time) > 0.0:
			ship.stab_enabled = false
		ship._physics_process(tick)
		seconds += tick
		# Landing at home refills the tanks, so count what was used on the way down.
		if not state.is_on_surface():
			result["rcs"] = rcs_at_start - ship.rcs_fuel
		result["heat"] = maxf(result["heat"], ship.heat_share)
		result["hull"] = maxf(result["hull"], ship.hull_temperature)
		result["spin"] = maxf(result["spin"], absf(ship.angular_velocity))
		if is_nan(state.x) or is_nan(state.y) or is_nan(ship.heading) or is_nan(ship.angular_velocity):
			result["finite"] = false
			break
	result["landed"] = state.is_on_surface()
	result["speed"] = state.get_touchdown_speed()
	result["seconds"] = seconds
	result["along"] = _model.get_ground_column(state.x, state.y, state.time) * WORLD_PIXEL
	return result


func _test_descents() -> void:
	# Held engine first by STAB all the way down, with the tanks nearly empty, as a lander arrives.
	var ship: Node2D = _deorbit(0.0)
	ship.fuel = ship.body.fuel_capacity * 0.1
	ship._update_performance()
	ship.stab_enabled = true
	var held: Dictionary = _descend(ship, TICK, false)
	ship.free()
	_check_true("a descent from the start orbit reaches the ground", held["landed"] and held["finite"])
	_report("from the start orbit with tanks at 10%%, held engine first by STAB: touchdown at %.0f units/s (%s), peak heat %.2f, %.0f kg of RCS propellant. The old one-box drag gave 287 on the same flight." % [held["speed"], Units.speed_text(held["speed"]), held["heat"], held["rcs"]])
	_check_true("at roughly the old speed, still needing a landing burn", held["speed"] > 200.0 and held["speed"] < 450.0)
	_check_true("a gentle return from low orbit heats it gently (%.2f)" % held["heat"], held["heat"] > 0.1 and held["heat"] < 0.5)

	# Hands off from the top of the air: STAB lets go there, and ASS, as the ship starts, does what
	# it can. Flown at normal speed and at ten times warp.
	var flights: Array[Dictionary] = []
	for tick: float in [TICK, WARP_TICK]:
		ship = _deorbit(0.0)
		ship.fuel = ship.body.fuel_capacity * 0.1
		ship._update_performance()
		ship.assist_enabled = true
		ship.stab_enabled = true
		flights.append(_descend(ship, tick, true))
		ship.free()
	_check_true("hands off, it reaches the ground at normal speed and at ten times warp", flights[0]["landed"] and flights[1]["landed"] and flights[0]["finite"] and flights[1]["finite"])
	_report("the same, hands off from the top of the air with ASS on: touchdown at %.0f units/s (%s), peak heat %.2f, %.0f kg of RCS propellant, fastest spin %.2f rad/s" % [flights[0]["speed"], Units.speed_text(flights[0]["speed"]), flights[0]["heat"], flights[0]["rcs"], flights[0]["spin"]])
	var apart: float = absf(flights[1]["along"] - flights[0]["along"])
	_report("at ten times warp it comes down %.0f units (%.1f m) from there, at %.0f units/s" % [apart, Units.meters(apart), flights[1]["speed"]])
	_check_true("ten times warp lands close by", apart < 600.0)
	_check("at close to the same speed", flights[1]["speed"], flights[0]["speed"], 25.0)
	_check_true("with no wild spin", flights[1]["spin"] < 12.0)

	# Steep and fast, from high up.
	ship = _deorbit(-100000.0, 150000.0)
	ship.stab_enabled = true
	var steep: Dictionary = _descend(ship, TICK, false)
	ship.free()
	_report("dropped steeply from 150,000 units up: peak heat %.2f, hull %.2f, touchdown at %.0f units/s" % [steep["heat"], steep["hull"], steep["speed"]])
	_check_true("a steep return from high up passes the top of the heat scale", steep["heat"] > 1.0 and steep["finite"])
