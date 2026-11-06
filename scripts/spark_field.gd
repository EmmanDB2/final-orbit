# spark_field.gd: single pixels blown off the ship, drawn until they die out.
# From DESIGN.md, "Destruction" (single pixels are visual particles only, and a debris budget
# caps active pieces). Nothing here affects the flight.
#
# Sparks ride in a frame that coasts on the gravity model like a chunk does, and each one only
# keeps its offset from that frame. That keeps thousands of them cheap, and accurate however
# far the world's numbers get. A frame on the ground turns with the planet, and its sparks
# fall and bounce on the ground. Elsewhere they simply drift, slowed by any air.
class_name SparkField
extends Node2D

class SparkFrame:
	var state: ShipState
	var age: float = 0.0
	var angle: float = 0.0
	var resting: bool = false
	var gravity: float = 0.0
	var air_slowing: float = 0.0
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var vxs := PackedFloat32Array()
	var vys := PackedFloat32Array()
	var left := PackedFloat32Array()
	var hot := PackedFloat32Array()
	var sizes := PackedByteArray()
	var colors := PackedColorArray()

## Most sparks at once. Past this, the oldest frame's sparks go first.
@export var spark_budget: int = 1500
## Most frames at once.
@export var frame_budget: int = 8
## A new spark joins the newest frame if it's younger than this, in seconds.
@export var frame_join_seconds: float = 0.7
## How long a spark lives, in seconds.
@export var shortest_life: float = 1.6
@export var longest_life: float = 4.5
## Share of a spark's life at the end when it flickers out.
@export var flicker_share: float = 0.35
## How many sparks in a hundred start out glowing, and for how long at most, in seconds.
@export var hot_chance: float = 0.55
@export var longest_hot: float = 0.4
## How much of its speed a spark keeps when it bounces on the ground.
@export var bounce: float = 0.35
## How strongly air slows sparks, per second, at the thickness of the home planet's ground.
@export var air_slowing: float = 0.8
## How much air slows a whole cloud moving through it. Bits are light, so it's a lot.
@export var cloud_drag: float = 0.01
## Below this zoom sparks are too small to read, so they aren't drawn.
@export var faintest_zoom: float = 1.0 / 200.0

var _gravity_model: GravityModel
var _state: ShipState
var _rng := RandomNumberGenerator.new()
var _frames: Array[SparkFrame] = []
var _total: int = 0
var _tick: int = 0
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0


func _ready() -> void:
	# Frames must step before the ship does, so both show the same moment when drawn.
	process_physics_priority = -10


## Starts watching a flight.
func start_sparks(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state
	_rng.seed = 2


func spark_count() -> int:
	return _total


## Adds sparks at these offsets from a point in the world, all moving with that point, plus a
## push of their own: away from the hit by up to blast, and along kick.
func scatter(offsets: PackedVector2Array, colors: PackedColorArray, size: int, x: float, y: float, velocity_x: float, velocity_y: float, kick: Vector2, hit_offset: Vector2, blast: float) -> void:
	if offsets.is_empty():
		return
	var frame: SparkFrame = _frame_for(x, y, velocity_x, velocity_y)
	while _total + offsets.size() > spark_budget and _frames[0] != frame:
		_drop_oldest_frame()
	var adding: int = mini(offsets.size(), spark_budget - _total)
	if adding <= 0:
		return
	var from := Vector2(x - frame.state.x, y - frame.state.y)
	var moving := Vector2(velocity_x - frame.state.velocity_x, velocity_y - frame.state.velocity_y)
	for i in range(adding):
		var at: Vector2 = offsets[i]
		var away: Vector2 = at - hit_offset
		away = away.normalized() if away.length_squared() > 0.01 else Vector2.UP.rotated(_rng.randf() * TAU)
		var scatter_way: Vector2 = Vector2.UP.rotated(_rng.randf() * TAU) * _rng.randf_range(0.0, blast * 0.3)
		var velocity: Vector2 = moving + away * blast * _rng.randf_range(0.15, 1.0) + kick * _rng.randf_range(0.1, 1.0) + scatter_way
		var place: Vector2 = (from + at).rotated(-frame.angle)
		var way: Vector2 = velocity.rotated(-frame.angle)
		frame.xs.append(place.x)
		frame.ys.append(place.y)
		frame.vxs.append(way.x)
		frame.vys.append(way.y)
		frame.left.append(_rng.randf_range(shortest_life, longest_life))
		frame.hot.append(_rng.randf_range(0.05, longest_hot) if _rng.randf() < hot_chance else 0.0)
		frame.sizes.append(size)
		frame.colors.append(colors[i])
	_total += adding


func _on_ship_pixels_scattered(offsets: PackedVector2Array, colors: PackedColorArray, size: int, x: float, y: float, velocity_x: float, velocity_y: float, kick: Vector2, hit_offset: Vector2, blast: float) -> void:
	scatter(offsets, colors, size, x, y, velocity_x, velocity_y, kick, hit_offset, blast)


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit


func _frame_for(x: float, y: float, velocity_x: float, velocity_y: float) -> SparkFrame:
	if not _frames.is_empty():
		var newest: SparkFrame = _frames[_frames.size() - 1]
		if newest.age < frame_join_seconds:
			return newest

	var frame := SparkFrame.new()
	frame.state = ShipState.new()
	frame.state.x = x
	frame.state.y = y
	frame.state.velocity_x = velocity_x
	frame.state.velocity_y = velocity_y
	frame.state.time = _state.time
	# Over the ground already, it stays exactly as high as the ship's middle, which is resting.
	var altitude: float = _gravity_model.get_altitude(x, y, _state.time)
	frame.state.ground_clearance = altitude if _state.is_on_surface() else 1.0
	frame.resting = _state.is_on_surface()
	if frame.resting:
		frame.angle = _angle_on_body(frame)
		_gravity_model.propagate(frame.state, 0.0)
	_frames.append(frame)
	while _frames.size() > frame_budget:
		_drop_oldest_frame()
	return frame


func _angle_on_body(frame: SparkFrame) -> float:
	var body: int = _gravity_model.get_dominant_body(frame.state.x, frame.state.y, frame.state.time)
	var at: PackedFloat64Array = _gravity_model.get_body_position(body, frame.state.time)
	return atan2(frame.state.x - at[0], at[1] - frame.state.y)


func _drop_oldest_frame() -> void:
	_total -= _frames[0].xs.size()
	_frames.remove_at(0)


func _physics_process(delta: float) -> void:
	if _frames.is_empty():
		return
	_tick += 1
	for i in range(_frames.size() - 1, -1, -1):
		var frame: SparkFrame = _frames[i]
		frame.age += delta
		_step_frame(frame, delta)
		_step_sparks(frame, delta)
		if frame.xs.is_empty() and frame.age > frame_join_seconds:
			_frames.remove_at(i)
	queue_redraw()


func _step_frame(frame: SparkFrame, delta: float) -> void:
	var state: ShipState = frame.state
	var density: float = _gravity_model.get_air_density(state.x, state.y, state.time)
	frame.air_slowing = density * air_slowing
	if density > 0.0 and not frame.resting:
		var air: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
		var through_x: float = state.velocity_x - air[0]
		var through_y: float = state.velocity_y - air[1]
		var speed: float = sqrt(through_x * through_x + through_y * through_y)
		if speed > 0.001:
			var change: float = minf(density * speed * speed * cloud_drag * delta, speed)
			state.velocity_x -= through_x / speed * change
			state.velocity_y -= through_y / speed * change

	_gravity_model.propagate(state, delta)
	var now_resting: bool = state.is_on_surface()
	if now_resting:
		var angle: float = _angle_on_body(frame)
		if not frame.resting:
			_turn_sparks(frame, frame.angle - angle)
		frame.angle = angle
		var pull: PackedFloat64Array = _gravity_model.get_acceleration(state.x, state.y, state.time)
		frame.gravity = sqrt(pull[0] * pull[0] + pull[1] * pull[1])
	frame.resting = now_resting


# A cloud that has just come to rest changes to the ground's axes, with no visible jump.
func _turn_sparks(frame: SparkFrame, by: float) -> void:
	for i in range(frame.xs.size()):
		var place := Vector2(frame.xs[i], frame.ys[i]).rotated(by)
		var way := Vector2(frame.vxs[i], frame.vys[i]).rotated(by)
		frame.xs[i] = place.x
		frame.ys[i] = place.y
		frame.vxs[i] = way.x
		frame.vys[i] = way.y


func _step_sparks(frame: SparkFrame, delta: float) -> void:
	var keep: float = maxf(1.0 - frame.air_slowing * delta, 0.0)
	var fall: float = frame.gravity * delta if frame.resting else 0.0
	var ground: float = frame.state.ground_clearance
	var i: int = frame.xs.size() - 1
	while i >= 0:
		frame.left[i] -= delta
		if frame.left[i] <= 0.0:
			_remove_spark(frame, i)
		else:
			frame.vxs[i] *= keep
			frame.vys[i] = frame.vys[i] * keep + fall
			frame.xs[i] += frame.vxs[i] * delta
			frame.ys[i] += frame.vys[i] * delta
			if frame.resting and frame.ys[i] > ground:
				frame.ys[i] = ground
				frame.vxs[i] *= 0.6
				frame.vys[i] = -frame.vys[i] * bounce if frame.vys[i] > 20.0 else 0.0
			frame.hot[i] -= delta
		i -= 1


func _remove_spark(frame: SparkFrame, index: int) -> void:
	var last: int = frame.xs.size() - 1
	frame.xs[index] = frame.xs[last]
	frame.ys[index] = frame.ys[last]
	frame.vxs[index] = frame.vxs[last]
	frame.vys[index] = frame.vys[last]
	frame.left[index] = frame.left[last]
	frame.hot[index] = frame.hot[last]
	frame.sizes[index] = frame.sizes[last]
	frame.colors[index] = frame.colors[last]
	frame.xs.resize(last)
	frame.ys.resize(last)
	frame.vxs.resize(last)
	frame.vys.resize(last)
	frame.left.resize(last)
	frame.hot.resize(last)
	frame.sizes.resize(last)
	frame.colors.resize(last)
	_total -= 1


func _draw() -> void:
	if _pixels_per_unit < faintest_zoom:
		return
	var palette: AgencyPalette = UiStyle.palette()
	var zoom: float = _pixels_per_unit
	var art_scale: float = minf(zoom, 1.0)
	var flicker_after: float = longest_life * flicker_share
	var view_reach: float = get_viewport_rect().size.length()
	for frame: SparkFrame in _frames:
		var origin_x: float = (frame.state.x - _center_x) * zoom
		var origin_y: float = (frame.state.y - _center_y) * zoom
		if origin_x * origin_x + origin_y * origin_y > view_reach * view_reach * 4.0:
			continue
		var turn_cos: float = cos(frame.angle)
		var turn_sin: float = sin(frame.angle)
		for i in range(frame.xs.size()):
			var left: float = frame.left[i]
			if left < flicker_after:
				var gap: int = 2 if left > flicker_after * 0.4 else 3
				if (_tick + i) % gap != 0:
					continue
			var x: float = frame.xs[i]
			var y: float = frame.ys[i]
			var pixel: float = maxf(roundf(frame.sizes[i] * art_scale), 1.0)
			var color: Color = frame.colors[i]
			var hot: float = frame.hot[i]
			if hot > 0.0:
				color = palette.thrust_white if hot > 0.2 else (palette.thrust_yellow if hot > 0.08 else palette.thrust_red)
			draw_rect(Rect2(
					roundf(origin_x + (x * turn_cos - y * turn_sin) * zoom),
					roundf(origin_y + (x * turn_sin + y * turn_cos) * zoom),
					pixel, pixel), color)
