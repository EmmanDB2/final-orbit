# station_view.gd: a station where its rails put it, at true scale, turning with its orbit so its
# bottom always faces the body below. Farther out it's a marker dot. Its pixels are solid, and a ship
# that brings its hatch slowly and straight onto a free port docks there.
# From DESIGN.md, "Universe generation" (stations are hubs), "Core loop" (a run ends docked), and
# "Camera, zoom, and landing".
class_name StationView
extends Node2D

## Emitted when the pilot should be told why a docking didn't take.
signal message_raised(text: String)

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
## How long the roof takes to come off, in seconds.
@export var roof_seconds: float = 0.3

var layout: StationLayout
## Which free port the ship's docked at, or -1.
var docked_port: int = -1

var _gravity_model: GravityModel
var _state: ShipState
var _design: StationDesign
var _index: int = 0
var _sprite := Sprite2D.new()
var _inside_sprite := Sprite2D.new()
# The insides' light map, worked out on a worker thread, and that work while it's under way.
var _light_task: int = -1
var _baked_light: Image
var _roof_off: bool = false
var _roof_gone: float = 0.0
var _show_dot: bool = false
var _ship: Node2D
var _contact_range: float = 0.0
var _pixels_per_unit: float = 1.0
var _roll: float = 0.0
# Where the free ports are in the station's own frame, in world units: "at" and "face".
var _ports: Array[Dictionary] = []
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
	for port: Dictionary in layout.free_ports:
		var face := Vector2(port["face"])
		var surface: Vector2 = Vector2(port["point"]) + Vector2(0.5, 0.5) + face * 0.5
		_ports.append({"at": (surface - Vector2(layout.origin)) * design.art_pixel_size, "face": face})
	_sprite.texture = ImageTexture.create_from_image(layout.image)
	_sprite.centered = false
	_sprite.offset = -Vector2(layout.origin)
	_inside_sprite.texture = ImageTexture.create_from_image(layout.interior_image)
	_light_inside()
	_inside_sprite.centered = false
	_inside_sprite.offset = -Vector2(layout.origin)
	_inside_sprite.visible = false
	# Under the roof, which fades off it.
	add_child(_inside_sprite)
	add_child(_sprite)


# The insides lit by the station's lamps, or only faintly with the power off.
func _light_inside() -> void:
	var material: ShaderMaterial = PaletteLight.material_for(preload("res://shaders/interior_light.gdshader"))
	var lamps := PackedVector4Array()
	if _design.powered:
		for lamp: Dictionary in layout.lamps:
			lamps.append(Vector4(lamp["point"].x, lamp["point"].y, lamp["reach"], _design.lamp_brightness))
	var count: int = mini(lamps.size(), INTERIOR_LAMPS)
	lamps.resize(INTERIOR_LAMPS)
	material.set_shader_parameter("lamps", lamps)
	material.set_shader_parameter("lamp_count", count)
	material.set_shader_parameter("ambient", _design.ambient_light)
	material.set_shader_parameter("floor_mask", ImageTexture.create_from_image(StationLight.floor_mask(layout.picture_size(), layout.floors())))
	_inside_sprite.material = material
	# Walls stopping the lamps' light takes a while to work out, so it's done off to the side. Until
	# it's ready, the lamps light straight through.
	_wait_for_light()
	var size: Vector2i = layout.picture_size()
	var rooms: Array = layout.room_areas
	var lit: Array = layout.lamps if _design.powered else []
	var ambient: float = _design.ambient_light
	var brightness: float = _design.lamp_brightness
	_light_task = WorkerThreadPool.add_task(func() -> void: _baked_light = StationLight.bake(size, rooms, lit, ambient, brightness))


# Once the light map's ready, the insides use it.
func _pick_up_light() -> void:
	if _light_task < 0 or not WorkerThreadPool.is_task_completed(_light_task):
		return
	_wait_for_light()
	if _baked_light != null and _inside_sprite.material != null:
		_inside_sprite.material.set_shader_parameter("light_map", ImageTexture.create_from_image(_baked_light))
		_inside_sprite.material.set_shader_parameter("baked", true)


func _wait_for_light() -> void:
	if _light_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_light_task)
		_light_task = -1


func _exit_tree() -> void:
	_wait_for_light()


## How much light the lamps leave at a point in the station's frame, from 0 to 1.
func light_at(local: Vector2) -> float:
	var point: Vector2 = local / _design.art_pixel_size + Vector2(layout.origin)
	if _baked_light == null:
		return _design.ambient_light if not _design.powered else 1.0
	var x: int = clampi(floori(point.x), 0, _baked_light.get_width() - 1)
	var y: int = clampi(floori(point.y), 0, _baked_light.get_height() - 1)
	return _baked_light.get_pixel(x, y).r


## Shines the pilot's helmet lamp from a point in the station's frame, facing this way in it, or puts
## it out.
func light_helmet(local: Vector2, facing: float, on: bool) -> void:
	var material: ShaderMaterial = _inside_sprite.material
	if material == null:
		return
	material.set_shader_parameter("helmet_on", on)
	if on:
		material.set_shader_parameter("helmet_at", local / _design.art_pixel_size + Vector2(layout.origin))
		material.set_shader_parameter("helmet_facing", Vector2(sin(facing), -cos(facing)))


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
	var wanted: float = 1.0 if _roof_off else 0.0
	if _roof_gone == wanted:
		return
	_roof_gone = move_toward(_roof_gone, wanted, TimeWarp.real(delta) / roof_seconds)
	_inside_sprite.visible = _roof_gone > 0.0 and not _show_dot
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


## The free port with nothing docked at it that's within reach of this point in the world, or -1.
func free_port_near(x: float, y: float, time: float, port_reach: float) -> int:
	var frame: Dictionary = _frame_at(time)
	var local: Vector2 = Vector2(x - frame["x"], y - frame["y"]).rotated(-frame["angle"])
	for i in range(_ports.size()):
		if i != docked_port and local.distance_to(_ports[i]["at"]) <= port_reach:
			return i
	return -1


## The free port whose inner door is within reach of this point in the station's frame, or -1.
func port_near_inside(local: Vector2, door_reach: float) -> int:
	for i in range(_ports.size()):
		if local.distance_to(port_inner(i)) <= door_reach:
			return i
	return -1


## Something to use within reach of this point in the station's frame, or nothing.
func spot_near(local: Vector2, spot_reach: float) -> Dictionary:
	for spot: Dictionary in layout.spots:
		var at: Vector2 = (Vector2(spot["point"]) - Vector2(layout.origin)) * _design.art_pixel_size
		if local.distance_to(at) <= spot_reach:
			return spot
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
		var away: float = hatch.distance_to(_ports[i]["at"])
		if away < nearest_away:
			nearest_away = away
			nearest = i
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
	_ship.dock(_docked_point)
	_dock_goal_heading = _heading_into(port)
	_dock_heading = _ship.heading - frame["angle"]
	# Repairing can move the ship's center, so this reads where it is after that.
	_dock_place = Vector2(_state.x - frame["x"], _state.y - frame["y"]).rotated(-frame["angle"])
	_dock_goal = port["at"] - _ship.hatch_from_center().rotated(_dock_goal_heading)
	_guide_port = -1
	queue_redraw()
	return true


## What a save needs from the station: which port the ship's docked at, if any.
func save_state() -> Dictionary:
	return {"docked_port": docked_port if _ship.docked else -1}


## Puts a saved ship back on its port, all the way in. Docking repairs and refuels it, as it did when
## it first docked.
func restore_state(saved: Dictionary) -> void:
	var port_index: int = saved.get("docked_port", -1)
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
	_inside_sprite.visible = _roof_gone > 0.0 and not show_dot
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
