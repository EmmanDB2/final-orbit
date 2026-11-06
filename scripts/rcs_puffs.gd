# rcs_puffs.gd: draws gas puffing from the ship's RCS nozzles while they fire.
# From DESIGN.md, "Ships". Purely cosmetic: ship.gd says which nozzles are firing, and the
# nozzle positions come from the ship's design.
class_name RcsPuffs
extends Node2D

## Below this zoom the puffs would be too small to read, so they don't draw.
const MIN_SCALE: float = 0.2
## Exhaust direction for the side nozzles when backing up: angled toward the nose.
const FORWARD_SLANT: float = 0.7
## Size of a puff in art pixels: how far it reaches and its half width at each end.
const PUFF_LENGTH: float = 18.0
const PUFF_START_WIDTH: float = 1.5
const PUFF_END_WIDTH: float = 5.0
const PUFF_FRAMES_PER_SECOND: float = 30.0

var _left: Vector2 = Vector2.ZERO
var _right: Vector2 = Vector2.ZERO
var _rear: PackedVector2Array = PackedVector2Array()
var _art_scale: float = 1.0
var _fire_left: bool = false
var _fire_right: bool = false
var _fire_rear: bool = false
var _fire_front: bool = false
var _time: float = 0.0


## Takes nozzle positions in art pixels and makes them relative to the ship's middle.
func set_nozzles(design: ShipDesign) -> void:
	var middle: Vector2 = design.texture.get_size() / 2.0
	_left = design.rcs_left_nozzle - middle
	_right = design.rcs_right_nozzle - middle
	_rear = PackedVector2Array()
	for nozzle: Vector2 in design.rcs_rear_nozzles:
		_rear.append(nozzle - middle)


## Says which nozzles fire: the left and right sides, the rear pair, and the sides angled
## forward, which is how the ship backs up.
func set_firing(left: bool, right: bool, rear: bool, front: bool, art_scale: float) -> void:
	var was_firing: bool = _is_firing()
	_fire_left = left
	_fire_right = right
	_fire_rear = rear
	_fire_front = front
	_art_scale = art_scale
	if was_firing or _is_firing():
		queue_redraw()


func _is_firing() -> bool:
	return _fire_left or _fire_right or _fire_rear or _fire_front


func _process(delta: float) -> void:
	_time += delta
	if _is_firing():
		queue_redraw()


func _draw() -> void:
	if _art_scale < MIN_SCALE:
		return
	if _fire_left:
		_draw_puff(_left, Vector2.LEFT)
	if _fire_right:
		_draw_puff(_right, Vector2.RIGHT)
	if _fire_front:
		_draw_puff(_left, Vector2(-FORWARD_SLANT, -FORWARD_SLANT))
		_draw_puff(_right, Vector2(FORWARD_SLANT, -FORWARD_SLANT))
	if _fire_rear:
		for nozzle: Vector2 in _rear:
			_draw_puff(nozzle, Vector2.DOWN)


# A small cone of gas that widens as it leaves the nozzle and breaks up at the far end.
func _draw_puff(nozzle: Vector2, direction: Vector2) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var colors: Array[Color] = [
		palette.hull_lightest, palette.hull_lightest, palette.hull_lighter, palette.hull_light,
	]
	var side: Vector2 = direction.orthogonal()
	var pixel: float = 1.0 / _art_scale
	var frame: int = int(_time * PUFF_FRAMES_PER_SECOND)
	var along: float = 0.0
	while along < PUFF_LENGTH:
		var share: float = along / PUFF_LENGTH
		var half_width: float = lerpf(PUFF_START_WIDTH, PUFF_END_WIDTH, share)
		var color: Color = colors[int(share * colors.size())]
		var across: float = -half_width
		while across <= half_width:
			if speckle(along, across, frame) < 1.0 - share * share:
				var spot: Vector2 = (nozzle + direction * along + side * across) * _art_scale
				draw_rect(Rect2(spot.round(), Vector2.ONE), color)
			across += pixel
		along += pixel


## A repeatable 0-1 number for one spot of gas on one animation frame.
static func speckle(along: float, across: float, frame: int) -> float:
	return fposmod(sin(along * 12.9898 + across * 78.233 + frame * 37.719) * 43758.5453, 1.0)
