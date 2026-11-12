# title_lettering.gd: paints FINAL ORBIT as pixel art, with an agency-orange orbit swept around it, into a
# small image the title screen draws scaled up by whole numbers, so every art pixel stays a crisp square.
# The letters are stencil letters: each piece is its own shape, with a one-pixel gap where pieces would
# join, bowls and the O rounded off, a shaded bottom edge, and a dark outline. The orbit is a stepped
# ring, thicker where it swings to the front, light on its outer edge and dark on its inner one. It
# weaves: in front of the O where it swings round at the lower left, and behind the letters everywhere
# else, so they stay readable. From DESIGN.md, "Saving and the title screen" (Manny's mockup).
class_name TitleLettering

## Art pixels to a cell of the letter grid.
const CELL: int = 3
## Each letter on a grid 9 cells tall and 7 wide (I is 6), with strokes 2 cells thick. A letter is its
## pieces; a piece is blocks [x, y, width, height] and slants [x at the top, x at the bottom, width,
## top, bottom], in cells, joined into one shape. Every outside corner loses its corner pixel, and the
## corners named in "curve" ("tl", "tr", "bl", "br", of the piece's bounds) are rounded off along a
## circle as wide as "radius", in art pixels.
const LETTERS: Dictionary = {
	"F": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 2, 9]], "round": 1},
		{"blocks": [[2, 0, 5, 2]], "round": 1},
		{"blocks": [[2, 3.5, 4, 2]], "round": 1}]},
	"I": {"width": 6, "pieces": [
		{"blocks": [[0, 0, 6, 2], [2, 2, 2, 5], [0, 7, 6, 2]], "round": 1}]},
	"N": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 2, 9]], "round": 1},
		{"slants": [[2, 3, 2, 0, 9]], "round": 1},
		{"blocks": [[5, 0, 2, 9]], "round": 1}]},
	"A": {"width": 7, "pieces": [
		{"slants": [[1.5, 0, 2, 0, 9]], "round": 1},
		{"slants": [[3.5, 5, 2, 0, 9]], "round": 1},
		{"blocks": [[2.5, 5, 2, 1.7]], "round": 0}]},
	"L": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 2, 9]], "round": 1},
		{"blocks": [[2, 7, 5, 2]], "round": 1}]},
	"O": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 2, 9], [2, 0, 1.5, 2], [2, 7, 1.5, 2]], "round": 1, "curve": ["tl", "bl"], "radius": 6},
		{"blocks": [[5, 0, 2, 9], [3.5, 0, 1.5, 2], [3.5, 7, 1.5, 2]], "round": 1, "curve": ["tr", "br"], "radius": 6}]},
	"R": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 2, 9]], "round": 1},
		{"blocks": [[2, 0, 3.5, 2], [5, 0, 2, 5.5], [2, 3.5, 3.5, 2]], "round": 1, "curve": ["tr", "br"], "radius": 5},
		{"slants": [[3.5, 5, 2, 5.5, 9]], "round": 1}]},
	"B": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 2, 9]], "round": 1},
		{"blocks": [[2, 0, 3.5, 2], [5, 0, 2, 4.2], [2, 3.5, 3, 2], [5, 4.8, 2, 4.2], [2, 7, 3.5, 2]], "round": 1, "curve": ["tr", "br"], "radius": 5}]},
	"T": {"width": 7, "pieces": [
		{"blocks": [[0, 0, 7, 2]], "round": 1},
		{"blocks": [[2.5, 2, 2, 7]], "round": 1}]},
}
const LINES: Array[String] = ["FINAL", "ORBIT"]
const LETTER_HEIGHT: float = 9.0
## Room between letters, and between the two lines, in cells.
const LETTER_GAP: float = 1.5
const LINE_GAP: float = 2.0
## Room around the letters for the orbit, in art pixels.
const MARGIN := Vector2i(10, 6)
## How the orbit leans, in radians, how big it is against the letters, and how thick it is at the back
## and the front, in art pixels.
const ORBIT_TILT: float = -0.22
const ORBIT_REACH := Vector2(0.55, 0.42)
const ORBIT_BACK: float = 2.6
const ORBIT_FRONT: float = 4.6
## The stretch of the orbit drawn in front of the letters, as angles around it in its own frame, from
## the bottom (PI / 2) round to the left end (PI) and a little past.
const ORBIT_FRONT_FROM: float = 1.95
const ORBIT_FRONT_TO: float = 3.45


## How big the letters are, without the room around them, in art pixels.
static func letters_size() -> Vector2i:
	var widest: float = 0.0
	for line: String in LINES:
		widest = maxf(widest, _line_width(line))
	return Vector2i(roundi(widest * CELL), roundi((LETTER_HEIGHT * LINES.size() + LINE_GAP) * CELL))


## Where the letters start in the painted image, in art pixels.
static func letters_offset() -> Vector2i:
	return MARGIN


## Paints the whole thing: the back of the orbit, the letters, then the front of the orbit.
static func paint() -> Image:
	var palette: AgencyPalette = UiStyle.palette()
	var size: Vector2i = letters_size() + MARGIN * 2
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var back: Dictionary = {}
	var front: Dictionary = {}
	_orbit(size, back, front, palette)
	_lay(image, back, palette.hull_darkest)
	_lay(image, _letters(palette), palette.hull_darkest)
	_lay(image, front, palette.hull_darkest)
	return image


static func _line_width(line: String) -> float:
	var width: float = 0.0
	for letter: String in line:
		width += LETTERS[letter]["width"] + LETTER_GAP
	return width - LETTER_GAP


# Paints a layer of pixels, {Vector2i: Color}, with a one-pixel outline around it first, so it stands
# off whatever's under it.
static func _lay(image: Image, pixels: Dictionary, outline: Color) -> void:
	for at: Vector2i in pixels:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var edge: Vector2i = at + Vector2i(dx, dy)
				if not pixels.has(edge) and _inside(image, edge):
					image.set_pixelv(edge, outline)
	for at: Vector2i in pixels:
		image.set_pixelv(at, pixels[at])


static func _inside(image: Image, at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height()


# Every letter's pieces, gapped where they meet, rounded, and shaded along their bottoms.
static func _letters(palette: AgencyPalette) -> Dictionary:
	# Which piece each pixel belongs to, numbered across the whole lettering.
	var owner: Dictionary = {}
	var piece_number: int = 0
	for row in range(LINES.size()):
		var x: float = 0.0
		var y: float = row * (LETTER_HEIGHT + LINE_GAP)
		for letter: String in LINES[row]:
			for piece: Dictionary in LETTERS[letter]["pieces"]:
				var mask: Dictionary = _round(_piece_mask(piece, Vector2(x, y)), piece.get("round", 0))
				mask = _curve(mask, piece.get("curve", []), piece.get("radius", 0))
				for at: Vector2i in mask:
					# Touching a piece already laid leaves a gap: a stencil's bridge.
					var touches: bool = false
					for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						if owner.has(at + step) and owner[at + step] != piece_number:
							touches = true
					if not touches:
						owner[at] = piece_number
				piece_number += 1
			x += LETTERS[letter]["width"] + LETTER_GAP
	var pixels: Dictionary = {}
	for at: Vector2i in owner:
		var bottom: bool = not owner.has(at + Vector2i.DOWN) or owner[at + Vector2i.DOWN] != owner[at]
		pixels[at + MARGIN] = palette.hull_light if bottom else palette.hull_lightest
	return pixels


# One piece's pixels: its blocks and slants filled, judged at each pixel's middle.
static func _piece_mask(piece: Dictionary, origin: Vector2) -> Dictionary:
	var mask: Dictionary = {}
	for block: Array in piece.get("blocks", []):
		var low := Vector2i(roundi((origin.x + block[0]) * CELL), roundi((origin.y + block[1]) * CELL))
		var high := Vector2i(roundi((origin.x + block[0] + block[2]) * CELL), roundi((origin.y + block[1] + block[3]) * CELL))
		for y in range(low.y, high.y):
			for x in range(low.x, high.x):
				mask[Vector2i(x, y)] = true
	for slant: Array in piece.get("slants", []):
		var top: float = (origin.y + slant[3]) * CELL
		var bottom: float = (origin.y + slant[4]) * CELL
		var top_x: float = (origin.x + slant[0]) * CELL
		var bottom_x: float = (origin.x + slant[1]) * CELL
		var width: float = slant[2] * CELL
		for y in range(floori(top), ceili(bottom)):
			var share: float = (y + 0.5 - top) / (bottom - top)
			var left: float = lerpf(top_x, bottom_x, share)
			for x in range(floori(left), ceili(left + width)):
				if x + 0.5 >= left and x + 0.5 < left + width:
					mask[Vector2i(x, y)] = true
	return mask


# Takes the corner pixel off each of a shape's outside corners, which softens it without thinning it.
static func _round(mask: Dictionary, chop: int) -> Dictionary:
	if chop <= 0:
		return mask
	var kept: Dictionary = {}
	for at: Vector2i in mask:
		var open_x: bool = not mask.has(at + Vector2i.LEFT) or not mask.has(at + Vector2i.RIGHT)
		var open_y: bool = not mask.has(at + Vector2i.UP) or not mask.has(at + Vector2i.DOWN)
		if not (open_x and open_y):
			kept[at] = true
	return kept


# Rounds the named corners of a shape's bounds off along a circle this wide.
static func _curve(mask: Dictionary, corners: Array, radius: int) -> Dictionary:
	if corners.is_empty() or radius <= 0 or mask.is_empty():
		return mask
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-(1 << 20), -(1 << 20))
	for at: Vector2i in mask:
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
		high = Vector2i(maxi(high.x, at.x + 1), maxi(high.y, at.y + 1))
	var kept: Dictionary = mask.duplicate()
	for corner: String in corners:
		var right: bool = corner.ends_with("r")
		var lower: bool = corner.begins_with("b")
		var middle := Vector2(high.x - radius if right else low.x + radius, high.y - radius if lower else low.y + radius)
		for at: Vector2i in mask:
			var in_corner_x: bool = at.x >= high.x - radius if right else at.x < low.x + radius
			var in_corner_y: bool = at.y >= high.y - radius if lower else at.y < low.y + radius
			if in_corner_x and in_corner_y and (Vector2(at) + Vector2(0.5, 0.5)).distance_to(middle) > radius:
				kept.erase(at)
	return kept


# The orbit as stepped pixels, split into the half behind the letters and the half in front.
static func _orbit(size: Vector2i, back: Dictionary, front: Dictionary, palette: AgencyPalette) -> void:
	var middle: Vector2 = Vector2(size) / 2.0
	var reach: Vector2 = Vector2(letters_size()) * ORBIT_REACH
	for y in range(size.y):
		for x in range(size.x):
			# Into the orbit's own frame, where it's an upright ellipse.
			var local: Vector2 = (Vector2(x + 0.5, y + 0.5) - middle).rotated(-ORBIT_TILT)
			var angle: float = fposmod(atan2(local.y / reach.y, local.x / reach.x), TAU)
			var ring_radius: float = Vector2(cos(angle) * reach.x, sin(angle) * reach.y).length()
			var out: float = (Vector2(local.x / reach.x, local.y / reach.y).length() - 1.0) * ring_radius
			var near: float = maxf(sin(angle), 0.0)
			var half: float = lerpf(ORBIT_BACK, ORBIT_FRONT, near) / 2.0
			if absf(out) > half:
				continue
			var color: Color = palette.agency_orange
			if out > half - 1.0:
				color = palette.agency_orange_light
			elif out < -half + 1.0:
				color = palette.agency_orange_dark
			if angle >= ORBIT_FRONT_FROM and angle <= ORBIT_FRONT_TO:
				front[Vector2i(x, y)] = color
			else:
				back[Vector2i(x, y)] = color
