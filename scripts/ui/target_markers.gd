# target_markers.gd: a small agency-orange arrow at the screen edge for the target when it's off
# screen, with its callsign and distance. Zoomed out far enough that it's small, the label goes beside
# it instead. The pilot picks the target from a card, and the first station starts out as it.
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
var _target: Dictionary = {}
var _clear_area := Rect2()
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0
var _roll: float = 0.0


## Starts following a flight.
func start_markers(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state


## Makes this the target, given what to call it, how far it reaches from its middle in world units,
## and a way to ask where it is right now.
func set_target(thing: Dictionary, callsign: String, reach: float, point_of: Callable) -> void:
	_target = {"thing": thing, "callsign": callsign, "reach": reach, "point_of": point_of}
	queue_redraw()


func clear_target() -> void:
	_target = {}
	queue_redraw()


func is_target(thing: Dictionary) -> bool:
	return not _target.is_empty() and _target["thing"] == thing


func _on_clear_area_changed(area: Rect2) -> void:
	_clear_area = area
	queue_redraw()


func _on_view_rolled(angle: float) -> void:
	_roll = angle


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
	if _target.is_empty():
		return
	var at: PackedFloat64Array = _target["point_of"].call()
	var offset: Vector2 = Vector2((at[0] - _center_x) * _pixels_per_unit, (at[1] - _center_y) * _pixels_per_unit).rotated(-_roll)
	var away := Vector2(at[0] - _state.x, at[1] - _state.y)
	var text: String = "%s %s" % [_target["callsign"], UiStyle.distance_text(away.length())]
	var spot: Vector2 = middle + offset
	var reach_px: float = _target["reach"] * _pixels_per_unit
	if area.has_point(spot):
		if _pixels_per_unit <= label_zoom:
			_draw_label(text, spot + Vector2(maxf(reach_px, 3.0) + 4.0, -3.0), area)
		return
	# With its middle off screen but part of it in view, the arrow would only sit on top of it.
	if area.grow(reach_px).has_point(spot):
		return
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


# A dart with a notch in its tail, so it's clear which way it points even at this size.
func _draw_arrow(tip: Vector2, direction: Vector2) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var side: Vector2 = direction.orthogonal()
	var back: Vector2 = tip - direction * arrow_length
	var half_width: float = arrow_length * 0.45
	var dart := PackedVector2Array([tip, back + side * half_width, tip - direction * arrow_length * 0.65, back - side * half_width])
	# The 1 px dark outline all human-made things get.
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_set_transform(offset)
		draw_colored_polygon(dart, palette.hull_darkest)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(dart, palette.agency_orange)


func _draw_label(text: String, top_left: Vector2, area: Rect2) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var width: float = UiStyle.text_width(text, 1)
	var at: Vector2 = Vector2(
			clampf(top_left.x, area.position.x, maxf(area.end.x - width, area.position.x)),
			clampf(top_left.y, area.position.y, maxf(area.end.y - 7.0, area.position.y))).round()
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		UiStyle.draw_text(self, text, at + offset, palette.hull_darkest, 1)
	UiStyle.draw_text(self, text, at, palette.agency_orange_light, 1)
