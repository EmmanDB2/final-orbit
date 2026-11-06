# slice_station.gd: turns the station concept images in art/station_1/source/ into clean sprites in
# art/station_1/. Each image holds one room: its outside on the left, its inside in the middle, and
# a reference astronaut on the right. This cuts out the outside and the inside, drops the background
# and the stars, reads the fake pixels back down to real ones, and forces the agency palette.
# From DESIGN.md, "Art direction" (art pipeline, 1 px dark outline, locked palette).
#
# The outside and inside of a room come out on the same canvas, lined up on the room's docking
# ports. It prints where the ports are, for the station's data file. Only needs running again if the
# images change. Run with:
#   godot --headless --path . --script tools/slice_station.gd
extends SceneTree

## How wide one fake pixel is in the module images, in source pixels. The hub was drawn with smaller
## fake pixels, but at the same size overall, so it's read at this size too and its ports fit.
const SOURCE_PIXEL: float = 5.74
## How far a color can be from the image's background and still count as background.
const BACKGROUND_REACH: int = 30
## Pieces this small that touch nothing are stars.
const STAR_CELLS: int = 12
## How much bluer than red a dark patch has to be to be a hole showing space.
const SPACE_BLUE: float = 9.0
## Neighboring pixels this close in color are one surface in different shade, and get evened out.
const SHADE_REACH: float = 0.05
## A lone pixel this close in color to what's around it is noise, not a detail like a rivet.
const SPECK_CONTRAST: float = 0.2
## Shading shouldn't change what color something is painted, so brightness counts for less than hue.
const BRIGHTNESS_WEIGHT: float = 0.2

## Each room, and the source columns its outside and inside lie between.
const ROOMS: Array = [
	{"name": "hub", "outside": [80, 1260], "inside": [1335, 2560], "grid": false},
	{"name": "comms", "outside": [185, 1195], "inside": [1400, 2365], "grid": true},
	{"name": "crew_hab", "outside": [185, 1195], "inside": [1385, 2320], "grid": true},
	{"name": "eva_hab", "outside": [185, 1195], "inside": [1385, 2320], "grid": true},
	{"name": "ship_refueling", "outside": [70, 1240], "inside": [1395, 2432], "grid": true},
	{"name": "suit_room", "outside": [185, 1195], "inside": [1370, 2365], "grid": true},
]

var _palette := PackedInt32Array()
var _palette_lab := PackedVector3Array()
var _nearest := {}


func _initialize() -> void:
	_load_palette()
	for room: Dictionary in ROOMS:
		_cut_room(room)
	quit()


func _load_palette() -> void:
	var palette: Resource = load("res://data/agency_palette.tres")
	for property: Dictionary in palette.get_property_list():
		# Thrust colors are for fire, not for painting a hull.
		if property["type"] == TYPE_COLOR and not property["name"].begins_with("thrust_"):
			var color: Color = palette.get(property["name"])
			_palette.append(color.r8)
			_palette.append(color.g8)
			_palette.append(color.b8)
			_palette_lab.append(_to_oklab(color.r8, color.g8, color.b8))
	print("palette has %d colors" % (_palette.size() / 3))


func _cut_room(room: Dictionary) -> void:
	var path: String = "res://art/station_1/source/station_%s.jpg" % room["name"]
	var source: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	source.convert(Image.FORMAT_RGB8)
	var phase := Vector2.ZERO
	if room["grid"]:
		phase = _find_phase(source)
	var outside: Dictionary = _read_side(source, room["outside"], phase, room["grid"])
	var inside: Dictionary = _read_side(source, room["inside"], phase, room["grid"])

	# Line the two sides up on the port axis, and on the bottom of the bottom port.
	var a: Dictionary = _find_ports(outside)
	var b: Dictionary = _find_ports(inside)
	var half: int = maxi(a["half_width"], b["half_width"]) + 2
	var above: int = maxi(a["bottom"] - outside["used"].position.y, b["bottom"] - inside["used"].position.y) + 2
	var size := Vector2i(half * 2 + 1, above + 3)
	_save(outside, a, size, half, above, "res://art/station_1/%s.png" % room["name"])
	_save(inside, b, size, half, above, "res://art/station_1/%s_interior.png" % room["name"])

	var top_port: int = above - (a["bottom"] - a["top"])
	print("%s: canvas %s, axis x %d, outside ports y %d and %d, inside top port y %d" % [
			room["name"], size, half, top_port, above, above - (b["bottom"] - b["top"])])


# Finds how the fake pixel grid lines up with the image, from where the color changes fall.
func _find_phase(source: Image) -> Vector2:
	var w: int = source.get_width()
	var h: int = source.get_height()
	var data: PackedByteArray = source.get_data()
	var across := Vector2.ZERO
	var down := Vector2.ZERO
	for y in range(0, h - 1, 3):
		for x in range(0, w - 1, 3):
			var i: int = (y * w + x) * 3
			var here: int = data[i] + data[i + 1] + data[i + 2]
			var j: int = i + 3
			var right: int = data[j] + data[j + 1] + data[j + 2]
			var k: int = i + w * 3
			var below: int = data[k] + data[k + 1] + data[k + 2]
			var angle_x: float = TAU * (x + 0.5) / SOURCE_PIXEL
			var angle_y: float = TAU * (y + 0.5) / SOURCE_PIXEL
			across += Vector2(cos(angle_x), sin(angle_x)) * absi(here - right)
			down += Vector2(cos(angle_y), sin(angle_y)) * absi(here - below)
	return Vector2(fposmod(across.angle(), TAU), fposmod(down.angle(), TAU)) / TAU * SOURCE_PIXEL


# Reads one side of an image into cells of palette colors, then takes away everything that isn't it.
func _read_side(source: Image, columns: Array, phase: Vector2, on_grid: bool) -> Dictionary:
	var w: int = source.get_width()
	var h: int = source.get_height()
	var data: PackedByteArray = source.get_data()
	var background: Vector3i = _background_of(data, w, h)

	var left_cell: int = floori((columns[0] - phase.x) / SOURCE_PIXEL)
	var cells := Vector2i(ceili((columns[1] - phase.x) / SOURCE_PIXEL) - left_cell, floori((h - phase.y) / SOURCE_PIXEL))
	var color := PackedInt32Array()
	var dark := PackedByteArray()
	var blue := PackedFloat32Array()
	var lab := PackedVector3Array()
	lab.resize(cells.x * cells.y)
	color.resize(cells.x * cells.y)
	dark.resize(cells.x * cells.y)
	blue.resize(cells.x * cells.y)

	# On the grid, read only the middle of each fake pixel, away from the blur at its edges.
	var inset: float = 0.22 if on_grid else 0.0
	for cy in range(cells.y):
		var y0: int = ceili(phase.y + (cy + inset) * SOURCE_PIXEL)
		var y1: int = ceili(phase.y + (cy + 1 - inset) * SOURCE_PIXEL)
		for cx in range(cells.x):
			var x0: int = ceili(phase.x + (left_cell + cx + inset) * SOURCE_PIXEL)
			var x1: int = ceili(phase.x + (left_cell + cx + 1 - inset) * SOURCE_PIXEL)
			var votes := {}
			var samples: int = 0
			var like_background: int = 0
			var blue_total: int = 0
			# The whole cell decides whether anything's here, so a thin antenna isn't lost.
			for y in range(maxi(ceili(phase.y + cy * SOURCE_PIXEL), 0), mini(ceili(phase.y + (cy + 1) * SOURCE_PIXEL), h)):
				for x in range(maxi(ceili(phase.x + (left_cell + cx) * SOURCE_PIXEL), 0), mini(ceili(phase.x + (left_cell + cx + 1) * SOURCE_PIXEL), w)):
					var i: int = (y * w + x) * 3
					samples += 1
					blue_total += data[i + 2] - data[i]
					if absi(data[i] - background.x) + absi(data[i + 1] - background.y) + absi(data[i + 2] - background.z) <= BACKGROUND_REACH:
						like_background += 1
			var mean := Vector3i.ZERO
			var middle: int = 0
			for y in range(maxi(y0, 0), mini(y1, h)):
				for x in range(maxi(x0, 0), mini(x1, w)):
					var i: int = (y * w + x) * 3
					mean += Vector3i(data[i], data[i + 1], data[i + 2])
					middle += 1
					var index: int = _nearest_color(data[i], data[i + 1], data[i + 2])
					votes[index] = votes.get(index, 0) + 1
			var at: int = cy * cells.x + cx
			var best: int = -1
			var most: int = -1
			for index: int in votes:
				if votes[index] > most:
					most = votes[index]
					best = index
			color[at] = best
			if middle > 0:
				lab[at] = _to_oklab(mean.x / middle, mean.y / middle, mean.z / middle)
			dark[at] = 1 if samples > 0 and like_background * 100 >= samples * 80 else 0
			blue[at] = float(blue_total) / maxi(samples, 1)

	var keep: PackedByteArray = _strip_background(cells, dark, blue)
	_drop_stars(cells, keep)
	# On the grid a fake pixel is one color, so averaging takes out the JPEG noise. Off the grid a
	# cell can straddle two, and averaging them would make up a third, so it keeps its top vote.
	if on_grid:
		_smooth_shading(cells, lab, color, keep)
	_clean_specks(cells, color, keep)
	var used := Rect2i()
	var first: bool = true
	for cy in range(cells.y):
		for cx in range(cells.x):
			if keep[cy * cells.x + cx] == 1:
				var cell := Rect2i(cx, cy, 1, 1)
				used = cell if first else used.merge(cell)
				first = false
	return {"cells": cells, "color": color, "keep": keep, "used": used}


func _background_of(data: PackedByteArray, w: int, h: int) -> Vector3i:
	var total := Vector3i.ZERO
	var count: int = 0
	for y in [4, 8, h - 8, h - 4]:
		for x in range(4, w - 4, 40):
			var i: int = (y * w + x) * 3
			# Skip the odd star.
			if data[i] + data[i + 1] + data[i + 2] < 120:
				total += Vector3i(data[i], data[i + 1], data[i + 2])
				count += 1
	return total / count


# Clears background reached from outside. The hull's dark outline goes with it and gets drawn back
# when saving, because the two are too close in color to tell apart. Dark pockets closed off inside
# are kept, unless they're blue enough to be space showing through a gap in something.
func _strip_background(cells: Vector2i, dark: PackedByteArray, blue: PackedFloat32Array) -> PackedByteArray:
	var keep := PackedByteArray()
	keep.resize(cells.x * cells.y)
	keep.fill(1)
	var seen := PackedByteArray()
	seen.resize(cells.x * cells.y)
	var stack: Array[int] = []
	for at in range(cells.x * cells.y):
		var cx: int = at % cells.x
		var cy: int = at / cells.x
		if dark[at] == 1 and (cx == 0 or cy == 0 or cx == cells.x - 1 or cy == cells.y - 1):
			stack.append(at)
			seen[at] = 1
	while not stack.is_empty():
		var at: int = stack.pop_back()
		keep[at] = 0
		for next: int in _neighbors(at, cells):
			if dark[next] == 1 and seen[next] == 0:
				seen[next] = 1
				stack.append(next)

	for start in range(cells.x * cells.y):
		if dark[start] == 0 or seen[start] == 1:
			continue
		var pocket: Array[int] = [start]
		seen[start] = 1
		var total_blue: float = 0.0
		var walk: int = 0
		while walk < pocket.size():
			var at: int = pocket[walk]
			walk += 1
			total_blue += blue[at]
			for next: int in _neighbors(at, cells):
				if dark[next] == 1 and seen[next] == 0:
					seen[next] = 1
					pocket.append(next)
		if pocket.size() >= 4 and total_blue / pocket.size() >= SPACE_BLUE:
			for at: int in pocket:
				keep[at] = 0
	return keep


func _drop_stars(cells: Vector2i, keep: PackedByteArray) -> void:
	var seen := PackedByteArray()
	seen.resize(keep.size())
	for start in range(keep.size()):
		if keep[start] == 0 or seen[start] == 1:
			continue
		var piece: Array[int] = [start]
		seen[start] = 1
		var walk: int = 0
		while walk < piece.size():
			var at: int = piece[walk]
			walk += 1
			# Corners count here, so a diagonal antenna stays one piece.
			for next: int in _neighbors_with_corners(at, cells):
				if keep[next] == 1 and seen[next] == 0:
					seen[next] = 1
					piece.append(next)
		if piece.size() < STAR_CELLS:
			for at: int in piece:
				keep[at] = 0


# Evens out shading between pixels of nearly the same color and leaves real edges alone, so a gradient
# crossing from one palette color to the next makes a clean line instead of speckle.
func _smooth_shading(cells: Vector2i, lab: PackedVector3Array, color: PackedInt32Array, keep: PackedByteArray) -> void:
	for _pass in range(3):
		var before: PackedVector3Array = lab.duplicate()
		for at in range(lab.size()):
			if keep[at] == 0:
				continue
			var total: Vector3 = before[at]
			var count: int = 1
			for next: int in _neighbors_with_corners(at, cells):
				if keep[next] == 1 and before[next].distance_to(before[at]) < SHADE_REACH:
					total += before[next]
					count += 1
			lab[at] = total / count
	for at in range(lab.size()):
		if keep[at] == 1:
			color[at] = _nearest_to(lab[at])


# A shade halfway between two palette colors comes out as speckle. A pixel with almost nothing of its
# own color around it, and close in color to what is around it, takes on its surroundings.
func _clean_specks(cells: Vector2i, color: PackedInt32Array, keep: PackedByteArray) -> void:
	for _pass in range(3):
		var before: PackedInt32Array = color.duplicate()
		for at in range(color.size()):
			if keep[at] == 0:
				continue
			var votes := {}
			var same: int = 0
			for next: int in _neighbors_with_corners(at, cells):
				if keep[next] == 1:
					votes[before[next]] = votes.get(before[next], 0) + 1
					if before[next] == before[at]:
						same += 1
			if same > 1:
				continue
			var best: int = before[at]
			var most: int = 0
			for index: int in votes:
				if votes[index] > most:
					most = votes[index]
					best = index
			if best != before[at] and _palette_lab[best].distance_to(_palette_lab[before[at]]) < SPECK_CONTRAST:
				color[at] = best


func _neighbors_with_corners(at: int, cells: Vector2i) -> Array[int]:
	var cx: int = at % cells.x
	var cy: int = at / cells.x
	var found: Array[int] = []
	for y in range(maxi(cy - 1, 0), mini(cy + 2, cells.y)):
		for x in range(maxi(cx - 1, 0), mini(cx + 2, cells.x)):
			if x != cx or y != cy:
				found.append(y * cells.x + x)
	return found


func _neighbors(at: int, cells: Vector2i) -> Array[int]:
	var cx: int = at % cells.x
	var found: Array[int] = []
	if cx > 0:
		found.append(at - 1)
	if cx < cells.x - 1:
		found.append(at + 1)
	if at >= cells.x:
		found.append(at - cells.x)
	if at < cells.x * (cells.y - 1):
		found.append(at + cells.x)
	return found


# Finds the docking port axis from the bottom port, which nothing else ever sits beside.
func _find_ports(side: Dictionary) -> Dictionary:
	var cells: Vector2i = side["cells"]
	var keep: PackedByteArray = side["keep"]
	var used: Rect2i = side["used"]
	var bottom: int = used.end.y - 1
	var low: int = cells.x
	var high: int = 0
	for cy in range(bottom - 4, bottom + 1):
		for cx in range(cells.x):
			if keep[cy * cells.x + cx] == 1:
				low = mini(low, cx)
				high = maxi(high, cx)
	var axis: int = (low + high) / 2
	var top: int = used.position.y
	while top < bottom and keep[top * cells.x + axis] == 0:
		top += 1
	var half_width: int = maxi(axis - used.position.x, used.end.x - 1 - axis)
	return {"axis": axis, "top": top, "bottom": bottom, "half_width": half_width}


# Writes a side onto its canvas, and gives it its 1 px dark outline back.
func _save(side: Dictionary, ports: Dictionary, size: Vector2i, half: int, above: int, path: String) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var cells: Vector2i = side["cells"]
	var dark_outline: int = _darkest()
	var opaque := PackedByteArray()
	opaque.resize(size.x * size.y)
	var outlined := PackedByteArray()
	outlined.resize(size.x * size.y)
	for cy in range(cells.y):
		for cx in range(cells.x):
			var at: int = cy * cells.x + cx
			if side["keep"][at] == 0:
				continue
			var x: int = cx - ports["axis"] + half
			var y: int = cy - ports["bottom"] + above
			if x < 0 or y < 0 or x >= size.x or y >= size.y:
				continue
			var index: int = side["color"][at]
			image.set_pixel(x, y, _color_of(index))
			opaque[y * size.x + x] = 1
			outlined[y * size.x + x] = 1 if index == dark_outline else 0
	for y in range(size.y):
		for x in range(size.x):
			if opaque[y * size.x + x] == 1:
				continue
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = Vector2i(x, y) + offset
				if near.x < 0 or near.y < 0 or near.x >= size.x or near.y >= size.y:
					continue
				if opaque[near.y * size.x + near.x] == 1 and outlined[near.y * size.x + near.x] == 0:
					image.set_pixel(x, y, _color_of(dark_outline))
					break
	image.save_png(ProjectSettings.globalize_path(path))


func _color_of(index: int) -> Color:
	return Color8(_palette[index * 3], _palette[index * 3 + 1], _palette[index * 3 + 2])


func _darkest() -> int:
	var best: int = 0
	for index in range(_palette.size() / 3):
		var total: int = _palette[index * 3] + _palette[index * 3 + 1] + _palette[index * 3 + 2]
		if total < _palette[best * 3] + _palette[best * 3 + 1] + _palette[best * 3 + 2]:
			best = index
	return best


# The nearest palette color, measured the way the eye sees. Remembered, since colors repeat a lot.
func _nearest_color(r: int, g: int, b: int) -> int:
	var key: int = (r >> 2) << 12 | (g >> 2) << 6 | (b >> 2)
	if _nearest.has(key):
		return _nearest[key]
	var best: int = _nearest_to(_to_oklab(r, g, b))
	_nearest[key] = best
	return best


func _nearest_to(lab: Vector3) -> int:
	var best: int = 0
	var best_distance: float = INF
	for index in range(_palette_lab.size()):
		var gap: Vector3 = lab - _palette_lab[index]
		var distance: float = gap.x * gap.x * BRIGHTNESS_WEIGHT + gap.y * gap.y + gap.z * gap.z
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


# Oklab: lightness, then green to red, then blue to yellow.
func _to_oklab(r8: int, g8: int, b8: int) -> Vector3:
	var r: float = _to_linear(r8)
	var g: float = _to_linear(g8)
	var b: float = _to_linear(b8)
	var l: float = pow(0.4122 * r + 0.5363 * g + 0.0514 * b, 1.0 / 3.0)
	var m: float = pow(0.2119 * r + 0.6807 * g + 0.1074 * b, 1.0 / 3.0)
	var s: float = pow(0.0883 * r + 0.2817 * g + 0.6300 * b, 1.0 / 3.0)
	return Vector3(
			0.2105 * l + 0.7936 * m - 0.0041 * s,
			1.9780 * l - 2.4286 * m + 0.4506 * s,
			0.0259 * l + 0.7828 * m - 0.8087 * s)


func _to_linear(channel: int) -> float:
	var value: float = channel / 255.0
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
