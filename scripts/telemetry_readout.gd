# telemetry_readout.gd: shows how each touchdown went.
# From DESIGN.md, "Camera, zoom, and landing". Tier 0 has no damage, so this is all a
# touchdown does.
extends Node2D

## Telemetry green and amber, and agency red, from the agency palette.
@export var good_color: Color = Color("6BCB5A")
@export var warning_color: Color = Color("F2B33A")
@export var bad_color: Color = Color("C8302C")
## Darkest hull color, for the 1 px outline all human-made things get.
@export var outline_color: Color = Color("0E0F12")
## Top speed for a clean landing, in world units per second.
@export var soft_touchdown_speed: float = 50.0
## Top speed for a hard landing rather than a crash.
@export var hard_touchdown_speed: float = 500.0
## How long the touchdown message stays up, in seconds.
@export var message_seconds: float = 4.0
## How far below the top of the safe area the touchdown message goes.
@export var message_height: float = 56.0

var _message: String = ""
var _message_color: Color = Color.WHITE
var _message_time_left: float = 0.0


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			_message = ""
			queue_redraw()


func _on_ship_touched_down(speed: float, upright: bool) -> void:
	if speed > hard_touchdown_speed:
		_show_message("CRASH", bad_color)
	elif speed > soft_touchdown_speed or not upright:
		_show_message("HARD LANDING", warning_color)
	else:
		_show_message("LANDED", good_color)


func _on_ship_lifted_off() -> void:
	_message = ""
	_message_time_left = 0.0
	queue_redraw()


func _show_message(text: String, color: Color) -> void:
	_message = text
	_message_color = color
	_message_time_left = message_seconds
	queue_redraw()


func _draw() -> void:
	if _message == "":
		return
	var left: float = floorf(((get_parent() as Control).size.x - UiStyle.text_width(_message)) / 2.0)
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		UiStyle.draw_text(self, _message, Vector2(left, message_height) + offset, outline_color)
	UiStyle.draw_text(self, _message, Vector2(left, message_height), _message_color)
