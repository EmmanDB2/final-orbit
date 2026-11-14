# event_list.gd: the mid-flight events still open, under the gig tracker: each one's name, how far it
# is, and what it needs next. A tap on a row focuses the view on it and makes it the target. A tap on
# the header folds it into an amber EVT tab on the left edge, and a tap on the tab opens it again. It's
# only there while something's open. From DESIGN.md, "Mid-flight events".
class_name EventList
extends UiWidget

## Emitted when a row's tapped, with its event's id.
signal row_tapped(id: int)

const WIDTH: float = 236.0
const PADDING: float = 10.0
const LINE: float = 12.0
const HEADER: float = 22.0
const ROW: float = 30.0
const TAB_SIZE: Vector2 = Vector2(18.0, 58.0)

## One per open event: its "id", "kind", "title", "distance", "status", and whether it's "targeted".
var rows: Array = []
## Whether it's open, rather than folded to its tab. Only a tap changes it.
var wanted_open: bool = true
# What a finger's on: -1 for the header, a row's number, or -2 for nothing.
var _pressed: int = -2


func is_open() -> bool:
	return not rows.is_empty() and wanted_open


## Where it's drawn now: the panel, the tab, or nothing.
func shown_rect() -> Rect2:
	if rows.is_empty():
		return Rect2()
	if is_open():
		return Rect2(Vector2.ZERO, Vector2(WIDTH, _open_height()))
	return Rect2(Vector2(-position.x, 0.0), TAB_SIZE)


func touch_rect() -> Rect2:
	var rect: Rect2 = shown_rect()
	if not rect.has_area():
		return Rect2()
	return Rect2(global_position + rect.position, rect.size).grow_individual(0.0, 0.0, maxf(44.0 - rect.size.x, 0.0), 0.0)


func finger_down(at: Vector2) -> void:
	_pressed = _part_at(at - global_position)
	queue_redraw()


func finger_up() -> void:
	if _pressed == -1:
		wanted_open = not wanted_open
	elif _pressed >= 0 and _pressed < rows.size():
		row_tapped.emit(rows[_pressed]["id"])
	_pressed = -2
	queue_redraw()


# The header, a row, or nothing, at a point in its own space. Folded, the whole tab is the header.
func _part_at(local: Vector2) -> int:
	if not is_open():
		return -1
	if local.y < HEADER + 4.0:
		return -1
	var row: int = floori((local.y - HEADER - 4.0) / ROW)
	return row if row >= 0 and row < rows.size() else -2


func _open_height() -> float:
	return HEADER + 4.0 + rows.size() * ROW + 4.0


func _draw() -> void:
	if rows.is_empty():
		return
	var palette: AgencyPalette = UiStyle.palette()
	if not is_open():
		_draw_tab(palette)
		return
	var rect := Rect2(Vector2.ZERO, Vector2(WIDTH, _open_height()))
	UiStyle.draw_box(self, rect, palette.hull_mid, UiStyle.box_fill())
	if _pressed == -1:
		draw_rect(Rect2(2.0, 2.0, WIDTH - 4.0, HEADER), palette.hull_mid)
	_draw_signal_icon(Vector2(PADDING + 4.0, 12.0), palette.telemetry_amber)
	UiStyle.draw_text(self, "EVENTS", Vector2(PADDING + 16.0, 8.0), palette.telemetry_amber, 1)
	var arrow_x: float = PADDING + 16.0 + UiStyle.text_width("EVENTS ", 1)
	draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, 9.0), Vector2(arrow_x + 6.0, 9.0), Vector2(arrow_x + 3.0, 13.0)]), palette.telemetry_amber)
	var count: String = str(rows.size())
	UiStyle.draw_text(self, count, Vector2(WIDTH - PADDING - UiStyle.text_width(count, 1), 8.0), palette.hull_lighter, 1)
	var y: float = HEADER + 4.0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var row_rect := Rect2(2.0, y, WIDTH - 4.0, ROW - 2.0)
		if _pressed == i:
			draw_rect(row_rect, palette.hull_mid)
		elif row["targeted"]:
			draw_rect(Rect2(2.0, y, 2.0, ROW - 2.0), palette.agency_orange)
		var color: Color = EventList.color_of(row["kind"], palette)
		_draw_icon(row["kind"], Vector2(PADDING + 4.0, y + 7.0), color)
		UiStyle.draw_text(self, row["title"].to_upper(), Vector2(PADDING + 16.0, y + 2.0), palette.hull_lightest, 1)
		var distance: String = row["distance"]
		UiStyle.draw_text(self, distance, Vector2(WIDTH - PADDING - UiStyle.text_width(distance, 1), y + 2.0), palette.hull_lighter, 1)
		UiStyle.draw_text(self, row["status"], Vector2(PADDING + 16.0, y + 2.0 + LINE), palette.hull_light, 1)
		y += ROW


## Each kind's color: amber for signals, red for distress, and ice for comets.
static func color_of(kind: String, palette: AgencyPalette) -> Color:
	match kind:
		"distress":
			return palette.agency_red
		"comet":
			return palette.glass_light
	return palette.telemetry_amber


func _draw_icon(kind: String, middle: Vector2, color: Color) -> void:
	match kind:
		"distress":
			# A beacon: a small cross.
			draw_rect(Rect2(middle.x - 1.0, middle.y - 4.0, 3.0, 9.0), color)
			draw_rect(Rect2(middle.x - 4.0, middle.y - 1.0, 9.0, 3.0), color)
		"comet":
			draw_rect(Rect2(middle.x, middle.y - 1.0, 3.0, 3.0), color)
			draw_line(middle + Vector2(0.0, 1.0), middle + Vector2(-6.0, 4.0), color, 1.0)
		_:
			_draw_signal_icon(middle, color)


# A diamond.
func _draw_signal_icon(middle: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([middle + Vector2(0.0, -4.0), middle + Vector2(4.0, 0.0), middle + Vector2(0.0, 4.0), middle + Vector2(-4.0, 0.0)]), color)


# Folded: an amber tab on the left edge, with a diamond and EVT down it.
func _draw_tab(palette: AgencyPalette) -> void:
	var rect: Rect2 = shown_rect()
	UiStyle.draw_box(self, rect, palette.telemetry_amber, palette.hull_mid if _pressed == -1 else UiStyle.box_fill())
	var middle: float = rect.position.x + floorf(rect.size.x / 2.0)
	_draw_signal_icon(Vector2(middle, 10.0), palette.telemetry_amber)
	var y: float = 20.0
	for letter: String in "EVT":
		UiStyle.draw_text(self, letter, Vector2(middle - 2.0, y), palette.telemetry_amber, 1)
		y += 11.0
