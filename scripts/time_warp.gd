# time_warp.gd: speeds the whole flight up or slows it down by scaling time, in steps of 0.5, 1, 2, 5,
# and 10, which work any time, burning included, and 50 and 100, which are only for coasting. Those
# drop back to 10 by themselves when the coast ends: the engine on, the RCS used, near the station or
# the ground, in air, landed or docked, the pilot out, or a new body's gravity taking over.
# Everything simulated speeds up; the UI and camera keep to real time with TimeWarp.real().
# From DESIGN.md, "Time warp".
class_name TimeWarp
extends Node

## Emitted with the new speed whenever it changes.
signal warp_changed(factor: float)
## Emitted with what to say when the warp drops or won't go up.
signal message_raised(text: String)

const STEPS: Array[float] = [0.5, 1.0, 2.0, 5.0, 10.0, 50.0, 100.0]
## The fastest step that works any time. Past it, the ship is on rails, only coasting.
const MOST_ANY_TIME: float = 10.0

## Below this height over the ground, coasting warp drops back, in world units (500 m).
@export var near_ground_height: float = 10000.0

var factor: float = 1.0
var _gravity_model: GravityModel
var _ship: Node2D
var _pilot: Pilot
var _dominant: int = -1


## A frame's time in real seconds, for whatever should keep to real time while warping.
static func real(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.001)


## Whether the ship's coasting on rails: steering and RCS don't run at these speeds.
static func on_rails() -> bool:
	return Engine.time_scale > MOST_ANY_TIME


func _ready() -> void:
	# A restart reloads the scene, and the scale belongs to the whole engine, so start from 1.
	Engine.time_scale = 1.0
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func start(gravity_model: GravityModel, ship: Node2D, pilot: Pilot) -> void:
	_gravity_model = gravity_model
	_ship = ship
	_pilot = pilot


## One step faster, unless that's past 10 and the ship isn't coasting.
func faster() -> void:
	var next: float = _step_from(factor, 1)
	if next > MOST_ANY_TIME:
		var why: String = _why_not_coasting()
		if why != "":
			message_raised.emit("NO WARP PAST 10×: %s" % why)
			return
	_set_factor(next)


func slower() -> void:
	_set_factor(_step_from(factor, -1))


func reset() -> void:
	_set_factor(1.0)


func _physics_process(_delta: float) -> void:
	if _gravity_model == null:
		return
	if Input.is_action_just_pressed("warp_faster"):
		faster()
	if Input.is_action_just_pressed("warp_slower"):
		slower()
	if Input.is_action_just_pressed("warp_reset"):
		reset()
	var state: ShipState = _ship.state
	var dominant: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var changed_body: bool = _dominant >= 0 and dominant != _dominant
	_dominant = dominant
	if factor > MOST_ANY_TIME:
		var why: String = "NEW GRAVITY" if changed_body else _why_not_coasting()
		if why != "":
			_set_factor(MOST_ANY_TIME)
			message_raised.emit("WARP 10×: %s" % why)


# Why the ship isn't just coasting, or nothing if it is.
func _why_not_coasting() -> String:
	var state: ShipState = _ship.state
	if _pilot.mode != Pilot.ABOARD:
		return "PILOT OUT"
	if _ship.docked:
		return "DOCKED"
	if state.is_on_surface():
		return "LANDED"
	if _ship.engine_on:
		return "ENGINE ON"
	for action: StringName in [&"turn_left", &"turn_right", &"translate_forward", &"translate_back", &"translate_left", &"translate_right"]:
		if Input.is_action_pressed(action):
			return "RCS"
	if _ship.is_pointing():
		return "RCS"
	if _ship.near_station():
		return "NEAR STATION"
	if _gravity_model.get_air_density(state.x, state.y, state.time) > 0.0:
		return "IN AIR"
	if _gravity_model.get_altitude(state.x, state.y, state.time) < near_ground_height:
		return "NEAR GROUND"
	return ""


func _step_from(from: float, way: int) -> float:
	var index: int = STEPS.find(from)
	if index < 0:
		index = STEPS.find(1.0)
	return STEPS[clampi(index + way, 0, STEPS.size() - 1)]


func _set_factor(value: float) -> void:
	if value == factor:
		return
	factor = value
	Engine.time_scale = value
	warp_changed.emit(value)
