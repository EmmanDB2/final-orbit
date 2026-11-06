# damage_wave.gd: what the ship's art shows while damage eats through it.
# From DESIGN.md, "Destruction". A hit changes the ship's mass, thrust, and everything else
# at once. This only decides what's drawn: the lost pixels go a few at a time, starting where
# the hit landed and glowing just before they go, so damage spreads instead of blinking out.
class_name DamageWave
extends RefCounted

## How many ticks a hit takes to play out, depending on how many pixels it took.
const FEWEST_TICKS: int = 2
const MOST_TICKS: int = 26
const PIXELS_PER_TICK: int = 30
## Up to this many pixels, every one becomes its own spark. Past it, sparks stand in for 2 x 2
## blocks of pixels, and past the second limit for 3 x 3 blocks.
const SINGLE_SPARK_LIMIT: int = 800
const DOUBLE_SPARK_LIMIT: int = 3000

## The art as it should look right now, one texture per layer of the ship.
var textures: Array[ImageTexture] = []

var _body: ShipBody
var _images: Array[Image] = []
var _changed: PackedByteArray = PackedByteArray()
var _hits: Array[Dictionary] = []


func _init(body: ShipBody) -> void:
	_body = body
	for i in range(body.layer_count()):
		var image: Image = body.layer_image(i).duplicate()
		_images.append(image)
		textures.append(ImageTexture.create_from_image(image))
		_changed.append(0)


func is_idle() -> bool:
	return _hits.is_empty()


## Forgets anything still playing and shows this ship as it is.
func show_body(body: ShipBody) -> void:
	_body = body
	_hits.clear()
	for i in range(_images.size()):
		_images[i].copy_from(body.layer_image(i))
		textures[i].update(_images[i])


## How many pixels are showing, across every layer.
func shown_pixel_count() -> int:
	var count: int = 0
	for image: Image in _images:
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.5:
					count += 1
	return count


## Starts playing a hit, with pixels in the order they should go.
func add_hit(erased: Dictionary, hit_point: Vector2, kick: Vector2, blast: float) -> void:
	var pixels: PackedInt32Array = erased["pixels"]
	var count: int = pixels.size()
	if count == 0:
		return
	var ticks: int = clampi(count / PIXELS_PER_TICK, FEWEST_TICKS, MOST_TICKS)
	var block: int = 1
	if count > DOUBLE_SPARK_LIMIT:
		block = 3
	elif count > SINGLE_SPARK_LIMIT:
		block = 2
	_hits.append({
		"pixels": pixels,
		"colors": erased["colors"],
		"next": 0,
		"rate": ceili(float(count) / ticks),
		"block": block,
		"hit_point": hit_point,
		"kick": kick,
		"blast": blast,
	})


## Takes pixels away right now, for a piece that has just broken off and is drawn on its own.
func remove_now(pixels: PackedInt32Array) -> void:
	for pixel: int in pixels:
		_paint(pixel, Color(0.0, 0.0, 0.0, 0.0))


## How many ticks until the slowest hit has finished.
func ticks_left() -> int:
	var most: int = 1
	for hit: Dictionary in _hits:
		var left: int = hit["pixels"].size() - hit["next"]
		most = maxi(most, ceili(float(left) / hit["rate"]))
	return most


## Moves everything along one tick. Returns what just came off: "points", "colors", the spark
## "size", and the hit's "hit_point", "kick", and "blast".
func advance(hot: Color, warm: Color, cool: Color) -> Array[Dictionary]:
	var sprays: Array[Dictionary] = []
	for i in range(_hits.size() - 1, -1, -1):
		var hit: Dictionary = _hits[i]
		var pixels: PackedInt32Array = hit["pixels"]
		var colors: PackedColorArray = hit["colors"]
		var rate: int = hit["rate"]
		var next: int = hit["next"]
		var stride: int = hit["block"] * hit["block"]
		var stop: int = mini(next + rate, pixels.size())
		var spray_points := PackedVector2Array()
		var spray_colors := PackedColorArray()
		for index in range(next, stop):
			_paint(pixels[index], Color(0.0, 0.0, 0.0, 0.0))
			if index % stride == 0:
				spray_points.append(_body.position_of(pixels[index]))
				spray_colors.append(colors[index])
		sprays.append({
			"points": spray_points,
			"colors": spray_colors,
			"size": hit["block"],
			"hit_point": hit["hit_point"],
			"kick": hit["kick"],
			"blast": hit["blast"],
		})

		# The edge that goes next glows, hottest right beside the pixels that just left.
		_glow(pixels, stop, stop + rate, hot)
		_glow(pixels, stop + rate, stop + rate * 2, warm)
		_glow(pixels, stop + rate * 2, stop + rate * 3, cool)
		hit["next"] = stop
		if stop >= pixels.size():
			_hits.remove_at(i)
	for i in range(_images.size()):
		if _changed[i] == 1:
			_changed[i] = 0
			textures[i].update(_images[i])
	return sprays


func _glow(pixels: PackedInt32Array, start: int, stop: int, color: Color) -> void:
	for index in range(start, mini(stop, pixels.size())):
		_paint(pixels[index], color)


func _paint(pixel: int, color: Color) -> void:
	var layer: int = _body.pixel_layer[pixel]
	_images[layer].set_pixel(_body.pixel_x[pixel], _body.pixel_y[pixel], color)
	_changed[layer] = 1
