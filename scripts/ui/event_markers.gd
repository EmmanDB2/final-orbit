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
		var at: PackedFloat64Array = _events.point_of(event.id)
		if at.size() != 2:
			continue
		var spot: Vector2 = _view.to_screen(at[0], at[1]).round()
		if not area.has_point(spot):
			continue
		var targeted: bool = _markers != null and _markers.is_target(event.thing_dict())
		match event.type.kind:
			"signal":
				_draw_signal(event, spot, targeted, palette)


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
