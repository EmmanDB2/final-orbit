# plate_panel.gd: a side panel's metal backing. Its edge carries a red mark showing where
# BURN is, or an LED fuel gauge, so the strip still shows them when the panel is hidden.
# From DESIGN.md, "UI" (side panels and auto-hide).
class_name PlatePanel
extends Control

const GAUGE_SEGMENTS: int = 20
const GAUGE_WIDTH: float = 4.0

var burn_mark: Rect2 = Rect2()
var shows_fuel: bool = false
var _lit_segments: int = GAUGE_SEGMENTS


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var lit: int = ceili(data["fuel_share"] * GAUGE_SEGMENTS)
	if lit != _lit_segments:
		_lit_segments = lit
		queue_redraw()


func _draw() -> void:
	UiStyle.draw_plate(self, Rect2(Vector2.ZERO, size))
	if shows_fuel:
		_draw_fuel_gauge()
	if burn_mark.size != Vector2.ZERO:
		draw_rect(burn_mark.grow_individual(0.0, 0.0, 2.0, 0.0), UiStyle.palette().agency_red)


func _draw_fuel_gauge() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var color: Color = palette.telemetry_green
	if _lit_segments <= GAUGE_SEGMENTS / 10:
		color = palette.agency_red
	elif _lit_segments <= GAUGE_SEGMENTS / 4:
		color = palette.telemetry_amber
	var x: float = size.x - GAUGE_WIDTH - 1.0
	var segment_height: float = floorf((size.y - 8.0) / GAUGE_SEGMENTS)
	var bottom: float = size.y - 4.0
	for i in range(GAUGE_SEGMENTS):
		var y: float = bottom - (i + 1) * segment_height
		draw_rect(Rect2(x, y, GAUGE_WIDTH, segment_height - 1.0), color if i < _lit_segments else palette.hull_darkest)
