# star_view.gd: feeds the star's position and size into star.gdshader.
# From DESIGN.md, "Art direction" (space is shaders and code) and "Universe generation"
# (star colors). The star is body 0, so it sits at the world origin.
extends ColorRect

## Far out, the star stays at least this big on screen so it can be found, in pixels.
@export var smallest_radius: float = 3.0
## How far the glow reaches past the rim, as a share of the star's radius.
@export var glow_share: float = 1.6
## How far the glow reaches past the rim at any size, in pixels.
@export var glow_pixels: float = 14.0

var _radius: float = 0.0
var _roll: float = 0.0

@onready var _material: ShaderMaterial = material


## Starts showing a star, using its look from the data file.
func show_star(star: StarData) -> void:
	_radius = star.radius
	_material.set_shader_parameter("star_color", star.color)


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	var from_middle_x: float = -center_x * pixels_per_unit
	var from_middle_y: float = -center_y * pixels_per_unit
	var radius_px: float = maxf(_radius * pixels_per_unit, smallest_radius)
	var glow_px: float = radius_px * glow_share + glow_pixels
	var distance: float = sqrt(from_middle_x * from_middle_x + from_middle_y * from_middle_y)
	visible = distance - radius_px - glow_px < size.length() / 2.0
	if not visible:
		return

	_material.set_shader_parameter("center_px", size / 2.0 + Vector2(from_middle_x, from_middle_y).rotated(-_roll))
	_material.set_shader_parameter("radius_px", radius_px)
	_material.set_shader_parameter("glow_px", glow_px)
