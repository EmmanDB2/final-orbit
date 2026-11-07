# make_icons.gd: makes Android's icon layers from art/final_orbit_icon.png: the patch on a clear
# background, small enough that no launcher's mask clips it, a dark layer behind it, and a single-color
# one for themed icons. Only needs running again if the patch changes. Run with:
#   godot --headless --path . --script tools/make_icons.gd
extends SceneTree

const SIZE: int = 432
## How much of the layer the patch fills. Launchers only promise to show the middle 61 percent, and
## the patch is round, so it can go a little past that.
const PATCH_SHARE: float = 0.72


func _initialize() -> void:
	var patch: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/final_orbit_icon.png"))
	patch.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = patch.get_used_rect()
	patch = patch.get_region(used)
	var fit: float = SIZE * PATCH_SHARE / maxf(used.size.x, used.size.y)
	var size := Vector2i(roundi(used.size.x * fit), roundi(used.size.y * fit))
	# An icon isn't a sprite in the game, and it shrinks a long way, so smoothing is right here.
	patch.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var front := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	front.blit_rect(patch, Rect2i(Vector2i.ZERO, size), (Vector2i(SIZE, SIZE) - size) / 2)
	front.save_png(ProjectSettings.globalize_path("res://art/icon/icon_foreground.png"))
	# Themed icons only use how see-through a layer is, so the patch's light parts make the picture.
	var single := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var color: Color = front.get_pixel(x, y)
			single.set_pixel(x, y, Color(1.0, 1.0, 1.0, color.a * clampf(color.get_luminance() * 1.6, 0.0, 1.0)))
	single.save_png(ProjectSettings.globalize_path("res://art/icon/icon_monochrome.png"))
	var back := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	back.fill(UiStyle.palette().hull_darkest)
	back.save_png(ProjectSettings.globalize_path("res://art/icon/icon_background.png"))
	print("patch used ", used, " placed at ", size)
	quit()
