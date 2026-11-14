# comet_view.gd: a passing comet, all in code and shaders, being nature's: a lumpy, cratered nucleus
# lit from the star, tumbling slowly, with gas jets; a coma as wide as the scan reaches; a straight
# ion tail away from the star; and a dust tail that follows the comet's own path back from the
# nucleus, measured against the planet it's passing, and bends away from the star, so it sweeps round
# as the comet swings past. The nucleus's outline, craters, spin, and jets all come from the comet's
# name, so the same comet always looks the same. Everything's drawn in banded, dithered game pixels
# by two shaders. From DESIGN.md, "Mid-flight events" (passing comets).
class_name CometView
extends Node2D

const NUCLEUS_SHADER: Shader = preload("res://shaders/comet_nucleus.gdshader")
const GLOW_SHADER: Shader = preload("res://shaders/comet_glow.gdshader")
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
## The dust path: how many steps back along it, how often it's worked out again in seconds of game
## time, and the furthest back it goes, in seconds.
const DUST_SEGMENTS: int = 24
const DUST_REBUILD_SECONDS: float = 2.0
const DUST_MOST_SECONDS: float = 900.0
## How wide the glow's game pixels are, in screen pixels.
const GLOW_BLOCK: float = 4.0
## A jet's spot starts spraying once it faces the star this much (the dot of its direction with the
## star's), and sprays fully at the second number.
const JET_FACING_FROM: float = 0.1
const JET_FACING_TO: float = 0.5

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
var _glow: GlowLayer
var _nucleus: NucleusLayer
# The dust tail's path: where the comet was, against the middle of the world it's passing, going
# back from the nucleus, as world units, and when that was worked out on the flight's clock.
var _dust_offsets := PackedVector2Array()
var _dust_built_at: float = -1.0e30
# The same path as it's drawn now, in screen pixels from the nucleus, and how far from the nucleus its
# furthest point is, in world units.
var _dust_points := PackedVector2Array()
var _dust_extent: float = 0.0


## What's drawn for the coma, the tails, and the jets: one rectangle for their shader.
class GlowLayer extends Node2D:
	var rect := Rect2()

	func _draw() -> void:
		draw_rect(rect, Color.WHITE)


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
	# The glow first, and the nucleus over it.
	_glow = GlowLayer.new()
	var glow_material := ShaderMaterial.new()
	glow_material.shader = GLOW_SHADER
	glow_material.set_shader_parameter("seed", seed_value)
	glow_material.set_shader_parameter("glow_color", event.type.glow_color)
	glow_material.set_shader_parameter("ion_color", event.type.ion_color)
	glow_material.set_shader_parameter("dust_color", event.type.dust_tail_color)
	glow_material.set_shader_parameter("block", GLOW_BLOCK)
	_glow.material = glow_material
	add_child(_glow)
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
	# Only while some of it could be on screen: the tails reach far, and so does the dust path.
	var type: EventType = _event.type
	var reach: float = (maxf(type.tail_length, _dust_extent) + type.scan_reach) * pixels_per_unit
	visible = position.length() <= reach + 2000.0
	if visible:
		if absf(_event.state.time - _dust_built_at) >= DUST_REBUILD_SECONDS:
			_rebuild_dust()
		_place_glow()
		_place_nucleus()


# The nucleus's square, with what its shader needs to light it this moment.
func _place_nucleus() -> void:
	var type: EventType = _event.type
	var radius: float = type.nucleus_radius * _pixels_per_unit
	_nucleus.dot = radius < DOT_BELOW
	_nucleus.dot_color = type.glow_color
	_nucleus.half = radius * SQUARE_RADII / 2.0
	_nucleus.queue_redraw()
	if _nucleus.dot:
		return
	var material: ShaderMaterial = _nucleus.material as ShaderMaterial
	material.set_shader_parameter("spin", spin_at(_event.state.time))
	material.set_shader_parameter("light_dir", toward_star())
	material.set_shader_parameter("sun", sun_level())
	material.set_shader_parameter("radius_px", radius)
	material.set_shader_parameter("block", clampf(floorf(radius / 20.0), 1.0, 6.0))
	material.set_shader_parameter("roll", _roll)


## The way the star is from the comet, as a unit vector. The star sits at the world's middle.
func toward_star() -> Vector2:
	var toward: Vector2 = -Vector2(_event.state.x, _event.state.y).normalized()
	return toward if toward != Vector2.ZERO else Vector2.LEFT


## How much of the star can be seen from the comet, from 0 to 1.
func sun_level() -> float:
	if _gravity_model == null:
		return 1.0
	return Sunlight.at(_gravity_model, _event.state.x, _event.state.y, _event.state.time)


## The dust tail's path as it's drawn now, in screen pixels from the nucleus.
func dust_points() -> PackedVector2Array:
	return _dust_points


# The glow's rectangle and what its shader needs: the coma, both tails, and the jets.
func _place_glow() -> void:
	var type: EventType = _event.type
	var scale_by: float = _pixels_per_unit
	var state: ShipState = _event.state
	var away: Vector2 = -toward_star()
	var across := Vector2(-away.y, away.x)
	var sun: float = sun_level()
	var nucleus_px: float = type.nucleus_radius * scale_by
	var reach_px: float = type.scan_reach * scale_by
	var ion_length_px: float = type.tail_length * scale_by
	var ion_end_px: float = type.tail_width / 3.0 * ion_length_px
	var dust_length_px: float = type.dust_length * scale_by
	var dust_end_px: float = type.tail_width * dust_length_px
	_draw_dust_path(away)
	# The jets: each spot turns with the nucleus, and only sprays while it faces the star.
	var spin: float = spin_at(state.time)
	var toward: Vector2 = -away
	var sprays := PackedVector4Array()
	for angle: float in jet_angles:
		var pointing: Vector2 = Vector2.from_angle(angle + spin)
		var facing: float = smoothstep(JET_FACING_FROM, JET_FACING_TO, pointing.dot(toward))
		sprays.append(Vector4(pointing.x, pointing.y, outline_at(angle) * nucleus_px * 0.9, facing))
	while sprays.size() < 3:
		sprays.append(Vector4.ZERO)
	# What the glow covers: the coma, the ion tail, the dust path, and the jets (inside the coma).
	var covered := Rect2(Vector2.ZERO, Vector2.ZERO).grow(reach_px)
	covered = covered.expand(away * ion_length_px + across * ion_end_px).expand(away * ion_length_px - across * ion_end_px)
	covered = covered.expand(-across * maxf(nucleus_px, GLOW_BLOCK)).expand(across * maxf(nucleus_px, GLOW_BLOCK))
	var dust_box := Rect2(Vector2.ZERO, Vector2.ZERO)
	for point: Vector2 in _dust_points:
		dust_box = dust_box.expand(point)
	covered = covered.merge(dust_box.grow(dust_end_px)).grow(GLOW_BLOCK * 2.0)
	# Only what's on screen is drawn, with room for the view's roll: the middle of the screen is at
	# minus the comet's position.
	var half_screen: float = get_viewport_rect().size.length() / 2.0 + GLOW_BLOCK * 2.0
	var on_screen := Rect2(-position - Vector2(half_screen, half_screen), Vector2(half_screen, half_screen) * 2.0)
	var shown: Rect2 = covered.intersection(on_screen)
	_glow.visible = shown.has_area()
	if not _glow.visible:
		return
	_glow.rect = shown
	_glow.queue_redraw()
	var material: ShaderMaterial = _glow.material as ShaderMaterial
	material.set_shader_parameter("view_origin", position)
	material.set_shader_parameter("roll", _roll)
	material.set_shader_parameter("sun", sun)
	material.set_shader_parameter("away", away)
	material.set_shader_parameter("reach_px", reach_px)
	material.set_shader_parameter("nucleus_px", nucleus_px)
	material.set_shader_parameter("ion_length_px", ion_length_px)
	material.set_shader_parameter("ion_end_px", ion_end_px)
	material.set_shader_parameter("dust_length_px", dust_length_px)
	material.set_shader_parameter("dust_end_px", dust_end_px)
	material.set_shader_parameter("dust_points", _dust_points)
	material.set_shader_parameter("jets", sprays)
	material.set_shader_parameter("jet_count", jet_angles.size())


## The nucleus's outline toward an angle in its own frame, in nominal radii, blended smoothly between
## the bulges on either side, as its shader does.
func outline_at(angle: float) -> float:
	var turns: float = fposmod(angle / TAU, 1.0) * BULGES
	var first: int = int(floorf(turns)) % BULGES
	var second: int = (first + 1) % BULGES
	var along: float = turns - floorf(turns)
	along = along * along * (3.0 - 2.0 * along)
	return lerpf(bulges[first], bulges[second], along)


# Works the dust path out again: step back from now along the comet's own path, keeping where it was
# against the middle of the world it's passing. The steps are sized by how fast it's going against
# that world, so the points add up to the dust tail's length along the path.
func _rebuild_dust() -> void:
	var state: ShipState = _event.state
	_dust_built_at = state.time
	_dust_offsets = PackedVector2Array()
	var world: int = _event.place.get("world", 0)
	if _gravity_model == null:
		return
	var spacing: float = _event.type.dust_length / DUST_SEGMENTS
	var past := ShipState.new()
	past.x = state.x
	past.y = state.y
	past.velocity_x = state.velocity_x
	past.velocity_y = state.velocity_y
	past.time = state.time
	past.ground_clearance = _event.type.nucleus_radius
	var age: float = 0.0
	_dust_offsets.append(_against_world(past, world))
	for step in range(DUST_SEGMENTS):
		var moving: PackedFloat64Array = _gravity_model.get_body_velocity(world, past.time)
		var speed: float = Vector2(past.velocity_x - moving[0], past.velocity_y - moving[1]).length()
		var back: float = minf(spacing / maxf(speed, 1.0), DUST_MOST_SECONDS - age)
		if back <= 0.0:
			break
		_gravity_model.propagate(past, -back)
		age += back
		if past.is_on_surface():
			break
		_dust_offsets.append(_against_world(past, world))
	# A path that ran out early ends where it stopped.
	while _dust_offsets.size() < DUST_SEGMENTS + 1:
		_dust_offsets.append(_dust_offsets[_dust_offsets.size() - 1])


# Where a state is against the middle of the world, at its own time.
func _against_world(past: ShipState, world: int) -> Vector2:
	var middle: PackedFloat64Array = _gravity_model.get_body_position(world, past.time)
	return Vector2(past.x - middle[0], past.y - middle[1])


# The dust path as it's drawn now, in screen pixels from the nucleus: each kept point is the world's
# middle now plus where the comet was against it, and the further along, the more it's pushed away from
# the star, so the tail bends away from it.
func _draw_dust_path(away: Vector2) -> void:
	_dust_points.resize(DUST_SEGMENTS + 1)
	_dust_extent = 0.0
	if _dust_offsets.size() < DUST_SEGMENTS + 1 or _gravity_model == null:
		for i in range(DUST_SEGMENTS + 1):
			_dust_points[i] = Vector2.ZERO
		return
	var state: ShipState = _event.state
	var world: int = _event.place.get("world", 0)
	var middle: PackedFloat64Array = _gravity_model.get_body_position(world, state.time)
	var comet := Vector2(state.x, state.y)
	var type: EventType = _event.type
	var units := PackedVector2Array()
	units.resize(DUST_SEGMENTS + 1)
	# The nucleus is the first point, wherever the path was worked out.
	units[0] = Vector2.ZERO
	for i in range(1, DUST_SEGMENTS + 1):
		units[i] = Vector2(middle[0], middle[1]) + _dust_offsets[i] - comet
	var along: float = 0.0
	for i in range(DUST_SEGMENTS + 1):
		if i > 0:
			along += units[i].distance_to(units[i - 1])
		var lifted: Vector2 = units[i] + away * type.dust_lift * type.dust_length * pow(along / type.dust_length, 2.0)
		_dust_extent = maxf(_dust_extent, lifted.length())
		_dust_points[i] = lifted * _pixels_per_unit
