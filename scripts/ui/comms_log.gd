# comms_log.gd: everything the comms line has said lately, opened with the comms button. Tapping it
# does nothing, so it can be read with a thumb on it. From DESIGN.md, "UI" (comms line).
class_name CommsLog
extends UiWidget

const WIDTH: float = 300.0
const ROWS: int = 12
const ROW: float = 12.0

## Where the words come from.
var comms: CommsLine


## Hangs it from this top right corner.
func place(top_right: Vector2) -> void:
	size = Vector2(WIDTH, ROWS * ROW + 20.0)
	position = top_right - Vector2(WIDTH, 0.0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	UiStyle.draw_box(self, Rect2(Vector2.ZERO, size), palette.hull_lighter, UiStyle.box_fill())
	UiStyle.draw_text(self, "COMMS LOG", Vector2(10.0, 7.0), palette.hull_lighter, 1)
	if comms == null:
		return
	var first: int = maxi(comms.history.size() - ROWS, 0)
	var y: float = 20.0
	if comms.history.is_empty():
		UiStyle.draw_text(self, "Nothing yet", Vector2(10.0, y), palette.hull_light, 1, true)
	for i in range(first, comms.history.size()):
		var entry: Dictionary = comms.history[i]
		var total: int = int(entry["time"])
		UiStyle.draw_text(self, "%02d:%02d" % [total / 60, total % 60], Vector2(10.0, y), palette.hull_lighter, 1)
		UiStyle.draw_text(self, entry["text"].substr(0, 40), Vector2(48.0, y), entry["color"], 1)
		y += ROW
