# world_catalog.gd: what's known about everything the camera can focus on, for the cards the pilot
# holds a finger on. A body shows its numbers once the ship has been inside its sphere of influence,
# since an orbit reveals its mass, and scanning will fill in the rest. From DESIGN.md, "UI" (planet
# info).
class_name WorldCatalog
extends RefCounted

## The gravitational constant, with one world unit counting as one meter.
const G: float = 6.674e-11

var _gravity_model: GravityModel
var _state: ShipState
var _ship: Node2D
var _pilot: Node2D
var _bodies: Dictionary = {}
var _stations: Dictionary = {}
var _sites: Array[SiteView] = []
var _home_gravity: float = 1.0
var _visited: Dictionary = {}


func _init(gravity_model: GravityModel, state: ShipState, ship: Node2D, home_gravity: float) -> void:
	_gravity_model = gravity_model
	_state = state
	_ship = ship
	_home_gravity = home_gravity


## Tells it about the pilot.
func set_pilot(pilot: Node2D) -> void:
	_pilot = pilot


func add_body(index: int, data: BodyData) -> void:
	_bodies[index] = data


## A place built on a world, in the order the view numbers them.
func add_site(site: SiteView) -> void:
	_sites.append(site)


func add_station(index: int, design: StationDesign, reach: float, free_ports: int) -> void:
	_stations[index] = {"design": design, "reach": reach, "free_ports": free_ports}


func on_flight_data(_data: Dictionary) -> void:
	_visited[_gravity_model.get_dominant_body(_state.x, _state.y, _state.time)] = true


## The short name to put on a marker.
func callsign_of(thing: Dictionary) -> String:
	match thing["kind"]:
		"body":
			return _bodies[thing["index"]].display_name
		"satellite":
			return _stations[thing["index"]]["design"].callsign
		"pilot":
			return "PILOT"
		"site":
			return _sites[thing["index"]].data.callsign
	return "SHIP"


## How far it reaches from its middle, in world units.
func reach_of(thing: Dictionary) -> float:
	match thing["kind"]:
		"body":
			return _gravity_model.get_body_radius(thing["index"])
		"satellite":
			return _stations[thing["index"]]["reach"]
		"pilot":
			return 24.0
		"site":
			return _sites[thing["index"]].reach()
	return 110.0


## Everything a card shows: a "name", a "chip" saying what kind of thing it is, "rows" of
## [label, value, known], a "note", and whether it "can_target".
func info_of(thing: Dictionary) -> Dictionary:
	match thing["kind"]:
		"body":
			return _body_info(thing["index"])
		"satellite":
			return _station_info(thing["index"])
		"pilot":
			return _pilot_info()
		"site":
			return _site_info(thing["index"])
	return _ship_info()


func _body_info(index: int) -> Dictionary:
	var data: BodyData = _bodies[index]
	if index == 0:
		return _star_info(data)
	var known: bool = _visited.has(index)
	var moons: int = 0
	for other: int in _bodies:
		if other != index and _gravity_model.get_body_parent(other) == index:
			moons += 1
	var mu: float = data.surface_gravity * data.radius * data.radius
	var rows: Array = [
		["SIZE (R)", _km(data.radius) if known else "???", known],
		["MASS", _mass(mu) if known else "???", known],
		["GRAVITY", ("%.2f g" % (data.surface_gravity / _home_gravity)) if known else "???", known],
		["TEMP", "???", false],
		["ATM", "???", false],
		["MOONS", str(moons), true],
		["DAY LENGTH", _day_length(data.spin_rate) if known else "???", known],
	]
	return {"name": data.display_name, "chip": data.body_kind, "rows": rows,
			"note": "Scan to reveal" if known else "Orbit to reveal", "can_target": true}


func _star_info(data: BodyData) -> Dictionary:
	var planets: int = 0
	for other: int in _bodies:
		if other != 0 and _gravity_model.get_body_parent(other) == 0:
			planets += 1
	var mu: float = data.surface_gravity * data.radius * data.radius
	var away: float = Vector2(_state.x, _state.y).length()
	var rows: Array = [
		["SIZE (R)", _km(data.radius), true],
		["MASS", _mass(mu), true],
		["TEMP", "%s K" % _grouped(int((data as StarData).temperature)), true],
		["PLANETS", str(planets), true],
		["DISTANCE", _km(away), true],
	]
	return {"name": data.display_name, "chip": data.body_kind, "rows": rows, "note": "", "can_target": true}


func _station_info(index: int) -> Dictionary:
	var entry: Dictionary = _stations[index]
	var design: StationDesign = entry["design"]
	var parent: int = _gravity_model.get_satellite_parent(index)
	var at: PackedFloat64Array = _gravity_model.get_satellite_position(index, _state.time)
	var parent_at: PackedFloat64Array = _gravity_model.get_body_position(parent, _state.time)
	var moving: PackedFloat64Array = _gravity_model.get_satellite_velocity(index, _state.time)
	var parent_moving: PackedFloat64Array = _gravity_model.get_body_velocity(parent, _state.time)
	var radius: float = Vector2(at[0] - parent_at[0], at[1] - parent_at[1]).length()
	var speed: float = Vector2(moving[0] - parent_moving[0], moving[1] - parent_moving[1]).length()
	var away: float = Vector2(at[0] - _state.x, at[1] - _state.y).length()
	var rows: Array = [
		["ORBITS", _bodies[parent].display_name, true],
		["ALTITUDE", _meters(radius - _gravity_model.get_body_radius(parent)), true],
		["PERIOD", _minutes(TAU * radius / speed), true],
		["ROOMS", str(design.rooms.size()), true],
		["FREE PORTS", str(entry["free_ports"]), true],
		["SERVICES", "FUEL, REPAIR", true],
		["DISTANCE", _meters(away), true],
	]
	return {"name": design.display_name, "chip": design.chip, "rows": rows, "note": "", "can_target": true}


func _site_info(index: int) -> Dictionary:
	var site: SiteView = _sites[index]
	var at: PackedFloat64Array = site.middle(_state.time)
	var away: float = Vector2(at[0] - _state.x, at[1] - _state.y).length()
	var rows: Array = [
		["ON", _bodies[site.world].display_name, true],
		["BUILDINGS", str(site.data.buildings.size()), true],
		["PAD", _meters(site.data.pad_width) if site.data.pad_width > 0.0 else "NONE", true],
		["SERVICES", ", ".join(site.data.services), true],
		["DISTANCE", _meters(away), true],
	]
	return {"name": site.data.display_name, "chip": site.data.chip, "rows": rows, "note": "", "can_target": true}


func _ship_info() -> Dictionary:
	var status: Dictionary = _ship.status()
	var rows: Array = [
		["MASS", "%s kg" % _grouped(int(status["mass"])), true],
		["FUEL", "%d%%" % roundi(status["fuel_share"] * 100.0), true],
		["ΔV", _speed(status["delta_v"]), true],
		["HULL", "%d%%" % roundi(status["hull_share"] * 100.0), true],
		["ENGINE", "%d%%" % roundi(status["engine_share"] * 100.0), true],
		["LEGS", "DOWN" if status["legs_down"] else "UP", true],
	]
	return {"name": status["name"], "chip": status["chip"], "rows": rows, "note": "", "can_target": false}


func _pilot_info() -> Dictionary:
	var away := Vector2(_pilot.state.x - _state.x, _pilot.state.y - _state.y).length()
	var rows: Array = [
		["JETPACK", "%d%%" % roundi(_pilot.gas / _pilot.data.jet_seconds * 100.0), true],
		["ΔV", _speed(_pilot.gas * _pilot.data.jet_acceleration), true],
		["SHIP", _meters(away), true],
	]
	var chip: String = {Pilot.EVA: "ON EVA", Pilot.SURFACE: "ON FOOT"}.get(_pilot.mode, "INSIDE")
	return {"name": "Pilot", "chip": chip, "rows": rows, "note": "", "can_target": false}


# Thousands split with commas.
func _grouped(value: int) -> String:
	return Units.grouped(value)


# Sizes and distances are in world units, shown in real ones at the pilot's scale.
func _km(units: float) -> String:
	var km: float = Units.meters(units) / 1000.0
	return ("%.1f km" % km) if km < 100.0 else "%s km" % _grouped(roundi(km))


func _meters(units: float) -> String:
	return Units.distance_text(units).to_lower()


func _speed(units_per_second: float) -> String:
	return Units.speed_text(units_per_second).to_lower()


func _mass(mu: float) -> String:
	var kilograms: float = Units.kilograms_from_mu(mu, G)
	var power: int = floori(log(kilograms) / log(10.0))
	var raised: String = ""
	for digit: String in str(power):
		raised += "⁰¹²³⁴⁵⁶⁷⁸⁹"[int(digit)]
	return "%.2f × 10%s kg" % [kilograms / pow(10.0, power), raised]


func _day_length(spin_rate: float) -> String:
	if spin_rate == 0.0:
		return "NONE"
	var minutes: int = roundi(TAU / absf(spin_rate) / 60.0)
	return "%d h %d m" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d m" % minutes


func _minutes(seconds: float) -> String:
	return "%d m %d s" % [int(seconds) / 60, int(seconds) % 60]
