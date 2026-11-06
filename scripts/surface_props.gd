# surface_props.gd: seeded pixel sprites standing along a body's rim, chosen by what the ground
# is: boulders, crater rims, ice, lava, and alien plants. They're placeholder shapes for now.
# From DESIGN.md, "Camera, zoom, and landing" and "Universe generation" (the same seed gives the
# same world). They're only scenery: the ship flies through them.
class_name SurfaceProps
extends Node2D

## One world pixel of the ground, in world units. Props are built from these.
const WORLD_PIXEL: float = 2.0
## Each stretch of this many columns can hold one prop.
const CELL_COLUMNS: int = 48
## How much of the day's light reaches the night side, matching planet.gdshader.
const NIGHT_SHARE := Color(0.3, 0.34, 0.48)

## Props show at this zoom and closer.
@export var farthest_zoom: float = 1.0 / 16.0
## How many props to remember before starting over.
@export var most_remembered: int = 400

var _gravity_model: GravityModel
var _state: ShipState
var _bodies: Dictionary = {}
var _remembered: Dictionary = {}
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0


## Starts drawing props, given each body's index and its data.
func start_props(gravity_model: GravityModel, state: ShipState, bodies: Dictionary) -> void:
	_gravity_model = gravity_model
	_state = state
	_bodies = bodies


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit
	visible = pixels_per_unit >= farthest_zoom
	if visible:
		queue_redraw()


## What's at one stretch of a body's rim: empty, or a prop's "kind", "column", "height", and
## "rects" as [x, y, width, height, color], in world pixels up from the ground. Always the same
## for the same stretch.
func prop_at(body: int, cell: int) -> Dictionary:
	var key: int = body * 1000000 + cell
	if _remembered.has(key):
		return _remembered[key]
	if _remembered.size() > most_remembered:
		_remembered.clear()
	var prop: Dictionary = _make_prop(body, cell)
	_remembered[key] = prop
	return prop


func _make_prop(body_index: int, cell: int) -> Dictionary:
	var data: BodyData = _bodies[body_index]
	if data.prop_kinds.size() < 3:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([data.terrain_seed, cell])
	if rng.randf() > data.prop_density:
		return {}
	var column: int = cell * CELL_COLUMNS + rng.randi_range(0, CELL_COLUMNS - 1)
	var strip: PackedFloat32Array = _gravity_model.get_ground_strip(body_index, column - 4, 1, 9)
	var band: float = strip[8 + 1]
	# Nothing grows in the sea.
	if data.sea_level > 0.0 and band < 3.0:
		return {}
	var land_share: float = (band - 3.0) / 3.0 if data.sea_level > 0.0 else band / 6.0
	var kind: String = data.prop_kinds[clampi(int(land_share * 3.0), 0, 2)]
	# It sits on the lower side, so it never hangs off the edge of a step.
	var height: float = minf(minf(strip[0], strip[8]), strip[16])
	return {
		"kind": kind,
		"column": column,
		"height": height,
		"rects": _shape(kind, data, rng),
	}


func _shape(kind: String, data: BodyData, rng: RandomNumberGenerator) -> Array:
	match kind:
		"plant":
			return _plant(data, rng)
		"ice":
			return _ice(data, rng)
		"crater":
			return _crater(data, rng)
		"lava":
			return _lava(rng)
		_:
			return _boulder(data, rng)


# A lump, lit on top and dark at the bottom.
func _boulder(data: BodyData, rng: RandomNumberGenerator) -> Array:
	var rects: Array = []
	var half: int = rng.randi_range(2, 5)
	var tall: float = half * rng.randf_range(0.8, 1.5)
	var light: Color = data.strata_colors[0].lerp(data.surface_colors[5], 0.25)
	var dark: Color = data.strata_colors[1]
	for x in range(-half, half + 1):
		var share: float = float(x) / (half + 1)
		var height: int = maxi(roundi(tall * sqrt(1.0 - share * share)), 1)
		rects.append([x, 0, 1, height, dark])
		if height > 1:
			rects.append([x, ceili(height * 0.5), 1, height - ceili(height * 0.5), light])
	return rects


# A stem with fronds, in the land's and the shallows' colors, since nothing here need be green.
func _plant(data: BodyData, rng: RandomNumberGenerator) -> Array:
	var rects: Array = []
	var tall: int = rng.randi_range(3, 9)
	var stem: Color = data.surface_colors[3].darkened(0.3)
	var leaf: Color = data.surface_colors[2].lerp(data.surface_colors[3], 0.35).lightened(0.15)
	rects.append([0, 0, 1, tall, stem])
	var leaves: int = rng.randi_range(2, 4)
	for i in range(leaves):
		var at: int = tall - 1 - i * 2
		if at < 1:
			break
		var wide: int = rng.randi_range(1, 3)
		rects.append([-wide, at, wide, 1, leaf])
		rects.append([1, at, wide, 1, leaf])
		rects.append([-wide, at - 1, 1, 1, leaf])
		rects.append([wide, at - 1, 1, 1, leaf])
	return rects


# A shard, narrowing as it rises, lighter on one side.
func _ice(data: BodyData, rng: RandomNumberGenerator) -> Array:
	var rects: Array = []
	var half: int = rng.randi_range(1, 3)
	var tall: int = rng.randi_range(4, 11)
	var light: Color = data.surface_colors[5]
	var dark: Color = data.surface_colors[5].lerp(data.air_color, 0.45)
	for y in range(tall):
		var wide: int = roundi(half * (1.0 - float(y) / tall))
		rects.append([-wide, y, wide, 1, dark])
		rects.append([0, y, wide + 1, 1, light])
	return rects


# A low raised ring, seen from the side: two mounds with a dark floor between them.
func _crater(data: BodyData, rng: RandomNumberGenerator) -> Array:
	var rects: Array = []
	var half: int = rng.randi_range(4, 9)
	var rim: Color = data.strata_colors[0].lightened(0.15)
	var floor_color: Color = data.strata_colors[2]
	for x in range(-half, half + 1):
		var from_rim: int = absi(absi(x) - half)
		if from_rim <= 2:
			rects.append([x, 0, 1, 3 - from_rim, rim])
		else:
			rects.append([x, 0, 1, 1, floor_color])
	return rects


# A pool that glows, and a little spit of fire above it.
func _lava(rng: RandomNumberGenerator) -> Array:
	var rects: Array = []
	var half: int = rng.randi_range(3, 8)
	var hot := Color(0.98, 0.72, 0.28)
	var warm := Color(0.93, 0.4, 0.14)
	for x in range(-half, half + 1):
		rects.append([x, 0, 1, 1, warm if absi(x) > half / 2 else hot])
	rects.append([rng.randi_range(-half / 2, half / 2), 1, 1, rng.randi_range(1, 2), hot])
	return rects


func _draw() -> void:
	if _gravity_model == null:
		return
	var body: int = _gravity_model.get_dominant_body(_center_x, _center_y, _state.time)
	if not _bodies.has(body):
		return
	var data: BodyData = _bodies[body]
	var at: PackedFloat64Array = _gravity_model.get_body_position(body, _state.time)
	var radius: float = data.radius
	var turned: float = data.spin_rate * _state.time
	var from_x: float = _center_x - at[0]
	var from_y: float = _center_y - at[1]
	var distance: float = sqrt(from_x * from_x + from_y * from_y)
	var highest: float = _gravity_model.get_highest_ground(body)
	var reach_px: float = get_viewport_rect().size.length() / 2.0
	# Too high up to see the ground from here.
	if (distance - radius - highest) * _pixels_per_unit > reach_px:
		return

	modulate = _daylight(from_x / distance, from_y / distance, at)
	var column: float = _gravity_model.get_ground_column(_center_x, _center_y, _state.time)
	var span: int = ceili(reach_px / _pixels_per_unit / WORLD_PIXEL / CELL_COLUMNS) + 1
	var cell: int = floori(column / CELL_COLUMNS)
	var cells_around: int = ceili(TAU * radius / WORLD_PIXEL / CELL_COLUMNS)
	var pixel: float = WORLD_PIXEL * _pixels_per_unit
	for near in range(cell - span, cell + span + 1):
		var wrapped: int = posmod(near, cells_around)
		var prop: Dictionary = prop_at(body, wrapped)
		if prop.is_empty():
			continue
		var angle: float = (prop["column"] + 0.5) * WORLD_PIXEL / radius + turned
		var ground_r: float = radius + prop["height"]
		var place := Vector2(
				(at[0] + sin(angle) * ground_r - _center_x) * _pixels_per_unit,
				(at[1] - cos(angle) * ground_r - _center_y) * _pixels_per_unit)
		draw_set_transform(place, angle, Vector2.ONE * pixel)
		for rect: Array in prop["rects"]:
			draw_rect(Rect2(rect[0], -rect[1] - rect[3], rect[2], rect[3]), rect[4])
	draw_set_transform(Vector2.ZERO)


# The same flat steps of daylight the ground gets where it's in view.
func _daylight(out_x: float, out_y: float, at: PackedFloat64Array) -> Color:
	var to_star := Vector2(-at[0], -at[1]).normalized()
	var sun: float = (out_x * to_star.x + out_y * to_star.y) * 0.876
	var steps: float = clampf(floorf(clampf(sun * 1.25 + 0.2, 0.0, 1.0) * 2.0), 0.0, 2.0) / 2.0
	return NIGHT_SHARE.lerp(Color.WHITE, steps)
