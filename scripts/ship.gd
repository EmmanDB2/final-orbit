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
# at turn_acceleration. Thrust is the throttle setting while BURN is held.
#
# The RCS can also translate, moving the ship in any of four directions without turning
# it, for docking and precise landings. ASS doesn't cancel this, and it's too weak to lift
# off from anything.
#
# Fuel has mass. Burning it makes the ship lighter and quicker, and the main engine and
# RCS both stop when it runs out. Landing on the planet refills it until stations exist.
#
# On the ground the ship settles upright and the turn keys do nothing, so thrust always
# lifts it straight off.
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

## Emitted every physics tick with the ship's real position in the world.
signal world_position_changed(x: float, y: float)
## Emitted when the flight mode changes: true for ASS, false for RAW.
signal assist_changed(enabled: bool)
## Emitted when the ship's path has changed, from a burn or from touching a surface.
signal orbit_changed
## Emitted when STAB is switched on or off.
signal stab_changed(enabled: bool)
## Emitted when the ship reaches the ground, with its speed relative to the ground and
## whether its nose was pointing away from the surface.
signal touched_down(speed: float, upright: bool)
## Emitted when the ship leaves the ground.
signal lifted_off
## Emitted when a piece breaks off, with where it is, how it's moving, how it's turned, and
## the push it gets from the hit, in world units per second.
signal part_detached(piece: Dictionary, x: float, y: float, velocity_x: float, velocity_y: float, angle: float, spin: float, kick: Vector2)
## Emitted when pixels are destroyed, with where they were relative to the ship in the world.
signal pixels_scattered(offsets: PackedVector2Array, colors: PackedColorArray, x: float, y: float, velocity_x: float, velocity_y: float, kick: Vector2)
## Emitted with a short warning for the pilot, such as a module going down.
signal warning_raised(text: String)
## Emitted when the cockpit is lost, and the ship with it.
signal ship_lost
## Emitted when the ship can or can't fly any more, from damage or an empty tank.
signal stranded_changed(stranded: bool)
## Emitted several times a second with what the instruments show: altitude, speed,
## periapsis, apoapsis, time, heading, prograde, and spin.
signal flight_data_changed(data: Dictionary)

## What this ship is built from. Thrust and turning come from its engines and its mass.
@export var design: ShipDesign
## How many times per second the engine flame changes frame.
@export var flame_fps: float = 15.0
## True starts the ship in ASS, false in RAW.
@export var assist_enabled: bool = true
## Below this zoom the ship is drawn as a dot.
@export var dot_max_zoom: float = 0.0001
## The icon shows at this zoom and farther, and the sprite at anything closer.
@export var icon_max_zoom: float = 1.0 / 800.0
## A module with less than this share of its pixels left stops working.
@export var module_dead_share: float = 0.5
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
## Fuel aboard, in kilograms.
var fuel: float = 0.0
## Main engine acceleration right now, in world units per second squared.
var thrust_acceleration: float = 0.0
## How quickly the RCS changes the spin right now, in radians per second squared.
var turn_acceleration: float = 0.0
## RCS translation acceleration right now, in world units per second squared.
var translate_acceleration: float = 0.0
## How fast the nose is turning, in radians per second.
var angular_velocity: float = 0.0
## How much of the engine's thrust BURN uses, from 0 to 1.
var throttle: float = 1.0
var stab_enabled: bool = false
## Where the ship really is and how it's moving.
var state: ShipState

var _gravity_model: GravityModel
var _thrusting: bool = false
var _was_on_surface: bool = false
## How hot the air is making the ship, where 1.0 is the top of the scale.
var heat_share: float = 0.0
## How hot the hull has got, on the same scale. Past 1.0 it burns.
var hull_temperature: float = 0.0

var _show_sprite: bool = true
var _sprite_scale: float = 1.0
var _flame_position: Vector2 = Vector2.ZERO
var _show_dot: bool = false
var _point_active: bool = false
var _point_heading: float = 0.0
var _stab_needs_pick: bool = true
var _stab_direction: int = 0
var _flame_time: float = 0.0
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
var _texture: ImageTexture
var _heat_heading: float = 0.0
var _translate_forward: float = 0.0
var _translate_right: float = 0.0

@onready var _flame: Sprite2D = $Flame
@onready var _puffs: RcsPuffs = $RcsPuffs
@onready var _glow: ReentryGlow = $ReentryGlow
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	_flame_position = _flame.position
	body = ShipBody.measure(design)
	_whole_center = body.center_of_mass
	_texture = ImageTexture.create_from_image(body.image)
	_sprite.texture = _texture
	_rest_height = body.reach(_pivot, Vector2.DOWN)
	fuel = body.fuel_capacity
	_update_performance()
	_puffs.set_nozzles(design)
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
	if Input.is_action_just_pressed("toggle_assist"):
		assist_enabled = not assist_enabled
		assist_changed.emit(assist_enabled)
	if Input.is_action_just_pressed("toggle_stab"):
		stab_enabled = not stab_enabled
		_stab_needs_pick = true
		stab_changed.emit(stab_enabled)

	_spin_firing = 0.0
	if state.is_on_surface():
		angular_velocity = 0.0
		if not _lost:
			heading = rotate_toward(heading, _local_up_heading(), settle_speed * delta)
	else:
		var spin_before: float = angular_velocity
		var turn_input: float = Input.get_axis("turn_left", "turn_right")
		if fuel <= 0.0 or _lost:
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
		_burn_fuel(design.rcs_fuel_rate * firing * delta)
		_spin_firing = signf(angular_velocity - spin_before) * firing
		heading += angular_velocity * delta
	rotation = heading

	_thrusting = Input.is_action_pressed("thrust") and throttle > 0.0 and fuel > 0.0 and _engine_share > 0.0 and not _lost
	if _thrusting:
		state.velocity_x += sin(heading) * thrust_acceleration * throttle * delta
		state.velocity_y -= cos(heading) * thrust_acceleration * throttle * delta
		# Thrust off to one side of the center of mass spins the ship.
		var thrust_force: float = design.engine_force * _engine_share * throttle
		angular_velocity -= (_thrust_x - _pivot.x) * thrust_force / _spin_resistance_now * delta
		_burn_fuel(thrust_force / design.exhaust_velocity * delta)
	var translate_forward: float = _usable_forward(Input.get_axis("translate_back", "translate_forward"))
	var translate_right: float = _usable_right(Input.get_axis("translate_left", "translate_right"))
	var translating: bool = fuel > 0.0 and not _lost and (translate_forward != 0.0 or translate_right != 0.0)
	_translate_forward = translate_forward if translating else 0.0
	_translate_right = translate_right if translating else 0.0
	if translating:
		var along: float = translate_forward * translate_acceleration * delta
		var across: float = translate_right * translate_acceleration * delta
		state.velocity_x += sin(heading) * along + cos(heading) * across
		state.velocity_y += -cos(heading) * along + sin(heading) * across
		_burn_fuel(design.rcs_fuel_rate * (absf(translate_forward) + absf(translate_right)) * delta)

	var venting: bool = _leak_fuel(delta)
	var in_air: bool = _push_through_air(delta)
	_heat_hull(delta)

	state.ground_clearance = body.reach(_pivot, _local_down())
	_gravity_model.propagate(state, delta)

	var on_surface: bool = state.is_on_surface()
	if _thrusting or translating or venting or in_air or on_surface != _was_on_surface:
		orbit_changed.emit()
	if on_surface and not _was_on_surface:
		var tilt: float = absf(angle_difference(heading, _local_up_heading()))
		touched_down.emit(state.get_touchdown_speed(), tilt <= upright_tolerance)
		var landed_on: int = _gravity_model.get_dominant_body(state.x, state.y, state.time)
		_hit_ground(state.get_touchdown_speed(), landed_on)
		if _gravity_model.get_body_parent(landed_on) == 0 and not _lost:
			_refill_sound_tanks()
	elif _was_on_surface and not on_surface:
		lifted_off.emit()
	_was_on_surface = on_surface
	_check_stranded()

	world_position_changed.emit(state.x, state.y)

	if Engine.get_physics_frames() % telemetry_interval_ticks == 0:
		_report_telemetry()


# Runs once per rendered frame. Cosmetic only, so it doesn't touch the flight.
func _process(delta: float) -> void:
	_flame_time += delta
	_flame.frame = floori(_flame_time * flame_fps) % _flame.hframes
	_flame.visible = _thrusting and _show_sprite
	# Small corrections while holding steady don't show, so the nozzles don't flicker.
	var turning_clockwise: bool = _spin_firing > 0.2
	var turning_back: bool = _spin_firing < -0.2
	_glow.visible = _show_sprite
	_glow.rotation = _heat_heading - heading
	_glow.set_heat(heat_share, _sprite_scale)
	_puffs.visible = _show_sprite
	_puffs.set_leaks(_leak_points())
	_puffs.set_firing(
			turning_clockwise or _translate_right > 0.0,
			turning_back or _translate_right < 0.0,
			_translate_forward > 0.0,
			_translate_forward < 0.0,
			_sprite_scale)
	_icon.frame = 1 if _thrusting else 0


func _burn_fuel(amount: float) -> void:
	if amount > 0.0:
		fuel = maxf(fuel - amount, 0.0)
		_update_performance()


# Air pushes back against the ship's motion through it, and it moves with the planet, so
# this measures against the moving air. Side-on, the ship catches more of it. Returns
# whether there was any air to push through.
func _push_through_air(delta: float) -> bool:
	heat_share = 0.0
	if state.is_on_surface():
		return false
	var density: float = _gravity_model.get_air_density(state.x, state.y, state.time)
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
	var mass_now: float = body.mass + fuel
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
	_update_performance()


func _on_star_heat_changed(share: float) -> void:
	_star_heat = share


# The hull warms toward whatever's heating it, and past the top of the scale it burns away
# from the hot side, whichever that is.
func _heat_hull(delta: float) -> void:
	var heat: float = heat_share + _star_heat
	hull_temperature += (heat - hull_temperature) * minf(delta / design.hull_heat_seconds, 1.0)
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
	_take_damage(erased, -hot_side * 30.0)


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


# The ground takes all the ship's energy above the safe speed, since it's far heavier. The
# star takes everything, whatever the speed.
func _hit_ground(speed: float, landed_on: int) -> void:
	var energy: float = 0.5 * _mass_now * maxf(speed * speed - design.safe_impact_speed * design.safe_impact_speed, 0.0)
	if landed_on == 0:
		energy = INF
	if energy <= 0.0:
		return
	var up: Vector2 = Vector2.UP.rotated(_local_up_heading())
	_take_damage(body.crush(_local_down(), energy, int(state.time * 1000.0)), up * minf(speed * 0.25, 120.0))


## Puts every pixel back, as a station's repair bay will.
func repair() -> void:
	var moved: Vector2 = (-_pivot).rotated(heading)
	state.x += moved.x
	state.y += moved.y
	_pivot = Vector2.ZERO
	body = ShipBody.measure(design)
	_lost = false
	_warned_modules.clear()
	_update_for_damage()


## True if there's a pixel of the ship at this offset from it in the world.
func has_pixel_at(world_offset: Vector2) -> bool:
	return body.has_pixel(world_offset.rotated(-heading) + _pivot)


## The ship's whole mass right now, fuel included.
func current_mass() -> float:
	return _mass_now


## Something has hit the ship at this offset from it in the world, with this much energy.
func take_hit(world_offset: Vector2, energy: float) -> void:
	var erased: Dictionary = body.dent(world_offset.rotated(-heading) + _pivot, energy, int(state.time * 1000.0))
	_take_damage(erased, world_offset.normalized() * 40.0)


# Sends off what a hit destroyed and broke loose, then updates everything damage changes.
func _take_damage(erased: Dictionary, kick: Vector2) -> void:
	if erased["points"].is_empty():
		return
	var offsets := PackedVector2Array()
	for point: Vector2 in erased["points"]:
		offsets.append(_art_to_world(point))
	pixels_scattered.emit(offsets, erased["colors"], state.x, state.y, state.velocity_x, state.velocity_y, kick)
	for piece: Dictionary in body.split_off():
		var at: Vector2 = _art_to_world(piece["center"])
		part_detached.emit(piece, state.x + at.x, state.y + at.y, state.velocity_x, state.velocity_y, heading, angular_velocity, kick)
	_update_for_damage()


func _update_for_damage() -> void:
	_texture.update(body.image)

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
	for i in range(body.modules.size()):
		var module: ModuleData = body.modules[i]
		var share: float = body.module_share(i)
		var works: bool = share >= module_dead_share
		var on_left: bool = module.cell.x + 0.5 < columns_middle
		match module.kind:
			"engine":
				engine_count += 1
				if works:
					engine_total += share
					engine_sideways += share * (module.cell.x + 0.5 - columns_middle) * design.cell_size
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
	_tail_share = _engine_share
	_thrust_x = engine_sideways / engine_total if engine_total > 0.0 else 0.0
	_update_performance()

	_rest_height = body.reach(_pivot, Vector2.DOWN)
	state.ground_clearance = body.reach(_pivot, _local_down())
	if state.is_on_surface():
		_rest_on_ground()

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
	var wanted: float = _gravity_model.get_body_radius(dominant) + state.ground_clearance
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
	_mass_now = now["mass"]
	_spin_resistance_now = now["spin_resistance"]
	thrust_acceleration = design.engine_force * _engine_share / now["mass"]
	turn_acceleration = design.rcs_torque / now["spin_resistance"]
	translate_acceleration = design.rcs_translate_force / now["mass"]


## How much more speed the fuel aboard can give, from the rocket equation.
func delta_v() -> float:
	return design.exhaust_velocity * log((body.mass + fuel) / body.mass)


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
	var relative_x: float = state.velocity_x - ground[0]
	var relative_y: float = state.velocity_y - ground[1]
	var apsides: PackedFloat64Array = _gravity_model.get_orbit_apsides(state)
	flight_data_changed.emit({
		"altitude": _gravity_model.get_altitude(state.x, state.y, state.time) - _rest_height,
		"speed": sqrt(relative_x * relative_x + relative_y * relative_y),
		"periapsis": apsides[0],
		"apoapsis": apsides[1],
		"time": state.time,
		"heading": heading,
		"prograde": atan2(relative_x, -relative_y),
		"spin": angular_velocity,
		"fuel_share": fuel / body.original_fuel_capacity,
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
	_icon.visible = not _show_sprite and not show_dot


# The art hangs off the ship's real center, which moves on the art as damage shifts it.
func _place_art() -> void:
	var offset: Vector2 = -_pivot * _sprite_scale
	_sprite.position = offset
	_puffs.position = offset
	_glow.position = offset
	_flame.position = _flame_position * _sprite_scale + offset


func _draw() -> void:
	if _show_dot:
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), UiStyle.palette().hull_darkest)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), UiStyle.palette().hull_lightest)
