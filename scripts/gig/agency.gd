# agency.gd: the space agency's side of gigs: what each gig board offers, the gig the pilot has taken
# and how far along it is, and the credits paid out. Boards are filled from gig types in data, the same
# way every time for the same place and slot, so the same seed gives the same gigs. It learns what's
# going on from the ship, station, and sites, and tells the UI and the comms line through signals.
# From DESIGN.md, "Core loop" (gigs and payment rules) and "Gigs".
class_name Agency
extends Node

signal credits_changed(credits: int)
## Emitted whenever the active gig changes: taken, a step done or undone, delivered, or failed. Null
## once there's none.
signal gig_changed(gig: Gig)
## Emitted with something for the comms line, and whether it's good news.
signal message_raised(text: String, good: bool)

## Roughly what it takes, in meters per second, to get from each kind of place up to the station's
## orbit, and from there down to each. A route is one up and one down. For pricing and requirements,
## not for flying: the pilot still has to fly it.
const UP_DELTA_V: Dictionary = {"station": 0.0, "planet": 400.0, "moon": 250.0}
const DOWN_DELTA_V: Dictionary = {"station": 30.0, "planet": 120.0, "moon": 260.0}
## How far off the middle of a pad a landed ship can be and still be on it, past its half width, in
## world units.
const PAD_SLACK: float = 60.0

@export var gig_types: Array[GigType] = [preload("res://data/gigs/cargo.tres"), preload("res://data/gigs/survey.tres")]
## Below this map band a planet's surface is sea, where nothing's surveyed.
const SEA_BAND: float = 3.3
## How long between checks for a relay in sight, in seconds.
const RELAY_CHECK_SECONDS: float = 0.5
@export var world_seed: int = 2611
## How many gigs each board shows.
@export var board_size: int = 4

var credits: int = 0
var active: Gig = null
var _gravity_model: GravityModel
var _ship: Node2D
var _pilot: Pilot
var _station: Node2D
var _station_design: StationDesign
var _station_index: int = -1
var _sites: Array = []
var _bodies: Dictionary = {}
var _relay_wait: float = 0.0
## Whether the last check found a relay in sight, for the tracker.
var relay_in_sight: bool = false
# For each board, by place: its slots, each a gig or null once taken, and how many times each slot
# has been filled, so a taken gig is replaced by a new one.
var _boards: Dictionary = {}
var _rounds: Dictionary = {}
var _next_id: int = 1


func start(gravity_model: GravityModel, ship: Node2D, pilot: Pilot, station: Node2D, station_design: StationDesign, station_index: int, sites: Array, bodies: Dictionary = {}) -> void:
	_bodies = bodies
	_gravity_model = gravity_model
	_station_index = station_index
	_ship = ship
	_pilot = pilot
	_station = station
	_station_design = station_design
	_sites = sites
	ship.ship_lost.connect(_on_ship_lost)


## The gigs a board at this place shows now.
func board(place: Dictionary) -> Array[Gig]:
	var key: String = place_key(place)
	if not _boards.has(key):
		var slots: Array = []
		slots.resize(board_size)
		_boards[key] = slots
		var rounds: Array = []
		rounds.resize(board_size)
		rounds.fill(0)
		_rounds[key] = rounds
	var slots: Array = _boards[key]
	var shown: Array[Gig] = []
	for slot in range(board_size):
		if slots[slot] == null:
			slots[slot] = _make_gig(place, slot, _rounds[key][slot])
		shown.append(slots[slot])
	return shown


## What a gig needs that the ship and pilot have or haven't, as pairs of the text and whether it's met.
func requirements(gig: Gig) -> Array:
	var rows: Array = []
	if gig.type.kind == "cargo":
		rows.append(["CARGO ROOM %s/%s KG" % [Units.grouped(roundi(gig.cargo_kg)), Units.grouped(roundi(_ship.cargo_room()))], _ship.cargo_room() >= gig.cargo_kg])
		rows.append(["SHIP DOCKED HERE" if gig.origin["kind"] == "station" else "SHIP ON THE PAD", ship_at(gig.origin)])
	var delta_v: float = _ship.delta_v_with(gig.cargo_kg if gig.type.kind == "cargo" else 0.0)
	rows.append(["ΔV %s/%s M/S" % [Units.speed_number(gig.route_delta_v), Units.speed_number(delta_v)], delta_v >= gig.route_delta_v])
	if active != null and active != gig:
		rows.append(["ONE GIG AT A TIME", false])
	return rows


## What could go wrong on a gig, as pairs of the text and how bad: "LOW", "MEDIUM", "HIGH", or "".
func hazards(gig: Gig) -> Array:
	var margin: float = _ship.delta_v_with(gig.cargo_kg) / maxf(gig.route_delta_v, 1.0)
	var rows: Array = [["ΔV margin", "HIGH" if margin < 1.5 else ("MEDIUM" if margin < 2.5 else "LOW")]]
	match _route_kind(gig.destination):
		"planet":
			rows.append(["Landing in air", ""])
		"moon":
			rows.append(["Airless landing", ""])
		"station":
			rows.append(["Docking", ""])
	if gig.type.kind == "survey":
		rows.append(["No pad: rough ground", ""])
	return rows


## Takes a gig, if everything it needs is met. Cargo goes aboard then and there.
func accept(gig: Gig) -> bool:
	for row: Array in requirements(gig):
		if not row[1]:
			return false
	var key: String = place_key(gig.origin)
	var slot: int = _boards[key].find(gig)
	if slot >= 0:
		_boards[key][slot] = null
		_rounds[key][slot] += 1
	active = gig
	gig.state = "active"
	gig.step = 0
	message_raised.emit("GIG ACCEPTED: %s" % gig.title.to_upper(), true)
	if gig.type.kind == "cargo":
		_ship.load_cargo(gig.cargo_kg)
		gig.step = 1
		message_raised.emit("CARGO LOADED: %s KG" % Units.grouped(roundi(gig.cargo_kg)), true)
	if gig.type.kind == "survey":
		message_raised.emit("SURVEY SITE MARKED: %s" % place_name(gig.destination).to_upper(), true)
	gig_changed.emit(gig)
	return true


## What the agency adds to the context menu right now: each a "label", a "target" giving box corners
## in the world, and what to "run" when it's picked.
func options() -> Array:
	if active == null or _pilot.mode != Pilot.ABOARD:
		return []
	if active.type.kind == "cargo" and active.step == 2:
		return [{"label": "UNLOAD CARGO", "target": _place_box(active.destination), "run": _deliver}]
	if active.type.kind == "survey" and active.step == 1 and not active.scanning:
		return [{"label": "SCAN SITE", "target": _place_box(active.destination), "run": _start_scan}]
	return []


## Where a place is now, in the world.
func place_point(place: Dictionary) -> PackedFloat64Array:
	var time: float = _ship.state.time
	match place.get("kind", ""):
		"station":
			var frame: Dictionary = _station.frame_at(time)
			return PackedFloat64Array([frame["x"], frame["y"]])
		"site":
			return _sites[place["index"]].point_at(time, _sites[place["index"]].data.pad_offset)
		"survey":
			return _survey_point(place, time, 0.0)
	return PackedFloat64Array()


## The thing the camera and markers know a place as, for targeting it.
func place_thing(place: Dictionary) -> Dictionary:
	match place.get("kind", ""):
		"station":
			return {"kind": "satellite", "index": _station_index}
		"site":
			return {"kind": "site", "index": place["index"]}
	return {}


## Where the gig's current step happens, or nothing once it's there.
func current_place(gig: Gig) -> Dictionary:
	if gig == null:
		return {}
	return gig.destination


## A place's full name, such as Kepla Moon Base.
func place_name(place: Dictionary) -> String:
	match place.get("kind", ""):
		"station":
			return _station_design.display_name
		"site":
			return _sites[place["index"]].data.display_name
		"survey":
			return "%s on %s" % [place["name"], _world_name(place["world"])]
	return ""


## A place's short name in capitals, such as MOON BASE.
func place_tag(place: Dictionary) -> String:
	match place.get("kind", ""):
		"station":
			return _station_design.callsign
		"site":
			return _sites[place["index"]].data.chip
		"survey":
			return _world_name(place["world"]).to_upper()
	return ""


static func place_key(place: Dictionary) -> String:
	return "%s:%d" % [place.get("kind", ""), place.get("index", 0)]


## Whether the ship's at a place, ready to load or unload: docked at the station, or landed on a site's
## pad.
func ship_at(place: Dictionary) -> bool:
	var state: ShipState = _ship.state
	match place.get("kind", ""):
		"station":
			return _ship.docked
		"site":
			var site: SiteView = _sites[place["index"]]
			if not state.is_on_surface() or _gravity_model.get_dominant_body(state.x, state.y, state.time) != site.world:
				return false
			var along: float = site.along_of(state.x, state.y, state.time)
			return absf(along - site.data.pad_offset) <= site.data.pad_width / 2.0 + PAD_SLACK
	return false


func _physics_process(delta: float) -> void:
	if active == null or _ship == null:
		return
	if active.type.kind == "cargo":
		var there: bool = ship_at(active.destination)
		if active.step == 1 and there:
			active.step = 2
			gig_changed.emit(active)
		elif active.step == 2 and not there:
			active.step = 1
			gig_changed.emit(active)
	if active.type.kind == "survey":
		_track_survey(delta)
	# F on the Mac picks the agency's choice when the pilot has nothing of their own to do.
	if _pilot.mode == Pilot.ABOARD and _pilot._action == "" and Input.is_action_just_pressed("interact"):
		var offered: Array = options()
		if not offered.is_empty():
			offered[0]["run"].call()


# Cargo off at its destination: paid for the deliverable.
func _deliver() -> void:
	if active == null or active.type.kind != "cargo" or not ship_at(active.destination):
		return
	_ship.unload_cargo()
	_pay(active, "CARGO DELIVERED")


func _pay(gig: Gig, what: String) -> void:
	credits += gig.payout
	gig.state = "done"
	gig.step = gig.objectives.size()
	active = null
	credits_changed.emit(credits)
	message_raised.emit("%s: +%s CR" % [what, Units.grouped(gig.payout)], true)
	gig_changed.emit(null)


# Losing the ship loses what it carried, so the gig pays nothing.
func _on_ship_lost() -> void:
	if active == null:
		return
	var what: String = "CARGO LOST" if active.type.kind == "cargo" else "DATA LOST"
	active.state = "failed"
	active = null
	message_raised.emit("GIG FAILED: %s" % what, false)
	gig_changed.emit(null)


# Pointing at a place, for the context menu: the pad, or the port the ship's docked at.
func _place_box(place: Dictionary) -> Callable:
	match place.get("kind", ""):
		"station":
			return func() -> PackedFloat64Array:
				if _station.docked_port < 0:
					return PackedFloat64Array()
				return _station.box_corners(_station.port_point(_station.docked_port), Vector2(10.0, 10.0), _ship.state.time)
		"site":
			var site: SiteView = _sites[place["index"]]
			return func() -> PackedFloat64Array:
				var time: float = _ship.state.time
				var corners := PackedFloat64Array()
				var half: float = site.data.pad_width / 2.0
				for corner: Vector2 in [Vector2(-half, 24.0), Vector2(half, 24.0), Vector2(half, 0.0), Vector2(-half, 0.0)]:
					var at: PackedFloat64Array = site.point_at(time, site.data.pad_offset + corner.x, corner.y)
					corners.append(at[0])
					corners.append(at[1])
				return corners
		"survey":
			return func() -> PackedFloat64Array:
				var time: float = _ship.state.time
				var corners := PackedFloat64Array()
				for corner: Vector2 in [Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]:
					var at: PackedFloat64Array = _survey_point(place, time, corner.y * 40.0, corner.x * 40.0)
					corners.append(at[0])
					corners.append(at[1])
				return corners
	return Callable()


# The kind of place, for the route's delta-v: the station's orbit, a planet, or a moon.
func _route_kind(place: Dictionary) -> String:
	var world: int = -1
	if place.get("kind", "") == "site":
		world = _sites[place["index"]].world
	elif place.get("kind", "") == "survey":
		world = place["world"]
	if world >= 0:
		return "planet" if _gravity_model.get_body_parent(world) == 0 else "moon"
	return "station"


# Every place a gig can start or end at.
func _places() -> Array:
	var places: Array = [{"kind": "station", "index": 0}]
	for i in range(_sites.size()):
		places.append({"kind": "site", "index": i})
	return places


func _make_gig(place: Dictionary, slot: int, round_number: int) -> Gig:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s|%d|%d" % [world_seed, place_key(place), slot, round_number]).hash()
	# Surveys need worlds to put their spots on.
	var kinds: Array[GigType] = gig_types.filter(func(candidate: GigType) -> bool: return candidate.kind != "survey" or not _bodies.is_empty())
	var total: float = 0.0
	for type: GigType in kinds:
		total += type.weight
	var pick: float = rng.randf() * total
	var type: GigType = kinds[0]
	for candidate: GigType in kinds:
		pick -= candidate.weight
		if pick <= 0.0:
			type = candidate
			break
	var gig := Gig.new()
	gig.id = _next_id
	_next_id += 1
	gig.type = type
	gig.origin = place
	if type.kind == "survey":
		_make_survey(gig, rng)
	else:
		_make_cargo(gig, rng)
	return gig


func _make_cargo(gig: Gig, rng: RandomNumberGenerator) -> void:
	var type: GigType = gig.type
	var others: Array = _places().filter(func(other: Dictionary) -> bool: return place_key(other) != place_key(gig.origin))
	gig.destination = others[rng.randi() % others.size()]
	gig.thing = type.things[rng.randi() % type.things.size()]
	gig.cargo_kg = snappedf(rng.randf_range(type.lightest, type.heaviest), type.mass_step)
	var route: float = UP_DELTA_V[_route_kind(gig.origin)] + DOWN_DELTA_V[_route_kind(gig.destination)]
	gig.route_delta_v = route / Units.METERS_PER_UNIT
	gig.payout = roundi((type.base_pay + route * type.pay_per_delta_v + gig.cargo_kg / 1000.0 * type.pay_per_tonne) / 100.0) * 100
	gig.title = "%s: %s" % [type.label, gig.thing]
	var to: String = place_name(gig.destination)
	gig.description = "Carry %s kg of %s from %s to %s, in the cockpit. Paid once it's unloaded there; lose the ship and it's lost with it." % [Units.grouped(roundi(gig.cargo_kg)), gig.thing.to_lower(), place_name(gig.origin), to]
	var arrive: String = "DOCK AT %s" % place_tag(gig.destination) if gig.destination["kind"] == "station" else "LAND ON THE %s PAD" % place_tag(gig.destination)
	gig.objectives = PackedStringArray(["LOAD %s KG OF %s" % [Units.grouped(roundi(gig.cargo_kg)), gig.thing.to_upper()], arrive, "UNLOAD THE CARGO"])


func _make_survey(gig: Gig, rng: RandomNumberGenerator) -> void:
	var type: GigType = gig.type
	var worlds: Array = _bodies.keys()
	worlds.sort()
	var world: int = worlds[rng.randi() % worlds.size()]
	gig.thing = type.things[rng.randi() % type.things.size()]
	var columns: int = roundi(TAU * _gravity_model.get_body_radius(world) / 2.0)
	var column: int = rng.randi() % columns
	# Dry land only on a world with seas.
	var data: BodyData = _bodies[world]
	if data.body_kind != "AIRLESS":
		for attempt in range(40):
			var strip: PackedFloat32Array = _gravity_model.get_ground_strip(world, column, 1, 1)
			if strip[1] >= SEA_BAND:
				break
			column = rng.randi() % columns
	gig.destination = {"kind": "survey", "world": world, "column": column, "name": gig.thing}
	var route: float = UP_DELTA_V[_route_kind(gig.origin)] + DOWN_DELTA_V[_route_kind(gig.destination)]
	gig.route_delta_v = route / Units.METERS_PER_UNIT
	gig.payout = roundi((type.base_pay + route * type.pay_per_delta_v) / 100.0) * 100
	gig.title = "%s: %s" % [type.label, gig.thing]
	gig.description = "Land within %s of the %s on %s, scan it, and send the data home. Paid once it reaches the agency, which takes a relay in sight: Kapteyn-3 or a base. Lose the ship before then and the data's lost." % [Units.distance_text(type.site_reach).to_lower(), gig.thing.to_lower(), _world_name(world)]
	gig.objectives = PackedStringArray(["LAND WITHIN %s OF THE SITE" % Units.distance_text(type.site_reach), "SCAN THE SITE", "UPLINK THE DATA"])


# A survey's steps: landed near the spot, a scan running there, then the data sent once a relay's in
# sight.
func _track_survey(delta: float) -> void:
	var near: bool = _ship_near_survey(active)
	if active.step == 0 and near:
		active.step = 1
		gig_changed.emit(active)
	elif active.step == 1:
		if not near:
			active.scanning = false
			active.step = 0
			gig_changed.emit(active)
		elif active.scanning:
			active.scan_share = minf(active.scan_share + delta / active.type.scan_seconds, 1.0)
			if active.scan_share >= 1.0:
				active.scanning = false
				active.step = 2
				message_raised.emit("SCAN COMPLETE: DATA STORED", true)
				gig_changed.emit(active)
	elif active.step == 2:
		_relay_wait -= delta
		if _relay_wait <= 0.0:
			_relay_wait = RELAY_CHECK_SECONDS
			relay_in_sight = _relay_in_sight()
			if relay_in_sight:
				_pay(active, "DATA UPLINKED")


func _start_scan() -> void:
	if active != null and active.type.kind == "survey" and active.step == 1:
		active.scanning = true
		message_raised.emit("SCANNING", true)
		gig_changed.emit(active)


# Landed within reach of the survey spot, measured along the ground.
func _ship_near_survey(gig: Gig) -> bool:
	var state: ShipState = _ship.state
	var world: int = gig.destination["world"]
	if not state.is_on_surface() or _gravity_model.get_dominant_body(state.x, state.y, state.time) != world:
		return false
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, state.time)
	var radius: float = _gravity_model.get_body_radius(world)
	var ship_angle: float = atan2(state.x - center[0], center[1] - state.y)
	return absf(angle_difference(ship_angle, _survey_angle(gig.destination, state.time))) * radius <= gig.type.site_reach


# Whether the ship can see Kapteyn-3 or a base, with no world in the way.
func _relay_in_sight() -> bool:
	var state: ShipState = _ship.state
	var from := Vector2(state.x, state.y)
	var relays: Array = [place_point({"kind": "station"})]
	for site: SiteView in _sites:
		relays.append(site.middle(state.time))
	for relay: PackedFloat64Array in relays:
		if _clear_line(from, Vector2(relay[0], relay[1]), state.time):
			return true
	return false


func _clear_line(from: Vector2, to: Vector2, time: float) -> bool:
	for world: int in _bodies.keys():
		var center: PackedFloat64Array = _gravity_model.get_body_position(world, time)
		var middle := Vector2(center[0], center[1])
		var along: Vector2 = to - from
		var share: float = clampf((middle - from).dot(along) / maxf(along.length_squared(), 1.0), 0.0, 1.0)
		if (from + along * share).distance_to(middle) < _gravity_model.get_body_radius(world) - 1.0:
			return false
	return true


func _survey_angle(place: Dictionary, time: float) -> float:
	var world: int = place["world"]
	var data: BodyData = _bodies[world]
	return (place["column"] + 0.5) * 2.0 / _gravity_model.get_body_radius(world) + data.spin_rate * time


# The survey spot on the ground, or up from it, or along the ground from it, in world units.
func _survey_point(place: Dictionary, time: float, up: float = 0.0, along: float = 0.0) -> PackedFloat64Array:
	var world: int = place["world"]
	var radius: float = _gravity_model.get_body_radius(world)
	var center: PackedFloat64Array = _gravity_model.get_body_position(world, time)
	var angle: float = _survey_angle(place, time) + along / radius
	var way := Vector2(sin(angle), -cos(angle))
	var ground: float = _gravity_model.get_ground_height(center[0] + way.x * radius, center[1] + way.y * radius, time)
	var reach: float = radius + ground + up
	return PackedFloat64Array([center[0] + way.x * reach, center[1] + way.y * reach])


func _world_name(world: int) -> String:
	var data: BodyData = _bodies.get(world)
	return data.display_name if data != null else ""
