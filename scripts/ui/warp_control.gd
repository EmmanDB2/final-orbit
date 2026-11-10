# warp_control.gd: the time warp control in the clock's box: how fast time's going, then a fast
# forward button. A tap on the button goes one step faster, and holding it goes back to 1×. A tap on
# the readout goes one step slower. From DESIGN.md, "Time warp", drawn to Manny's 2026-11-10 mockup.
class_name WarpControl
extends UiWidget

signal faster
signal slower
signal reset

const BUTTON_WIDTH: float = 34.0
## How long the button's held before it resets to 1×, in milliseconds.
const HOLD_RESET: int = 500

var factor: float = 1.0:
	set(value):
		factor = value
		queue_redraw()
var _on_button: bool = false
var _pressed: bool = false
var _pressed_at: int = 0
var _reset_done: bool = false


func finger_down(position: Vector2) -> void:
	_pressed = true
	_on_button = position.x - global_position.x >= size.x - BUTTON_WIDTH - 4.0
	_pressed_at = Time.get_ticks_msec()
	_reset_done = false
	queue_redraw()


func finger_up() -> void:
	if _pressed and not _reset_done:
		if _on_button:
			faster.emit()
		else:
			slower.emit()
	_pressed = false
	queue_redraw()


func _process(_delta: float) -> void:
	if _pressed and _on_button and not _reset_done and Time.get_ticks_msec() - _pressed_at >= HOLD_RESET:
		_reset_done = true
		reset.emit()
		queue_redraw()


static func text_of(value: float) -> String:
	if value < 1.0:
		return "%s×" % str(value).trim_prefix("0")
	return "%d×" % int(value)


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var text: String = text_of(factor)
	var text_color: Color = palette.agency_orange_light if factor != 1.0 else palette.hull_lighter
	var readout_right: float = size.x - BUTTON_WIDTH - 6.0
	UiStyle.draw_text(self, text, Vector2(readout_right - UiStyle.text_width(text), floorf((size.y - 14.0) / 2.0)), text_color)
	var box := Rect2(size.x - BUTTON_WIDTH, 0.0, BUTTON_WIDTH, size.y)
	var down: bool = _pressed and _on_button
	UiStyle.draw_box(self, box, palette.hull_lighter, palette.hull_mid if down else UiStyle.box_fill())
	# Two chevrons pointing right.
	var middle := Vector2(floorf(box.get_center().x), floorf(box.get_center().y))
	for offset: float in [-6.0, 2.0]:
		for step in range(5):
			draw_rect(Rect2(middle.x + offset + step, middle.y - 4.0 + step, 2.0, 1.0), palette.hull_lightest)
			draw_rect(Rect2(middle.x + offset + step, middle.y + 4.0 - step, 2.0, 1.0), palette.hull_lightest)
