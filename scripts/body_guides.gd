# body_guides.gd: draws each moon's rails and the edge of its sphere of influence.
# From DESIGN.md, "Camera, zoom, and landing" (far zooms show local orbits and spheres
# of influence).
extends Node2D

## Canopy glass dark from the agency palette, so these sit behind the telemetry line.
@export var guide_color: Color = Color("2A4A55")
## The guides show at this zoom and farther out.
@export var closest_zoom: float = 0.01
## Points along each moon's orbit.
@export var orbit_samples: int = 256
## Points around each sphere of influence.
@export var ring_points: int = 96

var _gravity_model: GravityModel
var _state: ShipState
var _world_orbits: Array[PackedFloat64Array] = []
var _screen_orbits: Array[PackedVector2Array] = []
var _pixels_per_unit: float = 0.0


## Starts drawing the guides for every moon in the gravity model.
func start_guides(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	for index in range(1, gravity_model.get_body_count()):
		_world_orbits.append(gravity_model.get_body_orbit_path(index, orbit_samples))


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	# This sits in the background layer, behind the bodies, where the origin is the screen's corner.
	position = (get_viewport_rect().size / 2.0 + Vector2(-center_x * pixels_per_unit, -center_y * pixels_per_unit)).round()
	visible = pixels_per_unit <= closest_zoom
	if pixels_per_unit != _pixels_per_unit:
		_pixels_per_unit = pixels_per_unit
		_rebuild_orbits()
	if visible:
		queue_redraw()


func _rebuild_orbits() -> void:
	_screen_orbits.clear()
	for world: PackedFloat64Array in _world_orbits:
		var screen := PackedVector2Array()
		screen.resize(world.size() / 2)
		for i in range(screen.size()):
			screen[i] = Vector2(world[i * 2] * _pixels_per_unit, world[i * 2 + 1] * _pixels_per_unit)
		_screen_orbits.append(screen)


func _draw() -> void:
	for i in range(_screen_orbits.size()):
		var index: int = i + 1
		var now: PackedFloat64Array = _gravity_model.get_body_position(index, _state.time)
		var center := Vector2(now[0] * _pixels_per_unit, now[1] * _pixels_per_unit)
		var radius: float = _gravity_model.get_sphere_of_influence(index) * _pixels_per_unit
		_draw_outside_ring(_screen_orbits[i], center, radius)
		draw_arc(center, radius, 0.0, TAU, ring_points, guide_color, -1.0)


# Draws a moon's orbit line, stopping where it meets the ring around that moon.
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
