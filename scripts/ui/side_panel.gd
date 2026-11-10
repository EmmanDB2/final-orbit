# side_panel.gd: holds a group of controls in a corner, and slides off with them when they hide. The
# edge it leaves showing carries the fuel level and a mark where ENGINE is, so the strip still shows
# them. From DESIGN.md, "UI" (auto-hide).
class_name SidePanel
extends Control

const GAUGE_WIDTH: float = 3.0

## Where ENGINE is, and where the fuel level shows, on the panel's edge that stays showing.
var burn_mark: Rect2 = Rect2()
var fuel_mark: Rect2 = Rect2()
## The marks are only there for the strip left when hidden.
var mark_shows: bool = false:
	set(value):
		if value != mark_shows:
			mark_shows = value
			queue_redraw()
var _fuel_share: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var share: float = data["fuel_share"]
	if absf(share - _fuel_share) >= 0.002:
		_fuel_share = share
		if mark_shows:
			queue_redraw()


func _draw() -> void:
	if not mark_shows:
		return
	var palette: AgencyPalette = UiStyle.palette()
	if fuel_mark.size != Vector2.ZERO:
		var color: Color = palette.telemetry_cyan
		if _fuel_share <= 0.1:
			color = palette.agency_red
		elif _fuel_share <= 0.25:
			color = palette.telemetry_amber
		draw_rect(fuel_mark, palette.hull_dark)
		var lit: float = roundf(fuel_mark.size.y * clampf(_fuel_share, 0.0, 1.0))
		draw_rect(Rect2(fuel_mark.position.x, fuel_mark.end.y - lit, fuel_mark.size.x, lit), color)
	if burn_mark.size != Vector2.ZERO:
		draw_rect(burn_mark, palette.agency_orange)
