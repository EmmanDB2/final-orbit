# main.gd: sets up a flight and hands each system what it needs, opens the title screen over it, and
# starts keeping it once the player goes in.
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

## Which world's save this flight keeps: "normal", or "zen" in Zen Mode.
var save_slot: String = "normal"
## Zen Mode's music.
@export var music: MusicSet = preload("res://data/music_set.tres")
## What the station charges for fuel and repairs.
@export var service_prices: ServicePrices = preload("res://data/service_prices.tres")
## The ships the station's hangar has to fly.
@export var ship_list: ShipList = preload("res://data/ship_list.tres")

## The agency: gig boards, the gig taken, and credits.
var agency: Agency
var _site_views: Array = []
var _saves: SaveGame
var _saved: Dictionary = {}
var _catalog: WorldCatalog
var _title: TitleScreen
# Zen Mode: no gigs or pay, fuel and gas that never run out, and ambient music.
var _zen: bool = false
var _music: MusicPlayer
var _hangar: Hangar


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
	# A saved flight picks up where it was, before anything starts reading where the ship is. Behind the
	# title's NEW FLIGHT, it's the fresh start instead.
	var opening: bool = TitleScreen.opening and TitleScreen.allowed()
	_zen = opening and TitleScreen.world == "zen"
	save_slot = "zen" if _zen else "normal"
	# CONTINUE is the normal world's save, whichever world is behind the title.
	var has_save: bool = SaveGame.enabled() and FileAccess.file_exists(SaveGame.path_of("normal"))
	if opening and not has_save and TitleScreen.world == "continue":
		TitleScreen.world = "new"
	var fresh: bool = opening and TitleScreen.world == "new"
	var saved: Dictionary = {} if fresh else SaveGame.read(save_slot)
	var saved_ship: Dictionary = saved.get("flight", {}).get("ship", {})
	if not saved_ship.is_empty():
		state.x = saved_ship["x"]
		state.y = saved_ship["y"]
		state.velocity_x = saved_ship["velocity_x"]
		state.velocity_y = saved_ship["velocity_y"]
		state.time = saved_ship["time"]
	var home: int = gravity_model.get_dominant_body(state.x, state.y, state.time)

	$Background/Starfield.start_stars(gravity_model, state)
	$Background/Star.show_star(star)
	$Background/Planet.show_body(planet_index, planet, gravity_model, state, star)
	$Background/Moon.show_body(moon_index, moon, gravity_model, state, star)
	$Camera2D.start_view(gravity_model, state, {"kind": "body", "index": home if home > 0 else planet_index})
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
	if _zen:
		_start_zen()
	else:
		$Hud/SafeArea/FlightHud.connect_agency(agency)
	var services := ShipServices.new($Ship, agency, service_prices)
	services.free = _zen
	_hangar = Hangar.new(ship_list)
	services.hangar = _hangar
	# A traded ship's hatch sits somewhere else, so the station takes it onto the port again.
	services.redock = func() -> void: $Station.restore_state({"docked_port": $Station.docked_port})
	$Hud/SafeArea/FlightHud.connect_services(services)
	agency.message_raised.connect($Hud/SafeArea/CommsLine.on_agency_message)
	warp.message_raised.connect($Hud/SafeArea/CommsLine._on_ship_warning_raised)
	_start_landing_forecast()
	$Ship.start_flight(gravity_model, state, saved_ship.get("heading", PI / 2.0))
	if not saved.is_empty():
		_restore(saved, catalog)
	# Sound starts after the save's put back, so loading doesn't clunk or crunch.
	var sound := SoundDirector.new()
	add_child(sound)
	sound.start($Hud/SafeArea/FlightHud, $Hud/SafeArea/CommsLine, $Ship, $Pilot)
	_saved = saved
	_catalog = catalog
	$Hud/SafeArea/FlightHud.title_requested.connect(_to_title)
	if opening:
		_open_title(home, has_save)
	else:
		_begin()


# Starts keeping the world: it saves from here on. In Zen Mode the music starts too.
func _begin() -> void:
	_saves = SaveGame.new()
	_saves.slot = save_slot
	_saves.hangar = _hangar
	_saves.keep_lost_ship = not _zen
	add_child(_saves)
	_saves.start($Ship, $Pilot, agency, _catalog, $Station, _saved)
	if _zen:
		_music.play(music, music.zen_tracks)


# Zen Mode's rules: the ship's fuel and the pilot's jetpack never run out, repairs are free, and with no
# gigs the gig terminals have nothing to offer, which the comms line says.
func _start_zen() -> void:
	$Ship.endless_fuel = true
	$Pilot.endless_gas = true
	$Pilot.terminal_used.connect(func(place: Dictionary) -> void:
		if place.get("kind", "") != "service":
			$Hud/SafeArea/CommsLine.on_agency_message("NO GIGS IN ZEN MODE", true))
	_music = MusicPlayer.new()
	add_child(_music)


# The title screen over the world, which it frames and freezes. The HUD stays hidden and deaf until
# the player goes in.
func _open_title(home: int, has_save: bool) -> void:
	$Hud.visible = false
	$Hud/SafeArea/FlightHud.process_mode = Node.PROCESS_MODE_DISABLED
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_title = TitleScreen.new()
	_title.info = _title_info(home, has_save)
	layer.add_child(_title)
	$ScreenFit.screen_fitted.connect(_title._on_screen_fitted)
	$ScreenFit.refit()
	_title.entered.connect(_on_title_entered)
	_title.world_wanted.connect(_on_title_world_wanted)
	_title.start($Camera2D, home)


# What the title says about the world behind it: where the ship is, the credits, and the clock.
func _title_info(home: int, has_save: bool) -> Dictionary:
	var ship: Node2D = $Ship
	var where: String = "%s · IN FLIGHT" % _catalog.callsign_of({"kind": "body", "index": home}).to_upper()
	if ship.docked:
		where = "%s · DOCKED" % station.callsign
	elif ship.state.is_on_surface():
		where = "%s · LANDED" % _catalog.callsign_of({"kind": "body", "index": home}).to_upper()
		for i in range(_site_views.size()):
			if agency.ship_at({"kind": "site", "index": i}):
				where = "%s · LANDED" % _catalog.callsign_of({"kind": "site", "index": i})
	var lost: bool = ship._lost
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var comms: String = "COMMS: ALL SYSTEMS NOMINAL"
	if _zen:
		comms = "COMMS: ZEN MODE · NO GIGS, NO LIMITS"
	elif TitleScreen.world == "new":
		comms = "COMMS: READY FOR A NEW FLIGHT"
	elif lost:
		comms = "COMMS: SHIP LOST"
	return {
		"has_save": has_save,
		"where": where,
		"credits": agency.credits,
		"lost": lost,
		"time": ship.state.time,
		"comms": comms,
		"comms_red": lost and TitleScreen.world == "continue",
		"version": "v" + version if version != "" else "v0.1",
	}


# Into the world behind the title. A new flight replaces the save. The view eases into the ship, the
# world starts, and the HUD comes in once the view's close.
func _on_title_entered(item: String) -> void:
	if item == "NEW FLIGHT":
		SaveGame.erase(save_slot)
	TitleScreen.selected_item = ""
	get_tree().paused = false
	$Camera2D.release_title_frame()
	$Hud/SafeArea/FlightHud.process_mode = Node.PROCESS_MODE_ALWAYS
	_title.get_parent().queue_free()
	_title = null
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		$Hud.visible = true
		$Hud/SafeArea/FlightHud.arrive())
	if _zen:
		$Hud/SafeArea/CommsLine.on_agency_message("ZEN MODE: NO GIGS, NO LIMITS", true)
	_begin()


# Another world behind the title: the game loads again with it, arriving from far out.
func _on_title_world_wanted(next: String) -> void:
	TitleScreen.world = next
	TitleScreen.arriving = true
	get_tree().paused = false
	get_tree().reload_current_scene()


# Puts a saved world back: the flight as it was when the pilot was last aboard, then the agency's
# credits and gig, and the worlds visited.
func _restore(saved: Dictionary, catalog: WorldCatalog) -> void:
	var flight: Dictionary = saved.get("flight", {})
	_hangar.restore_state(saved.get("hangar", {}))
	if flight.has("ship"):
		# Flying another ship from the hangar: it becomes that one first.
		var design_path: String = flight["ship"].get("design", "")
		if design_path != "" and design_path != $Ship.design.resource_path and ResourceLoader.exists(design_path):
			$Ship.change_design(load(design_path))
		$Ship.restore_state(flight["ship"])
		$Station.restore_state(flight.get("station", {}))
		$Hud/SafeArea/FlightHud.show_throttle($Ship.throttle)
	agency.restore_state(saved.get("agency", {}))
	catalog.restore_state(saved.get("worlds", {}))


# TITLE: saves, and goes back to the title screen over this flight, Zen or not.
func _to_title() -> void:
	if _saves != null:
		_saves.save_now()
		_saves.stop()
	TitleScreen.opening = true
	TitleScreen.world = "zen" if _zen else "continue"
	TitleScreen.selected_item = "ZEN MODE" if _zen else "CONTINUE"
	TitleScreen.arriving = false
	get_tree().paused = false
	get_tree().reload_current_scene()


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
