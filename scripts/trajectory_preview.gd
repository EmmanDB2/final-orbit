# trajectory_preview.gd: draws the path the ship will coast along.
# From DESIGN.md, "Physics" (trajectory preview) and "Art direction" (telemetry cyan
# belongs to trajectories).
#
# The path is only worked out again when the orbit changes, so a steady orbit costs
# nothing. It's kept relative to the world origin, so when the view moves it's enough
# to move this node.
extends Node2D

## Telemetry cyan from the agency palette.
@export var line_color: Color = Color("7FE3D6")
## How far ahead a path that doesn't close is shown, in seconds. Closed orbits show one lap.
@export var horizon_seconds: float = 3600.0
## Points along the path.
@export var sample_count: int = 512
## How often, in physics ticks, a path that doesn't close gets worked out again, so the
## part the ship has already flown clears away.
@export var open_path_refresh_ticks: int = 30

var _gravity_model: GravityModel
var _state: ShipState
var _world_points: PackedFloat64Array = PackedFloat64Array()
var _screen_points: PackedVector2Array = PackedVector2Array()
var _pixels_per_unit: float = 0.0
var _path_is_closed: bool = false
var _ticks_since_update: int = 0


## Starts drawing the path of this ship state.
func start_preview(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	_update_path()


func _on_ship_orbit_changed() -> void:
	_update_path()


func _on_ship_world_position_changed(_x: float, _y: float) -> void:
	_ticks_since_update += 1
	if not _path_is_closed and _ticks_since_update >= open_path_refresh_ticks:
		_update_path()


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	position = Vector2(-center_x * pixels_per_unit, -center_y * pixels_per_unit).round()
	if pixels_per_unit != _pixels_per_unit:
		_pixels_per_unit = pixels_per_unit
		_rebuild_screen_points()


func _update_path() -> void:
	_ticks_since_update = 0
	_world_points = _gravity_model.predict_trajectory(_state, horizon_seconds, sample_count)

	# A closed orbit comes back to where it started, so it stays right until the next burn.
	var last: int = _world_points.size() - 2
	var gap_x: float = _world_points[last] - _world_points[0]
	var gap_y: float = _world_points[last + 1] - _world_points[1]
	_path_is_closed = _world_points.size() == sample_count * 2 and gap_x * gap_x + gap_y * gap_y < 1.0

	_rebuild_screen_points()


func _rebuild_screen_points() -> void:
	var count: int = _world_points.size() / 2
	_screen_points.resize(count)
	for i in range(count):
		_screen_points[i] = Vector2(_world_points[i * 2] * _pixels_per_unit, _world_points[i * 2 + 1] * _pixels_per_unit)
	queue_redraw()


func _draw() -> void:
	if _screen_points.size() >= 2:
		# A width of -1 draws a true one-pixel line, which stays on the pixel grid.
		draw_polyline(_screen_points, line_color, -1.0)
