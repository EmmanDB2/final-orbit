# event_director.gd: mid-flight events. While the ship's flying, it rolls now and then for something
# to come up, far enough away to change course for, and announces it on the comms line. It keeps every
# event that's come up, moves the ones that move, tracks what finishing each takes, pays for it through
# the agency, and saves them all. Events are opportunities: none of them is ever forced on the pilot.
# Rolls come from the seed and how many rolls there have been, so the same seed gives the same events.
# From DESIGN.md, "Mid-flight events" and "Core loop" (random events come up mid-flight).
class_name EventDirector
extends Node

## Emitted when an event's picked up.
signal event_found(event: FlightEvent)
## Emitted whenever an event moves on a step: scanned, charted, grabbed, and so on.
signal event_changed(event: FlightEvent)
## Emitted when an event's gone for good, such as a comet that's passed or an astronaut brought home.
signal event_gone(id: int)
## Emitted with something for the comms line, and whether it's good news.
signal message_raised(text: String, good: bool)

@export var event_types: Array[EventType] = [preload("res://data/events/signal.tres"), preload("res://data/events/distress.tres")]
## How long the ship has to be flying before the first roll, and between rolls after, in real seconds.
@export var first_wait: float = 60.0
@export var roll_seconds: float = 45.0
## The chance a roll brings something, which grows with every roll that doesn't.
@export var roll_chance: float = 0.25
@export var chance_growth: float = 0.15
## The most events open at once. Charted signals don't count.
@export var most_open: int = 4
## How far a signal stays from a base, in world units.
@export var base_clearance: float = 20000.0
## How long between checks for a relay in sight, in seconds.
const RELAY_CHECK_SECONDS: float = 0.5
## How close the pilot has to be to an astronaut adrift to take their hand, middle to middle, and how
## slowly they have to be drifting against each other, in world units and world units per second.
const GRAB_REACH: float = 40.0
const GRAB_SPEED: float = 30.0
## How far apart two people holding hands float, middle to middle, in world units.
const HOLD_GAP: float = 26.0
## Within this of an astronaut adrift, the ship's speeds read against them, and within this the
## pilot's, in world units.
const SHIP_CLOSE: float = 2000.0
const PILOT_CLOSE: float = 400.0

## Zen Mode: only the calm events come up.
var calm_only: bool = false
var events: Array[FlightEvent] = []

var _gravity_model: GravityModel
var _ship: Node2D
var _pilot: Pilot
var _agency: Agency
var _bodies: Dictionary = {}
var _sites: Array = []
var _world_seed: int = 0
var _rolls: int = 0
var _misses: int = 0
var _wait: float = 0.0
var _next_id: int = 1
var _next_name: int = 1
var _relay_wait: float = 0.0
var _relay_in_sight: bool = false


func start(gravity_model: GravityModel, ship: Node2D, pilot: Pilot, agency: Agency, bodies: Dictionary, sites: Array) -> void:
	_gravity_model = gravity_model
	_ship = ship
	_pilot = pilot
	_agency = agency
	_bodies = bodies
	_sites = sites
	_world_seed = agency.world_seed
	_wait = first_wait
	ship.ship_lost.connect(_on_ship_lost)
	pilot.mode_changed.connect(_on_pilot_mode_changed)
	# After the pilot and before the ship, so whatever's moving reaches the moment the ship's about to
	# reach before the view's placed, as the pilot does.
	process_physics_priority = -2


## The events still to be done, oldest first.
func open_events() -> Array[FlightEvent]:
	return events.filter(func(event: FlightEvent) -> bool: return event.is_open())


func find(id: int) -> FlightEvent:
	for event: FlightEvent in events:
		if event.id == id:
			return event
	return null


## Everything that can be tapped: every event, open or charted.
func things() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: FlightEvent in events:
		found.append(event.thing_dict())
	return found


## Where an event is right now, or nothing if it's gone.
func point_of(id: int) -> PackedFloat64Array:
	var event: FlightEvent = find(id)
	if event == null:
		return PackedFloat64Array()
	if event.type.kind == "signal":
		return _agency.place_point({"kind": "survey", "world": event.place["world"], "column": event.place["column"]})
	if event.rescue == "aboard":
		return PackedFloat64Array([_ship.state.x, _ship.state.y])
	return PackedFloat64Array([event.state.x, event.state.y])


## How big it is for a tap, as a radius in world units.
func tap_radius(id: int) -> float:
	var event: FlightEvent = find(id)
	if event == null:
		return 0.0
	match event.type.kind:
		"signal":
			return 200.0
		"distress":
			return 30.0
	return 60.0


## The world an event sits on, or -1 for one that's off the ground.
func world_of(id: int) -> int:
	var event: FlightEvent = find(id)
	if event == null or event.type.kind != "signal":
		return -1
	return event.place["world"]


## Its short name, for its marker and the events list.
func callsign_of(id: int) -> String:
	var event: FlightEvent = find(id)
	if event == null:
		return ""
	if event.type.kind == "signal" and event.step == FlightEvent.DONE:
		return event.name
	return event.type.chip


## What it's called in full on its card and the events list.
func title_of(event: FlightEvent) -> String:
	if event.type.kind == "signal" and event.step == FlightEvent.DONE:
		return "%s %s" % [event.thing, event.name]
	if event.type.kind == "distress":
		return "Stranded %s" % event.thing.to_lower()
	return event.type.label.capitalize()


## How it's getting on, for the events list: what to do next, or how the scan's going.
func status_of(event: FlightEvent) -> String:
	if event.type.kind == "distress":
		match event.rescue:
			"held":
				return "HELD · BOARD THE SHIP"
			"aboard":
				return "ABOARD · DOCK OR LAND ON A PAD"
		return "ADRIFT · MATCH ORBIT, THEN EVA"
	match event.step:
		FlightEvent.FOUND:
			if event.scan_share > 0.0:
				return "SCAN %d%%" % roundi(event.scan_share * 100.0) + ("" if _in_reach(event) else " · OUT OF REACH")
			return "SCAN WITHIN %s" % Units.distance_text(event.type.scan_reach)
		FlightEvent.STORED:
			return "UPLINKING" if _relay_in_sight else "DATA STORED · NO RELAY IN SIGHT"
	return "CHARTED"


## Everything a card shows about it, the same way the world catalog has it.
func info_of(id: int) -> Dictionary:
	var event: FlightEvent = find(id)
	if event == null:
		return {"name": "Gone", "chip": "", "rows": [], "note": "", "can_target": false}
	var at: PackedFloat64Array = point_of(id)
	var away: float = Vector2(at[0] - _ship.state.x, at[1] - _ship.state.y).length()
	var rows: Array = []
	var note: String = ""
	match event.type.kind:
		"signal":
			var world: String = _world_name(event.place["world"])
			rows.append(["ON", world, true])
			if event.step == FlightEvent.DONE:
				rows.append(["SOURCE", event.thing.to_upper(), true])
				rows.append(["CHARTED", "FIRST", true])
			else:
				rows.append(["SOURCE", "UNKNOWN", false])
				rows.append(["SCAN", "%d%%" % roundi(event.scan_share * 100.0), true])
				rows.append(["PAYS", "%s + %s CR" % [Units.grouped(event.type.pay), Units.grouped(event.type.first_bonus)], true])
				note = "Fly or land within %s and scan it. The data uplinks with a relay in sight." % Units.distance_text(event.type.scan_reach).to_lower()
		"distress":
			var world: int = _gravity_model.get_dominant_body(at[0], at[1], _ship.state.time)
			var moving: PackedFloat64Array = velocity_of(id)
			rows.append(["WHO", event.thing.to_upper(), true])
			rows.append(["NEAR", _world_name(world) if _bodies.has(world) else "DEEP SPACE", true])
			rows.append(["ALTITUDE", Units.distance_text(_gravity_model.get_altitude(at[0], at[1], _ship.state.time)).to_lower(), true])
			rows.append(["REL. SPEED", Units.speed_text(Vector2(moving[0] - _ship.state.velocity_x, moving[1] - _ship.state.velocity_y).length()).to_lower(), true])
			rows.append(["STATUS", event.rescue.to_upper(), true])
			rows.append(["PAYS", "%s CR" % Units.grouped(event.type.pay), true])
			note = "Match their orbit, go out on EVA, and take their hand. Bring them to Kapteyn-3 or a base."
	rows.append(["DISTANCE", Units.distance_text(away).to_lower(), true])
	var chip: String = "CHARTED" if event.step == FlightEvent.DONE else event.type.chip
	return {"name": title_of(event), "chip": chip, "rows": rows, "note": note, "can_target": true}


## How it's moving, as [x, y] velocity.
func velocity_of(id: int) -> PackedFloat64Array:
	var event: FlightEvent = find(id)
	if event == null or event.state == null or event.rescue == "aboard":
		return PackedFloat64Array([_ship.state.velocity_x, _ship.state.velocity_y])
	return PackedFloat64Array([event.state.velocity_x, event.state.velocity_y])


## What the events add to the context menu right now: each a "label", a "target" giving box corners in
## the world, and what to "run" when it's picked. From the cockpit, scans; out on EVA or on foot, taking
## someone's hand and letting go.
func options() -> Array:
	var offered: Array = []
	if _pilot.mode == Pilot.ABOARD and not _ship._lost:
		for event: FlightEvent in events:
			if event.step == FlightEvent.FOUND and not event.scanning and _in_reach(event):
				offered.append({"label": "SCAN %s" % event.type.chip, "target": _box_round(event.id), "run": _start_scan.bind(event.id)})
	elif _pilot.mode == Pilot.EVA or _pilot.mode == Pilot.SURFACE:
		for event: FlightEvent in events:
			if event.type.kind != "distress":
				continue
			if event.rescue == "held" and _pilot.mode == Pilot.EVA:
				offered.append({"label": "LET GO", "target": _box_round(event.id, 20.0), "run": _let_go.bind(event.id)})
			elif event.rescue == "adrift" and _can_grab(event):
				offered.append({"label": "GRAB HAND", "target": _box_round(event.id, 20.0), "run": _grab.bind(event.id)})
	return offered


## Picks up an event of this type now, wherever the roll puts it, as a roll would. Says whether it
## found somewhere to put it.
func spawn(type: EventType, seed_text: String = "") -> FlightEvent:
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_text if seed_text != "" else "%d|event|%d|%d" % [_world_seed, _rolls, _next_id]).hash()
	var event := FlightEvent.new()
	event.type = type
	event.found_at = _ship.state.time
	event.thing = type.things[rng.randi() % type.things.size()] if not type.things.is_empty() else ""
	var placed: bool = false
	match type.kind:
		"signal":
			placed = _place_signal(event, rng)
		"distress":
			placed = _place_adrift(event, rng)
	if not placed:
		return null
	event.id = _next_id
	_next_id += 1
	events.append(event)
	var at: PackedFloat64Array = point_of(event.id)
	var away: String = Units.distance_text(Vector2(at[0] - _ship.state.x, at[1] - _ship.state.y).length())
	message_raised.emit("%s: %s · %s" % [type.call, _where(event), away], true)
	event_found.emit(event)
	return event


## Everything a save needs: how far the rolls have got, and every event.
func save_state() -> Dictionary:
	var saved: Array = []
	for event: FlightEvent in events:
		saved.append(event.save_state())
	return {"rolls": _rolls, "misses": _misses, "wait": _wait, "next_id": _next_id, "next_name": _next_name, "events": saved}


func restore_state(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	_rolls = saved.get("rolls", 0)
	_misses = saved.get("misses", 0)
	_wait = saved.get("wait", first_wait)
	_next_id = saved.get("next_id", 1)
	_next_name = saved.get("next_name", 1)
	events.clear()
	for entry: Dictionary in saved.get("events", []):
		var event: FlightEvent = FlightEvent.from_saved(entry)
		if event != null:
			events.append(event)
			# Someone rescued is still aboard, and weighs.
			if event.type.kind == "distress" and event.rescue == "aboard":
				_ship.carry_passenger(event.type.mass_kg)
			event_found.emit(event)


func _physics_process(delta: float) -> void:
	if _ship == null:
		return
	if _flying():
		_wait -= TimeWarp.real(delta)
		if _wait <= 0.0:
			_roll()
	_relay_wait -= delta
	var check_relay: bool = _relay_wait <= 0.0
	if check_relay:
		_relay_wait = RELAY_CHECK_SECONDS
	for event: FlightEvent in events.duplicate():
		match event.type.kind:
			"signal":
				_track_scan(event, delta, check_relay)
			"distress":
				_track_rescue(event, delta)
	_read_speeds_against_survivors()
	_press_for_options()


# Not docked, not landed, and not lost: out between places, where things turn up.
func _flying() -> bool:
	return not _ship.docked and not _ship.state.is_on_surface() and not _ship._lost


func _roll() -> void:
	_rolls += 1
	_wait = roll_seconds
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|event|%d" % [_world_seed, _rolls]).hash()
	if open_events().size() >= most_open:
		return
	if rng.randf() > minf(roll_chance + chance_growth * _misses, 1.0):
		_misses += 1
		return
	var kinds: Array[EventType] = event_types.filter(func(type: EventType) -> bool: return type.calm or not calm_only)
	var total: float = 0.0
	for type: EventType in kinds:
		total += type.weight
	if total <= 0.0:
		return
	var pick: float = rng.randf() * total
	var chosen: EventType = kinds[0]
	for type: EventType in kinds:
		pick -= type.weight
		if pick <= 0.0:
			chosen = type
			break
	if spawn(chosen, "%d|event|%d|place" % [_world_seed, _rolls]) == null:
		_misses += 1
	else:
		_misses = 0


# A signal on the ground of the planet or the moon: far enough from the ship, off the seas, and
# away from the bases.
func _place_signal(event: FlightEvent, rng: RandomNumberGenerator) -> bool:
	var worlds: Array = _bodies.keys()
	worlds.sort()
	if worlds.is_empty():
		return false
	for attempt in range(60):
		var world: int = worlds[rng.randi() % worlds.size()]
		var columns: int = roundi(TAU * _gravity_model.get_body_radius(world) / 2.0)
		var column: int = rng.randi() % columns
		var data: BodyData = _bodies[world]
		if data.body_kind != "AIRLESS":
			var strip: PackedFloat32Array = _gravity_model.get_ground_strip(world, column, 1, 1)
			if strip[1] < Agency.SEA_BAND:
				continue
		var at: PackedFloat64Array = _agency.place_point({"kind": "survey", "world": world, "column": column})
		if Vector2(at[0] - _ship.state.x, at[1] - _ship.state.y).length() < event.type.nearest:
			continue
		var by_a_base: bool = false
		for site: SiteView in _sites:
			var middle: PackedFloat64Array = site.middle(_ship.state.time)
			if site.world == world and Vector2(at[0] - middle[0], at[1] - middle[1]).length() < base_clearance:
				by_a_base = true
		if by_a_base:
			continue
		event.place = {"world": world, "column": column}
		return true
	return false


# An astronaut adrift: somewhere in orbit round the world the ship's near, the same way round as the
# ship goes, so catching up is a matter of phasing, and far enough off to need it.
func _place_adrift(event: FlightEvent, rng: RandomNumberGenerator) -> bool:
	var time: float = _ship.state.time
	var world: int = _gravity_model.get_dominant_body(_ship.state.x, _ship.state.y, time)
	if not _bodies.has(world):
		var worlds: Array = _bodies.keys()
		worlds.sort()
		if worlds.is_empty():
			return false
		world = worlds[0]
	var data: BodyData = _bodies[world]
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, time)
	var center_moving: PackedFloat64Array = _gravity_model.get_body_velocity(world, time)
	var from_world := Vector2(_ship.state.x - center[0], _ship.state.y - center[1])
	var against := Vector2(_ship.state.velocity_x - center_moving[0], _ship.state.velocity_y - center_moving[1])
	var sense: float = 1.0 if from_world.cross(against) >= 0.0 else -1.0
	var radius: float = _gravity_model.get_body_radius(world)
	var influence: float = _gravity_model.get_sphere_of_influence(world)
	for attempt in range(60):
		var reach: float = radius + rng.randf_range(event.type.lowest_orbit, event.type.highest_orbit)
		if influence > 0.0 and reach * 1.05 > influence:
			continue
		var angle: float = rng.randf() * TAU
		var way := Vector2(cos(angle), sin(angle))
		var at := Vector2(center[0], center[1]) + way * reach
		if at.distance_to(Vector2(_ship.state.x, _ship.state.y)) < event.type.nearest:
			continue
		var speed: float = sqrt(data.get_mu() / reach) * rng.randf_range(0.99, 1.01)
		var moving: Vector2 = Vector2(-way.y, way.x) * sense * speed
		event.state = ShipState.new()
		event.state.x = at.x
		event.state.y = at.y
		event.state.velocity_x = center_moving[0] + moving.x
		event.state.velocity_y = center_moving[1] + moving.y
		event.state.time = time
		event.state.ground_clearance = 20.0
		return true
	return false


# Adrift, they coast on the gravity model like anything else. Held, they go where the pilot's hand
# takes them. Aboard, they ride along until the ship's docked at the station or on a base's pad.
func _track_rescue(event: FlightEvent, delta: float) -> void:
	# The ship hasn't moved yet this tick: this is the moment it's about to reach.
	var now: float = _ship.state.time + delta
	match event.rescue:
		"adrift":
			var behind: float = now - event.state.time
			if behind > 0.0:
				_gravity_model.propagate(event.state, behind)
		"held":
			_follow_pilot(event, now)
		"aboard":
			event.state.x = _ship.state.x
			event.state.y = _ship.state.y
			event.state.velocity_x = _ship.state.velocity_x
			event.state.velocity_y = _ship.state.velocity_y
			event.state.time = _ship.state.time
			if _ship.docked:
				_deliver(event, _agency.place_name({"kind": "station"}))
				return
			for i in range(_sites.size()):
				if _agency.ship_at({"kind": "site", "index": i}):
					_deliver(event, _agency.place_name({"kind": "site", "index": i}))
					return


# Holding hands: beside the pilot, on their right on EVA, or a step behind them on the ground.
func _follow_pilot(event: FlightEvent, now: float) -> void:
	var offset: Vector2 = Vector2(HOLD_GAP, 0.0).rotated(_pilot.facing)
	if _pilot.mode == Pilot.SURFACE or _pilot.mode == Pilot.INDOORS:
		var world: int = _gravity_model.get_dominant_body(_pilot.state.x, _pilot.state.y, _pilot.state.time)
		var center: PackedFloat64Array = _gravity_model.get_body_position(world, _pilot.state.time)
		var up := Vector2(_pilot.state.x - center[0], _pilot.state.y - center[1]).normalized()
		var along := Vector2(-up.y, up.x)
		offset = along * (-HOLD_GAP if _pilot._facing_right else HOLD_GAP)
	event.state.x = _pilot.state.x + offset.x
	event.state.y = _pilot.state.y + offset.y
	event.state.velocity_x = _pilot.state.velocity_x
	event.state.velocity_y = _pilot.state.velocity_y
	event.state.time = now


# Close enough to take their hand, and drifting slowly enough against them.
func _can_grab(event: FlightEvent) -> bool:
	var apart := Vector2(event.state.x - _pilot.state.x, event.state.y - _pilot.state.y)
	var against := Vector2(event.state.velocity_x - _pilot.state.velocity_x, event.state.velocity_y - _pilot.state.velocity_y)
	return apart.length() <= GRAB_REACH and against.length() <= GRAB_SPEED


func _grab(id: int) -> void:
	var event: FlightEvent = find(id)
	if event == null or event.rescue != "adrift" or not _can_grab(event):
		return
	event.rescue = "held"
	_pilot.carried_kg += event.type.mass_kg
	message_raised.emit("GOT THEM: BRING THEM ABOARD", true)
	event_changed.emit(event)


func _let_go(id: int) -> void:
	var event: FlightEvent = find(id)
	if event == null or event.rescue != "held":
		return
	event.rescue = "adrift"
	_pilot.carried_kg = maxf(_pilot.carried_kg - event.type.mass_kg, 0.0)
	message_raised.emit("LET GO", false)
	event_changed.emit(event)


# Boarding the ship takes whoever's held aboard too; walking into the station or a base's building
# with them brings them home there and then.
func _on_pilot_mode_changed(mode: String) -> void:
	for event: FlightEvent in events.duplicate():
		if event.type.kind != "distress" or event.rescue != "held":
			continue
		match mode:
			Pilot.ABOARD:
				event.rescue = "aboard"
				_pilot.carried_kg = maxf(_pilot.carried_kg - event.type.mass_kg, 0.0)
				_ship.carry_passenger(event.type.mass_kg)
				message_raised.emit("SURVIVOR ABOARD: DOCK OR LAND ON A PAD", true)
				event_changed.emit(event)
			Pilot.INSIDE:
				_deliver(event, _agency.place_name({"kind": "station"}))
			Pilot.INDOORS:
				_deliver(event, _pilot._site.data.display_name if _pilot._site != null else "the base")


func _deliver(event: FlightEvent, where: String) -> void:
	if event.rescue == "held":
		_pilot.carried_kg = maxf(_pilot.carried_kg - event.type.mass_kg, 0.0)
	elif event.rescue == "aboard":
		_ship.carry_passenger(-event.type.mass_kg)
	event.step = FlightEvent.DONE
	event.rescue = "home"
	events.erase(event)
	message_raised.emit("RESCUE COMPLETE: SAFE AT %s" % where.to_upper(), true)
	_agency.pay(event.type.pay, "SURVIVOR DELIVERED")
	event_gone.emit(event.id)


# Close to someone adrift, speeds read against them, for the ship and for the pilot reaching out.
func _read_speeds_against_survivors() -> void:
	var nearest_to_ship: FlightEvent = null
	var nearest_to_pilot: FlightEvent = null
	for event: FlightEvent in events:
		if event.type.kind != "distress" or event.rescue != "adrift":
			continue
		var at := Vector2(event.state.x, event.state.y)
		if at.distance_to(Vector2(_ship.state.x, _ship.state.y)) <= SHIP_CLOSE:
			nearest_to_ship = event
		if _pilot.mode == Pilot.EVA and at.distance_to(Vector2(_pilot.state.x, _pilot.state.y)) <= PILOT_CLOSE:
			nearest_to_pilot = event
	if nearest_to_ship != null:
		_ship.set_event_moving(velocity_of.bind(nearest_to_ship.id), "SURVIVOR")
	else:
		_ship.set_event_moving(Callable())
	_pilot.near_moving = velocity_of.bind(nearest_to_pilot.id) if nearest_to_pilot != null else Callable()


# F on the Mac picks the first of the events' choices when the pilot has nothing of their own to do,
# and the agency has nothing either.
func _press_for_options() -> void:
	if _pilot._action != "" or _pilot.input_blocked or not Input.is_action_just_pressed("interact"):
		return
	if _pilot.mode == Pilot.ABOARD and not _agency.options().is_empty():
		return
	var offered: Array = options()
	if not offered.is_empty():
		offered[0]["run"].call()


# A scan runs whenever the ship's in reach once it's started, keeping what it has when it's out of
# reach. Whole, the data waits aboard for a relay in sight, and goes home then.
func _track_scan(event: FlightEvent, delta: float, check_relay: bool) -> void:
	if event.step == FlightEvent.FOUND and event.scanning and _in_reach(event):
		event.scan_share = minf(event.scan_share + delta / event.type.scan_seconds, 1.0)
		if event.scan_share >= 1.0:
			event.scanning = false
			event.step = FlightEvent.STORED
			message_raised.emit("SCAN COMPLETE: DATA STORED", true)
			event_changed.emit(event)
	elif event.step == FlightEvent.STORED and check_relay:
		_relay_in_sight = _agency.can_see_relay()
		if _relay_in_sight:
			_chart(event)


func _chart(event: FlightEvent) -> void:
	event.step = FlightEvent.DONE
	event.name = "A-%02d" % _next_name
	_next_name += 1
	message_raised.emit("CHARTED: %s %s" % [event.thing.to_upper(), event.name], true)
	_agency.pay(event.type.pay, "DATA UPLINKED")
	_agency.pay(event.type.first_bonus, "FIRST TO CHART")
	event_changed.emit(event)


func _start_scan(id: int) -> void:
	var event: FlightEvent = find(id)
	if event == null or event.step != FlightEvent.FOUND or not _in_reach(event):
		return
	event.scanning = true
	message_raised.emit("SCANNING", true)
	event_changed.emit(event)


# Whether the ship's near enough to scan it, with the pilot aboard to work the scanner.
func _in_reach(event: FlightEvent) -> bool:
	if _pilot.mode != Pilot.ABOARD or _ship._lost:
		return false
	var at: PackedFloat64Array = point_of(event.id)
	return Vector2(at[0] - _ship.state.x, at[1] - _ship.state.y).length() <= event.type.scan_reach


# Losing the ship loses the data aboard: a stored scan has to be done again. Anyone rescued aboard is
# lost with it.
func _on_ship_lost() -> void:
	for event: FlightEvent in events.duplicate():
		if event.type.kind == "distress" and event.rescue == "aboard":
			events.erase(event)
			message_raised.emit("SURVIVOR LOST", false)
			event_gone.emit(event.id)
			continue
		if event.step == FlightEvent.STORED or event.scan_share > 0.0:
			if event.step != FlightEvent.DONE:
				event.step = FlightEvent.FOUND
				event.scan_share = 0.0
				event.scanning = false
				event_changed.emit(event)


# A box round an event, for the context menu's brackets.
func _box_round(id: int, half: float = 40.0) -> Callable:
	return func() -> PackedFloat64Array:
		var at: PackedFloat64Array = point_of(id)
		if at.is_empty():
			return PackedFloat64Array()
		return PackedFloat64Array([at[0] - half, at[1] - half, at[0] + half, at[1] - half, at[0] + half, at[1] + half, at[0] - half, at[1] + half])


# Where an event is, for the comms line: the world it's on or near.
func _where(event: FlightEvent) -> String:
	if event.type.kind == "signal":
		return _world_name(event.place["world"]).to_upper()
	var near: int = _gravity_model.get_dominant_body(event.state.x, event.state.y, event.state.time)
	return ("NEAR " + _world_name(near).to_upper()) if _bodies.has(near) else "DEEP SPACE"


func _world_name(world: int) -> String:
	var data: BodyData = _bodies.get(world)
	return data.display_name if data != null else ""
