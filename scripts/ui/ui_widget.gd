# ui_widget.gd: a piece of hardware that fingers can use. flight_hud.gd decides which
# widget each finger belongs to, so two thumbs can work two widgets at once.
class_name UiWidget
extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func finger_down(_position: Vector2) -> void:
	pass


func finger_moved(_position: Vector2) -> void:
	pass


func finger_up() -> void:
	pass


## Where this widget can be touched, in screen coordinates. Never less than 44 game pixels each way,
## whatever size it's drawn.
func touch_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	return rect.grow_individual(
			maxf((44.0 - rect.size.x) / 2.0, 0.0), maxf((44.0 - rect.size.y) / 2.0, 0.0),
			maxf((44.0 - rect.size.x) / 2.0, 0.0), maxf((44.0 - rect.size.y) / 2.0, 0.0))
