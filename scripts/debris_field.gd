# debris_field.gd: everything that's come off the ship: chunks with their own orbits, and
# single pixels as short-lived sparks.
# From DESIGN.md, "Destruction" (detached chunks become physics bodies with their own orbits,
# single pixels are visual particles only, and a debris budget caps active pieces).
#
# Chunks coast on the gravity model like the ship does, feel the air, and can hit the ship,
# which does damage from both their masses and the speed. Sparks only ever get drawn.
class_name DebrisField
extends Node2D

## Most chunks in flight. Past this, the oldest small one goes.
@export var chunk_budget: int = 12
## Most sparks at once.
@export var spark_budget: int = 240
## A piece with fewer pixels than this is just sparks.
@export var smallest_chunk: int = 30
## A chunk with fewer pixels than this fades after small_chunk_seconds, and can burn up.
@export var small_chunk: int = 200
@export var small_chunk_seconds: float = 30.0
## How long a chunk stays after coming to rest on the ground, in seconds.
@export var landed_seconds: float = 60.0
## How long a new chunk can't hit the ship, so it can get clear first, in seconds.
@export var clear_seconds: float = 1.5
## How much a hit's speed survives as a bounce, from 0 to 1.
@export var bounce: float = 0.2
## Energy it takes to destroy each pixel of a chunk, in joules.
@export var chunk_strength: float = 500000.0
## How far from its middle the ship can have a pixel, for a quick check before a close look.
@export var ship_reach: float = 130.0

var _gravity_model: GravityModel
var _state: ShipState
var _ship: Node2D
var _rng := RandomNumberGenerator.new()
var _chunks: Array[Dictionary] = []
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0
# Sparks, side by side in these arrays. Positions and speeds are relative to a body.
var _spark_body := PackedInt32Array()
var _spark_x := PackedFloat64Array()
var _spark_y := PackedFloat64Array()
var _spark_vx := PackedFloat64Array()
var _spark_vy := PackedFloat64Array()
var _spark_life := PackedFloat64Array()
var _spark_color := PackedColorArray()


## Starts watching a flight.
func start_debris(gravity_model: GravityModel, state: ShipState, ship: Node2D) -> void:
	_gravity_model = gravity_model
	_state = state
	_ship = ship
	_rng.seed = 1


func chunk_count() -> int:
	return _chunks.size()


func spark_count() -> int:
	return _spark_life.size()


func _on_ship_part_detached(piece: Dictionary, x: float, y: float, velocity_x: float, velocity_y: float, angle: float, spin: float, kick: Vector2) -> void:
	if piece["pixel_count"] < smallest_chunk:
		var offsets := PackedVector2Array()
		for point: Vector2 in piece["points"]:
			offsets.append((point - piece["center"]).rotated(angle))
		_on_ship_pixels_scattered(offsets, piece["colors"], x, y, velocity_x, velocity_y, kick)
		return

	var away: Vector2 = Vector2.UP.rotated(_rng.randf() * TAU) * _rng.randf_range(5.0, 25.0)
	var state := ShipState.new()
	state.x = x
	state.y = y
	state.velocity_x = velocity_x + kick.x + away.x
	state.velocity_y = velocity_y + kick.y + away.y
	state.time = _state.time

	var image: Image = piece["image"]
	state.ground_clearance = maxf(image.get_width(), image.get_height()) / 2.0
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.rotation = angle
	sprite.scale = Vector2.ONE * minf(_pixels_per_unit, 1.0)
	add_child(sprite)

	# Only a sample of its pixels is needed to tell whether it's touching the ship.
	var points := PackedVector2Array()
	var all_points: PackedVector2Array = piece["points"]
	var step: int = maxi(all_points.size() / 48, 1)
	for i in range(0, all_points.size(), step):
		points.append(all_points[i] - piece["center"])

	_chunks.append({
		"state": state,
		"sprite": sprite,
		"angle": angle,
		"spin": spin + _rng.randf_range(-0.8, 0.8),
		"mass": piece["mass"],
		"pixels": piece["pixel_count"],
		"radius": image.get_size().length() / 2.0,
		"width": float(image.get_width()),
		"points": points,
		"age": 0.0,
		"landed": 0.0,
	})
	_place_chunk(_chunks[_chunks.size() - 1])
	_keep_to_budget()


func _on_ship_pixels_scattered(offsets: PackedVector2Array, colors: PackedColorArray, x: float, y: float, velocity_x: float, velocity_y: float, kick: Vector2) -> void:
	var body: int = _gravity_model.get_dominant_body(x, y, _state.time)
	var at: PackedFloat64Array = _gravity_model.get_body_position(body, _state.time)
	var moving: PackedFloat64Array = _gravity_model.get_body_velocity(body, _state.time)
	var step: int = maxi(offsets.size() / 80, 1)
	for i in range(0, offsets.size(), step):
		if _spark_life.size() >= spark_budget:
			_remove_spark(0)
		var away: Vector2 = Vector2.UP.rotated(_rng.randf() * TAU) * _rng.randf_range(10.0, 90.0)
		_spark_body.append(body)
		_spark_x.append(x - at[0] + offsets[i].x)
		_spark_y.append(y - at[1] + offsets[i].y)
		_spark_vx.append(velocity_x - moving[0] + kick.x + away.x)
		_spark_vy.append(velocity_y - moving[1] + kick.y + away.y)
		_spark_life.append(_rng.randf_range(0.4, 1.4))
		_spark_color.append(colors[i])


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit
	for chunk: Dictionary in _chunks:
		_place_chunk(chunk)


func _place_chunk(chunk: Dictionary) -> void:
	var state: ShipState = chunk["state"]
	var sprite: Sprite2D = chunk["sprite"]
	sprite.position = Vector2(
			(state.x - _center_x) * _pixels_per_unit,
			(state.y - _center_y) * _pixels_per_unit).round()
	sprite.scale = Vector2.ONE * minf(_pixels_per_unit, 1.0)


func _physics_process(delta: float) -> void:
	for i in range(_chunks.size() - 1, -1, -1):
		var chunk: Dictionary = _chunks[i]
		chunk["age"] += delta
		var burned_up: bool = _push_through_air(chunk, delta)
		var state: ShipState = chunk["state"]
		_gravity_model.propagate(state, delta)
		if state.is_on_surface():
			chunk["spin"] = 0.0
			chunk["landed"] += delta
		else:
			chunk["angle"] += chunk["spin"] * delta
		(chunk["sprite"] as Sprite2D).rotation = chunk["angle"]

		var too_old: bool = chunk["pixels"] < small_chunk and chunk["age"] > small_chunk_seconds
		if burned_up or too_old or chunk["landed"] > landed_seconds or _hits_ship(chunk):
			_remove_chunk(i)


# Slows a chunk in the air. Returns true if it's small and hot enough to burn up.
func _push_through_air(chunk: Dictionary, delta: float) -> bool:
	var state: ShipState = chunk["state"]
	if state.is_on_surface():
		return false
	var density: float = _gravity_model.get_air_density(state.x, state.y, state.time)
	if density <= 0.0:
		return false
	var air: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var through_x: float = state.velocity_x - air[0]
	var through_y: float = state.velocity_y - air[1]
	var speed: float = sqrt(through_x * through_x + through_y * through_y)
	if speed < 0.001:
		return false
	var slowing: float = 0.5 * density * speed * speed * chunk["width"] / chunk["mass"]
	var change: float = minf(slowing * delta, speed)
	state.velocity_x -= through_x / speed * change
	state.velocity_y -= through_y / speed * change
	var heat: float = sqrt(density) * speed * speed * speed / _ship.design.heat_limit
	return heat >= 1.0 and chunk["pixels"] < small_chunk


# Checks a chunk against the ship's pixels. Returns true if the hit destroyed the chunk.
func _hits_ship(chunk: Dictionary) -> bool:
	if chunk["age"] < clear_seconds:
		return false
	var state: ShipState = chunk["state"]
	var dx: float = state.x - _state.x
	var dy: float = state.y - _state.y
	var close: float = ship_reach + chunk["radius"]
	if dx * dx + dy * dy > close * close:
		return false
	var relative_x: float = state.velocity_x - _state.velocity_x
	var relative_y: float = state.velocity_y - _state.velocity_y
	if dx * relative_x + dy * relative_y >= 0.0:
		return false

	var from_ship := Vector2(dx, dy)
	for point: Vector2 in chunk["points"]:
		var touching: Vector2 = from_ship + point.rotated(chunk["angle"])
		if _ship.has_pixel_at(touching):
			return _collide(chunk, touching, relative_x, relative_y)
	return false


# Both masses and the speed set the energy, and both get pushed apart.
func _collide(chunk: Dictionary, touching: Vector2, relative_x: float, relative_y: float) -> bool:
	var chunk_mass: float = chunk["mass"]
	var ship_mass: float = _ship.current_mass()
	var shared_mass: float = chunk_mass * ship_mass / (chunk_mass + ship_mass)
	var speed_squared: float = relative_x * relative_x + relative_y * relative_y
	var safe: float = _ship.design.safe_impact_speed
	var energy: float = 0.5 * shared_mass * maxf(speed_squared - safe * safe, 0.0)

	var state: ShipState = chunk["state"]
	var push: float = (1.0 + bounce) * shared_mass
	state.velocity_x -= relative_x * push / chunk_mass
	state.velocity_y -= relative_y * push / chunk_mass
	_state.velocity_x += relative_x * push / ship_mass
	_state.velocity_y += relative_y * push / ship_mass
	_ship.orbit_changed.emit()
	if energy > 0.0:
		_ship.take_hit(touching, energy)
	chunk["age"] = 0.0
	return energy >= chunk["pixels"] * chunk_strength


func _keep_to_budget() -> void:
	while _chunks.size() > chunk_budget:
		var smallest: int = 0
		for i in range(_chunks.size()):
			if _chunks[i]["pixels"] < _chunks[smallest]["pixels"]:
				smallest = i
		_remove_chunk(smallest)


func _remove_chunk(index: int) -> void:
	(_chunks[index]["sprite"] as Sprite2D).queue_free()
	_chunks.remove_at(index)


func _remove_spark(index: int) -> void:
	_spark_body.remove_at(index)
	_spark_x.remove_at(index)
	_spark_y.remove_at(index)
	_spark_vx.remove_at(index)
	_spark_vy.remove_at(index)
	_spark_life.remove_at(index)
	_spark_color.remove_at(index)


func _process(delta: float) -> void:
	if _spark_life.is_empty():
		return
	for i in range(_spark_life.size() - 1, -1, -1):
		_spark_life[i] -= delta
		if _spark_life[i] <= 0.0:
			_remove_spark(i)
		else:
			_spark_x[i] += _spark_vx[i] * delta
			_spark_y[i] += _spark_vy[i] * delta
	queue_redraw()


func _draw() -> void:
	for i in range(_spark_life.size()):
		var at: PackedFloat64Array = _gravity_model.get_body_position(_spark_body[i], _state.time)
		var spot := Vector2(
				(at[0] + _spark_x[i] - _center_x) * _pixels_per_unit,
				(at[1] + _spark_y[i] - _center_y) * _pixels_per_unit).round()
		draw_rect(Rect2(spot, Vector2.ONE), _spark_color[i])
