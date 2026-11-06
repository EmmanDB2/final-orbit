# plate_panel.gd: a side panel's metal backing, with a red mark showing where BURN is so
# the strip still shows it when the panel is hidden. From DESIGN.md, "UI" (auto-hide).
class_name PlatePanel
extends Control

var burn_mark: Rect2 = Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	UiStyle.draw_plate(self, Rect2(Vector2.ZERO, size))
	if burn_mark.size != Vector2.ZERO:
		draw_rect(burn_mark.grow_individual(0.0, 0.0, 2.0, 0.0), UiStyle.palette().agency_red)
