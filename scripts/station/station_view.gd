# station_view.gd: draws a station where its rails put it, at true scale. Farther out it's a marker
# dot, since it would be too small to make out. It holds still rather than turning. Its pixels are
# solid: the ship bounces off them, and can't hurt them for now.
# From DESIGN.md, "Universe generation" (stations are hubs) and "Camera, zoom, and landing".
class_name StationView
extends Node2D

## The station shows as a dot at this zoom and farther.
@export var dot_max_zoom: float = 1.0 / 256.0
## How far apart to check the ship's outline against the station, in world units.
@export var contact_spacing: float = 4.0
## The most the ship gets pushed out of the station in one tick, in world units.
@export var most_push: float = 64.0
## How far the ship's outline can reach from its center, in world units, plus some room.
@export var ship_reach: float = 180.0

var _gravity_model: GravityModel
var _state: ShipState
var _design: StationDesign
var _index: int = 0
var _sprite := Sprite2D.new()
var _show_dot: bool = false
var _ship: Node2D
var _contact_range: float = 0.0
var layout: StationLayout


## Starts drawing a station, given its satellite number in the gravity model.
func start_station(gravity_model: GravityModel, state: ShipState, design: StationDesign, index: int, ship: Node2D) -> void:
	_gravity_model = gravity_model
	_state = state
	_design = design
	_index = index
	_ship = ship
	layout = StationLayout.build(design)
	# Before the ship's tick, so a hit changes the move it's about to make.
	process_physics_priority = -5
	var far_corner := Vector2(layout.origin).max(Vector2(layout.image.get_size() - layout.origin))
	_contact_range = far_corner.length() * design.art_pixel_size + ship_reach
	_sprite.texture = ImageTexture.create_from_image(layout.image)
	_sprite.centered = false
	_sprite.offset = -Vector2(layout.origin)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if _gravity_model == null or not _ship.has_shape():
		return
	var at: PackedFloat64Array = _gravity_model.get_satellite_position(_index, _state.time)
	var to_ship := Vector2(_state.x - at[0], _state.y - at[1])
	if to_ship.length_squared() > _contact_range * _contact_range:
		return
	var points: PackedVector2Array = _ship.world_outline_samples(contact_spacing)
	var contact := Vector2.ZERO
	var touching: int = 0
	for point: Vector2 in points:
		if _is_solid(to_ship + point):
			contact += point
			touching += 1
	if touching == 0:
		return
	contact /= touching
	var normal: Vector2 = layout.normal_at(_on_picture(to_ship + contact))
	if normal == Vector2.ZERO:
		normal = to_ship.normalized()
	var push: float = 1.0
	while push < most_push and _any_solid(points, to_ship + normal * push):
		push += 1.0
	var moving: PackedFloat64Array = _gravity_model.get_satellite_velocity(_index, _state.time)
	_ship.hit_solid(contact, normal, push, moving[0], moving[1])


# Where an offset from the station's middle in the world falls on its picture.
func _on_picture(offset: Vector2) -> Vector2:
	return offset / _design.art_pixel_size + Vector2(layout.origin)


func _is_solid(offset: Vector2) -> bool:
	return layout.is_solid(_on_picture(offset))


func _any_solid(points: PackedVector2Array, shift: Vector2) -> bool:
	for point: Vector2 in points:
		if _is_solid(shift + point):
			return true
	return false


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	if _gravity_model == null:
		return
	var at: PackedFloat64Array = _gravity_model.get_satellite_position(_index, _state.time)
	# Whole pixels only, so it doesn't shimmer as it crawls across the grid.
	position = Vector2((at[0] - center_x) * pixels_per_unit, (at[1] - center_y) * pixels_per_unit).round()
	var show_dot: bool = pixels_per_unit <= dot_max_zoom
	_sprite.visible = not show_dot
	_sprite.scale = Vector2.ONE * _design.art_pixel_size * pixels_per_unit
	if show_dot != _show_dot:
		_show_dot = show_dot
		queue_redraw()


func _draw() -> void:
	if _show_dot:
		var palette: AgencyPalette = UiStyle.palette()
		draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), palette.hull_darkest)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), palette.agency_orange)
