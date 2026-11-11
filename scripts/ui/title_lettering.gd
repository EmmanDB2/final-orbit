# title_lettering.gd: draws FINAL ORBIT in big stencil letters, with an agency-orange orbit swept around
# them. Each stroke is its own block, with a gap where strokes would join, as a stencil leaves them, and
# a 1 px dark outline. From DESIGN.md, "Saving and the title screen" (Manny's mockup).
class_name TitleLettering

## The letters on a grid 9 cells tall and 7 wide (I is 6), with strokes 2 cells thick. Blocks are
## [x, y, width, height], and slants are [x at the top, x at the bottom, width, top, bottom], in cells.
const LETTERS: Dictionary = {
	"F": {"width": 7, "blocks": [[0, 0, 2, 9], [2, 0, 5, 2], [2, 3.5, 4, 2]], "slants": []},
	"I": {"width": 6, "blocks": [[0, 0, 6, 2], [2, 2, 2, 5], [0, 7, 6, 2]], "slants": []},
	"N": {"width": 7, "blocks": [[0, 0, 2, 9], [5, 0, 2, 9]], "slants": [[2, 3, 2, 0, 9]]},
	"A": {"width": 7, "blocks": [[2.6, 5, 1.8, 1.6]], "slants": [[1.5, 0, 2, 0, 9], [3.5, 5, 2, 0, 9]]},
	"L": {"width": 7, "blocks": [[0, 0, 2, 9], [2, 7, 5, 2]], "slants": []},
	"O": {"width": 7, "blocks": [[0, 2, 2, 5], [5, 2, 2, 5], [2, 0, 3, 2], [2, 7, 3, 2]], "slants": []},
	"R": {"width": 7, "blocks": [[0, 0, 2, 9], [2, 0, 3, 2], [5, 2, 2, 1.5], [2, 3.5, 3, 2]], "slants": [[3, 5, 2, 5.5, 9]]},
	"B": {"width": 7, "blocks": [[0, 0, 2, 9], [2, 0, 3, 2], [5, 2, 2, 1.5], [2, 3.5, 3, 2], [5, 5.5, 2, 1.5], [2, 7, 3, 2]], "slants": []},
	"T": {"width": 7, "blocks": [[0, 0, 7, 2], [2.5, 2, 2, 7]], "slants": []},
}
const LINES: Array[String] = ["FINAL", "ORBIT"]
const LETTER_HEIGHT: float = 9.0
## Room between letters, and between the two lines, in cells.
const LETTER_GAP: float = 1.5
const LINE_GAP: float = 2.0
## How the orbit leans, in radians, and how big it is against the lettering.
const ORBIT_TILT: float = -0.24
const ORBIT_REACH := Vector2(0.56, 0.34)
const ORBIT_THICKNESS: float = 3.0


## How big the lettering is with cells this big, in pixels.
static func size_for(cell: float) -> Vector2:
	var widest: float = 0.0
	for line: String in LINES:
		widest = maxf(widest, _line_width(line))
	return Vector2(widest, LETTER_HEIGHT * LINES.size() + LINE_GAP) * cell


## Draws the lettering with its top left here, the back of the orbit behind it and the front over it.
static func draw(canvas: CanvasItem, top_left: Vector2, cell: float) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var box := Rect2(top_left, size_for(cell))
	_draw_orbit(canvas, box, false, palette)
	var shapes: Array[PackedVector2Array] = []
	for row in range(LINES.size()):
		var x: float = top_left.x
		var y: float = top_left.y + row * (LETTER_HEIGHT + LINE_GAP) * cell
		for letter: String in LINES[row]:
			shapes.append_array(_letter_shapes(LETTERS[letter], Vector2(x, y), cell))
			x += (LETTERS[letter]["width"] + LETTER_GAP) * cell
	# Every outline first, so no stroke's outline lands on a neighbour's face.
	for shape: PackedVector2Array in shapes:
		for grown: PackedVector2Array in Geometry2D.offset_polygon(shape, 1.0, Geometry2D.JOIN_MITER):
			canvas.draw_colored_polygon(grown, palette.hull_darkest)
	for shape: PackedVector2Array in shapes:
		canvas.draw_colored_polygon(shape, palette.hull_lightest)
	_draw_orbit(canvas, box, true, palette)


static func _line_width(line: String) -> float:
	var width: float = 0.0
	for letter: String in line:
		width += LETTERS[letter]["width"] + LETTER_GAP
	return width - LETTER_GAP


# One letter's strokes as polygons on whole pixels, each pulled in a pixel all round, so strokes that
# meet leave a 2 px stencil gap.
static func _letter_shapes(letter: Dictionary, origin: Vector2, cell: float) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	for block: Array in letter["blocks"]:
		var rect := Rect2((origin + Vector2(block[0], block[1]) * cell).round(), (Vector2(block[2], block[3]) * cell).round())
		rect = rect.grow(-1.0)
		shapes.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	for slant: Array in letter["slants"]:
		var top: float = roundf(origin.y + slant[3] * cell) + 1.0
		var bottom: float = roundf(origin.y + slant[4] * cell) - 1.0
		var width: float = slant[2] * cell
		var top_x: float = roundf(origin.x + slant[0] * cell)
		var bottom_x: float = roundf(origin.x + slant[1] * cell)
		shapes.append(PackedVector2Array([
			Vector2(top_x + 1.0, top), Vector2(top_x + width - 1.0, top),
			Vector2(bottom_x + width - 1.0, bottom), Vector2(bottom_x + 1.0, bottom),
		]))
	return shapes


# Half the orbit: the far half goes behind the letters and the near half over them.
static func _draw_orbit(canvas: CanvasItem, box: Rect2, near: bool, palette: AgencyPalette) -> void:
	var middle: Vector2 = box.get_center()
	var reach: Vector2 = box.size * ORBIT_REACH
	var points := PackedVector2Array()
	var steps: int = 96
	for i in range(steps + 1):
		var angle: float = PI * float(i) / steps + (0.0 if near else PI)
		points.append((middle + Vector2(cos(angle) * reach.x, sin(angle) * reach.y).rotated(ORBIT_TILT)).round())
	canvas.draw_polyline(points, palette.hull_darkest, ORBIT_THICKNESS + 2.0)
	canvas.draw_polyline(points, palette.agency_orange, ORBIT_THICKNESS)
