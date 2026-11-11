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

@export var gig_types: Array[GigType] = [preload("res://data/gigs/cargo.tres")]
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
var _sites: Array = []
# For each board, by place: its slots, each a gig or null once taken, and how many times each slot
# has been filled, so a taken gig is replaced by a new one.
var _boards: Dictionary = {}
var _rounds: Dictionary = {}
var _next_id: int = 1


func start(gravity_model: GravityModel, ship: Node2D, pilot: Pilot, station: Node2D, station_design: StationDesign, sites: Array) -> void:
	_gravity_model = gravity_model
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
	var delta_v: float = _ship.delta_v_with(gig.cargo_kg)
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
	gig_changed.emit(gig)
	return true


## What the agency adds to the context menu right now: each a "label", a "target" giving box corners
## in the world, and what to "run" when it's picked.
func options() -> Array:
	if active == null or _pilot.mode != Pilot.ABOARD:
		return []
	if active.type.kind == "cargo" and active.step == 2:
		return [{"label": "UNLOAD CARGO", "target": _place_box(active.destination), "run": _deliver}]
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
	return PackedFloat64Array()


## A place's full name, such as Kepla Moon Base.
func place_name(place: Dictionary) -> String:
	match place.get("kind", ""):
		"station":
			return _station_design.display_name
		"site":
			return _sites[place["index"]].data.display_name
	return ""


## A place's short name in capitals, such as MOON BASE.
func place_tag(place: Dictionary) -> String:
	match place.get("kind", ""):
		"station":
			return _station_design.callsign
		"site":
			return _sites[place["index"]].data.chip
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


func _physics_process(_delta: float) -> void:
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
	active.state = "failed"
	active = null
	message_raised.emit("GIG FAILED: CARGO LOST", false)
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
	return Callable()


# The kind of place, for the route's delta-v: the station's orbit, a planet, or a moon.
func _route_kind(place: Dictionary) -> String:
	if place.get("kind", "") == "site":
		var world: int = _sites[place["index"]].world
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
	var total: float = 0.0
	for type: GigType in gig_types:
		total += type.weight
	var pick: float = rng.randf() * total
	var type: GigType = gig_types[0]
	for candidate: GigType in gig_types:
		pick -= candidate.weight
		if pick <= 0.0:
			type = candidate
			break
	var gig := Gig.new()
	gig.id = _next_id
	_next_id += 1
	gig.type = type
	gig.origin = place
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
