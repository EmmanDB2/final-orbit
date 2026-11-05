# body_view.gd: feeds one planet or moon's data and position into planet.gdshader.
# From DESIGN.md, "Art direction" (planets are shaders and code) and "Physics" (bodies
# move on Kepler rails, computed from time).
extends ColorRect

var _index: int = 0
var _radius: float = 0.0
var _gravity_model: GravityModel
var _state: ShipState

@onready var _material: ShaderMaterial = material


## Starts showing a body from the gravity model, using its look from the data file.
func show_body(index: int, body: BodyData, gravity_model: GravityModel, state: ShipState) -> void:
	_index = index
	_radius = body.radius
	_gravity_model = gravity_model
	_state = state
	_material.set_shader_parameter("surface_colors", body.surface_colors)
	_material.set_shader_parameter("terrain_seed", body.terrain_seed)
	_material.set_shader_parameter("largest_feature", body.radius * 0.6)


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	var position_now: PackedFloat64Array = _gravity_model.get_body_position(_index, _state.time)
	var screen_center: Vector2 = size / 2.0
	_material.set_shader_parameter("center_px", Vector2(
			screen_center.x + (position_now[0] - center_x) * pixels_per_unit,
			screen_center.y + (position_now[1] - center_y) * pixels_per_unit))
	_material.set_shader_parameter("radius_px", _radius * pixels_per_unit)
	_material.set_shader_parameter("units_per_px", 1.0 / pixels_per_unit)
