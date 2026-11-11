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
## The station on rails around the planet.
@export var station: StationDesign
## How high above the surface the ship starts, in a circular orbit.
@export var start_altitude: float = 30000.0
## Places built on worlds.
@export var sites: Array[SiteData] = [preload("res://data/launch_base.tres"), preload("res://data/moon_base.tres")]

## The agency: gig boards, the gig taken, and credits.
var agency: Agency
var _site_views: Array = []


func _ready() -> void:
	var gravity_model := PatchedConicsModel.new()
	gravity_model.set_central_body(star.get_mu(), star.radius, star.landing_line_altitude)
	var planet_index: int = _add_body(gravity_model, 0, planet)
	var moon_index: int = _add_body(gravity_model, planet_index, moon)
	var body_indices: Dictionary = {planet: planet_index, moon: moon_index}
	# Level ground for each site before anything reads the terrain.
	var site_heights: Array[float] = []
	for site: SiteData in sites:
		var half_columns: int = ceili(site.half_width / SiteView.WORLD_PIXEL)
		var blend_columns: int = ceili(site.blend / SiteView.WORLD_PIXEL)
		site_heights.append(gravity_model.add_flat_ground(body_indices[site.world], site.column - half_columns, site.column + half_columns, blend_columns))
	var station_index: int = gravity_model.add_satellite(planet_index, planet.radius + station.orbit_altitude,
			station.orbit_eccentricity, station.orbit_argument_of_periapsis, station.orbit_start_angle)

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
	$Background/Planet.show_body(planet_index, planet, gravity_model, state, star)
	$Background/Moon.show_body(moon_index, moon, gravity_model, state, star)
	$Camera2D.start_view(gravity_model, state, {"kind": "body", "index": planet_index})
	$Background/BodyGuides.start_guides(gravity_model, state)
	$Trajectory.start_preview(gravity_model, state)
	$Station.start_station(gravity_model, state, station, station_index, $Ship)
	$Hud/SafeArea/TargetMarkers.start_markers(gravity_model, state)
	var catalog := WorldCatalog.new(gravity_model, state, $Ship, planet.surface_gravity)
	catalog.add_body(0, star)
	catalog.add_body(planet_index, planet)
	catalog.add_body(moon_index, moon)
	catalog.add_station(station_index, station, $Station.reach(), $Station.layout.free_ports.size())
	var station_thing: Dictionary = {"kind": "satellite", "index": station_index}
	$Hud/SafeArea/TargetMarkers.set_target(station_thing, station.callsign, $Station.reach(), $Camera2D.point_getter(station_thing))
	$Sparks.start_sparks(gravity_model, state)
	$Debris.start_debris(gravity_model, state, $Ship, $Sparks)
	var bodies: Dictionary = {planet_index: planet, moon_index: moon}
	$SurfaceProps.start_props(gravity_model, state, bodies)
	for i in range(sites.size()):
		_start_site(gravity_model, state, sites[i], body_indices[sites[i].world], site_heights[i], catalog)
	$GroundEffects.start_effects(gravity_model, state, $Ship, $Sparks, bodies)
	$TurnGuide.ship = $Ship
	$Pilot.start_pilot(gravity_model, $Ship, $Station)
	$Camera2D.set_pilot($Pilot)
	catalog.set_pilot($Pilot)
	$Hud/SafeArea/FlightHud.connect_flight($Ship, $Camera2D, $TurnGuide, catalog, $Hud/SafeArea/TargetMarkers, $Hud/SafeArea/CommsLine, $Pilot)
	agency = Agency.new()
	add_child(agency)
	agency.start(gravity_model, $Ship, $Pilot, $Station, station, station_index, _site_views, {planet_index: planet, moon_index: moon})
	var warp := TimeWarp.new()
	add_child(warp)
	warp.start(gravity_model, $Ship, $Pilot)
	$Hud/SafeArea/FlightHud.connect_warp(warp)
	$Hud/SafeArea/FlightHud.connect_agency(agency)
	agency.message_raised.connect($Hud/SafeArea/CommsLine.on_agency_message)
	var sound := SoundDirector.new()
	add_child(sound)
	sound.start($Hud/SafeArea/FlightHud, $Hud/SafeArea/CommsLine, $Ship, $Pilot)
	warp.message_raised.connect($Hud/SafeArea/CommsLine._on_ship_warning_raised)
	_start_landing_forecast()
	$Ship.start_flight(gravity_model, state, PI / 2.0)


# The ship forecasts its own landing. The path line draws where that is, a label at the line's end
# says what it means, and the comms line's idea of a hard landing is what the ship goes by.
func _start_landing_forecast() -> void:
	$Ship.hard_touchdown_speed = $Hud/SafeArea/CommsLine.hard_touchdown_speed
	$Ship.landing_predicted.connect($Trajectory._on_ship_landing_predicted)
	var label := LandingLabel.new()
	$Hud/SafeArea.add_child(label)
	# Under the panels, with the target markers.
	$Hud/SafeArea.move_child(label, $Hud/SafeArea/TargetMarkers.get_index())
	label.start_label($Trajectory.landing_point)
	$Ship.landing_predicted.connect(label._on_ship_landing_predicted)
	$Camera2D.view_rolled.connect(label._on_view_rolled)
	$Camera2D.view_changed.connect(label._on_view_changed)


# A site draws behind the station, ship, and pilot, and in front of the ground.
func _start_site(gravity_model: GravityModel, state: ShipState, site: SiteData, world: int, level_height: float, catalog: WorldCatalog) -> void:
	var view := SiteView.new()
	_site_views.append(view)
	add_child(view)
	move_child(view, $Station.get_index())
	view.start_site(gravity_model, state, site, world, level_height, $Ship)
	$Camera2D.view_changed.connect(view._on_view_changed)
	$Camera2D.view_rolled.connect(view._on_view_rolled)
	$Camera2D.add_site(view)
	$Pilot.add_site(view)
	catalog.add_site(view)
	var half_columns: int = ceili((site.half_width + site.blend) / SiteView.WORLD_PIXEL)
	$SurfaceProps.clear_columns(world, site.column - half_columns, site.column + half_columns)


func _add_body(gravity_model: PatchedConicsModel, parent: int, body: BodyData) -> int:
	var index: int = gravity_model.add_body(parent, body.get_mu(), body.radius,
			body.orbit_semi_major_axis, body.orbit_eccentricity, body.orbit_argument_of_periapsis,
			body.orbit_start_angle, body.landing_line_altitude)
	gravity_model.set_body_spin(index, body.spin_rate)
	gravity_model.set_body_atmosphere(index, body.air_density, body.air_scale_height)
	gravity_model.set_body_terrain(index, body.terrain_seed, body.terrain_mountains, body.terrain_hills,
			body.terrain_rough, body.terrain_rocks, body.terrain_crater_depth, body.terrain_crater_share,
			body.terrain_cliff_step, body.sea_level, body.radius * 0.6, body.terrain_ridge_height)
	return index
