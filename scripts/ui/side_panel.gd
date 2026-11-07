# side_panel.gd: holds one side's controls, and slides off with them when they hide. Its inner edge
# carries the fuel gauge or a mark showing where BURN is, so the strip left on screen still shows
# them. From DESIGN.md, "UI" (side panels and auto-hide).
class_name SidePanel
extends Control

const GAUGE_WIDTH: float = 3.0

var burn_mark: Rect2 = Rect2()
## The mark's only there for the strip left when hidden.
var mark_shows: bool = false:
	set(value):
		if value != mark_shows:
			mark_shows = value
			queue_redraw()
var shows_fuel: bool = false
var gauge_height: float = 0.0
var _fuel_share: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var share: float = data["fuel_share"]
	if absf(share - _fuel_share) >= 0.002:
		_fuel_share = share
		queue_redraw()


func _draw() -> void:
	if shows_fuel:
		_draw_fuel_gauge()
	if mark_shows and burn_mark.size != Vector2.ZERO:
		draw_rect(burn_mark, UiStyle.palette().agency_orange)


func _draw_fuel_gauge() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var color: Color = palette.telemetry_cyan
	if _fuel_share <= 0.1:
		color = palette.agency_red
	elif _fuel_share <= 0.25:
		color = palette.telemetry_amber
	var x: float = size.x - GAUGE_WIDTH - 1.0
	var height: float = gauge_height if gauge_height > 0.0 else size.y
	draw_rect(Rect2(x, 0.0, GAUGE_WIDTH, height), palette.hull_dark)
	var lit: float = roundf(height * clampf(_fuel_share, 0.0, 1.0))
	draw_rect(Rect2(x, height - lit, GAUGE_WIDTH, lit), color)
