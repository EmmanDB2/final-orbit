# split_moon_pad.gd: splits the moon base's tower sheet from the asset editor into two sprites, the
# tanks and tower, and the landing pad, so the pad can be set into the ground, flush with it, while
# the tanks and tower stand on it. Only cuts and clears pixels: nothing is resized or recolored.
# From DESIGN.md, "Places on worlds" (moon base).
#
# Reads art/moon_base/source/tower_and_pad.png, the asset editor's launch_pad.png, and writes
# art/moon_base/tower.png and art/moon_base/pad.png. Only needs running again if the sheet changes:
#   godot --headless --path . --script tools/split_moon_pad.gd
extends SceneTree

const SOURCE := "res://art/moon_base/source/tower_and_pad.png"
## The pad's corner on the sheet: everything right of and below it is pad, and nothing else is.
const PAD_CORNER := Vector2i(262, 320)
## How wide the tanks and tower are on the sheet, swing arms included.
const TOWER_WIDTH: int = 380


func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	sheet.convert(Image.FORMAT_RGBA8)
	var pad: Image = sheet.get_region(Rect2i(PAD_CORNER, sheet.get_size() - PAD_CORNER))
	var tower: Image = sheet.get_region(Rect2i(0, 0, TOWER_WIDTH, sheet.get_height()))
	tower.fill_rect(Rect2i(PAD_CORNER, Vector2i(TOWER_WIDTH, sheet.get_height()) - PAD_CORNER), Color(0, 0, 0, 0))
	pad.save_png(ProjectSettings.globalize_path("res://art/moon_base/pad.png"))
	tower.save_png(ProjectSettings.globalize_path("res://art/moon_base/tower.png"))
	print("pad %s, tower %s" % [pad.get_size(), tower.get_size()])
	quit()
