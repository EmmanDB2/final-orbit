# tank_gauges.gd: the F and R bars beside the throttle: engine fuel in orange, and RCS propellant in
# cyan, each turning red when nearly gone. Out of the ship, F reads the jetpack and R goes. From
# DESIGN.md, "UI" (bottom right) and "Turning and RCS controls" (the RCS's own tank).
class_name TankGauges
extends Control

const ROW_HEIGHT: float = 20.0
const ROW_GAP: float = 15.0
const LABEL_WIDTH: float = 17.0
## At or under this share, a bar turns red.
const LOW_SHARE: float = 0.1

## Whether the R bar shows. It's the ship's; the jetpack has one tank.
var shows_rcs: bool = true:
	set(value):
		if value != shows_rcs:
			shows_rcs = value
			queue_redraw()
var _fuel_share: float = 1.0
var _rcs_share: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var fuel: float = data["fuel_share"]
	var rcs: float = data.get("rcs_share", _rcs_share)
	if absf(fuel - _fuel_share) >= 0.002 or absf(rcs - _rcs_share) >= 0.002:
		_fuel_share = fuel
		_rcs_share = rcs
		queue_redraw()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_draw_row("F", _fuel_share, palette.agency_orange, size.y - ROW_HEIGHT * 2.0 - ROW_GAP)
	if shows_rcs:
		_draw_row("R", _rcs_share, palette.telemetry_cyan, size.y - ROW_HEIGHT)


func _draw_row(label: String, share: float, color: Color, y: float) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var lit_color: Color = palette.agency_red if share <= LOW_SHARE else color
	UiStyle.draw_text(self, label, Vector2(0.0, y + floorf((ROW_HEIGHT - 14.0) / 2.0)), lit_color.lerp(palette.hull_lighter, 0.35))
	var box := Rect2(LABEL_WIDTH, y, size.x - LABEL_WIDTH, ROW_HEIGHT)
	UiStyle.draw_box(self, box, lit_color, UiStyle.box_fill())
	var inner: float = box.size.x - 8.0
	var lit: float = roundf(inner * clampf(share, 0.0, 1.0))
	if lit > 0.0:
		draw_rect(Rect2(box.position.x + 4.0, y + 4.0, lit, ROW_HEIGHT - 8.0), lit_color)
