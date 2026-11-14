# comet_view.gd: a passing comet: a lumpy, cratered nucleus lit from the star, tumbling slowly, in a
# faint coma round it as wide as the scan reaches, and a tail streaming straight away from the star,
# with a narrower bright one down its middle. The nucleus is drawn by a shader in banded, dithered
# tones; its outline, craters, spin, and jets all come from the comet's name, so the same comet always
# looks the same. Its colors are its own data, being nature's, not the agency's. From DESIGN.md,
# "Mid-flight events" (passing comets).
class_name CometView
extends Node2D

const NUCLEUS_SHADER: Shader = preload("res://shaders/comet_nucleus.gdshader")
## How many bulges the nucleus's outline has, and the most craters on it.
const BULGES: int = 18
const MOST_CRATERS: int = 10
## One turn takes this many seconds of game time, shortest and longest, either way round.
const SPIN_SECONDS_LEAST: float = 180.0
const SPIN_SECONDS_MOST: float = 360.0
## The nucleus's square is this many radii across, so the lumps have room.
const SQUARE_RADII: float = 2.4
## Under this many pixels across, the nucleus is a small dot instead.
const DOT_BELOW: float = 1.5

# What the comet's name decides: its outline, craters, spin, and where its jets sit.
var seed_value: float = 0.0
var bulges := PackedFloat32Array()
var craters := PackedVector4Array()
## Seconds for one turn, negative for turning the other way, and where in the turn it starts.
var spin_period: float = 300.0
var spin_start: float = 0.0
var jet_angles := PackedFloat32Array()

var _event: FlightEvent
var _gravity_model: GravityModel
var _pixels_per_unit: float = 1.0
var _roll: float = 0.0
var _nucleus: NucleusLayer


## What's drawn for the nucleus: its shader's square, or a dot when it's too small to show.
class NucleusLayer extends Node2D:
	var half: float = 0.0
	var dot: bool = false
	var dot_color: Color = Color.WHITE

	func _draw() -> void:
		if dot:
			draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), dot_color)
		else:
			draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color.WHITE)


func setup(event: FlightEvent, gravity_model: GravityModel = null) -> void:
	_event = event
	_gravity_model = gravity_model
	_work_out_look()
	_nucleus = NucleusLayer.new()
	var material := ShaderMaterial.new()
	material.shader = NUCLEUS_SHADER
	material.set_shader_parameter("seed", seed_value)
	material.set_shader_parameter("bulges", bulges)
	material.set_shader_parameter("craters", craters)
	material.set_shader_parameter("crater_count", craters.size())
	material.set_shader_parameter("nucleus_color", event.type.nucleus_color)
	material.set_shader_parameter("dust_color", event.type.dust_color)
	_nucleus.material = material
	add_child(_nucleus)


# Everything the comet's name decides, the same every time for the same name.
func _work_out_look() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("comet|%s" % _event.name).hash()
	seed_value = float(rng.randi() & 0xFFFF)
	bulges.clear()
	for i in range(BULGES):
		bulges.append(rng.randf_range(0.72, 1.0))
	craters.clear()
	for i in range(rng.randi_range(6, MOST_CRATERS)):
		var around: float = rng.randf() * TAU
		var from_middle: float = sqrt(rng.randf()) * 0.7
		craters.append(Vector4(cos(around) * from_middle, sin(around) * from_middle,
				rng.randf_range(0.1, 0.26), rng.randf_range(0.12, 0.3)))
	spin_period = rng.randf_range(SPIN_SECONDS_LEAST, SPIN_SECONDS_MOST) * (1.0 if rng.randf() < 0.5 else -1.0)
	spin_start = rng.randf() * TAU
	jet_angles.clear()
	for i in range(rng.randi_range(mini(2, _event.type.jets), maxi(_event.type.jets, 2))):
		jet_angles.append(rng.randf() * TAU)


## How far the nucleus has turned at a time on the flight's clock, in radians.
func spin_at(time: float) -> float:
	var lap: float = absf(spin_period)
	return spin_start + signf(spin_period) * TAU * fposmod(time, lap) / lap


func place(center_x: float, center_y: float, pixels_per_unit: float, roll: float) -> void:
	_pixels_per_unit = pixels_per_unit
	_roll = roll
	position = Vector2((_event.state.x - center_x) * pixels_per_unit, (_event.state.y - center_y) * pixels_per_unit)
	# Only while some of it could be on screen: the tail reaches far.
	var reach: float = (_event.type.tail_length + _event.type.scan_reach) * pixels_per_unit
	visible = position.length() <= reach + 2000.0
	if visible:
		_place_nucleus()
	queue_redraw()


# The nucleus's square, with what its shader needs to light it this moment.
func _place_nucleus() -> void:
	var type: EventType = _event.type
	var state: ShipState = _event.state
	var radius: float = type.nucleus_radius * _pixels_per_unit
	_nucleus.dot = radius < DOT_BELOW
	_nucleus.dot_color = type.glow_color
	_nucleus.half = radius * SQUARE_RADII / 2.0
	_nucleus.queue_redraw()
	if _nucleus.dot:
		return
	var toward_star: Vector2 = -Vector2(state.x, state.y).normalized()
	var sun: float = 1.0
	if _gravity_model != null:
		sun = Sunlight.at(_gravity_model, state.x, state.y, state.time)
	var material: ShaderMaterial = _nucleus.material as ShaderMaterial
	material.set_shader_parameter("spin", spin_at(state.time))
	material.set_shader_parameter("light_dir", toward_star)
	material.set_shader_parameter("sun", sun)
	material.set_shader_parameter("radius_px", radius)
	material.set_shader_parameter("block", clampf(floorf(radius / 20.0), 1.0, 6.0))
	material.set_shader_parameter("roll", _roll)


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
