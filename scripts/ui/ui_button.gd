# ui_button.gd: a chunky button with a lamp, from DESIGN.md, "UI".
class_name UiButton
extends UiWidget

signal tapped

var label: String = ""
var lamp_color: Color = Color.BLACK
var lamp_on: bool = false
var _pressed: bool = false


func setup(button_label: String, color: Color) -> UiButton:
	label = button_label
	lamp_color = color
	return self


func set_lamp(on: bool, color: Color, button_label: String) -> void:
	lamp_on = on
	lamp_color = color
	label = button_label
	queue_redraw()


func finger_down(_position: Vector2) -> void:
	_pressed = true
	queue_redraw()


func finger_up() -> void:
	if _pressed:
		tapped.emit()
	_pressed = false
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	UiStyle.draw_button(self, rect, _pressed)
	var palette: AgencyPalette = UiStyle.palette()
	var text_color: Color = lamp_color if lamp_on else palette.hull_lighter
	# Long labels on small buttons drop to the smaller text size.
	var pixel_size: int = 2 if UiStyle.text_width(label) <= size.x - 6.0 else 1
	var left: float = floorf((size.x - UiStyle.text_width(label, pixel_size)) / 2.0) + 1.0
	UiStyle.draw_text(self, label, Vector2(left, floorf((size.y - 7.0 * pixel_size) / 2.0)), text_color, pixel_size)
