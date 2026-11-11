# screen_fit.gd: makes the game fill any screen exactly, on whole-number pixels.
# From DESIGN.md, "Platform: Galaxy Z Fold 8" (one internal resolution per screen, each
# scaling by whole numbers).
#
# The pixel scale is the screen's short side divided by design_height, rounded to a whole
# number so pixels stay crisp. The game's size is then the screen divided by that scale,
# so it fills the screen. This runs again whenever the screen changes, such as a fold.
# It watches the window's size directly, because Godot's size_changed signal only fires
# when the game's internal size changes, which isn't every time the screen does.
extends Node

## Emitted with the game's size in game pixels, and how far in from the top-left and
## bottom-right the UI has to stay to avoid cutouts and system bars.
signal screen_fitted(view_size: Vector2, inset_top_left: Vector2, inset_bottom_right: Vector2)

## The short side the game is designed around, in game pixels.
@export var design_height: int = 616

var _fitted_screen: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_fit_to_screen()


## Fits again now, for something that starts listening after the first fit.
func refit() -> void:
	_fit_to_screen()


func _process(_delta: float) -> void:
	if get_window().size != _fitted_screen:
		_fit_to_screen()


func _fit_to_screen() -> void:
	var window: Window = get_window()
	var screen: Vector2i = window.size
	_fitted_screen = screen
	if screen.x <= 0 or screen.y <= 0:
		return

	var pixel_scale: int = maxi(1, roundi(float(mini(screen.x, screen.y)) / design_height))
	var view_size: Vector2i = screen / pixel_scale
	if window.content_scale_size != view_size:
		window.content_scale_size = view_size

	var inset_top_left := Vector2.ZERO
	var inset_bottom_right := Vector2.ZERO
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		inset_top_left = Vector2(safe.position) / pixel_scale
		inset_bottom_right = Vector2(screen - safe.end) / pixel_scale
	screen_fitted.emit(Vector2(view_size), inset_top_left, inset_bottom_right)
