# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship) and "Physics"
# (64-bit math, floating origin).
#
# The ship's real position and velocity live in a 64-bit ShipState, because Vector2
# is only 32-bit, and gravity moves it through the GravityModel interface. The node
# only shows the result: it's placed on screen from the current view, close up as the
# full sprite and far out as an icon.
#
# Two flight modes, from "Flight modes" in DESIGN.md. RAW is just your inputs. ASS
# (Attitude Stabilization System) also fires the RCS against the spin when you let
# go of the turn keys. ASS never touches velocity, since that would break orbits.
extends Node2D

## Emitted every physics tick with the ship's real position in the world.
signal world_position_changed(x: float, y: float)
## Emitted when the flight mode changes: true for ASS, false for RAW.
signal assist_changed(enabled: bool)

## How quickly A and D change the ship's spin, in radians per second squared.
## @export makes this value editable in the Inspector panel.
@export var turn_acceleration: float = 1.5
## Main engine acceleration, in pixels per second squared.
@export var thrust_acceleration: float = 300.0
## How many times per second the engine flame changes frame.
@export var flame_fps: float = 15.0
## True starts the ship in ASS, false in RAW.
@export var assist_enabled: bool = true
## The full sprite shows at this zoom and closer, and the icon at anything farther.
@export var full_sprite_min_zoom: float = 0.5

## Direction of the nose in radians. 0 points up the screen; positive turns clockwise.
var heading: float = 0.0
## How fast the nose is turning, in radians per second.
var angular_velocity: float = 0.0
## Where the ship really is and how it's moving.
var state: ShipState

var _gravity_model: GravityModel
var _thrusting: bool = false
var _show_full_sprite: bool = true
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
	heading = start_heading
	rotation = heading
	set_physics_process(true)


# Godot calls this at a fixed 60 ticks per second, so the flight is the same
# on any screen. delta is the length of one tick in seconds.
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_assist"):
		assist_enabled = not assist_enabled
		assist_changed.emit(assist_enabled)

	var turn_input: float = Input.get_axis("turn_left", "turn_right")
	if turn_input != 0.0:
		angular_velocity += turn_input * turn_acceleration * delta
	elif assist_enabled:
		# Same thrusters as manual turning, so the same strength. move_toward stops
		# exactly at zero instead of overshooting into a tiny spin the other way.
		angular_velocity = move_toward(angular_velocity, 0.0, turn_acceleration * delta)
	heading += angular_velocity * delta
	rotation = heading

	_thrusting = Input.is_action_pressed("thrust")
	if _thrusting:
		state.velocity_x += sin(heading) * thrust_acceleration * delta
		state.velocity_y -= cos(heading) * thrust_acceleration * delta
	_gravity_model.propagate(state, delta)

	world_position_changed.emit(state.x, state.y)


# Runs once per rendered frame. Cosmetic only, so it doesn't touch the flight.
func _process(delta: float) -> void:
	_flame_time += delta
	_flame.frame = floori(_flame_time * flame_fps) % _flame.hframes
	_flame.visible = _thrusting and _show_full_sprite
	_icon.frame = 1 if _thrusting else 0


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	# Whole pixels only, so the icon doesn't shimmer as it crawls across the grid.
	position = Vector2(
			(state.x - center_x) * pixels_per_unit,
			(state.y - center_y) * pixels_per_unit).round()
	_show_full_sprite = pixels_per_unit >= full_sprite_min_zoom
	_sprite.visible = _show_full_sprite
	_icon.visible = not _show_full_sprite
