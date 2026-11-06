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


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var rect := Rect2(Vector2.ZERO, size)
	if cover_open:
		UiStyle.draw_button(self, rect.grow_individual(0.0, -10.0, 0.0, 0.0), _firing)
		draw_rect(Rect2(2.0, 0.0, size.x - 4.0, 8.0), palette.agency_red)
		var text_y: float = 10.0 + floorf((size.y - 24.0) / 2.0)
		UiStyle.draw_text(self, "BURN", Vector2(floorf((size.x - UiStyle.text_width("BURN")) / 2.0) + 1.0, text_y), palette.agency_orange if not _firing else palette.telemetry_amber)
	else:
		draw_rect(rect, palette.hull_darkest)
		draw_rect(rect.grow(-1.0), palette.agency_red)
		for x in range(4, int(size.x) - 4, 8):
			draw_rect(Rect2(x, 3.0, 3.0, size.y - 6.0), palette.hull_darkest)
		var label_rect := Rect2(4.0, floorf(size.y / 2.0) - 10.0, size.x - 8.0, 20.0)
		draw_rect(label_rect, palette.agency_red)
		UiStyle.draw_text(self, "BURN", Vector2(floorf((size.x - UiStyle.text_width("BURN")) / 2.0) + 1.0, label_rect.position.y + 3.0), palette.hull_lightest)
