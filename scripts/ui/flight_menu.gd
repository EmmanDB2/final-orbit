# flight_menu.gd: what the FLIGHT button opens. Only what works so far is on it: pausing, and going back
# to the title screen. From DESIGN.md, "UI" (menus), which adds the manifest, ship, map, and settings as
# they're built.
class_name FlightMenu
extends Control

signal pause_pressed
signal title_pressed

const WIDTH: float = 124.0
const ROW: float = 44.0

var _pause: UiButton
var _title: UiButton


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cyan: Color = UiStyle.palette().telemetry_cyan
	_pause = UiButton.new().setup("PAUSE", cyan)
	_title = UiButton.new().setup("TITLE", UiStyle.palette().telemetry_amber)
	_pause.tapped.connect(func() -> void: pause_pressed.emit())
	_title.tapped.connect(func() -> void: title_pressed.emit())
	add_child(_pause)
	add_child(_title)


## Hangs it from this top right corner.
func place(top_right: Vector2) -> void:
	size = Vector2(WIDTH, ROW * 2.0)
	position = top_right - Vector2(WIDTH, 0.0)
	_pause.position = Vector2.ZERO
	_title.position = Vector2(0.0, ROW)
	_pause.size = Vector2(WIDTH, ROW - 4.0)
	_title.size = Vector2(WIDTH, ROW - 4.0)


func buttons() -> Array[UiWidget]:
	return [_pause, _title]


func show_paused(paused: bool) -> void:
	_pause.set_lamp(paused, UiStyle.palette().telemetry_cyan, "RESUME" if paused else "PAUSE")
