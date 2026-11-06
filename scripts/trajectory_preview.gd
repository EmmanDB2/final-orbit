# trajectory_preview.gd: draws the path the ship will coast along.
# From DESIGN.md, "Physics" (trajectory preview) and "Art direction" (telemetry cyan
# belongs to trajectories).
#
# The path is worked out again on a burn, on a change of dominant body, and every tick
# on a path that doesn't close, so no flown part lingers behind the ship. A closed orbit's
# line loops back over itself, so it only needs a couple of updates a second.
#
# Points are kept relative to where the ship was when the path was worked out, because
# they're 32-bit once they reach the screen and the world is far too big for that. That
# spot rides along with the dominant body, so when the view or the body moves it's enough
# to move this node.
#
# If the path reaches another body, this also rings that body where it will be at that
# moment, because the flyby on the line is drawn around that future position.
#
# The stretches inside a body's landing zone are drawn over the line in amber, so you can
# see where a path starts coming down. From the landing line idea in DESIGN.md.
extends Node2D

## Telemetry cyan from the agency palette.
@export var line_color: Color = Color("7FE3D6")
## Telemetry amber from the agency palette, for the part inside a landing zone.
@export var landing_color: Color = Color("F2B33A")
## How far ahead a path is shown, in seconds. Closed orbits show one lap.
@export var horizon_seconds: float = 21600.0
## Points along the path.
@export var sample_count: int = 512
## How often, in physics ticks, a coasting path gets worked out again, to clear the part
## already flown and to catch encounters as the moon moves.
@export var refresh_ticks: int = 30
## How many points are in the ring around a future encounter.
@export var ring_points: int = 64

var _gravity_model: GravityModel
var _state: ShipState
var _path_points: PackedFloat64Array = PackedFloat64Array()
var _anchor_x: float = 0.0
var _anchor_y: float = 0.0
var _center_x: float = 0.0
var _center_y: float = 0.0
var _screen_points: PackedVector2Array = PackedVector2Array()
var _entry_heights: PackedFloat64Array = PackedFloat64Array()
var _landing_runs: Array[PackedVector2Array] = []
var _pixels_per_unit: float = 0.0
var _ticks_since_update: int = 0
var _path_is_open: bool = true
var _dominant_body: int = 0
var _has_encounter: bool = false
var _encounter_body: int = 0
var _encounter_x: float = 0.0
var _encounter_y: float = 0.0


## Starts drawing the path of this ship state.
func start_preview(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	_update_path()


func _on_ship_orbit_changed() -> void:
	_update_path()


func _on_ship_world_position_changed(x: float, y: float) -> void:
	_ticks_since_update += 1
	var dominant: int = _gravity_model.get_dominant_body(x, y, _state.time)
	if dominant != _dominant_body or _path_is_open or _ticks_since_update >= refresh_ticks:
		_update_path()


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	if pixels_per_unit != _pixels_per_unit:
		_pixels_per_unit = pixels_per_unit
		_rebuild_screen_points()
	_place()


# Puts the spot the points are measured from where it is on screen now.
func _place() -> void:
	var body_now: PackedFloat64Array = _gravity_model.get_body_position(_dominant_body, _state.time)
	position = Vector2(
			(body_now[0] + _anchor_x - _center_x) * _pixels_per_unit,
			(body_now[1] + _anchor_y - _center_y) * _pixels_per_unit).round()


func _update_path() -> void:
	_ticks_since_update = 0
	_dominant_body = _gravity_model.get_dominant_body(_state.x, _state.y, _state.time)
	var body_now: PackedFloat64Array = _gravity_model.get_body_position(_dominant_body, _state.time)
	_anchor_x = _state.x - body_now[0]
	_anchor_y = _state.y - body_now[1]

	_path_points = _gravity_model.predict_trajectory(_state, horizon_seconds, sample_count)
	for i in range(0, _path_points.size(), 2):
		_path_points[i] -= _state.x
		_path_points[i + 1] -= _state.y
	_entry_heights = _gravity_model.predict_entry_heights(_state, horizon_seconds, sample_count)

	var gap_x: float = _path_points[_path_points.size() - 2] - _path_points[0]
	var gap_y: float = _path_points[_path_points.size() - 1] - _path_points[1]
	_path_is_open = gap_x * gap_x + gap_y * gap_y > 1.0

	var encounter: PackedFloat64Array = _gravity_model.find_encounter(_state, horizon_seconds)
	_has_encounter = encounter.size() == 2
	if _has_encounter:
		_encounter_body = int(encounter[1])
		# Where that body will be, seen from the dominant body, as the line draws it.
		var when: float = _state.time + encounter[0]
		var position_then: PackedFloat64Array = _gravity_model.get_body_position(_encounter_body, when)
		var dominant_then: PackedFloat64Array = _gravity_model.get_body_position(_dominant_body, when)
		_encounter_x = position_then[0] - dominant_then[0] - _anchor_x
		_encounter_y = position_then[1] - dominant_then[1] - _anchor_y

	_rebuild_screen_points()
	_place()


func _rebuild_screen_points() -> void:
	var count: int = _path_points.size() / 2
	_screen_points.resize(count)
	for i in range(count):
		_screen_points[i] = Vector2(_path_points[i * 2] * _pixels_per_unit, _path_points[i * 2 + 1] * _pixels_per_unit)
	_rebuild_landing_runs()
	queue_redraw()


# Splits out the stretches below the entry height, ending each exactly where the line crosses it.
func _rebuild_landing_runs() -> void:
	_landing_runs.clear()
	var run := PackedVector2Array()
	for i in range(_screen_points.size()):
		if _entry_heights[i] < 0.0:
			if run.is_empty() and i > 0:
				run.append(_crossing_point(i - 1, i))
			run.append(_screen_points[i])
		elif not run.is_empty():
			run.append(_crossing_point(i - 1, i))
			_landing_runs.append(run)
			run = PackedVector2Array()
	if run.size() >= 2:
		_landing_runs.append(run)


func _crossing_point(from_index: int, to_index: int) -> Vector2:
	var share: float = _entry_heights[from_index] / (_entry_heights[from_index] - _entry_heights[to_index])
	return _screen_points[from_index].lerp(_screen_points[to_index], share)


func _draw() -> void:
	if _screen_points.size() >= 2:
		# A width of -1 draws a true one-pixel line, which stays on the pixel grid.
		draw_polyline(_screen_points, line_color, -1.0)
	for run: PackedVector2Array in _landing_runs:
		draw_polyline(run, landing_color, -1.0)

	if _has_encounter:
		var center := Vector2(_encounter_x * _pixels_per_unit, _encounter_y * _pixels_per_unit)
		var surface: float = _gravity_model.get_body_radius(_encounter_body) * _pixels_per_unit
		draw_arc(center, surface, 0.0, TAU, ring_points, line_color, -1.0)
