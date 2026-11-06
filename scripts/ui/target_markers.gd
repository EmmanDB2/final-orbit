# target_markers.gd: small agency-orange arrows at the screen edge for targets that are off screen,
# each with its callsign and distance. Zoomed out far enough that a target's only a dot, the label
# goes beside the dot instead.
# From DESIGN.md, "UI" (edge markers).
class_name TargetMarkers
extends Node2D

## How far inside the clear part of the view the arrows stay.
@export var edge_margin: float = 8.0
## How long an arrow is, tip to tail.
@export var arrow_length: float = 10.0
## At this zoom and farther, an on-screen target gets a label too.
@export var label_zoom: float = 1.0 / 256.0

var _gravity_model: GravityModel
var _state: ShipState
var _targets: Array[Dictionary] = []
var _clear_area := Rect2()
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0


## Starts following a flight.
func start_markers(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state


## Adds a marker for a satellite, given its number in the gravity model.
func add_satellite_target(callsign: String, index: int) -> void:
	_targets.append({"callsign": callsign, "index": index})


func _on_clear_area_changed(area: Rect2) -> void:
	_clear_area = area
	queue_redraw()


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit
	queue_redraw()


func _draw() -> void:
	if _gravity_model == null or _clear_area.size.x <= edge_margin * 2.0 or _clear_area.size.y <= edge_margin * 2.0:
		return
	# The view's center is the middle of the whole screen, wherever the panels are.
	var middle: Vector2 = get_viewport_rect().size / 2.0 - global_position
	var area: Rect2 = _clear_area.grow(-edge_margin)
	for target: Dictionary in _targets:
		var at: PackedFloat64Array = _gravity_model.get_satellite_position(target["index"], _state.time)
		var offset := Vector2((at[0] - _center_x) * _pixels_per_unit, (at[1] - _center_y) * _pixels_per_unit)
		var away := Vector2(at[0] - _state.x, at[1] - _state.y)
		var text: String = "%s %s" % [target["callsign"], UiStyle.distance_text(away.length())]
		var spot: Vector2 = middle + offset
		if area.has_point(spot):
			if _pixels_per_unit <= label_zoom:
				_draw_label(text, spot + Vector2(7.0, -3.0), area)
			continue
		var direction: Vector2 = offset.normalized()
		var tip: Vector2 = _edge_point(middle, direction, area)
		_draw_arrow(tip, direction)
		# Far enough back along the arrow to clear it, however wide the words are that way.
		var half_width: float = UiStyle.text_width(text, 1) / 2.0
		var clearance: float = absf(direction.x) * half_width + absf(direction.y) * 4.0 + 4.0
		var label_middle: Vector2 = tip - direction * (arrow_length + clearance)
		_draw_label(text, label_middle - Vector2(half_width, 3.0), area)


# Where a line from the middle of the view leaves the clear area.
func _edge_point(middle: Vector2, direction: Vector2, area: Rect2) -> Vector2:
	var reach: float = INF
	if direction.x > 0.0:
		reach = minf(reach, (area.end.x - middle.x) / direction.x)
	elif direction.x < 0.0:
		reach = minf(reach, (area.position.x - middle.x) / direction.x)
	if direction.y > 0.0:
		reach = minf(reach, (area.end.y - middle.y) / direction.y)
	elif direction.y < 0.0:
		reach = minf(reach, (area.position.y - middle.y) / direction.y)
	return (middle + direction * maxf(reach, 0.0)).round()


func _draw_arrow(tip: Vector2, direction: Vector2) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var side: Vector2 = direction.orthogonal()
	var back: Vector2 = tip - direction * arrow_length
	var half_width: float = arrow_length * 0.45
	# The 1 px dark outline all human-made things get.
	draw_colored_polygon(PackedVector2Array([
		tip + direction * 2.0, back + side * (half_width + 2.0) - direction, back - side * (half_width + 2.0) - direction,
	]), palette.hull_darkest)
	draw_colored_polygon(PackedVector2Array([tip, back + side * half_width, back - side * half_width]), palette.agency_orange)


func _draw_label(text: String, top_left: Vector2, area: Rect2) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var width: float = UiStyle.text_width(text, 1)
	var at: Vector2 = Vector2(
			clampf(top_left.x, area.position.x, maxf(area.end.x - width, area.position.x)),
			clampf(top_left.y, area.position.y, maxf(area.end.y - 7.0, area.position.y))).round()
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		UiStyle.draw_text(self, text, at + offset, palette.hull_darkest, 1)
	UiStyle.draw_text(self, text, at, palette.agency_orange_light, 1)
