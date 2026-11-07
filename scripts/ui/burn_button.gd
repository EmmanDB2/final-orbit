# burn_button.gd: fires the engine at the throttle setting, under a red flip-up safety
# cover. From DESIGN.md, "UI" (side panels). The first touch lifts the cover, and the
# button fires while held. The cover drops again after a while with no burning.
class_name BurnButton
extends UiWidget

## How long the cover stays up with no burning, in seconds.
@export var cover_open_seconds: float = 6.0

var cover_open: bool = false
var _firing: bool = false
var _time_open: float = 0.0


func finger_down(_position: Vector2) -> void:
	if not cover_open:
		cover_open = true
		_time_open = 0.0
		queue_redraw()
		return
	_firing = true
	Input.action_press(&"thrust")
	queue_redraw()


func finger_up() -> void:
	if _firing:
		_firing = false
		_time_open = 0.0
		Input.action_release(&"thrust")
		queue_redraw()


func _process(delta: float) -> void:
	if cover_open and not _firing:
		_time_open += delta
		if _time_open >= cover_open_seconds:
			cover_open = false
			queue_redraw()


# Under its cover the button is hatched over. Lifting the cover clears that and thickens the outline,
# and firing fills it in.
func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var rect := Rect2(Vector2.ZERO, size)
	var text_color: Color = palette.agency_orange
	if _firing:
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
	var left: float = floorf((size.x - UiStyle.text_width("BURN", 3)) / 2.0) + 1.0
	var at := Vector2(left, floorf((size.y - 21.0) / 2.0))
	UiStyle.draw_text(self, "BURN", at, text_color, 3)
