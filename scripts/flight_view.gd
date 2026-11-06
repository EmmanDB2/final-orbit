# flight_view.gd: decides where the camera looks and how far out it is.
# From DESIGN.md, "Camera, zoom, and landing" and "UI".
#
# Zoom moves smoothly and has no outer limit. The stops are where the buttons and keys
# land, and how far out you are decides what stays centered: the ship up close, the body
# you're orbiting further out, and the middle of the system beyond that.
#
# Zooming changes what gets drawn, never the pixel size, so the Camera2D's own zoom stays
# at 1 and its position stays at 0,0. Instead, this signals the current view and each
# system places itself on screen from that.
extends Camera2D

## Emitted every physics tick with the world point at the middle of the screen, and
## the zoom in screen pixels per world unit.
signal view_changed(center_x: float, center_y: float, pixels_per_unit: float)

## What stays in the middle of the screen.
enum Focus {
	SHIP,
	DOMINANT_BODY,
	SYSTEM_CENTER,
}

## Where keys land, closest to farthest, in screen pixels per world unit.
@export var zoom_stops: PackedFloat64Array = PackedFloat64Array([1.0, 1.0 / 8.0, 1.0 / 128.0, 1.0 / 800.0, 1.0 / 2400.0])
## How far each key press moves past the last stop.
@export var zoom_out_step: float = 3.0
## The zoom the ORBIT button goes to, and the one the game starts at.
@export var orbit_zoom: float = 1.0 / 800.0
## The zoom the SYS button goes to.
@export var system_zoom: float = 1.0 / 2400.0
## The ship stays centered at this zoom and closer.
@export var ship_focus_zoom: float = 1.0 / 200.0
## The orbited body stays centered at this zoom and closer, down from ship_focus_zoom.
@export var body_focus_zoom: float = 1.0 / 1600.0
## How quickly zoom closes in on its target. Higher is snappier.
@export var zoom_speed: float = 10.0
## How long the view takes to slide to a new center, in seconds.
@export var focus_blend_seconds: float = 0.5
## The screen height the ORBIT and SYS zooms are set for, in game pixels. On a shorter
## screen they zoom out to match, so the same orbits still fit.
@export var design_height: float = 616.0

var _gravity_model: GravityModel
var _state: ShipState
var _far_fit: float = 1.0
var _zoom: float = 1.0 / 800.0
var _target_zoom: float = 1.0 / 800.0
var _focus: Focus = Focus.DOMINANT_BODY
var _previous_focus: Focus = Focus.DOMINANT_BODY
var _focus_blend: float = 1.0


## Starts following a flight.
func start_view(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	_zoom = orbit_zoom
	_target_zoom = orbit_zoom


## Jumps straight to a zoom, with no easing.
func set_zoom_now(zoom: float) -> void:
	_zoom = zoom
	_target_zoom = zoom
	_focus = _focus_for(zoom)
	_focus_blend = 1.0


## The zoom the view is heading toward.
func get_target_zoom() -> float:
	return _target_zoom


func _on_screen_fitted(view_size: Vector2, _inset_top_left: Vector2, _inset_bottom_right: Vector2) -> void:
	_far_fit = minf(view_size.y / design_height, 1.0)


## Goes to SYS, ORBIT, or SHIP.
func _on_zoom_button_pressed(button_name: String) -> void:
	match button_name:
		"SYS":
			_target_zoom = system_zoom * _far_fit
		"ORBIT":
			_target_zoom = orbit_zoom * _far_fit
		"SHIP":
			_target_zoom = zoom_stops[0]


## Scales the zoom directly, for a pinch. Above 1 zooms in.
func _on_zoom_scaled(factor: float) -> void:
	_target_zoom = minf(_target_zoom * factor, zoom_stops[0])
	_zoom = minf(_zoom * factor, zoom_stops[0])


func _on_ship_world_position_changed(x: float, y: float) -> void:
	if Input.is_action_just_pressed("zoom_in"):
		_target_zoom = _next_stop_in()
	if Input.is_action_just_pressed("zoom_out"):
		_target_zoom = _next_stop_out()

	var delta: float = get_physics_process_delta_time()
	_zoom = exp(lerpf(log(_zoom), log(_target_zoom), 1.0 - exp(-zoom_speed * delta)))
	if absf(_zoom / _target_zoom - 1.0) < 0.002:
		_zoom = _target_zoom

	var focus: Focus = _focus_for(_zoom)
	if focus != _focus:
		_previous_focus = _focus
		_focus = focus
		_focus_blend = 0.0
	_focus_blend = minf(_focus_blend + delta / focus_blend_seconds, 1.0)

	var target_x: float = _focus_x(_focus, x, y)
	var target_y: float = _focus_y(_focus, x, y)
	if _focus_blend < 1.0:
		var share: float = smoothstep(0.0, 1.0, _focus_blend)
		target_x = lerpf(_focus_x(_previous_focus, x, y), target_x, share)
		target_y = lerpf(_focus_y(_previous_focus, x, y), target_y, share)
	view_changed.emit(target_x, target_y, _zoom)


func _focus_for(zoom: float) -> Focus:
	if zoom >= ship_focus_zoom:
		return Focus.SHIP
	if zoom >= body_focus_zoom:
		return Focus.DOMINANT_BODY
	return Focus.SYSTEM_CENTER


func _focus_x(focus: Focus, ship_x: float, ship_y: float) -> float:
	match focus:
		Focus.SHIP:
			return ship_x
		Focus.DOMINANT_BODY:
			var body: int = _gravity_model.get_dominant_body(ship_x, ship_y, _state.time)
			return _gravity_model.get_body_position(body, _state.time)[0]
	return 0.0


func _focus_y(focus: Focus, ship_x: float, ship_y: float) -> float:
	match focus:
		Focus.SHIP:
			return ship_y
		Focus.DOMINANT_BODY:
			var body: int = _gravity_model.get_dominant_body(ship_x, ship_y, _state.time)
			return _gravity_model.get_body_position(body, _state.time)[1]
	return 0.0


func _next_stop_in() -> float:
	var best: float = zoom_stops[0]
	for stop: float in zoom_stops:
		if stop > _target_zoom * 1.01:
			best = minf(best, stop)
	if _target_zoom < zoom_stops[zoom_stops.size() - 1] / 1.01:
		return minf(_target_zoom * zoom_out_step, zoom_stops[zoom_stops.size() - 1])
	return best


func _next_stop_out() -> float:
	var best: float = _target_zoom / zoom_out_step
	for stop: float in zoom_stops:
		if stop < _target_zoom / 1.01:
			best = maxf(best, stop)
	return best
