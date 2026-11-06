# flight_view.gd: decides where the camera looks and how far out it is.
# From DESIGN.md, "Camera, zoom, and landing" and "UI".
#
# Zoom moves smoothly and has no outer limit. The stops are where the buttons and keys
# land. What stays centered depends only on the zoom, so the view can't jump: the ship up
# close, the body you're orbiting at the ORBIT zoom, and the middle of the system at the
# SYS zoom. In between, the ship or body slides steadily toward the middle as you zoom.
#
# Zooming changes what gets drawn, never the pixel size, so the Camera2D's own zoom stays
# at 1 and its position stays at 0,0. Instead, this signals the current view and each
# system places itself on screen from that.
extends Camera2D

## Emitted every physics tick with the world point at the middle of the screen, and
## the zoom in screen pixels per world unit.
signal view_changed(center_x: float, center_y: float, pixels_per_unit: float)

## Where keys land, closest to farthest, in screen pixels per world unit.
@export var zoom_stops: PackedFloat64Array = PackedFloat64Array([1.0, 1.0 / 8.0, 1.0 / 128.0, 1.0 / 800.0, 1.0 / 2400.0])
## How far each key press moves past the last stop.
@export var zoom_out_step: float = 3.0
## The zoom the ORBIT button goes to, and the one the game starts at.
@export var orbit_zoom: float = 1.0 / 800.0
## The zoom the SYS button goes to.
@export var system_zoom: float = 1.0 / 2400.0
## The ship is fully centered at this zoom and closer.
@export var ship_focus_zoom: float = 1.0 / 128.0
## How quickly zoom closes in on its target. Higher is snappier.
@export var zoom_speed: float = 10.0
## The most the zoom can change per second, as a natural log, so a long button zoom glides.
@export var zoom_max_rate: float = 6.0
## How long the view takes to slide to a new body when the dominant body changes, in seconds.
@export var focus_blend_seconds: float = 0.5
## The screen height the ORBIT and SYS zooms are set for, in game pixels. On a shorter
## screen they zoom out to match, so the same orbits still fit.
@export var design_height: float = 616.0

var _gravity_model: GravityModel
var _state: ShipState
var _far_fit: float = 1.0
var _zoom: float = 1.0 / 800.0
var _target_zoom: float = 1.0 / 800.0
var _body: int = 0
var _previous_body: int = 0
var _body_blend: float = 1.0


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
	var log_zoom: float = log(_zoom)
	var eased: float = lerpf(log_zoom, log(_target_zoom), 1.0 - exp(-zoom_speed * delta))
	_zoom = exp(move_toward(log_zoom, eased, zoom_max_rate * delta))
	if absf(_zoom / _target_zoom - 1.0) < 0.002:
		_zoom = _target_zoom

	var body: int = _gravity_model.get_dominant_body(x, y, _state.time)
	if body != _body:
		_previous_body = _body
		_body = body
		_body_blend = 0.0
	_body_blend = minf(_body_blend + delta / focus_blend_seconds, 1.0)

	var now: PackedFloat64Array = _gravity_model.get_body_position(_body, _state.time)
	var body_x: float = now[0]
	var body_y: float = now[1]
	if _body_blend < 1.0:
		var before: PackedFloat64Array = _gravity_model.get_body_position(_previous_body, _state.time)
		var share: float = smoothstep(0.0, 1.0, _body_blend)
		body_x = lerpf(before[0], body_x, share)
		body_y = lerpf(before[1], body_y, share)

	var orbit: float = orbit_zoom * _far_fit
	var system: float = system_zoom * _far_fit
	var center_x: float = 0.0
	var center_y: float = 0.0
	if _zoom >= ship_focus_zoom:
		center_x = x
		center_y = y
	elif _zoom >= orbit:
		var keep: float = _share_left(_zoom, orbit, ship_focus_zoom)
		center_x = x + (body_x - x) * keep
		center_y = y + (body_y - y) * keep
	elif _zoom >= system:
		var keep: float = _share_left(_zoom, system, orbit)
		center_x = body_x - body_x * keep
		center_y = body_y - body_y * keep
	view_changed.emit(center_x, center_y, _zoom)


# How much of the old center remains at this zoom, between a far zoom and a near one. It's
# chosen so the new center's distance from the middle of the screen, in pixels, shrinks
# steadily as the zoom changes, even though the world is growing underneath it.
func _share_left(zoom: float, far: float, near: float) -> float:
	var progress: float = clampf((log(zoom) - log(far)) / (log(near) - log(far)), 0.0, 1.0)
	return (far / zoom) * (1.0 - progress)


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
