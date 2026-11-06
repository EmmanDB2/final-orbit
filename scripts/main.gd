# main.gd: sets up a flight and hands each system what it needs.
# From DESIGN.md, "Physics" and "Scope ladder". This is the only place that knows which
# gravity model is running; everything else uses the GravityModel interface.
extends Node2D

## The star at the world origin.
@export var star: StarData
## The planet on rails around the star.
@export var planet: BodyData
## The moon on rails around the planet.
@export var moon: BodyData
## How high above the surface the ship starts, in a circular orbit.
@export var start_altitude: float = 30000.0


func _ready() -> void:
	var gravity_model := PatchedConicsModel.new()
	gravity_model.set_central_body(star.get_mu(), star.radius, star.landing_line_altitude)
	var planet_index: int = _add_body(gravity_model, 0, planet)
	var moon_index: int = _add_body(gravity_model, planet_index, moon)

	var planet_at: PackedFloat64Array = gravity_model.get_body_position(planet_index, 0.0)
	var planet_velocity: PackedFloat64Array = gravity_model.get_body_velocity(planet_index, 0.0)
	var start_radius: float = planet.radius + start_altitude
	var state := ShipState.new()
	state.x = planet_at[0]
	state.y = planet_at[1] - start_radius
	state.velocity_x = planet_velocity[0] + sqrt(planet.get_mu() / start_radius)
	state.velocity_y = planet_velocity[1]

	$Background/Starfield.start_stars(gravity_model, state)
	$Background/Star.show_star(star)
	$Background/Planet.show_body(planet_index, planet, gravity_model, state)
	$Background/Moon.show_body(moon_index, moon, gravity_model, state)
	$Camera2D.start_view(gravity_model, state)
	$Background/BodyGuides.start_guides(gravity_model, state)
	$Trajectory.start_preview(gravity_model, state)
	$Sparks.start_sparks(gravity_model, state)
	$Debris.start_debris(gravity_model, state, $Ship, $Sparks)
	$TurnGuide.ship = $Ship
	$Hud/SafeArea/FlightHud.connect_flight($Ship, $Camera2D, $TurnGuide)
	$Ship.start_flight(gravity_model, state, PI / 2.0)


func _add_body(gravity_model: PatchedConicsModel, parent: int, body: BodyData) -> int:
	var index: int = gravity_model.add_body(parent, body.get_mu(), body.radius,
			body.orbit_semi_major_axis, body.orbit_eccentricity, body.orbit_argument_of_periapsis,
			body.orbit_start_angle, body.landing_line_altitude)
	gravity_model.set_body_spin(index, body.spin_rate)
	gravity_model.set_body_atmosphere(index, body.air_density, body.air_scale_height)
	return index
