# astronaut_view.gd: draws the 3D pilot as pixel art. The model renders live into a small canvas
# at 1 px per 5 cm, already turned to its angle on screen so its pixels stay square with the
# screen, and a shader snaps it to the agency palette and outlines it. This also poses the joints
# every frame from what the pilot's doing, and draws the jetpack's flames. Seen from the side on
# worlds and in space, and from above inside stations.
# From DESIGN.md, "Player" (the 3D pilot being tried against the sprite sheets).
class_name AstronautView
extends Node2D

## How the pilot is seen.
enum Look { SIDE, ABOVE }

## How big the canvas is, in pixels, with the body's middle at its center.
const CANVAS: int = 64
## How many meters one pixel is.
const METERS_PER_PIXEL: float = 0.05
## How high the body's middle is above the boot soles, in meters. The model turns around it.
const MIDDLE: float = 0.93
## How far each hip is above the boot sole, in meters, for keeping the feet down.
const LEG_LENGTH: float = 0.65
## How far in front of and behind the body's middle the distance render reaches, in meters.
const DEPTH_REACH: float = 1.2
## How much nearer, in meters, a part has to be than what's behind it to get a line round it.
const LINE_STEP: float = 0.09
## Surfaces farther from the camera than this, in meters past the body's middle, are the far side
## and drawn a shade darker.
const FAR_SIDE: float = -0.05

## How the pilot is seen, and which way their head points on screen, clockwise from up.
var look: Look = Look.SIDE
var body_angle: float = 0.0
## Which way they face on screen when seen from the side.
var facing_right: bool = true
## What they're doing: &"idle", &"walk", &"air", &"jet", &"float", &"land", or &"push".
var motion: StringName = &"idle"
## Walking speed as a share of full speed, and in the air, how fast they're rising as a share of
## a jump's speed (negative falling).
var speed_share: float = 0.0
var rise_share: float = 0.0
## How far below the point this node marks the boot soles are, in pixels, when they stand
## on something. Zero puts the body's middle on the point.
var feet_below: float = 0.0
## Which way the jetpack is pushing on screen, or zero.
var thrust := Vector2.ZERO
## The view's turn, so the canvas can stay square with the screen.
var screen_roll: float = 0.0

var palette: AgencyPalette

var _viewport := SubViewport.new()
var _camera := Camera3D.new()
var _pivot := Node3D.new()
var _model := AstronautModel.new()
# A second copy, posed the same, painted by distance from the camera, for the lines between parts.
var _depth_viewport := SubViewport.new()
var _depth_pivot := Node3D.new()
var _depth_model := AstronautModel.new()
var _sprite := Sprite2D.new()
var _yaw: float = -PI / 2.0
var _phase: float = 0.0
var _time: float = 0.0
var _flicker: float = 0.0


func _ready() -> void:
	if palette == null:
		palette = UiStyle.palette()
	_viewport.size = Vector2i(CANVAS, CANVAS)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camera.environment = environment
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CANVAS * METERS_PER_PIXEL
	_camera.position = Vector3(0.0, 0.0, 6.0)
	_camera.near = 0.1
	_camera.far = 12.0
	_viewport.add_child(_camera)

	# Lit from the upper left, a little from the front, wherever the pilot turns.
	var light := DirectionalLight3D.new()
	light.light_energy = 0.9
	_viewport.add_child(light)
	light.look_at_from_position(Vector3(-1.0, 1.4, 1.2), Vector3.ZERO)

	_viewport.add_child(_pivot)
	_model.palette = palette
	_model.position = Vector3(0.0, -MIDDLE, 0.0)
	_pivot.add_child(_model)
	_build_depth_view()

	_sprite.texture = _viewport.get_texture()
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/pilot/astronaut_pixels.gdshader")
	var colors := PackedVector3Array()
	var colors_lab := PackedVector3Array()
	for color_name: StringName in [&"hull_dark", &"hull_mid", &"hull_light", &"hull_lighter", &"hull_lightest",
			&"gold_darkest", &"gold_dark", &"gold", &"gold_light", &"agency_orange_dark", &"agency_orange",
			&"agency_orange_light", &"agency_blue_dark", &"agency_blue", &"agency_blue_light"]:
		var color: Color = palette.get(color_name)
		colors.append(Vector3(color.r, color.g, color.b))
		colors_lab.append(_to_oklab(color))
	material.set_shader_parameter("color_count", colors.size())
	# The shader's arrays are a fixed length.
	colors.resize(24)
	colors_lab.resize(24)
	material.set_shader_parameter("colors", colors)
	material.set_shader_parameter("colors_lab", colors_lab)
	material.set_shader_parameter("distances", _depth_viewport.get_texture())
	material.set_shader_parameter("step_to_line", LINE_STEP / (DEPTH_REACH * 2.0))
	material.set_shader_parameter("far_side", 0.5 + FAR_SIDE / (DEPTH_REACH * 2.0))
	material.set_shader_parameter("outline_color", palette.hull_darkest)
	_sprite.material = material
	# Behind this node's own drawing, so the flames show in front.
	_sprite.show_behind_parent = true
	add_child(_sprite)


func _build_depth_view() -> void:
	_depth_viewport.size = Vector2i(CANVAS, CANVAS)
	_depth_viewport.transparent_bg = true
	_depth_viewport.own_world_3d = true
	_depth_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_depth_viewport)
	var camera := Camera3D.new()
	camera.environment = _camera.environment
	camera.projection = _camera.projection
	camera.size = _camera.size
	camera.position = _camera.position
	camera.near = _camera.near
	camera.far = _camera.far
	_depth_viewport.add_child(camera)
	_depth_viewport.add_child(_depth_pivot)
	_depth_model.position = _model.position
	_depth_pivot.add_child(_depth_model)
	var painted := ShaderMaterial.new()
	painted.shader = load("res://scripts/pilot/astronaut_depth.gdshader")
	painted.set_shader_parameter("nearest", _camera.position.z - DEPTH_REACH)
	painted.set_shader_parameter("farthest", _camera.position.z + DEPTH_REACH)
	for piece: Node in _depth_model.find_children("*", "MeshInstance3D", true, false):
		(piece as MeshInstance3D).material_override = painted


func _process(delta: float) -> void:
	# Nothing to render while the pilot's aboard.
	var update: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	_viewport.render_target_update_mode = update
	_depth_viewport.render_target_update_mode = update
	if not is_visible_in_tree():
		return
	_time += delta
	_flicker += delta
	_turn(delta)
	_pose(delta)
	# Square with the screen, with the body's middle where the feet put it.
	global_rotation = screen_roll
	var up := Vector2.UP.rotated(body_angle)
	_sprite.position = up * (MIDDLE / METERS_PER_PIXEL - feet_below) if feet_below > 0.0 else Vector2.ZERO
	queue_redraw()


# Turns the model to its angle on screen. Changing direction from the side turns through the
# front, so the visor sweeps past.
func _turn(delta: float) -> void:
	var wanted_yaw: float = -PI / 2.0 if facing_right else -PI * 1.5
	_yaw = move_toward(_yaw, wanted_yaw, 9.0 * delta)
	var roll := Basis(Vector3.BACK, -body_angle)
	if look == Look.ABOVE:
		# The top of the helmet toward the camera, and the front up the screen before turning.
		_pivot.basis = roll * Basis(Vector3.RIGHT, PI / 2.0)
	else:
		_pivot.basis = roll * Basis(Vector3.UP, _yaw)
	_depth_pivot.basis = _pivot.basis


func _pose(delta: float) -> void:
	var walking: float = clampf(speed_share, 0.0, 1.0)
	# About two steps a second at full speed, slower when slower.
	_phase = fmod(_phase + delta * TAU * lerpf(0.6, 1.0, walking) * (0.9 if walking > 0.05 else 0.0), TAU)
	var hip_l: float = 0.0
	var hip_r: float = 0.0
	var knee_l: float = -0.08
	var knee_r: float = -0.08
	var arm_l: float = 0.0
	var arm_r: float = 0.0
	var arm_out: float = 0.12
	var elbow: float = 0.18
	var lean: float = 0.0
	var drop: float = 0.0
	var breathe: float = sin(_time * 1.7) * 0.025
	match motion:
		&"walk":
			var swing: float = 0.62 * sqrt(walking)
			hip_l = swing * sin(_phase)
			hip_r = -hip_l
			knee_l = -(0.1 + 1.1 * swing * maxf(cos(_phase), 0.0))
			knee_r = -(0.1 + 1.1 * swing * maxf(-cos(_phase), 0.0))
			arm_l = -0.8 * hip_l
			arm_r = -0.8 * hip_r
			lean = -0.1 * walking
			drop = LEG_LENGTH * (1.0 - cos(absf(hip_l)))
		&"air":
			var tuck: float = 1.0 - clampf(absf(rise_share), 0.0, 1.0)
			hip_l = 0.2 + 0.7 * tuck
			hip_r = 0.05 + 0.6 * tuck
			knee_l = -(0.35 + 1.1 * tuck)
			knee_r = -(0.25 + 1.0 * tuck)
			arm_l = 0.3 + 0.5 * maxf(rise_share, 0.0)
			arm_r = 0.1 + 0.4 * maxf(rise_share, 0.0)
			arm_out = 0.45
			elbow = 0.5
		&"land", &"push":
			hip_l = 0.75
			hip_r = 0.65
			knee_l = -1.3
			knee_r = -1.2
			arm_l = 0.4
			arm_r = 0.3
			arm_out = 0.3
			elbow = 0.6
			lean = -0.3
			drop = 0.16
		&"jet":
			hip_l = -0.05 + sin(_time * 3.1) * 0.06
			hip_r = 0.12 + sin(_time * 2.7 + 1.0) * 0.06
			knee_l = -0.35
			knee_r = -0.55
			arm_l = 0.35
			arm_r = 0.2
			arm_out = 0.5
			elbow = 0.7
		&"float":
			hip_l = 0.25 + sin(_time * 0.7) * 0.18
			hip_r = 0.05 + sin(_time * 0.55 + 2.0) * 0.18
			knee_l = -0.5 + sin(_time * 0.9 + 1.0) * 0.2
			knee_r = -0.4 + sin(_time * 0.8 + 0.4) * 0.2
			arm_l = 0.3 + sin(_time * 0.6) * 0.25
			arm_r = 0.1 + sin(_time * 0.5 + 1.5) * 0.25
			arm_out = 0.55 + sin(_time * 0.45) * 0.15
			elbow = 0.5 + sin(_time * 0.7 + 0.5) * 0.2
	_turn_joint(&"hip_l", Vector3(hip_l, 0.0, 0.0))
	_turn_joint(&"hip_r", Vector3(hip_r, 0.0, 0.0))
	_turn_joint(&"knee_l", Vector3(knee_l, 0.0, 0.0))
	_turn_joint(&"knee_r", Vector3(knee_r, 0.0, 0.0))
	# The boots stay about level with the ground.
	_turn_joint(&"ankle_l", Vector3(-(hip_l + knee_l) * 0.8, 0.0, 0.0))
	_turn_joint(&"ankle_r", Vector3(-(hip_r + knee_r) * 0.8, 0.0, 0.0))
	_turn_joint(&"shoulder_l", Vector3(arm_l, 0.0, -arm_out))
	_turn_joint(&"shoulder_r", Vector3(arm_r, 0.0, arm_out))
	_turn_joint(&"elbow_l", Vector3(elbow, 0.0, 0.0))
	_turn_joint(&"elbow_r", Vector3(elbow, 0.0, 0.0))
	_turn_joint(&"spine", Vector3(lean * 0.5, 0.0, 0.0))
	_turn_joint(&"chest", Vector3(lean * 0.5 + breathe, 0.0, 0.0))
	_model.joint(&"root").position = Vector3(0.0, -drop, 0.0)
	_depth_model.joint(&"root").position = Vector3(0.0, -drop, 0.0)


func _turn_joint(joint_name: StringName, angles: Vector3) -> void:
	_model.joint(joint_name).rotation = angles
	_depth_model.joint(joint_name).rotation = angles


# Flames from the nozzles, the way the jetpack pushes the other way, flickering.
func _draw() -> void:
	if thrust == Vector2.ZERO or palette == null:
		return
	for nozzle: StringName in [&"jet_nozzle_l", &"jet_nozzle_r"]:
		var mark: Marker3D = _model.marker(nozzle)
		var at: Vector2 = _on_canvas(mark.global_position)
		var out: Vector2 = (_on_canvas(mark.global_position - mark.global_basis.y * 0.3) - at).normalized()
		var length: float = 4.0 + 2.0 * sin(_flicker * 31.0 + float(nozzle.length()))
		for step in range(int(length)):
			var color: Color = palette.thrust_white if step < 2 else (palette.thrust_yellow if step < length - 1.5 else palette.thrust_red)
			var spot: Vector2 = (at + out * (step + 1.0)).floor()
			draw_rect(Rect2(spot, Vector2.ONE), color)


# Where a point in the model's world lands on this node, in pixels.
func _on_canvas(point: Vector3) -> Vector2:
	return _camera.unproject_position(point) - Vector2(CANVAS, CANVAS) * 0.5 + _sprite.position


func _to_oklab(color: Color) -> Vector3:
	var linear: Color = color.srgb_to_linear()
	var l: float = pow(0.4122 * linear.r + 0.5363 * linear.g + 0.0514 * linear.b, 1.0 / 3.0)
	var m: float = pow(0.2119 * linear.r + 0.6807 * linear.g + 0.1074 * linear.b, 1.0 / 3.0)
	var s: float = pow(0.0883 * linear.r + 0.2817 * linear.g + 0.6300 * linear.b, 1.0 / 3.0)
	return Vector3(
			0.2105 * l + 0.7936 * m - 0.0041 * s,
			1.9780 * l - 2.4286 * m + 0.4506 * s,
			0.0259 * l + 0.7828 * m - 0.8087 * s)
