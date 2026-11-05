# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship) and "Physics"
# (64-bit math, floating origin).
#
# The ship's real position and velocity are separate 64-bit floats, because
# Vector2 is only 32-bit. The node itself stays at the origin and the world is
# drawn around it. Empty space only for now: gravity arrives with GravityModel.
#
# Two flight modes, from "Flight modes" in DESIGN.md. RAW is just your inputs. SAS
# (Ship Assist Systems) also fires the RCS against the spin when you let go of the
# turn keys. SAS never touches velocity, since that would break orbits.
extends Node2D

## Emitted every physics tick with the ship's real position in the world.
signal world_position_changed(x: float, y: float)
## Emitted when the flight mode changes: true for SAS, false for RAW.
signal assist_changed(enabled: bool)

## How quickly A and D change the ship's spin, in radians per second squared.
## @export makes this value editable in the Inspector panel.
@export var turn_acceleration: float = 1.5
## Main engine acceleration, in pixels per second squared.
@export var thrust_acceleration: float = 300.0
## How many times per second the engine flame changes frame.
@export var flame_fps: float = 15.0
## True starts the ship in SAS, false in RAW.
@export var assist_enabled: bool = true

## Direction of the nose in radians. 0 points up the screen; positive turns clockwise.
var heading: float = 0.0
## How fast the nose is turning, in radians per second.
var angular_velocity: float = 0.0
var world_x: float = 0.0
var world_y: float = 0.0
var velocity_x: float = 0.0
var velocity_y: float = 0.0

var _flame_time: float = 0.0

@onready var _flame: Sprite2D = $Flame


func _ready() -> void:
	assist_changed.emit(assist_enabled)


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

	var thrusting: bool = Input.is_action_pressed("thrust")
	if thrusting:
		velocity_x += sin(heading) * thrust_acceleration * delta
		velocity_y -= cos(heading) * thrust_acceleration * delta
	_flame.visible = thrusting

	world_x += velocity_x * delta
	world_y += velocity_y * delta
	world_position_changed.emit(world_x, world_y)


# Runs once per rendered frame. Cosmetic only, so it doesn't touch the flight.
func _process(delta: float) -> void:
	_flame_time += delta
	_flame.frame = floori(_flame_time * flame_fps) % _flame.hframes
