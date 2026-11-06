# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship) and "Physics"
# (64-bit math, floating origin).
#
# The ship's real position and velocity live in a 64-bit ShipState, because Vector2
# is only 32-bit, and gravity moves it through the GravityModel interface. The node
# only shows the result: it's placed on screen from the current view, close up as the
# full sprite and far out as an icon.
#
# Three things can steer the nose, strongest first: the turn keys, drag to point, and
# STAB, which holds whichever of four directions was closest when it took over (along
# the path or toward the body, nose first or thruster first). All of them use the RCS,
# at turn_acceleration. Thrust is the throttle setting while BURN is held.
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

## How quickly A and D change the ship's spin, in radians per second squared.
## @export makes this value editable in the Inspector panel.
@export var turn_acceleration: float = 1.5
## Main engine acceleration, in pixels per second squared.
@export var thrust_acceleration: float = 300.0
## How many times per second the engine flame changes frame.
@export var flame_fps: float = 15.0
## True starts the ship in ASS, false in RAW.
@export var assist_enabled: bool = true
## Below this zoom the ship is drawn as a dot.
@export var dot_max_zoom: float = 0.0001
## The full sprite shows at this zoom and closer, and the icon at anything farther.
@export var full_sprite_min_zoom: float = 0.5
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
var _show_full_sprite: bool = true
var _show_dot: bool = false
var _point_active: bool = false
var _point_heading: float = 0.0
var _stab_needs_pick: bool = true
var _stab_direction: int = 0
var _flame_time: float = 0.0

@onready var _flame: Sprite2D = $Flame
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
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

	if state.is_on_surface():
		angular_velocity = 0.0
		heading = rotate_toward(heading, _local_up_heading(), settle_speed * delta)
	else:
		var turn_input: float = Input.get_axis("turn_left", "turn_right")
		if turn_input != 0.0:
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
		heading += angular_velocity * delta
	rotation = heading

	_thrusting = Input.is_action_pressed("thrust") and throttle > 0.0
	if _thrusting:
		state.velocity_x += sin(heading) * thrust_acceleration * throttle * delta
		state.velocity_y -= cos(heading) * thrust_acceleration * throttle * delta
	_gravity_model.propagate(state, delta)

	var on_surface: bool = state.is_on_surface()
	if _thrusting or on_surface != _was_on_surface:
		orbit_changed.emit()
	if on_surface and not _was_on_surface:
		var tilt: float = absf(angle_difference(heading, _local_up_heading()))
		touched_down.emit(state.get_touchdown_speed(), tilt <= upright_tolerance)
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
	_flame.visible = _thrusting and _show_full_sprite
	_icon.frame = 1 if _thrusting else 0


## Starts or updates drag to point, turning the nose toward this heading.
func point_at(target_heading: float) -> void:
	_point_active = true
	_point_heading = target_heading


## Ends drag to point. ASS, STAB, or nothing takes over, depending on the flight mode.
func stop_pointing() -> void:
	_point_active = false


## How far out the turn guide's ring sits around the ship, in screen pixels.
func guide_radius() -> float:
	return 125.0 if _show_full_sprite else 16.0


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
	})


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	# Whole pixels only, so the icon doesn't shimmer as it crawls across the grid.
	position = Vector2(
			(state.x - center_x) * pixels_per_unit,
			(state.y - center_y) * pixels_per_unit).round()
	_show_full_sprite = pixels_per_unit >= full_sprite_min_zoom
	var show_dot: bool = pixels_per_unit < dot_max_zoom
	if show_dot != _show_dot:
		_show_dot = show_dot
		queue_redraw()
	_sprite.visible = _show_full_sprite
	_icon.visible = not _show_full_sprite and not show_dot


func _draw() -> void:
	if _show_dot:
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), UiStyle.palette().hull_darkest)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), UiStyle.palette().hull_lightest)
