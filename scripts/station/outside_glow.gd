# outside_glow.gd: what glows on a station seen from outside: its windows, warm while it's powered, its
# nav lights (red on the west, green on the east), its strobe, and each docking collar's approach
# lights. They're drawn flat in the palette's glow colors over the lit hull, so shade and the star never
# darken them. It's a child of the station's roof sprite, so it's scaled with it and fades with the roof.
# From DESIGN.md, "Lighting" (outside).
class_name OutsideGlow
extends Node2D

## How wide and tall a light is, in station pixels.
const LIGHT_SIZE: float = 3.0

## Where the picture's top left corner is relative to this node, in pixels.
var origin := Vector2.ZERO
## Window rectangles on the picture.
var windows: Array[Rect2i] = []
## Each light: its "point" on the picture, its "kind", and its "port".
var lights: Array[Dictionary] = []

var _powered: bool = true
var _strobe_on: bool = false
# What each approach light shows by its port name: "amber", "green", or "off".
var _approach: Dictionary = {}
var _palette: AgencyPalette


func _ready() -> void:
	_palette = UiStyle.palette()


## Says what the lights do now, and redraws if it's changed.
func set_state(powered: bool, strobe_on: bool, approach: Dictionary) -> void:
	if powered == _powered and strobe_on == _strobe_on and approach == _approach:
		return
	_powered = powered
	_strobe_on = strobe_on
	_approach = approach.duplicate()
	queue_redraw()


## The color a light shows now, or nothing (a clear color) if it's out.
func color_of(light: Dictionary) -> Color:
	var palette: AgencyPalette = _palette if _palette != null else UiStyle.palette()
	match light["kind"]:
		OutsideLight.NAV_RED:
			return palette.agency_red
		OutsideLight.NAV_GREEN:
			return palette.telemetry_green
		OutsideLight.STROBE:
			return palette.thrust_white if _strobe_on else Color(0.0, 0.0, 0.0, 0.0)
		OutsideLight.APPROACH:
			match _approach.get(light["port"], "off"):
				"amber":
					return palette.telemetry_amber
				"green":
					return palette.telemetry_green
	return Color(0.0, 0.0, 0.0, 0.0)


func _draw() -> void:
	var palette: AgencyPalette = _palette if _palette != null else UiStyle.palette()
	if _powered:
		for window: Rect2i in windows:
			draw_rect(Rect2(Vector2(window.position) - origin, Vector2(window.size)), palette.thrust_yellow)
	for light: Dictionary in lights:
		var color: Color = color_of(light)
		if color.a > 0.0:
			var at: Vector2 = Vector2(light["point"]) - origin - Vector2(LIGHT_SIZE, LIGHT_SIZE) * 0.5
			draw_rect(Rect2(at.round(), Vector2(LIGHT_SIZE, LIGHT_SIZE)), color)
