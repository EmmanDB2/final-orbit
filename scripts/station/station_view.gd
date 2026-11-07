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

var layout: StationLayout

var _gravity_model: GravityModel
var _state: ShipState
var _design: StationDesign
var _index: int = 0
var _sprite := Sprite2D.new()
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
	add_child(_sprite)


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


# How the part of the station at this offset from its middle is moving, turning included.
func _moving_at(frame: Dictionary, offset: Vector2) -> Vector2:
	return frame["moving"] + Vector2(-offset.y, offset.x) * frame["rate"]


func _physics_process(delta: float) -> void:
	if _gravity_model == null:
		return
	var frame: Dictionary = _frame_at(_state.time)
	var to_ship := Vector2(_state.x - frame["x"], _state.y - frame["y"])
	var distance: float = to_ship.length()

	if distance <= nearby_reach:
		var moving_here: Vector2 = _moving_at(frame, to_ship)
		_ship.set_nearby_frame(moving_here.x, moving_here.y)
	else:
		_ship.clear_nearby_frame()

	if _ship.docked:
		_dock_place = _dock_place.move_toward(_dock_goal, pull_speed * delta)
		_dock_heading = rotate_toward(_dock_heading, _dock_goal_heading, pull_turn * delta)
		_was_docked = true
		_guide_port = -1
		return
	if _was_docked:
		_was_docked = false
		_leaving_port = true
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
	_ship.dock(_docked_point)
	_dock_goal_heading = _heading_into(port)
	_dock_heading = _ship.heading - frame["angle"]
	# Repairing can move the ship's center, so this reads where it is after that.
	_dock_place = Vector2(_state.x - frame["x"], _state.y - frame["y"]).rotated(-frame["angle"])
	_dock_goal = port["at"] - _ship.hatch_from_center().rotated(_dock_goal_heading)
	_guide_port = -1
	queue_redraw()
	return true


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
