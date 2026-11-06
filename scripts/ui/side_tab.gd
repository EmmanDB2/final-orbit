# side_tab.gd: the small tab showing where hidden panels are. Dragging in from it brings
# them back. From DESIGN.md, "UI" (auto-hide).
class_name SideTab
extends UiWidget

signal dragged_in

## How far a finger drags inward to bring the panels back, in game pixels.
const DRAG_DISTANCE: float = 16.0

var from_left: bool = true
var _start_x: float = 0.0


func finger_down(position: Vector2) -> void:
	_start_x = position.x


func finger_moved(position: Vector2) -> void:
	var inward: float = position.x - _start_x if from_left else _start_x - position.x
	if inward >= DRAG_DISTANCE:
		dragged_in.emit()


## Bigger than it looks, so it's easy to catch with a thumb.
func touch_rect() -> Rect2:
	return get_global_rect().grow_individual(0.0, 22.0, 32.0, 22.0) if from_left else get_global_rect().grow_individual(32.0, 22.0, 0.0, 22.0)


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, palette.hull_darkest)
	draw_rect(rect.grow(-1.0), palette.hull_light)
	var middle: float = floorf(size.y / 2.0)
	for i in range(3):
		var y: float = middle - 6.0 + i * 5.0
		draw_rect(Rect2(3.0, y, size.x - 6.0, 2.0), palette.hull_dark)
