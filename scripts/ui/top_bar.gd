# top_bar.gd: the flight readouts across the top of the screen, always showing, with thin dividers
# between them. Each shows its unit small beside its name, in real units at the pilot's scale.
# From DESIGN.md, "UI" (top bar) and "Scale and precision".
class_name TopBar
extends Control

## How much of the bar's right end the buttons there take.
const BUTTONS_WIDTH: float = 136.0
const MOST_CELL_WIDTH: float = 112.0

var _cells: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var total: int = int(data["time"])
	var altitude: PackedStringArray = Units.distance_parts(maxf(data["altitude"], 0.0))
	var apoapsis: PackedStringArray = PackedStringArray(["ESC", ""]) if data["apoapsis"] < 0.0 else Units.distance_parts(data["apoapsis"])
	var periapsis: PackedStringArray = PackedStringArray(["HIT", ""]) if data["periapsis"] < 0.0 else Units.distance_parts(data["periapsis"])
	# Each is the name, the value, and the unit.
	var cells: Array = [
		["ALT", altitude[0], altitude[1]],
		["REL" if data["against_station"] else "SPD", Units.speed_number(data["speed"]), "M/S"],
		["AP", apoapsis[0], apoapsis[1]],
		["PE", periapsis[0], periapsis[1]],
		["ΔV", Units.speed_number(data["delta_v"]), "M/S"],
		["T+", "%02d:%02d" % [total / 60, total % 60], ""],
	]
	if cells != _cells:
		_cells = cells
		queue_redraw()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	# Just dark enough to read over a planet, and nothing against space.
	var band: Color = palette.hull_darkest
	band.a = 0.55
	draw_rect(Rect2(Vector2.ZERO, size), band)
	if _cells.is_empty():
		return
	var cell_width: float = minf(floorf((size.x - BUTTONS_WIDTH) / _cells.size()), MOST_CELL_WIDTH)
	for i in range(_cells.size()):
		var x: float = 14.0 + i * cell_width
		UiStyle.draw_text(self, _cells[i][0], Vector2(x, 7.0), palette.hull_lighter, 1)
		var unit_at: float = x + UiStyle.text_width(_cells[i][0] + " ", 1)
		UiStyle.draw_text(self, _cells[i][2], Vector2(unit_at, 7.0), palette.hull_light, 1)
		UiStyle.draw_text(self, _cells[i][1], Vector2(x, 19.0), palette.telemetry_cyan)
		if i < _cells.size() - 1:
			draw_rect(Rect2(x + cell_width - 12.0, 9.0, 1.0, 26.0), palette.hull_light)
