# save_game.gd: keeps a world between sessions, in one file per world. While the pilot's aboard it
# saves the flight (where the ship is, its damage, tanks, and switches) every few seconds, whenever
# something big happens, and whenever the app goes to the background. Out of the ship, the flight
# holds still at the moment they stepped out. Credits, gigs, and the worlds visited save the moment
# they change, wherever the pilot is. Every save has a version, and an older one is upgraded as it's
# read, never wiped. From DESIGN.md, "Saving and the title screen" and "Tech" (versioned saves).
class_name SaveGame
extends Node

## This version of the save. Raise it when what's saved changes, and add a step to _upgrade.
const VERSION: int = 4
## Where saves live. A test points this somewhere of its own and turns saving on for itself.
static var folder: String = "user://saves"
static var on_in_tests: bool = false
## How often it saves while flying, in real seconds.
const EVERY_SECONDS: float = 10.0

## Which world this is: "normal", or "zen".
var slot: String = "normal"
## Whether a lost ship is kept. Zen Mode lets it go, so the next Zen flight starts fresh.
var keep_lost_ship: bool = true
## The station's hangar, with the ships left there.
var hangar: Hangar
## The mid-flight events that have come up.
var events: EventDirector
# A death not yet got over: what killed them, how badly, and the bill once it's been charged. Saved at
# once, so closing the app can't undo it.
var _death: Dictionary = {}

var _ship: Node2D
var _pilot: Pilot
var _agency: Agency
var _catalog: WorldCatalog
var _station: Node2D
# The flight as it was the last time the pilot was aboard.
var _flight: Dictionary = {}
var _was_aboard: bool = true
var _wait: float = EVERY_SECONDS
var _soon: bool = false
var _stopped: bool = false


## Whether saving's on. It's off while a test runs the game, so tests never touch a player's save.
static func enabled() -> bool:
	return on_in_tests or (Engine.get_main_loop() != null and Engine.get_main_loop().get_script() == null)


static func path_of(world: String) -> String:
	return "%s/%s.save" % [folder, world]


## A world's save, upgraded to this version, or empty if there's none to read.
static func read(world: String) -> Dictionary:
	if not enabled() or not FileAccess.file_exists(path_of(world)):
		return {}
	var file := FileAccess.open(path_of(world), FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if not data is Dictionary or not data.has("version"):
		push_warning("The %s save can't be read." % world)
		return {}
	return _upgrade(data)


## Throws a world's save away, for a new flight.
static func erase(world: String) -> void:
	if FileAccess.file_exists(path_of(world)):
		DirAccess.remove_absolute(path_of(world))


# Brings an older save up to this version, one version at a time.
static func _upgrade(data: Dictionary) -> Dictionary:
	while data["version"] < VERSION:
		match data["version"]:
			1:
				# Version 2 added mid-flight events. An older world has had none.
				data["events"] = {}
			2:
				# Version 3 holds up to three gigs. An older world has at most one, the active one.
				var agency: Dictionary = data.get("agency", {})
				var active: Dictionary = agency.get("active", {})
				agency["gigs"] = [active] if not active.is_empty() else []
				agency["focus"] = active["id"] if not active.is_empty() else -1
				agency.erase("active")
				data["agency"] = agency
			3:
				# Version 4 saves the docked port by name. An old number stays a number in the save, and the
				# station turns it into a port by its design's legacy_ports when the ship's put back.
				pass
		data["version"] += 1
	return data


func _ready() -> void:
	# It saves while the flight's paused too, when the app goes to the background.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Starts keeping the world, from the save it was loaded from, if any.
func start(ship: Node2D, pilot: Pilot, agency: Agency, catalog: WorldCatalog, station: Node2D, loaded: Dictionary) -> void:
	_ship = ship
	_pilot = pilot
	_agency = agency
	_catalog = catalog
	_station = station
	_flight = loaded.get("flight", {})
	agency.credits_changed.connect(func(_credits: int) -> void: _soon = true)
	agency.gig_changed.connect(func(_gig: Gig) -> void: _soon = true)
	pilot.mode_changed.connect(_on_pilot_mode_changed)
	ship.docked_changed.connect(func(_docked: bool) -> void: _soon = true)
	ship.touched_down.connect(func(_speed: float, _upright: bool, _safe: float) -> void: _soon = true)
	ship.ship_lost.connect(func() -> void: _soon = true)
	# Trading ships happens from inside the station, so the flight takes the new ship there and then.
	ship.design_changed.connect(func(_design: ShipDesign) -> void:
		_take_flight()
		_soon = true)
	if events != null:
		events.event_found.connect(func(_event: FlightEvent) -> void: _soon = true)
		events.event_changed.connect(func(_event: FlightEvent) -> void: _soon = true)
		events.event_gone.connect(func(_id: int) -> void: _soon = true)


## Keeps a death, saving it now.
func note_death(death: Dictionary) -> void:
	_death = death.duplicate(true)
	save_now()


## The pilot's back at work: no death to get over, and the flight as it is now, with them in the
## station and the ship docked.
func death_over() -> void:
	_death = {}
	_take_flight()
	save_now()


## Stops saving, for a new flight that's about to replace this one.
func stop() -> void:
	_stopped = true


## Saves now: the flight if the pilot's aboard, and everything else wherever they are.
func save_now() -> void:
	if _stopped or not enabled() or _ship == null:
		return
	if _ship._lost and not keep_lost_ship:
		erase(slot)
		return
	if _pilot.mode == Pilot.ABOARD:
		_take_flight()
	var data: Dictionary = {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"flight": _flight,
		"agency": _agency.save_state(),
		"worlds": _catalog.save_state(),
		"hangar": hangar.save_state() if hangar != null else {},
		"events": events.save_state() if events != null else {},
		"death": _death,
	}
	_write(data)
	_wait = EVERY_SECONDS
	_soon = false


func _process(delta: float) -> void:
	_wait -= TimeWarp.real(delta)
	if _soon or _wait <= 0.0:
		save_now()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_now()


# Stepping out keeps the flight as it was at that moment; climbing back in picks it up again.
func _on_pilot_mode_changed(mode: String) -> void:
	var aboard: bool = mode == Pilot.ABOARD
	if _was_aboard and not aboard:
		_take_flight()
	_was_aboard = aboard
	_soon = true


func _take_flight() -> void:
	_flight = {"ship": _ship.save_state(), "station": _station.save_state()}


# Writes to a spare file first and then swaps it in, so a phone that closes the app mid-save still
# has the last whole save.
func _write(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var spare: String = path_of(slot) + ".new"
	var file := FileAccess.open(spare, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_var(data)
	file.close()
	DirAccess.rename_absolute(spare, path_of(slot))
