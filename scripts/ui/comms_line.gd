# comms_line.gd: the line along the bottom of the screen where the pilot hears what's going on: each
# touchdown, what damage has taken out, and otherwise how the flight stands. It keeps a log for the
# comms button. From DESIGN.md, "UI" (comms line), "Camera, zoom, and landing", and "Destruction".
class_name CommsLine
extends Node2D

## Top speed for a hard landing rather than a crash, in world units per second.
@export var hard_touchdown_speed: float = 250.0
## How long a message stays up, and how long it gets if another is waiting, in seconds.
@export var message_seconds: float = 4.0
@export var waiting_seconds: float = 1.5
## How many messages the log keeps.
@export var most_remembered: int = 40

## What's been said, oldest first: each with its "time", "text", and "color".
var history: Array[Dictionary] = []

var _messages: Array[Dictionary] = []
var _ship_lost: bool = false
var _status: String = "ORBIT STABLE"
var _area := Rect2()
var _time: float = 0.0


func _process(delta: float) -> void:
	if _messages.is_empty():
		return
	var current: Dictionary = _messages[0]
	if current["stays"]:
		return
	current["time_left"] -= TimeWarp.real(delta)
	if _messages.size() > 1:
		current["time_left"] = minf(current["time_left"], waiting_seconds)
	if current["time_left"] <= 0.0:
		_messages.remove_at(0)
		queue_redraw()


func _on_comms_area_changed(area: Rect2) -> void:
	_area = area
	queue_redraw()


func _on_flight_data(data: Dictionary) -> void:
	_time = data["time"]
	var status: String = "ORBIT STABLE"
	if data.has("status"):
		status = data["status"]
	elif data["docked"]:
		status = "DOCKED"
	elif data["landed"]:
		status = "LANDED"
	elif data.get("landing", "") != "":
		# The forecast of the landing, with no more burns: SAFE, HARD, CRASH, or BURN-UP.
		status = "%s TRAJECTORY" % data["landing"]
	elif data["periapsis"] < 0.0:
		status = "IMPACT TRAJECTORY"
	elif data["apoapsis"] < 0.0:
		status = "ESCAPE TRAJECTORY"
	elif data["against_station"]:
		status = "STATION CLOSE"
	if status != _status:
		_status = status
		queue_redraw()


func _on_ship_touched_down(speed: float, upright: bool, safe_speed: float) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	if speed > hard_touchdown_speed:
		_show_message("CRASH", palette.agency_red)
	elif speed > safe_speed or not upright:
		_show_message("HARD LANDING", palette.telemetry_amber)
	else:
		_show_message("LANDED", palette.telemetry_green)


func _on_ship_lifted_off() -> void:
	for i in range(_messages.size() - 1, -1, -1):
		if not _messages[i]["stays"]:
			_messages.remove_at(i)
	queue_redraw()


func _on_ship_warning_raised(text: String) -> void:
	_show_message(text, UiStyle.palette().telemetry_amber)


func _on_ship_docked_changed(is_docked: bool) -> void:
	if is_docked:
		_show_message("DOCKED", UiStyle.palette().telemetry_green)
		_show_message("REFUELED AND REPAIRED", UiStyle.palette().telemetry_green)


func _on_ship_lost() -> void:
	_messages.clear()
	_show_message("SHIP LOST", UiStyle.palette().agency_red, true)


func _show_message(text: String, color: Color, stays: bool = false) -> void:
	_messages.append({"text": text, "color": color, "time_left": message_seconds, "stays": stays})
	history.append({"time": _time, "text": text, "color": color})
	while history.size() > most_remembered:
		history.remove_at(0)
	queue_redraw()


func _draw() -> void:
	if _area.size.x <= 0.0:
		return
	var palette: AgencyPalette = UiStyle.palette()
	var text: String = _status
	var color: Color = palette.hull_lightest
	if not _messages.is_empty():
		text = _messages[0]["text"]
		color = _messages[0]["color"]
	var y: float = _area.position.y + floorf((_area.size.y - 7.0) / 2.0)
	var underline_y: float = y + 12.0
	draw_rect(Rect2(_area.position.x, _area.position.y + 6.0, 1.0, _area.size.y - 12.0), palette.hull_lighter)
	draw_rect(Rect2(_area.position.x + 10.0, underline_y, _area.size.x - 10.0, 1.0), palette.hull_lighter)
	var line: String = "COMMS: %s." % text
	var room: int = int((_area.size.x - 12.0) / 6.0)
	UiStyle.draw_text(self, line.substr(0, room), Vector2(_area.position.x + 12.0, y), color, 1)
