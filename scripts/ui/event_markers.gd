# event_markers.gd: where each mid-flight event is on screen, so it can be found and tapped at any zoom:
# a pulsing amber diamond for a signal that's still uncharted, a small cyan one with its name for one
# that's charted, a blinking red beacon for an astronaut adrift, and an ice-white mark for a comet,
# each with what it is beside it. A scan under way shows how far it's got. From DESIGN.md, "Mid-flight
# events".
class_name EventMarkers
extends Control

## Charted signals are named on screen at this zoom and closer, or whenever they're the target.
const NAME_ZOOM: float = 1.0 / 128.0
## How long a signal's pulse takes, in seconds.
const PULSE_SECONDS: float = 1.6

var _events: EventDirector
var _view: Node
var _markers: TargetMarkers
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start(events: EventDirector, view: Node, markers: TargetMarkers) -> void:
	_events = events
	_view = view
	_markers = markers


func _process(delta: float) -> void:
	_time += TimeWarp.real(delta)
	queue_redraw()


func _draw() -> void:
	if _events == null or _view == null:
		return
	var palette: AgencyPalette = UiStyle.palette()
	var area := Rect2(Vector2.ZERO, size).grow(20.0)
	for event: FlightEvent in _events.events:
		var targeted: bool = _markers != null and _markers.is_target(event.thing_dict())
		# Where it's headed, while it's the one being gone after.
		if targeted or _view.is_focus(event.thing_dict()):
			_draw_path(_events.path_of(event.id), EventList.color_of(event.type.kind, palette))
		var at: PackedFloat64Array = _events.point_of(event.id)
		if at.size() != 2:
			continue
		var spot: Vector2 = _view.to_screen(at[0], at[1]).round()
		if not area.has_point(spot):
			continue
		match event.type.kind:
			"signal":
				_draw_signal(event, spot, targeted, palette)
			"distress":
				_draw_distress(event, spot, palette)
			"comet":
				_draw_comet(event, spot, palette)


# A dotted line along a path, dim, so it sits behind the ship's own.
func _draw_path(points: PackedFloat64Array, color: Color) -> void:
	if points.size() < 4:
		return
	color.a = 0.55
	var last: Vector2 = _view.to_screen(points[0], points[1])
	var dash: bool = true
	for i in range(2, points.size(), 2):
		var next: Vector2 = _view.to_screen(points[i], points[i + 1])
		if dash:
			draw_line(last, next, color, 1.0)
		dash = not dash
		last = next


# A small ice-white mark and its name, with how the scan's going once it's under way.
func _draw_comet(event: FlightEvent, spot: Vector2, palette: AgencyPalette) -> void:
	var color: Color = palette.glass_light
	draw_rect(Rect2(spot.x - 3.0, spot.y - 3.0, 7.0, 7.0), palette.hull_darkest)
	draw_rect(Rect2(spot.x - 2.0, spot.y - 2.0, 5.0, 5.0), color)
	var label: String = "COMET %s" % event.name
	if event.step == FlightEvent.STORED:
		label += " · DATA STORED"
	elif event.step == FlightEvent.FOUND and event.scan_share > 0.0:
		label += " · SCAN %d%%" % roundi(event.scan_share * 100.0)
	_draw_label(label, spot, color, palette)


# A red beacon that blinks once a second, while they're adrift. Held or aboard, the pilot has them.
func _draw_distress(event: FlightEvent, spot: Vector2, palette: AgencyPalette) -> void:
	if event.rescue != "adrift":
		return
	# Up close they're drawn themselves, so the beacon sits off to the side.
	var close: bool = _view._zoom >= SurvivorView.SHOW_ZOOM
	var at: Vector2 = spot + (Vector2(0.0, -26.0) if close else Vector2.ZERO)
	if fmod(_time, 1.0) < 0.5:
		var red: Color = palette.agency_red
		draw_rect(Rect2(at.x - 2.0, at.y - 5.0, 5.0, 11.0), palette.hull_darkest)
		draw_rect(Rect2(at.x - 5.0, at.y - 2.0, 11.0, 5.0), palette.hull_darkest)
		draw_rect(Rect2(at.x - 1.0, at.y - 4.0, 3.0, 9.0), red)
		draw_rect(Rect2(at.x - 4.0, at.y - 1.0, 9.0, 3.0), red)
	_draw_label("DISTRESS", at, palette.agency_red, palette)


func _draw_signal(event: FlightEvent, spot: Vector2, targeted: bool, palette: AgencyPalette) -> void:
	if event.step == FlightEvent.DONE:
		_draw_diamond(spot, 3.0, palette.telemetry_cyan, palette)
		if targeted or _view._zoom >= NAME_ZOOM:
			_draw_label(event.name, spot, palette.telemetry_cyan, palette)
		return
	if event.step == FlightEvent.FOUND:
		var phase: float = fmod(_time, PULSE_SECONDS) / PULSE_SECONDS
		var ring: Color = palette.telemetry_amber
		ring.a = 1.0 - phase
		draw_arc(spot, 6.0 + 16.0 * phase, 0.0, TAU, 24, ring, 1.0)
	_draw_diamond(spot, 4.0, palette.telemetry_amber, palette)
	var label: String = "SIGNAL"
	if event.step == FlightEvent.STORED:
		label = "DATA STORED"
	elif event.scan_share > 0.0:
		label = "SCAN %d%%" % roundi(event.scan_share * 100.0)
	_draw_label(label, spot, palette.telemetry_amber, palette)


func _draw_diamond(spot: Vector2, half: float, color: Color, palette: AgencyPalette) -> void:
	var outline := PackedVector2Array([spot + Vector2(0.0, -half - 1.0), spot + Vector2(half + 1.0, 0.0), spot + Vector2(0.0, half + 1.0), spot + Vector2(-half - 1.0, 0.0)])
	draw_colored_polygon(outline, palette.hull_darkest)
	draw_colored_polygon(PackedVector2Array([spot + Vector2(0.0, -half), spot + Vector2(half, 0.0), spot + Vector2(0.0, half), spot + Vector2(-half, 0.0)]), color)


# What it is, beside it on a dark backing so it reads over a world.
func _draw_label(text: String, spot: Vector2, color: Color, _palette: AgencyPalette) -> void:
	var at := Vector2(spot.x + 9.0, spot.y - 4.0).floor()
	draw_rect(Rect2(at - Vector2(2.0, 2.0), Vector2(UiStyle.text_width(text, 1) + 4.0, 11.0)), UiStyle.box_fill())
	UiStyle.draw_text(self, text, at, color, 1)
