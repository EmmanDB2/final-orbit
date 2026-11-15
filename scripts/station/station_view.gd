# station_view.gd: a station where its rails put it, at true scale, turning with its orbit so its
# bottom always faces the body below. Farther out it's a marker dot. Its pixels are solid, and a ship
# that brings its hatch slowly and straight onto a free port docks there. Inside, a station of modules
# is drawn in layers: the floor and walls under everything, then the pilot, standing props, and hatch
# doors sorted by how far down their feet or bases are (a prop's base lower than the pilot's feet
# draws over them, higher draws under), then the overhead pipes and lintels, then the roof, which
# fades off. A station of old rooms has just the one inside picture.
# From DESIGN.md, "Universe generation" (stations are hubs), "Core loop" (a run ends docked), and
# "Camera, zoom, and landing".
class_name StationView
extends Node2D

## Emitted when the pilot should be told why a docking didn't take.
signal message_raised(text: String)
## Emitted when an airlock's cycle ends: which port it's on, and whether the pilot's going out.
signal airlock_cycle_done(port: int, going_out: bool)
## Emitted when the station's power is switched on or off.
signal powered_changed(on: bool)

## The station shows as a dot at this zoom and farther.
@export var dot_max_zoom: float = 1.0 / 256.0
## How far apart to check the ship's outline against the station, in world units.
@export var contact_spacing: float = 4.0
## The most the ship gets pushed out of the station in one tick, in world units.
@export var most_push: float = 64.0
## How far the ship's outline can reach from its center, in world units, plus some room.
@export var ship_reach: float = 180.0
## This close to the station's middle, the pilot's speed and markers read against it, in world units.
@export var nearby_reach: float = 2000.0
## The closest free port shows its line this close to it, and the line is this long, in world units.
@export var guide_reach: float = 700.0
@export var guide_length: float = 320.0
## The port's line only shows at this zoom and closer.
@export var guide_max_zoom: float = 1.0 / 8.0
## How fast a docked ship is drawn the last bit into place, in world units and radians per second.
@export var pull_speed: float = 24.0
@export var pull_turn: float = 0.6
## How far the hatch has to get from a port after undocking before it can dock again.
@export var undock_clear: float = 60.0
## How long between telling the pilot why a docking didn't take, in seconds.
@export var message_seconds: float = 3.0
## How far inside a port's outer edge its inner door is, in world units.
@export var port_door_depth: float = 44.0
## The most lamps the insides' shader takes.
const INTERIOR_LAMPS: int = 64
## The strobe flashes for this long every this long, in seconds. A floodlight lights the hull this far,
## in metres.
const STROBE_FLASH_SECONDS: float = 0.1
const STROBE_EVERY_SECONDS: float = 1.5
const FLOOD_REACH_METRES: float = 6.0
## The most floodlights the hull's shader takes.
const MOST_FLOODS: int = 8
## How long an airlock takes to cycle, in seconds, and how long its outer door stays open after.
const CYCLE_SECONDS: float = 2.5
const OUTER_OPEN_AFTER_SECONDS: float = 2.0
## The kinds of port: an old station's, which docks, lets the pilot in and out, and takes EVA; a docking
## collar, which only ships dock at; and an airlock, which only the pilot goes in and out of.
const LEGACY: String = "legacy"
const DOCK: String = "dock"
const AIRLOCK: String = "airlock"
## How long an emergency lamp's pulse takes, in seconds.
const EMERGENCY_PULSE_SECONDS: float = 2.4
## With the power on, a failing fixture flickers out for a moment every so often: how long it waits
## between flickers and how long each lasts, in seconds, each from the first to the second.
const FAILING_EVERY_SECONDS := Vector2(4.0, 10.0)
const FAILING_OUT_SECONDS := Vector2(0.05, 0.15)
## How long the roof takes to come off, in seconds.
@export var roof_seconds: float = 0.3
## How wide the pilot is across the shoulders as a radius when walking inside, in the station's art
## pixels: a station drawn at their own scale lets them through gaps their real width fits.
const PILOT_HALF_WIDTH_PIXELS: float = 6.0
## How far below the pilot's middle their feet are for sorting against props, in world units.
@export var pilot_feet: float = 6.0
## Which layer of depth each kind of thing is drawn at inside, in order: the pilot sits between the
## props that are behind them and the props in front.
const Z_BEHIND: int = 1
const Z_PILOT: int = 2
const Z_FRONT: int = 3
const Z_OVERHEAD: int = 4

var layout: StationLayout
## Which free port the ship's docked at, or -1.
var docked_port: int = -1

var _gravity_model: GravityModel
var _state: ShipState
var _design: StationDesign
var _index: int = 0
var _sprite := Sprite2D.new()
var _inside_sprite := Sprite2D.new()
# A station of modules: everything inside hangs off one node that's scaled to the zoom.
var _modular: bool = false
var _inside := Node2D.new()
var _stands: Array[Dictionary] = []
var _doors: HatchDoors
# Where the pilot is on the station's picture while they're inside, and whether they are.
var _pilot_at := Vector2.ZERO
var _pilot_inside: bool = false
# Every material the insides are drawn with, and the values their shared settings have now.
var _lit_materials: Array[ShaderMaterial] = []
var _light_params: Dictionary = {}
# A station whose modules set fixtures is lit the planned way: baked once, from its data, into maps with
# a channel per power circuit; the power, the flicker, and the pulse are only how live each circuit is.
var _planned: bool = false
var _baked_maps: Dictionary = {}
var _failing_out: bool = false
var _failing_wait: float = 0.0
# The insides' light map, worked out on a worker thread, and that work while it's under way.
var _light_task: int = -1
var _baked_light: Image
var _powered: bool = true
var _hull_task: int = -1
var _hull_material: ShaderMaterial
var _light_time: float = 0.0
var _sputter_on: bool = false
var _sputter_left: float = 0.0
var _roof_off: bool = false
var _roof_gone: float = 0.0
var _show_dot: bool = false
var _ship: Node2D
var _contact_range: float = 0.0
var _pixels_per_unit: float = 1.0
var _roll: float = 0.0
# Where the free ports are in the station's own frame, in world units: "at" and "face".
var _ports: Array[Dictionary] = []
# The airlock cycle under way: its "port", whether it's "out", and "time" through it, or empty.
var _cycle: Dictionary = {}
var _lamps: AirlockLamps
# What glows on the outside, and how long it's been running, for the strobe.
var _glow: OutsideGlow
var _outside_time: float = 0.0
# The port nearest the hatch, while it's close enough to show.
var _guide_port: int = -1
var _guide_ready: bool = false
var _was_docked: bool = false
var _leaving_port: bool = false
var _dock_place := Vector2.ZERO
var _dock_goal := Vector2.ZERO
var _dock_heading: float = 0.0
var _dock_goal_heading: float = 0.0
var _last_message: float = -100.0


## Starts drawing a station, given its satellite number in the gravity model.
func start_station(gravity_model: GravityModel, state: ShipState, design: StationDesign, index: int, ship: Node2D) -> void:
	_gravity_model = gravity_model
	_state = state
	_design = design
	_index = index
	_ship = ship
	layout = StationLayout.build(design)
	# Before the ship's tick, so a hit changes the move it's about to make.
	process_physics_priority = -5
	var far_corner := Vector2(layout.origin).max(Vector2(layout.image.get_size() - layout.origin))
	_contact_range = far_corner.length() * design.art_pixel_size + ship_reach
	# The ports a ship can dock at, and for a station of modules the airlocks after them.
	for port: Dictionary in layout.free_ports:
		_add_port(port, DOCK if layout.modular else LEGACY)
	for port: Dictionary in layout.airlock_ports:
		_add_port(port, AIRLOCK)
	_sprite.texture = ImageTexture.create_from_image(layout.image)
	# Its outside is lit by the star once its curvature's worked out, off to the side, as it's big.
	var outside: Image = layout.image
	_hull_task = WorkerThreadPool.add_task(func() -> void: _hull_material = HullLight.material_for(outside))
	_sprite.centered = false
	_sprite.offset = -Vector2(layout.origin)
	if layout.modular:
		_glow = OutsideGlow.new()
		_glow.origin = Vector2(layout.origin)
		_glow.windows = layout.windows
		_glow.lights = layout.outside_lights
		_sprite.add_child(_glow)
	_powered = design.powered
	_modular = layout.modular
	_planned = _modular and not layout.fixtures.is_empty()
	_failing_wait = randf_range(FAILING_EVERY_SECONDS.x, FAILING_EVERY_SECONDS.y)
	# Under the roof, which fades off it.
	if _modular:
		_build_modular_inside()
	else:
		_inside_sprite.texture = ImageTexture.create_from_image(layout.interior_image)
		_inside_sprite.material = _new_lit_material(Vector2.ZERO)
		_inside_sprite.centered = false
		_inside_sprite.offset = -Vector2(layout.origin)
		_inside_sprite.visible = false
		add_child(_inside_sprite)
	_light_inside()
	add_child(_sprite)


# The layers of a station of modules, as children of one node that's scaled to the zoom, so each one's
# position is its pixel on the station's picture less the origin. The floor goes first, then the doors'
# leaves, which slide under the walls, then the walls, then the props that stand, and the overhead layer last.
func _build_modular_inside() -> void:
	_inside.visible = false
	add_child(_inside)
	_inside.add_child(_layer_sprite(layout.floor_image, 0))
	_doors = HatchDoors.new()
	_doors.build(_inside, layout.hatches, _design, layout.origin, _new_lit_material)
	_inside.add_child(_layer_sprite(layout.walls_image, 0))
	for stand: Dictionary in layout.props:
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(stand["image"])
		sprite.centered = false
		sprite.position = Vector2(stand["at"] - layout.origin)
		sprite.z_index = Z_BEHIND
		sprite.material = _new_lit_material(Vector2(stand["at"]))
		if stand["prop"].plant:
			# Its green leaves step down their own ramp instead of glowing.
			sprite.material.set_shader_parameter("plant", true)
		_inside.add_child(sprite)
		_stands.append({"sprite": sprite, "foot": stand["foot"]})
	_inside.add_child(_layer_sprite(layout.overhead_image, Z_OVERHEAD))
	# The airlock's status lamps, either side of each of its doors.
	_lamps = AirlockLamps.new()
	_lamps.z_index = Z_OVERHEAD
	for i in range(_ports.size()):
		if _ports[i]["kind"] != AIRLOCK:
			continue
		for hatch: Dictionary in layout.hatches:
			if hatch["ports"].has(_ports[i]["name"]) and (hatch["kind"] == "airlock" or hatch["kind"] == "door"):
				var across: Vector2 = Vector2(hatch["face"]).orthogonal()
				for side in [-1.0, 1.0]:
					_lamps.lamps.append({"at": hatch["center"] - Vector2(layout.origin) + across * side * 20.0, "airlock": i})
	_inside.add_child(_lamps)
	_sync_collar_doors()


# A layer of the whole station's picture as a sprite, lit.
func _layer_sprite(image: Image, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.offset = -Vector2(layout.origin)
	sprite.z_index = depth
	sprite.material = _new_lit_material(Vector2.ZERO)
	return sprite


# A material the insides are drawn with, for art whose top left corner is here on the station's picture.
# Every one has the same palette and the same lamps, which _set_light_param keeps in step.
func _new_lit_material(corner: Vector2) -> ShaderMaterial:
	var material: ShaderMaterial = PaletteLight.material_for(preload("res://shaders/interior_light.gdshader"))
	for param: String in _light_params:
		material.set_shader_parameter(param, _light_params[param])
	material.set_shader_parameter("sprite_at", corner)
	_lit_materials.append(material)
	return material


# Sets one of the insides' shared settings on every material that draws them, if it's changed.
func _set_light_param(param: String, value: Variant) -> void:
	if _light_params.has(param) and _light_params[param] == value:
		return
	_light_params[param] = value
	for material: ShaderMaterial in _lit_materials:
		material.set_shader_parameter(param, value)


# A port, from the layout's, as the view keeps it: where its hatch is and which way it faces in the
# station's frame, in world units, its kind, and its name.
func _add_port(port: Dictionary, kind: String) -> void:
	var face := Vector2(port["face"])
	var surface: Vector2 = Vector2(port["point"]) + Vector2(0.5, 0.5) + face * 0.5
	var entry: Dictionary = {
		"at": (surface - Vector2(layout.origin)) * _design.art_pixel_size, "face": face,
		"kind": kind, "name": port.get("name", str(_ports.size())),
	}
	if port.has("inner"):
		# A station of modules says where the pilot stands by the port's door.
		entry["inner"] = (Vector2(port["inner"]) - Vector2(layout.origin)) * _design.art_pixel_size
	_ports.append(entry)


# The insides lit by the station's lamps. With the power off, only its emergency lamps pulse and its
# failing ones sputter.
func _light_inside() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_set_light_param("alarm_bright", palette.agency_red)
	_set_light_param("alarm_dim", palette.agency_orange_dark)
	var lit: Array = _lamps_now()
	# Until the light map's ready, the steady lamps light straight through.
	var lamps := PackedVector4Array()
	for lamp: Dictionary in lit:
		if lamp["kind"] == StationLight.STEADY:
			lamps.append(Vector4(lamp["point"].x, lamp["point"].y, lamp["reach"], lamp["brightness"]))
	if _planned:
		_light_planned(lamps)
		return
	var count: int = mini(lamps.size(), INTERIOR_LAMPS)
	lamps.resize(INTERIOR_LAMPS)
	_set_light_param("lamps", lamps)
	_set_light_param("lamp_count", count)
	_set_light_param("baked", false)
	var ambient: float = _design.ambient_light if _powered else _design.dark_ambient
	_set_light_param("ambient", ambient)
	_set_light_param("map_size", Vector2(layout.picture_size()))
	_set_floor_mask()
	# Walls stopping the lamps' light takes a while to work out, so it's done off to the side.
	_wait_for_light()
	_baked_light = null
	var size: Vector2i = layout.picture_size()
	var rooms: Array = layout.room_areas
	_light_task = WorkerThreadPool.add_task(func() -> void: _baked_light = StationLight.bake(size, rooms, lit, ambient))


# The planned way: the fixtures are baked once, whatever the power does, and from then on it's only
# how live each circuit is. Until they're ready, the mains and always fixtures light straight through.
func _light_planned(lamps: PackedVector4Array) -> void:
	_set_light_param("planned", true)
	_set_light_param("map_size", Vector2(layout.picture_size()))
	_set_floor_mask()
	_set_light_param("ambient", _design.ambient_light if _powered else _design.dark_ambient)
	if _baked_maps.is_empty() and _light_task < 0:
		var count: int = mini(lamps.size(), INTERIOR_LAMPS)
		lamps.resize(INTERIOR_LAMPS)
		_set_light_param("lamps", lamps)
		_set_light_param("lamp_count", count)
		var size: Vector2i = layout.picture_size()
		var rooms: Array = layout.room_areas
		var fixtures: Array = layout.fixtures
		_light_task = WorkerThreadPool.add_task(func() -> void: _baked_maps = StationLight.bake_fixtures(size, rooms, fixtures))
	_set_light_param("circuit_live", _circuits_live())


# Where someone can stand, for the helmet lamp's beam to stop at what isn't.
func _set_floor_mask() -> void:
	if not _light_params.has("floor_mask"):
		_set_light_param("floor_mask", ImageTexture.create_from_image(StationLight.floor_mask(layout.picture_size(), layout.floors())))


# How live each power circuit is now, as mains, failing, emergency, always: mains with the power on,
# emergency pulsing with it off, failing flickering out now and then with it on or sputtering with it
# off, and always on whatever the power does.
func _circuits_live() -> Vector4:
	var pulse: float = 0.675 + 0.325 * sin(_light_time * TAU / EMERGENCY_PULSE_SECONDS)
	var failing: float
	if _powered:
		failing = 0.0 if _failing_out else 1.0
	else:
		failing = 1.0 if _sputter_on else 0.0
	return Vector4(1.0 if _powered else 0.0, failing, 0.0 if _powered else pulse, 1.0)


# Each lamp as the power has it: all steady with it on; with it off, some emergency lamps and some
# failing ones, and the rest dark.
func _lamps_now() -> Array:
	var lit: Array = []
	if _planned:
		# Only for what shows until the fixtures' maps are ready.
		for fixture: Dictionary in layout.fixtures:
			var circuit: String = fixture["circuit"]
			if circuit == LightFixture.ALWAYS or (_powered and circuit != LightFixture.EMERGENCY):
				lit.append({"point": fixture["point"], "reach": fixture["reach"], "room": fixture["room"], "brightness": fixture["brightness"], "kind": StationLight.STEADY})
		return lit
	for i in range(layout.lamps.size()):
		var lamp: Dictionary = layout.lamps[i].duplicate()
		if _powered:
			lamp["kind"] = StationLight.STEADY
			lamp["brightness"] = _design.lamp_brightness
		elif _design.emergency_every > 0 and i % _design.emergency_every == 0:
			lamp["kind"] = StationLight.EMERGENCY
			lamp["brightness"] = _design.emergency_brightness
			lamp["reach"] = lamp["reach"] * _design.emergency_reach_share
		elif _design.failing_every > 0 and i % _design.failing_every == 1:
			lamp["kind"] = StationLight.FAILING
			lamp["brightness"] = _design.lamp_brightness
		else:
			continue
		lit.append(lamp)
	return lit


## Turns the station's power on or off, and its lamps with it.
func set_powered(on: bool) -> void:
	if on == _powered:
		return
	_powered = on
	_light_inside()
	powered_changed.emit(on)


func is_powered() -> bool:
	return _powered


# Once the light map's ready, the insides use it.
func _pick_up_light() -> void:
	if _light_task < 0 or not WorkerThreadPool.is_task_completed(_light_task):
		return
	_wait_for_light()
	if _planned:
		if not _baked_maps.is_empty() and not _lit_materials.is_empty():
			_set_light_param("circuit_light", ImageTexture.create_from_image(_baked_maps["light"]))
			_set_light_param("warm_share", ImageTexture.create_from_image(_baked_maps["warm"]))
			_set_light_param("red_share", ImageTexture.create_from_image(_baked_maps["red"]))
			_set_light_param("baked", true)
		return
	if _baked_light != null and not _lit_materials.is_empty():
		_set_light_param("light_map", ImageTexture.create_from_image(_baked_light))
		_set_light_param("baked", true)


func _wait_for_light() -> void:
	if _light_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_light_task)
		_light_task = -1


func _exit_tree() -> void:
	_wait_for_light()
	if _hull_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hull_task)
		_hull_task = -1


# What an approach light at a docking collar shows: "amber" while the collar's free, "green" while a ship
# is lined up to dock there, and "off" while one's docked there, or with the power off.
func approach_light(port_name: String) -> String:
	if not _powered:
		return "off"
	for i in range(_ports.size()):
		if _ports[i]["name"] == port_name and _ports[i]["kind"] == DOCK:
			if docked_port == i:
				return "off"
			return "green" if _guide_port == i and _guide_ready else "amber"
	return "off"


# Whether the strobe's flashing at this moment.
func strobe_on() -> bool:
	return fmod(_outside_time, STROBE_EVERY_SECONDS) < STROBE_FLASH_SECONDS


# The lights that glow on the outside: windows, nav lights, the strobe, and the approach lights, and the
# floodlights lighting the hull round each docking collar while it's powered.
func _light_glow(delta: float) -> void:
	if _glow == null:
		return
	_outside_time += delta
	var approach := {}
	for light: Dictionary in layout.outside_lights:
		if light["kind"] == OutsideLight.APPROACH:
			approach[light["port"]] = approach_light(light["port"])
	_glow.set_state(_powered, strobe_on(), approach)
	if _sprite.material == null:
		return
	var floods := PackedVector4Array()
	var reach: float = FLOOD_REACH_METRES / Units.METERS_PER_UNIT / _design.art_pixel_size
	for light: Dictionary in layout.outside_lights:
		if light["kind"] == OutsideLight.FLOOD and floods.size() < MOST_FLOODS:
			floods.append(Vector4(light["point"].x, light["point"].y, reach, 1.0 if _powered else 0.0))
	var count: int = floods.size()
	floods.resize(MOST_FLOODS)
	(_sprite.material as ShaderMaterial).set_shader_parameter("floods", floods)
	(_sprite.material as ShaderMaterial).set_shader_parameter("flood_count", count)


# The outside lit by the star, and dark in a world's shadow, once its curvature's ready.
func _light_outside() -> void:
	if _hull_task >= 0 and WorkerThreadPool.is_task_completed(_hull_task):
		WorkerThreadPool.wait_for_task_completion(_hull_task)
		_hull_task = -1
		# Its art has some shading drawn in already, so the star's is gentler.
		_hull_material.set_shader_parameter("ambient", 0.5)
		_sprite.material = _hull_material
	if _sprite.material == null or _gravity_model == null:
		return
	var frame: Dictionary = _frame_at(_state.time)
	var toward: Vector2 = -Vector2(frame["x"], frame["y"]).normalized()
	HullLight.aim(_sprite, toward, Sunlight.at(_gravity_model, frame["x"], frame["y"], _state.time))


# Emergency lamps pulse slowly, and failing ones sputter: mostly dark, with bursts of light. With the
# power on, a failing fixture flickers out for a moment every few seconds.
func _change_lights(delta: float) -> void:
	if _lit_materials.is_empty() or not _insides_visible():
		return
	_light_time += delta
	_sputter_left -= delta
	if _sputter_left <= 0.0:
		_sputter_on = not _sputter_on
		_sputter_left = randf_range(0.04, 0.25) if _sputter_on else randf_range(0.05, 1.6)
	_failing_wait -= delta
	if _failing_wait <= 0.0:
		_failing_out = not _failing_out
		_failing_wait = randf_range(FAILING_OUT_SECONDS.x, FAILING_OUT_SECONDS.y) if _failing_out else randf_range(FAILING_EVERY_SECONDS.x, FAILING_EVERY_SECONDS.y)
	if _planned:
		_set_light_param("circuit_live", _circuits_live())
		return
	_set_light_param("pulse", 0.675 + 0.325 * sin(_light_time * TAU / EMERGENCY_PULSE_SECONDS))
	_set_light_param("flicker", 1.0 if _sputter_on else 0.0)


# Whether the insides are showing at all.
func _insides_visible() -> bool:
	return _inside.visible if _modular else _inside_sprite.visible


## How much light the lamps leave at a point in the station's frame, from 0 to 1, with failing lamps
## out and emergency lamps halfway through their pulse.
func light_at(local: Vector2) -> float:
	var point: Vector2 = local / _design.art_pixel_size + Vector2(layout.origin)
	if _planned:
		if _baked_maps.is_empty():
			return 1.0 if _powered else _design.dark_ambient
		# Failing fixtures out and emergency ones halfway through their pulse, so it doesn't flicker.
		var live := Vector4(1.0 if _powered else 0.0, 0.0, 0.0 if _powered else 0.55, 1.0)
		return StationLight.evaluate(_baked_maps, floori(point.x), floori(point.y), live, _design.ambient_light if _powered else _design.dark_ambient)["light"]
	if _baked_light == null:
		return 1.0 if _powered else _design.dark_ambient
	var x: int = clampi(floori(point.x), 0, _baked_light.get_width() - 1)
	var y: int = clampi(floori(point.y), 0, _baked_light.get_height() - 1)
	var maps: Color = _baked_light.get_pixel(x, y)
	return 1.0 - (1.0 - maps.r) * (1.0 - maps.b * 0.55)


## Shines the pilot's helmet lamp from a point in the station's frame, facing this way in it, or puts
## it out.
func light_helmet(local: Vector2, facing: float, on: bool) -> void:
	if _lit_materials.is_empty():
		return
	_set_light_param("helmet_on", on)
	if on:
		_set_light_param("helmet_at", local / _design.art_pixel_size + Vector2(layout.origin))
		_set_light_param("helmet_facing", Vector2(sin(facing), -cos(facing)))


## Tells the station where the pilot is in its frame while they're inside, so the props they're behind
## or in front of are drawn that way, and the hatch doors open for them. Call it with inside false when
## they're not in the station.
func set_pilot_inside(local: Vector2, inside: bool) -> void:
	_pilot_inside = inside
	_pilot_at = local / _design.art_pixel_size + Vector2(layout.origin)
	var feet: float = _pilot_at.y + pilot_feet / _design.art_pixel_size
	for stand: Dictionary in _stands:
		var sprite: Sprite2D = stand["sprite"]
		sprite.z_index = Z_FRONT if inside and stand["foot"] > feet else Z_BEHIND


## The station's hatch doors, if it has them.
func hatch_doors() -> HatchDoors:
	return _doors


## How many game pixels wide one pixel of the station's art is drawn.
func art_pixel_size() -> float:
	return _design.art_pixel_size


## How far the station reaches from its middle, in world units.
func reach() -> float:
	var size := Vector2(layout.image.get_size() - layout.origin)
	return maxf(maxf(layout.origin.x, layout.origin.y), maxf(size.x, size.y)) * _design.art_pixel_size


## Takes the roof off, or puts it back.
func set_roof_off(off: bool) -> void:
	_roof_off = off


func _process(delta: float) -> void:
	_pick_up_light()
	_change_lights(TimeWarp.real(delta))
	_light_outside()
	_light_glow(TimeWarp.real(delta))
	_run_cycle(TimeWarp.real(delta))
	if _doors != null:
		_doors.update(TimeWarp.real(delta), _pilot_at if _pilot_inside else Vector2(-1.0e9, -1.0e9), layout.origin)
	var wanted: float = 1.0 if _roof_off else 0.0
	if _roof_gone == wanted:
		return
	_roof_gone = move_toward(_roof_gone, wanted, TimeWarp.real(delta) / roof_seconds)
	_inside_sprite.visible = _roof_gone > 0.0 and not _show_dot and not _modular
	_inside.visible = _roof_gone > 0.0 and not _show_dot and _modular
	_sprite.modulate.a = 1.0 - _roof_gone


## The station at a moment in time: its "x" and "y", how it's "moving", which way it's turned as an
## "angle", and how fast that's changing as a "rate".
func frame_at(time: float) -> Dictionary:
	return _frame_at(time)


## How the part of the station at this offset from its middle is moving, turning included.
func moving_at(frame: Dictionary, offset: Vector2) -> Vector2:
	return _moving_at(frame, offset)


## True if this point in the world is close enough that the station counts as nearby.
func is_nearby(x: float, y: float, time: float) -> bool:
	var frame: Dictionary = _frame_at(time)
	return Vector2(x - frame["x"], y - frame["y"]).length() <= nearby_reach


## Which way a free port faces, in the station's frame.
func port_face(port: int) -> Vector2:
	return _ports[port]["face"]


## Where the inner door of a free port is, in the station's frame.
func port_inner(port: int) -> Vector2:
	if _ports[port].has("inner"):
		return _ports[port]["inner"]
	return _ports[port]["at"] - _ports[port]["face"] * port_door_depth


## Where a port's hatch is, in the station's frame.
func port_point(port: int) -> Vector2:
	return _ports[port]["at"]


## Where a spot to use is, in the station's frame.
func spot_point(spot: Dictionary) -> Vector2:
	return (Vector2(spot["point"]) - Vector2(layout.origin)) * _design.art_pixel_size


## A box around a point in the station's frame, turning with the station, as its four corners in the
## world: for pointing at a hatch, a door, or a terminal. Its half size is in art pixels.
func box_corners(local: Vector2, half_pixels: Vector2, time: float) -> PackedFloat64Array:
	var frame: Dictionary = _frame_at(time)
	var half: Vector2 = half_pixels * _design.art_pixel_size
	var corners := PackedFloat64Array()
	for corner: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
		var offset: Vector2 = (local + corner * half).rotated(frame["angle"])
		corners.append(frame["x"] + offset.x)
		corners.append(frame["y"] + offset.y)
	return corners


## A point just outside a free port, in the station's frame.
func port_outer(port: int, clearance: float) -> Vector2:
	return _ports[port]["at"] + _ports[port]["face"] * clearance


## The port the pilot can board by from outside, on EVA, that's within reach of this point in the world,
## or -1: any free port of an old station, the airlock of a station of modules, and never a docking collar.
func free_port_near(x: float, y: float, time: float, port_reach: float) -> int:
	var frame: Dictionary = _frame_at(time)
	var local: Vector2 = Vector2(x - frame["x"], y - frame["y"]).rotated(-frame["angle"])
	for i in range(_ports.size()):
		if i != docked_port and port_exits(i) and local.distance_to(_ports[i]["at"]) <= port_reach:
			return i
	return -1


## What kind a port is: "legacy", "dock", or "airlock".
func port_kind(port: int) -> String:
	return _ports[port]["kind"]


## Whether the pilot can go out of the station by this port, and in by it from outside.
func port_exits(port: int) -> bool:
	return _ports[port]["kind"] != DOCK


# Whether a ship can dock at this port.
func _port_docks(port: Dictionary) -> bool:
	return port["kind"] != AIRLOCK


## The free port whose inner door is within reach of this point in the station's frame, or -1.
func port_near_inside(local: Vector2, door_reach: float) -> int:
	for i in range(_ports.size()):
		if local.distance_to(port_inner(i)) <= door_reach:
			return i
	return -1


## The nearest thing to use within reach of this point in the station's frame, or nothing. A bed to
## wake up beside isn't something to use, and the breaker panel only is while the lights switch is on.
func spot_near(local: Vector2, spot_reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_away: float = spot_reach
	for spot: Dictionary in layout.spots:
		if spot["kind"] == StationProp.WAKE or (spot["kind"] == StationProp.POWER and not FeatureFlags.LIGHTS_SWITCH):
			continue
		var at: Vector2 = (Vector2(spot["point"]) - Vector2(layout.origin)) * _design.art_pixel_size
		var away: float = local.distance_to(at)
		if away <= best_away:
			best_away = away
			best = spot
	return best


## How big the pilot is for walking about inside, in world units: their own radius, but never wider
## than six of the station's pixels, so a station drawn at 5 cm a pixel doesn't make them 1.2 m wide.
func walk_radius(body_radius: float) -> float:
	return minf(body_radius, PILOT_HALF_WIDTH_PIXELS * _design.art_pixel_size)


## Where the pilot wakes up after the med bay: standing beside the bed with the "wake" spot, facing down,
## as a "local" point in the station's frame and a "facing". Empty if the station has no such bed, and
## they wake at the home port's inner door instead.
func wake_spot(radius: float) -> Dictionary:
	for spot: Dictionary in layout.spots:
		if spot["kind"] != StationProp.WAKE:
			continue
		var bed: Vector2 = spot_point(spot)
		var ways: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
				Vector2(1.0, 1.0).normalized(), Vector2(-1.0, 1.0).normalized(), Vector2(1.0, -1.0).normalized(), Vector2(-1.0, -1.0).normalized()]
		var away: float = 0.0
		while away <= 120.0:
			for way: Vector2 in ways:
				if pilot_fits(bed + way * away, radius):
					return {"local": bed + way * away, "facing": PI}
			away += 2.0
	return {}


## True if someone this big can stand at this point in the station's frame.
func pilot_fits(local: Vector2, radius: float) -> bool:
	if not layout.is_walkable(_on_picture(local)):
		return false
	for i in range(8):
		if not layout.is_walkable(_on_picture(local + Vector2.UP.rotated(i * TAU / 8.0) * radius)):
			return false
	return true


## If someone this big at this point in the world is touching the station from outside, says the
## "normal" out of it, how far to "push" them along that, and how the station's "moving" there.
func push_pilot_out(x: float, y: float, time: float, radius: float) -> Dictionary:
	var frame: Dictionary = _frame_at(time)
	var to_pilot := Vector2(x - frame["x"], y - frame["y"])
	if to_pilot.length_squared() > _contact_range * _contact_range:
		return {}
	var angle: float = frame["angle"]
	var local: Vector2 = to_pilot.rotated(-angle)
	var touching: bool = false
	for i in range(8):
		if _is_solid(local + Vector2.UP.rotated(i * TAU / 8.0) * radius):
			touching = true
			break
	if not touching:
		return {}
	var normal: Vector2 = layout.normal_at(_on_picture(local))
	if normal == Vector2.ZERO:
		normal = local.normalized()
	var push: float = 1.0
	while push < most_push:
		var clear: bool = true
		for i in range(8):
			if _is_solid(local + normal * push + Vector2.UP.rotated(i * TAU / 8.0) * radius):
				clear = false
				break
		if clear:
			break
		push += 1.0
	return {"normal": normal.rotated(angle), "push": push, "moving": _moving_at(frame, to_pilot)}


# The station at a moment in time: where it is, how it's moving, which way it's turned, and how
# fast that's changing.
func _frame_at(time: float) -> Dictionary:
	var at: PackedFloat64Array = _gravity_model.get_satellite_position(_index, time)
	var moving: PackedFloat64Array = _gravity_model.get_satellite_velocity(_index, time)
	var parent: int = _gravity_model.get_satellite_parent(_index)
	var parent_at: PackedFloat64Array = _gravity_model.get_body_position(parent, time)
	var parent_moving: PackedFloat64Array = _gravity_model.get_body_velocity(parent, time)
	var from_parent := Vector2(at[0] - parent_at[0], at[1] - parent_at[1])
	var around_parent := Vector2(moving[0] - parent_moving[0], moving[1] - parent_moving[1])
	return {
		"x": at[0],
		"y": at[1],
		"moving": Vector2(moving[0], moving[1]),
		"angle": atan2(from_parent.x, -from_parent.y),
		"rate": from_parent.cross(around_parent) / from_parent.length_squared(),
	}


# How the station's frame is moving at a point and time.
func _moving_near(x: float, y: float, time: float) -> Vector2:
	var frame: Dictionary = _frame_at(time)
	return _moving_at(frame, Vector2(x - frame["x"], y - frame["y"]))


# How the part of the station at this offset from its middle is moving, turning included.
func _moving_at(frame: Dictionary, offset: Vector2) -> Vector2:
	return frame["moving"] + Vector2(-offset.y, offset.x) * frame["rate"]


func _physics_process(delta: float) -> void:
	if _gravity_model == null:
		return
	var frame: Dictionary = _frame_at(_state.time)
	var to_ship := Vector2(_state.x - frame["x"], _state.y - frame["y"])
	var distance: float = to_ship.length()

	_ship.set_nearby_moving(_moving_near if distance <= nearby_reach else Callable())

	if _ship.docked:
		_dock_place = _dock_place.move_toward(_dock_goal, pull_speed * delta)
		_dock_heading = rotate_toward(_dock_heading, _dock_goal_heading, pull_turn * delta)
		_was_docked = true
		_guide_port = -1
		return
	if _was_docked:
		_was_docked = false
		_leaving_port = true
		docked_port = -1
		_sync_collar_doors()
	_find_guide(frame, to_ship)
	if distance > _contact_range or not _ship.has_shape():
		return
	if _try_docking(frame, to_ship):
		return
	_touch_ship(frame, to_ship)


func _hatch_in_frame(frame: Dictionary, to_ship: Vector2) -> Vector2:
	return (to_ship + _ship.hatch_from_center().rotated(_ship.heading)).rotated(-frame["angle"])


# The heading that points a nose straight into this port, in the station's own frame.
func _heading_into(port: Dictionary) -> float:
	var into: Vector2 = -port["face"]
	return atan2(into.x, -into.y)


# How fast the hatch is moving against the station right where it is.
func _hatch_speed(frame: Dictionary, to_ship: Vector2) -> float:
	var hatch: Vector2 = _ship.hatch_from_center().rotated(_ship.heading)
	var moving: Vector2 = Vector2(_state.velocity_x, _state.velocity_y) + Vector2(-hatch.y, hatch.x) * _ship.angular_velocity
	return (moving - _moving_at(frame, to_ship + hatch)).length()


func _find_guide(frame: Dictionary, to_ship: Vector2) -> void:
	var was: int = _guide_port
	var was_ready: bool = _guide_ready
	_guide_port = -1
	_guide_ready = false
	if not _ship.pilot_aboard:
		if was >= 0:
			queue_redraw()
		return
	var hatch: Vector2 = _hatch_in_frame(frame, to_ship)
	var nearest: float = guide_reach
	for i in range(_ports.size()):
		if not _port_docks(_ports[i]):
			continue
		var away: float = hatch.distance_to(_ports[i]["at"])
		if away < nearest:
			nearest = away
			_guide_port = i
	if _guide_port >= 0:
		var port: Dictionary = _ports[_guide_port]
		var gap: Vector2 = hatch - port["at"]
		var across: float = absf(gap.dot(port["face"].orthogonal()))
		var off: float = absf(angle_difference(_ship.heading - frame["angle"], _heading_into(port)))
		_guide_ready = _ship.has_hatch() and across <= _design.dock_across \
				and off <= deg_to_rad(_design.dock_angle_degrees) and _hatch_speed(frame, to_ship) <= _design.dock_speed
	if _guide_port != was or _guide_ready != was_ready or _guide_port >= 0:
		queue_redraw()


# Docks if the hatch has come slowly and straight onto a free port. If it's only there to bump, says
# what was wrong.
func _try_docking(frame: Dictionary, to_ship: Vector2) -> bool:
	if not _ship.has_hatch():
		return false
	var hatch: Vector2 = _hatch_in_frame(frame, to_ship)
	var nearest: int = -1
	var nearest_away: float = INF
	for i in range(_ports.size()):
		if not _port_docks(_ports[i]):
			continue
		var away: float = hatch.distance_to(_ports[i]["at"])
		if away < nearest_away:
			nearest_away = away
			nearest = i
	if nearest < 0:
		return false
	if _leaving_port:
		_leaving_port = nearest_away < undock_clear
		return false
	var port: Dictionary = _ports[nearest]
	var gap: Vector2 = hatch - port["at"]
	if absf(gap.dot(port["face"])) > _design.dock_reach or absf(gap.dot(port["face"].orthogonal())) > _design.dock_across:
		return false
	var off: float = absf(angle_difference(_ship.heading - frame["angle"], _heading_into(port)))
	if _hatch_speed(frame, to_ship) > _design.dock_speed:
		_tell_pilot("TOO FAST TO DOCK")
		return false
	if off > deg_to_rad(_design.dock_angle_degrees):
		_tell_pilot("LINE UP TO DOCK")
		return false
	docked_port = nearest
	_sync_collar_doors()
	_ship.dock(_docked_point)
	_dock_goal_heading = _heading_into(port)
	_dock_heading = _ship.heading - frame["angle"]
	# Repairing can move the ship's center, so this reads where it is after that.
	_dock_place = Vector2(_state.x - frame["x"], _state.y - frame["y"]).rotated(-frame["angle"])
	_dock_goal = port["at"] - _ship.hatch_from_center().rotated(_dock_goal_heading)
	_guide_port = -1
	queue_redraw()
	return true


## What a save needs from the station: the name of the port the ship's docked at, if any.
func save_state() -> Dictionary:
	return {"docked_port": _ports[docked_port]["name"] if _ship.docked and docked_port >= 0 else ""}


## The name of the port the ship's docked at, or an empty one.
func docked_port_name() -> String:
	return _ports[docked_port]["name"] if docked_port >= 0 else ""


## Puts a saved ship back on its port, all the way in. Docking repairs and refuels it, as it did when
## it first docked. The port is a name; a number from an older save is turned into one by the design's
## legacy_ports, and a station without them takes it as the port's place in its list. A port the
## station doesn't have leaves the ship undocked.
func restore_state(saved: Dictionary) -> void:
	_dock_at(_port_from_save(saved.get("docked_port", "")))


## Docks the ship at the station's home port, as a pilot waking up in the med bay finds it, or at its
## first free port if the design names none.
func restore_home() -> void:
	var home: int = _port_from_save(_design.home_port)
	_dock_at(home if home >= 0 else _port_from_save(0))


# Which of the ports a saved value means, or -1: a name, or an old save's number.
func _port_from_save(value: Variant) -> int:
	if value is String or value is StringName:
		for i in range(_ports.size()):
			if _ports[i]["name"] == String(value) and _port_docks(_ports[i]):
				return i
		return -1
	var number: int = int(value)
	if number < 0:
		return -1
	if not _design.legacy_ports.is_empty():
		return _port_from_save(_design.legacy_ports[number]) if number < _design.legacy_ports.size() else -1
	# Of the ports that can dock, counting from 0.
	var counted: int = 0
	for i in range(_ports.size()):
		if _port_docks(_ports[i]):
			if counted == number:
				return i
			counted += 1
	return -1


func _dock_at(port_index: int) -> void:
	if port_index < 0 or port_index >= _ports.size():
		return
	var port: Dictionary = _ports[port_index]
	docked_port = port_index
	_dock_goal_heading = _heading_into(port)
	_dock_goal = port["at"] - _ship.hatch_from_center().rotated(_dock_goal_heading)
	_dock_place = _dock_goal
	_dock_heading = _dock_goal_heading
	_ship.dock(_docked_point)
	_was_docked = true
	_guide_port = -1
	_sync_collar_doors()


# A docking collar's door stands open while a ship's docked at it and shut otherwise, and an airlock's
# outer door stays shut unless it's cycling, whatever the pilot's nearness.
func _sync_collar_doors() -> void:
	if _doors == null:
		return
	for i in range(_ports.size()):
		var port: Dictionary = _ports[i]
		if port["kind"] == DOCK:
			var collar: int = _doors.find(port["name"], "dock")
			if collar >= 0:
				_doors.force(collar, HatchDoors.OPEN if docked_port == i else HatchDoors.SHUT)
		elif port["kind"] == AIRLOCK and _cycle.is_empty():
			var outer: int = _doors.find(port["name"], "airlock")
			if outer >= 0:
				_doors.force(outer, HatchDoors.SHUT)
			var inner: int = _doors.find(port["name"], "door")
			if inner >= 0:
				_doors.force(inner, HatchDoors.FREE)


## Starts an airlock's cycle, going out to space or coming in from it, which takes 2.5 seconds. Going
## out the inner door shuts, the lamps go red, then amber pulsing, then green, and the outer door opens:
## then airlock_cycle_done is emitted. Coming in runs it backward and ends with the inner door open. A
## station with no doors to run still waits the time.
func start_airlock_cycle(port: int, going_out: bool) -> void:
	_cycle = {"port": port, "out": going_out, "time": 0.0, "done": false, "after": 0.0}


## Whether an airlock's cycling, so the pilot waits for it.
func airlock_busy() -> bool:
	return not _cycle.is_empty() and not _cycle["done"]


# Runs the airlock's cycle on a bit: its doors, its lamps, and its end.
func _run_cycle(delta: float) -> void:
	if _cycle.is_empty():
		return
	var port_index: int = _cycle["port"]
	var airlock_name: String = _ports[port_index]["name"]
	var going_out: bool = _cycle["out"]
	var outer: int = _doors.find(airlock_name, "airlock") if _doors != null else -1
	var inner: int = _doors.find(airlock_name, "door") if _doors != null else -1
	_cycle["time"] += delta
	var t: float = _cycle["time"]
	if not _cycle["done"]:
		var lamp_state: int
		if going_out:
			lamp_state = AirlockLamps.RED if t < 0.8 else (AirlockLamps.AMBER if t < 1.9 else AirlockLamps.GREEN)
		else:
			lamp_state = AirlockLamps.GREEN if t < 0.6 else (AirlockLamps.AMBER if t < 1.7 else AirlockLamps.RED)
		if _lamps != null:
			_lamps.set_state(port_index, lamp_state)
		if _doors != null:
			if inner >= 0:
				_doors.force(inner, HatchDoors.SHUT)
			if outer >= 0:
				# Coming in, the outer door's open as they step in, and shuts behind them.
				_doors.force(outer, HatchDoors.OPEN if not going_out and t < 0.3 else HatchDoors.SHUT)
		if t >= CYCLE_SECONDS:
			_cycle["done"] = true
			_cycle["after"] = 0.0
			if _lamps != null:
				_lamps.set_state(port_index, AirlockLamps.GREEN)
			if _doors != null:
				if going_out and outer >= 0:
					_doors.force(outer, HatchDoors.OPEN)
				if not going_out and inner >= 0:
					_doors.force(inner, HatchDoors.OPEN)
			airlock_cycle_done.emit(port_index, going_out)
	else:
		_cycle["after"] += delta
		if _cycle["after"] >= (OUTER_OPEN_AFTER_SECONDS if going_out else 1.0):
			_cycle = {}
			_sync_collar_doors()


# Where a docked ship is held: [x, y, velocity x, velocity y, heading, spin].
func _docked_point(time: float) -> PackedFloat64Array:
	var frame: Dictionary = _frame_at(time)
	var offset: Vector2 = _dock_place.rotated(frame["angle"])
	var moving: Vector2 = _moving_at(frame, offset)
	return PackedFloat64Array([frame["x"] + offset.x, frame["y"] + offset.y, moving.x, moving.y,
			frame["angle"] + _dock_heading, frame["rate"]])


func _tell_pilot(text: String) -> void:
	if _state.time - _last_message >= message_seconds:
		_last_message = _state.time
		message_raised.emit(text)


func _touch_ship(frame: Dictionary, to_ship: Vector2) -> void:
	var angle: float = frame["angle"]
	var points: PackedVector2Array = _ship.world_outline_samples(contact_spacing)
	var contact := Vector2.ZERO
	var touching: int = 0
	for point: Vector2 in points:
		if _is_solid((to_ship + point).rotated(-angle)):
			contact += point
			touching += 1
	if touching == 0:
		return
	contact /= touching
	var normal: Vector2 = layout.normal_at(_on_picture((to_ship + contact).rotated(-angle))).rotated(angle)
	if normal == Vector2.ZERO:
		normal = to_ship.normalized()
	var push: float = 1.0
	while push < most_push and _any_solid(points, to_ship + normal * push, angle):
		push += 1.0
	var moving: Vector2 = _moving_at(frame, to_ship + contact)
	_ship.hit_solid(contact, normal, push, moving.x, moving.y)


# Where an offset from the station's middle, in its own frame, falls on its picture.
func _on_picture(offset: Vector2) -> Vector2:
	return offset / _design.art_pixel_size + Vector2(layout.origin)


func _is_solid(offset: Vector2) -> bool:
	return layout.is_solid(_on_picture(offset))


func _any_solid(points: PackedVector2Array, shift: Vector2, angle: float) -> bool:
	for point: Vector2 in points:
		if _is_solid((shift + point).rotated(-angle)):
			return true
	return false


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	if _gravity_model == null:
		return
	_pixels_per_unit = pixels_per_unit
	var frame: Dictionary = _frame_at(_state.time)
	# Whole pixels on screen, however the view is turned, so it doesn't shimmer as it crawls.
	var from_middle := Vector2((frame["x"] - center_x) * pixels_per_unit, (frame["y"] - center_y) * pixels_per_unit)
	position = from_middle.rotated(-_roll).round().rotated(_roll)
	rotation = frame["angle"]
	var show_dot: bool = pixels_per_unit <= dot_max_zoom
	_sprite.visible = not show_dot
	_sprite.scale = Vector2.ONE * _design.art_pixel_size * pixels_per_unit
	_inside_sprite.scale = _sprite.scale
	_inside.scale = _sprite.scale
	_inside_sprite.visible = _roof_gone > 0.0 and not show_dot and not _modular
	_inside.visible = _roof_gone > 0.0 and not show_dot and _modular
	if show_dot != _show_dot:
		_show_dot = show_dot
		queue_redraw()


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	if _show_dot:
		draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), palette.hull_darkest)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), palette.agency_orange)
		return
	if _guide_port < 0 or _pixels_per_unit < guide_max_zoom:
		return
	# A dashed line straight out from the port, green once the ship could dock.
	var port: Dictionary = _ports[_guide_port]
	var color: Color = palette.telemetry_green if _guide_ready else palette.telemetry_amber
	var dash: float = 12.0
	var along: float = 0.0
	while along < guide_length:
		var from: Vector2 = (port["at"] + port["face"] * along) * _pixels_per_unit
		var to: Vector2 = (port["at"] + port["face"] * (along + dash)) * _pixels_per_unit
		draw_line(from.round(), to.round(), color, -1.0)
		along += dash * 2.0
