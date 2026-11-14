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
# In air, from "Aerodynamics" in DESIGN.md, the air pushes on every part of the outline that faces
# into it. That slows the ship, lifts it sideways when it's tilted, and turns it toward whichever
# way its shape and mass trim. Deep and fast, the air turns it harder than the RCS can, and STAB,
# ASS, and drag to point lose until it slows down. The pushing and the RCS's rules are worked out
# in the physics core's AeroBody, which the landing prediction shares.
#
# A few times a second, while it's on its way down, the ship asks for a forecast of how it comes
# down with no more burns, from "Landing prediction" in DESIGN.md. That's flown ahead on another
# thread, and comes back as landing_predicted with where it lands and whether that's SAFE, HARD, a
# CRASH, or a BURN-UP.
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
## The legs' shock absorbers are damped springs this damped, short of stopping without bouncing, so
## they settle with barely a wobble. A spring this damped peaks at this share of how far it would go
## undamped, which sets how stiff each leg is so a landing at its soak speed just bottoms it out from
## its sag.
const SQUASH_DAMPING: float = 0.7
const SQUASH_PEAK: float = 0.458
## Which way a rise in the ground under the feet leans the ship onto its left legs.
const LEVEL_SIGN: float = 1.0
## How hard a bump has to be to be heard, as a share of the safe impact speed.
const BUMP_SHARE: float = 0.1

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
## Emitted when something hits the ship: how hard, as a share of the speed it can take without harm
## (so above 1 hurts), and how many pixels it destroyed. A gentle bump destroys none.
signal hull_struck(strength: float, damage: int)
## Emitted when the cockpit is lost, and the ship with it.
signal ship_lost
## Emitted when the ship becomes another, at the station's hangar.
signal design_changed(design: ShipDesign)
## Emitted when the ship can or can't fly any more, from damage or an empty tank.
## Emitted when the ship docks at a station or leaves it.
signal docked_changed(is_docked: bool)
signal stranded_changed(stranded: bool)
## Emitted several times a second with what the instruments show: altitude, speed,
## periapsis, apoapsis, time, heading, prograde, and spin.
signal flight_data_changed(data: Dictionary)
## Emitted with each new forecast of how the ship comes down with no more burns: what
## GravityModel.predict_descent gives, plus a "verdict" of SAFE, HARD, CRASH, or BURN-UP if it
## lands. Empty when it isn't on its way down any more.
signal landing_predicted(prediction: Dictionary)

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
## How long the air has to out-turn an RCS that's trying to hold before the pilot's told, and how
## long the RCS has to hold again before they'd be told a second time, in seconds.
@export var overpower_warning_seconds: float = 0.2
@export var overpower_calm_seconds: float = 4.0
## How long to leave between forecasts of the landing, in real seconds, and how far ahead and in
## how many points each one is flown.
@export var prediction_seconds: float = 0.25
@export var prediction_horizon: float = 21600.0
@export var prediction_samples: int = 256
## Top speed for a hard landing rather than a crash, in world units per second. The comms line
## decides it, and main.gd hands it over.
@export var hard_touchdown_speed: float = 250.0

## Direction of the nose in radians. 0 points up the screen; positive turns clockwise.
var heading: float = 0.0
## The ship's mass, center of mass, and spin resistance, measured from its pixels.
var body: ShipBody
## Engine fuel aboard, in kilograms.
var fuel: float = 0.0
## RCS propellant aboard, in kilograms, in its own tank. Turning and translating use it.
var rcs_fuel: float = 0.0
## Cargo aboard, in kilograms, for a gig. It's mass like anything else.
var cargo_kg: float = 0.0
## Someone rescued, riding in the cockpit, in kilograms.
var passenger_kg: float = 0.0
## How much of the star the ship can see, from 0 in a world's shadow to 1, for lighting its hull.
var sunlight: float = 1.0
## Zen Mode: burning and turning use no fuel or RCS propellant. Holed tanks still lose what's in them.
var endless_fuel: bool = false
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
var _event_moving: Callable
var _event_what: String = ""
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
# The ship as the air sees it: its outline in short pieces, rebuilt when the shape changes.
var _aero := AeroBody.new()
var _aero_stale: bool = true
# The way the side taking the heat faces, on the art.
var _hot_side: Vector2 = Vector2.UP
var _overpowered_seconds: float = 0.0
var _calm_seconds: float = 0.0
var _overpower_warned: bool = false
# The ship's center of mass as it is now, on the art.
var _center_now: Vector2 = Vector2.ZERO
var _prediction := LandingPrediction.new()
var _prediction_started: int = -100000
# The latest forecast of the landing, or empty.
var _landing: Dictionary = {}
# Which bodies have air, as they're asked about.
var _has_air: Dictionary = {}
var _translate_forward: float = 0.0
# Each module's drawn box on the art, for pointing at parts of the ship.
var _module_boxes: Array[Rect2] = []
# The landing legs: each its "layer" and "module", whether it's on the "left", and its shock absorber's
# "squash" in pixels and "speed".
var _legs: Array[Dictionary] = []
# How wide the ship stands, legs down and up, from its middle, in pixels.
var _stance_down: float = 62.0
var _stance_up: float = 18.0
# On uneven ground, how much more the left legs squeeze than the right ones, to sit nearer level.
var _leg_level: float = 0.0
var _translate_right: float = 0.0

@onready var _flame: EngineFlame = $Flame
@onready var _puffs: RcsPuffs = $RcsPuffs
@onready var _glow: ReentryGlow = $ReentryGlow
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	_build()
	# Nothing flies until start_flight hands over gravity and a starting state.
	set_physics_process(false)
	assist_changed.emit(assist_enabled)


# Builds the ship from its design: its pixels measured, its art, its flame, puffs, and heat glow, and
# full tanks.
func _build() -> void:
	for part: Sprite2D in _part_sprites:
		part.queue_free()
	_part_sprites.clear()
	_module_boxes.clear()
	_flame.setup(design.flame_length)
	body = ShipBody.measure(design)
	_whole_center = body.center_of_mass
	_legs.clear()
	for pair: Array in body.legs():
		_legs.append({"layer": pair[0], "module": pair[1], "left": body.layer_center(pair[0]).x < 0.0, "squash": 0.0, "speed": 0.0})
	body.set_parts_out(1.0)
	_stance_down = body.stance_half_width()
	body.set_parts_out(0.0)
	_stance_up = body.stance_half_width()
	body.set_parts_out(_legs_out)
	_wave = DamageWave.new(body)
	_sprite.texture = _wave.textures[0]
	# Lit by the star, shaded from its own outline as it's built.
	_sprite.material = HullLight.material_for(body.layer_image(0))
	_glow.setup(_wave.textures)
	for i in range(1, body.layer_count()):
		var part := Sprite2D.new()
		part.texture = _wave.textures[i]
		part.material = HullLight.material_for(body.layer_image(i))
		add_child(part)
		move_child(part, _sprite.get_index())
		_part_sprites.append(part)
	_rest_height = body.reach(_pivot, Vector2.DOWN)
	fuel = body.fuel_capacity
	rcs_fuel = design.rcs_capacity
	for i in range(body.modules.size()):
		_module_boxes.append(body.module_art_rect(i))
	_aero.pressure_coefficient = design.air_pressure_coefficient
	_aero_stale = true
	_update_performance()
	_puffs.set_nozzles(body)
	_aim_flame()


## Becomes another ship, as at the station's hangar: built new from its design, in the same place,
## whole, with full tanks, its legs stowed, and the cargo still aboard. The hangar puts back how it
## was left if it's been flown before.
func change_design(new_design: ShipDesign) -> void:
	design = new_design
	_pivot = Vector2.ZERO
	_sink = Vector2.ZERO
	_jolt_ticks = 0
	_lost = false
	_warned_modules.clear()
	legs_down = false
	_legs_out = 0.0
	_legs_moving = false
	_build()
	_update_for_damage()
	state.ground_clearance = _rest_height
	legs_changed.emit(false, false)
	design_changed.emit(design)
	orbit_changed.emit()


## What the hangar keeps of a ship while another's flown: its damage and its tanks.
func hangar_state() -> Dictionary:
	var tanks: Array[float] = []
	for tank: Dictionary in body.tanks:
		tanks.append(tank["capacity"])
	return {"damage": body.damage_depths(), "warned": _warned_modules.keys(), "tanks": tanks, "fuel": fuel, "rcs_fuel": rcs_fuel}


## Puts back how a ship was left in the hangar.
func apply_hangar_state(saved: Dictionary) -> void:
	_put_back_damage(saved)
	_put_back_tanks(saved)
	_update_performance()
	_place_art()
	orbit_changed.emit()


# Damage from a save or the hangar: modules already reported down aren't reported again.
func _put_back_damage(saved: Dictionary) -> void:
	for module_index: int in saved["warned"]:
		_warned_modules[module_index] = true
	body.restore_damage(saved["damage"])
	_update_for_damage()


# Tanks from a save or the hangar: what holes have cost them, and what's in them.
func _put_back_tanks(saved: Dictionary) -> void:
	var tanks: Array = saved["tanks"]
	if tanks.size() == body.tanks.size():
		body.fuel_capacity = 0.0
		for i in range(tanks.size()):
			body.tanks[i]["capacity"] = tanks[i]
			body.fuel_capacity += tanks[i]
	fuel = minf(saved["fuel"], body.fuel_capacity)
	rcs_fuel = saved["rcs_fuel"]


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
	heat_share = 0.0
	_air_density = _gravity_model.get_air_density(state.x, state.y, state.time)
	var in_air: bool = false
	if state.is_on_surface():
		angular_velocity = 0.0
		if not _lost:
			heading = rotate_toward(heading, _local_up_heading() - _rest_angle + _ground_lean, settle_speed * delta)
	else:
		in_air = _turn_and_meet_air(delta)
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
	if not FeatureFlags.AERODYNAMICS:
		in_air = _push_through_air(delta)
	_heat_hull(delta)

	_move_legs(delta)
	_spring_legs(delta)
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
		_kick_legs(state.get_touchdown_speed())
		var landed_on: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
		_hit_ground(state.get_touchdown_speed(), landed_on)
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
	_forecast_landing()

	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report_telemetry()


func _exit_tree() -> void:
	_prediction.finish()


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
	_forecast_landing()
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
		"cargo_kg": cargo_kg,
		"cargo_capacity": design.cargo_capacity,
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
## where the ship is: [x, y, velocity x, velocity y, heading, spin]. Refuelling and repairs are the
## station's services, and cost credits.
func dock(holder: Callable) -> void:
	docked = true
	_dock_holder = holder
	_switch_engine(false)
	hull_temperature = 0.0
	heat_share = 0.0
	_update_performance()
	docked_changed.emit(true)
	orbit_changed.emit()


## Pumps fuel and RCS propellant in, as much as the tanks that are left will hold.
func refuel(fuel_kg: float, rcs_kg: float) -> void:
	fuel = minf(fuel + fuel_kg, body.fuel_capacity)
	rcs_fuel = minf(rcs_fuel + rcs_kg, design.rcs_capacity)
	_update_performance()
	_check_stranded()
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


## The same for something else close by that isn't a station, such as an astronaut adrift: a way to
## ask how it's moving, as [x, y] velocity, and what to call it, or an empty one for nothing.
func set_event_moving(moving: Callable, what: String = "") -> void:
	_event_moving = moving
	_event_what = what


# Runs once per rendered frame. Cosmetic only, so it doesn't touch the flight.
func _process(delta: float) -> void:
	_light_hull()
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


# The hull's lit from the star, which sits at the world's middle.
func _light_hull() -> void:
	if _gravity_model != null:
		sunlight = Sunlight.at(_gravity_model, state.x, state.y, state.time)
	var toward: Vector2 = -Vector2(state.x, state.y).normalized()
	HullLight.aim(_sprite, toward, sunlight)
	for part: Sprite2D in _part_sprites:
		HullLight.aim(part, toward, sunlight)


func _switch_engine(on: bool) -> void:
	if on != engine_on:
		engine_on = on
		engine_switched.emit(on)


func _burn_fuel(amount: float) -> void:
	if amount > 0.0 and not endless_fuel:
		fuel = maxf(fuel - amount, 0.0)
		_update_performance()


func _burn_rcs(amount: float) -> void:
	if amount > 0.0 and not endless_fuel:
		rcs_fuel = maxf(rcs_fuel - amount, 0.0)
		_update_performance()


# Turns the ship for one tick. The RCS does what it's asked: the turn keys, drag to point, STAB, or
# ASS, strongest first. In air, the air pushes on every part of the outline that faces into it,
# measured against the air, which moves with the planet. That slows the ship, lifts it, and turns
# it, and it's where the heat comes from. Returns whether there was any air.
func _turn_and_meet_air(delta: float) -> bool:
	var control: int = AeroBody.CONTROL_NONE
	var control_value: float = 0.0
	var turn_input: float = Input.get_axis("turn_left", "turn_right") if pilot_aboard else 0.0
	if rcs_fuel <= 0.0 or _lost or TimeWarp.on_rails():
		pass
	elif turn_input != 0.0:
		control = AeroBody.CONTROL_TURN
		control_value = turn_input
		_stab_needs_pick = true
	elif _point_active:
		control = AeroBody.CONTROL_STEER
		control_value = _point_heading
		_stab_needs_pick = true
	elif stab_enabled:
		control = AeroBody.CONTROL_STEER
		control_value = _stab_heading()
	elif assist_enabled:
		# Same thrusters as manual turning, so the same strength.
		control = AeroBody.CONTROL_DAMP

	var density: float = _air_density if FeatureFlags.AERODYNAMICS else 0.0
	var through_x: float = 0.0
	var through_y: float = 0.0
	if density > 0.0:
		if _aero_stale:
			_aero_stale = false
			_aero.set_outline(body.outline_polygons_now(), design.air_segment_length)
		var air: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
		through_x = state.velocity_x - air[0]
		through_y = state.velocity_y - air[1]

	var flown: PackedFloat64Array = _aero.step(delta, density, through_x, through_y, heading, angular_velocity, control, control_value)
	state.velocity_x += flown[AeroBody.STEP_VELOCITY_X]
	state.velocity_y += flown[AeroBody.STEP_VELOCITY_Y]
	heading = flown[AeroBody.STEP_HEADING]
	angular_velocity = flown[AeroBody.STEP_SPIN]
	_spin_firing = flown[AeroBody.STEP_RCS_FIRING]
	_burn_rcs(design.rcs_fuel_rate * flown[AeroBody.STEP_RCS_USE] * delta)
	_note_overpowered(flown[AeroBody.STEP_OVERPOWERED], delta)
	if density <= 0.0:
		return false

	# Heating grows with the cube of speed, so a steep, fast entry is far worse. It's taken from the
	# part of the outline that meets the air hardest, and the hot side is whichever side that is.
	heat_share = flown[AeroBody.STEP_HEAT] / design.heat_limit
	if through_x * through_x + through_y * through_y > 0.000001:
		_heat_heading = atan2(through_x, -through_y)
	var hot := Vector2(flown[AeroBody.STEP_HOT_X], flown[AeroBody.STEP_HOT_Y])
	if hot != Vector2.ZERO:
		_hot_side = hot
	return true


# Tells the pilot once when the air is turning the ship harder than an RCS that's trying to hold
# it, and not again until the RCS has held for a while.
func _note_overpowered(seconds: float, delta: float) -> void:
	if seconds > 0.0:
		_calm_seconds = 0.0
		_overpowered_seconds += seconds
		if _overpowered_seconds >= overpower_warning_seconds and not _overpower_warned:
			_overpower_warned = true
			warning_raised.emit("AIR OVERPOWERING RCS")
		return
	_calm_seconds += delta
	if _calm_seconds >= overpower_calm_seconds:
		_overpowered_seconds = 0.0
		_overpower_warned = false


# The old drag, kept behind FeatureFlags.AERODYNAMICS to compare with: one box as wide and long as
# the ship, slowed by how much of it faces the air, and never turned by it. Returns whether there
# was any air to push through.
func _push_through_air(delta: float) -> bool:
	var density: float = _air_density
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
	var mass_now: float = body.mass + fuel + rcs_fuel + cargo_kg + passenger_kg
	var slowing: float = 0.5 * density * speed * speed * design.drag_coefficient * catching / mass_now
	var change: float = minf(slowing * delta, speed)
	state.velocity_x -= through_x / speed * change
	state.velocity_y -= through_y / speed * change

	heat_share = sqrt(density) * speed * speed * speed / design.heat_limit
	_heat_heading = atan2(through_x, -through_y)
	_hot_side = Vector2.UP.rotated(_heat_heading - heading)
	return true


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

	var hot_side: Vector2 = _hot_side.rotated(heading)
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
		hot_way = _hot_side
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
# How hard a landing can be and do no damage: what the hull takes, and with the legs fully down, each
# working leg's share of what the legs soak up. Losing a leg lowers it.
func _safe_impact_speed() -> float:
	var hull: float = design.safe_impact_speed
	if _legs_out < 1.0 or _legs.is_empty():
		return hull
	var soaked: float = 0.0
	for leg: Dictionary in _legs:
		if body.working_share(leg["module"]) >= module_dead_share:
			var module: ModuleData = body.modules[leg["module"]]
			soaked += module.soak_speed * module.soak_speed / _legs.size()
	return sqrt(hull * hull + soaked)


# How far to each side of its middle the ship stands on the ground: its feet with the legs down, or
# its engine bell.
func _stance() -> float:
	return _stance_down if legs_down else _stance_up


# Whether ground that rises this much across the ship's stance is too steep to stand on: its center
# of mass would be outside its feet.
func _too_steep(rise: float) -> bool:
	var stance: float = _stance()
	var center_height: float = maxf(body.reach(_center_now, Vector2.DOWN), 1.0)
	return absf(rise) / (stance * 2.0) > stance / center_height


# Keeps a forecast of the landing coming while the ship's on its way down: takes one that's
# finished, and starts the next. It's worked out on another thread, so this never waits.
func _forecast_landing() -> void:
	var answer: Dictionary = _prediction.take()
	var coming_down: bool = _is_coming_down()
	if not coming_down:
		if not _landing.is_empty():
			_landing = {}
			landing_predicted.emit(_landing)
		return
	if not answer.is_empty():
		answer["verdict"] = _verdict_of(answer) if answer["lands"] else ""
		_landing = answer
		landing_predicted.emit(answer)
	if _prediction.is_busy() or Time.get_ticks_msec() - _prediction_started < prediction_seconds * 1000.0:
		return
	_prediction_started = Time.get_ticks_msec()
	_prediction.start(_gravity_model, _state_copy(), _aero_copy(), _flight_now(), prediction_horizon, prediction_samples)


# Whether the ship's coast takes it into air or onto the ground.
func _is_coming_down() -> bool:
	if docked or _lost or state.is_on_surface():
		return false
	if _air_density > 0.0:
		return true
	var dominant: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	var reaches: float = _gravity_model.get_highest_ground(dominant) + state.ground_clearance
	if _body_has_air(dominant):
		reaches = maxf(reaches, _gravity_model.get_entry_altitude(dominant))
	if apsides[0] >= reaches:
		return false
	# On a path that never comes back, it only comes down if it hasn't passed its low point yet.
	if apsides[1] < 0.0:
		var at: PackedFloat64Array = _gravity_model.get_body_position(dominant, state.time)
		var moving: PackedFloat64Array = _gravity_model.get_body_velocity(dominant, state.time)
		return (state.x - at[0]) * (state.velocity_x - moving[0]) + (state.y - at[1]) * (state.velocity_y - moving[1]) < 0.0
	return true


func _body_has_air(index: int) -> bool:
	if not _has_air.has(index):
		var at: PackedFloat64Array = _gravity_model.get_body_position(index, state.time)
		_has_air[index] = _gravity_model.get_air_density(at[0], at[1] - _gravity_model.get_body_radius(index) - 1.0, state.time) > 0.0
	return _has_air[index]


# The ship's state and outline as they are now, for a forecast to fly without anything changing
# under it.
func _state_copy() -> ShipState:
	var copy := ShipState.new()
	copy.x = state.x
	copy.y = state.y
	copy.velocity_x = state.velocity_x
	copy.velocity_y = state.velocity_y
	copy.time = state.time
	copy.ground_clearance = state.ground_clearance
	return copy


func _aero_copy() -> AeroBody:
	if _aero_stale:
		_aero_stale = false
		_aero.set_outline(body.outline_polygons_now(), design.air_segment_length)
	return _aero.snapshot()


# How the ship's set up to fly from here with hands off: STAB and ASS as they're switched now, no
# turn keys, and no drag to point.
func _flight_now() -> Dictionary:
	var control: int = AeroBody.CONTROL_NONE
	var hold: int = _stab_direction
	if rcs_fuel > 0.0:
		if stab_enabled:
			control = AeroBody.CONTROL_STEER
			if _stab_needs_pick:
				hold = _closest_direction(_stab_directions())
		elif assist_enabled:
			control = AeroBody.CONTROL_DAMP
	return {
		"heading": heading,
		"spin": angular_velocity,
		"control": control,
		"hold": hold,
		"rcs_fuel": rcs_fuel,
		"rcs_fuel_rate": design.rcs_fuel_rate,
		"heat_limit": design.heat_limit,
		"hull_heat_seconds": design.hull_heat_seconds,
		"hull_temperature": hull_temperature,
		"star_heat": _star_heat,
		"stance_columns": maxi(roundi(_stance() / WORLD_PIXEL), 1),
	}


# What touching down the way a forecast says would mean, for the ship as it is.
func _verdict_of(prediction: Dictionary) -> String:
	if prediction["peak_hull"] > 1.0:
		return "BURN-UP"
	var speed: float = prediction["speed"]
	if speed <= _safe_impact_speed() and not _too_steep(prediction["rise"]):
		return "SAFE"
	if speed <= hard_touchdown_speed:
		return "HARD"
	return "CRASH"


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


# The legs' shock absorbers, each a damped spring. A touchdown squeezes them, and they spring back to sag
# under the ship's weight, each to the ground under its own foot, as far as its stroke goes. In the air
# they stretch out again. A leg moving, or broken, doesn't spring.
func _spring_legs(delta: float) -> void:
	if _legs.is_empty():
		return
	var standing: bool = state.is_on_surface() and _legs_out >= 1.0 and not _lost
	var weight_share: float = clampf(_mass_now / (body.mass + body.original_fuel_capacity + design.rcs_capacity), 0.0, 1.2)
	var targets: Dictionary = _leg_targets(weight_share) if standing else {}
	var changed: bool = false
	for leg: Dictionary in _legs:
		var module: ModuleData = body.modules[leg["module"]]
		var working: bool = body.working_share(leg["module"]) >= module_dead_share
		var squash: float = leg["squash"]
		if _legs_out < 1.0 or not working:
			squash = 0.0
			leg["speed"] = 0.0
		else:
			var target: float = targets.get("left" if leg["left"] else "right", 0.0)
			var room: float = maxf(module.stroke * (1.0 - module.sag_share), 0.5)
			var omega: float = module.soak_speed * SQUASH_PEAK / room
			leg["speed"] += (omega * omega * (target - squash) - 2.0 * SQUASH_DAMPING * omega * leg["speed"]) * delta
			squash += leg["speed"] * delta
			if squash >= module.stroke:
				squash = module.stroke
				leg["speed"] = minf(leg["speed"], 0.0)
			elif squash <= 0.0:
				squash = 0.0
				leg["speed"] = maxf(leg["speed"], 0.0)
		if absf(squash - leg["squash"]) > 0.001:
			changed = true
		leg["squash"] = squash
	if changed:
		for leg: Dictionary in _legs:
			body.set_squash(leg["layer"], leg["squash"])
		body.size_changed()
		_rest_height = body.reach(_pivot, Vector2.DOWN)
		_aero_stale = true
		_place_art()


# Where the left and right legs settle standing: sagging under the weight, the side on higher ground
# squeezed more and the other less, and when one side reaches an end of its stroke, the other takes up
# the rest.
func _leg_targets(weight_share: float) -> Dictionary:
	var stroke: float = INF
	var sag: float = 0.0
	for leg: Dictionary in _legs:
		var module: ModuleData = body.modules[leg["module"]]
		stroke = minf(stroke, module.stroke)
		sag = maxf(sag, module.sag_share * module.stroke * weight_share)
	sag = minf(sag, stroke)
	var left: float = sag + _leg_level / 2.0
	var right: float = sag - _leg_level / 2.0
	if right < 0.0:
		left -= right
		right = 0.0
	if left < 0.0:
		right -= left
		left = 0.0
	if left > stroke:
		right -= left - stroke
		left = stroke
	if right > stroke:
		left -= right - stroke
		right = stroke
	return {"left": clampf(left, 0.0, stroke), "right": clampf(right, 0.0, stroke)}


# A touchdown squeezes every leg that's fully down and working, as fast as the ship hit.
func _kick_legs(speed: float) -> void:
	if _legs_out < 1.0:
		return
	for leg: Dictionary in _legs:
		if body.working_share(leg["module"]) >= module_dead_share:
			leg["speed"] = maxf(leg["speed"], speed)


## How far each leg's shock absorber is squeezed now, in pixels.
func leg_squashes() -> Array[float]:
	var squashes: Array[float] = []
	for leg: Dictionary in _legs:
		squashes.append(leg["squash"])
	return squashes


func _move_legs(delta: float) -> void:
	if not _legs_moving:
		return
	_legs_out = move_toward(_legs_out, 1.0 if legs_down else 0.0, delta / design.legs_seconds)
	body.set_parts_out(_legs_out)
	_aero_stale = true
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
	_leg_level = 0.0
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

	var stance: int = mini(roundi(_stance() / WORLD_PIXEL), GROUND_CHECK_COLUMNS)
	var left: float = strip[(GROUND_CHECK_COLUMNS - stance) * 2]
	var right: float = strip[(GROUND_CHECK_COLUMNS + stance) * 2]
	var rise: float = left - right
	# Legs down, each leg's shock absorber takes up what it can of the difference, so the ship sits
	# nearer level than the ground under its feet.
	if legs_down and _legs_out >= 1.0 and not _legs.is_empty():
		var stroke: float = INF
		for leg: Dictionary in _legs:
			stroke = minf(stroke, body.modules[leg["module"]].stroke)
		_leg_level = clampf(rise * LEVEL_SIGN, -stroke, stroke)
		rise -= _leg_level * LEVEL_SIGN
	_ground_lean = clampf(atan2(rise, stance * 2.0 * WORLD_PIXEL), -most_ground_lean, most_ground_lean)


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
	var damage: int = _take_damage(body.crush(down, energy, int(state.time * 1000.0)), up * minf(speed * 0.4, 200.0), touching, clampf(speed * 0.7, 60.0, 320.0))
	# Touching down is heard already; only a landing that breaks something is a hit.
	if damage > 0:
		hull_struck.emit(speed / maxf(safe, 1.0), damage)


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
		# A bump: heard, but too gentle to hurt. Barely touching is silent.
		if into > safe * BUMP_SHARE:
			hull_struck.emit(into / safe, 0)
		return
	var energy: float = 0.5 * _mass_now * (into * into - safe * safe)
	var inward: Vector2 = (-normal).rotated(-heading)
	var touching: Vector2 = contact.rotated(-heading) + _pivot
	warning_raised.emit("%s COLLISION" % what)
	var damage: int = _take_damage(body.crush(inward, energy, int(state.time * 1000.0)), normal * minf(into * 0.4, 200.0), touching, clampf(into * 0.7, 60.0, 320.0))
	hull_struck.emit(into / safe, damage)


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


## Everything a save needs to put the ship back as it is: where it is and how it's moving, its
## damage, its tanks, and its switches. Cargo goes with the gig it belongs to.
func save_state() -> Dictionary:
	var tanks: Array[float] = []
	for tank: Dictionary in body.tanks:
		tanks.append(tank["capacity"])
	return {
		"design": design.resource_path,
		"x": state.x,
		"y": state.y,
		"velocity_x": state.velocity_x,
		"velocity_y": state.velocity_y,
		"time": state.time,
		"on_surface": state.is_on_surface(),
		"heading": heading,
		"spin": angular_velocity,
		"damage": body.damage_depths(),
		"warned": _warned_modules.keys(),
		"tanks": tanks,
		"fuel": fuel,
		"rcs_fuel": rcs_fuel,
		"hull_temperature": hull_temperature,
		"throttle": throttle,
		"engine_on": engine_on,
		"assist": assist_enabled,
		"stab": stab_enabled,
		"legs_down": legs_down,
		"legs_out": _legs_out,
	}


## Puts the ship back as a save had it, once it's flying. A ship that was lost stays lost. Being
## docked is the station's to put back.
func restore_state(saved: Dictionary) -> void:
	heading = saved["heading"]
	rotation = heading
	angular_velocity = saved["spin"]
	legs_down = saved["legs_down"]
	_legs_out = saved["legs_out"]
	_legs_moving = false
	body.set_parts_out(_legs_out)
	_put_back_damage(saved)
	# Damage moves the ship's center, so where it is comes after, just as it was saved.
	state.x = saved["x"]
	state.y = saved["y"]
	state.velocity_x = saved["velocity_x"]
	state.velocity_y = saved["velocity_y"]
	state.time = saved["time"]
	_sink = Vector2.ZERO
	_put_back_tanks(saved)
	hull_temperature = saved["hull_temperature"]
	throttle = saved["throttle"]
	_rest_height = body.reach(_pivot, Vector2.DOWN)
	_rest_angle = body.rest_angle()
	state.ground_clearance = _rest_height
	# Landed, it's on the ground again without touching down a second time.
	_was_on_surface = saved["on_surface"]
	if _was_on_surface:
		_gravity_model.propagate(state, 0.0)
		_touch_terrain()
	assist_enabled = saved["assist"]
	assist_changed.emit(assist_enabled)
	stab_enabled = saved["stab"]
	_stab_needs_pick = true
	stab_changed.emit(stab_enabled)
	legs_changed.emit(legs_down, false)
	_switch_engine(saved["engine_on"])
	_aero_stale = true
	_update_performance()
	_place_art()
	orbit_changed.emit()


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
	var damage: int = _take_damage(erased, world_offset.normalized() * 40.0, point, clampf(sqrt(energy / 500000.0) * 6.0, 40.0, 200.0))
	# Above the safe speed by however much the energy says.
	var safe: float = design.safe_impact_speed
	hull_struck.emit(sqrt(1.0 + 2.0 * energy / (_mass_now * safe * safe)), damage)


# Starts showing what a hit destroyed, sends off what broke loose, and updates everything
# damage changes. The pieces fly away from where the hit landed. Returns how many pixels it destroyed.
func _take_damage(erased: Dictionary, kick: Vector2, hit_point: Vector2, blast: float) -> int:
	if erased["points"].is_empty():
		return 0
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
	return erased["points"].size()


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
	_aero_stale = true
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
	_mass_now = now["mass"] + rcs_fuel + cargo_kg + passenger_kg
	_spin_resistance_now = now["spin_resistance"]
	thrust_acceleration = design.engine_force * _engine_share / _mass_now
	turn_acceleration = design.rcs_torque / now["spin_resistance"]
	translate_acceleration = design.rcs_translate_force / _mass_now
	# The air turns the ship around its center of mass as it is now, which moves as the tanks drain.
	_center_now = now["center_of_mass"]
	_aero.set_mass(_mass_now, _spin_resistance_now, _center_now)
	_aero.set_rcs(turn_acceleration, _rcs_left, _rcs_right)


## How much more speed the fuel aboard can give, from the rocket equation.
func delta_v() -> float:
	return delta_v_with(0.0)


## The same with this much more cargo aboard, in kilograms, for checking a gig before taking it.
func delta_v_with(extra_kg: float) -> float:
	var dry: float = body.mass + rcs_fuel + cargo_kg + passenger_kg + extra_kg
	return design.exhaust_velocity * log((dry + fuel) / dry)


## How much more cargo fits, in kilograms.
func cargo_room() -> float:
	return maxf(design.cargo_capacity - cargo_kg, 0.0)


## Takes cargo aboard, in kilograms.
func load_cargo(kg: float) -> void:
	cargo_kg += kg
	_update_performance()
	orbit_changed.emit()


## Takes someone aboard, or off with a negative mass, in kilograms. They ride in the cockpit and weigh
## like cargo, but aren't cargo: unloading a gig's cargo leaves them be.
func carry_passenger(kg: float) -> void:
	passenger_kg = maxf(passenger_kg + kg, 0.0)
	_update_performance()
	orbit_changed.emit()


## Takes all the cargo off, and says how much there was.
func unload_cargo() -> float:
	var had: float = cargo_kg
	cargo_kg = 0.0
	_update_performance()
	orbit_changed.emit()
	return had


## The cockpit's box in the world, for pointing at it: its four corners as x, y pairs, turning
## with the ship. Empty if the cockpit's gone.
func cockpit_corners() -> PackedFloat64Array:
	return _corners_of("cockpit")


## The whole ship's box in the world, the same way, for keeping things from covering it.
func hull_corners() -> PackedFloat64Array:
	return _corners_of("")


# The box round what's left of the modules of one kind, or of all of them, as world corners.
func _corners_of(kind: String) -> PackedFloat64Array:
	var box := Rect2()
	var found: bool = false
	for i in range(body.modules.size()):
		if (kind == "" or body.modules[i].kind == kind) and body.module_share(i) > 0.0:
			box = _module_boxes[i] if not found else box.merge(_module_boxes[i])
			found = true
	var corners := PackedFloat64Array()
	if not found:
		return corners
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var offset: Vector2 = _art_to_world(corner)
		corners.append(state.x + offset.x)
		corners.append(state.y + offset.y)
	return corners


## How hard the RCS thrusters are firing right now, from 0 to 1, turning or translating, for sound.
func rcs_activity() -> float:
	return clampf(maxf(absf(_spin_firing), maxf(absf(_translate_forward), absf(_translate_right))), 0.0, 1.0)


## How thick the air around the ship is, where 1 is the home planet's ground and 0 is none.
func air_density() -> float:
	return _air_density


## Whether drag to point is turning the ship.
func is_pointing() -> bool:
	return _point_active


## Whether a station's close enough that speeds read against it.
func near_station() -> bool:
	return _nearby_moving.is_valid()


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


# The heading of each direction STAB can hold, in the order of _stab_direction. The physics core
# works them out, so the landing prediction holds the same ones.
func _stab_directions() -> PackedFloat64Array:
	return _gravity_model.get_hold_headings(state.x, state.y, state.velocity_x, state.velocity_y, state.time)


func _stab_heading() -> float:
	var directions: PackedFloat64Array = _stab_directions()
	if _stab_needs_pick:
		_stab_needs_pick = false
		_stab_direction = _closest_direction(directions)
	return directions[_stab_direction]


# Whichever of those the nose is nearest.
func _closest_direction(directions: PackedFloat64Array) -> int:
	var nearest: int = 0
	var closest: float = INF
	for i in range(directions.size()):
		var gap: float = absf(angle_difference(heading, directions[i]))
		if gap < closest:
			closest = gap
			nearest = i
	return nearest


# The heading that points the nose straight away from the body below.
func _local_up_heading() -> float:
	var body: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
	var body_position: PackedFloat64Array = _gravity_model.get_body_position(body, state.time)
	return atan2(state.x - body_position[0], body_position[1] - state.y)


func _report_telemetry() -> void:
	var ground: PackedFloat64Array = _gravity_model.get_surface_velocity(state.x, state.y, state.time)
	var against: Vector2 = Vector2(ground[0], ground[1])
	var close_to: String = ""
	if _nearby_moving.is_valid():
		against = _nearby_moving.call(state.x, state.y, state.time)
		close_to = "STATION"
	elif _event_moving.is_valid():
		var moving: PackedFloat64Array = _event_moving.call()
		against = Vector2(moving[0], moving[1])
		close_to = _event_what
	var relative_x: float = state.velocity_x - against.x
	var relative_y: float = state.velocity_y - against.y
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	flight_data_changed.emit({
		"altitude": _gravity_model.get_altitude(state.x, state.y, state.time) - _rest_height,
		"speed": sqrt(relative_x * relative_x + relative_y * relative_y),
		"against_station": close_to != "",
		# What speeds are read against, when it isn't the ground: STATION, or an event such as SURVIVOR.
		"close_to": close_to,
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
		# What the forecast says of the landing, if it's coming down: SAFE, HARD, CRASH, or BURN-UP.
		"landing": _landing.get("verdict", ""),
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
