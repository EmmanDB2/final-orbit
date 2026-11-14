# comet_view.gd: a passing comet: a lumpy nucleus lit from the star, a faint coma round it as wide as
# the scan reaches, and a tail streaming straight away from the star, with a narrower bright one down
# its middle. Its colors are its own data, being nature's, not the agency's. From DESIGN.md,
# "Mid-flight events" (passing comets).
class_name CometView
extends Node2D

## How many points go round the nucleus's outline.
const OUTLINE_POINTS: int = 18

var _event: FlightEvent
var _pixels_per_unit: float = 1.0
# The nucleus's outline, in units of its radius, lumpy and the same every time for the same comet.
var _outline := PackedVector2Array()


func setup(event: FlightEvent) -> void:
	_event = event
	var rng := RandomNumberGenerator.new()
	rng.seed = ("comet|%s" % event.name).hash()
	for i in range(OUTLINE_POINTS):
		var angle: float = TAU * i / OUTLINE_POINTS
		var bulge: float = rng.randf_range(0.72, 1.0)
		_outline.append(Vector2(cos(angle), sin(angle) * 0.8) * bulge)


func place(center_x: float, center_y: float, pixels_per_unit: float, _roll: float) -> void:
	_pixels_per_unit = pixels_per_unit
	position = Vector2((_event.state.x - center_x) * pixels_per_unit, (_event.state.y - center_y) * pixels_per_unit)
	# Only while some of it could be on screen: the tail reaches far.
	var reach: float = (_event.type.tail_length + _event.type.scan_reach) * pixels_per_unit
	visible = position.length() <= reach + 2000.0
	queue_redraw()


func _draw() -> void:
	var type: EventType = _event.type
	var scale_by: float = _pixels_per_unit
	# Away from the star, which sits at the world's middle.
	var away := Vector2(_event.state.x, _event.state.y).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var across := Vector2(-away.y, away.x)
	# The coma, in soft rings out to the scan's reach.
	var glow: Color = type.glow_color
	for ring in range(4):
		var share: float = 1.0 - ring * 0.24
		glow.a = 0.018 + ring * 0.008
		draw_circle(Vector2.ZERO, maxf(type.scan_reach * share * scale_by, 2.0), glow)
	# The dust tail, wide and fading, and the bright one down its middle, both starting under the
	# nucleus.
	var head: float = type.nucleus_radius * 1.1 * scale_by
	var length: float = type.tail_length * scale_by
	var dust: Color = type.glow_color
	dust.a = 0.2
	var faded: Color = dust
	faded.a = 0.0
	draw_polygon(
			PackedVector2Array([across * head, away * length + across * length * 0.12, away * length - across * length * 0.12, -across * head]),
			PackedColorArray([dust, faded, faded, dust]))
	var bright: Color = type.glow_color
	bright.a = 0.38
	var bright_faded: Color = bright
	bright_faded.a = 0.0
	draw_polygon(
			PackedVector2Array([across * head * 0.4, away * length * 0.7, -across * head * 0.4]),
			PackedColorArray([bright, bright_faded, bright]))
	# The nucleus: at least a couple of pixels, however far out.
	var radius: float = type.nucleus_radius * scale_by
	if radius < 1.5:
		draw_rect(Rect2(-1.0, -1.0, 3.0, 3.0), type.nucleus_color)
		return
	var shape := PackedVector2Array()
	var lit := PackedVector2Array()
	for point: Vector2 in _outline:
		shape.append(point * radius)
		# A smaller copy pushed toward the star: lit on that side, the rest in its own shadow.
		lit.append(point * radius * 0.75 - away * radius * 0.22)
	draw_colored_polygon(shape, type.dust_color)
	draw_colored_polygon(lit, type.nucleus_color)
