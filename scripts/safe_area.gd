# safe_area.gd: a full-screen container for the UI that stays clear of camera cutouts and
# system bars. From DESIGN.md, "Platform: Galaxy Z Fold 8".
#
# Build UI as children of this node, anchored to its corners and edges, and it will follow
# every screen shape and every fold on its own.
extends Control


func _on_screen_fitted(_view_size: Vector2, inset_top_left: Vector2, inset_bottom_right: Vector2) -> void:
	offset_left = inset_top_left.x
	offset_top = inset_top_left.y
	offset_right = -inset_bottom_right.x
	offset_bottom = -inset_bottom_right.y
