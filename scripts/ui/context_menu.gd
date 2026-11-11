# context_menu.gd: what can be done with something nearby, shown on the thing itself: corner brackets
# around it in the world, a dotted line out to a label, and the label to tap, such as BOARD SHIP at
# the cockpit, ENTER at a door, or USE TERMINAL at a console. The same menu serves ships, stations,
# doors, and boards; it can hold more than one choice, one row each. From DESIGN.md, "UI" (context
# menus), drawn to Manny's 2026-11-10 mockup.
#
# The label isn't fixed to one side. Each frame it tries spots all round the thing, near and farther
# out, and takes the one that covers least of what matters: the ship, the pilot, where the pilot's
# heading, and the thing itself. It only moves to a new spot when that's clearly better, and it
# slides there, so it gets out of the way without flickering.
class_name ContextMenu
extends UiWidget

## Emitted with which row was tapped.
signal chosen(index: int)

const ROW_HEIGHT: float = 30.0
const PADDING: float = 12.0
const DIAMOND: float = 7.0
## The brackets are never smaller than this, so something tiny far out still gets them.
const SMALLEST_BOX: float = 18.0
const BRACKET_ARM: float = 7.0
## Where the label can go: this many directions round the thing, at each of these gaps from it.
const DIRECTIONS: int = 12
const GAPS: Array[float] = [28.0, 60.0, 104.0]
## How much better a new spot has to score before the label moves there, so it doesn't flicker,
## in the score's units (square pixels of overlap, roughly).
const STICKINESS: float = 700.0
## How quickly the label slides to a new spot, per second.
const SLIDE: float = 12.0
## How far the line runs straight out of the label before it turns toward the thing.
const STUB: float = 10.0
## Zoomed out it gets smaller, like everything else: in a step, since the stencil text only comes in
## whole sizes. Out past the hiding zoom, where the world's a few pixels, it isn't shown at all.
const SMALL_BELOW_ZOOM: float = 0.5
const HIDDEN_BELOW_ZOOM: float = 1.0 / 32.0
## How the small one compares with the full one.
const SMALL_SHARE: float = 0.6

var options: PackedStringArray = PackedStringArray()
var _box := Rect2()
var _has_box: bool = false
var _label := Rect2()
var _pressed: int = -1
var _spot: int = -1
var _at := Vector2.ZERO
var _placed: bool = false
var _small: bool = false


## Sets how big it's drawn for how far the view's zoomed out, and says whether it shows at all.
func fit_zoom(zoom: float) -> bool:
	var small: bool = zoom < SMALL_BELOW_ZOOM
	if small != _small:
		_small = small
		reset()
	return zoom >= HIDDEN_BELOW_ZOOM


func _scaled(full: float) -> float:
	return roundf(full * SMALL_SHARE) if _small else full


func _row_height() -> float:
	return 18.0 if _small else ROW_HEIGHT


func _text_size() -> int:
	return 1 if _small else 2


## Forgets where the label was, so the next placing puts it straight where it's best.
func reset() -> void:
	_spot = -1
	_placed = false


## Places the label for a box on screen, inside the clear part of the view, keeping off whatever's in
## avoid: pairs of a screen rect and how much covering it counts against a spot. With no box, the
## label sits at the top of the clear part.
func place(box: Rect2, has_box: bool, clear: Rect2, avoid: Array, delta: float) -> void:
	_has_box = has_box
	var label_size := Vector2(_label_width(), _row_height() * options.size())
	var wanted: Vector2
	if has_box:
		var smallest: float = _scaled(SMALLEST_BOX)
		var grow := Vector2(maxf(smallest - box.size.x, 0.0), maxf(smallest - box.size.y, 0.0)) / 2.0
		_box = box.grow_individual(grow.x + 4.0, grow.y + 4.0, grow.x + 4.0, grow.y + 4.0)
		var best: int = -1
		var best_score: float = INF
		var current_score: float = INF
		for i in range(DIRECTIONS * GAPS.size()):
			var score: float = _score(i, label_size, clear, avoid)
			if score < best_score:
				best_score = score
				best = i
			if i == _spot:
				current_score = score
		if _spot < 0 or best_score < current_score - STICKINESS:
			_spot = best
		wanted = _spot_rect(_spot, label_size, clear).position
	else:
		wanted = Vector2(clear.get_center().x - label_size.x / 2.0, clear.position.y + 10.0)
	if not _placed:
		_at = wanted
		_placed = true
	else:
		_at = _at.lerp(wanted, 1.0 - exp(-SLIDE * delta))
	_label = Rect2(_at.round(), label_size)
	queue_redraw()


func touch_rect() -> Rect2:
	var rect := Rect2(global_position + _label.position, _label.size)
	return rect.grow_individual(0.0, maxf((44.0 - rect.size.y) / 2.0, 0.0), 0.0, maxf((44.0 - rect.size.y) / 2.0, 0.0))


func finger_down(position: Vector2) -> void:
	_pressed = clampi(int((position.y - global_position.y - _label.position.y) / _row_height()), 0, options.size() - 1)
	queue_redraw()


func finger_up() -> void:
	if _pressed >= 0:
		chosen.emit(_pressed)
	_pressed = -1
	queue_redraw()


# Spot i: one of the directions round the box, at one of the gaps, kept inside the clear part.
func _spot_rect(i: int, label_size: Vector2, clear: Rect2) -> Rect2:
	var way := Vector2.RIGHT.rotated(TAU * (i % DIRECTIONS) / DIRECTIONS)
	var gap: float = _scaled(GAPS[i / DIRECTIONS])
	var half_box: Vector2 = _box.size / 2.0
	var half_label: Vector2 = label_size / 2.0
	# Far enough out along that way that the label clears the box by the gap.
	var reach: float = absf(way.x) * (half_box.x + half_label.x) + absf(way.y) * (half_box.y + half_label.y) + gap
	var top_left: Vector2 = _box.get_center() + way * reach - half_label
	top_left.x = clampf(top_left.x, clear.position.x, maxf(clear.end.x - label_size.x, clear.position.x))
	top_left.y = clampf(top_left.y, clear.position.y, maxf(clear.end.y - label_size.y, clear.position.y))
	return Rect2(top_left, label_size)


# Lower is better: little of what matters covered, not shoved about by the edges, and close to the
# thing.
func _score(i: int, label_size: Vector2, clear: Rect2, avoid: Array) -> float:
	var spot: Rect2 = _spot_rect(i, label_size, clear)
	var score: float = _covered(spot, _box) * 4.0
	for pair: Array in avoid:
		score += _covered(spot, pair[0]) * pair[1]
	var way := Vector2.RIGHT.rotated(TAU * (i % DIRECTIONS) / DIRECTIONS)
	var gap: float = _scaled(GAPS[i / DIRECTIONS])
	var half_box: Vector2 = _box.size / 2.0
	var half_label: Vector2 = label_size / 2.0
	var reach: float = absf(way.x) * (half_box.x + half_label.x) + absf(way.y) * (half_box.y + half_label.y) + gap
	var free: Vector2 = _box.get_center() + way * reach - half_label
	score += free.distance_to(spot.position) * 8.0
	score += gap * 3.0
	# Beside it first, the right before the left, then above, then below, which on a world is the dirt.
	score += (1.0 - absf(way.x)) * 90.0 + (30.0 if way.x < -0.1 else 0.0) + (40.0 if way.y > 0.1 else 0.0)
	return score


func _covered(a: Rect2, b: Rect2) -> float:
	var overlap: Rect2 = a.intersection(b)
	return overlap.get_area() if overlap.has_area() else 0.0


func _label_width() -> float:
	var widest: float = 0.0
	for option: String in options:
		widest = maxf(widest, UiStyle.text_width(option, _text_size()))
	return _scaled(PADDING) * 2.0 + _scaled(DIAMOND) + _scaled(8.0) + widest


func _draw() -> void:
	if options.is_empty():
		return
	var palette: AgencyPalette = UiStyle.palette()
	var line: Color = palette.gold_light
	if _has_box:
		_draw_brackets(_box, line, palette.hull_darkest)
		_draw_leader(line)
	# The label: a dark box with a thin edge, gold brackets on its corners, and a row per choice.
	UiStyle.draw_box(self, _label, palette.hull_mid, palette.hull_mid if _pressed >= 0 else UiStyle.box_fill())
	_draw_brackets(_label.grow(2.0 if _small else 3.0), line, Color(0.0, 0.0, 0.0, 0.0))
	for i in range(options.size()):
		var row_y: float = _label.position.y + i * _row_height()
		var middle: float = floorf(row_y + _row_height() / 2.0)
		var diamond_x: float = _label.position.x + _scaled(PADDING) + floorf(_scaled(DIAMOND) / 2.0)
		var point: float = 2.0 if _small else 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(diamond_x, middle - point), Vector2(diamond_x + point, middle),
			Vector2(diamond_x, middle + point), Vector2(diamond_x - point, middle)]), palette.gold)
		var text_x: float = _label.position.x + _scaled(PADDING) + _scaled(DIAMOND) + _scaled(8.0)
		UiStyle.draw_text(self, options[i], Vector2(text_x, middle - floorf(7.0 * _text_size() / 2.0)), palette.gold_light, _text_size())


# Like the hold card's line: straight out of the label's side that faces the thing, then straight to
# the nearest point on the brackets, at whatever angle that takes. Dotted, as in the mockup.
func _draw_leader(color: Color) -> void:
	var to_box: Vector2 = _box.get_center()
	var from: Vector2
	var out: Vector2
	if to_box.x > _label.end.x + 4.0:
		from = Vector2(_label.end.x + 3.0, _label.get_center().y)
		out = Vector2.RIGHT
	elif to_box.x < _label.position.x - 4.0:
		from = Vector2(_label.position.x - 3.0, _label.get_center().y)
		out = Vector2.LEFT
	elif to_box.y < _label.position.y:
		from = Vector2(_label.get_center().x, _label.position.y - 3.0)
		out = Vector2.UP
	else:
		from = Vector2(_label.get_center().x, _label.end.y + 3.0)
		out = Vector2.DOWN
	var elbow: Vector2 = from + out * _scaled(STUB)
	var target: Rect2 = _box.grow(2.0)
	var end := Vector2(clampf(elbow.x, target.position.x, target.end.x), clampf(elbow.y, target.position.y, target.end.y))
	if target.has_point(elbow):
		return
	_draw_dots(from, elbow, color)
	_draw_dots(elbow, end, color)


# Gold dots with a dark edge, like the brackets, so the line reads over a pale hull too.
func _draw_dots(from: Vector2, to: Vector2, color: Color) -> void:
	var dots: int = int(from.distance_to(to) / 5.0)
	var edge: Color = UiStyle.palette().hull_darkest
	for i in range(dots + 1):
		var at: Vector2 = from.lerp(to, float(i) / maxf(dots, 1)).floor()
		draw_rect(Rect2(at - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), edge)
	for i in range(dots + 1):
		var at: Vector2 = from.lerp(to, float(i) / maxf(dots, 1)).floor()
		draw_rect(Rect2(at - Vector2.ONE, Vector2(2.0, 2.0)), color)


# Four corner brackets around a box, each with a dark edge so it reads over bright art.
func _draw_brackets(box: Rect2, color: Color, edge: Color) -> void:
	var r := Rect2(box.position.floor(), box.size.floor())
	var arm: float = minf(_scaled(BRACKET_ARM), floorf(minf(r.size.x, r.size.y) / 2.0))
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
