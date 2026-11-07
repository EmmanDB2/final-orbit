# segmented_switch.gd: a switch with two sides, with the one that's on lit up. Tapping a side picks
# it. From DESIGN.md, "UI" (turning and RCS controls).
class_name SegmentedSwitch
extends UiWidget

signal changed(selected: int)

var options: PackedStringArray = PackedStringArray()
var selected: int = 0:
	set(value):
		selected = value
		queue_redraw()
var _touched: int = -1


func setup(names: PackedStringArray) -> SegmentedSwitch:
	options = names
	return self


func finger_down(position: Vector2) -> void:
	_touched = 0 if position.x - global_position.x < size.x / 2.0 else 1


func finger_up() -> void:
	if _touched >= 0 and _touched != selected:
		selected = _touched
		changed.emit(selected)
		queue_redraw()
	_touched = -1


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	UiStyle.draw_box(self, Rect2(Vector2.ZERO, size), palette.hull_lighter, UiStyle.box_fill())
	var half: float = floorf(size.x / 2.0)
	UiStyle.draw_box(self, Rect2(half * selected, 0.0, half if selected == 0 else size.x - half, size.y), palette.telemetry_cyan)
	for i in range(options.size()):
		var color: Color = palette.telemetry_cyan if i == selected else palette.hull_lighter
		var left: float = half * i + floorf((half - UiStyle.text_width(options[i])) / 2.0) + 1.0
		UiStyle.draw_text(self, options[i], Vector2(left, floorf((size.y - 14.0) / 2.0)), color)
