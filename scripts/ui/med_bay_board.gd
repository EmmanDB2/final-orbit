# med_bay_board.gd: waking up in the med bay: the agency's cheerful bill for putting the pilot back
# together and getting them a ship, line by line, what their credits paid, what the repo squad settled,
# and BACK TO WORK. It covers the flight while it's up. From DESIGN.md, "Death and the med bay".
class_name MedBayBoard
extends UiWidget

## Emitted when the pilot heads back to work.
signal done

const MOST_SIZE: Vector2 = Vector2(560.0, 420.0)
const HEADER: float = 50.0
const MARGIN: float = 20.0
const LINE: float = 26.0
const BUTTON_SIZE: Vector2 = Vector2(250.0, 44.0)

var _bill: Dictionary = {}
var _panel := Rect2()
var _pressed: bool = false


## Shows a bill from MedBay.bill().
func open(bill: Dictionary) -> void:
	_bill = bill
	visible = true
	queue_redraw()


func touch_rect() -> Rect2:
	return get_global_rect()


func finger_down(at: Vector2) -> void:
	_pressed = _button_rect().has_point(at - global_position)
	queue_redraw()


func finger_up() -> void:
	if _pressed:
		_finish()
	_pressed = false
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
		_finish()


func _finish() -> void:
	visible = false
	done.emit()


func _layout() -> void:
	var panel_size: Vector2 = MOST_SIZE.min(size - Vector2(16.0, 16.0))
	_panel = Rect2(((size - panel_size) / 2.0).floor(), panel_size)


func _button_rect() -> Rect2:
	return Rect2(Vector2(_panel.get_center().x - BUTTON_SIZE.x / 2.0, _panel.end.y - MARGIN - BUTTON_SIZE.y).floor(), BUTTON_SIZE)


func _draw() -> void:
	if _bill.is_empty():
		return
	_layout()
	var palette: AgencyPalette = UiStyle.palette()
	var shade: Color = palette.hull_darkest
	shade.a = 0.6
	draw_rect(Rect2(Vector2.ZERO, size), shade)
	var fill: Color = palette.hull_darkest
	fill.a = 0.96
	UiStyle.draw_box(self, _panel, palette.hull_light, fill)
	var left: float = _panel.position.x + MARGIN
	var right: float = _panel.end.x - MARGIN
	UiStyle.draw_text(self, "MED BAY", Vector2(left, _panel.position.y + 14.0), palette.agency_orange_light, 3)
	var where: String = "KAPTEYN-3 // RECOVERY"
	UiStyle.draw_text(self, where, Vector2(right - UiStyle.text_width(where, 1), _panel.position.y + 22.0), palette.hull_lighter, 1)
	draw_rect(Rect2(left, _panel.position.y + HEADER, right - left, 1.0), palette.hull_mid)
	var y: float = _panel.position.y + HEADER + 14.0
	UiStyle.draw_text(self, "WELCOME BACK, PILOT!", Vector2(left, y), palette.telemetry_green, 2)
	y += LINE
	UiStyle.draw_text(self, "YOU WERE LOST: %s" % _bill["killed"], Vector2(left, y), palette.hull_lighter, 1)
	y += LINE
	UiStyle.draw_text(self, "NOW LET'S TALK FEES!", Vector2(left, y), palette.telemetry_amber, 1)
	y += LINE
	for line: Array in _bill["lines"]:
		_draw_line(line[0], _credits(line[1]), y, palette.hull_lightest, palette)
		y += LINE
	draw_rect(Rect2(left, y - 6.0, right - left, 1.0), palette.hull_mid)
	_draw_line("TOTAL", _credits(_bill["total"]), y, palette.gold_light, palette)
	y += LINE
	if _bill["free"]:
		UiStyle.draw_text(self, "ZEN MODE: IT'S ON THE HOUSE!", Vector2(left, y), palette.telemetry_green, 1)
	elif _bill["settled"] > 0:
		_draw_line("YOUR SAVINGS", _credits(_bill["paid"]), y, palette.hull_lighter, palette)
		y += LINE
		_draw_line("THE REPO SQUAD SETTLED", _credits(_bill["settled"]), y, palette.telemetry_amber, palette)
		y += LINE
		UiStyle.draw_text(self, "YOU'RE OUT OF HERE DEBT FREE! A DREAM COME TRUE!", Vector2(left, y), palette.telemetry_green, 1)
	else:
		UiStyle.draw_text(self, "PAID IN FULL. TAKE CARE OUT THERE!", Vector2(left, y), palette.telemetry_green, 1)
	var button: Rect2 = _button_rect()
	UiStyle.draw_box(self, button, palette.agency_orange_light, palette.agency_orange_dark if _pressed else UiStyle.box_fill(), 2)
	var text: String = "[ BACK TO WORK ]"
	UiStyle.draw_text(self, text, Vector2(button.position.x + floorf((button.size.x - UiStyle.text_width(text, 2)) / 2.0), button.position.y + 15.0), palette.agency_orange_light, 2)


func _draw_line(label: String, amount: String, y: float, color: Color, _palette: AgencyPalette) -> void:
	var left: float = _panel.position.x + MARGIN
	var right: float = _panel.end.x - MARGIN
	UiStyle.draw_text(self, label, Vector2(left, y), color, 1)
	UiStyle.draw_text(self, amount, Vector2(right - UiStyle.text_width(amount, 1), y), color, 1)


func _credits(amount: int) -> String:
	return "%s CR" % Units.grouped(amount)
