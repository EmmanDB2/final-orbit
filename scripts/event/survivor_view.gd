# survivor_view.gd: the astronaut from a distress beacon, drawn like the pilot. Adrift, they turn over
# slowly and wave for help. Held, they go where the pilot goes, holding out a hand on EVA and keeping
# step on the ground. Aboard, they're out of sight. Far out, the event marker stands in for them. From
# DESIGN.md, "Mid-flight events" (distress beacons).
class_name SurvivorView
extends Node2D

## They're drawn at this zoom and closer, in screen pixels per world unit, like the pilot.
const SHOW_ZOOM: float = 1.0 / 32.0
## How slowly someone adrift turns over, in radians per second.
const TUMBLE: float = 0.12
## How far from the middle of the view they can be and still be drawn, in screen pixels.
const SHOW_REACH: float = 1600.0

var _event: FlightEvent
var _pilot: Pilot
var _figure: AstronautView
var _facing: float = 0.0
var _roll: float = 0.0
var _center := Vector2.ZERO


func setup(event: FlightEvent, pilot: Pilot) -> void:
	_event = event
	_pilot = pilot
	# Each one starts turned their own way.
	_facing = float(event.id) * 1.7
	_figure = AstronautView.new()
	add_child(_figure)


func place(center_x: float, center_y: float, pixels_per_unit: float, roll: float) -> void:
	_roll = roll
	_center = Vector2(center_x, center_y)
	position = Vector2((_event.state.x - center_x) * pixels_per_unit, (_event.state.y - center_y) * pixels_per_unit)
	visible = pixels_per_unit >= SHOW_ZOOM and _event.rescue != "aboard" and position.length() <= SHOW_REACH
	_figure.scale = Vector2.ONE * minf(pixels_per_unit, 1.0)


func _process(delta: float) -> void:
	if not visible:
		return
	rotation = _roll
	_figure.screen_roll = _roll
	# Lit by the star, like the pilot, and dark in a world's shadow.
	var state: ShipState = _event.state
	_figure.light_from = (-Vector2(state.x, state.y).normalized()).rotated(-_roll)
	_figure.sun_level = Sunlight.at(_pilot._gravity_model, state.x, state.y, state.time)
	_figure.turning = 0.0
	if _event.rescue == "held" and _pilot._figure != null:
		_keep_with_pilot()
		return
	_figure.holding = 0
	_figure.push = Vector2.ZERO
	_figure.motion = &"wave"
	if _event.state.is_on_surface():
		# Standing on a world, from the side, still waving.
		_figure.look = AstronautView.Look.SIDE
		_figure.feet_below = _pilot.data.stand_height
		_figure.body_angle = wrapf(_up_heading() - _roll, -PI, PI)
		_figure.speed_share = 0.0
		return
	_facing = wrapf(_facing + TUMBLE * delta, -PI, PI)
	_figure.look = AstronautView.Look.EVA
	_figure.feet_below = 0.0
	_figure.body_angle = rotate_toward(_figure.body_angle, wrapf(_facing - _roll, -PI, PI), 10.0 * delta)


# Held: the same way up as the pilot, drifting or walking with them.
func _keep_with_pilot() -> void:
	var with: AstronautView = _pilot._figure
	_facing = _pilot.facing
	_figure.look = with.look
	_figure.body_angle = with.body_angle
	_figure.feet_below = with.feet_below
	if _pilot.mode == Pilot.EVA:
		# Their left hand in the pilot's right, leaning along with the push.
		_figure.holding = -1
		_figure.push = with.push
		_figure.motion = &"float"
		return
	_figure.holding = 0
	_figure.push = Vector2.ZERO
	_figure.facing_right = with.facing_right
	_figure.speed_share = with.speed_share
	_figure.rise_share = with.rise_share
	_figure.motion = &"air" if with.motion == &"jet" else with.motion


# Straight up from the world they're on, as a heading.
func _up_heading() -> float:
	var state: ShipState = _event.state
	var gravity: GravityModel = _pilot._gravity_model
	var world: int = gravity.get_dominant_body(state.x, state.y, state.time)
	var center: PackedFloat64Array = gravity.get_body_position(world, state.time)
	return atan2(state.x - center[0], center[1] - state.y)
