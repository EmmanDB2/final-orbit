# body_view.gd: feeds one planet or moon's data and position into planet.gdshader, including
# the way to the star, which sits at the world origin.
# From DESIGN.md, "Art direction" (planets are shaders and code) and "Physics" (bodies
# move on Kepler rails, computed from time).
extends ColorRect

## Far out, a body stays at least this big on screen so it can be found, in pixels.
@export var smallest_radius: float = 2.0
## A moon whose orbit shrinks to less than this on screen is hidden, in pixels.
@export var smallest_orbit: float = 8.0

var _index: int = 0
var _radius: float = 0.0
var _moon_orbit: float = 0.0
var _spin_rate: float = 0.0
var _cloud_spin_rate: float = 0.0
var _air_height: float = 0.0
var _gravity_model: GravityModel
var _state: ShipState

@onready var _material: ShaderMaterial = material


## Starts showing a body from the gravity model, using its look from the data file.
func show_body(index: int, body: BodyData, gravity_model: GravityModel, state: ShipState, star: StarData) -> void:
	_index = index
	_radius = body.radius
	_spin_rate = body.spin_rate
	_cloud_spin_rate = body.cloud_spin_rate
	_air_height = body.landing_line_altitude if body.air_density > 0.0 else 0.0
	_material.set_shader_parameter("air_color", body.air_color)
	_material.set_shader_parameter("air_sunset_color", body.air_sunset_color)
	_material.set_shader_parameter("sea_level", body.sea_level)
	_material.set_shader_parameter("ice_cap", body.ice_cap)
	_material.set_shader_parameter("crater_amount", body.crater_amount)
	_material.set_shader_parameter("cloud_amount", body.cloud_amount)
	_material.set_shader_parameter("cloud_color", body.cloud_color)
	_material.set_shader_parameter("star_color", star.color)
	_moon_orbit = body.orbit_semi_major_axis if gravity_model.get_body_parent(index) > 0 else 0.0
	_gravity_model = gravity_model
	_state = state
	_material.set_shader_parameter("surface_colors", body.surface_colors)
	_material.set_shader_parameter("terrain_seed", body.terrain_seed)
	_material.set_shader_parameter("largest_feature", body.radius * 0.6)


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	var position_now: PackedFloat64Array = _gravity_model.get_body_position(_index, _state.time)
	var from_middle_x: float = (position_now[0] - center_x) * pixels_per_unit
	var from_middle_y: float = (position_now[1] - center_y) * pixels_per_unit
	var radius_px: float = maxf(_radius * pixels_per_unit, smallest_radius)
	var distance: float = sqrt(from_middle_x * from_middle_x + from_middle_y * from_middle_y)
	var air_px: float = _air_height * pixels_per_unit
	var on_screen: bool = distance - radius_px - air_px < size.length() / 2.0
	visible = on_screen and (_moon_orbit == 0.0 or _moon_orbit * pixels_per_unit >= smallest_orbit)
	if not visible:
		return

	var screen_center: Vector2 = size / 2.0
	_material.set_shader_parameter("center_px", Vector2(
			screen_center.x + from_middle_x,
			screen_center.y + from_middle_y))
	_material.set_shader_parameter("radius_px", radius_px)
	_material.set_shader_parameter("air_px", air_px)
	var turned: float = fposmod(_spin_rate * _state.time, TAU)
	_material.set_shader_parameter("spin_cos", cos(turned))
	_material.set_shader_parameter("spin_sin", sin(turned))
	var clouds_turned: float = fposmod(_cloud_spin_rate * _state.time, TAU)
	_material.set_shader_parameter("cloud_cos", cos(clouds_turned))
	_material.set_shader_parameter("cloud_sin", sin(clouds_turned))
	var to_star: Vector2 = Vector2(-position_now[0], -position_now[1]).normalized()
	_material.set_shader_parameter("light_way", to_star)
	_material.set_shader_parameter("units_per_px", 1.0 / pixels_per_unit)
