# trajectory_preview.gd: draws the path the ship will coast along.
# From DESIGN.md, "Physics" (trajectory preview, landing prediction) and "Art direction" (telemetry
# cyan belongs to trajectories).
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
#
# Above any air, the line is the exact coast, which ignores air. Where it meets air, the ship's
# forecast of its landing takes over: the coast is cut off at the top of the air, and from there
# the line is the path really flown through it, with the landing zone marked on the ground at its
# end. That part is drawn against the turning ground, so it ends on the ground the ship comes down
# on. Each forecast is swapped in as it arrives, and between them the line turns with the ground.
# Inside the air there's no coast worth drawing, so it isn't worked out at all.
extends Node2D

## How wide a column of the ground is, in world units. See the gravity model's terrain.
const WORLD_PIXEL: float = 2.0

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
## The most points the landing zone's line along the ground is drawn with.
@export var zone_points: int = 48

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
# The ship's latest forecast of its landing, or empty, and the part of it flown through air.
var _landing: Dictionary = {}
var _flown: LandingPath
var _flown_times: PackedFloat64Array = PackedFloat64Array()
var _flown_from: int = 0
var _riding: bool = false


func _ready() -> void:
	_flown = LandingPath.new()
	_flown.color = landing_color
	add_child(_flown)


## Starts drawing the path of this ship state.
func start_preview(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	_update_path()


func _on_ship_orbit_changed() -> void:
	if not _riding:
		_update_path()


func _on_ship_world_position_changed(x: float, y: float) -> void:
	_follow_flown_path(x, y)
	if _riding:
		return
	_ticks_since_update += 1
	var dominant: int = _gravity_model.get_dominant_body(x, y, _state.time)
	if dominant != _dominant_body or _path_is_open or _ticks_since_update >= refresh_ticks:
		_update_path()


## A new forecast of how the ship comes down, or an empty one when it isn't any more.
func _on_ship_landing_predicted(prediction: Dictionary) -> void:
	_landing = prediction
	var path: PackedFloat64Array = prediction.get("path", PackedFloat64Array())
	if path.size() < 4:
		_flown.clear()
		_flown_times = PackedFloat64Array()
	else:
		var points := PackedVector2Array()
		points.resize(path.size() / 2)
		for i in range(points.size()):
			points[i] = Vector2(path[i * 2], path[i * 2 + 1])
		_flown.points = points
		_flown.zone = _zone_along_ground(prediction)
		_flown_times = prediction["times"]
		_flown_from = 0
		_flown.queue_redraw()
	_follow_flown_path(_state.x, _state.y)
	if _riding:
		_place()
	else:
		_update_path()


## Where the forecast's landing is in the world right now, as [x, y], or nothing if there isn't one.
## The landing label asks this.
func landing_point() -> PackedFloat64Array:
	if not _landing.get("lands", false):
		return PackedFloat64Array()
	var end: PackedFloat64Array = _landing["end"]
	var turned: float = _ground_turn()
	var body_now: PackedFloat64Array = _gravity_model.get_body_position(_landing["body"], _state.time)
	return PackedFloat64Array([
			body_now[0] + end[0] * cos(turned) - end[1] * sin(turned),
			body_now[1] + end[0] * sin(turned) + end[1] * cos(turned)])


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
	# The flown path is measured from the body's middle, and turns with its ground.
	_flown.position = Vector2(-_anchor_x * _pixels_per_unit, -_anchor_y * _pixels_per_unit)
	_flown.scale = Vector2.ONE * _pixels_per_unit
	_flown.rotation = _ground_turn()
	if _flown.pixels_per_unit != _pixels_per_unit:
		_flown.pixels_per_unit = _pixels_per_unit
		_flown.queue_redraw()


# How far the ground has turned since the forecast's line through the air began, which is how far
# that line has to turn to stay on it. Nothing, until the ship gets there.
func _ground_turn() -> float:
	if _landing.is_empty():
		return 0.0
	return _landing.get("spin", 0.0) * maxf(_state.time - _landing.get("ground_time", _state.time), 0.0)


# Starts the flown line from where the ship is now, so none of it lingers behind, and notes whether
# the ship's on it yet. Once it is, it's in the air, and the coast above the air has nothing to show.
func _follow_flown_path(x: float, y: float) -> void:
	var riding: bool = not _flown_times.is_empty() and _state.time >= _flown_times[0]
	if riding:
		while _flown_from < _flown_times.size() and _flown_times[_flown_from] <= _state.time:
			_flown_from += 1
		var body_now: PackedFloat64Array = _gravity_model.get_body_position(_landing["body"], _state.time)
		var turned: float = -_ground_turn()
		var from_body_x: float = x - body_now[0]
		var from_body_y: float = y - body_now[1]
		_flown.from_index = _flown_from
		_flown.from_point = Vector2(
				from_body_x * cos(turned) - from_body_y * sin(turned),
				from_body_x * sin(turned) + from_body_y * cos(turned))
		_flown.queue_redraw()
	elif _flown.from_index != -1:
		_flown.from_index = -1
		_flown.queue_redraw()
	if riding != _riding:
		_riding = riding
		queue_redraw()


# The ground between the landing zone's two ends, following its ups and downs, measured like the
# flown path.
func _zone_along_ground(prediction: Dictionary) -> PackedVector2Array:
	var zone := PackedVector2Array()
	if not prediction.has("zone_from"):
		return zone
	var body: int = prediction["body"]
	var radius: float = _gravity_model.get_body_radius(body)
	var from: float = prediction["zone_from"]
	var to: float = prediction["zone_to"]
	var columns_across: float = (to - from) * radius / WORLD_PIXEL
	if columns_across < 1.0:
		return zone
	# Columns are fixed to the ground, so they're counted from where it was at the start of time.
	var around: float = fposmod(from - prediction["spin"] * prediction["ground_time"], TAU)
	var first: int = floori(around * radius / WORLD_PIXEL)
	var step: int = maxi(ceili(columns_across / maxi(zone_points - 1, 1)), 1)
	var count: int = floori(columns_across / step) + 1
	var strip: PackedFloat32Array = _gravity_model.get_ground_strip(body, first, step, count)
	for i in range(count):
		# Each height stands for a stretch of columns, and belongs at its middle. The first and last
		# sit on the zone's ends.
		var along: float = 0.0 if i == 0 else (i * step + step / 2.0) * WORLD_PIXEL / radius
		var angle: float = minf(from + along, to)
		zone.append(Vector2(sin(angle), -cos(angle)) * (radius + strip[i * 2]))
	var last: PackedFloat32Array = _gravity_model.get_ground_strip(body, first + floori(columns_across), 1, 1)
	zone.append(Vector2(sin(to), -cos(to)) * (radius + last[0]))
	return zone


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
	_cut_coast_at_air()
	queue_redraw()


# With a forecast flown through the air ahead, the coast stops where it first reaches the landing
# zone, which is the top of the air, and the flown line carries on from there.
func _cut_coast_at_air() -> void:
	if _flown_times.is_empty() or _landing.get("body", -1) != _dominant_body:
		return
	for i in range(_screen_points.size()):
		if _entry_heights[i] < 0.0:
			var kept: PackedVector2Array = _screen_points.slice(0, i)
			if i > 0:
				kept.append(_crossing_point(i - 1, i))
			_screen_points = kept
			_landing_runs.clear()
			return


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
	# In the air, the flown line is the whole path.
	if _riding:
		return
	if _screen_points.size() >= 2:
		# A width of -1 draws a true one-pixel line, which stays on the pixel grid.
		draw_polyline(_screen_points, line_color, -1.0)
	for run: PackedVector2Array in _landing_runs:
		draw_polyline(run, landing_color, -1.0)

	if _has_encounter:
		var center := Vector2(_encounter_x * _pixels_per_unit, _encounter_y * _pixels_per_unit)
		var surface: float = _gravity_model.get_body_radius(_encounter_body) * _pixels_per_unit
		draw_arc(center, surface, 0.0, TAU, ring_points, line_color, -1.0)
