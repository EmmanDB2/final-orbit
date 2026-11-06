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

var _gravity_model: GravityModel
var _state: ShipState
var _scroll_x: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var _scroll_y: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var _last_center_x: float = 0.0
var _last_center_y: float = 0.0
var _last_frame_body: int = -1

@onready var _material: ShaderMaterial = material


## Starts following a flight.
func start_stars(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state


func _on_view_changed(world_x: float, world_y: float, pixels_per_unit: float) -> void:
	# Motion is measured from the planet the ship is around, or from the star out in deep
	# space. Otherwise the planet's fast trip around the star would drag the stars along
	# even while the ship sits on the ground.
	var dominant: int = _gravity_model.get_dominant_body(_state.x, _state.y, _state.time)
	var frame_body: int = _gravity_model.get_local_root(dominant)
	var frame: PackedFloat64Array = _gravity_model.get_body_position(frame_body, _state.time)
	var center_x: float = world_x - frame[0]
	var center_y: float = world_y - frame[1]

	# The first view, or a new frame, has nothing to compare with. Otherwise the view never
	# jumps, so the stars keep moving through zooms too.
	if frame_body == _last_frame_body:
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
	_last_frame_body = frame_body


func _on_star_light_changed(color: Color, level: float) -> void:
	_material.set_shader_parameter("tint_enabled", true)
	_material.set_shader_parameter("star_color", color)
	_material.set_shader_parameter("light_level", level)
