# top_bar.gd: the flight readouts along the top of the screen, always showing, in two boxes that leave
# the middle open: ALT, SPD, AP, PE, and ΔV on the left, and the mission clock on the right, before
# the comms log and FLIGHT buttons. Each readout shows its unit small beside its name, in real units
# at the pilot's scale. From DESIGN.md, "UI" (top bar) and "Scale and precision".
class_name TopBar
extends Control

## How much of the bar's right end the comms log and FLIGHT buttons take.
const BUTTONS_WIDTH: float = 136.0
const EDGE: float = 8.0
const MOST_CELL_WIDTH: float = 86.0
const CELL_PADDING: float = 12.0
## The clock box fits this much clock, so it doesn't jump as the time grows.
const CLOCK_ROOM: String = "0:00:00"

## Room inside the clock box, right of the clock, for whatever sits there, in game pixels.
var clock_extra: float = 0.0:
	set(value):
		clock_extra = value
		queue_redraw()
var _cells: Array = []
var _clock: String = "00:00"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_flight_data(data: Dictionary) -> void:
	var total: int = int(data["time"])
	var altitude: PackedStringArray = Units.distance_parts(maxf(data["altitude"], 0.0))
	var apoapsis: PackedStringArray = PackedStringArray(["ESC", ""]) if data["apoapsis"] < 0.0 else Units.distance_parts(data["apoapsis"])
	var periapsis: PackedStringArray = PackedStringArray(["HIT", ""]) if data["periapsis"] < 0.0 else Units.distance_parts(data["periapsis"])
	# Each is the name, the value, the unit, and whether it's about the orbit's shape.
	var cells: Array = [
		["ALT", altitude[0], altitude[1], false],
		["REL" if data["against_station"] else "SPD", Units.speed_number(data["speed"]), "M/S", false],
		["AP", apoapsis[0], apoapsis[1], true],
		["PE", periapsis[0], periapsis[1], true],
		["ΔV", Units.speed_number(data["delta_v"]), "M/S", false],
	]
	var clock: String = "%02d:%02d" % [total / 60, total % 60]
	if total >= 3600:
		clock = "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
	if cells != _cells or clock != _clock:
		_cells = cells
		_clock = clock
		queue_redraw()


## The box of readouts on the left, in the bar's own coordinates.
func readouts_rect() -> Rect2:
	var count: int = maxi(_cells.size(), 5)
	return Rect2(EDGE, 0.0, CELL_PADDING + count * _cell_width(), size.y)


## The clock's box on the right, in the bar's own coordinates.
func clock_rect() -> Rect2:
	var width: float = CELL_PADDING * 2.0 + UiStyle.text_width(CLOCK_ROOM) + clock_extra
	return Rect2(maxf(size.x - BUTTONS_WIDTH - EDGE - width, 0.0), 0.0, width, size.y)


## Whether a point on screen is on one of the boxes, which are hardware, not open space.
func covers(point: Vector2) -> bool:
	var local: Vector2 = point - global_position
	return readouts_rect().has_point(local) or clock_rect().has_point(local)


func _cell_width() -> float:
	var room: float = size.x - BUTTONS_WIDTH - EDGE * 4.0 - CELL_PADDING * 3.0 - UiStyle.text_width(CLOCK_ROOM) - clock_extra
	return clampf(floorf(room / 5.0), 0.0, MOST_CELL_WIDTH)


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	# The boxes hang from the top edge, their top corners off the screen.
	for box: Rect2 in [readouts_rect(), clock_rect()]:
		UiStyle.draw_box(self, Rect2(box.position.x, -4.0, box.size.x, box.size.y + 4.0), palette.hull_mid, UiStyle.box_fill())
	var cell_width: float = _cell_width()
	for i in range(_cells.size()):
		var x: float = EDGE + CELL_PADDING + i * cell_width
		_draw_readout(x, _cells[i][0], _cells[i][2], _cells[i][1], palette.agency_orange_light if _cells[i][3] else palette.hull_lightest)
		if i < _cells.size() - 1:
			draw_rect(Rect2(x + cell_width - 8.0, 9.0, 1.0, 26.0), palette.hull_light)
	_draw_readout(clock_rect().position.x + CELL_PADDING, "T+", "", _clock, palette.hull_lightest)


func _draw_readout(x: float, label: String, unit: String, value: String, color: Color) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	UiStyle.draw_text(self, label, Vector2(x, 7.0), palette.hull_lighter, 1)
	if unit != "":
		UiStyle.draw_text(self, unit, Vector2(x + UiStyle.text_width(label + " ", 1), 7.0), palette.hull_light, 1)
	UiStyle.draw_text(self, value, Vector2(x, 19.0), color)
