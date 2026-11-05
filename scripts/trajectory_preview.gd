# trajectory_preview.gd: draws the path the ship will coast along.
# From DESIGN.md, "Physics" (trajectory preview) and "Art direction" (telemetry cyan
# belongs to trajectories).
#
# The path is worked out again on a burn, on a change of dominant body, every tick while
# orbiting a moving body, and otherwise only a couple of times a second. It's kept
# relative to the world origin, so when the view moves it's enough to move this node.
#
# If the path reaches another body, this also rings that body where it will be at that
# moment, because the flyby on the line is drawn around that future position.
extends Node2D

## Telemetry cyan from the agency palette.
@export var line_color: Color = Color("7FE3D6")
## How far ahead a path is shown, in seconds. Closed orbits show one lap.
@export var horizon_seconds: float = 3600.0
## Points along the path.
@export var sample_count: int = 512
## How often, in physics ticks, a coasting path gets worked out again, to clear the part
## already flown and to catch encounters as the moon moves.
@export var refresh_ticks: int = 30
## How many points are in the ring around a future encounter.
@export var ring_points: int = 64

var _gravity_model: GravityModel
var _state: ShipState
var _world_points: PackedFloat64Array = PackedFloat64Array()
var _screen_points: PackedVector2Array = PackedVector2Array()
var _pixels_per_unit: float = 0.0
var _ticks_since_update: int = 0
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
	# Around a moon the line is drawn around where the moon is now, so it has to keep up.
	if dominant != 0 or dominant != _dominant_body or _ticks_since_update >= refresh_ticks:
		_dominant_body = dominant
		_update_path()


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	position = Vector2(-center_x * pixels_per_unit, -center_y * pixels_per_unit).round()
	if pixels_per_unit != _pixels_per_unit:
		_pixels_per_unit = pixels_per_unit
		_rebuild_screen_points()


func _update_path() -> void:
	_ticks_since_update = 0
	_world_points = _gravity_model.predict_trajectory(_state, horizon_seconds, sample_count)

	var encounter: PackedFloat64Array = _gravity_model.find_encounter(_state, horizon_seconds)
	_has_encounter = encounter.size() == 2
	if _has_encounter:
		_encounter_body = int(encounter[1])
		var position_then: PackedFloat64Array = _gravity_model.get_body_position(_encounter_body, _state.time + encounter[0])
		_encounter_x = position_then[0]
		_encounter_y = position_then[1]

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

	if _has_encounter:
		var center := Vector2(_encounter_x * _pixels_per_unit, _encounter_y * _pixels_per_unit)
		var surface: float = _gravity_model.get_body_radius(_encounter_body) * _pixels_per_unit
		draw_arc(center, surface, 0.0, TAU, ring_points, line_color, -1.0)
