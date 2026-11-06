# telemetry_readout.gd: shows altitude and speed, and how each touchdown went.
# From DESIGN.md, "Art direction" (telemetry colors) and "Camera, zoom, and landing". This
# is a rough readout so landing can be judged, not the real UI, which isn't designed yet.
# Text is drawn from art/hud_font.png on the game's pixel grid.
extends Node2D

## Characters in hud_font.png, in order.
const FONT_CHARACTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const GLYPH_SIZE := Vector2i(10, 14)
const LINE_ADVANCE: int = 12

## Telemetry cyan, green, and amber, and agency red, from the agency palette.
@export var text_color: Color = Color("7FE3D6")
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
## Where the readout goes, under the flight mode panel, within the safe area.
@export var readout_position: Vector2 = Vector2(10.0, 40.0)
## How far below the top of the screen the touchdown message goes.
@export var message_height: float = 60.0

var font_texture: Texture2D = preload("res://art/hud_font.png")

var _altitude_text: String = ""
var _speed_text: String = ""
var _message: String = ""
var _message_color: Color = Color.WHITE
var _message_time_left: float = 0.0


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			_message = ""
			queue_redraw()


func _on_ship_telemetry_changed(altitude: float, speed: float) -> void:
	var altitude_text: String = "ALT %d" % roundi(maxf(altitude, 0.0))
	var speed_text: String = "SPD %d" % roundi(speed)
	if altitude_text != _altitude_text or speed_text != _speed_text:
		_altitude_text = altitude_text
		_speed_text = speed_text
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
	_draw_text(_altitude_text, readout_position, text_color)
	_draw_text(_speed_text, readout_position + Vector2(0.0, 18.0), text_color)
	if _message != "":
		var width: float = _message.length() * LINE_ADVANCE
		var left: float = floorf(((get_parent() as Control).size.x - width) / 2.0)
		_draw_text(_message, Vector2(left, message_height), _message_color)


func _draw_text(text: String, top_left: Vector2, color: Color) -> void:
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_draw_glyphs(text, top_left + offset, outline_color)
	_draw_glyphs(text, top_left, color)


func _draw_glyphs(text: String, top_left: Vector2, color: Color) -> void:
	var x: float = top_left.x
	for character: String in text:
		var index: int = FONT_CHARACTERS.find(character)
		if index >= 0:
			var source := Rect2(index * GLYPH_SIZE.x, 0, GLYPH_SIZE.x, GLYPH_SIZE.y)
			draw_texture_rect_region(font_texture, Rect2(Vector2(x, top_left.y), GLYPH_SIZE), source, color)
		x += LINE_ADVANCE
