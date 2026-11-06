# throttle_lever.gd: a notched lever that sets thrust power. BURN only activates it.
# From DESIGN.md, "UI" (side panels).
class_name ThrottleLever
extends UiWidget

signal throttle_changed(value: float)

const NOTCHES: int = 10
const HANDLE_HEIGHT: float = 22.0

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
	draw_rect(Rect2(center - 3.0, 0.0, 6.0, size.y), palette.hull_darkest)
	for i in range(NOTCHES + 1):
		var y: float = floorf(HANDLE_HEIGHT / 2.0 + travel * i / NOTCHES)
		var long: bool = i % 5 == 0
		draw_rect(Rect2(center - (14.0 if long else 9.0), y, 28.0 if long else 18.0, 1.0), palette.hull_lighter if long else palette.hull_light)
	var handle_y: float = floorf((1.0 - value) * travel)
	UiStyle.draw_button(self, Rect2(1.0, handle_y, size.x - 2.0, HANDLE_HEIGHT), false)
	draw_rect(Rect2(4.0, handle_y + floorf(HANDLE_HEIGHT / 2.0), size.x - 8.0, 2.0), palette.agency_orange)
