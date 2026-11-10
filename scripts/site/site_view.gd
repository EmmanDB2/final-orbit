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

var data: SiteData
## Which body it's on, and how high its level ground is above that body's base radius.
var world: int = -1
var ground_height: float = 0.0

var _gravity_model: GravityModel
var _state: ShipState
var _radius: float = 0.0
var _spin: float = 0.0
var _roll: float = 0.0
var _outside: Array[Sprite2D] = []
var _inside: Array[Sprite2D] = []
var _show_dot: bool = false
var _dot_at := Vector2.ZERO


## Starts drawing the site, on this body, on level ground this high.
func start_site(gravity_model: GravityModel, state: ShipState, site: SiteData, world_index: int, level_height: float) -> void:
	_gravity_model = gravity_model
	_state = state
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
		inside.texture = building.interior_texture
		inside.visible = false
		# The inside sits under the outside, which fades off it.
		add_child(inside)
		add_child(outside)
		_inside.append(inside)
		_outside.append(outside)


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


## The site's middle, a little above the ground, for the camera and markers.
func middle(time: float) -> PackedFloat64Array:
	return point_at(time, 0.0, MIDDLE_HEIGHT)


## How far the site reaches from its middle, in world units.
func reach() -> float:
	return data.half_width


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
