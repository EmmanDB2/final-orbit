# body_view.gd: feeds one planet or moon's data and position into planet.gdshader, including
# the way to the star, which sits at the world origin.
# From DESIGN.md, "Art direction" (planets are shaders and code) and "Physics" (bodies
# move on Kepler rails, computed from time).
extends ColorRect

## Far out, a body stays at least this big on screen so it can be found, in pixels.
@export var smallest_radius: float = 2.0
## How many columns of the rim the shader gets to draw at once. Must match the shader.
const STRIP_SIZE: int = 1024

## The skyline fades in between these zooms, in world units per pixel, so it can't be seen from
## orbit. It's only the drawing: the ground is the same height from everywhere.
@export var rim_gone_zoom: float = 400.0
@export var rim_full_zoom: float = 128.0
## The far-off mountains fade in between these zooms, in world units per pixel.
@export var ridge_gone_zoom: float = 96.0
@export var ridge_full_zoom: float = 48.0
## How fast the far-off mountains go by, as a share of the ground's speed.
@export var ridge_speed: float = 0.3
## How wide a pixel of the ground is at the closest zoom, in world units.
@export var world_pixel: float = 2.0
## Once a body is at least this big on screen, in pixels, its surface goes on the ground's grid.
@export var surface_grid_radius: float = 200.0
## A moon whose orbit shrinks to less than this on screen is hidden, in pixels.
@export var smallest_orbit: float = 8.0

var _index: int = 0
var _radius: float = 0.0
var _moon_orbit: float = 0.0
var _spin_rate: float = 0.0
var _cloud_spin_rate: float = 0.0
var _air_height: float = 0.0
var _gravity_model: GravityModel
var _strip_image: Image
var _strip_texture: ImageTexture
var _ridge_image: Image
var _ridge_texture: ImageTexture
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
	_material.set_shader_parameter("air_horizon_color", body.air_horizon_color)
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
	_material.set_shader_parameter("strata_colors", body.strata_colors)
	_material.set_shader_parameter("terrain_seed", body.terrain_seed)
	_material.set_shader_parameter("largest_feature", body.radius * 0.6)


# Up close the ground uses the same pixels as the ship. Farther out they get bigger, in steps,
# until a body is about 60 of its own pixels in radius.
func _block_size(radius_px: float, units_per_px: float) -> float:
	if units_per_px < 16.0:
		return 1.0
	var by_zoom: int = 2 if units_per_px < 32.0 else (3 if units_per_px < 64.0 else 4)
	return float(clampi(mini(by_zoom, roundi(radius_px / 60.0)), 1, 4))


# Works out where the middle of the view is on the ground's grid. Grid cells double in size as
# you zoom out, so each is always 2 to 4 pixels wide, and cells of one size nest inside the next,
# so colors don't swim while zooming.
func _feed_surface_grid(from_body_x: float, from_body_y: float, radius_px: float, pixels_per_unit: float) -> void:
	var distance: float = sqrt(from_body_x * from_body_x + from_body_y * from_body_y)
	var use_grid: bool = radius_px >= surface_grid_radius and distance > _radius * 0.7
	_material.set_shader_parameter("on_surface_grid", use_grid)
	if not use_grid:
		return
	var cell: float = world_pixel * pow(2.0, maxf(ceilf(log(1.0 / pixels_per_unit) / log(2.0)), 0.0))
	var angle: float = fposmod(atan2(from_body_x, -from_body_y) - _spin_rate * _state.time, TAU)
	var columns: float = angle * _radius / cell
	var column: float = floorf(columns)
	_material.set_shader_parameter("screen_middle", size / 2.0)
	_material.set_shader_parameter("view_from_body", Vector2(from_body_x, from_body_y) * pixels_per_unit)
	_material.set_shader_parameter("view_height_px", (distance - _radius) * pixels_per_unit)
	_material.set_shader_parameter("view_column", int(column))
	_material.set_shader_parameter("view_column_share", columns - column)
	_material.set_shader_parameter("cell_px", cell * pixels_per_unit)
	_material.set_shader_parameter("cell_units", cell)
	_feed_rim(int(column), roundi(cell / world_pixel), pixels_per_unit)
	_material.set_shader_parameter("detail_units", cell)


# Hands the shader the stretch of the rim in view, from the same numbers the physics uses.
func _feed_rim(column: int, step: int, pixels_per_unit: float) -> void:
	var strip: PackedFloat32Array = _gravity_model.get_ground_strip(_index, (column - STRIP_SIZE / 2) * step, step, STRIP_SIZE)
	if _strip_image == null:
		_strip_image = Image.create_from_data(STRIP_SIZE, 1, false, Image.FORMAT_RGF, strip.to_byte_array())
		_strip_texture = ImageTexture.create_from_image(_strip_image)
		_material.set_shader_parameter("rim_strip", _strip_texture)
	else:
		_strip_image.set_data(STRIP_SIZE, 1, false, Image.FORMAT_RGF, strip.to_byte_array())
		_strip_texture.update(_strip_image)
	var zoomed_out: float = 1.0 / pixels_per_unit
	_material.set_shader_parameter("rim_fade", clampf((rim_gone_zoom - zoomed_out) / (rim_gone_zoom - rim_full_zoom), 0.0, 1.0))

	# The far-off mountains stand on the ground in the middle of the view, and go by slower.
	var ridge_fade: float = clampf((ridge_gone_zoom - zoomed_out) / (ridge_gone_zoom - ridge_full_zoom), 0.0, 1.0)
	_material.set_shader_parameter("ridge_fade", ridge_fade)
	if ridge_fade <= 0.0:
		return
	var first: float = (column * step) * ridge_speed - STRIP_SIZE / 2.0 * step * ridge_speed
	var ridge: PackedFloat32Array = _gravity_model.get_distant_ridge(_index, first, step * ridge_speed, STRIP_SIZE, ridge_speed)
	if _ridge_image == null:
		_ridge_image = Image.create_from_data(STRIP_SIZE, 1, false, Image.FORMAT_RF, ridge.to_byte_array())
		_ridge_texture = ImageTexture.create_from_image(_ridge_image)
		_material.set_shader_parameter("ridge_strip", _ridge_texture)
	else:
		_ridge_image.set_data(STRIP_SIZE, 1, false, Image.FORMAT_RF, ridge.to_byte_array())
		_ridge_texture.update(_ridge_image)
	_material.set_shader_parameter("ridge_base_px", strip[STRIP_SIZE] * pixels_per_unit)


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	var position_now: PackedFloat64Array = _gravity_model.get_body_position(_index, _state.time)
	var from_middle_x: float = (position_now[0] - center_x) * pixels_per_unit
	var from_middle_y: float = (position_now[1] - center_y) * pixels_per_unit
	var radius_px: float = maxf(_radius * pixels_per_unit, smallest_radius)
	var distance: float = sqrt(from_middle_x * from_middle_x + from_middle_y * from_middle_y)
	var air_px: float = _air_height * pixels_per_unit
	var highest_px: float = _gravity_model.get_highest_ground(_index) * pixels_per_unit
	var on_screen: bool = distance - radius_px - maxf(air_px, highest_px) < size.length() / 2.0
	visible = on_screen and (_moon_orbit == 0.0 or _moon_orbit * pixels_per_unit >= smallest_orbit)
	if not visible:
		return

	var screen_center: Vector2 = size / 2.0
	_material.set_shader_parameter("center_px", Vector2(
			screen_center.x + from_middle_x,
			screen_center.y + from_middle_y))
	_material.set_shader_parameter("radius_px", radius_px)
	var block: float = _block_size(radius_px, 1.0 / pixels_per_unit)
	_material.set_shader_parameter("block_px", block)
	_material.set_shader_parameter("detail_units", block / pixels_per_unit)
	_feed_surface_grid(center_x - position_now[0], center_y - position_now[1], radius_px, pixels_per_unit)
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
