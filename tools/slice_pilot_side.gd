# slice_pilot_side.gd: turns the side-view astronaut sheet in art/pilot/source/ into a clean sprite sheet
# at art/pilot/pilot_side.png. The sheet is a grid of 8 x 6 cells on magenta, made from
# side_view_layout_template.png: rows for idle, walking, jumping, climbing, using a terminal, and a
# jetpack hover, all facing right. It drops the background, reads the fake pixels back down to real ones,
# and forces the agency palette. Frames standing on the ground keep their feet on one line, and frames in
# the air keep the helmet where it is when standing, so the pilot doesn't jump around between frames.
# From DESIGN.md, "Player" and "Art direction". Only needs running again if the sheet changes. Run with:
#   godot --headless --path . --script tools/slice_pilot_side.gd
extends SceneTree

## How wide one fake pixel is in the sheet, in source pixels.
const SOURCE_PIXEL: float = 3.2
## Where the fake-pixel grid starts, measured from the edges in the sheet: the same everywhere on it.
const GRID_START := Vector2(2.7, 1.25)
const COLUMNS: int = 8
const ROWS: int = 6
## How many frames each row holds.
const ROW_FRAMES: Array = [4, 8, 6, 4, 3, 4]
## Which frames stand on the ground, by row: the rest are in the air or on a ladder.
const GROUNDED: Array = [[0, 1, 2, 3], [0, 1, 2, 3, 4, 5, 6, 7], [0, 5], [], [0, 1, 2], []]
## Each frame's size in the finished sheet, and where the feet stand in it.
const FRAME: int = 64
const FEET_Y: int = 58
## The suit is grays, told apart by brightness alone, so brightness counts in full.
const BRIGHTNESS_WEIGHT: float = 1.0
## The palette colors the suit is drawn in, the same list the Gemini prompt gave. Glass, light blue,
## telemetry, and red colors are left out, since near-grays would otherwise turn bluish or green.
const SUIT_COLORS: Array = [
	"hull_darkest", "hull_dark", "hull_mid", "hull_light", "hull_lighter", "hull_lightest",
	"agency_orange", "agency_orange_dark", "agency_orange_light", "agency_blue",
	"gold_darkest", "gold_dark", "gold", "gold_light", "thrust_white", "thrust_yellow", "thrust_red",
]
## Pieces this small that touch nothing are noise, unless they're bright, like flames.
const SMALLEST_PIECE: int = 5

var _palette := PackedInt32Array()
var _palette_lab := PackedVector3Array()
var _thrust := PackedInt32Array()
var _gold := {}
var _nearest := {}


func _initialize() -> void:
	var palette: Resource = load("res://data/agency_palette.tres")
	for property: Dictionary in palette.get_property_list():
		if property["type"] == TYPE_COLOR and SUIT_COLORS.has(property["name"]):
			var color: Color = palette.get(property["name"])
			if property["name"].begins_with("gold"):
				_gold[_palette.size() / 3] = true
			if property["name"].begins_with("thrust_"):
				_thrust.append(_palette.size() / 3)
			_palette.append(color.r8)
			_palette.append(color.g8)
			_palette.append(color.b8)
			_palette_lab.append(_to_oklab(color.r8, color.g8, color.b8))

	var source: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/pilot/source/pilot_side_sheet.png"))
	source.convert(Image.FORMAT_RGB8)
	var cell := Vector2(source.get_width() / float(COLUMNS), source.get_height() / float(ROWS))
	var frames: Array = []
	for row in range(ROWS):
		for column in range(ROW_FRAMES[row]):
			var box := Rect2i(Vector2i((Vector2(column, row) * cell).round()) + Vector2i(1, 1), Vector2i(cell.round()) - Vector2i(2, 2))
			frames.append({"row": row, "column": column, "read": _read_frame(source, box, row == 5)})

	# Where the standing pilot's visor sits, which every other frame lines up with.
	var standing: Dictionary = frames[0]["read"]
	var visor_offset: Vector2 = standing["visor"] - Vector2(standing["middle_x"], standing["feet"])
	var visor_at := Vector2(FRAME / 2.0, FEET_Y) + visor_offset

	var sheet := Image.create(FRAME * COLUMNS, FRAME * ROWS, false, Image.FORMAT_RGBA8)
	for entry: Dictionary in frames:
		var read: Dictionary = entry["read"]
		var shift: Vector2 = visor_at - read["visor"]
		if GROUNDED[entry["row"]].has(entry["column"]):
			shift.y = FEET_Y - 1 - read["feet"]
		var place := Vector2i(entry["column"], entry["row"]) * FRAME
		var image: Image = read["image"]
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color: Color = image.get_pixel(x, y)
				if color.a == 0.0:
					continue
				var at: Vector2i = Vector2i(x, y) + Vector2i(shift.round())
				if at.x >= 0 and at.y >= 0 and at.x < FRAME and at.y < FRAME:
					sheet.set_pixelv(place + at, color)
	sheet.save_png(ProjectSettings.globalize_path("res://art/pilot/pilot_side.png"))
	print("standing pilot: visor %s from the feet, %d px tall" % [visor_offset, int(standing["feet"] - standing["top"]) + 1])
	quit()


# Magenta, the darker purple of the empty cells, and the light pink cell borders are all background.
func _is_background(r: int, g: int, b: int) -> bool:
	return r - g > 40 and b - g > 40


# Reads one cell into an image of its own fake pixels, with the visor, feet, and middle found.
func _read_frame(source: Image, box: Rect2i, flames: bool) -> Dictionary:
	var w: int = source.get_width()
	var data: PackedByteArray = source.get_data()
	var first := Vector2i(((Vector2(box.position) - GRID_START) / SOURCE_PIXEL).ceil())
	var start: Vector2 = GRID_START + Vector2(first) * SOURCE_PIXEL
	var cells := Vector2i(((Vector2(box.end) - start) / SOURCE_PIXEL).floor())
	var color := PackedInt32Array()
	var keep := PackedByteArray()
	color.resize(cells.x * cells.y)
	keep.resize(cells.x * cells.y)
	for cy in range(cells.y):
		for cx in range(cells.x):
			var x0: float = GRID_START.x + (first.x + cx) * SOURCE_PIXEL
			var y0: float = GRID_START.y + (first.y + cy) * SOURCE_PIXEL
			var total := Vector3i.ZERO
			var samples: int = 0
			var background: int = 0
			for y in range(ceili(y0 + 0.6), ceili(y0 + SOURCE_PIXEL - 0.6)):
				for x in range(ceili(x0 + 0.6), ceili(x0 + SOURCE_PIXEL - 0.6)):
					var i: int = (y * w + x) * 3
					if _is_background(data[i], data[i + 1], data[i + 2]):
						background += 1
					else:
						total += Vector3i(data[i], data[i + 1], data[i + 2])
						samples += 1
			var at: int = cy * cells.x + cx
			if samples == 0 or background * 100 >= (samples + background) * 55:
				continue
			keep[at] = 1
			color[at] = _nearest_color(total.x / samples, total.y / samples, total.z / samples, flames)
	_drop_noise(cells, keep, color)

	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var top: int = cells.y
	var feet: int = 0
	var left: int = cells.x
	var right: int = 0
	for cy in range(cells.y):
		for cx in range(cells.x):
			var at: int = cy * cells.x + cx
			if keep[at] == 0:
				continue
			var index: int = color[at]
			image.set_pixel(cx, cy, Color8(_palette[index * 3], _palette[index * 3 + 1], _palette[index * 3 + 2]))
			top = mini(top, cy)
			feet = maxi(feet, cy)
			left = mini(left, cx)
			right = maxi(right, cx)
	return {"image": image, "visor": _find_visor(cells, keep, color), "feet": feet, "top": top, "middle_x": (left + right) / 2.0}


func _drop_noise(cells: Vector2i, keep: PackedByteArray, color: PackedInt32Array) -> void:
	var seen := PackedByteArray()
	seen.resize(keep.size())
	for start in range(keep.size()):
		if keep[start] == 0 or seen[start] == 1:
			continue
		var piece: Array[int] = [start]
		seen[start] = 1
		var walk: int = 0
		var flame: bool = false
		while walk < piece.size():
			flame = flame or _thrust.has(color[piece[walk]])
			for next: int in _around(piece[walk], cells):
				if keep[next] == 1 and seen[next] == 0:
					seen[next] = 1
					piece.append(next)
			walk += 1
		if piece.size() < SMALLEST_PIECE and not flame:
			for at: int in piece:
				keep[at] = 0


# The middle of the biggest patch of gold, which is the visor.
func _find_visor(cells: Vector2i, keep: PackedByteArray, color: PackedInt32Array) -> Vector2:
	var seen := PackedByteArray()
	seen.resize(keep.size())
	var best: Array[int] = []
	for start in range(keep.size()):
		if keep[start] == 0 or seen[start] == 1 or not _gold.has(color[start]):
			continue
		var piece: Array[int] = [start]
		seen[start] = 1
		var walk: int = 0
		while walk < piece.size():
			for next: int in _around(piece[walk], cells):
				if keep[next] == 1 and seen[next] == 0 and _gold.has(color[next]):
					seen[next] = 1
					piece.append(next)
			walk += 1
		if piece.size() > best.size():
			best = piece
	var total := Vector2.ZERO
	for at: int in best:
		total += Vector2(at % cells.x, at / cells.x)
	return total / maxi(best.size(), 1)


func _around(at: int, cells: Vector2i) -> Array[int]:
	var cx: int = at % cells.x
	var cy: int = at / cells.x
	var found: Array[int] = []
	for y in range(maxi(cy - 1, 0), mini(cy + 2, cells.y)):
		for x in range(maxi(cx - 1, 0), mini(cx + 2, cells.x)):
			if x != cx or y != cy:
				found.append(y * cells.x + x)
	return found


# The nearest palette color in Oklab. Thrust colors only count on the hover row, where there are flames.
func _nearest_color(r: int, g: int, b: int, flames: bool) -> int:
	var key: int = ((r >> 1) << 16 | (g >> 1) << 8 | (b >> 1)) * 2 + (1 if flames else 0)
	if _nearest.has(key):
		return _nearest[key]
	var lab: Vector3 = _to_oklab(r, g, b)
	var best: int = 0
	var best_distance: float = INF
	for index in range(_palette_lab.size()):
		if not flames and _thrust.has(index):
			continue
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
