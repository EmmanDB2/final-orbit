# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship) and "Physics"
# (64-bit math, floating origin).
#
# The ship's real position and velocity are separate 64-bit floats, because
# Vector2 is only 32-bit. The node itself stays at the origin and the world is
# drawn around it. Empty space only for now: gravity arrives with GravityModel.
extends Node2D

## Emitted every physics tick with the ship's real position in the world.
signal world_position_changed(x: float, y: float)

## How fast the ship turns, in radians per second.
## @export makes this value editable in the Inspector panel.
@export var turn_speed: float = 2.0
## Main engine acceleration, in pixels per second squared.
@export var thrust_acceleration: float = 80.0
## How many times per second the engine flame changes frame.
@export var flame_fps: float = 15.0

## Direction of the nose in radians. 0 points up the screen; positive turns clockwise.
var heading: float = 0.0
var world_x: float = 0.0
var world_y: float = 0.0
var velocity_x: float = 0.0
var velocity_y: float = 0.0

var _flame_time: float = 0.0

@onready var _flame: Sprite2D = $Flame


# Godot calls this at a fixed 60 ticks per second, so the flight is the same
# on any screen. delta is the length of one tick in seconds.
func _physics_process(delta: float) -> void:
	heading += Input.get_axis("turn_left", "turn_right") * turn_speed * delta
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
