# rcs_button.gd: a pad button that fires the RCS while held. From DESIGN.md, "UI" (turning
# and RCS controls). It presses an input action, so the ship doesn't know it's a button.
class_name RcsButton
extends UiWidget

## Which way the arrow points, or zero for a rotate button.
var direction: Vector2 = Vector2.ZERO
## For a rotate button: -1 turns left and 1 turns right.
var rotation_sign: int = 0
var action: StringName = &""
var _pressed: bool = false


func setup(arrow: Vector2, turn: int, input_action: StringName) -> RcsButton:
	direction = arrow
	rotation_sign = turn
	action = input_action
	return self


## Points the button at a different action, letting go of the old one first.
func set_action(input_action: StringName, arrow: Vector2, turn: int) -> void:
	if _pressed and action != &"":
		Input.action_release(action)
	action = input_action
	direction = arrow
	rotation_sign = turn
	if _pressed and action != &"":
		Input.action_press(action)
	queue_redraw()


func finger_down(_position: Vector2) -> void:
	_pressed = true
	if action != &"":
		Input.action_press(action)
	queue_redraw()


func finger_up() -> void:
	if _pressed and action != &"":
		Input.action_release(action)
	_pressed = false
	queue_redraw()


func _draw() -> void:
	# With no action it isn't there at all, so rotating leaves only left and right.
	if action == &"":
		return
	var palette: AgencyPalette = UiStyle.palette()
	var fill: Color = palette.hull_mid if _pressed else UiStyle.box_fill()
	UiStyle.draw_box(self, Rect2(Vector2.ZERO, size), palette.telemetry_cyan if _pressed else palette.hull_lighter, fill)
	var color: Color = palette.telemetry_cyan if _pressed else palette.hull_lightest
	var middle: Vector2 = (size / 2.0).floor()
	if rotation_sign != 0:
		_draw_turn_symbol(middle, color)
	else:
		_draw_arrow(middle, direction, 8.0, color)


func _draw_arrow(tip_center: Vector2, pointing: Vector2, length: float, color: Color) -> void:
	var side := Vector2(-pointing.y, pointing.x)
	draw_colored_polygon(PackedVector2Array([
		tip_center + pointing * length,
		tip_center - pointing * length + side * length,
		tip_center - pointing * length - side * length,
	]), color)


# A curved arrow: an arc around the middle, with an arrowhead showing which way it turns.
func _draw_turn_symbol(middle: Vector2, color: Color) -> void:
	var radius: float = 11.0
	draw_arc(middle, radius, -PI * 0.9, -PI * 0.1, 16, color, 2.0)
	var end_angle: float = -PI * 0.1 if rotation_sign > 0 else -PI * 0.9
	var tip: Vector2 = middle + Vector2(cos(end_angle), sin(end_angle)) * radius
	_draw_arrow(tip + Vector2(0.0, 2.0), Vector2(0.0, 1.0), 5.0, color)
