# site_view.gd: draws a place built on a world, its buildings standing on the level ground the
# physics core made for it and turning with the world, in the same daylight as the ground. From far
# out it's a dot on the rim. It also says where the site is, for the camera, markers, and card.
# From DESIGN.md, "Places on worlds".
class_name SiteView
extends Node2D

## One column of a world's rim, in world units.
const WORLD_PIXEL: float = 2.0
## How far above the ground the site's middle is, for the camera and markers, in world units.
const MIDDLE_HEIGHT: float = 120.0

## Below this zoom the buildings would be too small to make out, so the site is a dot.
@export var dot_max_zoom: float = 1.0 / 48.0
## How far past the site's reach the ship has to be before it's checked against the buildings, how
## far apart the points round its outline are, and the farthest a hit pushes it out, in world units.
@export var ship_reach: float = 260.0
@export var contact_spacing: float = 4.0
@export var most_push: float = 64.0

var data: SiteData
## Which body it's on, and how high its level ground is above that body's base radius.
var world: int = -1
var ground_height: float = 0.0

var _gravity_model: GravityModel
var _state: ShipState
var _ship: Node2D
# Each building's art, for what's solid.
var _pictures: Array[Image] = []
var _radius: float = 0.0
var _spin: float = 0.0
var _roll: float = 0.0
var _outside: Array[Sprite2D] = []
var _inside: Array[Sprite2D] = []
var _show_dot: bool = false
var _dot_at := Vector2.ZERO
# For each building, how far its front wall has faded off, and where it's heading.
var _wall_gone: Array[float] = []
var _wall_wanted: Array[float] = []

## How fast a front wall fades off or back, in shares per second.
@export var wall_fade_speed: float = 3.0


## Starts drawing the site, on this body, on level ground this high, solid to the ship.
func start_site(gravity_model: GravityModel, state: ShipState, site: SiteData, world_index: int, level_height: float, ship: Node2D) -> void:
	_gravity_model = gravity_model
	_state = state
	_ship = ship
	# Before the ship's tick, so a hit changes the move it's about to make.
	process_physics_priority = -5
	data = site
	world = world_index
	ground_height = level_height
	_radius = gravity_model.get_body_radius(world_index)
	_spin = site.world.spin_rate
	for building: SiteBuilding in site.buildings:
		var inside := Sprite2D.new()
		var outside := Sprite2D.new()
		for sprite: Sprite2D in [inside, outside]:
			sprite.centered = false
			sprite.offset = Vector2(-building.texture.get_width() / 2.0, building.sink - building.texture.get_height())
		outside.texture = building.texture
		var picture: Image = building.texture.get_image()
		picture.convert(Image.FORMAT_RGBA8)
		_pictures.append(picture)
		inside.texture = building.interior_texture
		inside.visible = false
		# The inside sits under the outside, which fades off it.
		add_child(inside)
		add_child(outside)
		_inside.append(inside)
		_outside.append(outside)
		_wall_gone.append(0.0)
		_wall_wanted.append(0.0)


## The angle round the world, clockwise from straight up, of a point this far along the ground from
## the site's middle.
func angle_at(time: float, along: float = 0.0) -> float:
	return ((data.column + 0.5) * WORLD_PIXEL + along) / _radius + _spin * time


## A point this far along the ground from the site's middle and this high above its level ground.
func point_at(time: float, along: float = 0.0, up: float = 0.0) -> PackedFloat64Array:
	var at: PackedFloat64Array = _gravity_model.get_body_position(world, time)
	var angle: float = angle_at(time, along)
	var reach: float = _radius + ground_height + up
	return PackedFloat64Array([at[0] + sin(angle) * reach, at[1] - cos(angle) * reach])


## How far along the ground a point is from the site's middle, clockwise, in world units.
func along_of(x: float, y: float, time: float) -> float:
	var at: PackedFloat64Array = _gravity_model.get_body_position(world, time)
	var angle: float = atan2(x - at[0], at[1] - y)
	return angle_difference(angle_at(time), angle) * _radius


## Where a point on a building's art is in the world, with its art standing on the ground.
func building_point(time: float, index: int, on_art: Vector2, up: float = 0.0) -> PackedFloat64Array:
	var building: SiteBuilding = data.buildings[index]
	var size: Vector2 = building.texture.get_size()
	return point_at(time, building.offset + on_art.x - size.x / 2.0, size.y - building.sink - on_art.y + up)


## Where along a building's art a point along the ground is, in art pixels from its left edge.
func art_x(index: int, along: float) -> float:
	var building: SiteBuilding = data.buildings[index]
	return along - building.offset + building.texture.get_width() / 2.0


## Fades a building's front wall off to show its inside, or back on.
func set_inside(index: int, inside: bool) -> void:
	_wall_wanted[index] = 1.0 if inside else 0.0


func _process(delta: float) -> void:
	for i in range(_wall_gone.size()):
		if _wall_gone[i] != _wall_wanted[i]:
			_wall_gone[i] = move_toward(_wall_gone[i], _wall_wanted[i], wall_fade_speed * delta)
			_outside[i].modulate.a = 1.0 - _wall_gone[i]
			_inside[i].visible = _wall_gone[i] > 0.0 and _inside[i].texture != null


## The site's middle, a little above the ground, for the camera and markers.
func middle(time: float) -> PackedFloat64Array:
	return point_at(time, 0.0, MIDDLE_HEIGHT)


## How far the site reaches from its middle, in world units.
func reach() -> float:
	return data.half_width


func _physics_process(_delta: float) -> void:
	if _gravity_model == null or not _ship.has_shape() or _ship.docked:
		return
	var middle_at: PackedFloat64Array = point_at(_state.time)
	if Vector2(_state.x - middle_at[0], _state.y - middle_at[1]).length() > reach() + ship_reach:
		return
	for i in range(data.buildings.size()):
		_touch_ship(i)


# The buildings are solid to the ship, like the station: it bounces off what it touches, and takes
# damage above its safe speed. The pilot isn't stopped by them: they walk in front, along the ground.
func _touch_ship(index: int) -> void:
	var building: SiteBuilding = data.buildings[index]
	var time: float = _state.time
	var origin: PackedFloat64Array = point_at(time, building.offset)
	var angle: float = angle_at(time, building.offset)
	var to_ship := Vector2(_state.x - origin[0], _state.y - origin[1])
	var points: PackedVector2Array = _ship.world_outline_samples(contact_spacing)
	var contact := Vector2.ZERO
	var touching: int = 0
	for point: Vector2 in points:
		if _is_solid(index, (to_ship + point).rotated(-angle)):
			contact += point
			touching += 1
	if touching == 0:
		return
	contact /= touching
	var normal: Vector2 = _normal_at(index, (to_ship + contact).rotated(-angle)).rotated(angle)
	if normal == Vector2.ZERO:
		normal = Vector2.UP.rotated(angle)
	var push: float = 1.0
	while push < most_push and _any_solid(index, points, to_ship + normal * push, angle):
		push += 1.0
	var hit_at: Vector2 = to_ship + contact
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(origin[0] + hit_at.x, origin[1] + hit_at.y, time)
	_ship.hit_solid(contact, normal, push, ground[0], ground[1], "BUILDING")


# Whether a point, measured from where a building stands on the ground and turned upright with it,
# is solid: on its art, in its solid part, and above the ground.
func _is_solid(index: int, local: Vector2) -> bool:
	var building: SiteBuilding = data.buildings[index]
	var picture: Image = _pictures[index]
	var on_art: Vector2 = local + Vector2(picture.get_width() / 2.0, picture.get_height() - building.sink)
	if local.y > 0.0 or (building.solid_box.has_area() and not building.solid_box.has_point(on_art)):
		return false
	var x: int = floori(on_art.x)
	var y: int = floori(on_art.y)
	if x < 0 or y < 0 or x >= picture.get_width() or y >= picture.get_height():
		return false
	return picture.get_pixel(x, y).a > 0.5


func _any_solid(index: int, points: PackedVector2Array, shift: Vector2, angle: float) -> bool:
	for point: Vector2 in points:
		if _is_solid(index, (shift + point).rotated(-angle)):
			return true
	return false


# Which way is out of the solid near a point, from where the empty space round it lies.
func _normal_at(index: int, local: Vector2, around: int = 8) -> Vector2:
	var total := Vector2.ZERO
	for dy in range(-around, around + 1):
		for dx in range(-around, around + 1):
			if dx * dx + dy * dy <= around * around and not _is_solid(index, local + Vector2(dx, dy)):
				total += Vector2(dx, dy)
	return total.normalized()


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	if _gravity_model == null:
		return
	var time: float = _state.time
	var show_dot: bool = pixels_per_unit <= dot_max_zoom
	for i in range(data.buildings.size()):
		var building: SiteBuilding = data.buildings[i]
		var at: PackedFloat64Array = point_at(time, building.offset)
		# Whole pixels on screen, however the view is turned, so it doesn't shimmer as it crawls.
		var from_middle := Vector2((at[0] - center_x) * pixels_per_unit, (at[1] - center_y) * pixels_per_unit)
		var place: Vector2 = from_middle.rotated(-_roll).round().rotated(_roll)
		for sprite: Sprite2D in [_outside[i], _inside[i]]:
			sprite.position = place
			sprite.rotation = angle_at(time, building.offset)
			sprite.scale = Vector2.ONE * pixels_per_unit
		_outside[i].visible = not show_dot
	var body_at: PackedFloat64Array = _gravity_model.get_body_position(world, time)
	var middle_at: PackedFloat64Array = middle(time)
	modulate = SurfaceProps.daylight(middle_at[0] - body_at[0], middle_at[1] - body_at[1], body_at)
	_dot_at = Vector2((middle_at[0] - center_x) * pixels_per_unit, (middle_at[1] - center_y) * pixels_per_unit)
	if show_dot or show_dot != _show_dot:
		_show_dot = show_dot
		queue_redraw()


func _draw() -> void:
	if not _show_dot:
		return
	var palette: AgencyPalette = UiStyle.palette()
	draw_rect(Rect2(_dot_at - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), palette.hull_darkest)
	draw_rect(Rect2(_dot_at - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), palette.agency_orange)
