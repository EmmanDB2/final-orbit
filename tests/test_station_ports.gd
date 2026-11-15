# test_station_ports.gd: checks a station of modules' ports in the running game: ships dock only at
# docking collars, never an airlock; the airlock's cycle runs its lamps and doors and lets the pilot out
# only at its end; EXIT STATION is offered only at the airlock; a pilot waking up stands by the med bed;
# and a ship's docked port is saved by name, with an old save's number turned into one. The station is
# the synthetic one from tests/test_station.gd. Run with:
#   godot --headless --path . --script tests/test_station_ports.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var maker = load("res://tests/test_station.gd").new()
	var design: StationDesign = maker._synthetic_station()
	# What the old Kapteyn-3's numbers meant: 0 comms, 1 crew hab, 2 EVA hab, 3 ship refueling.
	design.legacy_ports = PackedStringArray(["dock_s", "dock_e", "dock_w", "dock_s"])
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.station = design
	root.add_child(main)
	await process_frame
	await process_frame
	var station: StationView = main.get_node("Station")
	var pilot: Pilot = main.get_node("Pilot")
	var ship: Node2D = main.get_node("Ship")
	_test_docking_only_at_collars(station, ship)
	_test_saves(station, ship)
	await _test_airlock(station, pilot)
	_test_waking(main, station, pilot)
	main.queue_free()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _flag(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_failures += 1
		print("FAIL %s" % label)


func _port_named(station: StationView, wanted: String) -> int:
	for i in range(station._ports.size()):
		if station._ports[i]["name"] == wanted:
			return i
	return -1


# Puts the ship so its hatch is on a port, nose straight in and standing still against the station,
# and tries to dock there.
func _try_dock_at(station: StationView, ship: Node2D, port: int) -> bool:
	var frame: Dictionary = station.frame_at(ship.state.time)
	var entry: Dictionary = station._ports[port]
	var into: Vector2 = -entry["face"]
	ship.heading = frame["angle"] + atan2(into.x, -into.y)
	var hatch: Vector2 = ship.hatch_from_center().rotated(ship.heading)
	var at: Vector2 = Vector2(entry["at"]).rotated(frame["angle"]) - hatch
	ship.state.x = frame["x"] + at.x
	ship.state.y = frame["y"] + at.y
	var to_ship := Vector2(ship.state.x - frame["x"], ship.state.y - frame["y"])
	# Moving with the station, turning included, so there's no speed against it.
	var moving: Vector2 = station.moving_at(frame, to_ship)
	ship.state.velocity_x = moving.x
	ship.state.velocity_y = moving.y
	ship.angular_velocity = frame["rate"]
	station.docked_port = -1
	station._leaving_port = false
	return station._try_docking(frame, to_ship)


func _test_docking_only_at_collars(station: StationView, ship: Node2D) -> void:
	var dock: int = _port_named(station, "dock_s")
	var airlock: int = _port_named(station, "airlock")
	_flag("the station has a docking collar and an airlock", dock >= 0 and airlock >= 0)
	_flag("a ship's hatch at the airlock can't dock", not _try_dock_at(station, ship, airlock) and station.docked_port == -1)
	_flag("at a docking collar it can", _try_dock_at(station, ship, dock) and station.docked_port == dock)
	_flag("an airlock can't be boarded onto from a ship, but is by EVA", station.port_exits(airlock) and not station.port_exits(dock))
	station.docked_port = -1


func _test_saves(station: StationView, ship: Node2D) -> void:
	station.restore_state({"docked_port": "dock_s"})
	_flag("a saved port name docks there", station.docked_port == _port_named(station, "dock_s"))
	_flag("and is saved by name", station.save_state()["docked_port"] == "dock_s")
	station.docked_port = -1
	# A version 3 save: the port is a number, and old 3 (ship refueling) is the south collar.
	var old: Dictionary = SaveGame._upgrade({"version": 3, "agency": {}, "flight": {"station": {"docked_port": 3}}})
	_flag("a version 3 save upgrades to version 4", old["version"] == SaveGame.VERSION and SaveGame.VERSION == 4)
	station.restore_state(old["flight"]["station"])
	_flag("with docked_port 3 it loads docked at dock_s", station.docked_port == _port_named(station, "dock_s"))
	station.docked_port = -1
	ship.docked = false
	station.restore_state({"docked_port": 1})
	_flag("an old number whose port the station doesn't have leaves the ship undocked", station.docked_port == -1)
	station.restore_state({"docked_port": "nowhere"})
	_flag("so does a name it doesn't have", station.docked_port == -1)
	station.restore_state({"docked_port": 99})
	_flag("and a number out of range", station.docked_port == -1)
	station.restore_state({"docked_port": 3})
	_flag("restoring puts the ship docked", station.docked_port >= 0 and ship.docked)
	station.docked_port = -1


func _test_airlock(station: StationView, pilot: Pilot) -> void:
	var airlock: int = _port_named(station, "airlock")
	var dock: int = _port_named(station, "dock_s")
	var done: Array = []
	station.airlock_cycle_done.connect(func(port: int, going_out: bool) -> void: done.append([port, going_out]))
	# EXIT STATION is offered at the airlock's door and not at a docking collar's.
	pilot._enter_station(airlock)
	station.start_airlock_cycle(airlock, true)
	station._cycle = {}
	station._sync_collar_doors()
	pilot._local = station.port_inner(airlock)
	pilot._tick_inside(0.016)
	_flag("EXIT STATION is offered at the airlock", pilot._action == "EXIT STATION")
	pilot._local = station.port_inner(dock)
	pilot._tick_inside(0.016)
	_flag("and not at a docking collar", pilot._action != "EXIT STATION")
	# The cycle going out: lamps red, then amber, then green, the outer door opening at the end.
	var lamps: AirlockLamps = station._lamps
	var doors: HatchDoors = station.hatch_doors()
	var outer: int = doors.find("airlock", "airlock")
	station.start_airlock_cycle(airlock, true)
	_flag("the pilot waits while it cycles", station.airlock_busy())
	station._run_cycle(0.4)
	_flag("lamps red at first", lamps.state_of(airlock) == AirlockLamps.RED)
	station._run_cycle(0.8)
	_flag("then amber", lamps.state_of(airlock) == AirlockLamps.AMBER)
	_flag("the outer door's still shut", doors.openness(outer) == 0.0)
	station._run_cycle(0.6)
	station._run_cycle(0.7)
	_flag("then green, and the cycle's done", done.size() == 1 and done[0][1] == true and lamps.state_of(airlock) == AirlockLamps.GREEN)
	_flag("the pilot's out through the outer door", pilot.mode == Pilot.EVA)
	doors.update(0.3, Vector2(-1.0e9, -1.0e9), station.layout.origin)
	_flag("and the outer door opens", doors.openness(outer) == 1.0)
	for i in range(30):
		station._run_cycle(0.1)
		doors.update(0.1, Vector2(-1.0e9, -1.0e9), station.layout.origin)
	_flag("and shuts again after", doors.openness(outer) == 0.0 and not station.airlock_busy())
	# Coming in runs it backward and ends with the inner door open.
	var inner: int = doors.find("airlock", "door")
	_flag("this station's airlock has no inner door of its own", inner == -1)
	pilot._enter_station(airlock)
	_flag("the pilot's in, waiting out the cycle", pilot.mode == Pilot.INSIDE and station.airlock_busy())
	for i in range(30):
		station._run_cycle(0.1)
	_flag("and it ends", not station.airlock_busy() and done.size() == 2 and done[1][1] == false)
	station._cycle = {}


func _test_waking(main: Node, station: StationView, pilot: Pilot) -> void:
	main.get_node("Ship").docked = false
	station.restore_home()
	_flag("the ship's put on the home port", station.docked_port == _port_named(station, "dock_s"))
	pilot.wake_in_station(station.docked_port)
	_flag("the pilot wakes up inside", pilot.mode == Pilot.INSIDE)
	var bed: Dictionary = {}
	for spot: Dictionary in station.layout.spots:
		if spot["kind"] == "wake":
			bed = spot
	var bed_at: Vector2 = station.spot_point(bed)
	_flag("beside the bed", pilot._local.distance_to(bed_at) < 60.0 and pilot._local.distance_to(bed_at) > 1.0)
	_flag("on floor they can stand on", station.pilot_fits(pilot._local, pilot.data.body_radius))
	_flag("facing down", absf(angle_difference(pilot._local_facing, PI)) < 0.01)
	_flag("and the bed isn't something to use", station.spot_near(bed_at, 4.0).is_empty())
