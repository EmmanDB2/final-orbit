# engine_button.gd: the ENGINE switch, under a red flip-up safety cover. From DESIGN.md, "UI"
# (side panels). The first touch lifts the cover, and each touch after that switches the engine on
# or off. While it's on the button is lit, and the throttle sets how hard it pushes. The cover
# drops again after a while with the engine off.
class_name EngineButton
extends UiWidget

## How long the cover stays up with the engine off, in seconds.
@export var cover_open_seconds: float = 6.0

var cover_open: bool = false
## Whether the engine's on, as the ship says.
var engine_on: bool = false:
	set(value):
		if value != engine_on:
			engine_on = value
			_time_open = 0.0
			if value:
				cover_open = true
			queue_redraw()
var _pressing: bool = false
var _time_open: float = 0.0


func finger_down(_position: Vector2) -> void:
	if not cover_open:
		cover_open = true
		_time_open = 0.0
		queue_redraw()
		return
	# The ship switches on the press, so each touch is one flip of the switch.
	_pressing = true
	Input.action_press(&"thrust")


func finger_up() -> void:
	if _pressing:
		_pressing = false
		_time_open = 0.0
		Input.action_release(&"thrust")


func _process(delta: float) -> void:
	if cover_open and not engine_on and not _pressing:
		_time_open += delta
		if _time_open >= cover_open_seconds:
			cover_open = false
			queue_redraw()


# Under its cover the button is hatched over. Lifting the cover clears that and thickens the outline,
# and the engine running fills it in.
func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var rect := Rect2(Vector2.ZERO, size)
	var text_color: Color = palette.agency_orange
	if engine_on:
		UiStyle.draw_box(self, rect, palette.agency_orange, palette.agency_orange, 2)
		text_color = palette.hull_darkest
	elif cover_open:
		UiStyle.draw_box(self, rect, palette.agency_orange_light, UiStyle.box_fill(), 2)
		text_color = palette.agency_orange_light
	else:
		UiStyle.draw_box(self, rect, palette.agency_orange, UiStyle.box_fill(), 2)
		for x in range(8, int(size.x) - 6, 10):
			for y in range(5, int(size.y) - 5, 2):
				draw_rect(Rect2(x + (y % 10) / 2, y, 1.0, 1.0), palette.agency_orange_dark)
	var text_size: int = 3 if UiStyle.text_width("ENGINE", 3) <= size.x - 12.0 else 2
	var left: float = floorf((size.x - UiStyle.text_width("ENGINE", text_size)) / 2.0) + 1.0
	var at := Vector2(left, floorf((size.y - 7.0 * text_size) / 2.0))
	UiStyle.draw_text(self, "ENGINE", at, text_color, text_size)
