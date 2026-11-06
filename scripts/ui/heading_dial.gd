# heading_dial.gd: nose direction, prograde and retrograde markers, and spin rate.
# From DESIGN.md, "UI" (turning and RCS controls). Inner screen only.
class_name HeadingDial
extends UiWidget

## The spin that fills the rate bar, in radians per second.
@export var full_rate: float = 2.0

var _heading: float = 0.0
var _prograde: float = 0.0
var _spin: float = 0.0


func on_flight_data(data: Dictionary) -> void:
	_heading = data["heading"]
	_prograde = data["prograde"]
	_spin = data["spin"]
	queue_redraw()


func _point(angle: float, radius: float, center: Vector2) -> Vector2:
	return (center + Vector2(sin(angle), -cos(angle)) * radius).round()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var radius: float = floorf(size.x / 2.0) - 1.0
	var center := Vector2(floorf(size.x / 2.0), radius + 1.0)
	draw_circle(center, radius, palette.hull_darkest)
	draw_arc(center, radius, 0.0, TAU, 32, palette.hull_light, -1.0)
	for i in range(8):
		draw_line(_point(i * TAU / 8.0, radius - 3.0, center), _point(i * TAU / 8.0, radius - 1.0, center), palette.hull_light, -1.0)
	draw_rect(Rect2(_point(_prograde + PI, radius - 6.0, center) - Vector2(1, 1), Vector2(3, 3)), palette.agency_orange)
	draw_rect(Rect2(_point(_prograde, radius - 6.0, center) - Vector2(1, 1), Vector2(3, 3)), palette.telemetry_cyan)
	draw_line(center, _point(_heading, radius - 4.0, center), palette.hull_lightest, -1.0)

	var bar_y: float = radius * 2.0 + 5.0
	draw_rect(Rect2(0.0, bar_y, size.x, 6.0), palette.hull_darkest)
	var middle: float = floorf(size.x / 2.0)
	var fill: float = clampf(_spin / full_rate, -1.0, 1.0) * (middle - 1.0)
	draw_rect(Rect2(middle + minf(fill, 0.0), bar_y + 1.0, absf(fill), 4.0), palette.telemetry_amber)
	draw_rect(Rect2(middle, bar_y, 1.0, 6.0), palette.hull_lighter)
