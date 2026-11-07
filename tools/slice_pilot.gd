# slice_pilot.gd: turns the astronaut sheet in art/pilot/source/ into a clean sprite sheet at
# art/pilot/pilot_eva.png: five frames across, and rows for facing down, facing right, jetting down,
# and jetting right. It drops the background, reads the fake pixels back down to real ones, forces the
# agency palette, and lines each frame up on the helmet, so the pilot doesn't jump between frames.
# From DESIGN.md, "Player" and "Art direction". Only needs running again if the sheet changes. Run with:
#   godot --headless --path . --script tools/slice_pilot.gd
extends SceneTree

## How wide one fake pixel is in the sheet, in source pixels.
const SOURCE_PIXEL: float = 3.2
## Where the gaps between the sheet's columns and rows are, in source pixels.
const COLUMN_GAPS: Array = [0, 212, 415, 618, 820, 1024]
const ROW_GAPS: Array = [0, 193, 373, 574, 765]
## Each frame's size in the finished sheet, with the helmet in the middle.
const FRAME: int = 96
## How far a color can be from the background and still count as it.
const BACKGROUND_REACH: int = 26
## Shading shouldn't change what color something is painted, so brightness counts for less than hue.
const BRIGHTNESS_WEIGHT: float = 0.35
## Pieces this small that touch nothing are noise, unless they're the sparks around a flame.
const SMALLEST_PIECE: int = 6

var _palette := PackedInt32Array()
var _palette_lab := PackedVector3Array()
var _nearest := {}
var _helmet_color: int = 0


func _initialize() -> void:
	var palette: Resource = load("res://data/agency_palette.tres")
	for property: Dictionary in palette.get_property_list():
		if property["type"] == TYPE_COLOR:
			var color: Color = palette.get(property["name"])
			_palette.append(color.r8)
			_palette.append(color.g8)
			_palette.append(color.b8)
			_palette_lab.append(_to_oklab(color.r8, color.g8, color.b8))
	var hull: Color = palette.get("hull_lightest")
	_helmet_color = _nearest_color(hull.r8, hull.g8, hull.b8)

	var source: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/pilot/source/pilot_eva_sheet.webp"))
	source.convert(Image.FORMAT_RGB8)
	var phase: Vector2 = _find_phase(source)
	var sheet := Image.create(FRAME * 5, FRAME * 4, false, Image.FORMAT_RGBA8)
	for row in range(4):
		for column in range(5):
			var box := Rect2i(COLUMN_GAPS[column], ROW_GAPS[row], COLUMN_GAPS[column + 1] - COLUMN_GAPS[column], ROW_GAPS[row + 1] - ROW_GAPS[row])
			var frame: Image = _read_frame(source, box, phase, row >= 2)
			sheet.blit_rect(frame, Rect2i(0, 0, FRAME, FRAME), Vector2i(column, row) * FRAME)
	sheet.save_png(ProjectSettings.globalize_path("res://art/pilot/pilot_eva.png"))
	quit()


func _find_phase(source: Image) -> Vector2:
	var w: int = source.get_width()
	var h: int = source.get_height()
	var data: PackedByteArray = source.get_data()
	var across := Vector2.ZERO
	var down := Vector2.ZERO
	for y in range(0, h - 1):
		for x in range(0, w - 1):
			var i: int = (y * w + x) * 3
			var here: int = data[i] + data[i + 1] + data[i + 2]
			var right: int = data[i + 3] + data[i + 4] + data[i + 5]
			var below: int = data[i + w * 3] + data[i + w * 3 + 1] + data[i + w * 3 + 2]
			var angle_x: float = TAU * (x + 0.5) / SOURCE_PIXEL
			var angle_y: float = TAU * (y + 0.5) / SOURCE_PIXEL
			across += Vector2(cos(angle_x), sin(angle_x)) * absi(here - right)
			down += Vector2(cos(angle_y), sin(angle_y)) * absi(here - below)
	return Vector2(fposmod(across.angle(), TAU), fposmod(down.angle(), TAU)) / TAU * SOURCE_PIXEL


# Reads one frame of the sheet into a square with the helmet in the middle.
func _read_frame(source: Image, box: Rect2i, phase: Vector2, keeps_sparks: bool) -> Image:
	var w: int = source.get_width()
	var data: PackedByteArray = source.get_data()
	var background := Vector3i(data[(3 * w + 3) * 3], data[(3 * w + 3) * 3 + 1], data[(3 * w + 3) * 3 + 2])
	var first := Vector2i(floori((box.position.x - phase.x) / SOURCE_PIXEL), floori((box.position.y - phase.y) / SOURCE_PIXEL))
	var cells := Vector2i(floori(box.size.x / SOURCE_PIXEL), floori(box.size.y / SOURCE_PIXEL))
	var color := PackedInt32Array()
	var empty := PackedByteArray()
	color.resize(cells.x * cells.y)
	empty.resize(cells.x * cells.y)
	for cy in range(cells.y):
		var y0: float = phase.y + (first.y + cy) * SOURCE_PIXEL
		for cx in range(cells.x):
			var x0: float = phase.x + (first.x + cx) * SOURCE_PIXEL
			var total := Vector3i.ZERO
			var samples: int = 0
			var like_background: int = 0
			# The middle of each fake pixel, away from the blur at its edges.
			for y in range(ceili(y0 + 0.6), ceili(y0 + SOURCE_PIXEL - 0.6)):
				for x in range(ceili(x0 + 0.6), ceili(x0 + SOURCE_PIXEL - 0.6)):
					if x < 0 or y < 0 or x >= w or y >= source.get_height():
						continue
					var i: int = (y * w + x) * 3
					total += Vector3i(data[i], data[i + 1], data[i + 2])
					samples += 1
					if absi(data[i] - background.x) + absi(data[i + 1] - background.y) + absi(data[i + 2] - background.z) <= BACKGROUND_REACH:
						like_background += 1
			var at: int = cy * cells.x + cx
			if samples == 0:
				empty[at] = 1
				continue
			color[at] = _nearest_color(total.x / samples, total.y / samples, total.z / samples)
			empty[at] = 1 if like_background * 100 >= samples * 60 else 0

	var keep: PackedByteArray = _clear_outside(cells, empty)
	_drop_noise(cells, keep, color, keeps_sparks)
	var helmet: Vector2 = _find_helmet(cells, keep, color)
	var image := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	for cy in range(cells.y):
		for cx in range(cells.x):
			if keep[cy * cells.x + cx] == 0:
				continue
			var place: Vector2i = Vector2i(cx, cy) - Vector2i(helmet.round()) + Vector2i(FRAME, FRAME) / 2
			if place.x >= 0 and place.y >= 0 and place.x < FRAME and place.y < FRAME:
				var index: int = color[cy * cells.x + cx]
				image.set_pixelv(place, Color8(_palette[index * 3], _palette[index * 3 + 1], _palette[index * 3 + 2]))
	return image


# Everything reached from the frame's edge through background is gone. Pockets of background closed
# off inside are too, if they're big enough not to be shading.
func _clear_outside(cells: Vector2i, empty: PackedByteArray) -> PackedByteArray:
	var keep := PackedByteArray()
	keep.resize(empty.size())
	keep.fill(1)
	var seen := PackedByteArray()
	seen.resize(empty.size())
	var stack: Array[int] = []
	for at in range(empty.size()):
		var cx: int = at % cells.x
		var cy: int = at / cells.x
		if empty[at] == 1 and (cx == 0 or cy == 0 or cx == cells.x - 1 or cy == cells.y - 1):
			stack.append(at)
			seen[at] = 1
	while not stack.is_empty():
		var at: int = stack.pop_back()
		keep[at] = 0
		for next: int in _around(at, cells, false):
			if empty[next] == 1 and seen[next] == 0:
				seen[next] = 1
				stack.append(next)
	for start in range(empty.size()):
		if empty[start] == 0 or seen[start] == 1:
			continue
		var pocket: Array[int] = [start]
		seen[start] = 1
		var walk: int = 0
		while walk < pocket.size():
			for next: int in _around(pocket[walk], cells, false):
				if empty[next] == 1 and seen[next] == 0:
					seen[next] = 1
					pocket.append(next)
			walk += 1
		if pocket.size() >= 8:
			for at: int in pocket:
				keep[at] = 0
	return keep


func _drop_noise(cells: Vector2i, keep: PackedByteArray, color: PackedInt32Array, keeps_sparks: bool) -> void:
	var seen := PackedByteArray()
	seen.resize(keep.size())
	for start in range(keep.size()):
		if keep[start] == 0 or seen[start] == 1:
			continue
		var piece: Array[int] = [start]
		seen[start] = 1
		var walk: int = 0
		var bright: bool = false
		while walk < piece.size():
			var lab: Vector3 = _palette_lab[color[piece[walk]]]
			bright = bright or Vector2(lab.y, lab.z).length() > 0.09
			for next: int in _around(piece[walk], cells, true):
				if keep[next] == 1 and seen[next] == 0:
					seen[next] = 1
					piece.append(next)
			walk += 1
		if piece.size() < SMALLEST_PIECE and not (keeps_sparks and bright):
			for at: int in piece:
				keep[at] = 0


# The middle of the biggest patch of the helmet's color.
func _find_helmet(cells: Vector2i, keep: PackedByteArray, color: PackedInt32Array) -> Vector2:
	var seen := PackedByteArray()
	seen.resize(keep.size())
	var best: Array[int] = []
	for start in range(keep.size()):
		if keep[start] == 0 or seen[start] == 1 or color[start] != _helmet_color:
			continue
		var piece: Array[int] = [start]
		seen[start] = 1
		var walk: int = 0
		while walk < piece.size():
			for next: int in _around(piece[walk], cells, false):
				if keep[next] == 1 and seen[next] == 0 and color[next] == _helmet_color:
					seen[next] = 1
					piece.append(next)
			walk += 1
		if piece.size() > best.size():
			best = piece
	var total := Vector2.ZERO
	for at: int in best:
		total += Vector2(at % cells.x, at / cells.x)
	return total / maxi(best.size(), 1)


func _around(at: int, cells: Vector2i, corners: bool) -> Array[int]:
	var cx: int = at % cells.x
	var cy: int = at / cells.x
	var found: Array[int] = []
	for y in range(maxi(cy - 1, 0), mini(cy + 2, cells.y)):
		for x in range(maxi(cx - 1, 0), mini(cx + 2, cells.x)):
			if (x != cx or y != cy) and (corners or x == cx or y == cy):
				found.append(y * cells.x + x)
	return found


func _nearest_color(r: int, g: int, b: int) -> int:
	var key: int = (r >> 1) << 16 | (g >> 1) << 8 | (b >> 1)
	if _nearest.has(key):
		return _nearest[key]
	var lab: Vector3 = _to_oklab(r, g, b)
	var best: int = 0
	var best_distance: float = INF
	for index in range(_palette_lab.size()):
		var gap: Vector3 = lab - _palette_lab[index]
		var distance: float = gap.x * gap.x * BRIGHTNESS_WEIGHT + gap.y * gap.y + gap.z * gap.z
		if distance < best_distance:
			best_distance = distance
			best = index
	_nearest[key] = best
	return best


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
