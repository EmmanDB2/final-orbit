# flight_menu.gd: what the FLIGHT button opens. Only what works so far is on it: pausing, and going back
# to the title screen. From DESIGN.md, "UI" (menus), which adds the manifest, ship, map, and settings as
# they're built.
class_name FlightMenu
extends Control

signal pause_pressed
signal title_pressed
## For trying the lighting: cuts the station's power, or brings it back.
signal lights_pressed
signal settings_pressed

const WIDTH: float = 124.0
const ROW: float = 44.0

var _pause: UiButton
var _title: UiButton
var _lights: UiButton
var _settings: UiButton


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cyan: Color = UiStyle.palette().telemetry_cyan
	_pause = UiButton.new().setup("PAUSE", cyan)
	_title = UiButton.new().setup("TITLE", UiStyle.palette().telemetry_amber)
	_pause.tapped.connect(func() -> void: pause_pressed.emit())
	_title.tapped.connect(func() -> void: title_pressed.emit())
	add_child(_pause)
	add_child(_title)
	_settings = UiButton.new().setup("SETTINGS", cyan)
	_settings.tapped.connect(func() -> void: settings_pressed.emit())
	add_child(_settings)
	if FeatureFlags.LIGHTS_SWITCH:
		_lights = UiButton.new().setup("LIGHTS OUT", UiStyle.palette().agency_red)
		_lights.tapped.connect(func() -> void: lights_pressed.emit())
		add_child(_lights)


## Hangs it from this top right corner.
func place(top_right: Vector2) -> void:
	var rows: Array[UiWidget] = buttons()
	size = Vector2(WIDTH, ROW * rows.size())
	position = top_right - Vector2(WIDTH, 0.0)
	for i in range(rows.size()):
		rows[i].position = Vector2(0.0, ROW * i)
		rows[i].size = Vector2(WIDTH, ROW - 4.0)


func buttons() -> Array[UiWidget]:
	if _lights != null:
		return [_pause, _settings, _title, _lights]
	return [_pause, _settings, _title]


## Says on the LIGHTS button what it'll do next.
func show_powered(powered: bool) -> void:
	if _lights != null:
		_lights.set_lamp(not powered, UiStyle.palette().agency_red, "LIGHTS OUT" if powered else "LIGHTS ON")


func show_paused(paused: bool) -> void:
	_pause.set_lamp(paused, UiStyle.palette().telemetry_cyan, "RESUME" if paused else "PAUSE")
