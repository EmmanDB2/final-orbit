# import_station.gd: turns a station's JSON (what tools/export_kapteyn_standin.py writes, or, later, the
# Asset Editor's export in the same shape) into the game's data: data/kapteyn_3.tres for the station and
# data/station_props/<id>.tres for each prop, so later stations come in the same way. It reads each
# module's four layers from art/kapteyn_3/, and the props and hatch pieces from art/station_props/.
#
# STAND-IN: this run reads art/kapteyn_3/standin/ and art/station_props/standin/, Gemini's round 1
# concept pixels, to be replaced by round 2. Change STAND_IN to the final folders when they arrive.
#
# Run it with the PNGs already imported:
#   godot --headless --path . --import
#   godot --headless --path . -s tools/import_station.gd
# From docs/briefs/kapteyn_3.md, tickets 6 and 6a.
extends SceneTree

const STAND_IN: bool = true
const STATION_ART: String = "res://art/kapteyn_3/standin/"
const PROP_ART: String = "res://art/station_props/standin/"
const JSON_PATH: String = "res://art/kapteyn_3/standin/kapteyn_3_standin.json"
const STATION_OUT: String = "res://data/kapteyn_3.tres"
const PROPS_OUT: String = "res://data/station_props/"
## What the old Kapteyn-3 had, kept so gigs, targets, and saves carry over.
const KEEP_FROM_OLD: Array[String] = ["display_name", "chip", "callsign", "powered", "emergency_every", "failing_every",
		"emergency_brightness", "emergency_reach_share", "dark_ambient", "ambient_light", "lamp_brightness",
		"dock_reach", "dock_across", "dock_speed", "dock_angle_degrees", "orbit_altitude", "orbit_eccentricity",
		"orbit_argument_of_periapsis", "orbit_start_angle"]
## Props whose spot is theirs whatever the placement says, and the plant that gets a green ramp.
const SPOT_OF_PROP: Dictionary = {"gig_board": "gig_board", "service_terminal": "service", "breaker_panel": "power"}
const PLANTS: Array[String] = ["planter"]


func _initialize() -> void:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("No station JSON at %s" % JSON_PATH)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROPS_OUT))
	var props: Dictionary = _make_props(data)
	var design := StationDesign.new()
	var old: StationDesign = load("res://data/station_1.tres")
	for name_to_keep: String in KEEP_FROM_OLD:
		design.set(name_to_keep, old.get(name_to_keep))
	design.art_pixel_size = 1.0
	design.home_port = data["home_port"]
	design.legacy_ports = PackedStringArray(data["legacy_ports"])
	design.hatch_floor = load(PROP_ART + "hatch_floor.png")
	design.hatch_walls = load(PROP_ART + "hatch_walls.png")
	design.hatch_overhead = load(PROP_ART + "hatch_overhead.png")
	design.hatch_roof = load(PROP_ART + "hatch_roof.png")
	design.hatch_door_left = load(PROP_ART + "hatch_door_left.png")
	design.hatch_door_right = load(PROP_ART + "hatch_door_right.png")
	design.docking_ring_roof = load(PROP_ART + "docking_ring_roof.png")
	design.capped_plate = load(PROP_ART + "capped_plate.png")
	# The leaves of the standard hatch: closed they meet in the opening, open they slide into the walls.
	design.door_left_closed = Vector2i(6, 17)
	design.door_left_open = Vector2i(-7, 17)
	design.door_right_closed = Vector2i(24, 17)
	design.door_right_open = Vector2i(37, 17)
	var modules: Array[StationModule] = []
	for entry: Dictionary in data["modules"]:
		modules.append(_make_module(entry, props))
	design.modules = modules
	var err: Error = ResourceSaver.save(design, STATION_OUT)
	if err != OK:
		push_error("Couldn't save the station: %s" % error_string(err))
		quit(1)
		return
	_mark_stand_in(STATION_OUT)
	print("wrote %s with %d modules and %d props" % [STATION_OUT, modules.size(), props.size()])
	quit()


# Every prop the placements use, saved as data/station_props/<id>.tres. A prop used with a spot its
# own isn't, like the one bed the pilot wakes in, is saved again as <id>_<spot>.
func _make_props(data: Dictionary) -> Dictionary:
	var made: Dictionary = {}
	var wanted: Dictionary = {}
	for module: Dictionary in data["modules"]:
		for placement: Dictionary in module["props"]:
			wanted[_prop_key(placement)] = placement
	for key: String in wanted:
		var placement: Dictionary = wanted[key]
		var id: String = placement["id"]
		var info: Dictionary = data["props"][id]
		var prop := StationProp.new()
		prop.id = key
		prop.texture = load(PROP_ART + id + ".png")
		prop.layer = info.get("layer", "floor")
		if info.has("footprint"):
			var f: Array = info["footprint"]
			prop.footprint = Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
			prop.lip = int(info.get("lip", 0))
		prop.spot_kind = _spot_of(placement)
		prop.plant = PLANTS.has(id)
		var path: String = PROPS_OUT + key + ".tres"
		ResourceSaver.save(prop, path)
		_mark_stand_in(path)
		made[key] = load(path)
	return made


func _spot_of(placement: Dictionary) -> String:
	if placement.get("spot", "") != "":
		return placement["spot"]
	return SPOT_OF_PROP.get(placement["id"], "")


func _prop_key(placement: Dictionary) -> String:
	var own: String = SPOT_OF_PROP.get(placement["id"], "")
	var spot: String = _spot_of(placement)
	return placement["id"] if spot == own else "%s_%s" % [placement["id"], spot]


func _make_module(entry: Dictionary, props: Dictionary) -> StationModule:
	var id: String = entry["id"]
	var module := StationModule.new()
	module.display_name = entry["display_name"]
	module.canvas_size = Vector2i(int(entry["canvas"][0]), int(entry["canvas"][1]))
	module.floor_texture = load("%s%s_floor.png" % [STATION_ART, id])
	module.walls_texture = load("%s%s_walls.png" % [STATION_ART, id])
	module.roof_texture = load("%s%s_roof.png" % [STATION_ART, id])
	module.bolts_to_module = int(entry.get("bolts_to_module", -1))
	module.bolts_to_port = entry.get("bolts_to_port", "")
	module.own_port = entry.get("own_port", "")
	for rect: Array in entry["floors"]:
		module.floors.append(Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])))
	for port_data: Dictionary in entry["ports"]:
		module.ports.append(_make_port(port_data))
	for door: Dictionary in entry["doors"]:
		module.doors.append(_make_port({"name": door["name"], "kind": "inner", "point": door["point"], "face": door["face"]}))
	for placement: Dictionary in entry["props"]:
		var put := PropPlacement.new()
		put.prop = props[_prop_key(placement)]
		put.position = Vector2i(int(placement["position"][0]), int(placement["position"][1]))
		put.turns = int(placement["turns"])
		module.props.append(put)
	for fixture_data: Dictionary in entry["fixtures"]:
		var fixture := LightFixture.new()
		fixture.point = Vector2(fixture_data["point"][0], fixture_data["point"][1])
		fixture.reach_metres = fixture_data["reach_m"]
		fixture.tint = fixture_data["tint"]
		fixture.circuit = fixture_data["circuit"]
		module.fixtures.append(fixture)
	for rect: Array in entry["windows"]:
		module.windows.append(Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])))
	for light_data: Dictionary in entry["outside_lights"]:
		var light := OutsideLight.new()
		light.point = Vector2(light_data["point"][0], light_data["point"][1])
		light.kind = light_data["kind"]
		light.port_name = light_data["port"]
		module.outside_lights.append(light)
	return module


func _make_port(port_data: Dictionary) -> StationPort:
	var port := StationPort.new()
	port.port_name = port_data["name"]
	port.kind = port_data["kind"]
	port.point = Vector2i(int(port_data["point"][0]), int(port_data["point"][1]))
	port.face = Vector2i(int(port_data["face"][0]), int(port_data["face"][1]))
	return port


# A comment under the file's first line, saying this is stand-in art.
func _mark_stand_in(path: String) -> void:
	if not STAND_IN:
		return
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = text.split("\n")
	lines.insert(1, "; STAND-IN: drawn from Gemini's round 1 concept (art/*/standin/), to be replaced by round 2. Made by tools/import_station.gd.")
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string("\n".join(lines))
