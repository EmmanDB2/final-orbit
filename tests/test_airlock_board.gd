# test_airlock_board.gd: the way back in. On EVA outside Kapteyn-3's airlock, BOARD STATION is on the context
# menu, and tapping it (the same call the menu's button makes) opens the outer door if it's closed, cycling
# first, and then the pilot drifts in by themselves at float speed; or they fly in on the jetpack across the
# open door's line. Either way the door shuts behind them, the airlock cycles, the inner door opens, and they
# can walk into the EVA room. Runs the game for real, tick by tick. Run with:
#   godot --headless --path . --script tests/test_airlock_board.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	await _test_board_with_the_door_closed()
	await _test_tap_drifts_in()
	await _test_fly_in_through_the_open_door()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _flag(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_failures += 1
		print("FAIL %s" % label)


# A fresh game with the pilot floating on EVA this far straight out from the airlock's mouth, moving as the
# station does.
func _start(distance: float) -> Dictionary:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var station: StationView = main.get_node("Station")
	var pilot: Pilot = main.get_node("Pilot")
	var air: int = -1
	for i in range(station._ports.size()):
		if station._ports[i]["kind"] == StationView.AIRLOCK:
			air = i
	var face: Vector2 = station._ports[air]["face"]
	var out_local: Vector2 = Vector2(station._ports[air]["at"]) + face * distance
	pilot.visible = true
	pilot.state.time = main.get_node("Ship").state.time
	var frame: Dictionary = station.frame_at(pilot.state.time)
	var world: Vector2 = out_local.rotated(frame["angle"])
	pilot.state.x = frame["x"] + world.x
	pilot.state.y = frame["y"] + world.y
	var moving: Vector2 = station.moving_at(frame, world)
	pilot.state.velocity_x = moving.x
	pilot.state.velocity_y = moving.y
	main.get_node("Ship").set_pilot_aboard(false)
	pilot.gas = pilot.data.jet_seconds
	pilot._set_mode(Pilot.EVA)
	for i in range(5):
		await physics_frame
	return {"main": main, "station": station, "pilot": pilot, "air": air, "face": face,
			"hud": main.get_node("Hud/SafeArea/FlightHud")}


# Taps BOARD STATION the way the menu's button does: its row's own call.
func _tap_board_station(hud: FlightHud, pilot: Pilot) -> bool:
	hud._gather_context_rows()
	if pilot._action != "BOARD STATION":
		return false
	hud._on_context_chosen(0)
	return true


func _local_of(station: StationView, pilot: Pilot) -> Vector2:
	var frame: Dictionary = station.frame_at(pilot.state.time)
	return Vector2(pilot.state.x - frame["x"], pilot.state.y - frame["y"]).rotated(-frame["angle"])


# How fast they're moving in along the airlock's way, against the station, in units a second.
func _speed_in(station: StationView, pilot: Pilot, face: Vector2) -> float:
	var frame: Dictionary = station.frame_at(pilot.state.time)
	var local: Vector2 = _local_of(station, pilot)
	var against := Vector2(pilot.state.velocity_x, pilot.state.velocity_y) - station.moving_at(frame, local.rotated(frame["angle"]))
	return -against.rotated(-frame["angle"]).dot(face)


func _wait_until(condition: Callable, ticks: int) -> bool:
	for i in range(ticks):
		await physics_frame
		if condition.call():
			return true
	return false


# Inside, with the cycle over: the inner door's open, and they can walk on into the EVA room.
func _check_in_the_eva_room(label: String, game: Dictionary) -> void:
	var station: StationView = game["station"]
	var pilot: Pilot = game["pilot"]
	var doors: HatchDoors = station.hatch_doors()
	var done: bool = await _wait_until(func() -> bool: return not station.airlock_busy() and not station._cycle.is_empty(), 900)
	_flag("%s: the cycle ends" % label, done)
	var inner: int = doors.find(station._ports[game["air"]]["name"], "door")
	await _wait_until(func() -> bool: return inner >= 0 and doors.openness(inner) == 1.0, 60)
	_flag("%s: the inner door is open" % label, inner >= 0 and doors.openness(inner) == 1.0)
	_flag("%s: the outer door is shut behind them" % label, doors.openness(doors.find(station._ports[game["air"]]["name"], "airlock")) == 0.0)
	# Walk on in, away from the airlock's mouth.
	var face: Vector2 = game["face"]
	var frame: Dictionary = station.frame_at(pilot.state.time)
	pilot._has_drag = true
	pilot._drag_heading = atan2(-face.x, face.y) + frame["angle"]
	var start: Vector2 = pilot._local
	for i in range(90):
		await physics_frame
	pilot._has_drag = false
	var inward: float = (start - pilot._local).dot(face)
	_flag("%s: they walk into the EVA room" % label, inward > 30.0 and station.pilot_fits(pilot._local, station.walk_radius(pilot.data.body_radius)))
	_flag("%s: and are inside, not in vacuum" % label, pilot.mode == Pilot.INSIDE and not station.airlock_vacuum())


# BOARD STATION with the outer door closed: it cycles and opens the door, and nobody's teleported.
func _test_board_with_the_door_closed() -> void:
	var game: Dictionary = await _start(60.0)
	var station: StationView = game["station"]
	var pilot: Pilot = game["pilot"]
	var doors: HatchDoors = station.hatch_doors()
	var outer: int = doors.find(station._ports[game["air"]]["name"], "airlock")
	_flag("closed: the outer door starts shut", doors.openness(outer) == 0.0 and station.open_airlock() == -1)
	_flag("closed: BOARD STATION is on the menu", await _tap_board_station(game["hud"], pilot))
	for i in range(3):
		await physics_frame
	_flag("closed: no teleport, they're still out there on EVA", pilot.mode == Pilot.EVA and _local_of(station, pilot).distance_to(station._ports[game["air"]]["at"]) > 30.0)
	_flag("closed: the airlock cycles", station.airlock_busy())
	var opened: bool = await _wait_until(func() -> bool: return station.open_airlock() == game["air"], 600)
	_flag("closed: the outer door opens", opened)
	await _wait_until(func() -> bool: return doors.openness(outer) == 1.0, 60)
	_flag("closed: and is open", doors.openness(outer) == 1.0)
	game["main"].queue_free()


# Route (b): tap BOARD STATION and they drift in by themselves, then the same float-in handover.
func _test_tap_drifts_in() -> void:
	var game: Dictionary = await _start(60.0)
	var station: StationView = game["station"]
	var pilot: Pilot = game["pilot"]
	_flag("tap: BOARD STATION is on the menu", await _tap_board_station(game["hud"], pilot))
	var came_in: bool = await _wait_until(func() -> bool: return pilot.mode == Pilot.INSIDE, 1500)
	_flag("tap: they drift in by themselves and are inside", came_in)
	_flag("tap: it cycles after they cross", station.airlock_busy() or not station._cycle.is_empty() or pilot.mode == Pilot.INSIDE)
	await _check_in_the_eva_room("tap", game)
	game["main"].queue_free()


# Route (a): the door's open, and they take the jetpack and float in across its line themselves.
func _test_fly_in_through_the_open_door() -> void:
	var game: Dictionary = await _start(40.0)
	var station: StationView = game["station"]
	var pilot: Pilot = game["pilot"]
	var face: Vector2 = game["face"]
	_flag("fly: BOARD STATION is on the menu", await _tap_board_station(game["hud"], pilot))
	var opened: bool = await _wait_until(func() -> bool: return station.open_airlock() == game["air"], 600)
	_flag("fly: the outer door opens", opened)
	# Take over: face the mouth and push in.
	var frame: Dictionary = station.frame_at(pilot.state.time)
	var into: Vector2 = (-face).rotated(frame["angle"])
	pilot.facing = atan2(into.x, -into.y)
	pilot._spin = 0.0
	var gas_before: float = pilot.gas
	# A push on the jetpack, then coasting in, as a player does.
	Input.action_press("thrust")
	await _wait_until(func() -> bool: return _speed_in(station, pilot, face) >= 12.0, 300)
	Input.action_release("thrust")
	var gas_used: bool = pilot.gas < gas_before
	var came_in: bool = await _wait_until(func() -> bool: return pilot.mode == Pilot.INSIDE, 900)
	_flag("fly: pushing in across the line takes them in", came_in)
	_flag("fly: on the jetpack, not drifting", gas_used)
	await _check_in_the_eva_room("fly", game)
	game["main"].queue_free()
