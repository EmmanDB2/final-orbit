# pilot.gd: the pilot, aboard the ship, out on EVA with a jetpack, or inside a station. Whichever it
# is, this decides what moving and the action button do. Out of the ship, the arrows and dragging go
# by the screen: up is up on screen. The jetpack pushes against orbital mechanics like anything else,
# and can run out. Inside, the pilot walks around the station's floors, which go around with it.
# From DESIGN.md, "Player" (EVA, and the same sprite scale inside and outside) and "Camera, zoom, and
# landing" (interiors). Behind FeatureFlags.EVA and FeatureFlags.INTERIORS.
class_name Pilot
extends Node2D

## The same readouts the ship gives, for when the pilot's out of it.
signal flight_data_changed(data: Dictionary)
## Emitted when the pilot goes aboard, on EVA, or inside: one of the modes below.
signal mode_changed(mode: String)
## Emitted when what the action button does changes, with its label, or nothing for no button.
signal action_changed(label: String)
## Emitted when leaving the ship becomes possible or not.
signal can_leave_changed(can_leave: bool)
## Emitted when the pilot can't get anywhere anymore.
signal stranded_changed(stranded: bool)
## Emitted when the pilot should hear something.
signal message_raised(text: String)

const ABOARD: String = "aboard"
const EVA: String = "eva"
const INSIDE: String = "inside"

@export var data: PilotData
## How often the readouts update, in physics ticks.
@export var telemetry_interval_ticks: int = 3
## Farther out than this, the pilot is drawn as a dot, in pixels per world unit.
@export var dot_max_zoom: float = 1.0 / 32.0

var mode: String = ABOARD
var state := ShipState.new()
var gas: float = 0.0
## Which way the pilot faces, in the world.
var facing: float = 0.0

var _gravity_model: GravityModel
var _ship: Node2D
var _station: StationView
var _sprite := Sprite2D.new()
var _roll: float = 0.0
var _has_drag: bool = false
var _drag_heading: float = 0.0
var _firing := Vector2.ZERO
# Inside: where the pilot is and how they're moving, which way they face, in the station's frame.
var _local := Vector2.ZERO
var _walking := Vector2.ZERO
var _local_facing: float = 0.0
var _action: String = ""
var _can_leave: bool = false
var _stranded: bool = false
var _lost: bool = false
var _pixels_per_unit: float = 1.0
var _show_dot: bool = false
var _last_interact_frame: int = -1
var _animation_time: float = 0.0


## Starts the pilot aboard the ship.
func start_pilot(gravity_model: GravityModel, ship: Node2D, station: StationView) -> void:
	_gravity_model = gravity_model
	_ship = ship
	_station = station
	gas = data.jet_seconds
	state.ground_clearance = data.body_radius
	# Before the ship's tick, so the pilot and ship both reach the same moment before the view's drawn.
	process_physics_priority = -3
	_sprite.texture = data.texture
	_sprite.hframes = data.hframes
	_sprite.vframes = data.vframes
	add_child(_sprite)
	visible = false


func _physics_process(delta: float) -> void:
	if _gravity_model == null:
		return
	match mode:
		ABOARD:
			_tick_aboard(delta)
		EVA:
			_tick_eva(delta)
		INSIDE:
			_tick_inside(delta)
	if mode == INSIDE and Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report()


func _tick_aboard(delta: float) -> void:
	var ship_state: ShipState = _ship.state
	_set_can_leave(FeatureFlags.EVA and _ship.can_be_left())
	var docked_port: int = _station.docked_port
	_set_action("BOARD STATION" if FeatureFlags.INTERIORS and _ship.docked and docked_port >= 0 else "")
	if _can_leave and Input.is_action_just_pressed("eva"):
		_leave_ship()
		_tick_eva(delta)
	elif _action != "" and _interact_pressed():
		_enter_station(docked_port)
		_tick_inside(delta)


func _leave_ship() -> void:
	var ship_state: ShipState = _ship.state
	var out: Vector2 = _ship.eva_exit_offset()
	var moving: Vector2 = Vector2(ship_state.velocity_x, ship_state.velocity_y) + Vector2(-out.y, out.x) * _ship.angular_velocity
	moving += out.normalized() * data.push_off_speed
	state.x = ship_state.x + out.x
	state.y = ship_state.y + out.y
	state.velocity_x = moving.x
	state.velocity_y = moving.y
	state.time = ship_state.time
	facing = _ship.heading
	_ship.set_pilot_aboard(false)
	_set_mode(EVA)


func _tick_eva(delta: float) -> void:
	if _lost:
		_gravity_model.propagate(state, delta)
		return
	# The ship hasn't moved yet this tick, so this is the moment the two can be compared.
	_look_around_outside()
	_set_stranded(gas <= 0.0 and _action == "")
	if _action != "" and _interact_pressed():
		_act_outside()
		if mode == INSIDE:
			_tick_inside(delta)
		if mode != EVA:
			return
	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report()
	var move: Vector2 = _wanted_move()
	_firing = Vector2.ZERO
	if move != Vector2.ZERO and gas > 0.0:
		state.velocity_x += move.x * data.jet_acceleration * delta
		state.velocity_y += move.y * data.jet_acceleration * delta
		gas = maxf(gas - move.length() * delta, 0.0)
		_firing = move
		facing = rotate_toward(facing, atan2(move.x, -move.y), data.turn_speed * delta)
	_gravity_model.propagate(state, delta)
	if state.is_on_surface():
		_lost = true
		visible = false
		message_raised.emit("PILOT LOST")
		_set_stranded(true)
		_set_action("")
		return
	_bump_station()


func _bump_station() -> void:
	var hit: Dictionary = _station.push_pilot_out(state.x, state.y, state.time, data.body_radius)
	if hit.is_empty():
		return
	var normal: Vector2 = hit["normal"]
	state.x += normal.x * hit["push"]
	state.y += normal.y * hit["push"]
	var moving: Vector2 = hit["moving"]
	var against := Vector2(state.velocity_x, state.velocity_y) - moving
	var into: float = against.dot(normal)
	if into < 0.0:
		state.velocity_x -= normal.x * into * 1.2
		state.velocity_y -= normal.y * into * 1.2


func _look_around_outside() -> void:
	var ship_state: ShipState = _ship.state
	var cockpit: Vector2 = _ship.cockpit_offset()
	var from_ship := Vector2(state.x - ship_state.x - cockpit.x, state.y - ship_state.y - cockpit.y)
	var against_ship: float = (Vector2(state.velocity_x, state.velocity_y) - Vector2(ship_state.velocity_x, ship_state.velocity_y)).length()
	if from_ship.length() <= data.board_reach and against_ship <= data.board_speed and _ship.can_be_boarded():
		_set_action("BOARD SHIP")
		return
	if FeatureFlags.INTERIORS and _station.free_port_near(state.x, state.y, state.time, data.hatch_reach) >= 0:
		_set_action("BOARD STATION")
		return
	_set_action("")


func _act_outside() -> void:
	if _action == "BOARD SHIP":
		_board_ship()
	elif _action == "BOARD STATION":
		_enter_station(_station.free_port_near(state.x, state.y, state.time, data.hatch_reach))


func _board_ship() -> void:
	gas = data.jet_seconds
	_firing = Vector2.ZERO
	_ship.set_pilot_aboard(true)
	_station.set_roof_off(false)
	_set_stranded(false)
	_set_mode(ABOARD)


func _enter_station(port: int) -> void:
	gas = data.jet_seconds
	_firing = Vector2.ZERO
	_local = _station.port_inner(port)
	_walking = Vector2.ZERO
	_local_facing = atan2(-_station.port_face(port).x, _station.port_face(port).y)
	if _ship.pilot_aboard:
		_ship.set_pilot_aboard(false)
	_station.set_roof_off(true)
	_set_stranded(false)
	_set_mode(INSIDE)


func _tick_inside(delta: float) -> void:
	# The ship hasn't moved yet this tick, and this has to land on the moment it's about to reach. A
	# single tick out would put the pilot hundreds of units off, at orbital speed.
	state.time = _ship.state.time + delta
	var frame: Dictionary = _station.frame_at(state.time)
	var wanted: Vector2 = _wanted_move().rotated(-frame["angle"]) * data.walk_speed
	_walking = _walking.move_toward(wanted, data.walk_acceleration * delta)
	# One way at a time, so a wall stops only the part of the move going into it.
	var along_x := Vector2(_walking.x * delta, 0.0)
	if _station.pilot_fits(_local + along_x, data.body_radius):
		_local += along_x
	else:
		_walking.x = 0.0
	var along_y := Vector2(0.0, _walking.y * delta)
	if _station.pilot_fits(_local + along_y, data.body_radius):
		_local += along_y
	else:
		_walking.y = 0.0
	if _walking.length() > 5.0:
		_local_facing = rotate_toward(_local_facing, atan2(_walking.x, -_walking.y), data.turn_speed * delta)
	_place_inside(frame)

	var spot: Dictionary = _station.spot_near(_local, data.use_reach)
	var port: int = _station.port_near_inside(_local, data.use_reach)
	if not spot.is_empty():
		_set_action("USE TERMINAL")
	elif port >= 0:
		_set_action("BOARD SHIP" if port == _station.docked_port else "EXIT STATION")
	else:
		_set_action("")
	if _action != "" and _interact_pressed():
		match _action:
			"USE TERMINAL":
				message_raised.emit("NO GIGS POSTED YET")
			"BOARD SHIP":
				_board_ship()
			"EXIT STATION":
				_leave_station(port, frame)


func _place_inside(frame: Dictionary) -> void:
	var offset: Vector2 = _local.rotated(frame["angle"])
	var moving: Vector2 = _station.moving_at(frame, offset) + _walking.rotated(frame["angle"])
	state.x = frame["x"] + offset.x
	state.y = frame["y"] + offset.y
	state.velocity_x = moving.x
	state.velocity_y = moving.y
	facing = _local_facing + frame["angle"]


func _leave_station(port: int, frame: Dictionary) -> void:
	var face: Vector2 = _station.port_face(port)
	var outside: Vector2 = (_station.port_outer(port, data.body_radius + 4.0)).rotated(frame["angle"])
	var moving: Vector2 = _station.moving_at(frame, outside) + face.rotated(frame["angle"]) * data.push_off_speed
	state.x = frame["x"] + outside.x
	state.y = frame["y"] + outside.y
	state.velocity_x = moving.x
	state.velocity_y = moving.y
	facing = atan2(face.rotated(frame["angle"]).x, -face.rotated(frame["angle"]).y)
	_walking = Vector2.ZERO
	_station.set_roof_off(false)
	_set_mode(EVA)


# One press does one thing, even when doing it opens up something else to do.
func _interact_pressed() -> bool:
	if not Input.is_action_just_pressed("interact") or _last_interact_frame == Engine.get_physics_frames():
		return false
	_last_interact_frame = Engine.get_physics_frames()
	return true


# Which way the pilot wants to go, in the world, up to full push. The buttons go by the screen.
func _wanted_move() -> Vector2:
	var on_screen := Vector2(
			Input.get_axis("translate_left", "translate_right") + Input.get_axis("turn_left", "turn_right"),
			-Input.get_axis("translate_back", "translate_forward") - (1.0 if Input.is_action_pressed("thrust") else 0.0))
	if on_screen != Vector2.ZERO:
		return on_screen.limit_length(1.0).rotated(_roll)
	if _has_drag:
		return Vector2.UP.rotated(_drag_heading)
	return Vector2.ZERO


## Starts or updates a drag: the pilot goes this way until it ends.
func point_at(target_heading: float) -> void:
	_has_drag = true
	_drag_heading = target_heading


func stop_pointing() -> void:
	_has_drag = false


func guide_radius() -> float:
	return maxf(32.0 * _pixels_per_unit, 16.0)


func _set_mode(new_mode: String) -> void:
	mode = new_mode
	_has_drag = false
	visible = mode != ABOARD
	_set_action("")
	mode_changed.emit(mode)


func _set_action(label: String) -> void:
	if label != _action:
		_action = label
		action_changed.emit(label)


func _set_can_leave(can_leave: bool) -> void:
	if can_leave != _can_leave:
		_can_leave = can_leave
		can_leave_changed.emit(can_leave)


func _set_stranded(stranded: bool) -> void:
	if stranded != _stranded:
		_stranded = stranded
		stranded_changed.emit(stranded)


func _report() -> void:
	var against := Vector2(state.velocity_x, state.velocity_y)
	var near_station: bool = mode == INSIDE
	var ship_state: ShipState = _ship.state
	var near: bool = true
	if mode == INSIDE:
		against = _station.moving_at(_station.frame_at(state.time), Vector2(state.x, state.y) - _station_center())
	elif _station.is_nearby(state.x, state.y, state.time):
		against = _station.moving_at(_station.frame_at(state.time), Vector2(state.x, state.y) - _station_center())
		near_station = true
	elif Vector2(state.x - ship_state.x, state.y - ship_state.y).length() <= 5000.0:
		against = Vector2(ship_state.velocity_x, ship_state.velocity_y)
	else:
		var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
		against = Vector2(ground[0], ground[1])
		near = false
	var relative: Vector2 = Vector2(state.velocity_x, state.velocity_y) - against
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	flight_data_changed.emit({
		"altitude": _gravity_model.get_altitude(state.x, state.y, state.time),
		"speed": relative.length(),
		"against_station": near,
		"docked": false,
		"landed": false,
		"periapsis": apsides[0],
		"apoapsis": apsides[1],
		"time": state.time,
		"heading": facing,
		"prograde": atan2(relative.x, -relative.y),
		"moving": relative.length_squared() >= 0.25,
		"spin": 0.0,
		"fuel_share": gas / data.jet_seconds,
		"delta_v": gas * data.jet_acceleration,
		"status": "INSIDE THE STATION" if mode == INSIDE else ("NEAR THE STATION" if near_station else "ON EVA"),
	})


func _station_center() -> Vector2:
	var frame: Dictionary = _station.frame_at(state.time)
	return Vector2(frame["x"], frame["y"])


# Picks the frame for what the pilot's doing. The sheet draws four headings, from two views and their
# mirror images. Up in a station that's all it uses, so the pixels stay square with the floor. Out in
# space they turn the rest of the way from whichever's nearest.
func _process(delta: float) -> void:
	if mode == ABOARD:
		return
	_animation_time += delta
	var on_screen: float = wrapf(facing - _roll, -PI, PI)
	var quarter: int = roundi(on_screen / (PI / 2.0))
	var sideways: bool = absi(quarter) == 1
	var frames: PackedInt32Array
	var fps: float
	if mode == INSIDE:
		frames = data.walk_side if sideways else data.walk_down
		fps = data.walk_fps if _walking.length() > 5.0 else 0.0
	elif _firing != Vector2.ZERO:
		frames = data.jet_side if sideways else data.jet_down
		fps = data.jet_fps
	else:
		frames = data.coast_side if sideways else data.coast_down
		fps = data.coast_fps
	_sprite.frame = frames[int(_animation_time * fps) % frames.size()]
	_sprite.flip_h = quarter == -1
	_sprite.flip_v = quarter == 0
	var leftover: float = 0.0 if mode == INSIDE else on_screen - quarter * PI / 2.0
	rotation = leftover + _roll


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	if mode == ABOARD:
		return
	_pixels_per_unit = pixels_per_unit
	position = Vector2((state.x - center_x) * pixels_per_unit, (state.y - center_y) * pixels_per_unit)
	_sprite.scale = Vector2.ONE * minf(pixels_per_unit, 1.0)
	var show_dot: bool = pixels_per_unit < dot_max_zoom
	_sprite.visible = not show_dot
	_show_dot = show_dot
	queue_redraw()


func _draw() -> void:
	if _show_dot:
		var palette: AgencyPalette = UiStyle.palette()
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), palette.hull_darkest)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), palette.telemetry_cyan)
