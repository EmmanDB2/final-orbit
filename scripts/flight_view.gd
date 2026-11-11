# flight_view.gd: decides where the camera looks and how far out it is.
# From DESIGN.md, "Camera, zoom, and landing" and "UI".
#
# Whatever was tapped last is the focus, and it stays in the middle of the screen at every zoom: the
# ship to start with, or a station, moon, planet, or the star. Zoom moves smoothly and has no outer
# limit, and the stops are where the buttons and keys land. A planet can't be zoomed into past the
# point where it fills the screen, since its middle has nothing to see. Only out at the whole system
# zooms does the middle slide to the star, so the whole system fits whatever's in focus.
#
# Zooming changes what gets drawn, never the pixel size, so the Camera2D's own zoom stays
# at 1 and its position stays at 0,0. Instead, this signals the current view and each
# system places itself on screen from that.
#
# From the ORBIT zoom in, the view also turns so that down on screen is down: toward the body
# below, or a nearby station's bottom, which is what keeps the ground and stations flat. Anything
# on the world's own canvas turns with the Camera2D. The background draws in screen space, so it's
# told the angle. Farther out than ORBIT, or with a body in focus, nothing is down, and it settles
# back to a fixed map.
extends Camera2D

## Emitted every physics tick with the world point at the middle of the screen, and
## the zoom in screen pixels per world unit.
signal view_changed(center_x: float, center_y: float, pixels_per_unit: float)
## Emitted just before view_changed, with how far the view is turned, clockwise, in radians.
signal view_rolled(angle: float)
## Emitted when the zoom settles on a different button's stop, with its name or nothing.
signal zoom_stop_changed(stop_name: String)

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
## How quickly zoom closes in on its target. Higher is snappier.
@export var zoom_speed: float = 10.0
## The most the zoom can change per second, as a natural log, so a long button zoom glides.
@export var zoom_max_rate: float = 6.0
## How long the view takes to slide to a new focus, in seconds.
@export var focus_blend_seconds: float = 0.5
## How close a tap has to land to something small on screen to pick it, in pixels.
@export var tap_reach: float = 18.0
## How much of the screen's height a body in focus can fill at the closest.
@export var body_fill: float = 0.9
## How wide the ship and a station count as for a tap, as a radius in world units.
@export var ship_tap_radius: float = 110.0
@export var station_tap_radius: float = 700.0
@export var pilot_tap_radius: float = 24.0
## How long the brackets around a new focus last, in seconds.
@export var focus_mark_seconds: float = 1.0
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
var _view_size := Vector2(816.0, 616.0)
var _body: int = 0
# What's in focus: a "kind" of ship, body, or satellite, and for the last two its "index".
var _focus: Dictionary = {"kind": "ship", "index": 0}
var _previous_focus: Dictionary = {"kind": "ship", "index": 0}
var _focus_blend: float = 1.0
var _focus_mark: float = 0.0
var _lit_stop: String = "?"
var _pilot: Node2D
# Places built on worlds, which can be tapped and focused like anything else.
var _sites: Array[SiteView] = []
# What the SHIP button brings the view back to: the ship, or the pilot while they're out of it.
var _avatar: Dictionary = {"kind": "ship", "index": 0}
var _center_x: float = 0.0
var _center_y: float = 0.0
var _roll: float = 0.0
var _roll_started: bool = false


## Starts following a flight, with something in focus at the SYS zoom.
func start_view(gravity_model: GravityModel, state: ShipState, start_focus: Dictionary) -> void:
	_gravity_model = gravity_model
	_state = state
	ignore_rotation = false
	_zoom = system_zoom
	_target_zoom = system_zoom
	_focus = start_focus
	_previous_focus = start_focus
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
	_view_size = view_size


## Goes to SYS, ORBIT, or SHIP. SHIP also brings the focus back to the ship, since it's the way home
## from anything else, and a body in focus couldn't be zoomed that close anyway.
func _on_zoom_button_pressed(button_name: String) -> void:
	match button_name:
		"SYS":
			var local: float = system_zoom * _far_fit
			var at_local: bool = absf(_target_zoom / local - 1.0) < 0.01
			_target_zoom = _whole_system_zoom * _far_fit if at_local or _body == 0 else local
		"ORBIT":
			_target_zoom = orbit_zoom * _far_fit
		"SHIP":
			_set_focus(_avatar)
			_target_zoom = zoom_stops[0]


## Scales the zoom directly, for a pinch. Above 1 zooms in.
func _on_zoom_scaled(factor: float) -> void:
	var closest: float = _closest_zoom()
	_target_zoom = minf(_target_zoom * factor, closest)
	_zoom = minf(_zoom * factor, closest)


func _on_ship_world_position_changed(x: float, y: float) -> void:
	if Input.is_action_just_pressed("zoom_in"):
		_target_zoom = _next_stop_in()
	if Input.is_action_just_pressed("zoom_out"):
		_target_zoom = _next_stop_out()

	var closest: float = _closest_zoom()
	_target_zoom = minf(_target_zoom, closest)
	var delta: float = TimeWarp.real(get_physics_process_delta_time())
	var log_zoom: float = log(_zoom)
	var eased: float = lerpf(log_zoom, log(_target_zoom), 1.0 - exp(-zoom_speed * delta))
	_zoom = exp(move_toward(log_zoom, eased, zoom_max_rate * delta))
	if absf(_zoom / _target_zoom - 1.0) < 0.002:
		_zoom = _target_zoom

	_body = _gravity_model.get_dominant_body(x, y, _state.time)
	_focus_blend = minf(_focus_blend + delta / focus_blend_seconds, 1.0)
	if _focus_mark > 0.0:
		_focus_mark = maxf(_focus_mark - delta / focus_mark_seconds, 0.0)
		queue_redraw()

	var ship := PackedFloat64Array([x, y])
	var center: PackedFloat64Array = _mix(_point_of(_previous_focus, ship), _point_of(_focus, ship), smoothstep(0.0, 1.0, _focus_blend))
	var system: float = system_zoom * _far_fit
	var whole: float = _whole_system_zoom * _far_fit
	if _zoom < whole:
		center = PackedFloat64Array([0.0, 0.0])
	elif _zoom < system:
		center = _mix(center, PackedFloat64Array([0.0, 0.0]), _share_left(_zoom, whole, system))
	_center_x = center[0]
	_center_y = center[1]
	_turn_toward_down(x, y, delta)
	_update_lit_stop()
	view_changed.emit(center[0], center[1], _zoom)


func _update_lit_stop() -> void:
	var lit: String = ""
	if absf(_target_zoom / (orbit_zoom * _far_fit) - 1.0) < 0.01:
		lit = "ORBIT"
	elif absf(_target_zoom / (system_zoom * _far_fit) - 1.0) < 0.01 or absf(_target_zoom / (_whole_system_zoom * _far_fit) - 1.0) < 0.01:
		lit = "SYS"
	elif absf(_target_zoom / zoom_stops[0] - 1.0) < 0.01:
		lit = "SHIP"
	if lit != _lit_stop:
		_lit_stop = lit
		zoom_stop_changed.emit(lit)


func _turn_toward_down(x: float, y: float, delta: float) -> void:
	var has_down: bool = _focus["kind"] != "body" and _zoom >= orbit_zoom * _far_fit * 0.9
	var at: PackedFloat64Array = _point_of(_focus, PackedFloat64Array([x, y]))
	var target: float = _down_at(at[0], at[1]) if has_down else 0.0
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


# Where something that can be in focus is right now.
func _point_of(focus: Dictionary, ship: PackedFloat64Array) -> PackedFloat64Array:
	match focus["kind"]:
		"body":
			return _gravity_model.get_body_position(focus["index"], _state.time)
		"satellite":
			return _gravity_model.get_satellite_position(focus["index"], _state.time)
		"pilot":
			return PackedFloat64Array([_pilot.state.x, _pilot.state.y])
		"site":
			return _sites[focus["index"]].middle(_state.time)
	return ship


func _set_focus(focus: Dictionary) -> void:
	if focus == _focus:
		_focus_mark = 1.0
		return
	_previous_focus = _focus
	_focus = focus
	_focus_blend = 0.0
	_focus_mark = 1.0


# The closest the view can get with this in focus. A body's middle has nothing to see.
func _closest_zoom() -> float:
	if _focus["kind"] != "body":
		return zoom_stops[0]
	var fits: float = minf(_view_size.x, _view_size.y) * 0.5 * body_fill / _gravity_model.get_body_radius(_focus["index"])
	return minf(fits, zoom_stops[0])


## Tells the view about a place built on a world.
func add_site(site: SiteView) -> void:
	_sites.append(site)


## Tells the view about the pilot.
func set_pilot(pilot: Node2D) -> void:
	_pilot = pilot


## When the pilot leaves the ship the view goes with them, up close. When they're back, it goes to
## the ship. Between EVA and inside a station it only stays on them.
func _on_pilot_mode_changed(mode: String) -> void:
	var was_aboard: bool = _avatar["kind"] == "ship"
	_avatar = {"kind": "ship", "index": 0} if mode == Pilot.ABOARD else {"kind": "pilot", "index": 0}
	if was_aboard != (mode == Pilot.ABOARD):
		_set_focus(_avatar)
		_target_zoom = zoom_stops[0]


## Whatever's under a tap becomes the focus. A tap on empty space does nothing.
func _on_space_tapped(screen_position: Vector2) -> void:
	var found: Dictionary = thing_at(screen_position)
	if not found.is_empty():
		_set_focus(found)


## Makes this the focus.
func set_focus(thing: Dictionary) -> void:
	_set_focus(thing)


func is_focus(thing: Dictionary) -> bool:
	return thing == _focus


## A way to ask where this thing is right now, as [x, y].
func point_getter(thing: Dictionary) -> Callable:
	return func() -> PackedFloat64Array: return _point_of(thing, PackedFloat64Array([_state.x, _state.y]))


## Where a point in the world shows on screen.
func to_screen(x: float, y: float) -> Vector2:
	return _view_size / 2.0 + Vector2((x - _center_x) * _zoom, (y - _center_y) * _zoom).rotated(-_roll)


## Where this thing shows on screen: its "center", and its "radius" in pixels.
func screen_spot_of(thing: Dictionary) -> Dictionary:
	var at: PackedFloat64Array = _point_of(thing, PackedFloat64Array([_state.x, _state.y]))
	var from_middle: Vector2 = Vector2((at[0] - _center_x) * _zoom, (at[1] - _center_y) * _zoom).rotated(-_roll)
	return {"center": _view_size / 2.0 + from_middle, "radius": _tap_radius_of(thing) * _zoom}


## What's at this point on screen, or nothing. The smallest thing wins where they overlap, so a ship
## can be picked in front of a planet.
func thing_at(screen_position: Vector2) -> Dictionary:
	var from_middle: Vector2 = (screen_position - _view_size / 2.0).rotated(_roll) / _zoom
	var tapped := Vector2(_center_x + from_middle.x, _center_y + from_middle.y)
	var best: Dictionary = {}
	var smallest: float = INF
	var candidates: Array[Dictionary] = [{"kind": "ship", "index": 0}]
	if _avatar["kind"] == "pilot":
		candidates.append(_avatar)
	for index in range(_gravity_model.get_satellite_count()):
		candidates.append({"kind": "satellite", "index": index})
	for index in range(_gravity_model.get_body_count()):
		candidates.append({"kind": "body", "index": index})
	for index in range(_sites.size()):
		candidates.append({"kind": "site", "index": index})
	for candidate: Dictionary in candidates:
		var at: PackedFloat64Array = _point_of(candidate, PackedFloat64Array([_state.x, _state.y]))
		var radius: float = _tap_radius_of(candidate)
		var reach: float = maxf(radius, tap_reach / _zoom)
		# A place on a world can't take taps on the middle of its world, however far out the view is,
		# or the world itself could never be picked once it's small.
		if candidate["kind"] == "site":
			reach = maxf(radius, minf(reach, _gravity_model.get_body_radius(_sites[candidate["index"]].world) * 0.5))
		if Vector2(at[0] - tapped.x, at[1] - tapped.y).length() <= reach and radius < smallest:
			smallest = radius
			best = candidate
	return best


func _tap_radius_of(focus: Dictionary) -> float:
	match focus["kind"]:
		"body":
			return _gravity_model.get_body_radius(focus["index"])
		"satellite":
			return station_tap_radius
		"pilot":
			return pilot_tap_radius
		"site":
			return _sites[focus["index"]].reach()
	return ship_tap_radius


# Brackets around a new focus for a moment, to show what the tap picked. It's always in the middle
# of the view, except out where the whole system is sliding into place.
func _draw() -> void:
	if _focus_mark <= 0.0:
		return
	var color: Color = UiStyle.palette().telemetry_cyan
	color.a = minf(_focus_mark * 2.0, 1.0)
	draw_set_transform(Vector2.ZERO, _roll)
	var half: float = clampf(_tap_radius_of(_focus) * _zoom, tap_reach, minf(_view_size.x, _view_size.y) * 0.46)
	var arm: float = half * 0.35
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner * half
		draw_line(at, at - Vector2(corner.x * arm, 0.0), color, -1.0)
		draw_line(at, at - Vector2(0.0, corner.y * arm), color, -1.0)


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
