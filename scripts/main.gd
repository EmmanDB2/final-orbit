# main.gd: sets up a flight and hands each system what it needs.
# From DESIGN.md, "Physics" and "Scope ladder" (Tier 0). This is the only place that
# knows which gravity model is running; everything else uses the GravityModel interface.
extends Node2D

## The planet at the world origin.
@export var planet: BodyData
## How high above the surface the ship starts, in a circular orbit.
@export var start_altitude: float = 30000.0


func _ready() -> void:
	var gravity_model := PatchedConicsModel.new()
	gravity_model.set_central_body(planet.get_mu(), planet.radius)

	var start_radius: float = planet.radius + start_altitude
	var state := ShipState.new()
	state.y = -start_radius
	state.velocity_x = sqrt(planet.get_mu() / start_radius)

	$Background/Planet.set_body(planet)
	$Trajectory.start_preview(gravity_model, state)
	$Ship.start_flight(gravity_model, state, PI / 2.0)
