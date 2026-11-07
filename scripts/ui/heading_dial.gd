# heading_dial.gd: nose direction, prograde and retrograde markers, and spin rate.
# From DESIGN.md, "UI" (turning and RCS controls).
class_name HeadingDial
extends UiWidget

## The spin that fills the rate bar, in radians per second.
@export var full_rate: float = 2.0

var _heading: float = 0.0
var _prograde: float = 0.0
var _moving: bool = false
var _spin: float = 0.0
var _roll: float = 0.0


func on_flight_data(data: Dictionary) -> void:
	_heading = data["heading"]
	_prograde = data["prograde"]
	_moving = data["moving"]
	_spin = data["spin"]
	queue_redraw()


## The dial reads against the screen, so the view turning turns it too.
func on_view_rolled(angle: float) -> void:
	_roll = angle
	queue_redraw()


func _point(angle: float, radius: float, center: Vector2) -> Vector2:
	return (center + Vector2(sin(angle), -cos(angle)) * radius).round()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var radius: float = floorf(minf(size.x, size.y) / 2.0) - 1.0
	var center: Vector2 = (size / 2.0).floor()
	draw_circle(center, radius, UiStyle.box_fill())
	draw_arc(center, radius, 0.0, TAU, 48, palette.hull_lighter, -1.0)
	for i in range(4):
		draw_line(_point(i * TAU / 4.0, radius - 4.0, center), _point(i * TAU / 4.0, radius - 1.0, center), palette.hull_lighter, -1.0)
	if _moving:
		draw_rect(Rect2(_point(_prograde - _roll + PI, radius - 8.0, center) - Vector2(2, 2), Vector2(4, 4)), palette.agency_orange)
		draw_rect(Rect2(_point(_prograde - _roll, radius - 8.0, center) - Vector2(2, 2), Vector2(4, 4)), palette.telemetry_cyan)
	draw_line(center, _point(_heading - _roll, radius - 6.0, center), palette.hull_lightest, -1.0)

	# Spin shows as an arc along the rim from the top, the way it's turning, and nothing when still.
	var share: float = clampf(_spin / full_rate, -1.0, 1.0)
	if absf(share) > 0.01:
		var from: float = -PI / 2.0
		draw_arc(center, radius + 2.0, from, from + share * PI, 24, palette.telemetry_amber, 1.0)
