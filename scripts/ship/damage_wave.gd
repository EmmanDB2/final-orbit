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

## The art as it should look right now.
var texture: ImageTexture

var _image: Image
var _half: Vector2
var _hits: Array[Dictionary] = []
var _changed: bool = false


func _init(image: Image) -> void:
	_image = image.duplicate()
	_half = Vector2(_image.get_size()) / 2.0
	texture = ImageTexture.create_from_image(_image)


func is_idle() -> bool:
	return _hits.is_empty()


## Forgets anything still playing and shows this art.
func show_image(image: Image) -> void:
	_hits.clear()
	_image.copy_from(image)
	texture.update(_image)


## Starts playing a hit. Points are from the middle of the art, in the order they should go.
func add_hit(points: PackedVector2Array, colors: PackedColorArray, hit_point: Vector2, kick: Vector2, blast: float) -> void:
	var count: int = points.size()
	if count == 0:
		return
	var ticks: int = clampi(count / PIXELS_PER_TICK, FEWEST_TICKS, MOST_TICKS)
	var block: int = 1
	if count > DOUBLE_SPARK_LIMIT:
		block = 3
	elif count > SINGLE_SPARK_LIMIT:
		block = 2
	_hits.append({
		"points": points,
		"colors": colors,
		"next": 0,
		"rate": ceili(float(count) / ticks),
		"block": block,
		"hit_point": hit_point,
		"kick": kick,
		"blast": blast,
	})


## Takes pixels away right now, for a piece that has just broken off and is drawn on its own.
func remove_now(points: PackedVector2Array) -> void:
	for point: Vector2 in points:
		_paint(point, Color(0.0, 0.0, 0.0, 0.0))


## How many ticks until the slowest hit has finished.
func ticks_left() -> int:
	var most: int = 1
	for hit: Dictionary in _hits:
		var left: int = hit["points"].size() - hit["next"]
		most = maxi(most, ceili(float(left) / hit["rate"]))
	return most


## Moves everything along one tick. Returns what just came off: "points", "colors", the spark
## "size", and the hit's "hit_point", "kick", and "blast".
func advance(hot: Color, warm: Color, cool: Color) -> Array[Dictionary]:
	var sprays: Array[Dictionary] = []
	for i in range(_hits.size() - 1, -1, -1):
		var hit: Dictionary = _hits[i]
		var points: PackedVector2Array = hit["points"]
		var colors: PackedColorArray = hit["colors"]
		var rate: int = hit["rate"]
		var next: int = hit["next"]
		var stride: int = hit["block"] * hit["block"]
		var stop: int = mini(next + rate, points.size())
		var spray_points := PackedVector2Array()
		var spray_colors := PackedColorArray()
		for index in range(next, stop):
			_paint(points[index], Color(0.0, 0.0, 0.0, 0.0))
			if index % stride == 0:
				spray_points.append(points[index])
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
		_glow(points, stop, stop + rate, hot)
		_glow(points, stop + rate, stop + rate * 2, warm)
		_glow(points, stop + rate * 2, stop + rate * 3, cool)
		hit["next"] = stop
		if stop >= points.size():
			_hits.remove_at(i)
	if _changed:
		_changed = false
		texture.update(_image)
	return sprays


func _glow(points: PackedVector2Array, start: int, stop: int, color: Color) -> void:
	for index in range(start, mini(stop, points.size())):
		_paint(points[index], color)


func _paint(point: Vector2, color: Color) -> void:
	_image.set_pixel(floori(point.x + _half.x), floori(point.y + _half.y), color)
	_changed = true
