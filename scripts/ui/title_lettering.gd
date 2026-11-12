# title_lettering.gd: paints FINAL ORBIT as pixel art, with an agency-orange orbit around it, into a small
# image the title screen draws scaled up by whole numbers, so every art pixel stays a crisp square. It's
# copied from Manny's mockup, measured off it in its own pixels: wide, sharp stencil letters, flat cream
# with a dark outline, each cut where a stencil would be (F's arms, N's stems, the A, L's foot, the O
# top and bottom, R's and B's bowls, T's bar), the O and the bowls round as in the mockup. The orbit
# is the ellipse that fits the mockup's: its near half crosses over the letters, and its far half
# passes behind the whole word, showing only at its two ends. From DESIGN.md, "Saving and the title
# screen".
class_name TitleLettering

## The mockup's pixels to an art pixel, and where its letters start, in its pixels.
const MOCKUP_SCALE: float = 3.76
const MOCKUP_ORIGIN := Vector2(60.0, 59.0)
const MOCKUP_END := Vector2(527.0, 282.0)
## The letters' pieces, in the mockup's pixels, in the order they're laid. A piece that touches one
## laid before it is cut back a pixel there, which is the stencil's seam. A piece adds shapes, takes
## "cut" shapes away, and may be clipped to a rectangle. Shapes: ["rect", x0, y0, x1, y1],
## ["round", x0, y0, x1, y1, top-left, top-right, bottom-right, bottom-left radii],
## ["ellipse", middle x, middle y, half width, half height], and ["poly", [x, y, x, y, ...]].
const PIECES: Array = [
	# F
	{"add": [["rect", 65, 59, 90, 162]]},
	{"add": [["rect", 90, 59, 148, 78], ["rect", 90, 103, 140, 121]]},
	# I
	{"add": [["rect", 163, 59, 188, 162]]},
	# N: the diagonal first, so the stems are the ones cut.
	{"add": [["poly", [206.7, 59, 234, 59, 302, 162, 275, 162]]]},
	{"add": [["rect", 205, 59, 230, 162]]},
	{"add": [["rect", 276, 59, 301, 162]]},
	# A: the right leg with the top and the crossbar, then the left leg.
	{"add": [["poly", [367, 59, 391, 59, 430, 162, 404, 162]], ["rect", 353, 123, 415, 142]]},
	{"add": [["poly", [356, 59, 381, 59, 342, 162, 316, 162]]]},
	# L
	{"add": [["rect", 445, 59, 470, 162]]},
	{"add": [["rect", 470, 143, 527, 162]]},
	# O, in two halves.
	{"add": [["ellipse", 113, 230.5, 53.5, 51.5]], "cut": [["round", 87, 202, 140, 259, 16, 16, 16, 16]], "clip": [60, 179, 113, 282]},
	{"add": [["ellipse", 113, 230.5, 53.5, 51.5]], "cut": [["round", 87, 202, 140, 259, 16, 16, 16, 16]], "clip": [113, 179, 167, 282]},
	# R
	{"add": [["rect", 181, 182, 207, 276]]},
	{"add": [["round", 207, 182, 272, 246, 0, 30, 32, 0], ["poly", [226, 240, 253, 240, 275, 282, 249, 282]]], "cut": [["round", 207, 202, 247, 227, 0, 6, 6, 0]]},
	# B
	{"add": [["rect", 293, 182, 318, 282]]},
	{"add": [["round", 318, 182, 379, 226, 0, 22, 22, 0], ["round", 318, 222, 383, 282, 0, 26, 26, 0]], "cut": [["round", 318, 202, 353, 220, 0, 6, 6, 0], ["round", 318, 237, 358, 263, 0, 8, 8, 0]]},
	# I
	{"add": [["rect", 400, 181, 425, 282]]},
	# T
	{"add": [["rect", 440, 181, 527, 202]]},
	{"add": [["rect", 471, 202, 496, 282]]},
]
## The orbit, fitted to the mockup's in its pixels: middle, half length, half width, lean in radians,
## and how thick the band is.
const ORBIT_MIDDLE := Vector2(288.3, 180.1)
const ORBIT_REACH := Vector2(273.7, 70.1)
const ORBIT_TILT: float = -0.344
const ORBIT_THICKNESS: float = 7.0
## Across this stretch of the mockup, the orbit's far half is out of sight behind the word.
const ORBIT_HIDDEN := Vector2(48.0, 502.0)
## Room around the letters for the orbit, in art pixels: left, top, right, bottom.
const MARGIN := Vector2i(12, 4)
const MARGIN_END := Vector2i(12, 6)


## How big the letters are, without the room around them, in art pixels.
static func letters_size() -> Vector2i:
	var size: Vector2 = (MOCKUP_END - MOCKUP_ORIGIN) / MOCKUP_SCALE
	return Vector2i(ceili(size.x), ceili(size.y))


## Where the letters start in the painted image, in art pixels.
static func letters_offset() -> Vector2i:
	return MARGIN


## Paints the whole thing: the far half of the orbit, the letters, then the near half over them.
static func paint() -> Image:
	var palette: AgencyPalette = UiStyle.palette()
	var size: Vector2i = letters_size() + MARGIN + MARGIN_END
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var back: Dictionary = {}
	var front: Dictionary = {}
	_orbit(size, back, front, palette)
	_lay(image, back, palette.hull_darkest)
	_lay(image, _letters(size, palette), palette.hull_darkest)
	_lay(image, front, palette.hull_darkest)
	return image


# Where an art pixel's middle falls on the mockup.
static func _on_mockup(at: Vector2i) -> Vector2:
	return MOCKUP_ORIGIN + (Vector2(at - MARGIN) + Vector2(0.5, 0.5)) * MOCKUP_SCALE


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


# Every piece, cut back a pixel where it touches one laid before it.
static func _letters(size: Vector2i, palette: AgencyPalette) -> Dictionary:
	var owner: Dictionary = {}
	for number in range(PIECES.size()):
		var piece: Dictionary = PIECES[number]
		for y in range(size.y):
			for x in range(size.x):
				var at := Vector2i(x, y)
				if owner.has(at) or not _in_piece(piece, _on_mockup(at)):
					continue
				var touches: bool = false
				for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if owner.has(at + step) and owner[at + step] != number:
						touches = true
				if not touches:
					owner[at] = number
	var pixels: Dictionary = {}
	for at: Vector2i in owner:
		pixels[at] = palette.hull_lightest
	return pixels


static func _in_piece(piece: Dictionary, point: Vector2) -> bool:
	if piece.has("clip"):
		var clip: Array = piece["clip"]
		if point.x < clip[0] or point.y < clip[1] or point.x >= clip[2] or point.y >= clip[3]:
			return false
	var inside: bool = false
	for shape: Array in piece["add"]:
		if _in_shape(shape, point):
			inside = true
			break
	if not inside:
		return false
	for shape: Array in piece.get("cut", []):
		if _in_shape(shape, point):
			return false
	return true


static func _in_shape(shape: Array, point: Vector2) -> bool:
	match shape[0]:
		"rect":
			return point.x >= shape[1] and point.y >= shape[2] and point.x < shape[3] and point.y < shape[4]
		"round":
			if point.x < shape[1] or point.y < shape[2] or point.x >= shape[3] or point.y >= shape[4]:
				return false
			# Each corner's radius, and the middle of its arc.
			var corners: Array = [
				[shape[5], Vector2(shape[1] + shape[5], shape[2] + shape[5]), -1, -1],
				[shape[6], Vector2(shape[3] - shape[6], shape[2] + shape[6]), 1, -1],
				[shape[7], Vector2(shape[3] - shape[7], shape[4] - shape[7]), 1, 1],
				[shape[8], Vector2(shape[1] + shape[8], shape[4] - shape[8]), -1, 1],
			]
			for corner: Array in corners:
				var radius: float = corner[0]
				var middle: Vector2 = corner[1]
				if radius <= 0.0:
					continue
				var beyond_x: bool = (point.x - middle.x) * corner[2] > 0.0
				var beyond_y: bool = (point.y - middle.y) * corner[3] > 0.0
				if beyond_x and beyond_y and point.distance_to(middle) > radius:
					return false
			return true
		"ellipse":
			var d := Vector2((point.x - shape[1]) / shape[3], (point.y - shape[2]) / shape[4])
			return d.length_squared() <= 1.0
		"poly":
			var points := PackedVector2Array()
			var flat: Array = shape[1]
			for i in range(0, flat.size(), 2):
				points.append(Vector2(flat[i], flat[i + 1]))
			return Geometry2D.is_point_in_polygon(point, points)
	return false


# The orbit's band, split into its far half (above its long axis) and its near half.
static func _orbit(size: Vector2i, back: Dictionary, front: Dictionary, palette: AgencyPalette) -> void:
	for y in range(size.y):
		for x in range(size.x):
			var at := Vector2i(x, y)
			# Into the orbit's own frame, where it's an upright ellipse.
			var on_mockup: Vector2 = _on_mockup(at)
			var local: Vector2 = (on_mockup - ORBIT_MIDDLE).rotated(-ORBIT_TILT)
			var angle: float = atan2(local.y / ORBIT_REACH.y, local.x / ORBIT_REACH.x)
			var ring_radius: float = Vector2(cos(angle) * ORBIT_REACH.x, sin(angle) * ORBIT_REACH.y).length()
			var out: float = (Vector2(local.x / ORBIT_REACH.x, local.y / ORBIT_REACH.y).length() - 1.0) * ring_radius
			if absf(out) > ORBIT_THICKNESS / 2.0:
				continue
			if sin(angle) >= 0.0:
				front[at] = palette.agency_orange
			elif on_mockup.x < ORBIT_HIDDEN.x or on_mockup.x > ORBIT_HIDDEN.y:
				back[at] = palette.agency_orange
