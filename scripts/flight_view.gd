# flight_view.gd: decides where the camera looks and how far out it is.
# From DESIGN.md, "Camera, zoom, and landing" and "UI".
#
# Zoom moves smoothly and has no outer limit. The stops are where the buttons and keys
# land. What stays centered depends only on the zoom, so the view can't jump: the ship up
# close, the body you're orbiting at the ORBIT zoom, its planet at the SYS zoom, and the
# star at the whole system zoom. In between, one slides steadily into the next. Out in
# deep space the ship stands in for the body and planet, since the star's too far to fit.
#
# Zooming changes what gets drawn, never the pixel size, so the Camera2D's own zoom stays
# at 1 and its position stays at 0,0. Instead, this signals the current view and each
# system places itself on screen from that.
#
# From the ORBIT zoom in, the view also turns so that down on screen is down: toward the body
# below, or a nearby station's bottom, which is what keeps the ground and stations flat. Anything
# on the world's own canvas turns with the Camera2D. The background draws in screen space, so it's
# told the angle. Farther out than ORBIT, nothing is down, and it settles back to a fixed map.
extends Camera2D

## Emitted every physics tick with the world point at the middle of the screen, and
## the zoom in screen pixels per world unit.
signal view_changed(center_x: float, center_y: float, pixels_per_unit: float)
## Emitted just before view_changed, with how far the view is turned, clockwise, in radians.
signal view_rolled(angle: float)

## Where keys land, closest to farthest, in screen pixels per world unit.
@export var zoom_stops: PackedFloat64Array = PackedFloat64Array([1.0, 1.0 / 8.0, 1.0 / 128.0, 1.0 / 800.0, 1.0 / 2400.0])
## How far each key press moves past the last stop.
@export var zoom_out_step: float = 3.0
## The zoom the ORBIT button goes to, and the one the game starts at.
@export var orbit_zoom: float = 1.0 / 800.0
## The zoom the SYS button goes to first: a planet and its moons. Pressing it again shows
## the whole star system.
@export var system_zoom: float = 1.0 / 2400.0
## How much of the screen's height the widest planet orbit fills at the whole system zoom.
@export var whole_system_fill: float = 0.8
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
## The fastest the view turns to a new down, in radians per second.
@export var fastest_roll: float = 1.6
## This close to a station, in world units, down is the station's own down.
@export var station_down_reach: float = 2000.0

var _gravity_model: GravityModel
var _state: ShipState
var _far_fit: float = 1.0
var _whole_system_zoom: float = 1.0 / 160000.0
var _zoom: float = 1.0 / 800.0
var _target_zoom: float = 1.0 / 800.0
var _body: int = 0
var _previous_body: int = 0
var _body_blend: float = 1.0
var _roll: float = 0.0
var _roll_started: bool = false


## Starts following a flight.
func start_view(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	ignore_rotation = false
	_zoom = orbit_zoom
	_target_zoom = orbit_zoom
	var widest: float = 0.0
	for index in range(1, gravity_model.get_body_count()):
		if gravity_model.get_body_parent(index) == 0:
			var at: PackedFloat64Array = gravity_model.get_body_position(index, 0.0)
			widest = maxf(widest, sqrt(at[0] * at[0] + at[1] * at[1]))
	if widest > 0.0:
		_whole_system_zoom = whole_system_fill * design_height / (2.0 * widest)


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
			var local: float = system_zoom * _far_fit
			var at_local: bool = absf(_target_zoom / local - 1.0) < 0.01
			_target_zoom = _whole_system_zoom * _far_fit if at_local or _body == 0 else local
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

	var share: float = smoothstep(0.0, 1.0, _body_blend)
	var ship := PackedFloat64Array([x, y])
	var orbit_center: PackedFloat64Array = _mix(_body_center(_previous_body, ship), _body_center(_body, ship), share)
	var planet_center: PackedFloat64Array = _mix(
			_body_center(_gravity_model.get_local_root(_previous_body), ship),
			_body_center(_gravity_model.get_local_root(_body), ship), share)

	var orbit: float = orbit_zoom * _far_fit
	var system: float = system_zoom * _far_fit
	var whole: float = _whole_system_zoom * _far_fit
	var center: PackedFloat64Array = ship
	if _zoom >= ship_focus_zoom:
		center = ship
	elif _zoom >= orbit:
		center = _mix(ship, orbit_center, _share_left(_zoom, orbit, ship_focus_zoom))
	elif _zoom >= system:
		center = _mix(orbit_center, planet_center, _share_left(_zoom, system, orbit))
	elif _zoom >= whole:
		center = _mix(planet_center, PackedFloat64Array([0.0, 0.0]), _share_left(_zoom, whole, system))
	else:
		center = PackedFloat64Array([0.0, 0.0])
	_turn_toward_down(x, y, delta)
	view_changed.emit(center[0], center[1], _zoom)


func _turn_toward_down(x: float, y: float, delta: float) -> void:
	var target: float = _down_at(x, y) if _zoom >= orbit_zoom * _far_fit * 0.9 else 0.0
	if _roll_started:
		var gap: float = absf(angle_difference(_roll, target))
		_roll = rotate_toward(_roll, target, minf(gap * 3.0 + 0.15, fastest_roll) * delta)
	else:
		_roll = target
		_roll_started = true
	rotation = _roll
	view_rolled.emit(_roll)


# The turn of the view that puts down at the bottom of the screen, at a point.
func _down_at(x: float, y: float) -> float:
	for index in range(_gravity_model.get_satellite_count()):
		var at: PackedFloat64Array = _gravity_model.get_satellite_position(index, _state.time)
		if Vector2(at[0] - x, at[1] - y).length_squared() <= station_down_reach * station_down_reach:
			var parent: PackedFloat64Array = _gravity_model.get_body_position(_gravity_model.get_satellite_parent(index), _state.time)
			return atan2(at[0] - parent[0], parent[1] - at[1])
	var body: PackedFloat64Array = _gravity_model.get_body_position(_gravity_model.get_dominant_body(x, y, _state.time), _state.time)
	return atan2(x - body[0], body[1] - y)


# Where a body is, or the ship for the star, which is too far off to center on up close.
func _body_center(body: int, ship: PackedFloat64Array) -> PackedFloat64Array:
	return ship if body == 0 else _gravity_model.get_body_position(body, _state.time)


func _mix(from: PackedFloat64Array, to: PackedFloat64Array, share: float) -> PackedFloat64Array:
	return PackedFloat64Array([lerpf(from[0], to[0], share), lerpf(from[1], to[1], share)])


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
