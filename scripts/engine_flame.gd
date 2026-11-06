# engine_flame.gd: feeds the ship's engine into engine_flame.gdshader. It lights fast and dies
# a moment later, instead of switching on and off.
# From DESIGN.md, "Ships" and "Art direction" (effects are shaders and code). Only for looks.
class_name EngineFlame
extends Node2D

## How long the flame takes to catch and to die, in seconds.
@export var ignite_seconds: float = 0.07
@export var fade_seconds: float = 0.16

var _longest: float = 150.0
var _half_exit: float = 10.0
var _power: float = 0.0
var _wanted: float = 0.0
var _rect := Rect2()
var _material := ShaderMaterial.new()


## Sets up the flame from the ship's design.
func setup(longest: float) -> void:
	_longest = longest
	var palette: AgencyPalette = UiStyle.palette()
	_material.shader = load("res://shaders/engine_flame.gdshader")
	_material.set_shader_parameter("white_hot", palette.thrust_white)
	_material.set_shader_parameter("yellow_hot", palette.thrust_yellow)
	_material.set_shader_parameter("red_hot", palette.thrust_red)
	_material.set_shader_parameter("longest", longest)
	material = _material
	visible = false


## Says how wide the engine's exit is now, in art pixels.
func set_exit(half_width: float) -> void:
	_half_exit = maxf(half_width, 1.0)
	_material.set_shader_parameter("half_exit", _half_exit)
	_update_rect()


## Says what the engine is doing: how hard it's pushing, how thick the air is, how damaged the
## engine is, and how far the flame can go before the ground, in art pixels.
func set_burn(share: float, air: float, sputter: float, room: float) -> void:
	_wanted = share
	_material.set_shader_parameter("air", air)
	_material.set_shader_parameter("sputter", sputter)
	_material.set_shader_parameter("room", room)


func _process(delta: float) -> void:
	var seconds: float = ignite_seconds if _wanted > _power else fade_seconds
	_power = move_toward(_power, _wanted, delta / seconds)
	visible = _power > 0.005
	_material.set_shader_parameter("power", _power)


func _update_rect() -> void:
	# Wide enough for the widest it can spread, in a vacuum.
	var half_width: float = _half_exit + _longest * 0.3 + 4.0
	var rect := Rect2(-half_width, 0.0, half_width * 2.0, _longest + 4.0)
	if rect != _rect:
		_rect = rect
		queue_redraw()


func _draw() -> void:
	draw_rect(_rect, Color.WHITE)
