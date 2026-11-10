# landing_label.gd: the small label at the end of the path line saying what touching down there
# means with no more burns: SAFE, HARD, CRASH, or BURN-UP, with the touchdown speed beside it.
# From DESIGN.md, "Physics" (Landing prediction) and "UI" (agency palette only, stencil text).
#
# It's drawn with the UI, not in the world, so the words stay upright and on whole pixels however
# the view is turned. The trajectory preview says where the line ends.
class_name LandingLabel
extends Node2D

## How far from the end of the line the words sit, in game pixels.
@export var offset: Vector2 = Vector2(8.0, -20.0)

var _end_point: Callable
var _text: String = ""
var _color: Color = Color.WHITE
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0
var _roll: float = 0.0


## Starts labelling the end of a line, given a way to ask where it ends in the world right now, as
## [x, y], or nothing while there's no landing to show.
func start_label(end_point: Callable) -> void:
	_end_point = end_point


func _on_ship_landing_predicted(prediction: Dictionary) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var verdict: String = prediction.get("verdict", "")
	_text = ""
	if verdict != "":
		_text = "%s %s" % [verdict, Units.speed_text(prediction["speed"])]
		match verdict:
			"SAFE":
				_color = palette.telemetry_green
			"HARD":
				_color = palette.telemetry_amber
			_:
				_color = palette.agency_red
	queue_redraw()


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit
	if _text != "":
		queue_redraw()


func _draw() -> void:
	if _text == "" or not _end_point.is_valid():
		return
	var at: PackedFloat64Array = _end_point.call()
	if at.size() < 2:
		return
	# The view's center is the middle of the whole screen, wherever the panels are.
	var view: Vector2 = get_viewport_rect().size
	var from_middle: Vector2 = Vector2((at[0] - _center_x) * _pixels_per_unit, (at[1] - _center_y) * _pixels_per_unit).rotated(-_roll)
	var on_screen: Vector2 = view / 2.0 + from_middle
	if not Rect2(Vector2.ZERO, view).has_point(on_screen):
		return
	var top_left: Vector2 = (on_screen - global_position + offset).round()
	var palette: AgencyPalette = UiStyle.palette()
	for nudge: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		UiStyle.draw_text(self, _text, top_left + nudge, palette.hull_darkest, 1)
	UiStyle.draw_text(self, _text, top_left, _color, 1)
