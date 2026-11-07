# top_bar.gd: the always-visible bar of flight readouts. From DESIGN.md, "UI" (top bar).
# Comms, cautions, and pay join it as those systems arrive.
class_name TopBar
extends Control

const CELL_WIDTH: float = 100.0

var _cells: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var total: int = int(data["time"])
	var cells: Array = [
		["ALT", _distance(maxf(data["altitude"], 0.0))],
		["REL" if data["against_station"] else "SPD", "%d" % roundi(data["speed"])],
		["AP", "ESC" if data["apoapsis"] < 0.0 else _distance(data["apoapsis"])],
		["PE", "HIT" if data["periapsis"] < 0.0 else _distance(data["periapsis"])],
		["DV", "%d" % roundi(data["delta_v"])],
		["T", "%02d %02d" % [total / 60, total % 60]],
	]
	if cells != _cells:
		_cells = cells
		queue_redraw()


func _distance(meters: float) -> String:
	if meters >= 1000000.0:
		return "%dKM" % roundi(meters / 1000.0)
	return "%d" % roundi(meters)


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	UiStyle.draw_plate(self, Rect2(Vector2.ZERO, size))
	for i in range(_cells.size()):
		var x: float = 10.0 + i * CELL_WIDTH
		UiStyle.draw_text(self, _cells[i][0], Vector2(x, 6.0), palette.hull_lighter, 1)
		UiStyle.draw_text(self, _cells[i][1], Vector2(x, 18.0), palette.telemetry_cyan)
