# telemetry_readout.gd: shows short messages to the pilot: how each touchdown went, and
# what damage has taken out.
# From DESIGN.md, "Camera, zoom, and landing" and "Destruction".
extends Node2D

## Telemetry green and amber, and agency red, from the agency palette.
@export var good_color: Color = Color("6BCB5A")
@export var warning_color: Color = Color("F2B33A")
@export var bad_color: Color = Color("C8302C")
## Darkest hull color, for the 1 px outline all human-made things get.
@export var outline_color: Color = Color("0E0F12")
## Top speed for a hard landing rather than a crash, in world units per second.
@export var hard_touchdown_speed: float = 250.0
## How long the touchdown message stays up, in seconds.
@export var message_seconds: float = 4.0
## How far below the top of the safe area the touchdown message goes.
@export var message_height: float = 56.0

## Most messages shown at once, newest at the bottom.
@export var most_messages: int = 4
## Pixels between one message and the next.
@export var message_spacing: float = 16.0

var _messages: Array[Dictionary] = []
var _ship_lost: bool = false


func _process(delta: float) -> void:
	var changed: bool = false
	for i in range(_messages.size() - 1, -1, -1):
		_messages[i]["time_left"] -= delta
		if _messages[i]["time_left"] <= 0.0 and not _messages[i]["stays"]:
			_messages.remove_at(i)
			changed = true
	if changed:
		queue_redraw()


func _on_ship_touched_down(speed: float, upright: bool, safe_speed: float) -> void:
	if speed > hard_touchdown_speed:
		_show_message("CRASH", bad_color)
	elif speed > safe_speed or not upright:
		_show_message("HARD LANDING", warning_color)
	else:
		_show_message("LANDED", good_color)


func _on_ship_lifted_off() -> void:
	for i in range(_messages.size() - 1, -1, -1):
		if not _messages[i]["stays"]:
			_messages.remove_at(i)
	queue_redraw()


func _on_ship_warning_raised(text: String) -> void:
	_show_message(text, warning_color)


func _on_ship_docked_changed(is_docked: bool) -> void:
	if is_docked:
		_show_message("DOCKED", good_color)
		_show_message("REFUELED AND REPAIRED", good_color)


func _on_ship_lost() -> void:
	_show_message("SHIP LOST", bad_color, true)


func _show_message(text: String, color: Color, stays: bool = false) -> void:
	_messages.append({"text": text, "color": color, "time_left": message_seconds, "stays": stays})
	while _messages.size() > most_messages:
		_messages.remove_at(0)
	queue_redraw()


func _draw() -> void:
	for i in range(_messages.size()):
		var text: String = _messages[i]["text"]
		var left: float = floorf(((get_parent() as Control).size.x - UiStyle.text_width(text)) / 2.0)
		var at := Vector2(left, message_height + i * message_spacing)
		for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			UiStyle.draw_text(self, text, at + offset, outline_color)
		UiStyle.draw_text(self, text, at, _messages[i]["color"])
