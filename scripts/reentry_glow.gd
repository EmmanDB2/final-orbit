# reentry_glow.gd: what heat looks like on the ship: a hull that glows from the hot side, hot air
# hugging it, and flames streaming off its edges. Purely for looks, and it doubles as a heat
# gauge, since the hull's color shows how close it is to burning.
# From DESIGN.md, "Hazards" (atmospheres: drag and re-entry heat).
#
# Each layer of the ship's art gets its own copy of reentry.gdshader, which uses that art as its
# mask, so it all follows the ship's real shape. From far out, where the art is too small for
# that, it's a little comet instead.
class_name ReentryGlow
extends Node2D

## One layer's heat, drawn over a rectangle around its art.
class HeatLayer:
	extends Node2D
	var rect := Rect2()
	func _draw() -> void:
		draw_rect(rect, Color.WHITE)


## Below this heat there's nothing to see, where 1.0 is the top of the scale.
const FIRST_SHOWS: float = 0.03
## How far around the art the air layer can reach, in art pixels.
const AIR_MARGIN: float = 18.0
## How far flames can trail behind the art at the top of the scale, in art pixels.
const LONGEST_FLAMES: float = 240.0
## Smaller than this share of its true size, the art can't show it, so it's a comet instead.
const COMET_BELOW: float = 0.2
## How long the comet's tail gets at the top of the scale, on screen, in pixels.
const COMET_TAIL: float = 40.0
const COMET_FRAMES_PER_SECOND: float = 30.0

var _layers: Array[HeatLayer] = []
var _sizes: Array[Vector2] = []
var _air_heat: float = 0.0
var _hull_heat: float = 0.0
var _wind := Vector2.UP
var _art_scale: float = 1.0
var _time: float = 0.0
var _frame: int = 0


## Sets up one heat layer per layer of the ship's art.
func setup(textures: Array[ImageTexture]) -> void:
	var shader: Shader = load("res://shaders/reentry.gdshader")
	var palette: AgencyPalette = UiStyle.palette()
	for texture: ImageTexture in textures:
		var layer := HeatLayer.new()
		var heat_material := ShaderMaterial.new()
		heat_material.shader = shader
		heat_material.set_shader_parameter("art", texture)
		heat_material.set_shader_parameter("art_size", Vector2(texture.get_size()))
		heat_material.set_shader_parameter("white_hot", palette.thrust_white)
		heat_material.set_shader_parameter("yellow_hot", palette.thrust_yellow)
		heat_material.set_shader_parameter("red_hot", palette.thrust_red)
		heat_material.set_shader_parameter("dull_hot", palette.agency_orange_dark)
		layer.material = heat_material
		layer.visible = false
		add_child(layer)
		_layers.append(layer)
		_sizes.append(Vector2(texture.get_size()))


## Puts a layer's heat where its art is right now.
func place_layer(index: int, center: Vector2, fold: float, art_scale: float) -> void:
	_layers[index].position = center * art_scale
	_layers[index].scale = Vector2(art_scale, art_scale * fold)


## Says how hot the air and hull are, which way the air is coming from and which side of the
## hull has soaked up heat, both on the art, and how big the art is on screen.
func set_heat(air_heat: float, hull_heat: float, wind: Vector2, soak: Vector2, art_scale: float) -> void:
	var was_comet: bool = _air_heat >= FIRST_SHOWS and _art_scale < COMET_BELOW
	_air_heat = air_heat
	_hull_heat = hull_heat
	_wind = wind
	_art_scale = art_scale
	var is_comet: bool = air_heat >= FIRST_SHOWS and art_scale < COMET_BELOW
	if was_comet != is_comet:
		queue_redraw()

	var show_art: bool = art_scale >= COMET_BELOW and (air_heat >= FIRST_SHOWS or hull_heat > 0.05)
	for i in range(_layers.size()):
		var layer: HeatLayer = _layers[i]
		layer.visible = show_art
		if not show_art:
			continue
		# A folded layer is upside down, so its directions are too.
		var flip: Vector2 = Vector2(1.0, -1.0 if layer.scale.y < 0.0 else 1.0)
		var layer_wind: Vector2 = wind * flip
		var heat_material: ShaderMaterial = layer.material
		heat_material.set_shader_parameter("wind_way", layer_wind)
		heat_material.set_shader_parameter("soak_way", soak * flip)
		heat_material.set_shader_parameter("air_heat", air_heat)
		heat_material.set_shader_parameter("hull_heat", hull_heat)
		var around := Rect2(-_sizes[i] / 2.0, _sizes[i]).grow(AIR_MARGIN)
		var tail: Vector2 = -layer_wind * LONGEST_FLAMES * minf(air_heat * 1.2, 1.0)
		var rect: Rect2 = around.merge(Rect2(around.position + tail, around.size))
		if rect != layer.rect:
			layer.rect = rect
			layer.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var frame: int = int(_time * COMET_FRAMES_PER_SECOND)
	if frame != _frame and _air_heat >= FIRST_SHOWS and _art_scale < COMET_BELOW:
		_frame = frame
		queue_redraw()


# From far out, a bright head and a flickering tail streaming back from it.
func _draw() -> void:
	if _air_heat < FIRST_SHOWS or _art_scale >= COMET_BELOW:
		return
	var palette: AgencyPalette = UiStyle.palette()
	var strength: float = minf(_air_heat, 1.0)
	var hot: Color = palette.thrust_white if _air_heat >= 0.5 else palette.thrust_yellow
	var head: float = maxf(2.0, 3.0 * _art_scale * 10.0)
	draw_rect(Rect2((_wind * head * 0.5 - Vector2.ONE * head / 2.0).round(), Vector2.ONE * head), hot)
	var tail: float = (10.0 + COMET_TAIL * strength)
	var along: float = 2.0
	while along < tail:
		var share: float = along / tail
		if RcsPuffs.speckle(along, 1.0, _frame) > share * 0.75:
			var spread: float = (RcsPuffs.speckle(along, 2.0, _frame) - 0.5) * (2.0 + share * 5.0)
			var spot: Vector2 = -_wind * along + _wind.orthogonal() * spread
			var color: Color = palette.thrust_yellow if share < 0.4 else palette.thrust_red
			draw_rect(Rect2(spot.round(), Vector2.ONE * 2.0), color)
		along += 2.0
