# airlock_lamps.gd: the status lamps beside an airlock's doors: green while the chamber is open to the
# station, red while it's sealed, and amber pulsing while it cycles. They glow, so they're drawn flat
# in the palette's lamp colors, over everything else inside. From DESIGN.md, "Universe generation"
# (stations) and the new Kapteyn-3's airlock.
class_name AirlockLamps
extends Node2D

const GREEN: int = 0
const RED: int = 1
const AMBER: int = 2
## How wide and tall a lamp is, in station pixels, and how fast an amber one pulses, in times a second.
const LAMP_SIZE: float = 4.0
const PULSE_RATE: float = 3.0

## Each lamp: where its middle is, in this node's pixels, and which "airlock" (a number) it's on.
var lamps: Array[Dictionary] = []
var _states: Dictionary = {}
var _time: float = 0.0
var _palette: AgencyPalette


func _ready() -> void:
	_palette = UiStyle.palette()


## Sets the state of every lamp on one airlock.
func set_state(airlock: int, state: int) -> void:
	if _states.get(airlock, GREEN) == state:
		return
	_states[airlock] = state
	queue_redraw()


## What state an airlock's lamps are in.
func state_of(airlock: int) -> int:
	return _states.get(airlock, GREEN)


## The color a lamp shows right now, for an airlock in this state.
func color_for(state: int) -> Color:
	var palette: AgencyPalette = _palette if _palette != null else UiStyle.palette()
	match state:
		RED:
			return palette.agency_red
		AMBER:
			return palette.telemetry_amber if int(_time * PULSE_RATE * 2.0) % 2 == 0 else palette.agency_orange_dark
	return palette.telemetry_green


func _process(delta: float) -> void:
	_time += delta
	for airlock: int in _states:
		if _states[airlock] == AMBER:
			queue_redraw()
			return


func _draw() -> void:
	for lamp: Dictionary in lamps:
		var at: Vector2 = lamp["at"] - Vector2(LAMP_SIZE, LAMP_SIZE) * 0.5
		draw_rect(Rect2(at.round(), Vector2(LAMP_SIZE, LAMP_SIZE)), color_for(_states.get(lamp["airlock"], GREEN)))
