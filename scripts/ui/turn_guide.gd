# turn_guide.gd: drag to point. Shows a cyan heading line from the ship toward the thumb,
# and a dashed ring around the ship that fades after release, and tells the ship where to
# turn. From DESIGN.md, "UI" (turning and RCS controls).
class_name TurnGuide
extends Node2D

## How fast the ring fades after release, per second.
@export var fade_speed: float = 2.0
## How many dashes are in the ring.
@export var dashes: int = 24

var ship: Node2D
var _thumb_on_screen: Vector2 = Vector2.ZERO
var _thumb: Vector2 = Vector2.ZERO
var _active: bool = false
var _fade: float = 0.0


func _on_point_changed(screen_position: Vector2) -> void:
	_thumb_on_screen = screen_position
	_active = true
	_fade = 1.0


func _on_point_released() -> void:
	_active = false
	ship.stop_pointing()


func _process(delta: float) -> void:
	if _active:
		# Where the thumb is in the world's canvas, which turns with the view.
		_thumb = get_canvas_transform().affine_inverse() * _thumb_on_screen
		var direction: Vector2 = _thumb - ship.position
		if direction.length() > 4.0:
			ship.point_at(atan2(direction.x, -direction.y))
		queue_redraw()
	elif _fade > 0.0:
		_fade = maxf(_fade - fade_speed * TimeWarp.real(delta), 0.0)
		queue_redraw()


func _draw() -> void:
	if _fade <= 0.0:
		return
	var cyan: Color = UiStyle.palette().telemetry_cyan
	if _active:
		draw_line(ship.position, _thumb, cyan, -1.0)
	var color: Color = cyan
	color.a = _fade
	var radius: float = ship.guide_radius()
	var step: float = TAU / dashes
	for i in range(dashes):
		draw_arc(ship.position, radius, i * step, i * step + step * 0.5, 4, color, -1.0)
