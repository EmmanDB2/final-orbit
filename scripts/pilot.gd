# pilot.gd: the pilot, aboard the ship, out on EVA with a jetpack, inside a station, or on foot on a
# world. Whichever it is, this decides what moving and the action button do. On EVA the jetpack
# steers like the ship's RCS: the rotate buttons turn the pilot, letting go stops the turn, a drag
# turns them to face that way, and the arrows push relative to them, up toward the helmet. Walking,
# inside or on the ground, goes by the screen: up is up on screen. The jetpack pushes against
# orbital mechanics like anything else, and can run out. Inside, the pilot walks around the station's floors,
# which go around with it. On a world they're seen from the side: they walk along the ground as it
# turns, jump, and fall back under its gravity, which is too strong for the jetpack to do more than
# stretch a jump, on a second press in the air. At a building's door they can go in, and the front
# wall fades off: they walk its floors, climb its ladders, and use its terminals. Falling toward a
# world on EVA, they're seen from the side and flail harder the faster they drop. From DESIGN.md,
# "Player" (EVA, walking on worlds, and the same sprite scale inside and outside), "Places on worlds", and "Camera, zoom, and landing" (interiors). Behind
# FeatureFlags.EVA, FeatureFlags.INTERIORS, and FeatureFlags.WALKING_ON_WORLDS.
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
## Emitted when the pilot dies: what killed them ("IMPACT", "BURNED UP", or "AIR RAN OUT"), and how
## badly, from 0 to 1, which sets the med bay's bill.
signal died(cause: String, severity: float)
## Emitted when the pilot uses a terminal: a gig board, the station's or a base's mission computer, as
## {"kind": "station"} or {"kind": "site", "index": i}; or ship services, as {"kind": "service", "at":
## place}, the place being the station or the site the terminal's at.
signal terminal_used(place: Dictionary)

const ABOARD: String = "aboard"
const EVA: String = "eva"
const INSIDE: String = "inside"
const SURFACE: String = "surface"
const INDOORS: String = "indoors"
## The boxes the context menu draws around what an action is about, in art pixels: half a station
## hatch or terminal each way, a building's doorway, and half a building's terminal console.
const PORT_BOX: Vector2 = Vector2(10.0, 10.0)
const TERMINAL_BOX: Vector2 = Vector2(14.0, 14.0)
const DOOR_BOX: Vector2 = Vector2(28.0, 44.0)

@export var data: PilotData
## How often the readouts update, in physics ticks.
@export var telemetry_interval_ticks: int = 3
## Farther out than this, the pilot is drawn as a dot, in pixels per world unit.
@export var dot_max_zoom: float = 1.0 / 32.0

var mode: String = ABOARD
var state := ShipState.new()
var gas: float = 0.0
## Zen Mode: the jetpack never runs out.
var endless_gas: bool = false
## Someone held by the hand, in kilograms: the jetpack pushes the both of them, so less hard.
var carried_kg: float = 0.0
## How someone adrift close by is moving, as [x, y] velocity, so speeds read against them while
## reaching for their hand. Empty when there's no one.
var near_moving: Callable
## Whether the helmet lamp's on. Inside a station it comes on by itself where the lamps leave it dark,
## and goes off again where they don't.
var helmet_lamp: bool = false
## Inside this distance from the star's middle, hulls burn, in world units, from DESIGN.md's hazards.
const STAR_HEAT_REACH: float = 6000000.0
## How long the middle of the body takes to settle to its standing height on landing, in seconds.
const LANDING_EASE_SECONDS: float = 0.1
## Falling to a world, they turn the other way when they're moving this fast sideways that way, in
## world units per second.
const FALL_TURN_SPEED: float = 20.0
## How long a burning pilot takes to flare and dissolve, how long the leak plumes take to die away
## after the air runs out, and how long a pilot out of air stays standing before they topple, in seconds.
const BURN_SECONDS: float = 0.4
const PLUME_FADE_SECONDS: float = 1.5
const SLUMP_SECONDS: float = 0.35
## Below this much light the helmet lamp comes on, and above that it goes off, from 0 to 1.
const LAMP_ON_BELOW: float = 0.5
const LAMP_OFF_ABOVE: float = 0.62
## Which way the pilot faces, in the world.
var facing: float = 0.0

var _gravity_model: GravityModel
var _ship: Node2D
var _station: StationView
var _sprite := Sprite2D.new()
# The 3D pilot, when FeatureFlags.PILOT_3D is on, drawn instead of the sprite.
var _figure: AstronautView
var _roll: float = 0.0
var _has_drag: bool = false
var _drag_heading: float = 0.0
var _firing := Vector2.ZERO
# The same push in the pilot's own frame, x to their right and y toward their feet, and which way the
# jetpack's turning them, for drawing the gas. On EVA, how fast they're spinning, clockwise.
var _push_local := Vector2.ZERO
var _turning: float = 0.0
var _spin: float = 0.0
# Inside: where the pilot is and how they're moving, which way they face, in the station's frame.
var _local := Vector2.ZERO
var _walking := Vector2.ZERO
var _local_facing: float = 0.0
var _action: String = ""
## True while a screen like the gig board is up: the pilot doesn't walk or use things then.
var input_blocked: bool = false
# Says where what the action's about is, as box corners in the world.
var _action_target: Callable = Callable()
var _can_leave: bool = false
var _stranded: bool = false
## The suit's air, in seconds of one hole leaking it, and its holes, each as which way it vents, as an
## angle from the head. Getting inside patches it and fills it up.
var air: float = 0.0
var suit_holes: PackedFloat32Array = PackedFloat32Array()
## Whether the pilot's dead, and what killed them. The body stays a body: it drifts, falls, and comes
## to rest like anything else, until the med bay.
var dead: bool = false
var death_cause: String = ""
var _pixels_per_unit: float = 1.0
var _show_dot: bool = false
var _last_interact_frame: int = -1
var _animation_time: float = 0.0
# On a world: which body, and how the pilot's moving against its ground, along it (clockwise is
# positive) and up off it. The position itself stays in the 64-bit state.
var _world: int = -1
var _along: float = 0.0
var _rising: float = 0.0
var _grounded: bool = false
var _facing_right: bool = true
var _jump_held: bool = false
var _jetting: bool = false
var _up_heading: float = 0.0
var _stride: float = 0.0
# On EVA near a world: whether they're falling to it, so they're seen from the side, and which way they
# face then, true for right.
var _falling_to_world: bool = false
var _fall_facing_right: bool = true
# A dead body: how long it's been dead, whether it's come to rest on a world, which way it falls over
# (-1 onto its left, as the screen has it, 1 onto its right), how far it has still to tip and how fast
# it's tipping, and how long it waits before it starts. And the height its middle is drawn at, and the
# sinking height and speed that settle it, in pixels.
var _dead_time: float = 0.0
var _resting: bool = false
var _topple_way: float = 1.0
var _topple_lying: float = 0.0
var _topple_toward: float = 1.0
var _topple_tilt: float = 0.0
var _topple_spin: float = 0.0
var _topple_wait: float = 0.0
var _settle_middle: float = 0.0
var _settle_falling: float = 0.0
var _settle_speed: float = 0.0
# How far the body's middle is drawn off where it'll settle, in pixels along the world's up, easing
# to nothing after a landing or a take-off.
var _lift_ease: float = 0.0
# A frame held for a moment, like the crouch on landing, and for how much longer.
var _pose: int = 0
var _pose_left: float = 0.0
# Places built on worlds, and the door the pilot's standing at outside one, as a site and building.
var _sites: Array[SiteView] = []
var _door_site: SiteView
var _door_building: int = -1
# Indoors: the site and building, where the pilot's feet are on its art, and the ladder they're on.
var _site: SiteView
var _building: int = -1
var _spot := Vector2.ZERO
var _ladder: int = -1
var _climbing: float = 0.0


## Starts the pilot aboard the ship.
func start_pilot(gravity_model: GravityModel, ship: Node2D, station: StationView) -> void:
	_gravity_model = gravity_model
	_ship = ship
	_station = station
	gas = data.jet_seconds
	air = data.air_seconds
	# A cockpit destroyed with them in it kills them too.
	ship.ship_lost.connect(_on_ship_lost)
	# The boots are what meet the ground.
	state.ground_clearance = data.stand_height
	# Before the ship's tick, so the pilot and ship both reach the same moment before the view's drawn.
	process_physics_priority = -3
	_sprite.texture = data.texture
	_sprite.hframes = data.hframes
	_sprite.vframes = data.vframes
	add_child(_sprite)
	if FeatureFlags.PILOT_3D:
		_sprite.visible = false
		_figure = AstronautView.new()
		add_child(_figure)
	visible = false


## Whether a pilot on EVA is falling to a world, so they're seen from the side: the world's not the star
## (index 0), the low point of their path is below the highest ground there plus their clearance, they're
## lower than the view height, and a path that never comes back (open_path) has yet to pass its low
## point (coming_in). All of it in world units.
static func falls_to_world(world: int, low_point: float, reach: float, altitude: float, view_height: float, open_path: bool, coming_in: bool) -> bool:
	if world == 0 or altitude >= view_height or low_point >= reach:
		return false
	return coming_in or not open_path


## How hard they flail falling this fast, from 0 to 1: nothing below the first speed, full at the second.
static func flail_share(descent: float, from_speed: float, full_speed: float) -> float:
	return smoothstep(from_speed, full_speed, descent)


func _physics_process(delta: float) -> void:
	if _gravity_model == null:
		return
	if endless_gas:
		gas = data.jet_seconds
	if dead:
		_tick_dead(delta)
		return
	match mode:
		ABOARD:
			_tick_aboard(delta)
		EVA:
			_tick_eva(delta)
		INSIDE:
			_tick_inside(delta)
		SURFACE:
			_tick_surface(delta)
		INDOORS:
			_tick_indoors(delta)
	if mode == INSIDE and Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report()


func _tick_aboard(delta: float) -> void:
	var ship_state: ShipState = _ship.state
	_set_can_leave(FeatureFlags.EVA and _ship.can_be_left())
	var docked_port: int = _station.docked_port
	if FeatureFlags.INTERIORS and _ship.docked and docked_port >= 0:
		_set_action("BOARD STATION", _station_box(_station.port_point(docked_port), PORT_BOX))
	else:
		_set_action("")
	if _can_leave and Input.is_action_just_pressed("eva"):
		if ship_state.is_on_surface():
			_step_out_onto_ground()
			_tick_surface(delta)
		else:
			_leave_ship()
			_tick_eva(delta)
	elif _action != "" and _interact_pressed():
		_enter_station(docked_port)
		_tick_inside(delta)


# Dead: the body drifts, tumbles, falls, and comes to rest like anything else, lying where it stops.
# The air still drags on it, and can still burn it up. Landing on a world, it tips over onto its back.
func _tick_dead(delta: float) -> void:
	if mode == ABOARD:
		return
	_dead_time += delta
	# Burned up: what's left flares and breaks up over a moment, carried on as it was, then it's gone.
	if death_cause == "BURNED UP":
		if _dead_time >= BURN_SECONDS:
			visible = false
		else:
			_gravity_model.propagate(state, delta)
		return
	if _feel_air(delta):
		_burn_up()
		return
	_gravity_model.propagate(state, delta)
	if state.is_on_surface():
		if not _resting:
			# Falling dead, it's just reached the ground.
			_rest_body(true, _gravity_model.get_altitude(state.x, state.y, state.time), state.get_touchdown_speed())
		_tick_rest(delta)
	else:
		facing = wrapf(facing + _spin * delta, -PI, PI)
		# A dead body doesn't turn over to face the way it's drifting.
		_update_fall_view(false)


# The body comes to rest on a world, lying on the ground: put 6 above it, moving with it, and set
# to tip over. from_air says it landed after tumbling, so it keeps its spin; middle is how high its
# middle was drawn, in pixels, and speed how hard it hit.
func _rest_body(from_air: bool, middle: float, speed: float) -> void:
	_resting = true
	_world = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var center: PackedFloat64Array = _gravity_model.get_body_position(_world, state.time)
	var angle: float = atan2(state.y - center[1], state.x - center[0])
	state.ground_clearance = 6.0
	var reach: float = _ground_radius(center, angle, state.time) + state.ground_clearance
	state.x = center[0] + cos(angle) * reach
	state.y = center[1] + sin(angle) * reach
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	state.velocity_x = ground[0]
	state.velocity_y = ground[1]
	_up_heading = atan2(cos(angle), -sin(angle))
	# Which way it falls: onto its back, unless it's already well over to the other side.
	var tipped: float = angle_difference(_up_heading, facing)
	_topple_way = -1.0 if _fall_facing_right else 1.0
	if absf(tipped) > 0.6 and signf(tipped) != _topple_way:
		_topple_way = signf(tipped)
	_topple_lying = _topple_way * PI / 2.0
	_topple_tilt = absf(_topple_lying - tipped)
	_topple_toward = signf(_topple_lying - tipped) if tipped != _topple_lying else _topple_way
	_topple_spin = maxf(_spin * _topple_toward, 0.0) if from_air else 0.0
	_spin = 0.0
	_topple_wait = SLUMP_SECONDS if death_cause == "AIR RAN OUT" else 0.0
	_settle_middle = middle
	_settle_falling = middle
	_settle_speed = minf(speed, AstronautView.SETTLE_MAX_SPEED)


# A body at rest on a world: tips over, and its middle settles to the ground.
func _tick_rest(delta: float) -> void:
	var center: PackedFloat64Array = _gravity_model.get_body_position(_world, state.time)
	_up_heading = atan2(state.x - center[0], center[1] - state.y)
	var pull: PackedFloat64Array = _gravity_model.get_acceleration(state.x, state.y, state.time)
	var gravity: float = sqrt(pull[0] * pull[0] + pull[1] * pull[1])
	if _topple_wait > 0.0:
		_topple_wait -= delta
	else:
		var tipped: Vector2 = AstronautView.topple_step(_topple_tilt, _topple_spin, gravity, delta)
		_topple_tilt = tipped.x
		_topple_spin = tipped.y
	# The angle from upright it's at now: lying, less what it has still to tip.
	var from_upright: float = _topple_lying - _topple_toward * _topple_tilt
	facing = wrapf(_up_heading + from_upright, -PI, PI)
	var settled: Vector3 = AstronautView.settle_step(_settle_middle, _settle_falling, _settle_speed, from_upright, gravity, delta)
	_settle_middle = settled.x
	_settle_falling = settled.y
	_settle_speed = settled.z


# The ship's lost when its cockpit's destroyed, and a pilot in it goes with it: burned up near the star,
# crushed anywhere else.
func _on_ship_lost() -> void:
	if mode != ABOARD:
		return
	var near_star: bool = Vector2(_ship.state.x, _ship.state.y).length() < STAR_HEAT_REACH
	_die("BURNED UP" if near_star else "CRUSHED", 1.0 if near_star else 0.8)


# The air slows the pilot as it does a debris chunk, and heats them; too much and they burn up. Says
# whether they did.
func _feel_air(delta: float) -> bool:
	if state.is_on_surface():
		return false
	var density: float = _gravity_model.get_air_density(state.x, state.y, state.time)
	if density <= 0.0:
		return false
	var air: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var through := Vector2(state.velocity_x - air[0], state.velocity_y - air[1])
	var speed: float = through.length()
	if speed < 0.001:
		return false
	var slowing: float = 0.5 * density * speed * speed * data.drag_area / data.mass_kg
	var change: float = minf(slowing * delta, speed)
	state.velocity_x -= through.x / speed * change
	state.velocity_y -= through.y / speed * change
	return sqrt(density) * speed * speed * speed / data.heat_limit >= 1.0


# Close enough to the star for the suit to cook, long before touching it.
func _too_near_star() -> bool:
	var star: float = _gravity_model.get_body_radius(0)
	return Vector2(state.x, state.y).length() < star * 1.5


# Dead from hitting something too hard: worse the harder it was.
func _die_of_impact(speed: float) -> void:
	var over: float = clampf((speed - data.fatal_landing_speed) / (data.fatal_landing_speed * 4.0), 0.0, 1.0)
	_spin = randf_range(-3.0, 3.0) * clampf(speed / data.fatal_landing_speed, 1.0, 3.0)
	# The ground stops a body dead, as it does a ship.
	if state.is_on_surface() or mode == SURFACE:
		var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
		state.velocity_x = ground[0]
		state.velocity_y = ground[1]
	_die("IMPACT", 0.3 + 0.7 * over, " %s" % Units.speed_text(speed), speed)


func _burn_up() -> void:
	_die("BURNED UP", 1.0)


# Knocked down by a hard landing: on their back for a moment. The suit takes a scrape too, once it
# has air to lose.
func _land_hard(_speed: float) -> void:
	_show_pose(data.jump_side[5], 0.8)
	message_raised.emit("HARD LANDING")
	_breach_suit()


# A hole in the suit: it leaks air, and the gas venting from it pushes them about.
func _breach_suit() -> void:
	suit_holes.append(randf() * TAU)
	message_raised.emit("SUIT BREACHED · O2 LEAKING" if suit_holes.size() == 1 else "SUIT BREACHED · %d HOLES" % suit_holes.size())


# The suit's holes leak air and, in space, push like small thrusters going the other way. Out of air,
# they die. Says whether they did.
func _leak(delta: float, pushes: bool) -> bool:
	if suit_holes.is_empty():
		return false
	air = maxf(air - suit_holes.size() * delta, 0.0)
	if pushes:
		for angle: float in suit_holes:
			var out: Vector2 = Vector2.UP.rotated(facing + angle)
			state.velocity_x -= out.x * data.leak_push * delta
			state.velocity_y -= out.y * data.leak_push * delta
	if air <= 0.0:
		_die("AIR RAN OUT", 0.1)
		return true
	return false


# Back inside, the suit's patched and filled up.
func _patch_suit() -> void:
	suit_holes.clear()
	air = data.air_seconds


func _die(cause: String, severity: float, detail: String = "", impact_speed: float = 0.0) -> void:
	if dead:
		return
	dead = true
	death_cause = cause
	_dead_time = 0.0
	_resting = false
	_firing = Vector2.ZERO
	_push_local = Vector2.ZERO
	_set_action("")
	_set_stranded(true)
	if helmet_lamp:
		helmet_lamp = false
		_station.light_helmet(Vector2.ZERO, 0.0, false)
	if mode == SURFACE:
		_fall_facing_right = _facing_right
	# Already on the ground: it's a body there at once, lying 6 above it, and settles down from where its
	# middle was drawn. Otherwise it keeps its height until it lands, and then does.
	var on_ground: bool = _grounded if mode == SURFACE else (mode == EVA and state.is_on_surface())
	if cause != "BURNED UP" and on_ground:
		var middle: float = AstronautView.STANDING_MIDDLE if mode == SURFACE else _gravity_model.get_altitude(state.x, state.y, state.time)
		_rest_body(false, middle + _lift_ease, impact_speed)
	elif mode == SURFACE:
		# In the air from a jump: the middle was drawn lower than it will be, so it eases up.
		_lift_ease = -(data.stand_height - AstronautView.STANDING_MIDDLE)
	if _figure != null:
		# How the body takes it: a hit crumples loosely, with the limbs flung; running out of air is a
		# slow slump.
		if cause == "IMPACT":
			var on_world: bool = on_ground or _falling_to_world or mode == SURFACE
			_figure.pose_spring = Vector2(16.0, 0.35) if on_world else Vector2(12.0, 0.5)
			_figure.jolt(clampf(impact_speed / data.fatal_landing_speed, 1.0, 3.0) / 3.0)
		elif cause == "AIR RAN OUT":
			_figure.pose_spring = Vector2(3.5, 1.0)
	# Burning up flares and breaks up first, which needs the 3D pilot; without it, it's gone at once.
	if cause == "BURNED UP" and (_figure == null or mode == ABOARD):
		visible = false
	message_raised.emit("SIGNAL LOST · %s%s" % [cause, detail])
	died.emit(cause, severity)


## Back from the med bay: alive, patched, and inside the station by this port.
func wake_in_station(port: int) -> void:
	dead = false
	death_cause = ""
	visible = true
	state.ground_clearance = data.stand_height
	_spin = 0.0
	_resting = false
	_dead_time = 0.0
	_lift_ease = 0.0
	if _figure != null:
		_figure.pose_spring = AstronautView.DEFAULT_SPRING
		_figure.burn = 0.0
		_figure.leak_strength = 1.0
		_figure.lift = 0.0
	carried_kg = 0.0
	_set_stranded(false)
	_enter_station(port)


## How hard the jetpack pushes now, in world units per second squared: less with someone held.
func jet_push() -> float:
	return data.jet_acceleration * data.mass_kg / (data.mass_kg + carried_kg)


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
	# Falling from the ship, they face the hatch's side, as stepping out onto the ground does.
	var world: int = _gravity_model.get_dominant_body(ship_state.x, ship_state.y, ship_state.time)
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, ship_state.time)
	var angle: float = atan2(ship_state.y - center[1], ship_state.x - center[0])
	_fall_facing_right = out.dot(Vector2(-sin(angle), cos(angle))) >= 0.0
	_ship.set_pilot_aboard(false)
	_set_mode(EVA)


func _tick_eva(delta: float) -> void:
	if dead:
		_tick_dead(delta)
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
	_steer(delta)
	var push: Vector2 = _body_push()
	_firing = Vector2.ZERO
	_push_local = Vector2.ZERO
	if push != Vector2.ZERO and gas > 0.0:
		_push_local = push
		_firing = push.rotated(facing)
		state.velocity_x += _firing.x * jet_push() * delta
		state.velocity_y += _firing.y * jet_push() * delta
		gas = maxf(gas - push.length() * delta, 0.0)
	if _feel_air(delta) or _too_near_star():
		_die("BURNED UP", 1.0)
		return
	if _leak(delta, true):
		return
	_gravity_model.propagate(state, delta)
	if state.is_on_surface():
		var speed: float = state.get_touchdown_speed()
		if speed > data.fatal_landing_speed or not FeatureFlags.WALKING_ON_WORLDS:
			_die_of_impact(speed)
			return
		_land_on_ground()
		if speed > data.safe_landing_speed:
			_land_hard(speed)
		return
	_update_fall_view()
	_bump_station()


# Once a tick on EVA: whether they're falling to a world (so they're seen from the side), and which way
# they face while they do: the way they last moved sideways against the ground, once past a speed
# (unless turn is false, as for a dead body).
func _update_fall_view(turn: bool = true) -> void:
	_falling_to_world = false
	var world: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	if world == 0:
		return
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, state.time)
	var out := Vector2(state.x - center[0], state.y - center[1])
	var up: Vector2 = out.normalized()
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var against := Vector2(state.velocity_x - ground[0], state.velocity_y - ground[1])
	var sideways: float = against.dot(Vector2(-up.y, up.x))
	if turn and sideways > FALL_TURN_SPEED:
		_fall_facing_right = true
	elif turn and sideways < -FALL_TURN_SPEED:
		_fall_facing_right = false
	var altitude: float = _gravity_model.get_altitude(state.x, state.y, state.time)
	if altitude >= data.fall_view_height:
		return
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	var reach: float = _gravity_model.get_highest_ground(world) + state.ground_clearance
	# On a path that never comes back, it only comes down if it hasn't passed its low point yet.
	var body_moving: PackedFloat64Array = _gravity_model.get_body_velocity(world, state.time)
	var coming_in: bool = out.x * (state.velocity_x - body_moving[0]) + out.y * (state.velocity_y - body_moving[1]) < 0.0
	_falling_to_world = falls_to_world(world, apsides[0], reach, altitude, data.fall_view_height, apsides[1] < 0.0, coming_in)


# How fast they're dropping toward the middle of the world they're over, against the ground's own
# motion, in world units per second. Negative going up.
func _descent() -> float:
	var world: int = _world if mode == SURFACE else _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, state.time)
	var out := Vector2(state.x - center[0], state.y - center[1])
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var against := Vector2(state.velocity_x - ground[0], state.velocity_y - ground[1])
	return -against.dot(out.normalized())


# Which way is up on screen over a world, clockwise from the top of the screen.
func _sky_heading(world: int) -> float:
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, state.time)
	return wrapf(atan2(state.x - center[0], center[1] - state.y) - _roll, -PI, PI)


# The rotate buttons spin the pilot, and letting go stops the spin, as the ship does with ASSIST on.
# A drag turns them to face that way, braking in time to stop there. Turning costs gas too.
func _steer(delta: float) -> void:
	var before: float = _spin
	var turn: float = Input.get_axis("turn_left", "turn_right")
	if gas <= 0.0:
		pass
	elif turn != 0.0:
		_spin = clampf(_spin + turn * data.spin_acceleration * delta, -data.most_spin, data.most_spin)
	elif _has_drag:
		var error: float = angle_difference(facing, _drag_heading)
		var braking_limit: float = sqrt(2.0 * data.spin_acceleration * absf(error))
		_spin = move_toward(_spin, signf(error) * minf(braking_limit, absf(error) * 4.0), data.spin_acceleration * delta)
	else:
		_spin = move_toward(_spin, 0.0, data.spin_acceleration * delta)
	_turning = signf(_spin - before)
	gas = maxf(gas - absf(_spin - before) / data.spin_acceleration * data.spin_gas_share, 0.0)
	facing = wrapf(facing + _spin * delta, -PI, PI)


# The arrows push relative to the pilot, like the ship's: up toward the helmet, right to their right.
# Returned in their own frame, with y toward their feet, up to full push.
func _body_push() -> Vector2:
	var forward: float = Input.get_axis("translate_back", "translate_forward") + (1.0 if Input.is_action_pressed("thrust") else 0.0)
	var right: float = Input.get_axis("translate_left", "translate_right")
	return Vector2(right, -forward).limit_length(1.0)


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
		if -into > data.fatal_landing_speed:
			_die_of_impact(-into)
		elif -into > data.safe_landing_speed:
			_breach_suit()


func _look_around_outside() -> void:
	var ship_state: ShipState = _ship.state
	var cockpit: Vector2 = _ship.cockpit_offset()
	var from_ship := Vector2(state.x - ship_state.x - cockpit.x, state.y - ship_state.y - cockpit.y)
	var against_ship: float = (Vector2(state.velocity_x, state.velocity_y) - Vector2(ship_state.velocity_x, ship_state.velocity_y)).length()
	if from_ship.length() <= data.board_reach and against_ship <= data.board_speed and _ship.can_be_boarded():
		_set_action("BOARD SHIP", _ship.cockpit_corners)
		return
	var port: int = _station.free_port_near(state.x, state.y, state.time, data.hatch_reach) if FeatureFlags.INTERIORS else -1
	if port >= 0:
		_set_action("BOARD STATION", _station_box(_station.port_point(port), PORT_BOX))
		return
	_set_action("")


func _act_outside() -> void:
	if _action == "BOARD SHIP":
		_board_ship()
	elif _action == "BOARD STATION":
		_enter_station(_station.free_port_near(state.x, state.y, state.time, data.hatch_reach))


func _board_ship() -> void:
	gas = data.jet_seconds
	_patch_suit()
	_firing = Vector2.ZERO
	_ship.set_pilot_aboard(true)
	_station.set_roof_off(false)
	_set_stranded(false)
	_set_mode(ABOARD)


func _enter_station(port: int) -> void:
	gas = data.jet_seconds
	_patch_suit()
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
		_set_action("USE TERMINAL", _station_box(_station.spot_point(spot), TERMINAL_BOX))
	elif port >= 0 and port == _station.docked_port:
		_set_action("BOARD SHIP", _ship.cockpit_corners)
	elif port >= 0:
		_set_action("EXIT STATION", _station_box(_station.port_inner(port), PORT_BOX))
	else:
		_set_action("")
	if _action != "" and _interact_pressed():
		match _action:
			"USE TERMINAL":
				# The docking room's terminal sells fuel and repairs; any other is the gig board.
				terminal_used.emit({"kind": "service", "at": {"kind": "station"}} if spot.get("kind", "") == "service" else {"kind": "station", "index": 0})
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


# Out of a landed ship, the pilot stands on the ground beside it, on the hatch's side.
func _step_out_onto_ground() -> void:
	var ship_state: ShipState = _ship.state
	_world = _gravity_model.get_dominant_body(ship_state.x, ship_state.y, ship_state.time)
	var center: PackedFloat64Array = _gravity_model.get_body_position(_world, ship_state.time)
	var angle: float = atan2(ship_state.y - center[1], ship_state.x - center[0])
	var right := Vector2(-sin(angle), cos(angle))
	var side: float = 1.0 if _ship.eva_exit_offset().dot(right) >= 0.0 else -1.0
	var widest: float = 0.0
	for point: Vector2 in _ship.world_outline_samples(4.0):
		widest = maxf(widest, point.dot(right) * side)
	var feet: float = _ground_radius(center, angle, ship_state.time)
	angle += side * (widest + data.body_radius) / feet
	state.time = ship_state.time
	_along = 0.0
	_rising = 0.0
	_grounded = true
	_facing_right = side > 0.0
	_place_on_ground(center, angle, _ground_radius(center, angle, ship_state.time))
	_ship.set_pilot_aboard(false)
	_set_mode(SURFACE)


# Come down softly on EVA, the pilot lands on their feet and walks.
func _land_on_ground() -> void:
	_world = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var center: PackedFloat64Array = _gravity_model.get_body_position(_world, state.time)
	var angle: float = atan2(state.y - center[1], state.x - center[0])
	_along = 0.0
	_rising = 0.0
	_grounded = true
	# They land facing the way they were falling, so nothing flips.
	_facing_right = _fall_facing_right
	_place_on_ground(center, angle, _ground_radius(center, angle, state.time))
	_set_mode(SURFACE)
	_show_pose(data.jump_side[5], 0.25)


func _tick_surface(delta: float) -> void:
	# The ship hasn't moved yet this tick, so this is the moment the two can be compared.
	_look_around_on_ground()
	if _action != "" and _interact_pressed():
		if _action == "ENTER":
			_enter_building(_door_site, _door_building)
			_tick_indoors(delta)
		else:
			_board_ship()
		return
	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report()

	# All in 64-bit: a 32-bit Vector2 this far from the middle of a world would wander off the ground.
	var center: PackedFloat64Array = _gravity_model.get_body_position(_world, state.time)
	var out_x: float = state.x - center[0]
	var out_y: float = state.y - center[1]
	var angle: float = atan2(out_y, out_x)
	var up := Vector2(cos(angle), sin(angle))
	var right := Vector2(-up.y, up.x)
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var body_moving: PackedFloat64Array = _gravity_model.get_body_velocity(_world, state.time)
	# How fast the ground turns, from how fast it's moving here.
	var spin: float = (out_x * (ground[1] - body_moving[1]) - out_y * (ground[0] - body_moving[0])) / (out_x * out_x + out_y * out_y)
	var pull: PackedFloat64Array = _gravity_model.get_acceleration(state.x, state.y, state.time)
	var gravity: float = sqrt(pull[0] * pull[0] + pull[1] * pull[1])

	var move: Vector2 = _wanted_move()
	var sideways: float = clampf(move.dot(right), -1.0, 1.0)
	var jump: bool = move.dot(up) > 0.5
	var fresh_press: bool = jump and not _jump_held
	_firing = Vector2.ZERO
	if _grounded:
		var grip: float = minf(data.walk_acceleration, gravity * data.ground_grip)
		_along = move_toward(_along, sideways * data.ground_walk_speed, grip * delta)
		if fresh_press:
			_rising = data.jump_speed
			_grounded = false
			_show_pose(data.jump_side[1], 0.12)
	else:
		# Off the ground, only the jetpack changes anything. It takes a second press, so a jump costs no
		# gas, and fires up for as long as that's held, steered by left and right.
		_jetting = (_jetting or fresh_press) and jump
		_push_local = Vector2.ZERO
		if _jetting and gas > 0.0:
			var push := Vector2(sideways, 1.0).limit_length(1.0)
			_along += push.x * jet_push() * delta
			_rising += push.y * jet_push() * delta
			gas = maxf(gas - push.length() * delta, 0.0)
			_firing = right * push.x + up * push.y
			_push_local = Vector2(0.0, -1.0)
		_rising -= gravity * delta
	_jump_held = jump
	if absf(sideways) > 0.1:
		_facing_right = sideways > 0.0

	# On the ship's clock, as inside a station: a tick out would put the pilot far off the ground.
	var later: float = _ship.state.time + delta
	var center_later: PackedFloat64Array = _gravity_model.get_body_position(_world, later)
	var feet: float = sqrt(out_x * out_x + out_y * out_y) - data.stand_height
	# The ground carries the pilot around with it, and walking adds to that.
	var riding: float = angle + spin * delta
	var angle_later: float = riding + _along * delta / feet
	var floor_there: float = _ground_radius(center_later, angle_later, later)
	# Ground higher than a step, or in the air higher than the boots, is a wall.
	if floor_there > feet + (data.step_height if _grounded else 0.0):
		_along = 0.0
		angle_later = riding
		floor_there = _ground_radius(center_later, angle_later, later)
	if _grounded and feet - floor_there > data.step_height:
		_grounded = false
		_rising = 0.0
	if _leak(delta, false):
		return
	var landed_at: float = 0.0
	if _grounded:
		feet = floor_there
	else:
		feet += _rising * delta
		if feet <= floor_there:
			feet = floor_there
			_grounded = true
			_jetting = false
			landed_at = -_rising
			_rising = 0.0
			_show_pose(data.jump_side[5], 0.15)
	state.time = later
	_place_on_ground(center_later, angle_later, feet)
	# A fall too far kills; a hard one knocks them down.
	if landed_at > data.fatal_landing_speed:
		_die_of_impact(landed_at)
		return
	if landed_at > data.safe_landing_speed:
		_land_hard(landed_at)
	_set_stranded(not _ship.can_be_boarded() or not _ship.state.is_on_surface() or _gravity_model.get_dominant_body(_ship.state.x, _ship.state.y, _ship.state.time) != _world)
	if feet - floor_there > data.ground_reach:
		_set_mode(EVA)


# How far the ground is from the middle of the world, at this angle around it.
func _ground_radius(center: PackedFloat64Array, angle: float, time: float) -> float:
	var base: float = _gravity_model.get_body_radius(_world)
	return base + _gravity_model.get_ground_height(center[0] + cos(angle) * base, center[1] + sin(angle) * base, time)


# Stands the pilot with their boots this far from the world's middle, moving with its ground.
func _place_on_ground(center: PackedFloat64Array, angle: float, feet: float) -> void:
	var up := Vector2(cos(angle), sin(angle))
	var right := Vector2(-up.y, up.x)
	var reach: float = feet + data.stand_height
	state.x = center[0] + cos(angle) * reach
	state.y = center[1] + sin(angle) * reach
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	state.velocity_x = ground[0] + right.x * _along + up.x * _rising
	state.velocity_y = ground[1] + right.y * _along + up.y * _rising
	_up_heading = atan2(up.x, -up.y)
	facing = _up_heading


# Standing by the ship, the pilot can climb back in.
func _look_around_on_ground() -> void:
	_door_site = null
	_door_building = -1
	if _grounded and _ship.can_be_boarded() and _beside_ship():
		_set_action("BOARD SHIP", _ship.cockpit_corners)
	elif _grounded and FeatureFlags.INTERIORS and _find_door():
		_set_action("ENTER", _door_box(_door_site, _door_building))
	else:
		_set_action("")


# Standing at a building's door, outside. Remembers which.
func _find_door() -> bool:
	for site: SiteView in _sites:
		if site.world != _world:
			continue
		var along: float = site.along_of(state.x, state.y, state.time)
		if absf(along) > site.reach() + 50.0:
			continue
		for i in range(site.data.buildings.size()):
			var building: SiteBuilding = site.data.buildings[i]
			if building.door.x < 0.0:
				continue
			if absf(site.art_x(i, along) - building.door.x) <= data.use_reach * 0.5:
				_door_site = site
				_door_building = i
				return true
	return false


# Through the door: the front wall fades off, and the pilot walks the floors inside.
func _enter_building(site: SiteView, index: int) -> void:
	_patch_suit()
	_site = site
	_building = index
	_spot = site.data.buildings[index].door
	_ladder = -1
	_along = 0.0
	_rising = 0.0
	_grounded = true
	site.set_inside(index, true)
	_set_mode(INDOORS)
	_place_indoors()


# Out the door: back on the ground outside it, and the front wall fades back.
func _leave_building() -> void:
	var door: Vector2 = _site.data.buildings[_building].door
	var outside: PackedFloat64Array = _site.building_point(state.time, _building, Vector2(door.x, door.y))
	_site.set_inside(_building, false)
	_world = _site.world
	var center: PackedFloat64Array = _gravity_model.get_body_position(_world, state.time)
	var angle: float = atan2(outside[1] - center[1], outside[0] - center[0])
	_along = 0.0
	_rising = 0.0
	_grounded = true
	_place_on_ground(center, angle, _ground_radius(center, angle, state.time))
	_set_mode(SURFACE)


# Indoors, the floors are level and the walls are their ends. Up and down climb a ladder where
# there is one, and left or right steps off onto a floor it reaches. Everything's on the
# building's art, which turns with the world, so this works like walking on the ground.
func _tick_indoors(delta: float) -> void:
	# On the ship's clock, as on the ground.
	state.time = _ship.state.time + delta
	var building: SiteBuilding = _site.data.buildings[_building]
	var up := Vector2.UP.rotated(_site.angle_at(state.time, building.offset))
	var right := Vector2(-up.y, up.x)
	var move: Vector2 = _wanted_move()
	var sideways: float = clampf(move.dot(right), -1.0, 1.0)
	var climb: float = clampf(move.dot(up), -1.0, 1.0)
	_climbing = 0.0
	if _ladder >= 0:
		var ladder: Vector3 = building.ladders[_ladder]
		_spot.x = ladder.x
		if absf(climb) > 0.3:
			_climbing = signf(climb) * data.climb_speed
			_spot.y = clampf(_spot.y - _climbing * delta, ladder.y, ladder.z)
		var floor_here: int = _floor_at(building, _spot)
		if floor_here >= 0 and absf(sideways) > 0.3:
			_spot.y = building.floors[floor_here].z
			_ladder = -1
		_along = 0.0
	else:
		var floor_here: int = _floor_at(building, _spot)
		var level: Vector3 = building.floors[maxi(floor_here, 0)]
		_along = move_toward(_along, sideways * data.ground_walk_speed, data.walk_acceleration * delta)
		var stepped: float = clampf(_spot.x + _along * delta, level.x + data.body_radius, level.y - data.body_radius)
		if stepped != _spot.x + _along * delta:
			_along = 0.0
		_spot.x = stepped
		var ladder_here: int = _ladder_at(building, _spot)
		if ladder_here >= 0:
			var ladder: Vector3 = building.ladders[ladder_here]
			if (climb > 0.5 and ladder.y < _spot.y - 0.5) or (climb < -0.5 and ladder.z > _spot.y + 0.5):
				_ladder = ladder_here
				_along = 0.0
	if absf(sideways) > 0.1:
		_facing_right = sideways > 0.0

	if absf(_spot.x - building.door.x) <= data.use_reach * 0.5 and absf(_spot.y - building.door.y) < 2.0 and _ladder < 0:
		_set_action("EXIT", _door_box(_site, _building))
	elif _terminal_at(building, _spot) >= 0 and _ladder < 0:
		_set_action("USE TERMINAL", _terminal_box(_site, _building, _terminal_at(building, _spot)))
	else:
		_set_action("")
	if _action != "" and _interact_pressed():
		if _action == "EXIT":
			_leave_building()
			return
		var terminal: int = _terminal_at(building, _spot)
		if building.board_terminals.has(terminal):
			terminal_used.emit({"kind": "site", "index": _sites.find(_site)})
		elif building.service_terminals.has(terminal):
			terminal_used.emit({"kind": "service", "at": {"kind": "site", "index": _sites.find(_site)}})
		else:
			message_raised.emit(building.terminal_messages[terminal])
	_place_indoors()
	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report()


# The floor the pilot's feet are on, or -1 between floors on a ladder.
func _floor_at(building: SiteBuilding, spot: Vector2) -> int:
	for i in range(building.floors.size()):
		var level: Vector3 = building.floors[i]
		if absf(level.z - spot.y) < 1.5 and spot.x >= level.x - 2.0 and spot.x <= level.y + 2.0:
			return i
	return -1


func _ladder_at(building: SiteBuilding, spot: Vector2) -> int:
	for i in range(building.ladders.size()):
		var ladder: Vector3 = building.ladders[i]
		if absf(ladder.x - spot.x) <= 10.0 and spot.y >= ladder.y - 1.0 and spot.y <= ladder.z + 1.0:
			return i
	return -1


func _terminal_at(building: SiteBuilding, spot: Vector2) -> int:
	for i in range(building.terminals.size()):
		var terminal: Vector2 = building.terminals[i]
		if absf(terminal.x - spot.x) <= data.use_reach * 0.5 and absf(terminal.y - spot.y) < 2.0:
			return i
	return -1


# The pilot's middle above their feet on the art, moving with the ground and their own steps.
func _place_indoors() -> void:
	var building: SiteBuilding = _site.data.buildings[_building]
	var at: PackedFloat64Array = _site.building_point(state.time, _building, _spot, data.stand_height)
	var up := Vector2.UP.rotated(_site.angle_at(state.time, building.offset + _spot.x - building.texture.get_width() / 2.0))
	var right := Vector2(-up.y, up.x)
	state.x = at[0]
	state.y = at[1]
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	state.velocity_x = ground[0] + right.x * _along + up.x * _climbing
	state.velocity_y = ground[1] + right.y * _along + up.y * _climbing
	_up_heading = atan2(up.x, -up.y)
	facing = _up_heading


# Under the ship or beside it, anywhere along its width, and no higher than its top.
func _beside_ship() -> bool:
	var ship_state: ShipState = _ship.state
	var from_ship := Vector2(state.x - ship_state.x, state.y - ship_state.y)
	if from_ship.length() > 600.0:
		return false
	var up: Vector2 = Vector2.UP.rotated(_up_heading)
	var right := Vector2(-up.y, up.x)
	var left_edge: float = INF
	var right_edge: float = -INF
	var top: float = -INF
	for point: Vector2 in _ship.world_outline_samples(8.0):
		left_edge = minf(left_edge, point.dot(right))
		right_edge = maxf(right_edge, point.dot(right))
		top = maxf(top, point.dot(up))
	var across: float = from_ship.dot(right)
	return across >= left_edge - data.use_reach and across <= right_edge + data.use_reach and from_ship.dot(up) <= top


func _show_pose(frame: int, seconds: float) -> void:
	_pose = frame
	_pose_left = seconds


# One press does one thing, even when doing it opens up something else to do.
func _interact_pressed() -> bool:
	if input_blocked or not Input.is_action_just_pressed("interact") or _last_interact_frame == Engine.get_physics_frames():
		return false
	_last_interact_frame = Engine.get_physics_frames()
	return true


# Which way the pilot wants to go, in the world, up to full push. The buttons go by the screen.
func _wanted_move() -> Vector2:
	var on_screen: Vector2 = wanted_on_screen()
	if on_screen != Vector2.ZERO:
		return on_screen.rotated(_roll)
	if _has_drag:
		return Vector2.UP.rotated(_drag_heading)
	return Vector2.ZERO


## Which way the player's pushing the pilot, on screen, from the arrows or a drag: nothing if
## they're not. The context menu uses it to keep out of the way.
func wanted_on_screen() -> Vector2:
	if input_blocked:
		return Vector2.ZERO
	var on_screen := Vector2(
			Input.get_axis("translate_left", "translate_right") + Input.get_axis("turn_left", "turn_right"),
			-Input.get_axis("translate_back", "translate_forward") - (1.0 if Input.is_action_pressed("thrust") else 0.0))
	if on_screen != Vector2.ZERO:
		return on_screen.limit_length(1.0)
	if _has_drag:
		return Vector2.UP.rotated(_drag_heading - _roll)
	return Vector2.ZERO


## Tells the pilot about a place built on a world, so they can go into its buildings.
func add_site(site: SiteView) -> void:
	_sites.append(site)


## Starts or updates a drag: the pilot goes this way until it ends.
func point_at(target_heading: float) -> void:
	_has_drag = true
	_drag_heading = target_heading


func stop_pointing() -> void:
	_has_drag = false


func guide_radius() -> float:
	return maxf(32.0 * _pixels_per_unit, 16.0)


func _set_mode(new_mode: String) -> void:
	var old_mode: String = mode
	mode = new_mode
	_falling_to_world = false
	# The standing body's middle is lower than the floating one's, by this much, so changing between
	# them eases rather than jumps.
	var settle: float = data.stand_height - AstronautView.MIDDLE / AstronautView.METERS_PER_PIXEL
	if old_mode == EVA and new_mode == SURFACE:
		_lift_ease = settle
	elif old_mode == SURFACE and new_mode == EVA:
		_lift_ease = -settle
		_fall_facing_right = _facing_right
	else:
		_lift_ease = 0.0
	if helmet_lamp and mode != INSIDE:
		helmet_lamp = false
		_station.light_helmet(Vector2.ZERO, 0.0, false)
	_has_drag = false
	_jump_held = false
	_jetting = false
	_pose_left = 0.0
	_spin = 0.0
	_turning = 0.0
	_push_local = Vector2.ZERO
	visible = mode != ABOARD
	# From the side on a world, from above everywhere else.
	var side: bool = mode == SURFACE or mode == INDOORS
	_sprite.frame = 0
	_sprite.texture = data.side_texture if side else data.texture
	_sprite.hframes = data.side_hframes if side else data.hframes
	_sprite.vframes = data.side_vframes if side else data.vframes
	_set_action("")
	mode_changed.emit(mode)


## What the action on offer is about, as the four corners of a box around it in the world, or
## nothing: the cockpit to board, the door to go through, the terminal to use. It moves with the
## thing, so it's worked out each time it's asked for, on the ship's clock, which keeps running while
## the pilot's own waits aboard.
func action_target() -> PackedFloat64Array:
	if _action == "" or not _action_target.is_valid():
		return PackedFloat64Array()
	return _action_target.call()


# Points at something in the station's frame, turning with it.
func _station_box(local: Vector2, half_pixels: Vector2) -> Callable:
	return func() -> PackedFloat64Array: return _station.box_corners(local, half_pixels, _ship.state.time)


# Points at a building's door: a doorway a little taller than the pilot, on its floor.
func _door_box(site: SiteView, building: int) -> Callable:
	var door: Vector2 = site.data.buildings[building].door
	var box := Rect2(door.x - DOOR_BOX.x / 2.0, door.y - DOOR_BOX.y, DOOR_BOX.x, DOOR_BOX.y)
	return func() -> PackedFloat64Array: return site.art_box_corners(building, box, _ship.state.time)


# Points at a building's terminal: the console in front of where the pilot stands to use it.
func _terminal_box(site: SiteView, building: int, terminal: int) -> Callable:
	var at: Vector2 = site.data.buildings[building].terminals[terminal]
	var box := Rect2(at.x - TERMINAL_BOX.x, at.y - 10.0 - TERMINAL_BOX.y * 2.0, TERMINAL_BOX.x * 2.0, TERMINAL_BOX.y * 2.0)
	return func() -> PackedFloat64Array: return site.art_box_corners(building, box, _ship.state.time)


func _set_action(label: String, target: Callable = Callable()) -> void:
	_action_target = target
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
	var status: String = "ON EVA"
	if mode == SURFACE or mode == INDOORS:
		var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
		against = Vector2(ground[0], ground[1])
		near = false
		status = "ON FOOT" if mode == SURFACE else "IN %s" % _site.data.buildings[_building].display_name.to_upper()
	elif mode == INSIDE:
		against = _station.moving_at(_station.frame_at(state.time), Vector2(state.x, state.y) - _station_center())
	elif _station.is_nearby(state.x, state.y, state.time):
		against = _station.moving_at(_station.frame_at(state.time), Vector2(state.x, state.y) - _station_center())
		near_station = true
	elif near_moving.is_valid():
		var moving: PackedFloat64Array = near_moving.call()
		against = Vector2(moving[0], moving[1])
		status = "NEAR SURVIVOR"
	elif Vector2(state.x - ship_state.x, state.y - ship_state.y).length() <= 5000.0:
		against = Vector2(ship_state.velocity_x, ship_state.velocity_y)
	else:
		var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
		against = Vector2(ground[0], ground[1])
		near = false
	var relative: Vector2 = Vector2(state.velocity_x, state.velocity_y) - against
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	flight_data_changed.emit({
		"altitude": _gravity_model.get_altitude(state.x, state.y, state.time) - (data.stand_height if mode == SURFACE or mode == INDOORS else 0.0),
		"speed": relative.length(),
		"against_station": near,
		"docked": false,
		"landed": (mode == SURFACE and _grounded) or mode == INDOORS,
		"periapsis": apsides[0],
		"apoapsis": apsides[1],
		"time": state.time,
		"heading": facing,
		"prograde": atan2(relative.x, -relative.y),
		"moving": relative.length_squared() >= 0.25,
		"spin": 0.0,
		"fuel_share": gas / data.jet_seconds,
		# The suit's air shows only once it's leaking.
		"air_share": air / data.air_seconds if not suit_holes.is_empty() else -1.0,
		"delta_v": gas * jet_push(),
		"status": "INSIDE THE STATION" if mode == INSIDE else ("NEAR THE STATION" if near_station else status),
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
	if _figure != null:
		_show_figure(delta)
		return
	if mode == SURFACE or mode == INDOORS:
		_animate_on_ground(delta)
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


# Tells the 3D pilot what the pilot's doing. It turns itself on screen, so this node stays square.
func _show_figure(delta: float) -> void:
	rotation = _roll
	_figure.screen_roll = _roll
	_figure.push = _push_local
	_figure.turning = _turning if mode == EVA else 0.0
	# A hand out to the side for someone being held, on EVA.
	_figure.holding = 1 if carried_kg > 0.0 and mode == EVA else 0
	# Holes in the suit vent, and the visor frosts as the air goes.
	# After the air runs out, the plumes thin and die away rather than stopping at once.
	var plume: bool = not dead or (death_cause == "AIR RAN OUT" and _dead_time < PLUME_FADE_SECONDS)
	_figure.leaks = suit_holes if plume else PackedFloat32Array()
	_figure.leak_strength = clampf(1.0 - _dead_time / PLUME_FADE_SECONDS, 0.0, 1.0) if dead else 1.0
	_figure.burn = clampf(_dead_time / BURN_SECONDS, 0.0, 1.0) if dead and death_cause == "BURNED UP" else 0.0
	_figure.frost = 1.0 - air / data.air_seconds if not suit_holes.is_empty() or dead else 0.0
	_light_inside()
	if dead:
		# A burning pilot keeps the pose they had, and flares and breaks up.
		if death_cause != "BURNED UP":
			_show_body(delta)
		return
	_figure.flail = 0.0
	_lift_ease = move_toward(_lift_ease, 0.0, absf(data.stand_height - AstronautView.MIDDLE / AstronautView.METERS_PER_PIXEL) / LANDING_EASE_SECONDS * delta)
	_figure.lift = _lift_ease
	match mode:
		SURFACE:
			_figure.look = AstronautView.Look.SIDE
			_figure.body_angle = rotate_toward(_figure.body_angle, wrapf(_up_heading - _roll, -PI, PI), 10.0 * delta)
			_figure.ground_up = wrapf(_up_heading - _roll, -PI, PI)
			_figure.facing_right = _facing_right
			_figure.feet_below = data.stand_height
			_figure.speed_share = absf(_along) / data.ground_walk_speed
			_figure.rise_share = _rising / data.jump_speed
			if _pose_left > 0.0:
				_pose_left -= delta
				_figure.motion = &"land" if _pose == data.jump_side[5] else &"push"
			elif _firing != Vector2.ZERO:
				_figure.motion = &"jet"
			elif not _grounded:
				# Dropping fast, they flail: an honest body reacting, not a forecast.
				var descent: float = _descent()
				if descent > data.flail_from_speed:
					_figure.motion = &"fall"
					_figure.flail = flail_share(descent, data.flail_from_speed, data.flail_full_speed)
				else:
					_figure.motion = &"air"
			elif absf(_along) > 4.0:
				_figure.motion = &"walk"
			else:
				_figure.motion = &"idle"
		EVA:
			# Upright when drifting, leaning into a push until they're nearly flat, seen from the back
			# with the head the way they face, like the ship's nose.
			_figure.feet_below = 0.0
			_figure.body_angle = rotate_toward(_figure.body_angle, wrapf(facing - _roll, -PI, PI), 10.0 * delta)
			var jetting: bool = _firing != Vector2.ZERO or _turning != 0.0
			if _falling_to_world:
				# Falling to a world: seen from the side, turning about their middle, and flailing
				# harder the faster they drop, unless the jetpack's firing.
				_figure.look = AstronautView.Look.SIDE
				_figure.facing_right = _fall_facing_right
				_figure.ground_up = _sky_heading(_gravity_model.get_dominant_body(state.x, state.y, state.time))
				if jetting:
					_figure.motion = &"jet"
				else:
					_figure.motion = &"fall"
					_figure.flail = flail_share(_descent(), data.flail_from_speed, data.flail_full_speed)
			else:
				_figure.look = AstronautView.Look.EVA
				_figure.motion = &"jet" if jetting else &"float"
				if _lift_ease != 0.0:
					_figure.ground_up = _sky_heading(_gravity_model.get_dominant_body(state.x, state.y, state.time))
		INDOORS:
			_figure.feet_below = data.stand_height
			_figure.body_angle = rotate_toward(_figure.body_angle, wrapf(_up_heading - _roll, -PI, PI), 10.0 * delta)
			_figure.facing_right = _facing_right
			if _ladder >= 0:
				# On a ladder, seen from behind, climbing.
				_figure.look = AstronautView.Look.CLIMB
				_figure.motion = &"climb"
				_figure.speed_share = absf(_climbing) / data.climb_speed
			else:
				_figure.look = AstronautView.Look.SIDE
				_figure.speed_share = absf(_along) / data.ground_walk_speed
				_figure.motion = &"walk" if absf(_along) > 4.0 else &"idle"
		INSIDE:
			# From above, facing the way they walk.
			_figure.look = AstronautView.Look.ABOVE
			_figure.feet_below = 0.0
			_figure.body_angle = wrapf(facing - _roll, -PI, PI)
			_figure.speed_share = _walking.length() / data.walk_speed
			_figure.motion = &"walk" if _walking.length() > 5.0 else &"idle"


# Dead: limp, tumbling from the side near a world and from above in space, and on the ground tipping
# over onto its back and settling, its middle sinking to the ground rather than jumping.
func _show_body(delta: float) -> void:
	_figure.motion = &"limp"
	_figure.push = Vector2.ZERO
	_figure.turning = 0.0
	_figure.holding = 0
	_figure.flail = 0.0
	_figure.feet_below = 0.0
	_figure.body_angle = wrapf(facing - _roll, -PI, PI)
	if _resting:
		_figure.look = AstronautView.Look.SIDE
		_figure.facing_right = _fall_facing_right
		_figure.ground_up = wrapf(_up_heading - _roll, -PI, PI)
		_figure.lift = _settle_middle - state.ground_clearance
		return
	# In the air: from the side near a world, as when alive, and from above in space.
	_lift_ease = move_toward(_lift_ease, 0.0, absf(data.stand_height - AstronautView.STANDING_MIDDLE) / LANDING_EASE_SECONDS * delta)
	_figure.lift = _lift_ease
	if _falling_to_world:
		_figure.look = AstronautView.Look.SIDE
		_figure.facing_right = _fall_facing_right
		_figure.ground_up = _sky_heading(_gravity_model.get_dominant_body(state.x, state.y, state.time))
	else:
		_figure.look = AstronautView.Look.EVA


# Inside a station, the pilot's lit by the lamps where they stand, and the helmet lamp comes on where
# that's dark. Anywhere else, it's out.
func _light_inside() -> void:
	if mode != INSIDE:
		if helmet_lamp:
			helmet_lamp = false
			_station.light_helmet(Vector2.ZERO, 0.0, false)
		_figure.light_level = 1.0
		# Outside, lit by the star, and dark in a world's shadow. Indoors at a base, by the room.
		if mode == EVA or mode == SURFACE:
			_figure.light_from = (-Vector2(state.x, state.y).normalized()).rotated(-_roll)
			_figure.sun_level = Sunlight.at(_gravity_model, state.x, state.y, state.time)
		else:
			_figure.light_from = Vector2(-1.0, -1.4)
			_figure.sun_level = 1.0
		return
	_figure.light_from = Vector2(-1.0, -1.4)
	_figure.sun_level = 1.0
	var room: float = _station.light_at(_local)
	# The player's setting: always on, always off, or by itself where it's dark.
	match String(GameSettings.value("helmet_lamp")):
		"ON":
			helmet_lamp = true
		"OFF":
			helmet_lamp = false
		_:
			if helmet_lamp and room > LAMP_OFF_ABOVE:
				helmet_lamp = false
			elif not helmet_lamp and room < LAMP_ON_BELOW:
				helmet_lamp = true
	_station.light_helmet(_local, _local_facing, helmet_lamp)
	# Their own lamp lights them a little too.
	_figure.light_level = maxf(room, 0.55) if helmet_lamp else room


# From the side, standing up straight on the ground, facing the way they last walked.
func _animate_on_ground(delta: float) -> void:
	var frames: PackedInt32Array = data.idle_side
	var fps: float = data.idle_fps
	if _firing != Vector2.ZERO:
		frames = data.hover_side
		fps = data.jet_fps
	elif not _grounded:
		var rise_share: float = _rising / data.jump_speed
		frames = PackedInt32Array([data.jump_side[2] if rise_share > 0.3 else (data.jump_side[3] if rise_share > -0.3 else data.jump_side[4])])
	elif absf(_along) > 4.0:
		frames = data.stride_side
		fps = data.stride_fps * absf(_along) / data.ground_walk_speed
	_stride += delta * fps
	if _pose_left > 0.0:
		_pose_left -= delta
		_sprite.frame = _pose
	else:
		_sprite.frame = frames[int(_stride) % frames.size()]
	_sprite.flip_h = not _facing_right
	_sprite.flip_v = false
	rotation = _up_heading


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	if mode == ABOARD:
		return
	_pixels_per_unit = pixels_per_unit
	position = Vector2((state.x - center_x) * pixels_per_unit, (state.y - center_y) * pixels_per_unit)
	_sprite.scale = Vector2.ONE * minf(pixels_per_unit, 1.0)
	var show_dot: bool = pixels_per_unit < dot_max_zoom
	_sprite.visible = not show_dot and _figure == null
	if _figure != null:
		# The same size inside a station as out, as walking inside already has it. The station's art
		# pixels are bigger than the pilot's, which keeping the pilot's real size is worth.
		_figure.scale = Vector2.ONE * minf(pixels_per_unit, 1.0)
		_figure.visible = not show_dot
	_show_dot = show_dot
	queue_redraw()


func _draw() -> void:
	if _show_dot:
		var palette: AgencyPalette = UiStyle.palette()
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), palette.hull_darkest)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), palette.telemetry_cyan)
