# settings_screen.gd: SETTINGS, from the title or the FLIGHT menu: each sound channel's volume in tenths
# with − and +, haptics, the helmet lamp (AUTO, ON, or OFF), and whether the controls hide when idle,
# then DONE. Every change is kept at once. It covers what's behind it while it's up, and works while
# the game's paused behind the title. From DESIGN.md, "Settings".
class_name SettingsScreen
extends UiWidget

## Emitted when anything changes, so whoever uses the settings can pick them up.
signal changed
## Emitted on DONE.
signal closed

const MOST_SIZE: Vector2 = Vector2(560.0, 440.0)
const HEADER: float = 50.0
const MARGIN: float = 20.0
const ROW: float = 44.0
const SMALL_BUTTON: Vector2 = Vector2(44.0, 34.0)
const CHOICE_SIZE: Vector2 = Vector2(110.0, 34.0)
const DONE_SIZE: Vector2 = Vector2(200.0, 44.0)
## The volumes, each with its setting and what it's called.
const VOLUMES: Array = [["effects", "EFFECTS"], ["ui", "COCKPIT"], ["radio", "RADIO"], ["music", "MUSIC"]]

## Over the title, nothing passes it touches, so it takes them itself.
var own_input: bool = false
var _panel := Rect2()
var _pressed: String = ""


func _init() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	visible = true
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not own_input or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			finger_down(event.position)
		else:
			finger_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()


func touch_rect() -> Rect2:
	return get_global_rect()


func finger_down(at: Vector2) -> void:
	_pressed = _part_at(at - global_position)
	queue_redraw()


func finger_up() -> void:
	var part: String = _pressed
	_pressed = ""
	queue_redraw()
	if part == "":
		return
	if part == "done":
		visible = false
		closed.emit()
		return
	if part.ends_with(":-") or part.ends_with(":+"):
		var key: String = part.substr(0, part.length() - 2)
		var step: float = 0.1 if part.ends_with(":+") else -0.1
		GameSettings.set_value(key, snappedf(clampf(float(GameSettings.value(key)) + step, 0.0, 1.0), 0.1))
	elif part == "haptics" or part == "auto_hide":
		GameSettings.set_value(part, not bool(GameSettings.value(part)))
	elif part == "helmet_lamp":
		var choices: Array[String] = GameSettings.LAMP_CHOICES
		var now: int = choices.find(String(GameSettings.value("helmet_lamp")))
		GameSettings.set_value("helmet_lamp", choices[(now + 1) % choices.size()])
	changed.emit()


# What's under a point in its own space: a volume's "key:-" or "key:+", a toggle's key, "done", or
# nothing.
func _part_at(local: Vector2) -> String:
	_layout()
	for i in range(VOLUMES.size()):
		var key: String = VOLUMES[i][0]
		if _minus_rect(i).grow(4.0).has_point(local):
			return key + ":-"
		if _plus_rect(i).grow(4.0).has_point(local):
			return key + ":+"
	for i in range(_toggles().size()):
		if _choice_rect(VOLUMES.size() + i).grow(4.0).has_point(local):
			return _toggles()[i][0]
	if _done_rect().has_point(local):
		return "done"
	return ""


func _toggles() -> Array:
	return [["haptics", "HAPTICS"], ["helmet_lamp", "HELMET LAMP"], ["auto_hide", "HIDE CONTROLS WHEN IDLE"]]


func _layout() -> void:
	var panel_size: Vector2 = MOST_SIZE.min(size - Vector2(16.0, 16.0))
	_panel = Rect2(((size - panel_size) / 2.0).floor(), panel_size)


func _row_y(row: int) -> float:
	return _panel.position.y + HEADER + 10.0 + row * ROW


func _minus_rect(row: int) -> Rect2:
	return Rect2(Vector2(_panel.end.x - MARGIN - SMALL_BUTTON.x * 2.0 - 160.0, _row_y(row)), SMALL_BUTTON)


func _plus_rect(row: int) -> Rect2:
	return Rect2(Vector2(_panel.end.x - MARGIN - SMALL_BUTTON.x, _row_y(row)), SMALL_BUTTON)


func _choice_rect(row: int) -> Rect2:
	return Rect2(Vector2(_panel.end.x - MARGIN - CHOICE_SIZE.x, _row_y(row)), CHOICE_SIZE)


func _done_rect() -> Rect2:
	return Rect2(Vector2(_panel.get_center().x - DONE_SIZE.x / 2.0, _panel.end.y - MARGIN - DONE_SIZE.y).floor(), DONE_SIZE)


func _draw() -> void:
	_layout()
	var palette: AgencyPalette = UiStyle.palette()
	var shade: Color = palette.hull_darkest
	shade.a = 0.6
	draw_rect(Rect2(Vector2.ZERO, size), shade)
	var fill: Color = palette.hull_darkest
	fill.a = 0.96
	UiStyle.draw_box(self, _panel, palette.hull_light, fill)
	var left: float = _panel.position.x + MARGIN
	UiStyle.draw_text(self, "SETTINGS", Vector2(left, _panel.position.y + 14.0), palette.agency_orange_light, 3)
	draw_rect(Rect2(left, _panel.position.y + HEADER, _panel.size.x - MARGIN * 2.0, 1.0), palette.hull_mid)
	for i in range(VOLUMES.size()):
		var key: String = VOLUMES[i][0]
		var share: float = float(GameSettings.value(key))
		var y: float = _row_y(i)
		UiStyle.draw_text(self, VOLUMES[i][1], Vector2(left, y + 10.0), palette.hull_lightest, 2)
		_draw_button(_minus_rect(i), "-", _pressed == key + ":-", palette)
		_draw_button(_plus_rect(i), "+", _pressed == key + ":+", palette)
		# The level in ten blocks between them.
		var bar_left: float = _minus_rect(i).end.x + 8.0
		var block: float = (_plus_rect(i).position.x - 8.0 - bar_left) / 10.0
		for b in range(10):
			var lit: bool = b < roundi(share * 10.0)
			draw_rect(Rect2(bar_left + b * block + 1.0, y + 8.0, block - 2.0, SMALL_BUTTON.y - 16.0), palette.telemetry_cyan if lit else palette.hull_dark)
	var toggles: Array = _toggles()
	for i in range(toggles.size()):
		var row: int = VOLUMES.size() + i
		var key: String = toggles[i][0]
		var y: float = _row_y(row)
		UiStyle.draw_text(self, toggles[i][1], Vector2(left, y + 10.0), palette.hull_lightest, 2)
		var shown: String = String(GameSettings.value(key)) if key == "helmet_lamp" else ("ON" if bool(GameSettings.value(key)) else "OFF")
		_draw_button(_choice_rect(row), shown, _pressed == key, palette)
	var done: Rect2 = _done_rect()
	UiStyle.draw_box(self, done, palette.agency_orange_light, palette.agency_orange_dark if _pressed == "done" else UiStyle.box_fill(), 2)
	UiStyle.draw_text(self, "[ DONE ]", Vector2(done.position.x + floorf((done.size.x - UiStyle.text_width("[ DONE ]", 2)) / 2.0), done.position.y + 15.0), palette.agency_orange_light, 2)


func _draw_button(rect: Rect2, label: String, pressed: bool, palette: AgencyPalette) -> void:
	UiStyle.draw_box(self, rect, palette.telemetry_cyan, palette.hull_mid if pressed else UiStyle.box_fill())
	UiStyle.draw_text(self, label, Vector2(rect.position.x + floorf((rect.size.x - UiStyle.text_width(label, 1)) / 2.0), rect.position.y + floorf((rect.size.y - 7.0) / 2.0)), palette.telemetry_cyan, 1)
