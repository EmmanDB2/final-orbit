# body_guides.gd: draws each body's rails and the edge of its sphere of influence.
# From DESIGN.md, "Camera, zoom, and landing" (far zooms show orbits and spheres of
# influence).
#
# Each body's rails are drawn around its parent as it is now, since moons ride along with
# their planet. An orbit or ring too small to read on screen is left out.
extends Node2D

## Canopy glass dark from the agency palette, so these sit behind the telemetry line.
@export var guide_color: Color = Color("2A4A55")
## The guides show at this zoom and farther out.
@export var closest_zoom: float = 0.01
## Points along each orbit.
@export var orbit_samples: int = 512
## Points around each sphere of influence.
@export var ring_points: int = 96
## An orbit whose radius on screen is smaller than this isn't drawn, in pixels.
@export var smallest_orbit: float = 12.0
## A sphere of influence whose radius on screen is smaller than this isn't drawn, in pixels.
@export var smallest_ring: float = 5.0

var _gravity_model: GravityModel
var _state: ShipState
var _rails: Array[PackedFloat64Array] = []
var _screen_orbits: Array[PackedVector2Array] = []
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 0.0


## Starts drawing the guides for every body with rails in the gravity model.
func start_guides(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	for index in range(1, gravity_model.get_body_count()):
		_rails.append(gravity_model.get_body_orbit_path(index, orbit_samples))
	for index in range(gravity_model.get_satellite_count()):
		_rails.append(gravity_model.get_satellite_orbit_path(index, orbit_samples))


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	visible = pixels_per_unit <= closest_zoom
	if pixels_per_unit != _pixels_per_unit:
		_pixels_per_unit = pixels_per_unit
		_rebuild_orbits()
	if visible:
		queue_redraw()


func _rebuild_orbits() -> void:
	_screen_orbits.clear()
	for rail: PackedFloat64Array in _rails:
		var screen := PackedVector2Array()
		screen.resize(rail.size() / 2)
		for i in range(screen.size()):
			screen[i] = Vector2(rail[i * 2] * _pixels_per_unit, rail[i * 2 + 1] * _pixels_per_unit)
		_screen_orbits.append(screen)


func _draw() -> void:
	# This sits in the background layer, behind the bodies, where the origin is the screen's corner.
	var middle: Vector2 = get_viewport_rect().size / 2.0
	var body_rails: int = _gravity_model.get_body_count() - 1
	for i in range(body_rails, _screen_orbits.size()):
		_draw_satellite_rail(i - body_rails, _screen_orbits[i], middle)
	for i in range(body_rails):
		var index: int = i + 1
		var parent_now: PackedFloat64Array = _gravity_model.get_body_position(_gravity_model.get_body_parent(index), _state.time)
		var body_now: PackedFloat64Array = _gravity_model.get_body_position(index, _state.time)
		var parent_on_screen := Vector2(
				(parent_now[0] - _center_x) * _pixels_per_unit,
				(parent_now[1] - _center_y) * _pixels_per_unit)
		draw_set_transform((middle + parent_on_screen).round())

		var center := Vector2(
				(body_now[0] - parent_now[0]) * _pixels_per_unit,
				(body_now[1] - parent_now[1]) * _pixels_per_unit)
		var radius: float = _gravity_model.get_sphere_of_influence(index) * _pixels_per_unit
		if center.length() >= smallest_orbit:
			_draw_outside_ring(_screen_orbits[i], center, radius)
		if radius >= smallest_ring and center.length() >= smallest_orbit:
			draw_arc(center, radius, 0.0, TAU, ring_points, guide_color, -1.0)


# A satellite's rails, around its parent as it is now. It has no ring to stop at.
func _draw_satellite_rail(index: int, points: PackedVector2Array, middle: Vector2) -> void:
	var parent_now: PackedFloat64Array = _gravity_model.get_body_position(_gravity_model.get_satellite_parent(index), _state.time)
	var parent_on_screen := Vector2(
			(parent_now[0] - _center_x) * _pixels_per_unit,
			(parent_now[1] - _center_y) * _pixels_per_unit)
	if points[0].length() >= smallest_orbit:
		draw_set_transform((middle + parent_on_screen).round())
		draw_polyline(points, guide_color, -1.0)


# Draws a body's orbit line, stopping where it meets the ring around that body.
func _draw_outside_ring(points: PackedVector2Array, center: Vector2, radius: float) -> void:
	var run := PackedVector2Array()
	for i in range(points.size()):
		if points[i].distance_to(center) >= radius:
			if run.is_empty() and i > 0:
				run.append(_ring_crossing(points[i - 1], points[i], center, radius))
			run.append(points[i])
		elif not run.is_empty():
			run.append(_ring_crossing(points[i - 1], points[i], center, radius))
			draw_polyline(run, guide_color, -1.0)
			run = PackedVector2Array()
	if run.size() >= 2:
		draw_polyline(run, guide_color, -1.0)


func _ring_crossing(from: Vector2, to: Vector2, center: Vector2, radius: float) -> Vector2:
	var from_distance: float = from.distance_to(center)
	return from.lerp(to, (radius - from_distance) / (to.distance_to(center) - from_distance))
