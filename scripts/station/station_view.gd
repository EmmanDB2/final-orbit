# station_view.gd: draws a station where its rails put it, at true scale. Farther out it's a marker
# dot, since it would be too small to make out. It holds still rather than turning.
# From DESIGN.md, "Universe generation" (stations are hubs) and "Camera, zoom, and landing".
class_name StationView
extends Node2D

## The station shows as a dot at this zoom and farther.
@export var dot_max_zoom: float = 1.0 / 256.0

var _gravity_model: GravityModel
var _state: ShipState
var _design: StationDesign
var _index: int = 0
var _sprite := Sprite2D.new()
var _show_dot: bool = false
var layout: StationLayout


## Starts drawing a station, given its satellite number in the gravity model.
func start_station(gravity_model: GravityModel, state: ShipState, design: StationDesign, index: int) -> void:
	_gravity_model = gravity_model
	_state = state
	_design = design
	_index = index
	layout = StationLayout.build(design)
	_sprite.texture = ImageTexture.create_from_image(layout.image)
	_sprite.centered = false
	_sprite.offset = -Vector2(layout.origin)
	add_child(_sprite)


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
