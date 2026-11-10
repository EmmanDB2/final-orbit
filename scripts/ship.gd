# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship) and "Physics"
# (64-bit math, floating origin).
#
# The ship's real position and velocity live in a 64-bit ShipState, because Vector2
# is only 32-bit, and gravity moves it through the GravityModel interface. The node
# only shows the result: it's placed on screen from the current view. Closer than the
# Orbit view it's the sprite, at true size with no smoothing. At the Orbit view and farther
# it's the icon, and very far out it's a dot.
#
# Three things can steer the nose, strongest first: the turn keys, drag to point, and
# STAB, which holds whichever of four directions was closest when it took over (along
# the path or toward the body, nose first or thruster first). All of them use the RCS,
# at turn_acceleration. The ENGINE switch turns the main engine on and off, and the throttle
# sets how hard it pushes, with 0 idling. It cuts out on touchdown, docking, the pilot leaving,
# or running dry, so it's never left on by mistake.
#
# The RCS can also translate, moving the ship in any of four directions without turning
# it, for docking and precise landings. ASS doesn't cancel this, and it's too weak to lift
# off from anything.
#
# Fuel has mass. Burning it makes the ship lighter and quicker, and the main engine and
# RCS both stop when it runs out. Landing on the planet refills it until stations exist.
#
# On the ground the ship settles on whatever's holding it up, which is upright if it's whole,
# and the turn keys do nothing, so thrust lifts it straight off.
#
# The landing legs go down with LEGS. Down, the ship stands on their feet and they take a
# harder landing. Up, it lands on its engine bell. Their pixels are real, so they're what the
# ground hits first and they can break off, leaving the ship tipped over on what's left.
#
# Pixels are the ship, from "Destruction" in DESIGN.md. The ground touches whichever pixel
# reaches it first, and a hit crushes pixels from that side. Pieces no longer attached fly
# off as debris, and the ship then turns around its new center of mass. Losing a module
# changes how it flies: a lost RCS module can't push its way, a lost engine module pushes
# off-center and spins the ship, and a holed tank vents and pushes the ship away from the
# hole. Lose the cockpit and the ship is lost.
#
# Two flight modes, from "Flight modes" in DESIGN.md. RAW is just your inputs. ASS
# (Attitude Stabilization System) also fires the RCS against the spin when you let
# go of the turn keys. ASS never touches velocity, since that would break orbits.
extends Node2D

## How wide a column of the ground is, in world units. See the gravity model's terrain.
const WORLD_PIXEL: float = 2.0
## How many columns to each side the ship checks the ground under itself, enough for its whole
## width, legs out, however it's turned.
const GROUND_CHECK_COLUMNS: int = 90
## How long a hit shakes the art, in ticks.
const JOLT_TICKS: int = 18

## Emitted every physics tick with the ship's real position in the world.
signal world_position_changed(x: float, y: float)
## Emitted when the flight mode changes: true for ASS, false for RAW.
signal assist_changed(enabled: bool)
## Emitted when the ship's path has changed, from a burn or from touching a surface.
signal orbit_changed
## Emitted when STAB is switched on or off.
signal stab_changed(enabled: bool)
## Emitted when the ship reaches the ground, with its speed relative to the ground, whether
## its nose was pointing away from the surface, and the fastest landing that does no damage.
signal touched_down(speed: float, upright: bool, safe_speed: float)
## Emitted when how hard the engine is pushing changes, from 0 for off to 1 for flat out.
signal engine_changed(share: float)
## Emitted when the ENGINE switch goes on or off, by the pilot or cutting out by itself.
signal engine_switched(on: bool)
## Emitted when the legs start or finish moving: which way they're going, and whether they
## still are.
signal legs_changed(down: bool, moving: bool)
## Emitted when the ship leaves the ground.
signal lifted_off
## Emitted when a piece breaks off, with where it is, how it's moving, how it's turned, and
## the push it gets from the hit, in world units per second.
signal part_detached(piece: Dictionary, x: float, y: float, velocity_x: float, velocity_y: float, angle: float, spin: float, kick: Vector2)
## Emitted as destroyed pixels come off: where they are relative to the ship in the world, how
## big a spark each one is, how the ship's moving, and how the hit throws them.
signal pixels_scattered(offsets: PackedVector2Array, colors: PackedColorArray, size: int, x: float, y: float, velocity_x: float, velocity_y: float, kick: Vector2, hit_offset: Vector2, blast: float)
## Emitted with a short warning for the pilot, such as a module going down.
signal warning_raised(text: String)
## Emitted when the cockpit is lost, and the ship with it.
signal ship_lost
## Emitted when the ship can or can't fly any more, from damage or an empty tank.
## Emitted when the ship docks at a station or leaves it.
signal docked_changed(is_docked: bool)
signal stranded_changed(stranded: bool)
## Emitted several times a second with what the instruments show: altitude, speed,
## periapsis, apoapsis, time, heading, prograde, and spin.
signal flight_data_changed(data: Dictionary)

## What this ship is built from. Thrust and turning come from its engines and its mass.
@export var design: ShipDesign
## True starts the ship in ASS, false in RAW.
@export var assist_enabled: bool = true
## Below this zoom the ship is drawn as a dot.
@export var dot_max_zoom: float = 0.0001
## The icon shows at this zoom and farther, and the sprite at anything closer.
@export var icon_max_zoom: float = 1.0 / 800.0
## A module with less than this share of its working pixels left stops working.
@export var module_dead_share: float = 0.5
## How quickly heat moves to a new side of the hull as the ship turns, in radians per second.
@export var soak_turn_rate: float = 1.2
## How far above the ground the ship starts checking its shape against the terrain.
@export var terrain_check_height: float = 200.0
## The steepest ground the ship leans with when it's resting on it, in radians.
@export var most_ground_lean: float = 0.5
## Landed against something solid, the ship slides along the ground at most this far a tick, in
## world units, and only when the solid faces at least this much sideways (a share of its normal).
@export var most_slide: float = 8.0
@export var most_slide_slope: float = 0.3
## A piece that breaks off with fewer pixels than this is just sparks.
@export var smallest_chunk: int = 30
## An engine keeps pushing, more weakly, down to this share of its bell.
@export var engine_dead_share: float = 0.25
## How fast the ship straightens up on the ground, in radians per second.
@export var settle_speed: float = 2.0
## Touching down within this angle of straight up counts as upright, in radians.
@export var upright_tolerance: float = 0.5
## How many physics ticks between telemetry updates.
@export var telemetry_interval_ticks: int = 3

## Direction of the nose in radians. 0 points up the screen; positive turns clockwise.
var heading: float = 0.0
## The ship's mass, center of mass, and spin resistance, measured from its pixels.
var body: ShipBody
## Engine fuel aboard, in kilograms.
var fuel: float = 0.0
## RCS propellant aboard, in kilograms, in its own tank. Turning and translating use it.
var rcs_fuel: float = 0.0
## Main engine acceleration right now, in world units per second squared.
var thrust_acceleration: float = 0.0
## How quickly the RCS changes the spin right now, in radians per second squared.
var turn_acceleration: float = 0.0
## RCS translation acceleration right now, in world units per second squared.
var translate_acceleration: float = 0.0
## How fast the nose is turning, in radians per second.
var angular_velocity: float = 0.0
## How much of the engine's thrust it pushes with while it's on, from 0 to 1.
var throttle: float = 1.0
## Whether the ENGINE switch is on. It pushes only with fuel, some throttle, and an engine left.
var engine_on: bool = false
var stab_enabled: bool = false
## Where the ship really is and how it's moving.
var state: ShipState

var _gravity_model: GravityModel
var _thrusting: bool = false
var _was_on_surface: bool = false
## True if the landing legs are down or on their way down.
var legs_down: bool = false
## How hot the air is making the ship, where 1.0 is the top of the scale.
var heat_share: float = 0.0
## How hot the hull has got, on the same scale. Past 1.0 it burns.
var hull_temperature: float = 0.0

var _show_sprite: bool = true
var _sprite_scale: float = 1.0
## True while the ship is held at a station's port.
var docked: bool = false
## False while the pilot's out. The ship takes no orders then, though ASS and STAB keep working.
var pilot_aboard: bool = true
var _dock_holder: Callable
# Says how a nearby station is moving at a point and time, if there's one close.
var _nearby_moving: Callable
var _flame_at: Vector2 = Vector2.ZERO
var _flame_room: float = 100000.0
var _air_density: float = 0.0
var _show_dot: bool = false
var _point_active: bool = false
var _point_heading: float = 0.0
var _stab_needs_pick: bool = true
var _stab_direction: int = 0
var _spin_firing: float = 0.0
var _star_heat: float = 0.0
var _burn_energy: float = 0.0
var _burn_wait: float = 0.0
var _burning: bool = false
var _pivot: Vector2 = Vector2.ZERO
var _whole_center: Vector2 = Vector2.ZERO
var _rest_height: float = 105.0
var _mass_now: float = 1.0
var _spin_resistance_now: float = 1.0
var _engine_share: float = 1.0
var _tail_share: float = 1.0
var _thrust_x: float = 0.0
var _rcs_left: bool = true
var _rcs_right: bool = true
var _lost: bool = false
var _stranded: bool = false
var _warned_modules: Dictionary = {}
var _wave: DamageWave
var _part_sprites: Array[Sprite2D] = []
var _legs_out: float = 0.0
var _legs_moving: bool = false
var _rest_angle: float = 0.0
var _ground_lean: float = 0.0
var _engine_reported: float = 0.0
var _sink: Vector2 = Vector2.ZERO
var _sink_per_tick: float = 0.0
var _jolt_ticks: int = 0
var _jolt_size: float = 0.0
var _heat_heading: float = 0.0
var _soak_way: Vector2 = Vector2.UP
var _translate_forward: float = 0.0
var _translate_right: float = 0.0

@onready var _flame: EngineFlame = $Flame
@onready var _puffs: RcsPuffs = $RcsPuffs
@onready var _glow: ReentryGlow = $ReentryGlow
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	_flame.setup(design.flame_length)
	body = ShipBody.measure(design)
	_whole_center = body.center_of_mass
	_wave = DamageWave.new(body)
	_sprite.texture = _wave.textures[0]
	_glow.setup(_wave.textures)
	for i in range(1, body.layer_count()):
		var part := Sprite2D.new()
		part.texture = _wave.textures[i]
		add_child(part)
		move_child(part, _sprite.get_index())
		_part_sprites.append(part)
	_rest_height = body.reach(_pivot, Vector2.DOWN)
	fuel = body.fuel_capacity
	rcs_fuel = design.rcs_capacity
	_update_performance()
	_puffs.set_nozzles(body)
	_aim_flame()
	# Nothing flies until start_flight hands over gravity and a starting state.
	set_physics_process(false)
	assist_changed.emit(assist_enabled)


## Starts the ship flying.
func start_flight(gravity_model: GravityModel, start_state: ShipState, start_heading: float) -> void:
	_gravity_model = gravity_model
	state = start_state
	state.ground_clearance = _rest_height
	heading = start_heading
	rotation = heading
	set_physics_process(true)


# Godot calls this at a fixed 60 ticks per second, so the flight is the same
# on any screen. delta is the length of one tick in seconds.
func _physics_process(delta: float) -> void:
	if pilot_aboard and Input.is_action_just_pressed("toggle_assist"):
		assist_enabled = not assist_enabled
		assist_changed.emit(assist_enabled)
	if pilot_aboard and Input.is_action_just_pressed("toggle_legs"):
		_toggle_legs()
	if pilot_aboard and Input.is_action_just_pressed("toggle_stab"):
		stab_enabled = not stab_enabled
		_stab_needs_pick = true
		stab_changed.emit(stab_enabled)
	if docked:
		_hold_docked(delta)
		return
	if pilot_aboard and Input.is_action_just_pressed("thrust"):
		_switch_engine(not engine_on)
	if engine_on and (fuel <= 0.0 or _engine_share <= 0.0 or _lost):
		_switch_engine(false)

	_spin_firing = 0.0
	if state.is_on_surface():
		angular_velocity = 0.0
		if not _lost:
			heading = rotate_toward(heading, _local_up_heading() - _rest_angle + _ground_lean, settle_speed * delta)
	else:
		var spin_before: float = angular_velocity
		var turn_input: float = Input.get_axis("turn_left", "turn_right") if pilot_aboard else 0.0
		if rcs_fuel <= 0.0 or _lost:
			pass
		elif turn_input != 0.0:
			angular_velocity += turn_input * turn_acceleration * delta
			_stab_needs_pick = true
		elif _point_active:
			_steer_toward(_point_heading, delta)
			_stab_needs_pick = true
		elif stab_enabled:
			_steer_toward(_stab_heading(), delta)
		elif assist_enabled:
			# Same thrusters as manual turning, so the same strength. move_toward stops
			# exactly at zero instead of overshooting into a tiny spin the other way.
			angular_velocity = move_toward(angular_velocity, 0.0, turn_acceleration * delta)
		# The left nozzle turns the nose clockwise and the right one back, so a lost one
		# can't push its way.
		var spin_change: float = angular_velocity - spin_before
		if (spin_change > 0.0 and not _rcs_left) or (spin_change < 0.0 and not _rcs_right):
			angular_velocity = spin_before
		var firing: float = absf(angular_velocity - spin_before) / (turn_acceleration * delta)
		_burn_rcs(design.rcs_fuel_rate * firing * delta)
		_spin_firing = signf(angular_velocity - spin_before) * firing
		heading += angular_velocity * delta
	rotation = heading

	_thrusting = pilot_aboard and engine_on and throttle > 0.0 and fuel > 0.0 and _engine_share > 0.0 and not _lost
	if _thrusting:
		state.velocity_x += sin(heading) * thrust_acceleration * throttle * delta
		state.velocity_y -= cos(heading) * thrust_acceleration * throttle * delta
		# Thrust off to one side of the center of mass spins the ship.
		var thrust_force: float = design.engine_force * _engine_share * throttle
		angular_velocity -= (_thrust_x - _pivot.x) * thrust_force / _spin_resistance_now * delta
		_burn_fuel(thrust_force / design.exhaust_velocity * delta)
	var translate_forward: float = _usable_forward(Input.get_axis("translate_back", "translate_forward")) if pilot_aboard else 0.0
	var translate_right: float = _usable_right(Input.get_axis("translate_left", "translate_right")) if pilot_aboard else 0.0
	var translating: bool = rcs_fuel > 0.0 and not _lost and (translate_forward != 0.0 or translate_right != 0.0)
	_translate_forward = translate_forward if translating else 0.0
	_translate_right = translate_right if translating else 0.0
	if translating:
		var along: float = translate_forward * translate_acceleration * delta
		var across: float = translate_right * translate_acceleration * delta
		state.velocity_x += sin(heading) * along + cos(heading) * across
		state.velocity_y += -cos(heading) * along + sin(heading) * across
		_burn_rcs(design.rcs_fuel_rate * (absf(translate_forward) + absf(translate_right)) * delta)

	var venting: bool = _leak_fuel(delta)
	var in_air: bool = _push_through_air(delta)
	_heat_hull(delta)

	_move_legs(delta)
	_touch_terrain()
	_gravity_model.propagate(state, delta)
	_find_flame_room()

	var on_surface: bool = state.is_on_surface()
	if _thrusting or translating or venting or in_air or on_surface != _was_on_surface:
		orbit_changed.emit()
	if on_surface and not _was_on_surface:
		_switch_engine(false)
		var tilt: float = absf(angle_difference(heading, _local_up_heading()))
		touched_down.emit(state.get_touchdown_speed(), tilt <= upright_tolerance, _safe_impact_speed())
		var landed_on: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
		_hit_ground(state.get_touchdown_speed(), landed_on)
		if _gravity_model.get_body_parent(landed_on) == 0 and not _lost:
			_refill_sound_tanks()
	elif _was_on_surface and not on_surface:
		lifted_off.emit()
	_was_on_surface = on_surface
	_check_stranded()
	_show_damage()
	var engine_now: float = throttle * _engine_share if _thrusting else 0.0
	if engine_now != _engine_reported:
		_engine_reported = engine_now
		engine_changed.emit(engine_now)

	world_position_changed.emit(state.x, state.y)

	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report_telemetry()


# Held at the port: the station says where the ship is, and nothing else moves it.
func _hold_docked(delta: float) -> void:
	state.time += delta
	var hold: PackedFloat64Array = _dock_holder.call(state.time)
	state.x = hold[0]
	state.y = hold[1]
	state.velocity_x = hold[2]
	state.velocity_y = hold[3]
	heading = hold[4]
	rotation = heading
	angular_velocity = hold[5]
	_spin_firing = 0.0
	_translate_forward = 0.0
	_translate_right = 0.0
	_thrusting = false
	_move_legs(delta)
	_check_stranded()
	_show_damage()
	if _engine_reported != 0.0:
		_engine_reported = 0.0
		engine_changed.emit(0.0)
	world_position_changed.emit(state.x, state.y)
	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report_telemetry()
	if pilot_aboard and Input.is_action_just_pressed("undock"):
		undock()


## How the ship is doing, for its card.
func status() -> Dictionary:
	return {
		"name": design.display_name,
		"chip": design.chip,
		"mass": _mass_now,
		"fuel_share": fuel / body.original_fuel_capacity,
		"rcs_share": rcs_fuel / design.rcs_capacity if design.rcs_capacity > 0.0 else 0.0,
		"delta_v": delta_v(),
		"hull_share": float(body.pixel_count) / body.original_pixel_count,
		"engine_share": _engine_share,
		"legs_down": legs_down,
	}


## Whether the pilot can step out from here: into space, or onto the ground when it's landed.
func can_be_left() -> bool:
	return not _lost and (FeatureFlags.WALKING_ON_WORLDS or not state.is_on_surface())


## Whether there's still somewhere to get back in.
func can_be_boarded() -> bool:
	return not _lost


## Says whether the pilot's aboard.
func set_pilot_aboard(aboard: bool) -> void:
	pilot_aboard = aboard
	if not aboard:
		_switch_engine(false)
	_point_active = false


## Where the pilot comes out, as an offset from the ship in the world.
func eva_exit_offset() -> Vector2:
	return _art_to_world(design.eva_exit)


## Where the pilot gets back in, as an offset from the ship in the world.
func cockpit_offset() -> Vector2:
	return _art_to_world(design.cockpit_point)


## Whether the hatch is still there to dock with.
func has_hatch() -> bool:
	return pilot_aboard and not _lost and not state.is_on_surface() and body.has_pixel(design.hatch_point + Vector2(0.0, 3.0))


## Where the hatch is from the ship's center, in the ship's own frame.
func hatch_from_center() -> Vector2:
	return design.hatch_point - _pivot


## Takes the ship onto a station's port. The holder is called each tick with the time, and says
## where the ship is: [x, y, velocity x, velocity y, heading, spin]. A station fills the tanks and
## repairs the hull, for free for now.
func dock(holder: Callable) -> void:
	docked = true
	_dock_holder = holder
	_switch_engine(false)
	repair()
	fuel = body.fuel_capacity
	rcs_fuel = design.rcs_capacity
	hull_temperature = 0.0
	heat_share = 0.0
	_update_performance()
	docked_changed.emit(true)
	orbit_changed.emit()


## Lets go of the station, drifting gently backward off the port.
func undock() -> void:
	if not docked:
		return
	docked = false
	var backward: Vector2 = Vector2.DOWN.rotated(heading) * design.undock_speed
	state.velocity_x += backward.x
	state.velocity_y += backward.y
	docked_changed.emit(false)
	orbit_changed.emit()


## Gives the ship a way to ask how a nearby station is moving at a point and time, so the pilot's
## speed and direction markers read against it. An empty one means there's nothing nearby.
func set_nearby_moving(moving_at: Callable) -> void:
	_nearby_moving = moving_at


# Runs once per rendered frame. Cosmetic only, so it doesn't touch the flight.
func _process(delta: float) -> void:
	_flame.set_burn(_engine_reported if _show_sprite else 0.0, minf(_air_density, 1.0), 1.0 - _engine_share, _flame_room)
	# Small corrections while holding steady don't show, so the nozzles don't flicker.
	var turning_clockwise: bool = _spin_firing > 0.2
	var turning_back: bool = _spin_firing < -0.2
	_glow.visible = _show_sprite
	_glow.set_heat(heat_share, hull_temperature, Vector2.UP.rotated(_heat_heading - heading), _soak_way, _sprite_scale)
	_puffs.visible = _show_sprite
	_puffs.set_leaks(_leak_points())
	_puffs.set_firing(
			turning_clockwise or _translate_right > 0.0,
			turning_back or _translate_right < 0.0,
			_translate_forward > 0.0,
			_translate_forward < 0.0,
			_sprite_scale)
	_icon.frame = 1 if _thrusting else 0


func _switch_engine(on: bool) -> void:
	if on != engine_on:
		engine_on = on
		engine_switched.emit(on)


func _burn_fuel(amount: float) -> void:
	if amount > 0.0:
		fuel = maxf(fuel - amount, 0.0)
		_update_performance()


func _burn_rcs(amount: float) -> void:
	if amount > 0.0:
		rcs_fuel = maxf(rcs_fuel - amount, 0.0)
		_update_performance()


# Air pushes back against the ship's motion through it, and it moves with the planet, so
# this measures against the moving air. Side-on, the ship catches more of it. Returns
# whether there was any air to push through.
func _push_through_air(delta: float) -> bool:
	heat_share = 0.0
	var density: float = _gravity_model.get_air_density(state.x, state.y, state.time)
	_air_density = density
	if state.is_on_surface():
		return false
	if density <= 0.0:
		return false

	var air: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var through_x: float = state.velocity_x - air[0]
	var through_y: float = state.velocity_y - air[1]
	var speed: float = sqrt(through_x * through_x + through_y * through_y)
	if speed < 0.001:
		return true

	var along_nose: float = absf(through_x * sin(heading) - through_y * cos(heading)) / speed
	var across_nose: float = sqrt(maxf(1.0 - along_nose * along_nose, 0.0))
	var catching: float = body.width * along_nose + body.length * across_nose
	var mass_now: float = body.mass + fuel + rcs_fuel
	var slowing: float = 0.5 * density * speed * speed * design.drag_coefficient * catching / mass_now
	var change: float = minf(slowing * delta, speed)
	state.velocity_x -= through_x / speed * change
	state.velocity_y -= through_y / speed * change

	# Heating grows with the cube of speed, so a steep, fast entry is far worse.
	heat_share = sqrt(density) * speed * speed * speed / design.heat_limit
	_heat_heading = atan2(through_x, -through_y)
	return true


# Fills whatever tanks have no holes. A holed one wouldn't hold it.
func _refill_sound_tanks() -> void:
	var sound: float = 0.0
	for tank: Dictionary in body.tanks:
		if body.module_share(tank["module"]) >= 1.0:
			sound += tank["capacity"]
	fuel = maxf(fuel, sound)
	rcs_fuel = design.rcs_capacity
	_update_performance()


func _on_star_heat_changed(share: float) -> void:
	_star_heat = share


# The hull warms toward whatever's heating it, and past the top of the scale it burns away
# from the hot side, whichever that is.
func _heat_hull(delta: float) -> void:
	var heat: float = heat_share + _star_heat
	hull_temperature += (heat - hull_temperature) * minf(delta / design.hull_heat_seconds, 1.0)
	_soak_up_heat(delta)
	if hull_temperature <= 1.0:
		_burning = false
		_burn_energy = 0.0
		return
	if not _burning:
		_burning = true
		warning_raised.emit("HULL BURNING")
	_burn_energy += (hull_temperature - 1.0) * design.burn_power * delta
	_burn_wait -= delta
	if _burn_wait > 0.0:
		return
	_burn_wait = design.burn_seconds

	var hot_side: Vector2 = Vector2.UP.rotated(_heat_heading)
	if _star_heat > heat_share:
		hot_side = Vector2(-state.x, -state.y).normalized()
	var erased: Dictionary = body.crush(hot_side.rotated(-heading), _burn_energy, int(state.time * 1000.0))
	_burn_energy = 0.0
	var hot_on_art: Vector2 = hot_side.rotated(-heading)
	_take_damage(erased, -hot_side * 30.0, _pivot + hot_on_art * body.reach(_pivot, hot_on_art), 25.0)


# Heat soaks into the side facing it, and stays there as the ship turns or leaves the air,
# working around slowly if a new side starts taking it.
func _soak_up_heat(delta: float) -> void:
	var hot_way: Vector2 = Vector2.ZERO
	if _star_heat > heat_share and _star_heat > 0.05:
		hot_way = Vector2(-state.x, -state.y).normalized().rotated(-heading)
	elif heat_share > 0.03:
		hot_way = Vector2.UP.rotated(_heat_heading - heading)
	if hot_way == Vector2.ZERO:
		return
	if hull_temperature < 0.05:
		_soak_way = hot_way
	else:
		var turned: float = clampf(_soak_way.angle_to(hot_way), -soak_turn_rate * delta, soak_turn_rate * delta)
		_soak_way = _soak_way.rotated(turned)


# How much of a forward or back push the working nozzles can give. The tail nozzles push
# forward and sit on the engine modules, and the two side nozzles push back.
func _usable_forward(wanted: float) -> float:
	if wanted > 0.0:
		return wanted * _tail_share
	return wanted * ((1.0 if _rcs_left else 0.0) + (1.0 if _rcs_right else 0.0)) / 2.0


# The left nozzle pushes right and the right nozzle pushes left.
func _usable_right(wanted: float) -> float:
	if (wanted > 0.0 and not _rcs_left) or (wanted < 0.0 and not _rcs_right):
		return 0.0
	return wanted


# The way the ground lies from the ship, in the ship's own frame.
func _local_down() -> Vector2:
	return Vector2.DOWN.rotated(_local_up_heading() - heading)


# A point on the art, as an offset from the ship in the world.
func _art_to_world(point: Vector2) -> Vector2:
	return (point - _pivot).rotated(heading)


# Legs fully down and all working take a harder landing.
func _safe_impact_speed() -> float:
	if _legs_out < 1.0:
		return design.safe_impact_speed
	for i in range(body.modules.size()):
		if body.modules[i].kind == "leg" and body.working_share(i) < module_dead_share:
			return design.safe_impact_speed
	return design.legs_safe_impact_speed


# The legs carry the ship's weight on the ground, so they can't go up there.
func _toggle_legs() -> void:
	if _lost:
		return
	if legs_down and state.is_on_surface():
		warning_raised.emit("LEGS LOCKED ON GROUND")
		return
	legs_down = not legs_down
	_legs_moving = true
	legs_changed.emit(legs_down, true)


func _move_legs(delta: float) -> void:
	if not _legs_moving:
		return
	_legs_out = move_toward(_legs_out, 1.0 if legs_down else 0.0, delta / design.legs_seconds)
	body.set_parts_out(_legs_out)
	_rest_height = body.reach(_pivot, Vector2.DOWN)
	_rest_angle = body.rest_angle()
	_place_art()
	if _legs_out == (1.0 if legs_down else 0.0):
		_legs_moving = false
		legs_changed.emit(legs_down, false)


# How far the flame can reach before the ground stops it, along the way it's pointing.
func _find_flame_room() -> void:
	_flame_room = 100000.0
	# It takes a moment to die after the engine stops, and it shouldn't go through the ground then.
	if not _thrusting and not _flame.visible:
		return
	var height: float = _gravity_model.get_altitude(state.x, state.y, state.time)
	if height > design.flame_length * 2.0 + state.ground_clearance:
		return
	var aim: float = Vector2.DOWN.dot(_local_down())
	if aim > 0.2:
		var exit_below: float = (_flame_at - _pivot).dot(_local_down())
		_flame_room = maxf((height - exit_below) / aim, 0.0)


# The ground isn't flat, so whichever of the ship's pixels is first to meet it is what touches.
# That only matters low down. It also works out which way the ground under the ship leans.
func _touch_terrain() -> void:
	var down: Vector2 = _local_down()
	var flat_reach: float = body.reach(_pivot, down)
	state.ground_clearance = flat_reach
	_ground_lean = 0.0
	if _gravity_model.get_altitude(state.x, state.y, state.time) > flat_reach + terrain_check_height:
		return
	var dominant: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var column: int = floori(_gravity_model.get_ground_column(state.x, state.y, state.time))
	var strip: PackedFloat32Array = _gravity_model.get_ground_strip(dominant, column - GROUND_CHECK_COLUMNS, 1, GROUND_CHECK_COLUMNS * 2 + 1)
	var here: float = strip[GROUND_CHECK_COLUMNS * 2]
	var along: Vector2 = down.orthogonal()
	var clearance: float = 0.0
	for point: Vector2 in body.outline_now():
		var from_middle: Vector2 = point - _pivot
		var drop: float = from_middle.dot(down)
		# Clockwise around the planet is to the ship's right when it's upright.
		var sideways: int = clampi(roundi(-from_middle.dot(along) / WORLD_PIXEL), -GROUND_CHECK_COLUMNS, GROUND_CHECK_COLUMNS)
		var ground: float = strip[(sideways + GROUND_CHECK_COLUMNS) * 2]
		clearance = maxf(clearance, drop + ground - here)
	state.ground_clearance = clearance
	# Resting, it follows its own lowest pixel down as it settles, so it stays on the ground.
	if state.is_on_surface():
		_rest_on_ground()

	var stance: int = mini(roundi((62.0 if legs_down else 18.0) / WORLD_PIXEL), GROUND_CHECK_COLUMNS)
	var left: float = strip[(GROUND_CHECK_COLUMNS - stance) * 2]
	var right: float = strip[(GROUND_CHECK_COLUMNS + stance) * 2]
	_ground_lean = clampf(atan2(left - right, stance * 2.0 * WORLD_PIXEL), -most_ground_lean, most_ground_lean)


# A point on the art as it's drawn right now, which a crushed ship is still sinking toward.
func _shown_to_world(point: Vector2) -> Vector2:
	return (point - _pivot + _sink).rotated(heading)


# The ground takes all the ship's energy above the safe speed, since it's far heavier. The
# star takes everything, whatever the speed.
func _hit_ground(speed: float, landed_on: int) -> void:
	var safe: float = _safe_impact_speed()
	var energy: float = 0.5 * _mass_now * maxf(speed * speed - safe * safe, 0.0)
	if landed_on == 0:
		energy = INF
	if energy <= 0.0:
		return
	var up: Vector2 = Vector2.UP.rotated(_local_up_heading())
	var down: Vector2 = _local_down()
	var touching: Vector2 = _pivot + down * body.reach(_pivot, down)
	_take_damage(body.crush(down, energy, int(state.time * 1000.0)), up * minf(speed * 0.4, 200.0), touching, clampf(speed * 0.7, 60.0, 320.0))


## Something solid stopped the ship, at this offset from it in the world. The normal points out of
## the solid, the ship moves out along it by this much, and the solid is moving at this velocity.
## It bounces, and takes damage above the safe speed, as with hitting the ground, with a warning
## naming what it hit. A landed ship slides along the ground out of it instead, so one that tips
## over beside a building ends up beside it, not in it.
func hit_solid(contact: Vector2, normal: Vector2, push: float, solid_x: float, solid_y: float, what: String = "STATION") -> void:
	if state.is_on_surface():
		_slide_out_on_ground(normal, push)
		return
	state.x += normal.x * push
	state.y += normal.y * push
	var spin_speed: Vector2 = Vector2(-contact.y, contact.x) * angular_velocity
	var moving: Vector2 = Vector2(state.velocity_x - solid_x, state.velocity_y - solid_y) + spin_speed
	var into: float = -moving.dot(normal)
	if into <= 0.0:
		return
	var lever: float = contact.cross(normal)
	var impulse: float = (1.0 + design.contact_bounce) * into / (1.0 / _mass_now + lever * lever / _spin_resistance_now)
	state.velocity_x += normal.x * impulse / _mass_now
	state.velocity_y += normal.y * impulse / _mass_now
	angular_velocity += lever * impulse / _spin_resistance_now
	orbit_changed.emit()

	var safe: float = design.safe_impact_speed
	if into <= safe:
		return
	var energy: float = 0.5 * _mass_now * (into * into - safe * safe)
	var inward: Vector2 = (-normal).rotated(-heading)
	var touching: Vector2 = contact.rotated(-heading) + _pivot
	warning_raised.emit("%s COLLISION" % what)
	_take_damage(body.crush(inward, energy, int(state.time * 1000.0)), normal * minf(into * 0.4, 200.0), touching, clampf(into * 0.7, 60.0, 320.0))


# Landed, the ship moves along the ground only, never up off it or down into it, as far as it takes
# to clear the solid by the push along its normal. A solid pressing straight down, like an overhang,
# can't push it anywhere. The ground sets it back down where it ends up.
func _slide_out_on_ground(normal: Vector2, push: float) -> void:
	var up := Vector2.UP.rotated(_local_up_heading())
	var along: Vector2 = normal - up * normal.dot(up)
	var share: float = along.length()
	if share < most_slide_slope:
		return
	var shift: Vector2 = along / share * minf(push / share, most_slide)
	state.x += shift.x
	state.y += shift.y


## Puts every pixel back, as a station's repair bay will.
func repair() -> void:
	var moved: Vector2 = (-_pivot).rotated(heading)
	state.x += moved.x
	state.y += moved.y
	_pivot = Vector2.ZERO
	_sink = Vector2.ZERO
	_jolt_ticks = 0
	body = ShipBody.measure(design)
	body.set_parts_out(_legs_out)
	_wave.show_body(body)
	_lost = false
	_warned_modules.clear()
	_update_for_damage()


## The corners of the ship's outline, as offsets from it in the world.
func world_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in body.outline_now():
		points.append(_art_to_world(point))
	return points


## Points along the edges of the ship's outline, as offsets from it in the world.
func world_outline_samples(spacing: float) -> PackedVector2Array:
	var points: PackedVector2Array = body.outline_samples_now(spacing)
	for i in range(points.size()):
		points[i] = _art_to_world(points[i])
	return points


## Whether there's anything left of the ship.
func has_shape() -> bool:
	return body.pixel_count > 0


## True if there's a pixel of the ship at this offset from it in the world.
func has_pixel_at(world_offset: Vector2) -> bool:
	return body.has_pixel(world_offset.rotated(-heading) + _pivot)


## The ship's whole mass right now, fuel included.
func current_mass() -> float:
	return _mass_now


## Something has hit the ship at this offset from it in the world, with this much energy.
func take_hit(world_offset: Vector2, energy: float) -> void:
	var point: Vector2 = world_offset.rotated(-heading) + _pivot
	var erased: Dictionary = body.dent(point, energy, int(state.time * 1000.0))
	_take_damage(erased, world_offset.normalized() * 40.0, point, clampf(sqrt(energy / 500000.0) * 6.0, 40.0, 200.0))


# Starts showing what a hit destroyed, sends off what broke loose, and updates everything
# damage changes. The pieces fly away from where the hit landed.
func _take_damage(erased: Dictionary, kick: Vector2, hit_point: Vector2, blast: float) -> void:
	if erased["points"].is_empty():
		return
	_wave.add_hit(erased, hit_point, kick, blast)
	_jolt_size = maxf(_jolt_size, clampf(erased["points"].size() / 120.0, 0.5, 5.0))
	_jolt_ticks = JOLT_TICKS
	var hit_at: Vector2 = _art_to_world(hit_point)
	for piece: Dictionary in body.split_off():
		if piece["pixel_count"] < smallest_chunk:
			_wave.add_loose(piece["pixels"], piece["colors"])
			continue
		_wave.remove_now(piece["pixels"])
		var at: Vector2 = _art_to_world(piece["center"])
		var thrown: Vector2 = kick + (at - hit_at).normalized() * blast * 0.4
		part_detached.emit(piece, state.x + at.x, state.y + at.y, state.velocity_x, state.velocity_y, heading, angular_velocity, thrown)
	_update_for_damage()


# Plays out damage on the art one tick further: pixels come off as sparks, a crushed ship
# sinks to where it now rests, and the whole thing shakes briefly.
func _show_damage() -> void:
	if _wave.is_idle() and _sink == Vector2.ZERO and _jolt_ticks <= 0:
		return
	var palette: AgencyPalette = UiStyle.palette()
	for spray: Dictionary in _wave.advance(palette.thrust_white, palette.thrust_yellow, palette.thrust_red):
		var offsets := PackedVector2Array()
		for point: Vector2 in spray["points"]:
			offsets.append(_shown_to_world(point))
		pixels_scattered.emit(offsets, spray["colors"], spray["size"], state.x, state.y, state.velocity_x, state.velocity_y, spray["kick"], _shown_to_world(spray["hit_point"]), spray["blast"])
	_sink = _sink.move_toward(Vector2.ZERO, _sink_per_tick)
	_jolt_ticks -= 1
	if _jolt_ticks <= 0:
		_jolt_size = 0.0
	_place_art()


# The flame comes out of whatever's left of the bell.
func _aim_flame() -> void:
	var exit: Dictionary = body.engine_exit(engine_dead_share)
	if not exit.is_empty():
		_flame_at = exit["middle"]
		_flame.set_exit(exit["half_width"])


func _update_for_damage() -> void:
	if _wave.is_idle():
		_wave.show_body(body)

	# The ship now turns around its new center of mass, which stays put in the world.
	if body.pixel_count > 0:
		var new_pivot: Vector2 = body.center_of_mass - _whole_center
		var moved: Vector2 = (new_pivot - _pivot).rotated(heading)
		state.x += moved.x
		state.y += moved.y
		_pivot = new_pivot
	_place_art()

	# A tank can only hold as much as is left of it, and the rest of its fuel is gone. What
	# remains leaks out over time.
	if body.fuel_capacity > 0.0:
		var fill: float = fuel / body.fuel_capacity
		for tank: Dictionary in body.tanks:
			var room: float = tank["full"] * body.module_share(tank["module"])
			if tank["capacity"] > room:
				fuel -= (tank["capacity"] - room) * fill
				body.cut_tank(tank, tank["capacity"] - room)
		fuel = clampf(fuel, 0.0, body.fuel_capacity)

	# Fuel vents from the edge of what's left of a tank, facing where the hole is.
	for tank: Dictionary in body.tanks:
		if body.module_share(tank["module"]) < 1.0:
			var tank_at: Vector2 = tank["position"]
			var hole_at: Vector2 = body.module_hole(tank["module"])
			tank["vent"] = body.nearest_in_module(tank["module"], hole_at)
			tank["vent_way"] = (hole_at - tank_at).normalized() if hole_at != tank_at else Vector2.RIGHT

	var engine_count: int = 0
	var engine_total: float = 0.0
	var engine_sideways: float = 0.0
	var cockpit_count: int = 0
	var cockpit_total: float = 0.0
	var columns_middle: float = 0.0
	for module: ModuleData in body.modules:
		columns_middle = maxf(columns_middle, module.cell.x + 1.0)
	columns_middle /= 2.0
	var tail_nozzles: int = 0
	for i in range(body.modules.size()):
		var module: ModuleData = body.modules[i]
		var share: float = body.working_share(i)
		var works: bool = share >= (engine_dead_share if module.kind == "engine" else module_dead_share)
		var on_left: bool = module.cell.x + 0.5 < columns_middle
		match module.kind:
			"engine":
				engine_count += 1
				if works:
					engine_total += share
					engine_sideways += share * (module.cell.x + 0.5 - columns_middle) * design.cell_size
				if body.nozzle_share(i) >= module_dead_share:
					tail_nozzles += 1
			"rcs":
				if on_left:
					_rcs_left = works
				else:
					_rcs_right = works
			"cockpit":
				cockpit_count += 1
				cockpit_total += share
		if not works and not _warned_modules.has(i):
			_warned_modules[i] = true
			warning_raised.emit("%s LOST" % module.display_name.to_upper().replace(",", ""))
	_engine_share = engine_total / engine_count if engine_count > 0 else 0.0
	_aim_flame()
	_tail_share = float(tail_nozzles) / engine_count if engine_count > 0 else 0.0
	_thrust_x = engine_sideways / engine_total if engine_total > 0.0 else 0.0
	_update_performance()

	_rest_height = body.reach(_pivot, Vector2.DOWN)
	_rest_angle = body.rest_angle()
	state.ground_clearance = body.reach(_pivot, _local_down())
	if state.is_on_surface():
		var was_x: float = state.x
		var was_y: float = state.y
		_rest_on_ground()
		_sink += Vector2(was_x - state.x, was_y - state.y).rotated(-heading)
		_sink_per_tick = maxf(_sink.length() / _wave.ticks_left(), 0.5)

	if cockpit_count > 0 and cockpit_total / cockpit_count < module_dead_share and not _lost:
		_lost = true
		_thrusting = false
		ship_lost.emit()


# Sets the ship down where its lowest pixel now touches, so it doesn't drop in and bounce.
func _rest_on_ground() -> void:
	var dominant: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var at: PackedFloat64Array = _gravity_model.get_body_position(dominant, state.time)
	var dx: float = state.x - at[0]
	var dy: float = state.y - at[1]
	var distance: float = sqrt(dx * dx + dy * dy)
	var ground: float = _gravity_model.get_ground_height(state.x, state.y, state.time)
	var wanted: float = _gravity_model.get_body_radius(dominant) + ground + state.ground_clearance
	if distance > 0.0:
		state.x = at[0] + dx * wanted / distance
		state.y = at[1] + dy * wanted / distance


# A holed tank leaks in proportion to the hole, losing capacity as it goes, and the escaping
# fuel pushes the ship away from the hole. Returns whether anything leaked.
func _leak_fuel(delta: float) -> bool:
	if fuel <= 0.0 or body.fuel_capacity <= 0.0:
		return false
	var leaking: bool = false
	for tank: Dictionary in body.tanks:
		var hole: float = 1.0 - body.module_share(tank["module"])
		if hole <= 0.0 or tank["capacity"] <= 0.0 or fuel <= 0.0:
			continue
		leaking = true
		var fill: float = fuel / body.fuel_capacity
		var lost_fuel: float = minf(design.tank_leak_rate * hole * delta, tank["capacity"] * fill)
		body.cut_tank(tank, lost_fuel / fill)
		fuel = maxf(fuel - lost_fuel, 0.0)

		var hole_at: Vector2 = tank["vent"]
		var outward: Vector2 = tank["vent_way"]
		var push: Vector2 = -outward * lost_fuel * design.vent_speed / delta
		var world_push: Vector2 = push.rotated(heading)
		state.velocity_x += world_push.x / _mass_now * delta
		state.velocity_y += world_push.y / _mass_now * delta
		var lever: Vector2 = hole_at - _pivot
		angular_velocity += (lever.x * push.y - lever.y * push.x) / _spin_resistance_now * delta
	if leaking:
		_update_performance()
	return leaking


# Where fuel is venting from, as pairs of a point on the art and the way it's going.
func _leak_points() -> Array:
	var leaks: Array = []
	if fuel > 0.0:
		for tank: Dictionary in body.tanks:
			if body.module_share(tank["module"]) < 1.0 and tank["capacity"] > 0.0:
				leaks.append([tank["vent"], tank["vent_way"]])
	return leaks


func _check_stranded() -> void:
	var stranded: bool = _lost or _engine_share <= 0.0 or fuel <= 0.0
	if stranded != _stranded:
		_stranded = stranded
		stranded_changed.emit(stranded)


func _update_performance() -> void:
	var now: Dictionary = body.with_fuel(fuel)
	# The RCS tank is small and near the middle, so it adds mass but barely any spin resistance.
	_mass_now = now["mass"] + rcs_fuel
	_spin_resistance_now = now["spin_resistance"]
	thrust_acceleration = design.engine_force * _engine_share / _mass_now
	turn_acceleration = design.rcs_torque / now["spin_resistance"]
	translate_acceleration = design.rcs_translate_force / _mass_now


## How much more speed the fuel aboard can give, from the rocket equation.
func delta_v() -> float:
	return design.exhaust_velocity * log((body.mass + rcs_fuel + fuel) / (body.mass + rcs_fuel))


## Starts or updates drag to point, turning the nose toward this heading.
func point_at(target_heading: float) -> void:
	_point_active = true
	_point_heading = target_heading


## Ends drag to point. ASS, STAB, or nothing takes over, depending on the flight mode.
func stop_pointing() -> void:
	_point_active = false


## How far out the turn guide's ring sits around the ship, in screen pixels.
func guide_radius() -> float:
	return maxf(125.0 * _sprite_scale, 16.0) if _show_sprite else 16.0


func _on_throttle_changed(value: float) -> void:
	throttle = value


# Fires the RCS to turn toward a heading and arrive with no spin left.
func _steer_toward(target_heading: float, delta: float) -> void:
	var error: float = angle_difference(heading, target_heading)
	var braking_limit: float = sqrt(2.0 * turn_acceleration * absf(error))
	var desired: float = signf(error) * minf(braking_limit, absf(error) * 4.0)
	angular_velocity = move_toward(angular_velocity, desired, turn_acceleration * delta)


# The heading of each direction STAB can hold, in the order of _stab_direction.
func _stab_directions() -> PackedFloat64Array:
	var body: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var body_velocity: PackedFloat64Array = _gravity_model.get_body_velocity(body, state.time)
	var along: float = atan2(state.velocity_x - body_velocity[0], body_velocity[1] - state.velocity_y)
	var away: float = _local_up_heading()
	return PackedFloat64Array([along, along + PI, away + PI, away])


func _stab_heading() -> float:
	var directions: PackedFloat64Array = _stab_directions()
	if _stab_needs_pick:
		_stab_needs_pick = false
		var closest: float = INF
		for i in range(directions.size()):
			var gap: float = absf(angle_difference(heading, directions[i]))
			if gap < closest:
				closest = gap
				_stab_direction = i
	return directions[_stab_direction]


# The heading that points the nose straight away from the body below.
func _local_up_heading() -> float:
	var body: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var body_position: PackedFloat64Array = _gravity_model.get_body_position(body, state.time)
	return atan2(state.x - body_position[0], body_position[1] - state.y)


func _report_telemetry() -> void:
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var against: Vector2 = Vector2(ground[0], ground[1])
	if _nearby_moving.is_valid():
		against = _nearby_moving.call(state.x, state.y, state.time)
	var relative_x: float = state.velocity_x - against.x
	var relative_y: float = state.velocity_y - against.y
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	flight_data_changed.emit({
		"altitude": _gravity_model.get_altitude(state.x, state.y, state.time) - _rest_height,
		"speed": sqrt(relative_x * relative_x + relative_y * relative_y),
		"against_station": _nearby_moving.is_valid(),
		"docked": docked,
		"landed": state.is_on_surface(),
		"periapsis": apsides[0],
		"apoapsis": apsides[1],
		"time": state.time,
		"heading": heading,
		"prograde": atan2(relative_x, -relative_y),
		# Sitting still, the speed is only rounding noise, so that direction means nothing.
		"moving": not state.is_on_surface() and relative_x * relative_x + relative_y * relative_y >= 0.25,
		"spin": angular_velocity,
		"fuel_share": fuel / body.original_fuel_capacity,
		"rcs_share": rcs_fuel / design.rcs_capacity if design.rcs_capacity > 0.0 else 0.0,
		"delta_v": delta_v(),
	})


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	# Whole pixels only, so the icon doesn't shimmer as it crawls across the grid.
	position = Vector2(
			(state.x - center_x) * pixels_per_unit,
			(state.y - center_y) * pixels_per_unit).round()
	_show_sprite = pixels_per_unit > icon_max_zoom
	_sprite_scale = minf(pixels_per_unit, 1.0)
	_sprite.scale = Vector2.ONE * _sprite_scale
	_flame.scale = Vector2.ONE * _sprite_scale
	_place_art()
	var show_dot: bool = pixels_per_unit < dot_max_zoom
	if show_dot != _show_dot:
		_show_dot = show_dot
		queue_redraw()
	_sprite.visible = _show_sprite
	for part: Sprite2D in _part_sprites:
		part.visible = _show_sprite
	_icon.visible = not _show_sprite and not show_dot


# The art hangs off the ship's real center, which moves on the art as damage shifts it.
func _place_art() -> void:
	var offset: Vector2 = (_sink - _pivot) * _sprite_scale
	if _jolt_ticks > 0:
		var fading: float = float(_jolt_ticks) / JOLT_TICKS
		offset += Vector2(sin(_jolt_ticks * 2.1), cos(_jolt_ticks * 1.3)) * _jolt_size * fading * _sprite_scale
	_sprite.position = offset
	for i in range(_part_sprites.size()):
		_part_sprites[i].position = offset + body.layer_center(i + 1) * _sprite_scale
		_part_sprites[i].scale = Vector2(_sprite_scale, _sprite_scale * body.layer_fold(i + 1))
	if _legs_out > 0.0:
		queue_redraw()
	_puffs.position = offset
	_glow.position = offset
	for i in range(body.layer_count()):
		_glow.place_layer(i, body.layer_center(i), body.layer_fold(i), _sprite_scale)
	_flame.position = _flame_at * _sprite_scale + offset


func _draw() -> void:
	# The struts holding the legs out, behind everything else. They have no pixels of their own.
	if _show_sprite and _legs_out > 0.0:
		var palette: AgencyPalette = UiStyle.palette()
		var offset: Vector2 = (_sink - _pivot) * _sprite_scale
		var thickness: float = maxf(roundf(2.0 * _sprite_scale), 1.0)
		for strut: Array in body.part_struts(module_dead_share):
			var from: Vector2 = offset + strut[0] * _sprite_scale
			var to: Vector2 = offset + strut[1] * _sprite_scale
			draw_line(from, to, palette.hull_darkest, thickness + 2.0)
			draw_line(from, to, palette.hull_light, thickness)
	if _show_dot:
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), UiStyle.palette().hull_darkest)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), UiStyle.palette().hull_lightest)
