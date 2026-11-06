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


## Where this widget can be touched, in screen coordinates.
func touch_rect() -> Rect2:
	return get_global_rect()
