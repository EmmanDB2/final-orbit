# side_tab.gd: the small tab at the left edge that shows and hides the control panels. It's always
# there: a tap flips them, and dragging in from it brings them back. From DESIGN.md, "UI" (auto-hide).
class_name SideTab
extends UiWidget

signal dragged_in
signal tapped

## How far a finger drags inward to bring the panels back, in game pixels.
const DRAG_DISTANCE: float = 16.0

var from_left: bool = true
var _start_x: float = 0.0
var _dragged: bool = false
var _pressed: bool = false


func finger_down(position: Vector2) -> void:
	_start_x = position.x
	_dragged = false
	_pressed = true
	queue_redraw()


func finger_moved(position: Vector2) -> void:
	var inward: float = position.x - _start_x if from_left else _start_x - position.x
	if inward >= DRAG_DISTANCE and not _dragged:
		_dragged = true
		dragged_in.emit()


func finger_up() -> void:
	if _pressed and not _dragged:
		tapped.emit()
	_pressed = false
	queue_redraw()


## Bigger than it looks, so it's easy to catch with a thumb.
func touch_rect() -> Rect2:
	return get_global_rect().grow_individual(0.0, 22.0, 32.0, 22.0) if from_left else get_global_rect().grow_individual(32.0, 22.0, 0.0, 22.0)


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	UiStyle.draw_box(self, Rect2(Vector2.ZERO, size), palette.hull_lighter, palette.hull_mid if _pressed else UiStyle.box_fill())
	var middle: float = floorf(size.y / 2.0)
	for i in range(3):
		draw_rect(Rect2(3.0, middle - 5.0 + i * 5.0, size.x - 6.0, 1.0), palette.hull_lighter)
