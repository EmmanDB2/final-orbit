# context_menu.gd: what can be done with something nearby, shown on the thing itself: corner brackets
# around it in the world, a dotted line out to a label, and the label to tap, such as BOARD SHIP at
# the cockpit, ENTER at a door, or USE TERMINAL at a console. The same menu serves ships, stations,
# doors, and boards; it can hold more than one choice, one row each. From DESIGN.md, "UI" (context
# menus), drawn to Manny's 2026-11-10 mockup.
class_name ContextMenu
extends UiWidget

## Emitted with which row was tapped.
signal chosen(index: int)

const ROW_HEIGHT: float = 30.0
const PADDING: float = 12.0
const DIAMOND: float = 7.0
## How far the label sits from the brackets, along the dotted line.
const LEADER: float = 40.0
## The brackets are never smaller than this, so something tiny far out still gets them.
const SMALLEST_BOX: float = 18.0
const BRACKET_ARM: float = 7.0

var options: PackedStringArray = PackedStringArray()
var _box := Rect2()
var _has_box: bool = false
var _label := Rect2()
var _pressed: int = -1


## Shows the choices beside a box on screen, kept inside the clear part of the view. With no box, the
## label sits at the top of that clear part.
func show_at(box: Rect2, has_box: bool, clear: Rect2) -> void:
	_has_box = has_box
	var size_now := Vector2(_label_width(), ROW_HEIGHT * options.size())
	if has_box:
		var grow := Vector2(maxf(SMALLEST_BOX - box.size.x, 0.0), maxf(SMALLEST_BOX - box.size.y, 0.0)) / 2.0
		_box = box.grow_individual(grow.x + 4.0, grow.y + 4.0, grow.x + 4.0, grow.y + 4.0)
		var x: float = _box.end.x + LEADER
		if x + size_now.x > clear.end.x:
			x = _box.position.x - LEADER - size_now.x
		var y: float = _box.get_center().y - size_now.y / 2.0
		_label = Rect2(Vector2(x, y), size_now)
	else:
		_label = Rect2(Vector2(clear.get_center().x - size_now.x / 2.0, clear.position.y + 10.0), size_now)
	# Kept in the clear part, so it never lands under the panels.
	_label.position.x = clampf(_label.position.x, clear.position.x, maxf(clear.end.x - size_now.x, clear.position.x))
	_label.position.y = clampf(_label.position.y, clear.position.y, maxf(clear.end.y - size_now.y, clear.position.y))
	_label.position = _label.position.floor()
	queue_redraw()


func touch_rect() -> Rect2:
	var rect := Rect2(global_position + _label.position, _label.size)
	return rect.grow_individual(0.0, maxf((44.0 - rect.size.y) / 2.0, 0.0), 0.0, maxf((44.0 - rect.size.y) / 2.0, 0.0))


func finger_down(position: Vector2) -> void:
	_pressed = clampi(int((position.y - global_position.y - _label.position.y) / ROW_HEIGHT), 0, options.size() - 1)
	queue_redraw()


func finger_up() -> void:
	if _pressed >= 0:
		chosen.emit(_pressed)
	_pressed = -1
	queue_redraw()


func _label_width() -> float:
	var widest: float = 0.0
	for option: String in options:
		widest = maxf(widest, UiStyle.text_width(option))
	return PADDING * 2.0 + DIAMOND + 8.0 + widest


func _draw() -> void:
	if options.is_empty():
		return
	var palette: AgencyPalette = UiStyle.palette()
	var line: Color = palette.gold_light
	if _has_box:
		_draw_brackets(_box, line, palette.hull_darkest)
		# The dotted line from the brackets to the label, on whichever side the label is.
		var from := Vector2(_box.end.x + 3.0 if _label.position.x > _box.end.x else _box.position.x - 3.0, _box.get_center().y)
		var to := Vector2(_label.position.x - 6.0 if _label.position.x > _box.end.x else _label.end.x + 6.0, _label.get_center().y)
		var length: float = from.distance_to(to)
		var step: float = 5.0
		var dots: int = int(length / step)
		for i in range(dots + 1):
			var at: Vector2 = from.lerp(to, float(i) / maxf(dots, 1)).floor()
			draw_rect(Rect2(at, Vector2(2.0, 2.0)), line)
	# The label: a dark box with a thin edge, gold brackets on its corners, and a row per choice.
	UiStyle.draw_box(self, _label, palette.hull_mid, palette.hull_mid if _pressed >= 0 else UiStyle.box_fill())
	_draw_brackets(_label.grow(3.0), line, Color(0.0, 0.0, 0.0, 0.0))
	for i in range(options.size()):
		var row_y: float = _label.position.y + i * ROW_HEIGHT
		var middle: float = floorf(row_y + ROW_HEIGHT / 2.0)
		var diamond_x: float = _label.position.x + PADDING + floorf(DIAMOND / 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(diamond_x, middle - 4.0), Vector2(diamond_x + 4.0, middle),
			Vector2(diamond_x, middle + 4.0), Vector2(diamond_x - 4.0, middle)]), palette.gold)
		UiStyle.draw_text(self, options[i], Vector2(_label.position.x + PADDING + DIAMOND + 8.0, middle - 7.0), palette.gold_light)


# Four corner brackets around a box, each with a dark edge so it reads over bright art.
func _draw_brackets(box: Rect2, color: Color, edge: Color) -> void:
	var r := Rect2(box.position.floor(), box.size.floor())
	var arm: float = minf(BRACKET_ARM, floorf(minf(r.size.x, r.size.y) / 2.0))
	var strokes: Array[Rect2] = []
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = r.position.x if corner.x == 0 else r.end.x - 2.0
		var y: float = r.position.y if corner.y == 0 else r.end.y - 2.0
		strokes.append(Rect2(x if corner.x == 0 else x - arm + 2.0, y, arm, 2.0))
		strokes.append(Rect2(x, y if corner.y == 0 else y - arm + 2.0, 2.0, arm))
	# All the edges first, so no edge covers another stroke's gold where they meet.
	if edge.a > 0.0:
		for stroke: Rect2 in strokes:
			draw_rect(stroke.grow(1.0), edge)
	for stroke: Rect2 in strokes:
		draw_rect(stroke, color)
