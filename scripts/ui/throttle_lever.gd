# throttle_lever.gd: a notched lever that sets thrust power. BURN only activates it.
# From DESIGN.md, "UI" (side panels).
class_name ThrottleLever
extends UiWidget

signal throttle_changed(value: float)

const NOTCHES: int = 10
const HANDLE_HEIGHT: float = 16.0

var value: float = 1.0


func finger_down(position: Vector2) -> void:
	finger_moved(position)


func finger_moved(position: Vector2) -> void:
	var travel: float = maxf(size.y - HANDLE_HEIGHT, 1.0)
	var share: float = 1.0 - clampf((position.y - global_position.y - HANDLE_HEIGHT / 2.0) / travel, 0.0, 1.0)
	var notched: float = roundf(share * NOTCHES) / NOTCHES
	if notched != value:
		value = notched
		throttle_changed.emit(value)
		queue_redraw()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var center: float = floorf(size.x / 2.0)
	var travel: float = size.y - HANDLE_HEIGHT
	draw_rect(Rect2(center, 0.0, 1.0, size.y), palette.hull_lighter)
	for i in range(NOTCHES + 1):
		var y: float = floorf(HANDLE_HEIGHT / 2.0 + travel * i / NOTCHES)
		var half: float = 9.0 if i % 5 == 0 else 6.0
		draw_rect(Rect2(center - half, y, half * 2.0 + 1.0, 1.0), palette.hull_lighter)
	var handle_y: float = floorf((1.0 - value) * travel)
	var handle := Rect2(center - 16.0, handle_y, 33.0, HANDLE_HEIGHT)
	UiStyle.draw_box(self, handle, palette.hull_lighter, palette.hull_dark)
	draw_rect(Rect2(handle.position.x + 3.0, handle_y + floorf(HANDLE_HEIGHT / 2.0) - 1.0, handle.size.x - 6.0, 3.0), palette.agency_orange)
