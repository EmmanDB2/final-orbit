# heading_dial.gd: a compass-style dial with a crosshair: the nose as a cyan arrowhead, prograde as a
# cyan ring and retrograde as an orange one, and spin as an amber arc along the rim, with the spin
# rate read out underneath. It reads against the screen. From DESIGN.md, "UI" (turning and RCS
# controls), drawn to Manny's 2026-11-10 mockup.
class_name HeadingDial
extends UiWidget

## The spin that fills the rate arc, in radians per second.
@export var full_rate: float = 2.0
## How much room the readout under the circle takes, in game pixels.
const READOUT_HEIGHT: float = 18.0

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
	var circle: float = minf(size.x, size.y - READOUT_HEIGHT)
	var radius: float = floorf(circle / 2.0) - 3.0
	var center: Vector2 = Vector2(floorf(size.x / 2.0), floorf(circle / 2.0))
	draw_circle(center, radius, UiStyle.box_fill())
	# Ticks every 10 degrees, longer and brighter every 30, inside the ring.
	for i in range(36):
		var angle: float = i * TAU / 36.0
		var major: bool = i % 3 == 0
		var inner: float = radius - (7.0 if major else 4.0)
		draw_line(_point(angle, inner, center), _point(angle, radius - 2.0, center), palette.hull_lighter if major else palette.hull_mid, 1.0)
	draw_arc(center, radius, 0.0, TAU, 64, palette.hull_lighter, 1.0)
	draw_rect(Rect2(center.x - 1.0, center.y - radius - 1.0, 3.0, 3.0), palette.telemetry_cyan)
	# The crosshair, dim, through a small ring in the middle.
	var reach: float = radius - 9.0
	draw_rect(Rect2(center.x - reach, center.y, reach * 2.0 + 1.0, 1.0), palette.hull_mid)
	draw_rect(Rect2(center.x, center.y - reach, 1.0, reach * 2.0 + 1.0), palette.hull_mid)
	draw_arc(center, 7.0, 0.0, TAU, 24, palette.hull_lighter, 1.0)

	if _moving:
		var retro: Vector2 = _point(_prograde - _roll + PI, radius - 15.0, center)
		draw_arc(retro, 4.0, 0.0, TAU, 12, palette.agency_orange, 1.0)
		draw_line(retro + Vector2(-2.0, -2.0), retro + Vector2(2.0, 2.0), palette.agency_orange, 1.0)
		draw_line(retro + Vector2(-2.0, 2.0), retro + Vector2(2.0, -2.0), palette.agency_orange, 1.0)
		draw_arc(_point(_prograde - _roll, radius - 15.0, center), 4.0, 0.0, TAU, 12, palette.telemetry_cyan, 1.0)

	# The nose: a line out from the middle ring to an arrowhead.
	var nose: float = _heading - _roll
	var tip: Vector2 = _point(nose, radius - 10.0, center)
	draw_line(_point(nose, 8.0, center), _point(nose, radius - 17.0, center), palette.hull_lightest, 1.0)
	var forward := Vector2(sin(nose), -cos(nose))
	var side := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - forward * 9.0 + side * 5.0, tip - forward * 9.0 - side * 5.0]), palette.telemetry_cyan)

	# Spin shows as an arc along the rim from the top, the way it's turning, and nothing when still.
	var share: float = clampf(_spin / full_rate, -1.0, 1.0)
	if absf(share) > 0.01:
		var from: float = -PI / 2.0
		draw_arc(center, radius + 2.0, from, from + share * PI, 24, palette.telemetry_amber, 1.0)

	# The spin rate, in degrees a second, under the dial.
	var rate: int = roundi(rad_to_deg(_spin))
	var text: String = "%d°/S" % rate
	var color: Color = palette.telemetry_amber if rate != 0 else palette.hull_lighter
	UiStyle.draw_text(self, text, Vector2(floorf((size.x - UiStyle.text_width(text)) / 2.0), circle + 3.0), color)
