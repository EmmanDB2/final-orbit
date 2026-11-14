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

@export var event_types: Array[EventType] = [preload("res://data/events/signal.tres")]
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
	return PackedFloat64Array([event.state.x, event.state.y])


## How big it is for a tap, as a radius in world units.
func tap_radius(id: int) -> float:
	var event: FlightEvent = find(id)
	if event == null:
		return 0.0
	match event.type.kind:
		"signal":
			return 200.0
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
	return event.type.label.capitalize()


## How it's getting on, for the events list: what to do next, or how the scan's going.
func status_of(event: FlightEvent) -> String:
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
	rows.append(["DISTANCE", Units.distance_text(away).to_lower(), true])
	var chip: String = "CHARTED" if event.step == FlightEvent.DONE else event.type.chip
	return {"name": title_of(event), "chip": chip, "rows": rows, "note": note, "can_target": true}


## What the events add to the context menu right now: each a "label", a "target" giving box corners in
## the world, and what to "run" when it's picked.
func options() -> Array:
	var offered: Array = []
	if _pilot.mode != Pilot.ABOARD or _ship._lost:
		return offered
	for event: FlightEvent in events:
		if event.step == FlightEvent.FOUND and not event.scanning and _in_reach(event):
			offered.append({"label": "SCAN %s" % event.type.chip, "target": _box_round(event.id), "run": _start_scan.bind(event.id)})
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


# Losing the ship loses the data aboard: a stored scan has to be done again.
func _on_ship_lost() -> void:
	for event: FlightEvent in events:
		if event.step == FlightEvent.STORED or event.scan_share > 0.0:
			if event.step != FlightEvent.DONE:
				event.step = FlightEvent.FOUND
				event.scan_share = 0.0
				event.scanning = false
				event_changed.emit(event)


# A box round an event, for the context menu's brackets.
func _box_round(id: int) -> Callable:
	return func() -> PackedFloat64Array:
		var at: PackedFloat64Array = point_of(id)
		if at.is_empty():
			return PackedFloat64Array()
		var half: float = 40.0
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
