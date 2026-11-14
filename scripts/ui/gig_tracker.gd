# gig_tracker.gd: the gigs the pilot holds, under the readouts at the top left. The focused gig shows in
# full: what it is, its steps with the one being worked on marked OBJ, how far it is to where that step
# happens, the cargo aboard, and the pay. Any others are one row each under it, with a tap on a row
# focusing that gig. A tap on its header folds it into an orange GIG tab on the left edge (with the count
# under the word when several are held), and a tap on the tab opens it again, whether the controls are
# hidden or not. It's only there while a gig is. From DESIGN.md, "Gigs" (tracker), drawn to Manny's
# 2026-11-10 mockup.
class_name GigTracker
extends UiWidget

## Emitted when a row of another held gig is tapped, with that gig's id.
signal gig_picked(id: int)

const WIDTH: float = 236.0
const PADDING: float = 10.0
const LINE: float = 12.0
const HEADER: float = 22.0
const TAB_SIZE: Vector2 = Vector2(18.0, 70.0)

## The focused gig, shown in full.
var gig: Gig = null
## How many gigs are held in all, the focused one included.
var held: int = 1
## One per other held gig, oldest first: its "title", the "right_text" at the row's right (how far it is,
## or the survey's state), and its "id".
var others: Array = []
## Whether it's open, rather than folded to its tab. Only a tap changes it.
var wanted_open: bool = true
## How far it is to where the current step happens, as text, or nothing.
var distance_text: String = ""
var cargo_text: String = ""
# What a finger's on: -1 for the header, a row's number, or -2 for nothing.
var _pressed: int = -2


func is_open() -> bool:
	return gig != null and wanted_open


## Where it's drawn now: the panel, the tab, or nothing.
func shown_rect() -> Rect2:
	if gig == null:
		return Rect2()
	if is_open():
		return Rect2(Vector2.ZERO, Vector2(WIDTH, _open_height()))
	return Rect2(Vector2(-position.x, 0.0), TAB_SIZE)


func touch_rect() -> Rect2:
	var rect: Rect2 = shown_rect()
	if not rect.has_area():
		return Rect2()
	if is_open() and others.is_empty():
		# Only the header folds it; the rest is just to read.
		rect.size.y = HEADER + 8.0
	return Rect2(global_position + rect.position, rect.size).grow_individual(0.0, 0.0, maxf(44.0 - rect.size.x, 0.0), maxf(44.0 - rect.size.y, 0.0))


func finger_down(at: Vector2) -> void:
	_pressed = _part_at(at - global_position)
	queue_redraw()


func finger_up() -> void:
	if _pressed == -1:
		wanted_open = not wanted_open
	elif _pressed >= 0 and _pressed < others.size():
		gig_picked.emit(others[_pressed]["id"])
	_pressed = -2
	queue_redraw()


# The header, a row of another gig, or nothing, at a point in its own space. Folded, the whole tab is
# the header. The first row's reach includes the separator above it.
func _part_at(local: Vector2) -> int:
	if not is_open() or local.y < HEADER + 4.0:
		return -1
	if others.is_empty() or local.y < _rows_top() - 6.0:
		return -2
	return clampi(floori((local.y - _rows_top()) / LINE), 0, others.size() - 1)


# Where the gig's own part ends and the separator goes, when there are other gigs.
func _separator_y() -> float:
	return HEADER + 4.0 + (_title_lines().size() + gig.objectives.size() + 1) * LINE + 4.0 + 7.0 + 6.0


func _rows_top() -> float:
	return _separator_y() + 6.0


func _open_height() -> float:
	if not others.is_empty():
		return _rows_top() + others.size() * LINE + PADDING
	var lines: int = _title_lines().size() + gig.objectives.size() + 3
	return HEADER + PADDING + lines * LINE + PADDING


func _title_lines() -> PackedStringArray:
	return _wrap(gig.title.to_upper(), WIDTH - PADDING * 2.0)


func _draw() -> void:
	if gig == null:
		return
	var palette: AgencyPalette = UiStyle.palette()
	if not is_open():
		_draw_tab(palette)
		return
	var rect := Rect2(Vector2.ZERO, Vector2(WIDTH, _open_height()))
	UiStyle.draw_box(self, rect, palette.hull_mid, UiStyle.box_fill())
	_draw_corners(rect.grow(2.0), palette.agency_orange)
	# The header: a warning sign, ACTIVE GIG, and a fold mark.
	var header_fill: Color = palette.hull_mid if _pressed == -1 else Color(0.0, 0.0, 0.0, 0.0)
	if header_fill.a > 0.0:
		draw_rect(Rect2(2.0, 2.0, WIDTH - 4.0, HEADER), header_fill)
	_draw_warning(Vector2(PADDING, 7.0), 9.0, palette.agency_orange)
	var header: String = "ACTIVE GIG" if held <= 1 else "ACTIVE GIGS %d/%d" % [held, Agency.MAX_GIGS]
	UiStyle.draw_text(self, header, Vector2(PADDING + 16.0, 8.0), palette.agency_orange_light, 1)
	var arrow_x: float = PADDING + 16.0 + UiStyle.text_width(header + " ", 1)
	draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, 9.0), Vector2(arrow_x + 6.0, 9.0), Vector2(arrow_x + 3.0, 13.0)]), palette.agency_orange_light)
	var y: float = HEADER + 4.0
	for line: String in _title_lines():
		UiStyle.draw_text(self, line, Vector2(PADDING, y), palette.hull_lightest, 1)
		y += LINE
	y += 2.0
	for i in range(gig.objectives.size()):
		var done: bool = i < gig.step
		var current: bool = i == gig.step
		var color: Color = palette.telemetry_green if done else (palette.hull_lightest if current else palette.hull_light)
		var text: String = "%s %s" % ["[x]" if done else "[ ]", gig.objectives[i]]
		UiStyle.draw_text(self, text, Vector2(PADDING, y), color, 1)
		if current:
			UiStyle.draw_text(self, "OBJ", Vector2(WIDTH - PADDING - UiStyle.text_width("OBJ", 1), y), palette.agency_orange_light, 1)
		y += LINE
	y += 2.0
	if distance_text != "":
		UiStyle.draw_text(self, "DIST: %s" % distance_text, Vector2(PADDING + 18.0, y), palette.hull_lighter, 1)
	y += LINE
	if cargo_text != "":
		UiStyle.draw_text(self, cargo_text, Vector2(PADDING + 18.0, y), palette.hull_lighter, 1)
	var pay: String = "%s Cr" % Units.grouped(gig.payout)
	UiStyle.draw_text(self, pay, Vector2(WIDTH - PADDING - UiStyle.text_width(pay, 1), y), palette.gold_light, 1)
	if not others.is_empty():
		_draw_others(palette)


# A thin separator, then each other held gig as a row: its title cut to fit, and its distance or state
# at the right.
func _draw_others(palette: AgencyPalette) -> void:
	draw_rect(Rect2(PADDING, _separator_y(), WIDTH - PADDING * 2.0, 1.0), palette.hull_mid)
	var y: float = _rows_top()
	for i in range(others.size()):
		var row: Dictionary = others[i]
		if _pressed == i:
			draw_rect(Rect2(2.0, y - 2.0, WIDTH - 4.0, LINE), palette.hull_mid)
		var right: String = row["right_text"]
		var right_width: float = UiStyle.text_width(right, 1)
		UiStyle.draw_text(self, right, Vector2(WIDTH - PADDING - right_width, y), palette.hull_lighter, 1)
		var title: String = _cut(String(row["title"]).to_upper(), WIDTH - PADDING * 2.0 - right_width - 8.0)
		UiStyle.draw_text(self, title, Vector2(PADDING, y), palette.hull_lightest, 1)
		y += LINE


# Text cut to fit a width, ending in .. if it had to be.
func _cut(text: String, width: float) -> String:
	if UiStyle.text_width(text, 1) <= width:
		return text
	while text.length() > 1 and UiStyle.text_width(text + "..", 1) > width:
		text = text.substr(0, text.length() - 1)
	return text.strip_edges() + ".."


# Folded: an orange tab on the left edge, with an arrow and GIG down it.
func _draw_tab(palette: AgencyPalette) -> void:
	var rect: Rect2 = shown_rect()
	UiStyle.draw_box(self, rect, palette.agency_orange, palette.hull_mid if _pressed == -1 else UiStyle.box_fill())
	var middle: float = rect.position.x + floorf(rect.size.x / 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(middle - 2.0, 7.0), Vector2(middle + 2.0, 10.0), Vector2(middle - 2.0, 13.0)]), palette.agency_orange_light)
	var y: float = 20.0
	for letter: String in "GIG":
		UiStyle.draw_text(self, letter, Vector2(middle - 2.0, y), palette.agency_orange_light, 1)
		y += 11.0
	# With several held, how many, under the word.
	if held > 1:
		UiStyle.draw_text(self, str(held), Vector2(middle - 2.0, y + 4.0), palette.hull_lightest, 1)


func _draw_corners(box: Rect2, color: Color) -> void:
	var arm: float = 8.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = box.position.x if corner.x == 0 else box.end.x - 2.0
		var y: float = box.position.y if corner.y == 0 else box.end.y - 2.0
		draw_rect(Rect2(x if corner.x == 0 else x - arm + 2.0, y, arm, 2.0), color)
		draw_rect(Rect2(x, y if corner.y == 0 else y - arm + 2.0, 2.0, arm), color)


func _draw_warning(top_left: Vector2, height: float, color: Color) -> void:
	var width: float = height + 2.0
	var tip := Vector2(top_left.x + floorf(width / 2.0), top_left.y)
	draw_colored_polygon(PackedVector2Array([tip, Vector2(top_left.x + width, top_left.y + height), Vector2(top_left.x, top_left.y + height)]), color)
	draw_rect(Rect2(tip.x, top_left.y + 3.0, 1.0, 3.0), UiStyle.palette().hull_darkest)


func _wrap(text: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line: String = ""
	for word: String in text.split(" "):
		var tried: String = word if line == "" else line + " " + word
		if UiStyle.text_width(tried, 1) > width and line != "":
			lines.append(line)
			line = word
		else:
			line = tried
	if line != "":
		lines.append(line)
	return lines
