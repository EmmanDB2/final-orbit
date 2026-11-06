# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship) and "Physics"
# (64-bit math, floating origin).
#
# The ship's real position and velocity live in a 64-bit ShipState, because Vector2
# is only 32-bit, and gravity moves it through the GravityModel interface. The node
# only shows the result: it's placed on screen from the current view. Closer than the
# Orbit view it's the sprite, at true size down to a minimum, with no smoothing. At the
# Orbit view and farther it's the icon, and very far out it's a dot.
#
# Three things can steer the nose, strongest first: the turn keys, drag to point, and
# STAB, which holds whichever of four directions was closest when it took over (along
# the path or toward the body, nose first or thruster first). All of them use the RCS,
# at turn_acceleration. Thrust is the throttle setting while BURN is held.
#
# The RCS can also translate, moving the ship in any of four directions without turning
# it, for docking and precise landings. ASS doesn't cancel this, and it's too weak to lift
# off from anything.
#
# Fuel has mass. Burning it makes the ship lighter and quicker, and the main engine and
# RCS both stop when it runs out. Landing on the planet refills it until stations exist.
#
# On the ground the ship settles upright and the turn keys do nothing, so thrust always
# lifts it straight off. Tier 0 has no damage, so a touchdown only reports how it went.
#
# Two flight modes, from "Flight modes" in DESIGN.md. RAW is just your inputs. ASS
# (Attitude Stabilization System) also fires the RCS against the spin when you let
# go of the turn keys. ASS never touches velocity, since that would break orbits.
extends Node2D

## Emitted every physics tick with the ship's real position in the world.
signal world_position_changed(x: float, y: float)
## Emitted when the flight mode changes: true for ASS, false for RAW.
signal assist_changed(enabled: bool)
## Emitted when the ship's path has changed, from a burn or from touching a surface.
signal orbit_changed
## Emitted when STAB is switched on or off.
signal stab_changed(enabled: bool)
## Emitted when the ship reaches the ground, with its speed relative to the ground and
## whether its nose was pointing away from the surface.
signal touched_down(speed: float, upright: bool)
## Emitted when the ship leaves the ground.
signal lifted_off
## Emitted several times a second with what the instruments show: altitude, speed,
## periapsis, apoapsis, time, heading, prograde, and spin.
signal flight_data_changed(data: Dictionary)

## What this ship is built from. Thrust and turning come from its engines and its mass.
@export var design: ShipDesign
## How many times per second the engine flame changes frame.
@export var flame_fps: float = 15.0
## True starts the ship in ASS, false in RAW.
@export var assist_enabled: bool = true
## Below this zoom the ship is drawn as a dot.
@export var dot_max_zoom: float = 0.0001
## The icon shows at this zoom and farther, and the sprite at anything closer.
@export var icon_max_zoom: float = 1.0 / 800.0
## The smallest the sprite gets, as a share of its full size. About the icon's height.
@export var sprite_min_scale: float = 0.08
## Height of the ship's center when it's resting on its engine bell, in world units.
@export var ground_clearance: float = 105.0
## How fast the ship straightens up on the ground, in radians per second.
@export var settle_speed: float = 2.0
## Touching down within this angle of straight up counts as upright, in radians.
@export var upright_tolerance: float = 0.5
## How many physics ticks between telemetry updates.
@export var telemetry_interval_ticks: int = 3

## Direction of the nose in radians. 0 points up the screen; positive turns clockwise.
var heading: float = 0.0
## The ship's mass, center of mass, and spin resistance, measured from its pixels.
var body: ShipBody
## Fuel aboard, in kilograms.
var fuel: float = 0.0
## Main engine acceleration right now, in world units per second squared.
var thrust_acceleration: float = 0.0
## How quickly the RCS changes the spin right now, in radians per second squared.
var turn_acceleration: float = 0.0
## RCS translation acceleration right now, in world units per second squared.
var translate_acceleration: float = 0.0
## How fast the nose is turning, in radians per second.
var angular_velocity: float = 0.0
## How much of the engine's thrust BURN uses, from 0 to 1.
var throttle: float = 1.0
var stab_enabled: bool = false
## Where the ship really is and how it's moving.
var state: ShipState

var _gravity_model: GravityModel
var _thrusting: bool = false
var _was_on_surface: bool = false
var _show_sprite: bool = true
var _sprite_scale: float = 1.0
var _flame_position: Vector2 = Vector2.ZERO
var _show_dot: bool = false
var _point_active: bool = false
var _point_heading: float = 0.0
var _stab_needs_pick: bool = true
var _stab_direction: int = 0
var _flame_time: float = 0.0
var _spin_firing: float = 0.0
var _translate_forward: float = 0.0
var _translate_right: float = 0.0

@onready var _flame: Sprite2D = $Flame
@onready var _puffs: RcsPuffs = $RcsPuffs
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	_flame_position = _flame.position
	body = ShipBody.measure(design)
	fuel = body.fuel_capacity
	_update_performance()
	_puffs.set_nozzles(design)
	# Nothing flies until start_flight hands over gravity and a starting state.
	set_physics_process(false)
	assist_changed.emit(assist_enabled)


## Starts the ship flying.
func start_flight(gravity_model: GravityModel, start_state: ShipState, start_heading: float) -> void:
	_gravity_model = gravity_model
	state = start_state
	state.ground_clearance = ground_clearance
	heading = start_heading
	rotation = heading
	set_physics_process(true)


# Godot calls this at a fixed 60 ticks per second, so the flight is the same
# on any screen. delta is the length of one tick in seconds.
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_assist"):
		assist_enabled = not assist_enabled
		assist_changed.emit(assist_enabled)
	if Input.is_action_just_pressed("toggle_stab"):
		stab_enabled = not stab_enabled
		_stab_needs_pick = true
		stab_changed.emit(stab_enabled)

	_spin_firing = 0.0
	if state.is_on_surface():
		angular_velocity = 0.0
		heading = rotate_toward(heading, _local_up_heading(), settle_speed * delta)
	else:
		var spin_before: float = angular_velocity
		var turn_input: float = Input.get_axis("turn_left", "turn_right")
		if fuel <= 0.0:
			pass
		elif turn_input != 0.0:
			angular_velocity += turn_input * turn_acceleration * delta
			_stab_needs_pick = true
		elif _point_active:
			_steer_toward(_point_heading, delta)
			_stab_needs_pick = true
		elif stab_enabled:
			_steer_toward(_stab_heading(), delta)
		elif assist_enabled:
			# Same thrusters as manual turning, so the same strength. move_toward stops
			# exactly at zero instead of overshooting into a tiny spin the other way.
			angular_velocity = move_toward(angular_velocity, 0.0, turn_acceleration * delta)
		var firing: float = absf(angular_velocity - spin_before) / (turn_acceleration * delta)
		_burn_fuel(design.rcs_fuel_rate * firing * delta)
		_spin_firing = signf(angular_velocity - spin_before) * firing
		heading += angular_velocity * delta
	rotation = heading

	_thrusting = Input.is_action_pressed("thrust") and throttle > 0.0 and fuel > 0.0
	if _thrusting:
		state.velocity_x += sin(heading) * thrust_acceleration * throttle * delta
		state.velocity_y -= cos(heading) * thrust_acceleration * throttle * delta
		_burn_fuel(design.engine_force * throttle / design.exhaust_velocity * delta)
	var translate_forward: float = Input.get_axis("translate_back", "translate_forward")
	var translate_right: float = Input.get_axis("translate_left", "translate_right")
	var translating: bool = fuel > 0.0 and (translate_forward != 0.0 or translate_right != 0.0)
	_translate_forward = translate_forward if translating else 0.0
	_translate_right = translate_right if translating else 0.0
	if translating:
		var along: float = translate_forward * translate_acceleration * delta
		var across: float = translate_right * translate_acceleration * delta
		state.velocity_x += sin(heading) * along + cos(heading) * across
		state.velocity_y += -cos(heading) * along + sin(heading) * across
		_burn_fuel(design.rcs_fuel_rate * (absf(translate_forward) + absf(translate_right)) * delta)

	_gravity_model.propagate(state, delta)

	var on_surface: bool = state.is_on_surface()
	if _thrusting or translating or on_surface != _was_on_surface:
		orbit_changed.emit()
	if on_surface and not _was_on_surface:
		var tilt: float = absf(angle_difference(heading, _local_up_heading()))
		touched_down.emit(state.get_touchdown_speed(), tilt <= upright_tolerance)
		if _gravity_model.get_dominant_body(state.x, state.y, state.time) == 0:
			fuel = body.fuel_capacity
			_update_performance()
	elif _was_on_surface and not on_surface:
		lifted_off.emit()
	_was_on_surface = on_surface

	world_position_changed.emit(state.x, state.y)

	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report_telemetry()


# Runs once per rendered frame. Cosmetic only, so it doesn't touch the flight.
func _process(delta: float) -> void:
	_flame_time += delta
	_flame.frame = floori(_flame_time * flame_fps) % _flame.hframes
	_flame.visible = _thrusting and _show_sprite
	# Small corrections while holding steady don't show, so the nozzles don't flicker.
	var turning_clockwise: bool = _spin_firing > 0.2
	var turning_back: bool = _spin_firing < -0.2
	_puffs.visible = _show_sprite
	_puffs.set_firing(
			turning_clockwise or _translate_right > 0.0,
			turning_back or _translate_right < 0.0,
			_translate_forward > 0.0,
			_translate_forward < 0.0,
			_sprite_scale)
	_icon.frame = 1 if _thrusting else 0


func _burn_fuel(amount: float) -> void:
	if amount > 0.0:
		fuel = maxf(fuel - amount, 0.0)
		_update_performance()


func _update_performance() -> void:
	var now: Dictionary = body.with_fuel(fuel)
	thrust_acceleration = design.engine_force / now["mass"]
	turn_acceleration = design.rcs_torque / now["spin_resistance"]
	translate_acceleration = design.rcs_translate_force / now["mass"]


## How much more speed the fuel aboard can give, from the rocket equation.
func delta_v() -> float:
	return design.exhaust_velocity * log((body.mass + fuel) / body.mass)


## Starts or updates drag to point, turning the nose toward this heading.
func point_at(target_heading: float) -> void:
	_point_active = true
	_point_heading = target_heading


## Ends drag to point. ASS, STAB, or nothing takes over, depending on the flight mode.
func stop_pointing() -> void:
	_point_active = false


## How far out the turn guide's ring sits around the ship, in screen pixels.
func guide_radius() -> float:
	return maxf(125.0 * _sprite_scale, 16.0) if _show_sprite else 16.0


func _on_throttle_changed(value: float) -> void:
	throttle = value


# Fires the RCS to turn toward a heading and arrive with no spin left.
func _steer_toward(target_heading: float, delta: float) -> void:
	var error: float = angle_difference(heading, target_heading)
	var braking_limit: float = sqrt(2.0 * turn_acceleration * absf(error))
	var desired: float = signf(error) * minf(braking_limit, absf(error) * 4.0)
	angular_velocity = move_toward(angular_velocity, desired, turn_acceleration * delta)


# The heading of each direction STAB can hold, in the order of _stab_direction.
func _stab_directions() -> PackedFloat64Array:
	var body: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var body_velocity: PackedFloat64Array = _gravity_model.get_body_velocity(body, state.time)
	var along: float = atan2(state.velocity_x - body_velocity[0], body_velocity[1] - state.velocity_y)
	var away: float = _local_up_heading()
	return PackedFloat64Array([along, along + PI, away + PI, away])


func _stab_heading() -> float:
	var directions: PackedFloat64Array = _stab_directions()
	if _stab_needs_pick:
		_stab_needs_pick = false
		var closest: float = INF
		for i in range(directions.size()):
			var gap: float = absf(angle_difference(heading, directions[i]))
			if gap < closest:
				closest = gap
				_stab_direction = i
	return directions[_stab_direction]


# The heading that points the nose straight away from the body below.
func _local_up_heading() -> float:
	var body: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var body_position: PackedFloat64Array = _gravity_model.get_body_position(body, state.time)
	return atan2(state.x - body_position[0], body_position[1] - state.y)


func _report_telemetry() -> void:
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var relative_x: float = state.velocity_x - ground[0]
	var relative_y: float = state.velocity_y - ground[1]
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	flight_data_changed.emit({
		"altitude": _gravity_model.get_altitude(state.x, state.y, state.time) - ground_clearance,
		"speed": sqrt(relative_x * relative_x + relative_y * relative_y),
		"periapsis": apsides[0],
		"apoapsis": apsides[1],
		"time": state.time,
		"heading": heading,
		"prograde": atan2(relative_x, -relative_y),
		"spin": angular_velocity,
		"fuel_share": fuel / body.fuel_capacity,
		"delta_v": delta_v(),
	})


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	# Whole pixels only, so the icon doesn't shimmer as it crawls across the grid.
	position = Vector2(
			(state.x - center_x) * pixels_per_unit,
			(state.y - center_y) * pixels_per_unit).round()
	_show_sprite = pixels_per_unit > icon_max_zoom
	_sprite_scale = clampf(pixels_per_unit, sprite_min_scale, 1.0)
	_sprite.scale = Vector2.ONE * _sprite_scale
	_flame.scale = Vector2.ONE * _sprite_scale
	_flame.position = _flame_position * _sprite_scale
	var show_dot: bool = pixels_per_unit < dot_max_zoom
	if show_dot != _show_dot:
		_show_dot = show_dot
		queue_redraw()
	_sprite.visible = _show_sprite
	_icon.visible = not _show_sprite and not show_dot


func _draw() -> void:
	if _show_dot:
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), UiStyle.palette().hull_darkest)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), UiStyle.palette().hull_lightest)
