# throttle_lever.gd: a notched lever that sets how hard the engine pushes while it's on, with 0
# idling.
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


# A boxed track with a slot down the middle and notches either side, brighter every half, under a
# handle with an orange line. Drawn to Manny's 2026-11-10 mockup.
func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var center: float = floorf(size.x / 2.0)
	var travel: float = size.y - HANDLE_HEIGHT
	var track := Rect2(center - 13.0, HANDLE_HEIGHT / 2.0 - 6.0, 27.0, travel + 12.0)
	UiStyle.draw_box(self, track, palette.hull_mid, UiStyle.box_fill())
	draw_rect(Rect2(center - 1.0, track.position.y + 4.0, 3.0, track.size.y - 8.0), palette.hull_darkest)
	for i in range(NOTCHES + 1):
		var y: float = floorf(HANDLE_HEIGHT / 2.0 + travel * i / NOTCHES)
		var major: bool = i % 5 == 0
		var color: Color = palette.hull_lightest if major else palette.hull_light
		var length: float = 6.0 if major else 4.0
		draw_rect(Rect2(center - 4.0 - length, y, length, 1.0), color)
		draw_rect(Rect2(center + 5.0, y, length, 1.0), color)
	var handle_y: float = floorf((1.0 - value) * travel)
	var handle := Rect2(center - 16.0, handle_y, 33.0, HANDLE_HEIGHT)
	UiStyle.draw_box(self, handle, palette.hull_lighter, palette.hull_dark)
	draw_rect(Rect2(handle.position.x + 4.0, handle_y + floorf(HANDLE_HEIGHT / 2.0) - 1.0, handle.size.x - 8.0, 3.0), palette.agency_orange)
