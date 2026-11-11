# survey_marker.gd: orange brackets on a survey gig's spot once it's on screen, with SURVEY SITE beside
# them, so the spot can be found up close where the edge marker gives way. From DESIGN.md, "Gigs"
# (survey gigs).
class_name SurveyMarker
extends Control

const HALF: float = 14.0

## Where the spot is on screen.
var at := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var box := Rect2((at - Vector2(HALF, HALF * 2.0)).floor(), Vector2(HALF * 2.0, HALF * 2.0))
	var arm: float = 7.0
	var strokes: Array[Rect2] = []
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = box.position.x if corner.x == 0 else box.end.x - 2.0
		var y: float = box.position.y if corner.y == 0 else box.end.y - 2.0
		strokes.append(Rect2(x if corner.x == 0 else x - arm + 2.0, y, arm, 2.0))
		strokes.append(Rect2(x, y if corner.y == 0 else y - arm + 2.0, 2.0, arm))
	for stroke: Rect2 in strokes:
		draw_rect(stroke.grow(1.0), palette.hull_darkest)
	for stroke: Rect2 in strokes:
		draw_rect(stroke, palette.agency_orange)
	var label: String = "SURVEY SITE"
	var label_at := Vector2(box.end.x + 6.0, box.position.y + 2.0).floor()
	draw_rect(Rect2(label_at - Vector2(3.0, 3.0), Vector2(UiStyle.text_width(label, 1) + 6.0, 13.0)), UiStyle.box_fill())
	UiStyle.draw_text(self, label, label_at, palette.agency_orange_light, 1)
