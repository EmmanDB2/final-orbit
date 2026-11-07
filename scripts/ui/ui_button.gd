# ui_button.gd: an outlined button that lights up when it's on. From DESIGN.md, "UI".
class_name UiButton
extends UiWidget

signal tapped

var label: String = ""
var lamp_color: Color = Color.BLACK
var lamp_on: bool = false
## A symbol drawn with the label: "chat", "menu", or nothing.
var icon: String = ""
## Which text size to use, or 0 to pick whichever fits.
var text_size: int = 0
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
	var palette: AgencyPalette = UiStyle.palette()
	var line: Color = lamp_color if lamp_on else palette.hull_lighter
	var fill: Color = palette.hull_mid if _pressed else UiStyle.box_fill()
	UiStyle.draw_box(self, Rect2(Vector2.ZERO, size), line, fill)
	var text_color: Color = lamp_color if lamp_on else palette.hull_lightest
	var room: float = size.x - 6.0
	if icon == "menu":
		room -= 16.0
	var pixel_size: int = text_size
	if pixel_size == 0:
		pixel_size = 2 if UiStyle.text_width(label) <= room else 1
	var width: float = UiStyle.text_width(label, pixel_size)
	var extra: float = 16.0 if icon == "menu" else 0.0
	var left: float = floorf((size.x - width - extra) / 2.0) + 1.0
	if label != "":
		UiStyle.draw_text(self, label, Vector2(left, floorf((size.y - 7.0 * pixel_size) / 2.0)), text_color, pixel_size)
	match icon:
		"menu":
			var x: float = left + width + 4.0
			var middle: float = floorf(size.y / 2.0)
			for offset: float in [-4.0, 0.0, 4.0]:
				draw_rect(Rect2(x, middle + offset, 10.0, 1.0), text_color)
		"chat":
			var c: Vector2 = (size / 2.0).floor()
			UiStyle.draw_box(self, Rect2(c.x - 9.0, c.y - 7.0, 18.0, 12.0), text_color)
			draw_rect(Rect2(c.x - 5.0, c.y + 5.0, 2.0, 3.0), text_color)
			for dot: float in [-4.0, 0.0, 4.0]:
				draw_rect(Rect2(c.x + dot - 1.0, c.y - 2.0, 2.0, 2.0), text_color)
