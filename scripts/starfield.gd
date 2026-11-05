# starfield.gd: scrolls starfield.gdshader to match the ship's real position.
# From DESIGN.md, "Art direction" (space is shaders and code) and "Physics"
# (floating origin).
#
# The GPU only has 32-bit floats, so each layer's scroll is wrapped to the size of
# the star pattern here, in 64-bit, before it is sent over. That keeps the stars
# steady no matter how far the ship has flown.
extends ColorRect

## Size of the repeating star pattern. Must match the constants in the shader.
const TILE_PIXELS: float = 16384.0

## How far each layer scrolls per pixel the ship moves, farthest first.
@export var parallax: PackedFloat64Array = PackedFloat64Array([0.05, 0.15, 0.4])

@onready var _material: ShaderMaterial = material


func _on_ship_world_position_changed(x: float, y: float) -> void:
	var scroll := PackedVector2Array()
	for factor: float in parallax:
		scroll.append(Vector2(
				fposmod(floorf(x * factor), TILE_PIXELS),
				fposmod(floorf(y * factor), TILE_PIXELS)))
	_material.set_shader_parameter("layer_scroll", scroll)


func _on_star_light_changed(color: Color, level: float) -> void:
	_material.set_shader_parameter("tint_enabled", true)
	_material.set_shader_parameter("star_color", color)
	_material.set_shader_parameter("light_level", level)
