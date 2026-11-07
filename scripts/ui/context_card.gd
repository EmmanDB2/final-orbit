# context_card.gd: the card a hold brings up for anything the camera can focus on: what it is, what's
# known about it, and buttons to make it the target or the focus. A line runs from the card to the
# thing, which it follows as they move. From DESIGN.md, "UI" (planet info).
class_name ContextCard
extends Control

signal target_pressed
signal focus_pressed

const WIDTH: float = 224.0
const MARGIN: float = 10.0
const ROW: float = 12.0
const VALUE_X: float = 92.0
const BUTTON_HEIGHT: float = 26.0
## How far from the thing the card sits.
const GAP: float = 30.0

## What the card is showing.
var thing: Dictionary = {}

var _info: Dictionary = {}
var _target_button: UiButton
var _focus_button: UiButton
var _point_on_screen := Vector2.ZERO
var _points_right: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette: AgencyPalette = UiStyle.palette()
	_target_button = UiButton.new().setup("SET TARGET", palette.agency_orange)
	_target_button.lamp_on = true
	_target_button.text_size = 1
	_focus_button = UiButton.new().setup("FOCUS", palette.telemetry_cyan)
	_focus_button.text_size = 1
	_target_button.tapped.connect(func() -> void: target_pressed.emit())
	_focus_button.tapped.connect(func() -> void: focus_pressed.emit())
	add_child(_target_button)
	add_child(_focus_button)


func buttons() -> Array[UiWidget]:
	return [_target_button, _focus_button] if _target_button.visible else [_focus_button]


## Fills the card in. Info has a "name", a "chip", "rows" of [label, value, known], a "note", and
## whether it "can_target".
func show_info(info: Dictionary, shown: Dictionary, is_target: bool, is_focus: bool) -> void:
	_info = info
	thing = shown
	var palette: AgencyPalette = UiStyle.palette()
	var rows: int = info["rows"].size()
	var note_room: float = ROW + 6.0 if info["note"] != "" else 0.0
	var height: float = 34.0 + rows * ROW + 6.0 + note_room + BUTTON_HEIGHT + MARGIN
	size = Vector2(WIDTH, height)
	var button_y: float = height - MARGIN - BUTTON_HEIGHT
	var inner: float = WIDTH - MARGIN * 2.0
	_target_button.visible = info["can_target"]
	if info["can_target"]:
		_target_button.size = Vector2(floorf(inner * 0.58), BUTTON_HEIGHT)
		_target_button.position = Vector2(MARGIN, button_y)
		_target_button.set_lamp(true, palette.telemetry_cyan if is_target else palette.agency_orange, "CLEAR TARGET" if is_target else "SET TARGET")
		_focus_button.size = Vector2(inner - _target_button.size.x - 6.0, BUTTON_HEIGHT)
		_focus_button.position = Vector2(MARGIN + _target_button.size.x + 6.0, button_y)
	else:
		_focus_button.size = Vector2(inner, BUTTON_HEIGHT)
		_focus_button.position = Vector2(MARGIN, button_y)
	_focus_button.set_lamp(is_focus, palette.telemetry_cyan, "FOCUSED" if is_focus else "FOCUS")
	queue_redraw()


## Sits beside something on screen, inside the area given, on whichever side has room.
func place_beside(center: Vector2, radius: float, area: Rect2) -> void:
	var reach: float = minf(radius, area.size.x) + GAP
	var left: float = center.x - reach - WIDTH
	_points_right = left >= area.position.x
	if not _points_right:
		left = center.x + reach
	var y: float = center.y - size.y / 2.0
	position = Vector2(
			clampf(left, area.position.x, maxf(area.end.x - WIDTH, area.position.x)),
			clampf(y, area.position.y, maxf(area.end.y - size.y, area.position.y))).floor()
	_points_right = position.x + WIDTH / 2.0 < center.x


## Where the line goes: the rim of the thing, on the side facing the card.
func point_at(center: Vector2, radius: float) -> void:
	var card_side := Vector2(position.x + (WIDTH if _points_right else 0.0), position.y + 60.0)
	var way: Vector2 = (card_side - center).normalized()
	var point: Vector2 = (center + way * radius).round()
	if point != _point_on_screen:
		_point_on_screen = point
		queue_redraw()


func _draw() -> void:
	if _info.is_empty():
		return
	var palette: AgencyPalette = UiStyle.palette()
	_draw_leader(palette)
	UiStyle.draw_box(self, Rect2(Vector2.ZERO, size), palette.hull_lighter, UiStyle.box_fill())
	UiStyle.draw_text(self, _info["name"], Vector2(MARGIN, 9.0), palette.hull_lightest)

	var chip: String = _info["chip"]
	var chip_width: float = UiStyle.text_width(chip, 1) + 8.0
	var chip_rect := Rect2(WIDTH - MARGIN - chip_width, 8.0, chip_width, 15.0)
	UiStyle.draw_box(self, chip_rect, palette.hull_lighter)
	UiStyle.draw_text(self, chip, chip_rect.position + Vector2(4.0, 4.0), palette.hull_lighter, 1)
	draw_rect(Rect2(MARGIN, 28.0, WIDTH - MARGIN * 2.0, 1.0), palette.hull_light)

	var y: float = 34.0
	for row: Array in _info["rows"]:
		UiStyle.draw_text(self, row[0], Vector2(MARGIN, y), palette.hull_lighter, 1)
		UiStyle.draw_text(self, row[1], Vector2(VALUE_X, y), palette.telemetry_cyan if row[2] else palette.hull_lighter, 1)
		y += ROW
	if _info["note"] != "":
		y += 2.0
		draw_rect(Rect2(MARGIN, y, WIDTH - MARGIN * 2.0, 1.0), palette.hull_light)
		UiStyle.draw_text(self, _info["note"], Vector2(MARGIN, y + 5.0), palette.hull_lighter, 1, true)


# Out from the card a little, then across to a small square on the thing.
func _draw_leader(palette: AgencyPalette) -> void:
	var from := Vector2(WIDTH if _points_right else 0.0, 60.0)
	var elbow: Vector2 = from + Vector2(12.0 if _points_right else -12.0, 0.0)
	var point: Vector2 = _point_on_screen - global_position
	draw_line(from, elbow, palette.hull_lighter, -1.0)
	draw_line(elbow, point, palette.hull_lighter, -1.0)
	draw_rect(Rect2(point - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), palette.hull_lightest)
