# slice_launch_base.gd: turns the launch base concept images in art/launch_base/source/ into clean
# sprites in art/launch_base/. Each image holds a building's outside and its cutaway side by side,
# or the tower and pad alone, with a reference astronaut. Gemini drew these as smooth illustrations
# rather than on a grid of big square pixels, so this scales them down by the size of their doors:
# each source pixel snaps to the agency palette, and each sprite pixel takes the commonest color
# under it, leaning dark so the thin outlines survive. The outside and the cutaway come out on the
# same canvas, sampled from their own outlines so the two line up, standing on the canvas's bottom
# edge. From DESIGN.md, "Places on worlds" and "Art direction" (locked palette, 1 px dark outline).
# Only needs running again if the images change. Run with:
#   godot --headless --path . --script tools/slice_launch_base.gd
extends SceneTree

## How many world units, or sprite pixels, one source pixel becomes. Doors come out a little taller
## than the 37 px pilot, and the tower's crew arm comes out at the lander's cockpit.
const UNITS_PER_SOURCE_PIXEL: float = 0.65
## How many samples each way go into one sprite pixel.
const SAMPLES: int = 4
## How much more a dark sample counts than a light one, so outlines win against what's beside them.
const DARK_PULL: float = 1.6
## A sample this dark, in Oklab lightness, is an outline or deep shadow.
const DARK_LIGHTNESS: float = 0.3
## Pieces of art this small that touch nothing are specks, not parts of the building, in source
## pixels, and in sprite pixels once cut.
const SMALLEST_PIECE: int = 30
const SMALLEST_CUT_PIECE: int = 8
## Shading shouldn't change what color something is painted, so brightness counts for less than hue.
const BRIGHTNESS_WEIGHT: float = 0.5
## A lone pixel this close in lightness to what's around it is noise, not a detail like a light.
const SPECK_CONTRAST: float = 0.15

## Each image: what it's called here, and the source boxes of its outside and cutaway, with any patch
## to paint over where its astronaut overlaps the building, copied from this many rows above.
const PIECES: Array = [
	{"source": "vehicle_assembly", "name": "assembly", "outside": Rect2i(18, 18, 486, 712), "inside": Rect2i(520, 18, 476, 712),
			"patch": Rect2i(983, 662, 14, 50), "patch_from": 56},
	{"source": "launch_pad", "name": "tower", "outside": Rect2i(48, 20, 532, 714)},
	{"source": "mission_control", "name": "mission_control", "outside": Rect2i(12, 196, 484, 354), "inside": Rect2i(508, 196, 470, 354)},
]

## The agency colors buildings can use. Telemetry cyan is the UI's, the thrust colors are flames',
## and light blue is left out because bluish grays in the images would turn to it.
const COLORS: Array = [
	"hull_darkest", "hull_dark", "hull_mid", "hull_light", "hull_lighter", "hull_lightest",
	"agency_orange", "agency_orange_dark", "agency_orange_light", "agency_red",
	"agency_blue_dark", "agency_blue",
	"gold_darkest", "gold_dark", "gold", "gold_light", "glass_dark", "glass_light",
	"telemetry_green", "telemetry_amber",
]

var _palette: Array[Color] = []
var _palette_lab: PackedVector3Array = PackedVector3Array()
var _darkest: int = 0
var _nearest := {}


func _initialize() -> void:
	var agency: Resource = load("res://data/agency_palette.tres")
	for color_name: String in COLORS:
		var color: Color = agency.get(color_name)
		if color_name == "hull_darkest":
			_darkest = _palette.size()
		_palette.append(color)
		_palette_lab.append(_to_oklab(color))
	for piece: Dictionary in PIECES:
		var source: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/launch_base/source/%s.png" % piece["source"]))
		source.convert(Image.FORMAT_RGB8)
		if piece.has("patch"):
			_patch(source, piece["patch"], piece["patch_from"])
		var outside_box: Rect2i = _tight_box(source, piece["outside"])
		var size := Vector2i((Vector2(outside_box.size) * UNITS_PER_SOURCE_PIXEL).round())
		var outside: Image = _resample(source, outside_box, size)
		outside.save_png(ProjectSettings.globalize_path("res://art/launch_base/%s.png" % piece["name"]))
		var line: String = "%s: %d x %d px from %s" % [piece["name"], size.x, size.y, outside_box]
		if piece.has("inside"):
			var inside_box: Rect2i = _tight_box(source, piece["inside"])
			_resample(source, inside_box, size).save_png(ProjectSettings.globalize_path("res://art/launch_base/%s_interior.png" % piece["name"]))
			line += ", inside from %s" % inside_box
		print(line)
	quit()


# Paints over a patch with the rows above it, for where a reference astronaut stands on the art.
func _patch(source: Image, box: Rect2i, from_above: int) -> void:
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			source.set_pixel(x, y, source.get_pixel(x, y - from_above))


func _is_background(color: Color) -> bool:
	return color.r8 - color.g8 > 25 and color.b8 - color.g8 > 25


# The smallest box round the art in a source box, leaving out specks and the astronaut if it's apart.
func _tight_box(source: Image, box: Rect2i) -> Rect2i:
	var keep := PackedByteArray()
	keep.resize(box.size.x * box.size.y)
	for y in range(box.size.y):
		for x in range(box.size.x):
			if not _is_background(source.get_pixel(box.position.x + x, box.position.y + y)):
				keep[y * box.size.x + x] = 1
	# The biggest piece is the building; anything not touching it is left out.
	var seen := PackedByteArray()
	seen.resize(keep.size())
	var biggest := PackedInt32Array()
	for start in range(keep.size()):
		if keep[start] == 0 or seen[start] == 1:
			continue
		var piece := PackedInt32Array([start])
		seen[start] = 1
		var walk: int = 0
		while walk < piece.size():
			var at: int = piece[walk]
			var cx: int = at % box.size.x
			var cy: int = at / box.size.x
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + offset.x
				var ny: int = cy + offset.y
				if nx < 0 or ny < 0 or nx >= box.size.x or ny >= box.size.y:
					continue
				var next: int = ny * box.size.x + nx
				if keep[next] == 1 and seen[next] == 0:
					seen[next] = 1
					piece.append(next)
			walk += 1
		if piece.size() > biggest.size():
			biggest = piece
	var low := Vector2i(box.size)
	var high := Vector2i(-1, -1)
	for at: int in biggest:
		var p := Vector2i(at % box.size.x, at / box.size.x)
		low = Vector2i(mini(low.x, p.x), mini(low.y, p.y))
		high = Vector2i(maxi(high.x, p.x), maxi(high.y, p.y))
	return Rect2i(box.position + low, high - low + Vector2i.ONE)


# Samples a source box down to a sprite of this size: each pixel is the commonest palette color
# among the samples under it, with dark ones counting extra, or clear when most samples are.
func _resample(source: Image, box: Rect2i, size: Vector2i) -> Image:
	var index := PackedInt32Array()
	index.resize(size.x * size.y)
	var step := Vector2(box.size) / Vector2(size)
	for y in range(size.y):
		for x in range(size.x):
			var votes := {}
			var clear: int = 0
			for sy in range(SAMPLES):
				for sx in range(SAMPLES):
					var at: Vector2 = Vector2(box.position) + (Vector2(x, y) + (Vector2(sx, sy) + Vector2(0.5, 0.5)) / SAMPLES) * step
					var color: Color = source.get_pixel(clampi(int(at.x), 0, source.get_width() - 1), clampi(int(at.y), 0, source.get_height() - 1))
					if _is_background(color):
						clear += 1
						continue
					var chosen: int = _nearest_color(color)
					var weight: float = DARK_PULL if _palette_lab[chosen].x < DARK_LIGHTNESS else 1.0
					votes[chosen] = votes.get(chosen, 0.0) + weight
			var best: int = -1
			var best_votes: float = 0.0
			for chosen: int in votes:
				if votes[chosen] > best_votes:
					best_votes = votes[chosen]
					best = chosen
			index[y * size.x + x] = best if clear * 2 < SAMPLES * SAMPLES else -1
	_clean_specks(index, size)
	_drop_loose_bits(index, size)
	_outline(index, size)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		for x in range(size.x):
			var chosen: int = index[y * size.x + x]
			if chosen >= 0:
				image.set_pixel(x, y, _palette[chosen])
	return image


# A pixel with no neighbor of its own color, and close in lightness to its neighbors, takes their
# commonest color.
func _clean_specks(index: PackedInt32Array, size: Vector2i) -> void:
	var before: PackedInt32Array = index.duplicate()
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var here: int = before[y * size.x + x]
			if here < 0:
				continue
			var counts := {}
			var alone: bool = true
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var other: int = before[(y + offset.y) * size.x + x + offset.x]
				if other == here:
					alone = false
				counts[other] = counts.get(other, 0) + 1
			if not alone:
				continue
			var common: int = here
			var most: int = 0
			for other: int in counts:
				if counts[other] > most:
					most = counts[other]
					common = other
			if common >= 0 and absf(_palette_lab[common].x - _palette_lab[here].x) < SPECK_CONTRAST:
				index[y * size.x + x] = common


# Little pieces left floating once cut, where thin lines broke up, go.
func _drop_loose_bits(index: PackedInt32Array, size: Vector2i) -> void:
	var seen := PackedByteArray()
	seen.resize(index.size())
	for start in range(index.size()):
		if index[start] < 0 or seen[start] == 1:
			continue
		var piece := PackedInt32Array([start])
		seen[start] = 1
		var walk: int = 0
		while walk < piece.size():
			var at: int = piece[walk]
			var cx: int = at % size.x
			var cy: int = at / size.x
			for y in range(maxi(cy - 1, 0), mini(cy + 2, size.y)):
				for x in range(maxi(cx - 1, 0), mini(cx + 2, size.x)):
					var next: int = y * size.x + x
					if index[next] >= 0 and seen[next] == 0:
						seen[next] = 1
						piece.append(next)
			walk += 1
		if piece.size() < SMALLEST_CUT_PIECE:
			for at: int in piece:
				index[at] = -1


# The outermost pixels of the art become the 1 px dark outline, keeping its size.
func _outline(index: PackedInt32Array, size: Vector2i) -> void:
	var before: PackedInt32Array = index.duplicate()
	for y in range(size.y):
		for x in range(size.x):
			if before[y * size.x + x] < 0:
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				# The bottom edge stands on the ground, so it isn't outlined against the canvas's edge.
				if ny >= size.y:
					continue
				if nx < 0 or nx >= size.x or ny < 0 or before[ny * size.x + nx] < 0:
					index[y * size.x + x] = _darkest
					break


func _nearest_color(color: Color) -> int:
	var key: int = (color.r8 >> 2) << 12 | (color.g8 >> 2) << 6 | (color.b8 >> 2)
	if _nearest.has(key):
		return _nearest[key]
	var lab: Vector3 = _to_oklab(color)
	var best: int = 0
	var best_distance: float = INF
	for i in range(_palette_lab.size()):
		var gap: Vector3 = lab - _palette_lab[i]
		var distance: float = gap.x * gap.x * BRIGHTNESS_WEIGHT + gap.y * gap.y + gap.z * gap.z
		if distance < best_distance:
			best_distance = distance
			best = i
	_nearest[key] = best
	return best


func _to_oklab(color: Color) -> Vector3:
	var linear: Color = color.srgb_to_linear()
	var l: float = pow(0.4122 * linear.r + 0.5363 * linear.g + 0.0514 * linear.b, 1.0 / 3.0)
	var m: float = pow(0.2119 * linear.r + 0.6807 * linear.g + 0.1074 * linear.b, 1.0 / 3.0)
	var s: float = pow(0.0883 * linear.r + 0.2817 * linear.g + 0.6300 * linear.b, 1.0 / 3.0)
	return Vector3(
			0.2105 * l + 0.7936 * m - 0.0041 * s,
			1.9780 * l - 2.4286 * m + 0.4506 * s,
			0.0259 * l + 0.7828 * m - 0.8087 * s)
