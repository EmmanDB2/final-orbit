# starfield.gd: scrolls starfield.gdshader to match how the view moves.
# From DESIGN.md, "Art direction" (space is shaders and code) and "Physics"
# (floating origin).
#
# The GPU only has 32-bit floats, so each layer's scroll is added up and wrapped to
# the size of the star pattern here, in 64-bit, before it is sent over. That keeps the
# stars steady no matter how far the ship has flown.
extends ColorRect

## Size of the repeating star pattern. Must match the constants in the shader.
const TILE_PIXELS: float = 16384.0

## How far each layer scrolls per pixel the view moves, farthest first.
@export var parallax: PackedFloat64Array = PackedFloat64Array([0.05, 0.15, 0.4])
## Real stars barely move at orbital speed, so fast motion gets squeezed toward this
## many pixels per tick. Slow motion is nearly unaffected.
@export var scroll_speed_limit: float = 20.0

var _scroll_x: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var _scroll_y: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var _last_center_x: float = 0.0
var _last_center_y: float = 0.0
var _last_pixels_per_unit: float = 0.0

@onready var _material: ShaderMaterial = material


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	# The very first view has nothing to compare with. After that the view never jumps,
	# so the stars keep moving through zooms too.
	if _last_pixels_per_unit > 0.0:
		var moved_x: float = (center_x - _last_center_x) * pixels_per_unit
		var moved_y: float = (center_y - _last_center_y) * pixels_per_unit
		var speed: float = sqrt(moved_x * moved_x + moved_y * moved_y)
		var squeeze: float = scroll_speed_limit / (scroll_speed_limit + speed)
		var scroll := PackedVector2Array()
		for i in range(parallax.size()):
			_scroll_x[i] = fposmod(_scroll_x[i] + moved_x * squeeze * parallax[i], TILE_PIXELS)
			_scroll_y[i] = fposmod(_scroll_y[i] + moved_y * squeeze * parallax[i], TILE_PIXELS)
			scroll.append(Vector2(floorf(_scroll_x[i]), floorf(_scroll_y[i])))
		_material.set_shader_parameter("layer_scroll", scroll)

	_last_center_x = center_x
	_last_center_y = center_y
	_last_pixels_per_unit = pixels_per_unit


func _on_star_light_changed(color: Color, level: float) -> void:
	_material.set_shader_parameter("tint_enabled", true)
	_material.set_shader_parameter("star_color", color)
	_material.set_shader_parameter("light_level", level)
