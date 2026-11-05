# main.gd: sets up a flight and hands each system what it needs.
# From DESIGN.md, "Physics" and "Scope ladder" (Tier 0). This is the only place that
# knows which gravity model is running; everything else uses the GravityModel interface.
extends Node2D

## The planet at the world origin.
@export var planet: BodyData
## The moon on rails around it.
@export var moon: BodyData
## How high above the surface the ship starts, in a circular orbit.
@export var start_altitude: float = 30000.0


func _ready() -> void:
	var gravity_model := PatchedConicsModel.new()
	gravity_model.set_central_body(planet.get_mu(), planet.radius, planet.landing_line_altitude)
	gravity_model.add_moon(moon.get_mu(), moon.radius, moon.orbit_semi_major_axis,
			moon.orbit_eccentricity, moon.orbit_argument_of_periapsis, moon.orbit_start_angle,
			moon.landing_line_altitude)

	var start_radius: float = planet.radius + start_altitude
	var state := ShipState.new()
	state.y = -start_radius
	state.velocity_x = sqrt(planet.get_mu() / start_radius)

	$Background/Planet.show_body(0, planet, gravity_model, state)
	$Background/Moon.show_body(1, moon, gravity_model, state)
	$Camera2D.start_view(gravity_model, state)
	$Background/BodyGuides.start_guides(gravity_model, state)
	$Trajectory.start_preview(gravity_model, state)
	$Ship.start_flight(gravity_model, state, PI / 2.0)
