# ground_effects.gd: what the ship does to the ground near it: engine dust and its shadow.
# From DESIGN.md, "Camera, zoom, and landing". Only for looks, and it never affects the flight.
class_name GroundEffects
extends Node2D

## One world pixel of the ground, in world units.
const WORLD_PIXEL: float = 2.0
## The most dust raised per tick, flat out right on the ground.
const MOST_DUST_PER_TICK: int = 4

## The engine raises dust from this high and lower, in world units.
@export var dust_height: float = 260.0
## The engine has to point at least this much at the ground to raise dust, from 0 to 1.
@export var dust_aim: float = 0.35
## The ship casts a shadow from this high and lower, in world units.
@export var shadow_height: float = 800.0
## The farthest out the shadow still shows, as a zoom.
@export var shadow_farthest_zoom: float = 1.0 / 16.0
## How dark the shadow is.
@export var shadow_color: Color = Color(0.0, 0.0, 0.06, 0.42)
## How low the star has to sit before the shadow is gone, from 0 to 1.
@export var lowest_sun: float = 0.14

var _gravity_model: GravityModel
var _state: ShipState
var _ship: Node2D
var _sparks: SparkField
var _bodies: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _engine_share: float = 0.0
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0


## Starts watching a flight, given each body's index and its data.
func start_effects(gravity_model: GravityModel, state: ShipState, ship: Node2D, sparks: SparkField, bodies: Dictionary) -> void:
	_gravity_model = gravity_model
	_state = state
	_ship = ship
	_sparks = sparks
	_bodies = bodies
	_rng.seed = 3
	# Dust starts at the ship's moment, so this runs just after the ship does.
	process_physics_priority = 10


func _on_ship_engine_changed(share: float) -> void:
	_engine_share = share


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _gravity_model != null and _engine_share > 0.0:
		_raise_dust()


# Where the exhaust meets the ground, dust blows out both ways along it.
func _raise_dust() -> void:
	var body: int = _gravity_model.get_dominant_body(_state.x, _state.y, _state.time)
	if not _bodies.has(body):
		return
	var height: float = _gravity_model.get_altitude(_state.x, _state.y, _state.time)
	if height > dust_height:
		return
	var at: PackedFloat64Array = _gravity_model.get_body_position(body, _state.time)
	var up := Vector2(_state.x - at[0], _state.y - at[1]).normalized()
	var exhaust := Vector2(-sin(_ship.heading), cos(_ship.heading))
	var aim: float = exhaust.dot(-up)
	if aim < dust_aim:
		return

	var strength: float = _engine_share * (1.0 - height / dust_height)
	var hit_x: float = _state.x + exhaust.x * height / aim
	var hit_y: float = _state.y + exhaust.y * height / aim
	var data: BodyData = _bodies[body]
	var ground: float = _gravity_model.get_ground_height(hit_x, hit_y, _state.time)
	var out := Vector2(hit_x - at[0], hit_y - at[1]).normalized()
	var ground_x: float = at[0] + out.x * (data.radius + ground)
	var ground_y: float = at[1] + out.y * (data.radius + ground)
	var column: float = _gravity_model.get_ground_column(ground_x, ground_y, _state.time)
	var band: float = _gravity_model.get_ground_strip(body, floori(column), 1, 1)[1]
	var surface: Color = data.surface_colors[clampi(int(band), 0, 5)]
	var dirt: Color = data.strata_colors[0]

	var across := Vector2(-out.y, out.x)
	var offsets := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(ceili(strength * MOST_DUST_PER_TICK)):
		offsets.append(across * _rng.randf_range(-14.0, 14.0) + out * _rng.randf_range(1.0, 5.0))
		colors.append(surface if _rng.randf() < 0.5 else dirt)
	var moving: PackedFloat64Array = _gravity_model.get_surface_velocity(ground_x, ground_y, _state.time)
	_sparks.scatter(offsets, colors, 1, ground_x, ground_y, moving[0], moving[1], out * (20.0 + strength * 60.0), Vector2.ZERO, 60.0 + strength * 170.0, true)


# The ship's shadow lies along the ground, shifted away from the star, and thins as it climbs.
func _draw() -> void:
	if _gravity_model == null or _pixels_per_unit < shadow_farthest_zoom or not _ship.has_shape():
		return
	var body: int = _gravity_model.get_dominant_body(_state.x, _state.y, _state.time)
	if not _bodies.has(body):
		return
	var height: float = _gravity_model.get_altitude(_state.x, _state.y, _state.time)
	if height > shadow_height:
		return
	var at: PackedFloat64Array = _gravity_model.get_body_position(body, _state.time)
	var up := Vector2(_state.x - at[0], _state.y - at[1]).normalized()
	var clockwise := Vector2(-up.y, up.x)
	var to_star := Vector2(-at[0], -at[1]).normalized()
	var sun_up: float = to_star.dot(up)
	if sun_up < lowest_sun:
		return
	var shift: float = clampf(-to_star.dot(clockwise) / sun_up * height, -shadow_height, shadow_height)

	var low: float = INF
	var high: float = -INF
	for point: Vector2 in _ship.world_outline():
		var sideways: float = point.dot(clockwise)
		low = minf(low, sideways)
		high = maxf(high, sideways)

	var data: BodyData = _bodies[body]
	var step: int = maxi(ceili(1.0 / _pixels_per_unit), 1)
	var column: float = _gravity_model.get_ground_column(_state.x, _state.y, _state.time)
	var first: int = floori((column + (low + shift) / WORLD_PIXEL) / step) * step
	var count: int = ceili((high - low) / WORLD_PIXEL / step) + 1
	var strip: PackedFloat32Array = _gravity_model.get_ground_strip(body, first, step, count)
	var turned: float = data.spin_rate * _state.time
	var pixel: float = WORLD_PIXEL * step * _pixels_per_unit
	var fade: float = height / shadow_height
	var rows: int = 3 if fade < 0.5 else 2
	# Higher up the strip narrows with hard ends, keeping only its middle: all of it at first, then
	# the middle 60%, then the middle 30%.
	var kept: float = 1.0 if fade <= 0.35 else (0.6 if fade <= 0.7 else 0.3)
	for i in range(count):
		if absf((i + 0.5) / count - 0.5) > kept * 0.5:
			continue
		var at_column: int = first + i * step
		var angle: float = (at_column + step * 0.5) * WORLD_PIXEL / data.radius + turned
		var ground_r: float = data.radius + strip[i * 2]
		var place := Vector2(
				(at[0] + sin(angle) * ground_r - _center_x) * _pixels_per_unit,
				(at[1] - cos(angle) * ground_r - _center_y) * _pixels_per_unit)
		draw_set_transform(place, angle, Vector2.ONE * pixel)
		draw_rect(Rect2(-0.5, 0.0, 1.0, rows), shadow_color)
	draw_set_transform(Vector2.ZERO)
