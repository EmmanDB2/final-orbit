# planet_view.gd: feeds a planet's data and the current view into planet.gdshader.
# From DESIGN.md, "Art direction" (planets are shaders and code). Tier 0's planet sits
# at the world origin.
extends ColorRect

var _body_radius: float = 0.0

@onready var _material: ShaderMaterial = material


func set_body(body: BodyData) -> void:
	_material.set_shader_parameter("surface_colors", body.surface_colors)
	_material.set_shader_parameter("terrain_seed", body.terrain_seed)
	_body_radius = body.radius


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	var screen_center: Vector2 = size / 2.0
	_material.set_shader_parameter("center_px", Vector2(
			screen_center.x - center_x * pixels_per_unit,
			screen_center.y - center_y * pixels_per_unit))
	_material.set_shader_parameter("radius_px", _body_radius * pixels_per_unit)
	_material.set_shader_parameter("units_per_px", 1.0 / pixels_per_unit)

