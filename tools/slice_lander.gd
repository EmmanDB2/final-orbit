# slice_lander.gd: cuts art/ship_lander.png into one PNG per module, plus one per landing leg,
# in art/lander/. From DESIGN.md, "Ships" (modules snap to a fixed grid).
#
# This only needs running again if the whole-ship drawing changes. Every pixel goes into
# exactly one piece, so the pieces put back together match the drawing exactly. Run with:
#   godot --headless --path . --script tools/slice_lander.gd
extends SceneTree

const CELL: int = 64
## Where the art's top-left corner sits on the 2 x 4 module grid.
const ART_ON_GRID := Vector2i(8, 22)
const NAMES: Array = [
	["cockpit_left", "cockpit_right"],
	["rcs_left", "rcs_right"],
	["tank_left", "tank_right"],
	["engine_left", "engine_right"],
]


func _initialize() -> void:
	var art: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/ship_lander.png"))
	art.convert(Image.FORMAT_RGBA8)
	var used := PackedByteArray()
	used.resize(art.get_width() * art.get_height())
	used.fill(0)

	_save_leg(art, used, "leg_left", _in_left_leg)
	_save_leg(art, used, "leg_right", _in_right_leg)

	for row in range(NAMES.size()):
		for column in range(2):
			var piece := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
			var cell := Vector2i(column, row) * CELL
			for y in range(art.get_height()):
				for x in range(art.get_width()):
					var on_grid := Vector2i(x, y) + ART_ON_GRID
					var local: Vector2i = on_grid - cell
					if local.x < 0 or local.y < 0 or local.x >= CELL or local.y >= CELL:
						continue
					if used[y * art.get_width() + x] == 0:
						piece.set_pixel(local.x, local.y, art.get_pixel(x, y))
			piece.save_png(ProjectSettings.globalize_path("res://art/lander/%s.png" % NAMES[row][column]))
	quit()


# Saves one leg cropped to its own size, and prints where it goes on the module grid.
func _save_leg(art: Image, used: PackedByteArray, leg_name: String, is_leg: Callable) -> void:
	var low := Vector2i(art.get_size())
	var high := Vector2i(-1, -1)
	for y in range(art.get_height()):
		for x in range(art.get_width()):
			if art.get_pixel(x, y).a >= 0.5 and is_leg.call(x, y):
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	var piece := Image.create(high.x - low.x + 1, high.y - low.y + 1, false, Image.FORMAT_RGBA8)
	var count: int = 0
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if art.get_pixel(x, y).a >= 0.5 and is_leg.call(x, y):
				piece.set_pixel(x - low.x, y - low.y, art.get_pixel(x, y))
				used[y * art.get_width() + x] = 1
				count += 1
	piece.save_png(ProjectSettings.globalize_path("res://art/lander/%s.png" % leg_name))
	print("%s: %d pixels, %s, grid position %s" % [leg_name, count, piece.get_size(), low + ART_ON_GRID])


# The foot pad, its neck, the post, the sleeve, and the brace, leaving out the hull beside it
# and the tank below it.
func _in_left_leg(x: int, y: int) -> bool:
	if y < 78 or y > 122:
		return false
	if y > 120:
		return x <= 10
	if y <= 82:
		return x <= 18
	if y >= 116:
		return x <= 13
	if y >= 96:
		return x <= 21
	return x <= 18


func _in_right_leg(x: int, y: int) -> bool:
	if y < 77 or y > 122:
		return false
	if y > 120:
		return x >= 99
	if y >= 116:
		return x >= 95
	if y >= 110:
		return x >= 89
	if y >= 100:
		return x >= 90
	return x >= 91
