# event_scene.gd: draws the mid-flight events that have a body in the world: an astronaut adrift, held,
# or standing about, and later comets. Each gets a view of its own while it's around, placed with the
# rest of the world as the camera moves. From DESIGN.md, "Mid-flight events".
class_name EventScene
extends Node2D

var _events: EventDirector
var _pilot: Pilot
var _views: Dictionary = {}
var _center_x: float = 0.0
var _center_y: float = 0.0
var _pixels_per_unit: float = 1.0
var _roll: float = 0.0


func start(events: EventDirector, pilot: Pilot) -> void:
	_events = events
	_pilot = pilot
	events.event_found.connect(_add)
	events.event_gone.connect(_remove)
	for event: FlightEvent in events.events:
		_add(event)


func _add(event: FlightEvent) -> void:
	if _views.has(event.id):
		return
	var view: Node2D = null
	match event.type.kind:
		"distress":
			var survivor := SurvivorView.new()
			survivor.setup(event, _pilot)
			view = survivor
		"comet":
			var comet := CometView.new()
			comet.setup(event)
			view = comet
	if view == null:
		return
	_views[event.id] = view
	add_child(view)
	view.call("place", _center_x, _center_y, _pixels_per_unit, _roll)


func _remove(id: int) -> void:
	if _views.has(id):
		_views[id].queue_free()
		_views.erase(id)


func _on_view_rolled(angle: float) -> void:
	_roll = angle


func _on_view_changed(center_x: float, center_y: float, pixels_per_unit: float) -> void:
	_center_x = center_x
	_center_y = center_y
	_pixels_per_unit = pixels_per_unit
	for view: Node2D in _views.values():
		view.call("place", center_x, center_y, pixels_per_unit, _roll)
